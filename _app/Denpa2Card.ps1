function New-Rpg2RoundRectPath([Drawing.RectangleF]$Rect,[single]$Radius) {
  $path=New-Object Drawing.Drawing2D.GraphicsPath;$diameter=$Radius*2
  $path.AddArc($Rect.X,$Rect.Y,$diameter,$diameter,180,90);$path.AddArc($Rect.Right-$diameter,$Rect.Y,$diameter,$diameter,270,90)
  $path.AddArc($Rect.Right-$diameter,$Rect.Bottom-$diameter,$diameter,$diameter,0,90);$path.AddArc($Rect.X,$Rect.Bottom-$diameter,$diameter,$diameter,90,90);$path.CloseFigure();$path
}

function Get-Rpg2CardLabel([string]$Japanese) {
  if($env:DENPA_EDITOR_LANGUAGE-ne'English'){return $Japanese}
  $labels=@{'名前'='Name';'性格'='Personality';'アンテナ'='Antenna';'体格'='Body Type';'補正'='Abilities';'特典ID'='Present ID';'くび'='Neck';'ふく'='Clothes';'うで'='Arm';'せなか'='Back';'あし'='Feet'}
  if($labels.ContainsKey($Japanese)){return [string]$labels[$Japanese]};$Japanese
}

function Add-Rpg2CardPanel([Drawing.Graphics]$Graphics,[Drawing.RectangleF]$Rect,[Drawing.Color]$Fill,[Drawing.Color]$Border,[single]$Radius,[single]$Width=4) {
  $path=New-Rpg2RoundRectPath $Rect $Radius;$brush=New-Object Drawing.SolidBrush($Fill);$pen=New-Object Drawing.Pen($Border,$Width)
  $Graphics.FillPath($brush,$path);$Graphics.DrawPath($pen,$path);$brush.Dispose();$pen.Dispose();$path.Dispose()
}

