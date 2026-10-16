function New-Rpg1RoundRectPath([Drawing.RectangleF]$Rect,[single]$Radius) {
  $path=New-Object Drawing.Drawing2D.GraphicsPath;$diameter=$Radius*2
  $path.AddArc($Rect.X,$Rect.Y,$diameter,$diameter,180,90);$path.AddArc($Rect.Right-$diameter,$Rect.Y,$diameter,$diameter,270,90)
  $path.AddArc($Rect.Right-$diameter,$Rect.Bottom-$diameter,$diameter,$diameter,0,90);$path.AddArc($Rect.X,$Rect.Bottom-$diameter,$diameter,$diameter,90,90);$path.CloseFigure();$path
}

function Get-Rpg1CardLabel([string]$Japanese) {
  if($env:DENPA_EDITOR_LANGUAGE-ne'English'){return $Japanese}
  $labels=@{'名前'='Name';'性格'='Personality';'アンテナ'='Antenna';'体格'='Body Type';'補正'='Abilities'}
  if($labels.ContainsKey($Japanese)){return [string]$labels[$Japanese]};$Japanese
}

function Add-Rpg1CardPanel([Drawing.Graphics]$Graphics,[Drawing.RectangleF]$Rect,[Drawing.Color]$Fill,[Drawing.Color]$Border,[single]$Radius,[single]$Width=4) {
  $path=New-Rpg1RoundRectPath $Rect $Radius;$brush=New-Object Drawing.SolidBrush($Fill);$pen=New-Object Drawing.Pen($Border,$Width)
  $Graphics.FillPath($brush,$path);$Graphics.DrawPath($pen,$path);$brush.Dispose();$pen.Dispose();$path.Dispose()
}

