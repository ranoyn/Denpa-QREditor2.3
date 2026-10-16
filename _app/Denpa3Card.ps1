function New-Rpg3CardRoundRectPath([Drawing.RectangleF]$Rect,[single]$Radius) {
  $path=New-Object Drawing.Drawing2D.GraphicsPath;$diameter=$Radius*2
  $path.AddArc($Rect.X,$Rect.Y,$diameter,$diameter,180,90);$path.AddArc($Rect.Right-$diameter,$Rect.Y,$diameter,$diameter,270,90)
  $path.AddArc($Rect.Right-$diameter,$Rect.Bottom-$diameter,$diameter,$diameter,0,90);$path.AddArc($Rect.X,$Rect.Bottom-$diameter,$diameter,$diameter,90,90);$path.CloseFigure();$path
}

function Get-Rpg3CardLabel([string]$Japanese) {
  if($env:DENPA_EDITOR_LANGUAGE-ne'English'){return $Japanese}
  $equipmentLabels=@{'ふく'='Clothing';'くび'='Neck';'せなか'='Back';'うで'='Arms';'あし'='Feet'}
  if($equipmentLabels.ContainsKey($Japanese)){return $equipmentLabels[$Japanese]}
  $labels=@{'名前'='Name';'性格'='Personality';'アンテナ'='Antenna';'体格'='Body Type';'補正'='Abilities';'特典ID'='Present ID';'アイテム'='Item';'モンスター'='Monster';'デコレ1'='Decorate 1';'デコレ2'='Decorate 2';'デコレ3'='Decorate 3';'ジュエル'='Jewels';'さいだいHP'='Max HP';'さいだいAP'='Max AP';'こうげきりょく'='Attack';'ぼうぎょりょく'='Defend';'すばやさ'='Speed';'かいひりつ'='Evade'}
  if($labels.ContainsKey($Japanese)){return [string]$labels[$Japanese]};$Japanese
}

function Get-Rpg3CardPersonality([string]$Value) {
  $Value=$Value-replace'\(頭身変化\)|\(Proportion Change\)',''
  $english=$env:DENPA_EDITOR_LANGUAGE-eq'English'
  switch -Regex ($Value) {
    '^(主人公|Protagonist)(\(注意\)|\(Caution\))?$' {if($english){return 'Protagonist(Caution)'};return '主人公(注意)'}
    '^(テル|Jasper)$' {if($english){return 'Jasper'};return 'テル'}
    '^(ルナ|Amber)$' {if($english){return 'Amber'};return 'ルナ'}
  }
  Get-Rpg3CardValue $Value
}

function Add-Rpg3CardPanel([Drawing.Graphics]$Graphics,[Drawing.RectangleF]$Rect,[Drawing.Color]$Fill,[Drawing.Color]$Border,[single]$Radius,[single]$Width=4) {
  $path=New-Rpg3CardRoundRectPath $Rect $Radius;$brush=New-Object Drawing.SolidBrush($Fill);$pen=New-Object Drawing.Pen($Border,$Width)
  $Graphics.FillPath($brush,$path);$Graphics.DrawPath($pen,$path);$brush.Dispose();$pen.Dispose();$path.Dispose()
}

function Add-Rpg3CardBluePanel([Drawing.Graphics]$Graphics,[Drawing.RectangleF]$Rect,[single]$Radius) {
  $path=New-Rpg3CardRoundRectPath $Rect $Radius
  $base=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(92,36,76,190));$Graphics.FillPath($base,$path)
  $outer=New-Object Drawing.Pen([Drawing.Color]::FromArgb(235,19,25,111),4);$Graphics.DrawPath($outer,$path)
  $middleRect=[Drawing.RectangleF]::new($Rect.X+5,$Rect.Y+5,$Rect.Width-10,$Rect.Height-10);$middlePath=New-Rpg3CardRoundRectPath $middleRect ([Math]::Max(2,$Radius-5))
  $middle=New-Object Drawing.Pen([Drawing.Color]::FromArgb(205,76,116,235),2);$Graphics.DrawPath($middle,$middlePath)
  $innerRect=[Drawing.RectangleF]::new($Rect.X+9,$Rect.Y+9,$Rect.Width-18,$Rect.Height-18);$innerPath=New-Rpg3CardRoundRectPath $innerRect ([Math]::Max(2,$Radius-9))
  $inner=New-Object Drawing.Pen([Drawing.Color]::FromArgb(185,128,169,255),1);$Graphics.DrawPath($inner,$innerPath)
  $base.Dispose();$outer.Dispose();$middle.Dispose();$inner.Dispose();$path.Dispose();$middlePath.Dispose();$innerPath.Dispose()
}