function Add-Rpg2CardText([Drawing.Graphics]$Graphics,[string]$Text,[Drawing.FontFamily]$Family,[single]$Size,[Drawing.Color]$Color,[Drawing.RectangleF]$Rect,[string]$Alignment='Near') {
  $font=New-Object Drawing.Font($Family,$Size,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$brush=New-Object Drawing.SolidBrush($Color);$format=New-Object Drawing.StringFormat
  $format.Alignment=[Drawing.StringAlignment]::$Alignment;$format.LineAlignment='Center';$Graphics.DrawString($Text,$font,$brush,$Rect,$format)
  $format.Dispose();$brush.Dispose();$font.Dispose()
}

function Add-Rpg2CardOutlinedText([Drawing.Graphics]$Graphics,[string]$Text,[Drawing.FontFamily]$Family,[single]$Size,[Drawing.RectangleF]$Rect,[single]$MinimumSize=15) {
  $font=New-Object Drawing.Font($Family,$Size,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$format=New-Object Drawing.StringFormat;$format.LineAlignment='Center';$format.FormatFlags=$format.FormatFlags-bor[Drawing.StringFormatFlags]::NoWrap
  $path=$null;$actual=$Size
  while($actual-ge$MinimumSize){if($path){$path.Dispose()};$path=New-Object Drawing.Drawing2D.GraphicsPath;$emSize=$Graphics.DpiY*$actual/72;$layoutRect=[Drawing.RectangleF]::new($Rect.X,$Rect.Y,10000,$Rect.Height);$path.AddString($Text,$Family,[int][Drawing.FontStyle]::Bold,$emSize,$layoutRect,$format);$bounds=$path.GetBounds();if($bounds.Width-le($Rect.Width-3)-and$bounds.Right-le($Rect.Right-4)-and$bounds.Height-le($Rect.Height-2)){break};$actual-=1}
  $outline=New-Object Drawing.Pen([Drawing.Color]::FromArgb(245,250,250,250),5);$outline.LineJoin='Round';$fill=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(25,33,39))
  $Graphics.DrawPath($outline,$path);$Graphics.FillPath($fill,$path);$fill.Dispose();$outline.Dispose();$path.Dispose();$format.Dispose();$font.Dispose()
}

function Get-Rpg2CardFontFamilies([string]$AssetRoot) {
  $collection=New-Object Drawing.Text.PrivateFontCollection
  $fontPath=Join-Path $AssetRoot 'fonts\MPLUS1p-Bold.ttf'
  if(Test-Path -LiteralPath $fontPath){$collection.AddFontFile($fontPath)}
  $display=$collection.Families|Where-Object Name -eq 'M PLUS 1p'|Select-Object -First 1;$ui=$display
  if(-not$display){$display=New-Object Drawing.FontFamily('Yu Gothic UI')};if(-not$ui){$ui=New-Object Drawing.FontFamily('Yu Gothic UI')}
  [pscustomobject]@{Collection=$collection;Display=$display;UI=$ui}
}

function Get-Rpg2CardVisibleBounds([Drawing.Bitmap]$Bitmap) {
  $left=$Bitmap.Width;$top=$Bitmap.Height;$right=-1;$bottom=-1
  $data=$Bitmap.LockBits((New-Object Drawing.Rectangle(0,0,$Bitmap.Width,$Bitmap.Height)),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try{
    $stride=[Math]::Abs($data.Stride);$bytes=New-Object byte[]($stride*$Bitmap.Height);[Runtime.InteropServices.Marshal]::Copy($data.Scan0,$bytes,0,$bytes.Length)
    for($y=0;$y-lt$Bitmap.Height;$y++){for($x=0;$x-lt$Bitmap.Width;$x++){if($bytes[$y*$stride+$x*4+3]-gt0){if($x-lt$left){$left=$x};if($x-gt$right){$right=$x};if($y-lt$top){$top=$y};if($y-gt$bottom){$bottom=$y}}}}
  }finally{$Bitmap.UnlockBits($data)}
  if($right-lt$left-or$bottom-lt$top){[Drawing.Rectangle]::new(0,0,$Bitmap.Width,$Bitmap.Height)}else{[Drawing.Rectangle]::new([int]$left,[int]$top,[int]($right-$left+1),[int]($bottom-$top+1))}
}

function Add-Rpg2CardModel([Drawing.Graphics]$Graphics,[string]$ModelPath) {
  if(!(Test-Path -LiteralPath $ModelPath)){return}
  $model=[Drawing.Bitmap]::FromFile($ModelPath);try{$source=Get-Rpg2CardVisibleBounds $model;$target=New-Object Drawing.RectangleF(48,344,320,530);$scale=[Math]::Min($target.Width/$source.Width,$target.Height/$source.Height);$width=$source.Width*$scale;$height=$source.Height*$scale;$x=$target.X+($target.Width-$width)/2;$y=$target.Y+($target.Height-$height)/2;$destination=[Drawing.Rectangle]::new([int][Math]::Round($x),[int][Math]::Round($y),[int][Math]::Round($width),[int][Math]::Round($height));$Graphics.DrawImage($model,$destination,$source.X,$source.Y,$source.Width,$source.Height,[Drawing.GraphicsUnit]::Pixel)}finally{$model.Dispose()}
}

function New-Rpg2CardBitmap {
  param(
    [string]$AssetRoot,[string]$ModelPath,[hashtable]$QrPaths,[string]$Name,[string]$Personality,[string]$Stature,[string]$Antenna,
    [string]$SpecialId,[string]$Neck,[string]$Arm,[string]$Back,[string]$Feet,[string]$Clothing,[datetime]$IssueDate=(Get-Date),[string]$Correction=''
  )
  # 未装備はカード上では文字を出さない。GUI上の表記揺れもここで吸収する。
  if($Neck -in @('なし','(なし)','（なし）')){$Neck=''}
  if($Arm -in @('なし','(なし)','（なし）')){$Arm=''}
  if($Back -in @('なし','(なし)','（なし）')){$Back=''}
  if($Feet -in @('なし','(なし)','（なし）')){$Feet=''}
  if($Clothing -in @('なし','(なし)','（なし）')){$Clothing=''}
  $backgroundPath=Join-Path $AssetRoot 'rpg2-card\rpg2-card-background-original.jpg';if(!(Test-Path -LiteralPath $backgroundPath)){throw 'RPG2カード背景が見つかりません。'}
  $bitmap=[Drawing.Bitmap]::FromFile($backgroundPath);$g=[Drawing.Graphics]::FromImage($bitmap);$fonts=Get-Rpg2CardFontFamilies $AssetRoot;$display=$fonts.Display;$ui=$fonts.UI
  $g.SmoothingMode='AntiAlias';$g.InterpolationMode='HighQualityBicubic';$g.PixelOffsetMode='HighQuality';$g.TextRenderingHint='AntiAliasGridFit'
  $ink=[Drawing.Color]::FromArgb(28,25,38);$purpleFill=[Drawing.Color]::FromArgb(214,165,148,220);$purpleBorder=[Drawing.Color]::FromArgb(91,39,147)
  Add-Rpg2CardPanel $g (New-Object Drawing.RectangleF(528,31,726,216)) $purpleFill $purpleBorder 18 4
  $dash=New-Object Drawing.Pen([Drawing.Color]::FromArgb(155,255,255,255),2);$dash.DashStyle='Dot';$g.DrawLine($dash,556,106,1227,106);$g.DrawLine($dash,556,170,1227,170);$dash.Dispose()
  Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel '名前') $ui 24 (New-Object Drawing.RectangleF(557,48,120,48));Add-Rpg2CardOutlinedText $g $Name $display 28 (New-Object Drawing.RectangleF(700,48,525,48)) 14
  Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel '体格') $ui 24 (New-Object Drawing.RectangleF(557,112,135,48));Add-Rpg2CardOutlinedText $g $Stature $display 24 (New-Object Drawing.RectangleF(700,112,175,48)) 18
  Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel 'アンテナ') $ui 24 (New-Object Drawing.RectangleF(557,176,145,48));Add-Rpg2CardOutlinedText $g $Antenna $display 24 (New-Object Drawing.RectangleF(700,176,280,48)) 18
  Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel '性格') $ui 22 (New-Object Drawing.RectangleF(880,112,140,48));Add-Rpg2CardOutlinedText $g $Personality $display 22 (New-Object Drawing.RectangleF(1025,112,205,48)) 12
  Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel '補正') $ui 22 $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){[Drawing.RectangleF]::new(988,176,125,48)}else{[Drawing.RectangleF]::new(988,176,100,48)});Add-Rpg2CardOutlinedText $g $Correction $display 20 $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){[Drawing.RectangleF]::new(1110,176,135,48)}else{[Drawing.RectangleF]::new(1070,176,175,48)}) 12
  Add-Rpg2CardPanel $g (New-Object Drawing.RectangleF(31,322,354,580)) ([Drawing.Color]::FromArgb(218,255,255,255)) ([Drawing.Color]::White) 28 5;Add-Rpg2CardModel $g $ModelPath

  $regions=@(@{Name='JP';X=406;Tint=[Drawing.Color]::FromArgb(255,150,179);Tab=[Drawing.Color]::FromArgb(255,221,232)},@{Name='NA';X=690;Tint=[Drawing.Color]::FromArgb(119,207,147);Tab=[Drawing.Color]::FromArgb(221,248,229)},@{Name='EU';X=971;Tint=[Drawing.Color]::FromArgb(116,196,231);Tab=[Drawing.Color]::FromArgb(218,244,255)})
  foreach($region in $regions){$regionX=[int]$region.X;Add-Rpg2CardPanel $g ([Drawing.RectangleF]::new($regionX,322,267,320)) ([Drawing.Color]::FromArgb(238,255,255,255)) $region.Tint 17 3;$tabBrush=New-Object Drawing.SolidBrush($region.Tab);$g.FillRectangle($tabBrush,$regionX+2,324,77,40);$tabBrush.Dispose();Add-Rpg2CardText $g $region.Name $display 28 $ink ([Drawing.RectangleF]::new($regionX+10,322,62,43)) 'Center';if($QrPaths.ContainsKey($region.Name)-and(Test-Path -LiteralPath $QrPaths[$region.Name])){$qr=[Drawing.Image]::FromFile($QrPaths[$region.Name]);$g.InterpolationMode='NearestNeighbor';$g.DrawImage($qr,[Drawing.Rectangle]::new($regionX+2,366,264,264));$g.InterpolationMode='HighQualityBicubic';$qr.Dispose()}}

  $equipFill=[Drawing.Color]::FromArgb(224,40,159,148);$equipBorder=[Drawing.Color]::FromArgb(18,105,103);Add-Rpg2CardPanel $g (New-Object Drawing.RectangleF(405,662,842,240)) $equipFill $equipBorder 13 4
  $separator=New-Object Drawing.Pen([Drawing.Color]::FromArgb(170,12,91,91),3);$g.DrawLine($separator,408,718,1244,718);$g.DrawLine($separator,408,778,1244,778);$g.DrawLine($separator,408,838,1244,838);$g.DrawLine($separator,811,718,811,899);$separator.Dispose()
  Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel '特典ID') $ui $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){25}else{29}) (New-Object Drawing.RectangleF(435,668,150,44));Add-Rpg2CardOutlinedText $g $SpecialId $display 25 (New-Object Drawing.RectangleF(575,668,220,44));Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel 'くび') $ui $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){25}else{29}) (New-Object Drawing.RectangleF(436,722,115,52));Add-Rpg2CardOutlinedText $g $Neck $display 25 (New-Object Drawing.RectangleF(575,722,220,52))
  Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel 'せなか') $ui $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){25}else{29}) (New-Object Drawing.RectangleF(436,782,125,52));Add-Rpg2CardOutlinedText $g $Back $display 25 (New-Object Drawing.RectangleF(575,782,220,52));Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel 'うで') $ui $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){25}else{29}) (New-Object Drawing.RectangleF(832,722,100,52));Add-Rpg2CardOutlinedText $g $Arm $display 25 (New-Object Drawing.RectangleF(959,722,265,52))
  Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel 'ふく') $ui $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){25}else{29}) (New-Object Drawing.RectangleF(436,842,100,52));Add-Rpg2CardOutlinedText $g $Clothing $display 25 (New-Object Drawing.RectangleF(575,842,220,52));Add-Rpg2CardOutlinedText $g (Get-Rpg2CardLabel 'あし') $ui $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){25}else{29}) (New-Object Drawing.RectangleF(832,782,100,52));Add-Rpg2CardOutlinedText $g $Feet $display 25 (New-Object Drawing.RectangleF(959,782,265,52))
  Add-Rpg2CardText $g ('発行日　'+$IssueDate.ToString('yyyy/MM/dd')) $ui 24 $ink (New-Object Drawing.RectangleF(36,930,360,44))
  $g.Dispose();$fonts.Collection.Dispose();$bitmap
}