function Add-Rpg1CardText([Drawing.Graphics]$Graphics,[string]$Text,[Drawing.FontFamily]$Family,[single]$Size,[Drawing.Color]$Color,[Drawing.RectangleF]$Rect,[string]$Alignment='Near') {
  $font=New-Object Drawing.Font($Family,$Size,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$brush=New-Object Drawing.SolidBrush($Color);$format=New-Object Drawing.StringFormat
  $format.Alignment=[Drawing.StringAlignment]::$Alignment;$format.LineAlignment='Center';$Graphics.DrawString($Text,$font,$brush,$Rect,$format);$format.Dispose();$brush.Dispose();$font.Dispose()
}

function Add-Rpg1CardFittedText([Drawing.Graphics]$Graphics,[string]$Text,[Drawing.FontFamily]$Family,[single]$Size,[single]$Minimum,[Drawing.Color]$Color,[Drawing.RectangleF]$Rect) {
  $chosen=$Size;while($chosen-gt$Minimum){$font=New-Object Drawing.Font($Family,$chosen,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$measured=$Graphics.MeasureString($Text,$font);$font.Dispose();if($measured.Width-le$Rect.Width){break};$chosen-=1}
  Add-Rpg1CardText $Graphics $Text $Family $chosen $Color $Rect
}

function Get-Rpg1CardFontFamilies([string]$AssetRoot) {
  $collection=New-Object Drawing.Text.PrivateFontCollection
  $fontPath=Join-Path $AssetRoot 'fonts\MPLUS1p-Bold.ttf'
  if(Test-Path -LiteralPath $fontPath){$collection.AddFontFile($fontPath)}
  $display=$collection.Families|Where-Object Name -eq 'M PLUS 1p'|Select-Object -First 1;$ui=$display
  if(-not$display){$display=New-Object Drawing.FontFamily('Yu Gothic UI')};if(-not$ui){$ui=New-Object Drawing.FontFamily('Yu Gothic UI')}
  [pscustomobject]@{Collection=$collection;Display=$display;UI=$ui}
}

function Get-Rpg1CardVisibleBounds([Drawing.Bitmap]$Bitmap) {
  $left=$Bitmap.Width;$top=$Bitmap.Height;$right=-1;$bottom=-1
  $data=$Bitmap.LockBits((New-Object Drawing.Rectangle(0,0,$Bitmap.Width,$Bitmap.Height)),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try{$stride=[Math]::Abs($data.Stride);$bytes=New-Object byte[]($stride*$Bitmap.Height);[Runtime.InteropServices.Marshal]::Copy($data.Scan0,$bytes,0,$bytes.Length)
    for($y=0;$y-lt$Bitmap.Height;$y++){for($x=0;$x-lt$Bitmap.Width;$x++){if($bytes[$y*$stride+$x*4+3]-gt0){if($x-lt$left){$left=$x};if($x-gt$right){$right=$x};if($y-lt$top){$top=$y};if($y-gt$bottom){$bottom=$y}}}}}finally{$Bitmap.UnlockBits($data)}
  if($right-lt$left-or$bottom-lt$top){[Drawing.Rectangle]::new(0,0,$Bitmap.Width,$Bitmap.Height)}else{[Drawing.Rectangle]::new([int]$left,[int]$top,[int]($right-$left+1),[int]($bottom-$top+1))}
}

function Add-Rpg1CardModel([Drawing.Graphics]$Graphics,[string]$ModelPath) {
  if(!(Test-Path -LiteralPath $ModelPath)){return};$model=[Drawing.Bitmap]::FromFile($ModelPath)
  try{$source=Get-Rpg1CardVisibleBounds $model;$target=[Drawing.RectangleF]::new(48,344,320,530);$scale=[Math]::Min($target.Width/$source.Width,$target.Height/$source.Height);$width=$source.Width*$scale;$height=$source.Height*$scale
    $destination=[Drawing.Rectangle]::new([int][Math]::Round($target.X+($target.Width-$width)/2),[int][Math]::Round($target.Y+($target.Height-$height)/2),[int][Math]::Round($width),[int][Math]::Round($height));$Graphics.DrawImage($model,$destination,$source.X,$source.Y,$source.Width,$source.Height,[Drawing.GraphicsUnit]::Pixel)}finally{$model.Dispose()}
}

function New-Rpg1CardBitmap {
  param([string]$AssetRoot,[string]$ModelPath,[hashtable]$QrPaths,[string]$Name,[string]$Personality,[string]$Stature,[string]$Antenna,[datetime]$IssueDate=(Get-Date),[string]$Correction='')
  $backgroundPath=Join-Path $AssetRoot 'rpg1-card\rpg1-card-background-original.jpg';if(!(Test-Path -LiteralPath $backgroundPath)){throw 'RPG1カード背景が見つかりません。'}
  $source=[Drawing.Bitmap]::FromFile($backgroundPath);try{$bitmap=New-Object Drawing.Bitmap($source)}finally{$source.Dispose()}
  $g=[Drawing.Graphics]::FromImage($bitmap);$fonts=Get-Rpg1CardFontFamilies $AssetRoot;$display=$fonts.Display;$ui=$fonts.UI;$ink=[Drawing.Color]::FromArgb(28,31,35)
  $g.SmoothingMode='AntiAlias';$g.InterpolationMode='HighQualityBicubic';$g.PixelOffsetMode='HighQuality';$g.TextRenderingHint='AntiAliasGridFit'
  $rowPen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(90,78,68,57),2);$rowPen.DashStyle='Dot';$g.DrawLine($rowPen,556,106,1227,106);$g.DrawLine($rowPen,556,170,1227,170);$rowPen.Dispose()
  Add-Rpg1CardText $g (Get-Rpg1CardLabel '名前') $ui 24 $ink ([Drawing.RectangleF]::new(557,48,120,48));Add-Rpg1CardFittedText $g $Name $display 28 14 $ink ([Drawing.RectangleF]::new(700,48,525,48))
  Add-Rpg1CardFittedText $g (Get-Rpg1CardLabel '体格') $ui 24 18 $ink ([Drawing.RectangleF]::new(557,112,135,48));Add-Rpg1CardFittedText $g $Stature $display 24 18 $ink ([Drawing.RectangleF]::new(700,112,175,48))
  Add-Rpg1CardText $g (Get-Rpg1CardLabel 'アンテナ') $ui 24 $ink ([Drawing.RectangleF]::new(557,176,145,48));Add-Rpg1CardFittedText $g $Antenna $display 24 18 $ink ([Drawing.RectangleF]::new(700,176,280,48))
  Add-Rpg1CardFittedText $g (Get-Rpg1CardLabel '性格') $ui 22 15 $ink ([Drawing.RectangleF]::new(880,112,140,48));Add-Rpg1CardFittedText $g $Personality $display 22 12 $ink ([Drawing.RectangleF]::new(1025,112,205,48))
  Add-Rpg1CardFittedText $g (Get-Rpg1CardLabel '補正') $ui 22 15 $ink ([Drawing.RectangleF]::new(988,176,100,48));Add-Rpg1CardFittedText $g $Correction $display 20 12 $ink ([Drawing.RectangleF]::new(1090,176,145,48))
  Add-Rpg1CardPanel $g ([Drawing.RectangleF]::new(31,322,354,580)) ([Drawing.Color]::FromArgb(150,255,255,255)) ([Drawing.Color]::FromArgb(165,255,255,255)) 28 5;Add-Rpg1CardModel $g $ModelPath
  $regions=@(@{Name='JP';X=406;Tint=[Drawing.Color]::FromArgb(255,150,179);Tab=[Drawing.Color]::FromArgb(255,221,232)},@{Name='NA';X=690;Tint=[Drawing.Color]::FromArgb(119,207,147);Tab=[Drawing.Color]::FromArgb(221,248,229)},@{Name='EU';X=971;Tint=[Drawing.Color]::FromArgb(116,196,231);Tab=[Drawing.Color]::FromArgb(218,244,255)})
  foreach($region in $regions){$x=[int]$region.X;Add-Rpg1CardPanel $g ([Drawing.RectangleF]::new($x,322,267,320)) ([Drawing.Color]::White) $region.Tint 17 3
    $tab=New-Object Drawing.SolidBrush($region.Tab);$g.FillRectangle($tab,$x+2,324,77,40);$tab.Dispose();Add-Rpg1CardText $g $region.Name $display 28 $ink ([Drawing.RectangleF]::new($x+10,322,62,43)) 'Center'
    if($QrPaths.ContainsKey($region.Name)-and(Test-Path -LiteralPath $QrPaths[$region.Name])){$qr=[Drawing.Image]::FromFile($QrPaths[$region.Name]);$g.InterpolationMode='NearestNeighbor';$g.DrawImage($qr,[Drawing.Rectangle]::new($x+2,366,264,264));$g.InterpolationMode='HighQualityBicubic';$qr.Dispose()}}
  Add-Rpg1CardText $g ('発行日　'+$IssueDate.ToString('yyyy/MM/dd')) $ui 24 $ink ([Drawing.RectangleF]::new(36,930,360,44))
  $g.Dispose();$fonts.Collection.Dispose();$bitmap
}