function Add-Rpg3CardBlueRow([Drawing.Graphics]$Graphics,[Drawing.RectangleF]$Rect,[single]$BandCenterY) {
  $path=New-Rpg3CardRoundRectPath $Rect 2;$cell=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(18,53,89,200));$Graphics.FillPath($cell,$path)
  $edge=New-Object Drawing.Pen([Drawing.Color]::FromArgb(128,16,33,125),2);$Graphics.DrawPath($edge,$path)
  $bandRect=[Drawing.RectangleF]::new($Rect.X+3,$BandCenterY-11,$Rect.Width-6,22)
  $band=[Drawing.Drawing2D.LinearGradientBrush]::new($bandRect,[Drawing.Color]::FromArgb(174,15,36,146),[Drawing.Color]::FromArgb(151,25,71,190),0);$Graphics.FillRectangle($band,$bandRect)
  $top=New-Object Drawing.Pen([Drawing.Color]::FromArgb(135,92,128,238),1);$bottom=New-Object Drawing.Pen([Drawing.Color]::FromArgb(165,10,25,107),1)
  $Graphics.DrawLine($top,$bandRect.X,$bandRect.Y,$bandRect.Right,$bandRect.Y);$Graphics.DrawLine($bottom,$bandRect.X,$bandRect.Bottom,$bandRect.Right,$bandRect.Bottom)
  $cell.Dispose();$edge.Dispose();$band.Dispose();$top.Dispose();$bottom.Dispose();$path.Dispose()
}

function Get-Rpg3CardFontFamilies([string]$AssetRoot) {
  $collection=New-Object Drawing.Text.PrivateFontCollection
  $fontPath=Join-Path $AssetRoot 'fonts\MPLUS1p-Bold.ttf'
  if(Test-Path -LiteralPath $fontPath){$collection.AddFontFile($fontPath)}
  $display=$collection.Families|Where-Object Name -eq 'M PLUS 1p'|Select-Object -First 1;$ui=$display
  if(-not$display){$display=New-Object Drawing.FontFamily('Yu Gothic UI')};if(-not$ui){$ui=New-Object Drawing.FontFamily('Yu Gothic UI')}
  [pscustomobject]@{Collection=$collection;Display=$display;UI=$ui}
}

function Add-Rpg3CardText([Drawing.Graphics]$Graphics,[string]$Text,[Drawing.FontFamily]$Family,[single]$Size,[Drawing.Color]$Color,[Drawing.RectangleF]$Rect,[string]$Alignment='Near') {
  if([string]::IsNullOrWhiteSpace($Text)){return}
  $font=New-Object Drawing.Font($Family,$Size,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$brush=New-Object Drawing.SolidBrush($Color);$format=New-Object Drawing.StringFormat
  $format.Alignment=[Drawing.StringAlignment]::$Alignment;$format.LineAlignment='Center';$format.FormatFlags=$format.FormatFlags-bor[Drawing.StringFormatFlags]::NoWrap
  $Graphics.DrawString($Text,$font,$brush,$Rect,$format);$format.Dispose();$brush.Dispose();$font.Dispose()
}

function Add-Rpg3CardOutlinedText([Drawing.Graphics]$Graphics,[string]$Text,[Drawing.FontFamily]$Family,[single]$Size,[Drawing.RectangleF]$Rect,[single]$MinimumSize=15) {
  if([string]::IsNullOrWhiteSpace($Text)){return}
  $format=New-Object Drawing.StringFormat;$format.LineAlignment='Center';$format.FormatFlags=$format.FormatFlags-bor[Drawing.StringFormatFlags]::NoWrap
  $path=$null;$actual=$Size
  while($actual-ge$MinimumSize){
    if($path){$path.Dispose()};$path=New-Object Drawing.Drawing2D.GraphicsPath;$emSize=$Graphics.DpiY*$actual/72
    $layoutRect=[Drawing.RectangleF]::new($Rect.X,$Rect.Y,10000,$Rect.Height)
    $path.AddString($Text,$Family,[int][Drawing.FontStyle]::Bold,$emSize,$layoutRect,$format);$bounds=$path.GetBounds()
    if($bounds.Width-le($Rect.Width-3)-and$bounds.Right-le($Rect.Right-4)-and$bounds.Height-le($Rect.Height-2)){break};$actual-=1
  }
  $outline=New-Object Drawing.Pen([Drawing.Color]::FromArgb(235,8,24,77),4);$outline.LineJoin='Round';$fill=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(250,255,255,255))
  $Graphics.DrawPath($outline,$path);$Graphics.FillPath($fill,$path);$fill.Dispose();$outline.Dispose();$path.Dispose();$format.Dispose()
}

function Get-Rpg3CardVisibleBounds([Drawing.Bitmap]$Image) {
  $left=$Image.Width;$top=$Image.Height;$right=-1;$bottom=-1
  $data=$Image.LockBits([Drawing.Rectangle]::new(0,0,$Image.Width,$Image.Height),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try{
    $stride=[Math]::Abs($data.Stride);$bytes=New-Object byte[]($stride*$Image.Height)
    for($y=0;$y-lt$Image.Height;$y++){[Runtime.InteropServices.Marshal]::Copy([IntPtr]::Add($data.Scan0,$y*$data.Stride),$bytes,$y*$stride,$stride)}
    for($y=0;$y-lt$Image.Height;$y++){$row=$y*$stride;for($x=0;$x-lt$Image.Width;$x++){if($bytes[$row+$x*4+3]-lt8){continue};if($x-lt$left){$left=$x};if($x-gt$right){$right=$x};if($y-lt$top){$top=$y};if($y-gt$bottom){$bottom=$y}}}
  }finally{$Image.UnlockBits($data)}
  if($right-lt$left-or$bottom-lt$top){return [Drawing.Rectangle]::new(0,0,$Image.Width,$Image.Height)}
  [Drawing.Rectangle]::new($left,$top,$right-$left+1,$bottom-$top+1)
}

function Add-Rpg3CardModel([Drawing.Graphics]$Graphics,[string]$ModelPath) {
  if(!(Test-Path -LiteralPath $ModelPath)){return};$model=[Drawing.Bitmap]::FromFile($ModelPath)
  try{$source=Get-Rpg3CardVisibleBounds $model;$target=[Drawing.RectangleF]::new(48,344,320,530);$scale=[Math]::Min($target.Width/$source.Width,$target.Height/$source.Height);$width=$source.Width*$scale;$height=$source.Height*$scale
    $destination=[Drawing.Rectangle]::new([int][Math]::Round($target.X+($target.Width-$width)/2),[int][Math]::Round($target.Y+($target.Height-$height)/2),[int][Math]::Round($width),[int][Math]::Round($height))
    $Graphics.DrawImage($model,$destination,$source.X,$source.Y,$source.Width,$source.Height,[Drawing.GraphicsUnit]::Pixel)}finally{$model.Dispose()}
}

function Get-Rpg3CardValue([string]$Value) {
  if([string]::IsNullOrWhiteSpace($Value)-or$Value-in@('なし','(なし)','（なし）')){return ''};$Value
}

function New-Rpg3CardBitmap {
  param(
    [string]$AssetRoot,[string]$ModelPath,[hashtable]$QrPaths,[string]$Name,[string]$Personality,[string]$Stature,[string]$Antenna,[string]$Correction,
    [string]$SpecialId,[string]$Monster,[string]$Item,[string]$Decor1,[string]$Decor2,[string]$Decor3,[int]$JewelCount=0,[datetime]$IssueDate=(Get-Date),
    [int]$HpBonus=0,[int]$ApBonus=0,[int]$AttackBonus=0,[int]$DefenseBonus=0,[int]$SpeedBonus=0,[int]$EvadeBonus=0,
    [switch]$IsNormal,[hashtable]$Equipment=@{}
  )
  $Personality=Get-Rpg3CardPersonality $Personality;$Correction=Get-Rpg3CardValue $Correction;$Monster=Get-Rpg3CardValue $Monster;$Item=Get-Rpg3CardValue $Item
  $Decor1=Get-Rpg3CardValue $Decor1;$Decor2=Get-Rpg3CardValue $Decor2;$Decor3=Get-Rpg3CardValue $Decor3
  $backgroundPath=Join-Path $AssetRoot 'rpg3-card\rpg3-card-background-original.jpg';if(!(Test-Path -LiteralPath $backgroundPath)){throw 'RPG3カード背景が見つかりません。'}
  $bitmap=[Drawing.Bitmap]::FromFile($backgroundPath);$g=[Drawing.Graphics]::FromImage($bitmap);$fonts=Get-Rpg3CardFontFamilies $AssetRoot;$display=$fonts.Display;$ui=$fonts.UI
  $g.SmoothingMode='AntiAlias';$g.InterpolationMode='HighQualityBicubic';$g.PixelOffsetMode='HighQuality';$g.TextRenderingHint='AntiAliasGridFit';$ink=[Drawing.Color]::FromArgb(20,28,45)

  Add-Rpg3CardBluePanel $g ([Drawing.RectangleF]::new(528,31,726,216)) 9
  Add-Rpg3CardBlueRow $g ([Drawing.RectangleF]::new(540,42,702,60)) 72;Add-Rpg3CardBlueRow $g ([Drawing.RectangleF]::new(540,102,702,64)) 136;Add-Rpg3CardBlueRow $g ([Drawing.RectangleF]::new(540,166,702,69)) 200
  Add-Rpg3CardOutlinedText $g (Get-Rpg3CardLabel '名前') $ui 24 ([Drawing.RectangleF]::new(557,48,120,48));Add-Rpg3CardOutlinedText $g $Name $display 28 ([Drawing.RectangleF]::new(700,48,525,48)) 14
  Add-Rpg3CardOutlinedText $g (Get-Rpg3CardLabel '体格') $ui 24 ([Drawing.RectangleF]::new(557,112,135,48));Add-Rpg3CardOutlinedText $g $Stature $display 24 ([Drawing.RectangleF]::new(700,112,175,48)) 18
  Add-Rpg3CardOutlinedText $g (Get-Rpg3CardLabel '性格') $ui 22 ([Drawing.RectangleF]::new(880,112,140,48));Add-Rpg3CardOutlinedText $g $Personality $display 22 ([Drawing.RectangleF]::new(1025,112,205,48)) 12
  Add-Rpg3CardOutlinedText $g (Get-Rpg3CardLabel 'アンテナ') $ui 24 ([Drawing.RectangleF]::new(557,176,145,48));Add-Rpg3CardOutlinedText $g $Antenna $display 24 ([Drawing.RectangleF]::new(700,176,280,48)) 18
  Add-Rpg3CardOutlinedText $g (Get-Rpg3CardLabel '補正') $ui 22 $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){[Drawing.RectangleF]::new(988,176,125,48)}else{[Drawing.RectangleF]::new(988,176,100,48)});Add-Rpg3CardOutlinedText $g $Correction $display 20 $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){[Drawing.RectangleF]::new(1110,176,135,48)}else{[Drawing.RectangleF]::new(1070,176,175,48)}) 12

  Add-Rpg3CardPanel $g ([Drawing.RectangleF]::new(31,322,354,580)) ([Drawing.Color]::FromArgb(218,255,255,255)) ([Drawing.Color]::White) 28 5;Add-Rpg3CardModel $g $ModelPath
  $regions=@(@{Name='JP';X=406;Tint=[Drawing.Color]::FromArgb(255,150,179);Tab=[Drawing.Color]::FromArgb(255,221,232)},@{Name='NA';X=690;Tint=[Drawing.Color]::FromArgb(119,207,147);Tab=[Drawing.Color]::FromArgb(221,248,229)},@{Name='EU';X=971;Tint=[Drawing.Color]::FromArgb(116,196,231);Tab=[Drawing.Color]::FromArgb(218,244,255)})
  foreach($region in $regions){$x=[int]$region.X;Add-Rpg3CardPanel $g ([Drawing.RectangleF]::new($x,322,267,320)) ([Drawing.Color]::FromArgb(238,255,255,255)) $region.Tint 17 3
    $tab=New-Object Drawing.SolidBrush($region.Tab);$g.FillRectangle($tab,$x+2,324,77,40);$tab.Dispose();Add-Rpg3CardText $g $region.Name $display 28 $ink ([Drawing.RectangleF]::new($x+10,322,62,43)) 'Center'
    if($QrPaths.ContainsKey($region.Name)-and(Test-Path -LiteralPath $QrPaths[$region.Name])){$qr=[Drawing.Image]::FromFile($QrPaths[$region.Name]);$g.InterpolationMode='NearestNeighbor';$g.DrawImage($qr,[Drawing.Rectangle]::new($x+2,366,264,264));$g.InterpolationMode='HighQualityBicubic';$qr.Dispose()}}

  Add-Rpg3CardBluePanel $g ([Drawing.RectangleF]::new(405,662,842,240)) 7
  $rows=if($IsNormal){
    $none=if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'None'}else{'なし'}
    $gear=@{};foreach($key in @('clothing','neck','back','arm','feet')){$gear[$key]=if($Equipment.ContainsKey($key)-and-not[string]::IsNullOrWhiteSpace($Equipment[$key])){[string]$Equipment[$key]}else{$none}}
    @(
      @('ふく',$gear.clothing,'くび',$gear.neck),
      @('せなか',$gear.back,'うで',$gear.arm),
      @('あし',$gear.feet,'さいだいHP',('+'+$HpBonus.ToString())),
      @('さいだいAP',('+'+$ApBonus.ToString()),'こうげきりょく',('+'+$AttackBonus.ToString())),
      @('ぼうぎょりょく',('+'+$DefenseBonus.ToString()),'すばやさ',('+'+$SpeedBonus.ToString()))
    )
  }else{@(
    @('特典ID',$SpecialId,'ジュエル',($JewelCount.ToString()+'J')),
    @('アイテム',$Item,'デコレ1',$Decor1),
    @('デコレ2',$Decor2,'さいだいHP',('+'+$HpBonus.ToString())),
    @('さいだいAP',('+'+$ApBonus.ToString()),'こうげきりょく',('+'+$AttackBonus.ToString())),
    @('ぼうぎょりょく',('+'+$DefenseBonus.ToString()),'すばやさ',('+'+$SpeedBonus.ToString()))
  )}
  for($index=0;$index-lt$rows.Count;$index++){
    $row=$rows[$index];$y=668+$index*46
    Add-Rpg3CardBlueRow $g ([Drawing.RectangleF]::new(408,$y,403,46)) ($y+23)
    Add-Rpg3CardBlueRow $g ([Drawing.RectangleF]::new(811,$y,433,46)) ($y+23)
    Add-Rpg3CardOutlinedText $g (Get-Rpg3CardLabel $row[0]) $ui 23 ([Drawing.RectangleF]::new(435,$y+1,190,44)) 15
    Add-Rpg3CardOutlinedText $g $row[1] $display 23 ([Drawing.RectangleF]::new(635,$y+1,170,44)) 12
    Add-Rpg3CardOutlinedText $g (Get-Rpg3CardLabel $row[2]) $ui 23 ([Drawing.RectangleF]::new(832,$y+1,190,44)) 15
    Add-Rpg3CardOutlinedText $g $row[3] $display 23 ([Drawing.RectangleF]::new(1032,$y+1,194,44)) 12
  }

  # Both formats share this two-row overlay at the bottom of the model panel.
  Add-Rpg3CardBluePanel $g ([Drawing.RectangleF]::new(31,806,354,96)) 7
  Add-Rpg3CardBlueRow $g ([Drawing.RectangleF]::new(34,808,348,46)) 831
  Add-Rpg3CardBlueRow $g ([Drawing.RectangleF]::new(34,854,348,46)) 877
  Add-Rpg3CardOutlinedText $g (Get-Rpg3CardLabel 'モンスター') $ui 22 ([Drawing.RectangleF]::new(46,809,118,44)) 14
  Add-Rpg3CardOutlinedText $g $Monster $display 22 ([Drawing.RectangleF]::new(170,809,198,44)) 12
  Add-Rpg3CardOutlinedText $g (Get-Rpg3CardLabel 'かいひりつ') $ui 22 ([Drawing.RectangleF]::new(46,855,118,44)) 14
  Add-Rpg3CardOutlinedText $g ('+'+$EvadeBonus.ToString()) $display 22 ([Drawing.RectangleF]::new(170,855,198,44)) 12

  Add-Rpg3CardText $g ('発行日　'+$IssueDate.ToString('yyyy/MM/dd')) $ui 24 $ink ([Drawing.RectangleF]::new(36,930,360,44))
  $g.Dispose();$fonts.Collection.Dispose();$bitmap
}
