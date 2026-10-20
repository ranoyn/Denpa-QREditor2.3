Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$cardModule = Join-Path $PSScriptRoot 'Denpa2Card.ps1'
if (Test-Path -LiteralPath $cardModule) { . $cardModule }
$towerFilterModule = Join-Path $PSScriptRoot 'DenpaTowerFilter.ps1'
if (Test-Path -LiteralPath $towerFilterModule) { . $towerFilterModule }

$localAssetRoot = Join-Path $PSScriptRoot 'assets'
$assetRoot = if (Test-Path -LiteralPath $localAssetRoot) { $localAssetRoot } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\assets')) }
$script:rpg3TwoDAssetRoot=Join-Path $assetRoot 'rpg3-2d'
. (Join-Path $PSScriptRoot 'Rpg3TwoDPreview.ps1')
# Compatibility argument label only; no JavaScript file is required.
$editorTool = 'denpa2-qr-editor.mjs'
. (Join-Path $PSScriptRoot 'DenpaQrBackend.ps1')

# Reconstruct the legacy Shiroganemaru/Yamana defaults from field definitions.
$normalCarrier = 'generated2:normal-shiroganemaru'
$specialCarrier = 'generated2:special-yamana'

$localDataRoot = Join-Path $PSScriptRoot 'data'
$dataRoot = if (Test-Path -LiteralPath $localDataRoot) { $localDataRoot } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\data')) }
$templateCatalogModule=Join-Path $PSScriptRoot 'DenpaTemplateCatalog.ps1';if(!(Test-Path -LiteralPath $templateCatalogModule)){throw '電波テンプレート読込機能が見つかりません。'};. $templateCatalogModule
$nameLanguageModule=Join-Path $PSScriptRoot 'DenpaNameLanguage.ps1'
if(!(Test-Path -LiteralPath $nameLanguageModule)){throw '多言語名前UIが見つかりません。'}
. $nameLanguageModule
$nameCatalogPath = Join-Path $dataRoot 'rpg2-name-catalog.tsv'
$naEquipmentCatalogPath = Join-Path $dataRoot 'rpg2-equipment-na.tsv'
$naEquipmentRows = if(Test-Path -LiteralPath $naEquipmentCatalogPath){@(Import-Csv -LiteralPath $naEquipmentCatalogPath -Delimiter "`t" -Encoding UTF8)}else{@()}
$naEquipmentNamesByCode=@{}
foreach($row in $naEquipmentRows){$naEquipmentNamesByCode[([string]$row.category+'|'+([string]$row.code).ToUpperInvariant())]=[string]$row.en_name}
$antennaCatalogPath = Join-Path $dataRoot 'antenna-catalog.json'
$antennaCatalog = if(Test-Path $antennaCatalogPath){Get-Content $antennaCatalogPath -Raw -Encoding UTF8|ConvertFrom-Json}else{$null}
$towerCompatibilityPath=Join-Path $dataRoot 'rpg2-tower-compatibility.json'
$towerCompatibility=if(Test-Path -LiteralPath $towerCompatibilityPath){Get-Content -Raw -LiteralPath $towerCompatibilityPath -Encoding UTF8|ConvertFrom-Json}else{$null}
$legitimateNames = @('つかさ')
if (Test-Path -LiteralPath $nameCatalogPath) {
  $loadedNames = @(Import-Csv -LiteralPath $nameCatalogPath -Delimiter "`t" -Encoding UTF8 | ForEach-Object { $_.name } | Where-Object { $_ })
  if ($loadedNames.Count) { $legitimateNames = $loadedNames }
}
$displayNames=@(Sort-DenpaJapaneseNames $legitimateNames)

function New-CodeArray([int]$Maximum) { @(0..$Maximum | ForEach-Object { '{0:X2}' -f $_ }) }
function New-DecimalArray([int]$Maximum) { @(0..$Maximum | ForEach-Object { $_.ToString() }) }
function New-Rpg2UndefinedTail([object[]]$Confirmed,[int]$TargetMaximum){@($Confirmed+@(($Confirmed.Count)..$TargetMaximum|ForEach-Object{"未定義($_)"}))}
function New-GenericNames([string]$Prefix, [int]$Maximum, [bool]$ZeroIsNone = $false) {
  @(0..$Maximum | ForEach-Object {
    if ($ZeroIsNone -and $_ -eq 0) { '(なし)' } else { "$Prefix$($_ + 1)" }
  })
}

# RPG2で確認済みの選択肢に、指定数だけ連続する未定義値を加える。
# 統合版で別作品から切り替えた場合は未定義値へ自動変換せず0へ戻す。
function New-Rpg2ConfirmedOptions([object[]]$Names, [int]$ConfirmedMaximum, [int]$UnimplementedCount = 1) {
  $confirmed = @($Names[0..$ConfirmedMaximum])
  $unimplemented = @(1..$UnimplementedCount | ForEach-Object {
    "未定義($($ConfirmedMaximum + $_))"
  })
  return @($confirmed + $unimplemented)
}
function New-Rpg2ConfirmedCodes([int]$ConfirmedMaximum, [int]$UnimplementedCount = 1) {
  return @(0..($ConfirmedMaximum + $UnimplementedCount) | ForEach-Object { '{0:X2}' -f $_ })
}

$personalityNames = @('いちご','にがうり','トウガラシ','バナナ','レモン','ぶどう','かき')
$antennaNames = @(
  'アンテナなし','おたから2ばい','レアおたから2ばい','ゴールド2ばい','ちょっとステルス',
  'ちょっとかいふく','みんなすこしかいふく','ちょっとふっかつ','みんなちょっとふっかつ',
  'げどく','やけどなおす','かわかす','かぜなおす','どろおとす','おはらい','かんでんなおす',
  'あたためる','しびれとる','めざめる','めぐすり','むてき','みんなこうふん','たくわえる',
  'わざはねかえす','すこしつよくなれ','みんなつよめになれ','すこしかたくなれ',
  'みんなかためになれ','すこしはやくなれ','みんなはやめになれ','すこしかわしやすい',
  'みんなあてられにくい','どくどくシグナル','もうどく','ねむらせる','しびれさせる',
  'めかくし','ブレスふうじ','すこしよわくなれ','みんなよわめになれ','すこしやわくなれ',
  'みんなやわらかめ','すこしおそくなれ','みんなおそめになれ','ひのたま','ばくはつ','やまかじ',
  'とがったこおり','ロックアイス','あられ','つむじかぜ','ビルかぜ','かまいたち','らくせき',
  'いしつぶて','マグニチュード3','せいでんき','いなづま','ひゃくボルト','みずでっぽう',
  'バケツのみず','たかなみ','よわいこうせん','スポットライト','ふゆのひざし','おどかす',
  'ダークボール','くろいきり'
)
$rpg3ExtraAntennaNames=@('つかまえる','もえさかるこおり','かさいせんぷう','だいふんか','らくらいかさい','ほのおのうみ','こおりあらし','こおりいんせき','かみなりふぶき','ひさめ','つちけむり','でんきあらし','ぼうふうう','かみなりがんせき','どせきりゅう','らいう','ならくのたいよう')
$rpg3ExtraAntennaCodes=@(68,69,70,71,72,73,75,76,77,78,81,82,83,87,88,93,99)
for($i=0;$i-lt$rpg3ExtraAntennaNames.Count;$i++){$antennaNames+=("{0}(未定義{1})"-f$rpg3ExtraAntennaNames[$i],$rpg3ExtraAntennaCodes[$i])}
$antennaCodes=@(0..67|ForEach-Object{'{0:X2}'-f$_})+@($rpg3ExtraAntennaCodes|ForEach-Object{'{0:X2}'-f$_})
$bodyColorNames = @(
  '黒','赤','水色','緑','オレンジ','黄','青','白','赤／水色','赤／緑','赤／オレンジ','赤／黄','赤／青','赤／白',
  '水色／緑','水色／オレンジ','水色／黄','水色／青','水色／白','緑／オレンジ','緑／黄','緑／青','緑／白',
  'オレンジ／黄','オレンジ／青','オレンジ／白','黄／青','黄／白','青／白','紫','銀','金','桃'
)
$headNames = @(
  'まる','よこまる','たてまる','さんかく','おにぎり','しかく','かどまる','しずく','つぼ','こぐま',
  'あまつゆ','チューリップ','ロボ','イカ','ロケット','スター','くま','ハート','ねこみみ','デビル',
  'みかづき','とんがり','でんち','トゲトゲ','たまご','タワー','いぬみみ','メラメラ','クワガタ',
  'ダイヤ','ルビー','たいよう','うさみみ','まきがい','キャッスル','ブロック','たまねぎ','わっか','コック','おさかな','クラッシュ'
)
$rpg2HeadOptions=@()
for($headIndex=0;$headIndex-le39;$headIndex++){
  $rpg2HeadOptions+=if($headIndex-le31){$headNames[$headIndex]}else{"$($headNames[$headIndex])(未定義)"}
}
$statureNames = @(
  '0最速','0準速','0中間','0準大','0最大','3+最速','3+準速','3+中間','3+準大','3+最大',
  '3-最速','3-準速','3-中間','3-準大','3-最大','6+最速','6+準速','6+中間','6+準大','6+最大',
  '10最速','6-準速','6-中間','6-準大','6-最大','15最速','15準速','15中間','10準大','10最大'
)
$hairColorNames = @('黒','白','茶','黄茶','赤茶','黄','青','緑','紫','桃','オレンジ','赤','黒(未定義12)','金(未定義13)','青(未定義14)','銀(未定義15)')
$skinHairNames=@('黒','白','茶','黄茶','赤茶','黄','青','緑','紫','桃')
$skinNames = @(0..5 | ForEach-Object { $_.ToString() }) + @(0..19 | ForEach-Object { '{0}髪(未定義{1})' -f $skinHairNames[$_], (6 + $_) })
$faceEquipmentNames = @(
  '(なし)','みどりのめがね','ピンクのめがね','サングラス','きいろいめがね','しかくいめがね',
  'アイマスク','ふくろうめがね','あおいめがね','マスカレードマスク','くろぶちめがね',
  'バタフライマスク','すいちゅうメガネ','むしのめ','きんぴかグラス','ハートグラス'
  ,'スターグラス','あかぶちメガネ','ワイルドグラス','ゴーグル','カラーゴーグル','まるめがね','びんぞこめがね','パイロットゴーグル','未定義(24)','未定義(25)'
)
$neckEquipmentNames = @('(なし)') + @(
  'めざましのスカーフ','よくみえのスカーフ','マヒよけのスカーフ','まえかけ','どくよけのスカーフ',
  'スパイクチョーカー','ハートのチョーカー','バラのチョーカー','まよけのすず','めざましのリボン',
  'よくみえのリボン','マヒよけのリボン','やみのおまもり','ひのおまもり','ひかりのおまもり',
  'みずのおまもり','でんきのおまもり','つちのおまもり','こおりのおまもり','かぜのおまもり',
  'たいかんのリボン','たいねつのリボン','どくよけのリボン','クリスマスコサージュ','ネクタイ','つけえり',
  'ハロウィンのリボン','たいかんのマフラー','めんえきのマフラー','ゴムのマフラー','どろよけのマフラー',
  'ぼうすいのマフラー','たいねつのマフラー','のろいよけのマフラー','しんぴのスカーフ','まどわずのリボン',
  'いやしのリボン','しあわせのおまもり','まどわずのスカーフ','ぼうはんブザー','しんぴのリボン',
  'ラッキースター','いやしのスカーフ','きんのチョーカー','ハートのネックレス','こううんのおまもり',
  'しあわせのおまもり+','きぞくのスカーフ','きんのペンダント','シークレットスター','てあみのマフラー'
)
$neckEquipmentCodes=@('0000')+@(384..434|ForEach-Object{'{0:X4}'-f$_})
$backCatalogPath = Join-Path $dataRoot 'rpg2-back-equipment.tsv'
if (Test-Path -LiteralPath $backCatalogPath) {
  $backRows = @(Import-Csv -LiteralPath $backCatalogPath -Delimiter "`t" -Encoding UTF8)
  $backEquipmentNames = @('(なし)') + @($backRows | ForEach-Object { $_.name })
  $backEquipmentCodes = @('0000') + @($backRows | ForEach-Object { $_.code })
} else {
  $backEquipmentNames = @('(なし)','おもちゃのかたな','カミナリだいこ','ぴこぴこハンマー','むしのはね','ふろしきぶくろ')
  $backEquipmentCodes = @('0000','01C8','01CC','01D0','01D4','01D8')
}
$armCatalogPath = Join-Path $dataRoot 'rpg2-arm-equipment.tsv'
if (Test-Path -LiteralPath $armCatalogPath) {
  $armRows = @(Import-Csv -LiteralPath $armCatalogPath -Delimiter "`t" -Encoding UTF8)
  $armEquipmentNames = @('(なし)') + @($armRows | ForEach-Object { $_.name })
  $armEquipmentCodes = @('0000') + @($armRows | ForEach-Object { $_.code })
} else {
  $armEquipmentNames = @('(なし)','やすいとけい')
  $armEquipmentCodes = @('0000','0200')
}
$feetCatalogPath = Join-Path $dataRoot 'rpg2-feet-equipment.tsv'
if (Test-Path -LiteralPath $feetCatalogPath) {
  $feetRows = @(Import-Csv -LiteralPath $feetCatalogPath -Delimiter "`t" -Encoding UTF8)
  $feetEquipmentNames = @('(なし)') + @($feetRows | ForEach-Object { $_.name })
  $feetEquipmentCodes = @('0000') + @($feetRows | ForEach-Object { $_.code })
} else {
  $feetEquipmentNames = @('(なし)','すばやさアンクレット')
  $feetEquipmentCodes = @('0000','0230')
}
$clothingCatalogPath = Join-Path $dataRoot 'rpg2-clothing.tsv'
if (Test-Path -LiteralPath $clothingCatalogPath) {
  $clothingRows = @(Import-Csv -LiteralPath $clothingCatalogPath -Delimiter "`t" -Encoding UTF8)
  $clothingNames = @('(なし)') + @($clothingRows | ForEach-Object { $_.name })
  $clothingCodes = @('0400') + @($clothingRows | ForEach-Object { $_.code })
} else {
  $clothingNames = @('(なし)','APプリント','かぼちゃ','うし','クローバー','オーナメント')
  $clothingCodes = @('0400','069D','069E','069F','06A0','06A1')
}

$fields = @(
  @{ Label='名前'; Key='--name'; Names=$displayNames; Default='つかさ'; Name=$true },
  @{ Label='アンテナの形'; Key='--antenna-appearance'; Names=if($antennaCatalog){@($antennaCatalog.appearances|ForEach-Object{$_.name})}else{(New-DecimalArray 0xDF)}; Codes=if($antennaCatalog){@($antennaCatalog.appearances|ForEach-Object{$_.code})}else{(New-CodeArray 0xDF)}; Default='00'; UiOnly=$true },
  @{ Label='頭の形'; Key='--head-shape'; Names=$rpg2HeadOptions; Codes=(New-CodeArray 39); Default='01' },
  @{ Label='髪'; Key='--hair'; Names=(New-Rpg2UndefinedTail (New-DecimalArray 0x1F) 0x3F); Codes=(New-CodeArray 0x3F); Default='00' },
  @{ Label='輪郭'; Key='--face-shape'; Names=(New-Rpg2ConfirmedOptions (New-DecimalArray 0x0F) 8 7); Codes=(New-Rpg2ConfirmedCodes 8 7); Default='08' },
  @{ Label='眉'; Key='--eyebrow'; Names=(New-Rpg2UndefinedTail (New-DecimalArray 0x0F) 0x14); Codes=(New-CodeArray 0x14); Default='00' },
  @{ Label='目'; Key='--eyes'; Names=(New-Rpg2UndefinedTail (New-DecimalArray 0x27) 0x30); Codes=(New-CodeArray 0x30); Default='02' },
  @{ Label='鼻'; Key='--nose'; Names=(New-Rpg2UndefinedTail (New-DecimalArray 0x17) 0x21); Codes=(New-CodeArray 0x21); Default='13' },
  @{ Label='口'; Key='--mouth'; Names=(New-Rpg2UndefinedTail (New-DecimalArray 0x1F) 0x29); Codes=(New-CodeArray 0x29); Default='00' },
  @{ Label='頬'; Key='--cheeks'; Names=(New-Rpg2UndefinedTail (New-DecimalArray 7) 0x0B); Codes=(New-CodeArray 0x0B); Default='00' },
  @{ Label='顔装備'; Key='--glasses'; Names=@($faceEquipmentNames[0..15]+@(16..23|ForEach-Object{"$($faceEquipmentNames[$_])(未定義$_)"})+@('未定義(24)','未定義(25)')); Codes=(New-CodeArray 25); Default='00' },
  @{ Label='体格'; Key='--stature'; Names=$statureNames; Codes=(New-CodeArray 29); Default='17' },
  @{ Label='体色'; Key='--body-color'; Names=$bodyColorNames; Codes=(New-CodeArray 0x20); Default='07' },
  @{ Label='肌色'; Key='--face-image'; Names=$skinNames; Codes=(New-CodeArray 15); Default='05' },
  @{ Label='髪色'; Key='--hair-color'; Names=$hairColorNames; Codes=(New-CodeArray 15); Default='05' },
  @{ Label='性格'; Key='--personality'; Names=@($personalityNames + @('なし','主人公','あかり','テル','ルナ')); Codes=@((New-CodeArray 7) + @('64','65','66','67')); Default='00' },
  @{ Label='アンテナ'; Key='--antenna'; Names=$antennaNames; Codes=$antennaCodes; Default='03' }
)

$form = New-Object Windows.Forms.Form
$form.Text = 'Denpa QREditor2.3 v1.0.2 - RPG2'
$form.ClientSize = New-Object Drawing.Size(1260, 850)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Yu Gothic UI', 10)

$title = New-Object Windows.Forms.Label
$title.Text = 'Denpa QREditor2.3 v1.0.2'
$title.Font = New-Object Drawing.Font('Yu Gothic UI', 16, [Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(18, 14)
$form.Controls.Add($title)

$sub = New-Object Windows.Forms.Label
$sub.Text = '暗号・CRC・QR生成を内蔵（日本版・提供QRを土台に生成）'
$sub.AutoSize = $true
$sub.Location = New-Object Drawing.Point(20, 58)
$form.Controls.Add($sub)

$freeNameCheck = New-Object Windows.Forms.CheckBox
$freeNameCheck.Text = '正規名以外を自由入力'
$freeNameCheck.AutoSize = $true
$freeNameCheck.Location = New-Object Drawing.Point(450, 58)
$form.Controls.Add($freeNameCheck)

$boxes = @{}
$codesByKey = @{}
for ($i = 0; $i -lt $fields.Count; $i++) {
  $column = [Math]::Floor($i / 6)
  $row = $i % 6
  $x = 20 + $column * 185
  $y = 100 + $row * 43
  $label = New-Object Windows.Forms.Label
  $label.Name = 'label_' + $fields[$i].Key
  $label.Text = $fields[$i].Label
  $label.AutoSize = $true
  $label.Location = New-Object Drawing.Point($x, ($y + 4))
  $form.Controls.Add($label)
  $box = New-Object Windows.Forms.ComboBox
  $box.Name = $fields[$i].Key
  $box.DropDownStyle = 'DropDownList'
  $box.Location = New-Object Drawing.Point(($x + 85), $y)
  $box.Size = New-Object Drawing.Size(90, 27)
  $box.DropDownWidth = if ($fields[$i].Name) { 220 } else { 180 }
  [void]$box.Items.AddRange([object[]]$fields[$i].Names)
  if ($fields[$i].Name) {
    $box.SelectedIndex = $box.Items.IndexOf($fields[$i].Default)
  } else {
    $codesByKey[$fields[$i].Key] = @($fields[$i].Codes)
    $box.SelectedIndex = [Array]::IndexOf([object[]]$codesByKey[$fields[$i].Key], [object]$fields[$i].Default)
  }
  $form.Controls.Add($box)
  $boxes[$fields[$i].Key] = $box
}

$nameBox = $boxes['--name']
$boxes['--antenna-appearance'].Enabled=$false
$nameBox.AutoCompleteSource = [Windows.Forms.AutoCompleteSource]::ListItems
$nameBox.AutoCompleteMode = [Windows.Forms.AutoCompleteMode]::SuggestAppend
$nameBox.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDown
$freeNameCheck.Checked=$true
$freeNameCheck.Visible=$false
$nameLanguage=New-DenpaNameLanguageState -Form $form -DataRoot $dataRoot -JpBox $nameBox

# RPG2専用の顔テンプレート。内容は他作品と共有しない。
$faceTemplateLabel=New-Object Windows.Forms.Label;$faceTemplateLabel.Text='顔テンプレート';$faceTemplateLabel.AutoSize=$true;$faceTemplateLabel.Location=New-Object Drawing.Point(390,406);$form.Controls.Add($faceTemplateLabel)
$faceTemplateBox=New-Object Windows.Forms.ComboBox;$faceTemplateBox.Name='faceTemplate';$faceTemplateBox.DropDownStyle='DropDownList';$faceTemplateBox.Location=New-Object Drawing.Point(495,401);$faceTemplateBox.Size=New-Object Drawing.Size(170,27);[void]$faceTemplateBox.Items.Add('(選択なし)');$faceTemplateBox.SelectedIndex=0;$form.Controls.Add($faceTemplateBox)
$towerCombinationCheck=New-Object Windows.Forms.CheckBox;$towerCombinationCheck.Name='towerCombinationCheck';$towerCombinationCheck.Text='正規候補に絞る';$towerCombinationCheck.AutoSize=$true;$towerCombinationCheck.Checked=$false;$towerCombinationCheck.Enabled=($null-ne$towerCompatibility);$towerCombinationCheck.Location=New-Object Drawing.Point(390,438);$form.Controls.Add($towerCombinationCheck)
$faceSyncCheck=New-Object Windows.Forms.CheckBox;$faceSyncCheck.Name='faceSyncCheck';$faceSyncCheck.Text='髪と輪郭を同期する';$faceSyncCheck.AutoSize=$true;$faceSyncCheck.Checked=$true;$faceSyncCheck.Location=New-Object Drawing.Point(390,466);$form.Controls.Add($faceSyncCheck)
$definedFaceCheck=New-Object Windows.Forms.CheckBox;$definedFaceCheck.Name='definedFaceCheck';$definedFaceCheck.Text='未定義を選択しない';$definedFaceCheck.AutoSize=$true;$definedFaceCheck.Checked=$true;$definedFaceCheck.Location=New-Object Drawing.Point(390,494);$form.Controls.Add($definedFaceCheck)
$rpg2HairContourMap=@{1=0;2=0;3=4;4=0;5=7;6=6;7=1;8=0;9=2;10=0;11=7;12=2;13=7;14=4;15=1;16=3;17=1;18=5;19=3;20=0;21=8;22=8;23=0;24=0;25=0;26=0;27=0;28=1;29=0;30=0;31=3}
$rpg2AllNames=@($legitimateNames);$rpg2AllPersonalityNames=@($boxes['--personality'].Items|ForEach-Object{[string]$_});$rpg2AllPersonalityCodes=@($codesByKey['--personality'])
$rpg2TowerFieldMap=@{'--face-shape'='createSelectFace';'--head-shape'='createSelectHead';'--eyes'='createSelectEye';'--nose'='createSelectNose';'--mouth'='createSelectMouth';'--cheeks'='createSelectCheek';'--eyebrow'='createSelectBrow';'--glasses'='createSelectGlass'}
$rpg2TowerValueOffsets=@{'--cheeks'=1;'--glasses'=1}
$rpg2TowerPersonalityFields=@(@{Key='--face-shape';Base=0x00},@{Key='--hair-color';Base=0x28},@{Key='--hair';Base=0x48},@{Key='--stature';Base=0x60},@{Key='--eyebrow';Base=0x70},@{Key='--eyes';Base=0x78},@{Key='--body-color';Base=0x88})
$script:rpg2UpdatingTowerFilter=$false;$script:rpg2TowerFilterActive=$false;$script:rpg2TowerCandidates=$null
function Update-Rpg2TowerChoices{if($script:rpg2UpdatingTowerFilter-or(-not$towerCombinationCheck.Checked-and-not$script:rpg2TowerFilterActive)){return};$script:rpg2UpdatingTowerFilter=$true;try{$candidates=Get-DenpaTowerCandidates $towerCompatibility $boxes $codesByKey $rpg2TowerFieldMap $rpg2TowerPersonalityFields $rpg2TowerValueOffsets;$script:rpg2TowerCandidates=$candidates;Set-DenpaTowerCandidateChoices $towerCombinationCheck.Checked $candidates $nameBox $rpg2AllNames $boxes['--personality'] $codesByKey '--personality' $rpg2AllPersonalityNames $rpg2AllPersonalityCodes;$script:rpg2TowerFilterActive=$towerCombinationCheck.Checked}finally{$script:rpg2UpdatingTowerFilter=$false}}
function Assert-Rpg2TowerCombination{if(-not$towerCombinationCheck.Checked){return};$candidates=Get-DenpaTowerCandidates $towerCompatibility $boxes $codesByKey $rpg2TowerFieldMap $rpg2TowerPersonalityFields $rpg2TowerValueOffsets;if($candidates.Rows.Count-eq0){throw '現在の顔パーツには、アンテナ塔で出現する正規組み合わせがありません。'};$allowedNames=@($candidates.NameIds|ForEach-Object{$rpg2AllNames[[int]$_]});if($allowedNames-notcontains$nameBox.Text){throw '現在の顔パーツからアンテナ塔で出現する名前を選択してください。'};$personalityCode=Get-Code $boxes['--personality'];if($candidates.PersonalityIds-notcontains[Convert]::ToInt32($personalityCode,16)){throw '現在の顔パーツから決まる正規の性格を選択してください。'}}
Format-DenpaNumericFaceChoices $boxes
$rpg2FullFaceNames=@{};$rpg2FullFaceCodes=@{};foreach($key in @('--head-shape','--face-shape','--hair','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses','--hair-color','--face-image')){$rpg2FullFaceNames[$key]=@($boxes[$key].Items|ForEach-Object{[string]$_});$rpg2FullFaceCodes[$key]=@($codesByKey[$key])}
function Update-Rpg2HairContourSync{$hairCode=[Convert]::ToInt32($codesByKey['--hair'][$boxes['--hair'].SelectedIndex],16);if(-not$faceSyncCheck.Checked){$boxes['--face-shape'].Enabled=$true;return};if($hairCode-eq0){$boxes['--face-shape'].Enabled=$true}elseif($rpg2HairContourMap.ContainsKey($hairCode)){$wanted='{0:X2}'-f[int]$rpg2HairContourMap[$hairCode];$idx=[Array]::IndexOf([object[]]$codesByKey['--face-shape'],[object]$wanted);if($idx-ge0){$boxes['--face-shape'].SelectedIndex=$idx;$boxes['--face-shape'].Enabled=$false}}}
function Update-Rpg2DefinedFaceChoices{
  $allowed=@{'--head-shape'=@(0..31);'--face-shape'=@(0..8);'--hair'=@(0..31);'--eyebrow'=@(0..15);'--eyes'=@(0..39);'--nose'=@(0..23);'--mouth'=@(0..31);'--cheeks'=@(0..7);'--glasses'=@(0..15);'--hair-color'=@(0..11);'--face-image'=@(0..5)}
  foreach($key in $allowed.Keys){$current=if($boxes[$key].SelectedIndex-ge0){$codesByKey[$key][$boxes[$key].SelectedIndex]}else{'00'};$names=@();$codes=@();for($i=0;$i-lt$rpg2FullFaceCodes[$key].Count;$i++){if(-not$definedFaceCheck.Checked-or($allowed[$key]-contains[Convert]::ToInt32($rpg2FullFaceCodes[$key][$i],16))){$names+=$rpg2FullFaceNames[$key][$i];$codes+=$rpg2FullFaceCodes[$key][$i]}};$boxes[$key].BeginUpdate();try{$boxes[$key].Items.Clear();[void]$boxes[$key].Items.AddRange([object[]]$names);$codesByKey[$key]=@($codes);$idx=[Array]::IndexOf([object[]]$codes,[object]$current);$boxes[$key].SelectedIndex=if($idx-ge0){$idx}else{0}}finally{$boxes[$key].EndUpdate()}}
  Update-Rpg2HairContourSync
  Update-Rpg2TowerChoices
}
$faceSyncCheck.Add_CheckedChanged({Update-Rpg2HairContourSync;Update-Rpg2TowerChoices});$boxes['--hair'].Add_SelectedIndexChanged({Update-Rpg2HairContourSync;Update-Rpg2TowerChoices});$definedFaceCheck.Add_CheckedChanged({Update-Rpg2DefinedFaceChoices});$towerCombinationCheck.Add_CheckedChanged({if($towerCombinationCheck.Checked){$faceSyncCheck.Checked=$true;$definedFaceCheck.Checked=$true};Update-Rpg2TowerChoices});foreach($key in @($rpg2TowerFieldMap.Keys)+@('--hair-color','--stature','--body-color')){$boxes[$key].Add_SelectedIndexChanged({Update-Rpg2TowerChoices})};Update-Rpg2DefinedFaceChoices

$preview = New-Object Windows.Forms.PictureBox
$preview.Name = 'qrPreview'
$preview.Location = New-Object Drawing.Point(810, 100)
$preview.Size = New-Object Drawing.Size(420, 420)
$preview.SizeMode = 'Zoom'
$preview.BorderStyle = 'FixedSingle'
$form.Controls.Add($preview)

$facePreviewLabel = New-Object Windows.Forms.Label
$facePreviewLabel.Text = 'プレビュー（自動反映）'
$facePreviewLabel.AutoSize = $true
$facePreviewLabel.Location = New-Object Drawing.Point(590, 76)
$form.Controls.Add($facePreviewLabel)
$facePreview = New-Object Windows.Forms.PictureBox
$facePreview.Name = 'facePreview'
$facePreview.Location = New-Object Drawing.Point(590, 100)
$facePreview.Size = New-Object Drawing.Size(200, 200)
$facePreview.SizeMode = 'Zoom'
$facePreview.BackColor = [Drawing.Color]::White
$facePreview.BorderStyle = 'FixedSingle'
$form.Controls.Add($facePreview)
$discordLink=New-Object Windows.Forms.LinkLabel
$discordLink.Name='discordServerLink'
$discordLink.Text='Discord Server'
$discordLink.AutoSize=$true
$discordLink.Font=New-Object Drawing.Font('Yu Gothic UI',11,[Drawing.FontStyle]::Regular)
$discordLink.Location=New-Object Drawing.Point(590,360)
$discordLink.Add_LinkClicked({Start-Process 'https://discord.gg/ndf'})
$form.Controls.Add($discordLink)

$regionGroup = New-Object Windows.Forms.GroupBox
$regionGroup.Text = '地域（選択すると即時反映）'
$regionGroup.Location = New-Object Drawing.Point(590, 365)
$regionGroup.Size = New-Object Drawing.Size(200, 70)
$regionButtons = @{}
foreach($entry in @(@('JP',12),@('NA',72),@('EU',132))){$radio=New-Object Windows.Forms.RadioButton;$radio.Text=$entry[0];$radio.Location=New-Object Drawing.Point($entry[1],28);$radio.AutoSize=$true;$regionGroup.Controls.Add($radio);$regionButtons[$entry[0]]=$radio}
$regionButtons['JP'].Checked=$true
$form.Controls.Add($regionGroup)

$modeLabel = New-Object Windows.Forms.Label
$modeLabel.Text = 'QR形式'
$modeLabel.AutoSize = $true
$modeLabel.Location = New-Object Drawing.Point(20, 500)
$form.Controls.Add($modeLabel)
$modeBox = New-Object Windows.Forms.ComboBox
$modeBox.DropDownStyle = 'DropDownList'
$modeBox.Location = New-Object Drawing.Point(105, 496)
$modeBox.Size = New-Object Drawing.Size(160, 27)
[void]$modeBox.Items.AddRange([object[]]@('通常QR','特典QR'))
$modeBox.SelectedIndex = 0
$form.Controls.Add($modeBox)

$qrDateLabel = New-Object Windows.Forms.Label
$qrDateLabel.Text = 'QR日付'
$qrDateLabel.AutoSize = $true
$qrDateLabel.Location = New-Object Drawing.Point(385, 636)
$qrDateLabel.Visible = $true
$form.Controls.Add($qrDateLabel)
$qrDate = New-Object Windows.Forms.DateTimePicker
$qrDate.Format = [Windows.Forms.DateTimePickerFormat]::Custom
$qrDate.CustomFormat = 'yyyy/MM/dd'
$qrDate.Location = New-Object Drawing.Point(470, 632)
$qrDate.Size = New-Object Drawing.Size(160, 27)
$qrDate.Value = [DateTime]::Today
$qrDate.ShowCheckBox=$true;$qrDate.Checked=$false
$qrDate.Visible = $true
$form.Controls.Add($qrDate)

$claimSlotLabel = New-Object Windows.Forms.Label
$claimSlotLabel.Text = '特典ID'
$claimSlotLabel.AutoSize = $true
$claimSlotLabel.Location = New-Object Drawing.Point(385, 500)
$form.Controls.Add($claimSlotLabel)
$rpg2ClaimSlotValues=@(256..511)
$rpg2ClaimSlotLabels=@(256..511|ForEach-Object{switch($_){257{'257（ショウたろう）'};307{'307（つきよ）'};308{'308（クリス）'};309{'309（いわた）'};310{'310（やまな）'};default{[string]$_}}})
$claimSlotBox = New-Object Windows.Forms.ComboBox
$claimSlotBox.DropDownStyle = 'DropDownList'
$claimSlotBox.Location = New-Object Drawing.Point(470, 496)
$claimSlotBox.Size = New-Object Drawing.Size(180, 27)
$claimSlotBox.DropDownWidth = 210
[void]$claimSlotBox.Items.AddRange([object[]]$rpg2ClaimSlotLabels)
$claimSlotBox.SelectedIndex = 0
$claimSlotBox.Enabled = $false
$form.Controls.Add($claimSlotBox)
function Get-Rpg2ClaimSlot{if($claimSlotBox.SelectedIndex-lt0){throw '特典IDが選択されていません。'};return [int]$rpg2ClaimSlotValues[$claimSlotBox.SelectedIndex]}
function Set-Rpg2ClaimSlot([int]$Value){$index=[Array]::IndexOf([object[]]$rpg2ClaimSlotValues,[object]$Value);if($index-lt0){throw "特典IDが一覧にありません: $Value"};$claimSlotBox.SelectedIndex=$index}
$claimSlotHint = New-Object Windows.Forms.Label
$claimSlotHint.AutoSize = $true
$claimSlotHint.Location = New-Object Drawing.Point(608,500)
$claimSlotHint.Text = ''
$form.Controls.Add($claimSlotHint)
$updateClaimSlotHint = {
  $claimSlotHint.Text = ''
}
$claimSlotHint.Visible=$false
$claimSlotBox.Add_SelectedIndexChanged($updateClaimSlotHint)

$neckLabel = New-Object Windows.Forms.Label
$neckLabel.Text = '首装備'
$neckLabel.AutoSize = $true
$neckLabel.Location = New-Object Drawing.Point(20, 548)
$form.Controls.Add($neckLabel)
$neckBox = New-Object Windows.Forms.ComboBox
$neckBox.DropDownStyle = 'DropDownList'
$neckBox.Location = New-Object Drawing.Point(105, 544)
$neckBox.Size = New-Object Drawing.Size(260, 27)
$neckBox.DropDownWidth = 280
[void]$neckBox.Items.AddRange([object[]]$neckEquipmentNames)
$neckBox.SelectedIndex = 0
$neckBox.Enabled = $false
$form.Controls.Add($neckBox)

$armLabel = New-Object Windows.Forms.Label
$armLabel.Text = '腕装備'
$armLabel.AutoSize = $true
$armLabel.Location = New-Object Drawing.Point(385, 548)
$form.Controls.Add($armLabel)
$armBox = New-Object Windows.Forms.ComboBox
$armBox.DropDownStyle = 'DropDownList'
$armBox.Location = New-Object Drawing.Point(470, 544)
$armBox.Size = New-Object Drawing.Size(260, 27)
$armBox.DropDownWidth = 280
[void]$armBox.Items.AddRange([object[]]$armEquipmentNames)
$armBox.SelectedIndex = 0
$armBox.Enabled = $false
$form.Controls.Add($armBox)

$backLabel = New-Object Windows.Forms.Label
$backLabel.Text = '背中装備'
$backLabel.AutoSize = $true
$backLabel.Location = New-Object Drawing.Point(20, 592)
$form.Controls.Add($backLabel)
$backBox = New-Object Windows.Forms.ComboBox
$backBox.DropDownStyle = 'DropDownList'
$backBox.Location = New-Object Drawing.Point(105, 588)
$backBox.Size = New-Object Drawing.Size(260, 27)
$backBox.DropDownWidth = 280
[void]$backBox.Items.AddRange([object[]]$backEquipmentNames)
$backBox.SelectedIndex = 0
$backBox.Enabled = $false
$form.Controls.Add($backBox)

$clothingLabel = New-Object Windows.Forms.Label
$clothingLabel.Text = '服装備'
$clothingLabel.AutoSize = $true
$clothingLabel.Location = New-Object Drawing.Point(385, 592)
$form.Controls.Add($clothingLabel)
$clothingBox = New-Object Windows.Forms.ComboBox
$clothingBox.DropDownStyle = 'DropDownList'
$clothingBox.Location = New-Object Drawing.Point(470, 588)
$clothingBox.Size = New-Object Drawing.Size(260, 27)
$clothingBox.DropDownWidth = 280
[void]$clothingBox.Items.AddRange([object[]]$clothingNames)
$clothingBox.SelectedIndex = 0
$clothingBox.Enabled = $false
$form.Controls.Add($clothingBox)

$feetLabel = New-Object Windows.Forms.Label
$feetLabel.Text = '足装備'
$feetLabel.AutoSize = $true
$feetLabel.Location = New-Object Drawing.Point(20, 636)
$form.Controls.Add($feetLabel)
$feetBox = New-Object Windows.Forms.ComboBox
$feetBox.DropDownStyle = 'DropDownList'
$feetBox.Location = New-Object Drawing.Point(105, 632)
$feetBox.Size = New-Object Drawing.Size(260, 27)
$feetBox.DropDownWidth = 280
[void]$feetBox.Items.AddRange([object[]]$feetEquipmentNames)
$feetBox.SelectedIndex = 0
$feetBox.Enabled = $false
$form.Controls.Add($feetBox)

$rpg2PaintLabel=New-Object Windows.Forms.Label
$rpg2PaintLabel.Name='rpg2PaintLabel';$rpg2PaintLabel.AutoSize=$true
$rpg2PaintLabel.Location=New-Object Drawing.Point(20,674);$form.Controls.Add($rpg2PaintLabel)
$rpg2PaintBox=New-Object Windows.Forms.ComboBox
$rpg2PaintBox.Name='rpg2PaintBox';$rpg2PaintBox.DropDownStyle='DropDownList'
$rpg2PaintBox.Location=New-Object Drawing.Point(105,670);$rpg2PaintBox.Size=New-Object Drawing.Size(260,27)
$rpg2PaintBox.DropDownWidth=280;$form.Controls.Add($rpg2PaintBox)
function Set-Rpg2PaintLanguage([string]$Language){
  $selected=[Math]::Max(0,$rpg2PaintBox.SelectedIndex)
  $rpg2PaintLabel.Text=if($Language-eq'English'){'Paint'}else{'ペイントざい'}
  $colors=@{'黒'='Black';'赤'='Red';'水色'='Light Blue';'緑'='Green';'オレンジ'='Orange';'黄'='Yellow';'青'='Blue';'白'='White';'紫'='Purple';'銀'='Silver';'金'='Gold';'桃'='Pink'}
  $names=@($(if($Language-eq'English'){'None'}else{'(なし)'}))
  foreach($name in $bodyColorNames){$names+=if($Language-eq'English'){(@($name-split'／'|ForEach-Object{$colors[$_]})-join' / ')}else{$name}}
  $rpg2PaintBox.BeginUpdate()
  try{$rpg2PaintBox.Items.Clear();[void]$rpg2PaintBox.Items.AddRange([object[]]$names);$rpg2PaintBox.SelectedIndex=$selected}finally{$rpg2PaintBox.EndUpdate()}
}
Set-Rpg2PaintLanguage $env:DENPA_EDITOR_LANGUAGE
function Set-Rpg2EquipmentLanguage([string]$Language){
  foreach($spec in @(
    [pscustomobject]@{Category='neck';Box=$neckBox;Codes=$neckEquipmentCodes;Japanese=$neckEquipmentNames},
    [pscustomobject]@{Category='arm';Box=$armBox;Codes=$armEquipmentCodes;Japanese=$armEquipmentNames},
    [pscustomobject]@{Category='back';Box=$backBox;Codes=$backEquipmentCodes;Japanese=$backEquipmentNames},
    [pscustomobject]@{Category='feet';Box=$feetBox;Codes=$feetEquipmentCodes;Japanese=$feetEquipmentNames},
    [pscustomobject]@{Category='clothing';Box=$clothingBox;Codes=$clothingCodes;Japanese=$clothingNames}
  )){
    $selected=$spec.Box.SelectedIndex
    $names=if($Language-eq'English'){
      @(for($i=0;$i-lt$spec.Codes.Count;$i++){
        if($i-eq0){'None';continue}
        $key=$spec.Category+'|'+([string]$spec.Codes[$i]).ToUpperInvariant()
        if($naEquipmentNamesByCode.ContainsKey($key)){$naEquipmentNamesByCode[$key]}else{$spec.Japanese[$i]}
      })
    }else{@($spec.Japanese)}
    $spec.Box.BeginUpdate()
    try{$spec.Box.Items.Clear();[void]$spec.Box.Items.AddRange([object[]]$names)}finally{$spec.Box.EndUpdate()}
    if($selected-ge0-and$selected-lt$spec.Box.Items.Count){$spec.Box.SelectedIndex=$selected}else{$spec.Box.SelectedIndex=0}
  }
}

# 特典QRを選んだ直後に、確認済みの代表装備一式を初期値として使う。
$neckBox.SelectedIndex=$neckBox.Items.IndexOf('しあわせのおまもり')
$armBox.SelectedIndex=[Array]::IndexOf([object[]]$armEquipmentCodes,[object]'0227')
$backBox.SelectedIndex=[Array]::IndexOf([object[]]$backEquipmentCodes,[object]'01F2')
$clothingBox.SelectedIndex=[Array]::IndexOf([object[]]$clothingCodes,[object]'06B3')
$feetBox.SelectedIndex=[Array]::IndexOf([object[]]$feetEquipmentCodes,[object]'024C')

$displayButton = New-Object Windows.Forms.Button
$displayButton.Text = 'QR表示'
$displayButton.Font = New-Object Drawing.Font('Yu Gothic UI', 11, [Drawing.FontStyle]::Bold)
$displayButton.Location = New-Object Drawing.Point(20, 700)
$displayButton.Size = New-Object Drawing.Size(145, 48)
$displayButton.Visible = $false
$form.Controls.Add($displayButton)

$saveButton = New-Object Windows.Forms.Button
$saveButton.Text = 'QR保存'
$saveButton.Font = New-Object Drawing.Font('Yu Gothic UI', 11, [Drawing.FontStyle]::Bold)
$saveButton.Location = New-Object Drawing.Point(20, 700)
$saveButton.Size = New-Object Drawing.Size(145, 48)
$saveButton.Enabled = $false
$form.Controls.Add($saveButton)

$cardButton = New-Object Windows.Forms.Button
$cardButton.Text = 'カードで保存'
$cardButton.Font = New-Object Drawing.Font('Yu Gothic UI', 11, [Drawing.FontStyle]::Bold)
$cardButton.Location = New-Object Drawing.Point(180, 700)
$cardButton.Size = New-Object Drawing.Size(145, 48)
$cardButton.Enabled = $false
$form.Controls.Add($cardButton)

$status = New-Object Windows.Forms.Label
$status.Name = 'qrStatus'
$status.Text = '選択内容からQRを自動生成します。'
$status.Location = New-Object Drawing.Point(350, 705)
$status.Size = New-Object Drawing.Size(680, 50)
$form.Controls.Add($status)

$script:currentQrPath = $null
$script:rpg2Generating = $false
$script:rpg2CardRegionOverride = $null
$script:rpg2TemplateSpecialCarrierPath = $null
$script:rpg2OfficialTemplateDate = $null
$script:rpg2ManualSpecialDate = $qrDate.Value.Date
$script:rpg2DateControlActive = $false
function Clear-Rpg2OfficialTemplateDate {
  $wasOfficial=($null-ne$script:rpg2OfficialTemplateDate)
  $script:rpg2OfficialTemplateDate=$null
  if($wasOfficial){$qrDate.Value=$script:rpg2ManualSpecialDate}
}
function Update-Rpg2ModeControls {
  $hasEquipment=($modeBox.SelectedIndex-eq1)
  $neckBox.Enabled=$hasEquipment;$armBox.Enabled=$hasEquipment;$backBox.Enabled=$hasEquipment;$clothingBox.Enabled=$hasEquipment;$feetBox.Enabled=$hasEquipment;$claimSlotBox.Enabled=$hasEquipment
  $qrDateLabel.Visible=$true;$qrDate.Visible=$true;$script:rpg2DateControlActive=$hasEquipment
  if($hasEquipment-or$null-ne$script:rpg2OfficialTemplateDate){$qrDate.Checked=$true}
  $qrDate.Enabled=($null-eq$script:rpg2OfficialTemplateDate)
  $qrDateLabel.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'QR Date'}else{'QR日付'})
  &$updateClaimSlotHint
}
$autoQrTimer = New-Object Windows.Forms.Timer
$autoQrTimer.Interval = 280
function Get-Code($box) {
  if ($box.SelectedIndex -lt 0) { throw "$($box.Name)が選択されていません。" }
  $codesByKey[$box.Name][$box.SelectedIndex]
}

function Set-Rpg2TemplateCode([string]$Key,[string]$Code) {
  $index=[Array]::IndexOf([object[]]$codesByKey[$Key],[object]$Code.ToUpperInvariant())
  if($index-lt0){throw "顔テンプレートの値が一覧にありません: $Key = $Code"}
  $boxes[$Key].SelectedIndex=$index
}
function Set-Rpg2EquipmentCode([Windows.Forms.ComboBox]$Box,[object[]]$Codes,[string]$Code) {
  $index=[Array]::IndexOf([object[]]$Codes,[object]$Code.ToUpperInvariant())
  if($index-lt0){throw "公式装備が一覧にありません: $Code"}
  $Box.SelectedIndex=$index
}
$rpg2Templates=@(Import-DenpaTemplateCatalog -ApplicationRoot $PSScriptRoot -Game 'RPG2')
if($rpg2Templates.Count-gt0){[void]$faceTemplateBox.Items.AddRange([object[]]@($rpg2Templates|ForEach-Object{$_.Label}))}
$faceTemplateBox.Add_SelectedIndexChanged({
  if($script:templateCatalogRefreshing){return}
  if($faceTemplateBox.SelectedIndex-ge1-and$faceTemplateBox.SelectedIndex-le$rpg2Templates.Count){
    $template=$rpg2Templates[$faceTemplateBox.SelectedIndex-1]
    if($template.ContainsKey('SavedOptions')){Apply-DenpaSavedTemplate $template 'RPG2';return}
    $rpg2MemoBox.Text=if($template.ContainsKey('Memo')){[string]$template.Memo}else{''}
    $rpg2PaintBox.SelectedIndex=if($template.ContainsKey('PaintColor')){[int]$template.PaintColor+1}else{0}
    # Keep the template's stored contour; hair synchronization must not overwrite it.
    $restoreHairSync=$faceSyncCheck.Checked
    $towerCombinationCheck.Checked=$false;$faceSyncCheck.Checked=$false
    Set-DenpaTemplateNames $nameLanguage $template
    foreach($entry in $template.Fields.GetEnumerator()|Where-Object{$_.Key-ne'--antenna-appearance'}){Set-Rpg2TemplateCode $entry.Key $entry.Value}
    Set-Rpg2TemplateCode '--antenna-appearance' $template.Fields['--antenna-appearance']
    $hairCode=[Convert]::ToInt32($template.Fields['--hair'],16);$contourCode=[Convert]::ToInt32($template.Fields['--face-shape'],16)
    if($restoreHairSync-and(($hairCode-eq0)-or($rpg2HairContourMap.ContainsKey($hairCode)-and$rpg2HairContourMap[$hairCode]-eq$contourCode))){$faceSyncCheck.Checked=$true}
    $script:rpg2TemplateSpecialCarrierPath=$null
    if($template.ContainsKey('Date')){if($null-eq$script:rpg2OfficialTemplateDate){$script:rpg2ManualSpecialDate=$qrDate.Value.Date};$script:rpg2OfficialTemplateDate=[datetime]::ParseExact($template.Date,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);$qrDate.Value=$script:rpg2OfficialTemplateDate}else{Clear-Rpg2OfficialTemplateDate}
    if($template.ContainsKey('Claim')){$modeBox.SelectedIndex=1;Set-Rpg2ClaimSlot ([int]$template.Claim);$neckBox.SelectedIndex=if([int]$template.Neck-eq0){0}else{[int]$template.Neck-383};Set-Rpg2EquipmentCode $armBox $armEquipmentCodes $template.Arm;Set-Rpg2EquipmentCode $backBox $backEquipmentCodes $template.Back;Set-Rpg2EquipmentCode $feetBox $feetEquipmentCodes $template.Feet;Set-Rpg2EquipmentCode $clothingBox $clothingCodes $template.Clothing}
    else{$modeBox.SelectedIndex=0;$neckBox.SelectedIndex=0;$armBox.SelectedIndex=0;$backBox.SelectedIndex=0;$feetBox.SelectedIndex=0;$clothingBox.SelectedIndex=0}
  }elseif($faceTemplateBox.SelectedIndex-eq0){$script:rpg2TemplateSpecialCarrierPath=$null;Clear-Rpg2OfficialTemplateDate}
  Update-Rpg2ModeControls
})

function Get-Rpg2Int([string]$Key) { [Convert]::ToInt32((Get-Code $boxes[$Key]),16) }
function Get-Rpg2PreviewPartCode([string]$Key) { Get-DenpaTwoDPreviewPartCode $boxes[$Key] (Get-Rpg2Int $Key) }
function Get-Rpg2EquipmentClaimId([int]$NeckId,[string]$ArmCode,[string]$BackCode,[string]$FeetCode,[string]$ClothingCode) {
  # 現行特別QRは過去版との比較用に、従来どおり0x6E..0x6Fへ入力値をそのまま書く。
  # 特典QRでは0x6Eを受取コード、0x6Fを地域リスト長として分離する。
  return Get-Rpg2ClaimSlot
}
$antennaFinalAppearanceCodes = @(
  0,4,7,10,13,16,19,22,25,27,29,31,33,35,37,39,
  41,43,45,47,49,50,52,54,57,60,63,66,69,72,75,78,
  80,82,84,86,88,90,93,96,99,102,105,108,111,114,117,120,
  123,126,129,132,135,138,141,144,147,150,153,156,159,162,165,168,
  171,174,177,180
)

function New-Rpg2ModelPng([string]$OutputPath,[switch]$IncludeEquipment,[switch]$Transparent) {
  # 配布版は作者提供の2D素材だけでプレビューする。装備欄はQRには残すが、
  # CIA由来の装備モデル／テクスチャは読み込まず、絵には反映しない。
  $bodyPalette=@('#202020','#E83B3B','#38C9F0','#36C96B','#F08A31','#F1D63A','#365CDF','#F3F3F3');$skinPalette=@('#FFE7D2','#FFD2AF','#FFBEAA','#CB8964','#9D6044','#673C2E');$hairPalette=@('#17151D','#F2F2F2','#804507','#CD902A','#942A00','#F0D238','#2667C9','#3C9A4F','#7E4AB5','#E875A5','#F75700','#F00011','#17151D','#F4C542','#2667C9','#AEB8C8')
  $bodyPairs=@(@(1,2),@(1,3),@(1,4),@(1,5),@(1,6),@(1,7),@(2,3),@(2,4),@(2,5),@(2,6),@(2,7),@(3,4),@(3,5),@(3,6),@(3,7),@(4,5),@(4,6),@(4,7),@(5,6),@(5,7),@(6,7))
  $bodyCode=Get-Rpg2Int '--body-color';$bodySecondaryHex=$null;if($bodyCode-ge8-and$bodyCode-le28){$pair=$bodyPairs[$bodyCode-8];$bodyHex=$bodyPalette[$pair[0]];$bodySecondaryHex=$bodyPalette[$pair[1]]}else{$bodyHex=if($bodyCode-lt8){$bodyPalette[$bodyCode]}elseif($bodyCode-eq29){'#8A46C7'}elseif($bodyCode-eq30){'#BCC5D3'}elseif($bodyCode-eq31){'#E5B92B'}else{'#F07FB0'}}
  $antennaGroupCode=Get-Rpg2Int '--antenna'
  $skinCode=Get-Rpg2Int '--face-image';$hairCode=Get-Rpg2Int '--hair-color';$skinHex=if($skinCode-lt6){$skinPalette[$skinCode]}else{$hairPalette[[Math]::Min(($skinCode-6),$hairPalette.Count-1)]}
  New-DenpaTwoDPreviewPng -OutputPath $OutputPath -Transparent:$Transparent -HeadCode (Get-Rpg2PreviewPartCode '--head-shape') -OutlineCode (Get-Rpg2PreviewPartCode '--face-shape') -HairCode (Get-Rpg2PreviewPartCode '--hair') -BrowCode (Get-Rpg2PreviewPartCode '--eyebrow') -EyeCode (Get-Rpg2PreviewPartCode '--eyes') -NoseCode (Get-Rpg2PreviewPartCode '--nose') -MouthCode (Get-Rpg2PreviewPartCode '--mouth') -CheekCode (Get-Rpg2PreviewPartCode '--cheeks') -GlassesCode (Get-Rpg2PreviewPartCode '--glasses') -AntennaCode (Get-DenpaTwoDPreviewPartCode $boxes['--antenna'] $antennaGroupCode) -BodyHex $bodyHex -SecondaryBodyHex $bodySecondaryHex -SkinHex $skinHex -HairHex ($hairPalette[[Math]::Min($hairCode,15)]) -ArtHairColorCode ([Math]::Min($hairCode,12))
}
$script:rpg2ModelRendering = $false
$script:rpg2ModelPending = $false
function Update-Rpg2ModelPreview {
  if($script:rpg2ModelRendering){$script:rpg2ModelPending=$true;return}
  $script:rpg2ModelRendering=$true
  $modelPath=Join-Path ([IO.Path]::GetTempPath()) ('denpa2-live-'+[Guid]::NewGuid().ToString('N')+'.png')
  try {
    [void](New-Rpg2ModelPng $modelPath -IncludeEquipment -Transparent)
    if((Get-Item -LiteralPath $modelPath).Length -le 0){throw 'レンダラーが空の画像を返しました。'}
    $source=[Drawing.Image]::FromFile($modelPath)
    try{$image=New-Object Drawing.Bitmap($source)}finally{$source.Dispose()}
    if($facePreview.Image){$old=$facePreview.Image;$facePreview.Image=$null;$old.Dispose()}
    $facePreview.Image=$image
    $facePreviewLabel.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Preview'}else{'プレビュー'})
  } catch {
    $status.Text='プレビューエラー: '+$_.Exception.Message
    $facePreviewLabel.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Preview'}else{'プレビュー'})
  } finally {
    if(Test-Path -LiteralPath $modelPath){Remove-Item -LiteralPath $modelPath -Force}
    $script:rpg2ModelRendering=$false
    if($script:rpg2ModelPending){$script:rpg2ModelPending=$false;$facePreviewTimer.Stop();$facePreviewTimer.Start()}
  }
}

$markDirty = {
  if($script:editorLanguageUpdating){return}
  $saveButton.Enabled = $false
  $cardButton.Enabled = $false
  $status.Text = '変更をQRへ反映しています…'
  if($form.Visible-or$env:DENPA2_QR_EDITOR_SMOKE){$autoQrTimer.Stop();$autoQrTimer.Start()}
}
$qrDate.Add_ValueChanged({
  if($modeBox.SelectedIndex-eq1-and-not$qrDate.Checked){$qrDate.Checked=$true}
  if($null-eq$script:rpg2OfficialTemplateDate){$script:rpg2ManualSpecialDate=$qrDate.Value.Date}
  &$markDirty
})
foreach ($field in $fields) {
  if ($field.Name) { $boxes[$field.Key].Add_TextChanged($markDirty) }
  else { $boxes[$field.Key].Add_SelectedIndexChanged($markDirty) }
}
foreach($language in @('EU','NA','DEU','FRA')){$nameLanguage.Boxes[$language].Add_TextChanged($markDirty)}
foreach($language in @('EU','DEU','FRA')){$nameLanguage.Checks[$language].Add_CheckedChanged($markDirty)}
if($antennaCatalog){
  $appearanceByAbility=@{};foreach($appearance in $antennaCatalog.appearances){foreach($ability in $appearance.abilities){if(-not$appearanceByAbility.ContainsKey($ability)){$appearanceByAbility[$ability]=$appearance.code}}}
  $syncAntenna={ $ability=Get-Code $boxes['--antenna'];$appearance=if($appearanceByAbility.ContainsKey($ability)){$appearanceByAbility[$ability]}else{'00'};$idx=[Array]::IndexOf([object[]]$codesByKey['--antenna-appearance'],[object]$appearance);if($idx-ge0){$boxes['--antenna-appearance'].SelectedIndex=$idx} }
  $boxes['--antenna'].Add_SelectedIndexChanged($syncAntenna);&$syncAntenna
}
$facePreviewTimer=New-Object Windows.Forms.Timer;$facePreviewTimer.Interval=320;$facePreviewTimer.Add_Tick({$facePreviewTimer.Stop();$facePreviewTimer.Interval=320;Update-Rpg2ModelPreview})
$scheduleModelPreview={if(-not$script:editorLanguageUpdating-and($form.Visible-or$env:DENPA2_QR_EDITOR_SMOKE)){$facePreviewTimer.Stop();$facePreviewTimer.Start()}}
foreach ($key in @('--head-shape','--face-shape','--hair','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses','--face-image','--hair-color','--body-color','--stature','--antenna')) { $boxes[$key].Add_SelectedIndexChanged($scheduleModelPreview) }
if($env:DENPA2_QR_EDITOR_SMOKE){Update-Rpg2ModelPreview}elseif($env:DENPA_EDITOR_EMBED-ne'1'){$form.Add_Shown({$facePreviewTimer.Stop();$facePreviewTimer.Interval=50;$facePreviewTimer.Start()})}
$neckBox.Add_SelectedIndexChanged($markDirty)
$armBox.Add_SelectedIndexChanged($markDirty)
$backBox.Add_SelectedIndexChanged($markDirty)
$clothingBox.Add_SelectedIndexChanged($markDirty)
$feetBox.Add_SelectedIndexChanged($markDirty)
$rpg2PaintBox.Add_SelectedIndexChanged($markDirty)
$claimSlotBox.Add_SelectedIndexChanged($markDirty)
# 装備はQR／カードの文字情報だけを更新し、配布版の2D絵には反映しない。
# CheckedChanged also fires while controls are reparented and while the previous
# region is unchecked. Only a completed user click should schedule regeneration.
foreach($radio in $regionButtons.Values){$radio.Add_Click({if($this.Checked){&$markDirty}})}
$modeBox.Add_SelectedIndexChanged({
  Update-Rpg2ModeControls
  &$scheduleModelPreview
  & $markDirty
})
Update-Rpg2ModeControls
$script:rpg2DisplayOnClick = [Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance')
$autoQrTimer.Add_Tick({
  $autoQrTimer.Stop()
  if(-not $script:rpg2Generating){
    # PerformClick intentionally ignores an invisible button.  The old QR
    # button is kept only as the generation command, so invoke its click event
    # directly for reliable live updating.
    [void]$script:rpg2DisplayOnClick.Invoke($displayButton,@([EventArgs]::Empty))
  }
})

$displayButton.Add_Click({
  if($script:rpg2Generating){return};$script:rpg2Generating=$true
  try {
    Assert-DenpaNonoGuard ([Convert]::ToInt32((Get-Code $boxes['--hair']),16)) ([Convert]::ToInt32((Get-Code $boxes['--eyes']),16))
    Assert-Rpg2TowerCombination
    $tempPath = Join-Path ([IO.Path]::GetTempPath()) ('Denpa2QR-' + [Guid]::NewGuid().ToString('N') + '.png')
    $selectedRegion=if($script:rpg2CardRegionOverride){[string]$script:rpg2CardRegionOverride}else{($regionButtons.GetEnumerator()|Where-Object{$_.Value.Checked}|Select-Object -First 1).Key};if(-not$selectedRegion){$selectedRegion='JP'}
    $isSpecial = ($modeBox.SelectedIndex -eq 1)
    $selectedCarrier = if($isSpecial){$specialCarrier}else{$normalCarrier}
    $args = @($editorTool, 'edit', '--carrier', $selectedCarrier, '--png', $tempPath)
    $activeName=Get-DenpaNameForRegion $nameLanguage $selectedRegion
    if ([string]::IsNullOrWhiteSpace($activeName)) {
      $saveButton.Enabled=$false;$cardButton.Enabled=$false;$status.Text='名前を入力するとQRを自動更新します。';return
    }
    $args += @('--name', $activeName)
    # 実在NA版では識別乱数が00/F0/FFを含むため、地域判定には使わない。
    # 地域はRPG2平文ヘッダーの二重フィールドで指定する。
    $args+=@('--region',$selectedRegion)
    if($isSpecial){$args+=@('--identity-byte',('{0:X2}'-f(Get-Random -Minimum 0 -Maximum 256)))}
    foreach ($field in $fields | Where-Object { -not $_.Name -and -not $_.UiOnly }) { $args += @($field.Key, (Get-Code $boxes[$field.Key])) }
    if ($isSpecial) {
      $neckId = if($neckBox.SelectedIndex-eq0){0}else{383 + $neckBox.SelectedIndex}
      $armCode = $armEquipmentCodes[$armBox.SelectedIndex]
      $backCode = $backEquipmentCodes[$backBox.SelectedIndex]
      $clothingCode = $clothingCodes[$clothingBox.SelectedIndex]
      $feetCode = $feetEquipmentCodes[$feetBox.SelectedIndex]
      $claimId = Get-Rpg2EquipmentClaimId $neckId $armCode $backCode $feetCode $clothingCode
      $args += @(
        '--official-claim-id', ('{0:X4}' -f $claimId),
        '--official-neck-equipment', ('{0:X4}' -f $neckId),
        '--official-arm-equipment', $armCode,
        '--official-back-equipment', $backCode,
        '--official-clothing', $clothingCode,
        '--official-feet-equipment', $feetCode
      )
      $args += @('--official-special-region',$selectedRegion)
    }
    if($modeBox.SelectedIndex-eq1-or$qrDate.Checked-or$null-ne$script:rpg2OfficialTemplateDate){$args+=@('--qr-date',$qrDate.Value.ToString('yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture))}
    $ability=Get-DenpaCallLabSelection;if($ability-ge0){$args+=@('--rpg3-ability',$ability.ToString('X2'))}
    $args+=@(Get-DenpaAdvancedQrArguments 2)
    $args+=@('--memo',[string]$rpg2MemoBox.Text)
    $args+=@('--paint-color',$(if($rpg2PaintBox.SelectedIndex-le0){'FF'}else{'{0:X2}'-f($rpg2PaintBox.SelectedIndex-1)}))
    $script:lastGenerateArguments = @($args)
    $output = Invoke-DenpaQrBackend -Game 2 -Arguments ([string[]]$args)
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tempPath)) { throw ($output -join "`r`n") }
    if ($preview.Image) { $old = $preview.Image; $preview.Image = $null; $old.Dispose() }
    $bytes = [IO.File]::ReadAllBytes($tempPath)
    $stream = New-Object IO.MemoryStream(,$bytes)
    try {
      $loaded = [Drawing.Image]::FromStream($stream)
      try { $preview.Image = New-Object Drawing.Bitmap($loaded) } finally { $loaded.Dispose() }
    } finally { $stream.Dispose() }
    if ($script:currentQrPath -and (Test-Path -LiteralPath $script:currentQrPath)) { Remove-Item -LiteralPath $script:currentQrPath -Force }
    $script:currentQrPath = $tempPath
    $saveButton.Enabled = $true
    $cardButton.Enabled = $true
    $kind=if($isSpecial){'特典QR'}else{'通常QR'}
    $status.Text = "$selectedRegion $kind を自動更新しました。"
  } catch {
    $script:rpg2LastError = $_.Exception.Message
    if($script:rpg2LastError-match 'ENOSPC|no space left on device'){$script:rpg2LastError='保存先ドライブの空き容量が不足しているため、QR用の一時画像を書き込めませんでした。不要なファイルを整理してから再試行してください。'}
    $status.Text = 'QR生成エラー: ' + $script:rpg2LastError
    if ($env:DENPA_EDITOR_EMBED -ne '1') {
      [Windows.Forms.MessageBox]::Show($script:rpg2LastError, '生成エラー', 'OK', 'Error') | Out-Null
    }
  } finally {$script:rpg2Generating=$false}
})

$saveButton.Add_Click({
  if (-not $script:currentQrPath -or -not (Test-Path -LiteralPath $script:currentQrPath)) { return }
  $dialog = New-Object Windows.Forms.SaveFileDialog
  $dialog.Filter = 'PNG画像 (*.png)|*.png'
  $dialog.FileName = 'RPG2_QR.png'
  if ($dialog.ShowDialog() -eq 'OK') {
    Copy-Item -LiteralPath $script:currentQrPath -Destination $dialog.FileName -Force
    $status.Text = "保存しました: $($dialog.FileName)"
  }
})

function Get-Rpg2CardEquipmentNames {
  $result=@{};$state=Get-DenpaAdvancedQrState
  foreach($slot in @(@('Neck',$neckBox,$neckEquipmentCodes),@('Arm',$armBox,$armEquipmentCodes),@('Back',$backBox,$backEquipmentCodes),@('Feet',$feetBox,$feetEquipmentCodes),@('Clothing',$clothingBox,$clothingCodes))){
    $index=$slot[1].SelectedIndex
    if($modeBox.SelectedIndex-eq0){
      $code=if($state.Equipment-and$state.Equipment.ContainsKey($slot[0].ToLowerInvariant())){$state.Equipment[$slot[0].ToLowerInvariant()]}else{'0000'}
      $index=[Array]::IndexOf([object[]]$slot[2],[object][string]$code);if($index-lt0){$index=0}
    }
    $result[$slot[0]]=[string]$slot[1].Items[$index]
  }
  $result
}
$cardButton.Add_Click({
  $cardTemp=$null
  try{
    if(-not(Get-Command New-Rpg2CardBitmap -ErrorAction SilentlyContinue)){throw 'カード描画部品が見つかりません。'}
    if(-not$script:currentQrPath-or-not(Test-Path $script:currentQrPath)){throw 'QRの自動生成が完了していません。'}
    $cardTemp=Join-Path([IO.Path]::GetTempPath())('denpa2-card-'+[Guid]::NewGuid().ToString('N'));[void](New-Item -ItemType Directory -Path $cardTemp)
    $modelPath=Join-Path $cardTemp 'model.png';[void](New-Rpg2ModelPng $modelPath -IncludeEquipment -Transparent)
    $invoke=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance');$qrPaths=@{}
    $autoQrTimer.Stop()
    foreach($region in @('JP','NA','EU')){$script:rpg2CardRegionOverride=$region;[void]$invoke.Invoke($displayButton,@([EventArgs]::Empty));$path=Join-Path $cardTemp ($region+'.png');Copy-Item -LiteralPath $script:currentQrPath -Destination $path -Force;$qrPaths[$region]=$path}
    $script:rpg2CardRegionOverride=$null;[void]$invoke.Invoke($displayButton,@([EventArgs]::Empty))
    $specialIdText=if($modeBox.SelectedIndex-eq1){(Get-Rpg2ClaimSlot).ToString()}else{''}
    $equipmentNames=Get-Rpg2CardEquipmentNames
    $card=New-Rpg2CardBitmap -AssetRoot $assetRoot -ModelPath $modelPath -QrPaths $qrPaths -Name (Get-DenpaCardDisplayName $nameLanguage) -Personality $boxes['--personality'].Text -Stature $boxes['--stature'].Text -Antenna $boxes['--antenna'].Text -SpecialId $specialIdText -Neck $equipmentNames.Neck -Arm $equipmentNames.Arm -Back $equipmentNames.Back -Feet $equipmentNames.Feet -Clothing $equipmentNames.Clothing -Correction (Get-DenpaCallLabCardText)
    $workingArea=[Windows.Forms.Screen]::FromControl($form).WorkingArea;$cardWindowWidth=[Math]::Min(900,[Math]::Max(620,$workingArea.Width-120));$cardWindowHeight=[Math]::Min(680,[Math]::Max(500,$workingArea.Height-120))
    $window=New-Object Windows.Forms.Form;$window.Icon=$form.Icon;$window.Text='RPG2 カードプレビュー';$window.ClientSize=New-Object Drawing.Size($cardWindowWidth,$cardWindowHeight);$window.MinimumSize=New-Object Drawing.Size(620,500);$window.StartPosition='CenterParent'
    $buttonPanel=New-Object Windows.Forms.Panel;$buttonPanel.Dock='Bottom';$buttonPanel.Height=52;$window.Controls.Add($buttonPanel)
    $picture=New-Object Windows.Forms.PictureBox;$picture.Dock='Fill';$picture.Padding=New-Object Windows.Forms.Padding(10);$picture.SizeMode='Zoom';$picture.Image=$card;$window.Controls.Add($picture);$picture.BringToFront();$buttonPanel.BringToFront()
    $saveCard=New-Object Windows.Forms.Button;$saveCard.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Save PNG'}else{'カードをPNG保存'});$saveCard.Location=New-Object Drawing.Point(365,9);$saveCard.Size=New-Object Drawing.Size(170,34);$buttonPanel.Controls.Add($saveCard);$buttonPanel.Add_Resize({$saveCard.Left=[Math]::Max(0,[int](($buttonPanel.ClientSize.Width-$saveCard.Width)/2))})
    $saveCard.Add_Click({$dialog=New-Object Windows.Forms.SaveFileDialog;$dialog.Filter='PNG画像 (*.png)|*.png';$dialog.FileName=($nameBox.Text+'_RPG2カード.png');if($dialog.ShowDialog()-eq'OK'){$picture.Image.Save($dialog.FileName,[Drawing.Imaging.ImageFormat]::Png);$status.Text="カードを保存しました: $($dialog.FileName)"}})
    [void]$window.ShowDialog($form);if($picture.Image){$picture.Image.Dispose()};$window.Dispose()
  }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'カード生成エラー','OK','Error')|Out-Null}
  finally{$script:rpg2CardRegionOverride=$null;$autoQrTimer.Stop();if($cardTemp-and(Test-Path -LiteralPath $cardTemp)){Remove-Item -LiteralPath $cardTemp -Recurse -Force -ErrorAction SilentlyContinue}}
})

function Apply-UnifiedRpg2Layout {
  $form.BackColor=[Drawing.Color]::FromArgb(214,235,251)
  $title.Visible=$false;$sub.Visible=$false;$regionGroup.Visible=$false
  foreach($panelSpec in @(@(20,4,320,625),@(362,4,285,625),@(666,4,585,89),@(666,103,585,361),@(666,480,585,190))){
    $panel=New-Object Windows.Forms.Panel;$panel.Location=New-Object Drawing.Point($panelSpec[0],$panelSpec[1]);$panel.Size=New-Object Drawing.Size($panelSpec[2],$panelSpec[3]);$panel.BackColor=[Drawing.Color]::FromArgb(178,255,255,255);$panel.BorderStyle='FixedSingle';$form.Controls.Add($panel);$panel.SendToBack();$panel.Visible=$false
  }
  foreach($control in @($form.Controls)){if(-not($control -is [Windows.Forms.Panel])){$control.BringToFront()}}
  $commonCaption=New-Object Windows.Forms.Label;$commonCaption.Text='顔パーツ';$commonCaption.Font=New-Object Drawing.Font('Yu Gothic UI',11,[Drawing.FontStyle]::Bold);$commonCaption.AutoSize=$true;$commonCaption.Location=New-Object Drawing.Point(42,17);$form.Controls.Add($commonCaption)
  $qrCaption=New-Object Windows.Forms.Label;$qrCaption.Text='QRコード';$qrCaption.Font=New-Object Drawing.Font('Yu Gothic UI',11,[Drawing.FontStyle]::Bold);$qrCaption.AutoSize=$true;$qrCaption.Location=New-Object Drawing.Point(690,76);$form.Controls.Add($qrCaption)
  $leftKeys=@('--antenna','--head-shape','--hair','--face-shape','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses','--stature','--body-color','--face-image','--hair-color')
  for($i=0;$i-lt$leftKeys.Count;$i++){$key=$leftKeys[$i];$box=$boxes[$key];$label=$form.Controls.Find('label_'+$key,$true)[0];$y = 47 + ($i * 36);$label.Location=New-Object Drawing.Point(40,($y + 4));$box.Location=New-Object Drawing.Point(145,$y);$box.Size=New-Object Drawing.Size(170,27)}
  $faceTemplateLabel.Location=New-Object Drawing.Point(40,555);$faceTemplateBox.Location=New-Object Drawing.Point(145,551);$faceTemplateBox.Size=New-Object Drawing.Size(170,27);$towerCombinationCheck.Location=New-Object Drawing.Point(40,582);$faceSyncCheck.Location=New-Object Drawing.Point(40,606);$definedFaceCheck.Location=New-Object Drawing.Point(40,630)
  $boxes['--antenna-appearance'].Visible=$false;$form.Controls.Find('label_--antenna-appearance',$true)[0].Visible=$false
  $nameLabel=$form.Controls.Find('label_--name',$true)[0];$nameLabel.Text='名前';$nameLabel.Visible=$true;$nameLabel.Font=New-Object Drawing.Font('Yu Gothic UI',11,[Drawing.FontStyle]::Bold);$nameLabel.Location=New-Object Drawing.Point(690,17)
  $freeNameCheck.Visible=$false
  $personalityLabel=$form.Controls.Find('label_--personality',$true)[0];Set-DenpaNameLanguageLayout $nameLanguage $personalityLabel $boxes['--personality']
  $facePreviewLabel.Text='プレビュー';$facePreviewLabel.Location=New-Object Drawing.Point(385,17);$facePreview.Location=New-Object Drawing.Point(388,38);$facePreview.Size=New-Object Drawing.Size(233,300);$discordLink.Location=New-Object Drawing.Point(388,640)
  foreach($entry in @(@('JP',856),@('NA',947),@('EU',1038))){$radio=$regionButtons[$entry[0]];$regionGroup.Controls.Remove($radio);$form.Controls.Add($radio);$radio.Location=New-Object Drawing.Point($entry[1],111)}
  $qrCaption.Location=New-Object Drawing.Point(690,111);$preview.Location=New-Object Drawing.Point(803,143);$preview.Size=New-Object Drawing.Size(310,300)
  $displayButton.Visible=$false;$saveButton.Location=New-Object Drawing.Point(1124,218);$saveButton.Size=New-Object Drawing.Size(105,48);$cardButton.Text='カード表示';$cardButton.Location=New-Object Drawing.Point(1124,282);$cardButton.Size=New-Object Drawing.Size(105,48);$status.Visible=$false
  $modeLabel.Text='特典';$modeLabel.Location=New-Object Drawing.Point(689,478);$modeLabel.Font=New-Object Drawing.Font('Yu Gothic UI',11,[Drawing.FontStyle]::Bold);$modeBox.Location=New-Object Drawing.Point(809,471);$modeBox.Size=New-Object Drawing.Size(140,27)
  $claimSlotLabel.Text='特典ID';$claimSlotLabel.Location=New-Object Drawing.Point(955,478);$claimSlotBox.Location=New-Object Drawing.Point(1040,471);$claimSlotBox.Size=New-Object Drawing.Size(140,27);$claimSlotHint.Location=New-Object Drawing.Point(1190,478)
  foreach($entry in @(@($neckLabel,$neckBox,686,525),@($armLabel,$armBox,876,525),@($backLabel,$backBox,1066,525),@($feetLabel,$feetBox,781,578),@($clothingLabel,$clothingBox,971,578))){$entry[0].Location=New-Object Drawing.Point($entry[2],$entry[3]);$entry[1].Location=New-Object Drawing.Point($entry[2],([int]$entry[3] + 19));$entry[1].Size=New-Object Drawing.Size(170,27)}
  $qrDateLabel.Location=New-Object Drawing.Point(970,635);$qrDate.Location=New-Object Drawing.Point(1070,629);$qrDate.Size=New-Object Drawing.Size(160,27)
  $rpg2PaintLabel.Location=New-Object Drawing.Point(686,626)
  $rpg2PaintBox.Location=New-Object Drawing.Point(686,653);$rpg2PaintBox.Size=New-Object Drawing.Size(260,27)
}
if($env:DENPA_EDITOR_EMBED-eq'1'){Apply-UnifiedRpg2Layout}
$script:nonoSelectionGuard=Register-DenpaNonoSelectionGuard $boxes {[Convert]::ToInt32((Get-Code $boxes['--hair']),16);[Convert]::ToInt32((Get-Code $boxes['--eyes']),16)}
. (Join-Path $PSScriptRoot 'DenpaCallLab.ps1')
New-DenpaCallLab 2

# The imported RPG2 record stores 16 UTF-16 code units at QR 0x10..0x2F.
$rpg2MemoLabel=New-Object Windows.Forms.Label
$rpg2MemoLabel.Name='rpg2MemoLabel';$rpg2MemoLabel.Text='メモ';$rpg2MemoLabel.Size=New-Object Drawing.Size(233,23)
$rpg2MemoLabel.Location=New-Object Drawing.Point($script:callLab.Target.Left,($script:callLab.Target.Bottom+10))
$form.Controls.Add($rpg2MemoLabel)
$rpg2MemoBox=New-Object Windows.Forms.TextBox
$rpg2MemoBox.Name='rpg2Memo';$rpg2MemoBox.MaxLength=16;$rpg2MemoBox.Size=New-Object Drawing.Size($script:callLab.Target.Width,27)
$rpg2MemoBox.Location=New-Object Drawing.Point($rpg2MemoLabel.Left,($rpg2MemoLabel.Bottom+2))
$rpg2MemoBox.Add_TextChanged($markDirty);$form.Controls.Add($rpg2MemoBox)
$rpg2PaintLabel.Location=New-Object Drawing.Point($rpg2MemoBox.Left,($rpg2MemoBox.Bottom+10))
$rpg2PaintBox.Location=New-Object Drawing.Point($rpg2MemoBox.Left,($rpg2PaintLabel.Bottom+4))
$rpg2PaintBox.Width=$rpg2MemoBox.Width

$form.Add_FormClosed({
  $autoQrTimer.Stop();$autoQrTimer.Dispose();$facePreviewTimer.Stop();$facePreviewTimer.Dispose()
  if ($preview.Image) { $preview.Image.Dispose() }
  if ($facePreview.Image) { $facePreview.Image.Dispose() }
  if ($script:currentQrPath -and (Test-Path -LiteralPath $script:currentQrPath)) { Remove-Item -LiteralPath $script:currentQrPath -Force }
})
if($env:DENPA_EDITOR_EMBED-ne'1'){$form.Add_Shown({$autoQrTimer.Stop();$autoQrTimer.Start()})}

if($env:DENPA2_QR_EDITOR_SMOKE-eq'2d-preview'){
  $previewRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\previews'));[IO.Directory]::CreateDirectory($previewRoot)|Out-Null
  $modeBox.SelectedIndex=1
  $before=Join-Path $previewRoot 'RPG2-2d-equipment-none.png';[void](New-Rpg2ModelPng $before -IncludeEquipment)
  foreach($equipmentBox in @($neckBox,$armBox,$backBox,$clothingBox,$feetBox)){if($equipmentBox.Items.Count-gt1){$equipmentBox.SelectedIndex=1}}
  $after=Join-Path $previewRoot 'RPG2-2d-equipment-selected.png';[void](New-Rpg2ModelPng $after -IncludeEquipment)
  if((Get-FileHash $before -Algorithm SHA256).Hash-ne(Get-FileHash $after -Algorithm SHA256).Hash){throw 'RPG2 distribution preview must ignore equipment artwork.'}
  $boxes['--antenna'].SelectedIndex=[Array]::IndexOf([object[]]$codesByKey['--antenna'],[object]'2C')
  $antenna=Join-Path $previewRoot 'RPG2-2d-fireball.png';[void](New-Rpg2ModelPng $antenna)
  if((Get-FileHash $before -Algorithm SHA256).Hash-eq(Get-FileHash $antenna -Algorithm SHA256).Hash){throw 'RPG2 2D antenna was not composited.'}
  Write-Output("GUI_RPG2_2D_PREVIEW_EQUIPMENT_IGNORED_OK image="+$antenna);$form.Dispose();return
}
if($env:DENPA2_QR_EDITOR_SMOKE-eq'tower-filter'){
  foreach($entry in @{'--face-shape'='00';'--head-shape'='00';'--eyes'='00';'--nose'='00';'--mouth'='00';'--cheeks'='00';'--eyebrow'='00';'--glasses'='00';'--hair'='00';'--hair-color'='00';'--stature'='00';'--body-color'='00'}.GetEnumerator()){Set-Rpg2TemplateCode $entry.Key $entry.Value};$towerCombinationCheck.Checked=$true;if($script:rpg2TowerCandidates.Rows.Count-eq0){throw 'RPG2 none-cheek/none-glasses regular combination failed.'};$towerCombinationCheck.Checked=$false
  foreach($entry in @{'--face-shape'='00';'--head-shape'='1E';'--eyes'='00';'--nose'='00';'--mouth'='00';'--cheeks'='00';'--eyebrow'='0C';'--glasses'='02';'--hair'='00';'--hair-color'='00';'--stature'='00';'--body-color'='00'}.GetEnumerator()){Set-Rpg2TemplateCode $entry.Key $entry.Value}
  $towerCombinationCheck.Checked=$true
  if(-not$faceSyncCheck.Checked-or-not$definedFaceCheck.Checked-or$towerCombinationCheck.Text-ne'正規候補に絞る'-or$towerCombinationCheck.Top-ge$faceSyncCheck.Top-or$script:rpg2TowerCandidates.Rows.Count-ne1-or[int]$script:rpg2TowerCandidates.Rows[0]-ne0-or$nameBox.Items.Count-ge$rpg2AllNames.Count-or$boxes['--personality'].Items.Count-ne1-or$boxes['--personality'].Text-ne'にがうり'){throw 'RPG2 regular-candidate filtering failed.'}
  Set-Rpg2TemplateCode '--head-shape' '01';if((Get-Code $boxes['--head-shape'])-ne'01'-or(Get-Code $boxes['--glasses'])-ne'02'){throw 'RPG2 regular-candidate filter changed prioritized face parts.'};Set-Rpg2TemplateCode '--head-shape' '1E'
  Assert-Rpg2TowerCombination
  $nameBox.Text='正規候補外テスト';$failed=$false;try{Assert-Rpg2TowerCombination}catch{$failed=$true};if(-not$failed){throw 'RPG2 antenna-tower generation validation failed.'}
  $towerCombinationCheck.Checked=$false
  if($nameBox.Items.Count-ne1917-or$boxes['--personality'].Items.Count-ne12){throw 'RPG2 antenna-tower free-selection restore failed.'}
  Write-Output 'GUI_RPG2_REGULAR_CANDIDATE_FILTER_OK row=0 personality=にがうり';$form.Dispose();return
}

if($env:DENPA2_QR_EDITOR_SMOKE-eq'regional-long-names'){
  $nameLanguage.IndividualCheck.Checked=$true
  $testCount=0
  foreach($mode in @(0,1)){
    $modeBox.SelectedIndex=$mode
    foreach($region in @('NA','EU')){
      $regionButtons[$region].Checked=$true
      foreach($longName in @('Kingston','Kingsley','Jamarion','Christopher')){
        $nameLanguage.Syncing=$true
        try{$nameLanguage.Boxes[$region].Text=$longName}finally{$nameLanguage.Syncing=$false}
        $autoQrTimer.Stop()
        [void]$script:rpg2DisplayOnClick.Invoke($displayButton,@([EventArgs]::Empty))
        $nameAt=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--name')
        if(-not$saveButton.Enabled-or$nameAt-lt0-or$script:lastGenerateArguments[$nameAt+1]-ne$longName-or-not(Test-Path -LiteralPath $script:currentQrPath)){throw "RPG2 overseas GUI name failed: $region $longName mode=$mode"}
        $testCount++
      }
    }
  }
  Write-Output "GUI_RPG2_OVERSEAS_LONG_NAMES_OK $testCount normal/special cases";$form.Dispose();return
}

if($env:DENPA2_QR_EDITOR_SMOKE-eq'region-click'){
  $radioClick=[Windows.Forms.RadioButton].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance')
  foreach($region in @('NA','EU','JP')){
    $regionButtons[$region].Checked=$true;[void]$radioClick.Invoke($regionButtons[$region],@([EventArgs]::Empty))
    $deadline=[DateTime]::UtcNow.AddSeconds(8);while(($autoQrTimer.Enabled-or$script:rpg2Generating)-and[DateTime]::UtcNow-lt$deadline){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 20}
    if(-not$regionButtons[$region].Checked-or$autoQrTimer.Enabled-or$script:rpg2Generating-or-not$saveButton.Enabled){throw "RPG2 region click failed: $region"}
  }
  Write-Output 'GUI_RPG2_REGION_CLICK_JP_NA_EU_OK';$form.Dispose();return
}

if($env:DENPA2_QR_EDITOR_SMOKE-eq'card'){
  $modeBox.SelectedIndex=1;$neckBox.SelectedIndex=25;$armBox.SelectedIndex=1;$backBox.SelectedIndex=1;$feetBox.SelectedIndex=1;$clothingBox.SelectedIndex=1;$autoQrTimer.Stop()
  $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance');$tempRoot=Join-Path([IO.Path]::GetTempPath())('denpa2-card-smoke-'+[Guid]::NewGuid().ToString('N'));[void](New-Item -ItemType Directory -Path $tempRoot);$qrPaths=@{};$originalRegion=($regionButtons.GetEnumerator()|Where-Object{$_.Value.Checked}|Select-Object -First 1).Key
  foreach($region in @('JP','NA','EU')){$script:rpg2CardRegionOverride=$region;[void]$click.Invoke($displayButton,@([EventArgs]::Empty));$target=Join-Path $tempRoot ($region+'.png');Copy-Item $script:currentQrPath $target;$qrPaths[$region]=$target};$script:rpg2CardRegionOverride=$null;if(-not$regionButtons[$originalRegion].Checked){throw 'RPG2 card generation changed the visible region selection.'}
  $model=Join-Path $tempRoot 'model.png';[void](New-Rpg2ModelPng $model -IncludeEquipment -Transparent);$card=New-Rpg2CardBitmap -AssetRoot $assetRoot -ModelPath $model -QrPaths $qrPaths -Name (Get-DenpaCardDisplayName $nameLanguage) -Personality $boxes['--personality'].Text -Stature $boxes['--stature'].Text -Antenna $boxes['--antenna'].Text -SpecialId (Get-Rpg2ClaimSlot).ToString() -Neck $neckBox.Text -Arm $armBox.Text -Back $backBox.Text -Feet $feetBox.Text -Clothing $clothingBox.Text;$output=Join-Path $tempRoot 'card.png';$card.Save($output,[Drawing.Imaging.ImageFormat]::Png);$card.Dispose();if(!(Test-Path $output)-or(Get-Item $output).Length-lt100000){throw'RPG2 card render smoke failed.'};Write-Output("GUI_RPG2_AUTO_REGION_CARD_OK "+$output);$form.Dispose();return
}

if($env:DENPA2_QR_EDITOR_SMOKE-eq'hair-contour'){
  if($faceSyncCheck.Text-ne'髪と輪郭を同期する'-or-not$faceSyncCheck.Checked){throw 'RPG2 hair/contour wording failed.'}
  if($boxes['--hair'].Top-ge$boxes['--face-shape'].Top){throw 'RPG2 hair must be displayed above contour.'}
  $boxes['--face-shape'].SelectedIndex=8;$boxes['--hair'].SelectedIndex=3
  if($boxes['--hair'].SelectedIndex-ne3-or(Get-Code $boxes['--face-shape'])-ne'04'-or$boxes['--face-shape'].Enabled){throw 'RPG2 hair-primary contour synchronization failed.'}
  $boxes['--hair'].SelectedIndex=28;if((Get-Code $boxes['--face-shape'])-ne'01'-or$boxes['--face-shape'].Enabled){throw 'RPG2 hair 28 / contour 1 synchronization failed.'}
  $faceSyncCheck.Checked=$false
  if(-not$boxes['--face-shape'].Enabled){throw 'RPG2 free hair/contour combination failed.'}
  Write-Output 'GUI_RPG2_HAIR_PRIMARY_CONTOUR_SYNC_OK';$form.Dispose();return
}

if ($env:DENPA2_QR_EDITOR_SMOKE -eq '1') {
  if(-not($claimSlotBox-is[Windows.Forms.ComboBox])-or$claimSlotBox.Items.Count-ne256-or$rpg2ClaimSlotValues[$claimSlotBox.Items.IndexOf('310（やまな）')]-ne310){throw 'RPG2 benefit ID dropdown/official labels failed.'}
  if($legitimateNames.Count-ne1917-or$legitimateNames[0]-ne'たくむ'-or$legitimateNames[1000]-ne'あい'-or$legitimateNames[-1]-ne'わこ'){throw 'RPG2 independent name catalog failed.'}
  if($regionButtons.Count-ne3-or-not$regionButtons['JP'].Checked-or$displayButton.Visible-or$saveButton.Location.X-ne20-or$cardButton.Location.X-ne180){throw 'RPG2 instant QR / region radio / save button layout failed.'}
  if(-not(Get-Command New-Rpg2CardBitmap -ErrorAction SilentlyContinue)){throw 'RPG2 card module failed to load.'}
  if ($legitimateNames.Count -ne 1917 -or $nameBox.Text -ne 'つかさ') { throw 'RPG2 shared legitimate-name catalog failed.' }
  $nameBox.Text='自由名テスト';if($nameBox.Text-ne'自由名テスト'-or$nameBox.DropDownStyle-ne'DropDown'){throw 'RPG2 free-name mode failed.'}
  if($freeNameCheck.Visible-or$faceTemplateBox.Items.Count-ne9-or$faceTemplateBox.Items[1]-ne'ショウたろう(公式)'-or$faceTemplateBox.Items[4]-ne'やまな(公式)'-or$faceTemplateBox.Items[5]-ne'しろがねまる(公式)'-or$faceTemplateBox.Items[6]-ne'つきよ(公式)'-or$faceTemplateBox.Items[7]-ne'こがねまる(公式)'-or$faceTemplateBox.Items[8]-ne'ゆかり'){throw 'RPG2 independent official face-template/name UI failed.'}
  $faceTemplateBox.SelectedIndex=4
  if($nameBox.Text-ne'やまな'-or$modeBox.SelectedIndex-ne1-or(Get-Rpg2ClaimSlot)-ne310-or$neckBox.SelectedIndex-ne26-or$armEquipmentCodes[$armBox.SelectedIndex]-ne'0200'-or$clothingCodes[$clothingBox.SelectedIndex]-ne'0677'-or-not$script:rpg2TemplateSpecialCarrierPath.EndsWith('rpg2-special-yamana.hex')){throw 'RPG2 Yamana official special template failed.'}
  foreach($officialCheck in @(@(1,'ショウたろう',257,'2011-01-01'),@(2,'クリス',308,'2012-12-01'),@(3,'いわた',309,'2013-01-01'),@(4,'やまな',310,'2013-01-01'),@(6,'つきよ',307,'2012-10-05'))){$faceTemplateBox.SelectedIndex=[int]$officialCheck[0];if($nameBox.Text-ne$officialCheck[1]-or(Get-Rpg2ClaimSlot)-ne[int]$officialCheck[2]-or$modeBox.SelectedIndex-ne1-or$qrDate.Value.ToString('yyyy-MM-dd')-ne$officialCheck[3]-or$qrDate.Enabled-or$qrDateLabel.Text-ne'QR日付'){throw("RPG2 official template/date failed: "+$officialCheck[1])}}
  $faceTemplateBox.SelectedIndex=5;if($nameBox.Text-ne'しろがねまる'-or$modeBox.SelectedIndex-ne0-or-not$script:rpg2TemplateSpecialCarrierPath.EndsWith('rpg2-normal-shiroganemaru.hex')-or$qrDate.Value.ToString('yyyy-MM-dd')-ne'2012-10-20'-or$qrDate.Enabled){throw 'RPG2 Shiroganemaru official fixed-date template failed.'}
  $faceTemplateBox.SelectedIndex=7;if($nameBox.Text-ne'こがねまる'-or$modeBox.SelectedIndex-ne0-or-not$script:rpg2TemplateSpecialCarrierPath.EndsWith('rpg2-normal-koganemaru.hex')-or$qrDate.Value.ToString('yyyy-MM-dd')-ne'2012-11-21'-or$qrDate.Enabled-or$boxes['--body-color'].SelectedIndex-ne0x1F-or$boxes['--hair-color'].SelectedIndex-ne1){throw 'RPG2 Koganemaru official fixed-date template failed.'}
  $faceTemplateBox.SelectedIndex=8
  if($nameBox.Text-ne'ゆかり'-or$modeBox.SelectedIndex-ne0-or$boxes['--antenna'].Text-ne'アンテナなし'-or$boxes['--stature'].SelectedIndex-ne0-or$boxes['--personality'].Text-ne'トウガラシ'-or$neckBox.SelectedIndex-ne0-or$script:rpg2TemplateSpecialCarrierPath){throw 'RPG2 Yukari normal template failed.'}
  $definedFaceCheck.Checked=$false
  if($boxes['--head-shape'].Items.Count-ne40-or$boxes['--head-shape'].Items[31]-ne'たいよう'-or$boxes['--head-shape'].Items[32]-ne'うさみみ(未定義)'-or$boxes['--head-shape'].Items[39]-ne'おさかな(未定義)'){throw 'RPG2 named undefined head choices failed.'}
  if($boxes['--face-shape'].Items.Count-ne16-or$boxes['--face-shape'].Items[8]-ne'8'-or$boxes['--face-shape'].Items[9]-ne'未定義(9)'-or$boxes['--face-shape'].Items[15]-ne'未定義(15)'){throw 'RPG2 contour range failed.'}
  if($boxes['--hair'].Items.Count-ne64-or$boxes['--hair'].Items[63]-ne'未定義(63)'-or$boxes['--eyebrow'].Items.Count-ne21-or$boxes['--eyes'].Items.Count-ne49-or$boxes['--nose'].Items.Count-ne34-or$boxes['--mouth'].Items.Count-ne42-or$boxes['--cheeks'].Items.Count-ne12-or$boxes['--glasses'].Items.Count-ne26-or$boxes['--glasses'].Items[15]-ne'ハートグラス'-or$boxes['--glasses'].Items[25]-ne'未定義(25)'){throw 'RPG2 RPG3-range undefined face choices failed.'}
  if($boxes['--personality'].Items.Count-ne12-or$boxes['--personality'].Items[7]-ne'なし'-or$boxes['--personality'].Items[8]-ne'主人公'-or$boxes['--personality'].Items[11]-ne'ルナ'-or$codesByKey['--personality'][8]-ne'64'-or$codesByKey['--personality'][11]-ne'67'){throw 'RPG2 personality story mapping failed.'}
  if($boxes['--face-image'].Items.Count-ne16-or$boxes['--face-image'].Items[0]-ne'0'-or$boxes['--face-image'].Items[5]-ne'5'-or$boxes['--face-image'].Items[6]-ne'黒髪(未定義6)'-or$boxes['--face-image'].Items[15]-ne'桃髪(未定義15)'){throw 'RPG2 skin/hair overflow naming failed.'}
  if($boxes['--hair-color'].Items.Count-ne16-or$boxes['--hair-color'].Items[12]-ne'黒(未定義12)'-or$boxes['--hair-color'].Items[13]-ne'金(未定義13)'-or$boxes['--hair-color'].Items[14]-ne'青(未定義14)'-or$boxes['--hair-color'].Items[15]-ne'銀(未定義15)'){throw 'RPG2 hair-color remapping failed.'}
  if($nameLanguage.Checks.JP.Visible-or$nameLanguage.Checks.NA.Visible-or-not$nameLanguage.Checks.EU.Checked-or$nameLanguage.Checks.DEU.Checked-or$nameLanguage.Checks.FRA.Checked-or-not$nameLanguage.Checks.DEU.Enabled-or-not$nameLanguage.Checks.FRA.Enabled-or$nameLanguage.Boxes.DEU.Enabled-or$nameLanguage.Boxes.FRA.Enabled-or[string]::IsNullOrWhiteSpace($nameLanguage.Boxes.DEU.Text)-or[string]::IsNullOrWhiteSpace($nameLanguage.Boxes.FRA.Text)){throw 'RPG2 multilingual name default controls failed.'}
  if($boxes['--antenna'].Items.Count-ne85-or$boxes['--antenna'].Items[68]-ne'つかまえる(未定義68)'-or$boxes['--antenna'].Items[84]-ne'ならくのたいよう(未定義99)'){throw 'RPG2 antenna undefined slots failed.'}
  foreach($key in @('--head-shape','--face-shape','--hair','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses','--face-image','--hair-color')){
    $codes=@($codesByKey[$key]);$lastIndex=$codes.Count-1
    if([Convert]::ToInt32($codes[$lastIndex],16)-ne([Convert]::ToInt32($codes[$lastIndex-1],16)+1)){throw "RPG2 $key unimplemented ID is not consecutive."}
    $boxes[$key].SelectedIndex=$lastIndex
    if((Get-Code $boxes[$key])-ne$codes[$lastIndex]){throw "RPG2 $key unimplemented ID reverted instead of being retained."}
    $boxes[$key].SelectedIndex=0
  }
  $definedFaceCheck.Checked=$true
  if(-not $facePreview.Image){throw 'RPG2 shared face preview failed.'}
  if ($neckBox.Items.Count -ne 52 -or $neckBox.Items[0] -ne '(なし)' -or $neckBox.SelectedIndex -ne 0) { throw "Neck none/catalog mismatch: $($neckBox.Items.Count)" }
  if ($clothingBox.Items.Count -ne 102) { throw "Clothing catalog count mismatch: $($clothingBox.Items.Count)" }
  if ($armBox.Items.Count -ne 42) { throw "Arm catalog count mismatch: $($armBox.Items.Count)" }
  if ($backBox.Items.Count -ne 64) { throw "Back catalog count mismatch: $($backBox.Items.Count)" }
  if ($feetBox.Items.Count -ne 30) { throw "Feet catalog count mismatch: $($feetBox.Items.Count)" }
  $cheapWatchIndex = [Array]::IndexOf([object[]]$armEquipmentCodes, [object]'0200')
  $drillHandIndex = [Array]::IndexOf([object[]]$armEquipmentCodes, [object]'0228')
  if ($cheapWatchIndex -lt 0 -or $armEquipmentNames[$cheapWatchIndex] -ne 'やすいとけい') { throw 'やすいとけい mapping smoke test failed.' }
  if ($drillHandIndex -lt 0 -or $armEquipmentNames[$drillHandIndex] -ne 'ドリルハンド') { throw 'ドリルハンド mapping smoke test failed.' }
  $fanIndex = [Array]::IndexOf([object[]]$backEquipmentCodes, [object]'01BA')
  $secretScrollIndex = [Array]::IndexOf([object[]]$backEquipmentCodes, [object]'01F7')
  if ($fanIndex -lt 0 -or $backEquipmentNames[$fanIndex] -ne 'うちわ') { throw 'うちわ mapping smoke test failed.' }
  if ($secretScrollIndex -lt 0 -or $backEquipmentNames[$secretScrollIndex] -ne 'ひでんのまきもの') { throw 'ひでんのまきもの mapping smoke test failed.' }
  $ankletIndex = [Array]::IndexOf([object[]]$feetEquipmentCodes, [object]'0230')
  $monsterFeetIndex = [Array]::IndexOf([object[]]$feetEquipmentCodes, [object]'024C')
  if ($ankletIndex -lt 0 -or $feetEquipmentNames[$ankletIndex] -ne 'すばやさアンクレット') { throw 'すばやさアンクレット mapping smoke test failed.' }
  if ($monsterFeetIndex -lt 0 -or $feetEquipmentNames[$monsterFeetIndex] -ne 'かいじゅうのあし') { throw 'かいじゅうのあし mapping smoke test failed.' }
  $speedIndex = [Array]::IndexOf([object[]]$clothingCodes, [object]'069C')
  $ornamentIndex = [Array]::IndexOf([object[]]$clothingCodes, [object]'06A1')
  if ($speedIndex -lt 0 -or $clothingNames[$speedIndex] -ne 'スピードプリント') { throw 'スピードプリント mapping smoke test failed.' }
  if ($ornamentIndex -lt 0 -or $clothingNames[$ornamentIndex] -ne 'オーナメント') { throw 'オーナメント mapping smoke test failed.' }
  if($neckEquipmentNames -match '検証枠' -or $armEquipmentNames -match '検証枠' -or $backEquipmentNames -match '検証枠' -or $feetEquipmentNames -match '検証枠' -or $clothingNames -match '検証枠'){throw 'RPG2 equipment probe slots were not removed.'}
  $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance');[void]$click.Invoke($displayButton,@([EventArgs]::Empty));if(-not$script:currentQrPath-or-not(Test-Path $script:currentQrPath)-or-not$saveButton.Enabled-or-not$cardButton.Enabled){throw 'RPG2 automatic QR generation failed.'};if($script:lastGenerateArguments-contains'--qr-date'){throw 'RPG2 normal QR unexpectedly overwrote the authentic carrier timestamp.'};$carrierIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--carrier');if($carrierIndex-lt0-or$script:lastGenerateArguments[$carrierIndex+1]-ne$normalCarrier){throw 'RPG2 normal QR did not use the authentic Shiroganemaru carrier.'};$jpHash=(Get-FileHash $script:currentQrPath -Algorithm SHA256).Hash
  $definedFaceCheck.Checked=$false;$boxes['--face-image'].SelectedIndex=15;$autoQrTimer.Stop();[void]$click.Invoke($displayButton,@([EventArgs]::Empty));$skinArg=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--face-image');if($skinArg-lt0-or$script:lastGenerateArguments[$skinArg+1]-ne'0F'-or-not$saveButton.Enabled){throw 'RPG2 undefined skin 15 QR generation failed.'};$boxes['--face-image'].SelectedIndex=5;$definedFaceCheck.Checked=$true
  $regionalRow=@($nameLanguage.Rows|Where-Object JP -eq 'つかさ'|Select-Object -First 1)[0];Sync-DenpaNameLanguageRow $nameLanguage $regionalRow
  Set-DenpaEuLanguage $nameLanguage 'FRA';$regionButtons['EU'].Checked=$true;$autoQrTimer.Stop();[void]$click.Invoke($displayButton,@([EventArgs]::Empty));$nameArg=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--name');if($nameArg-lt0-or$script:lastGenerateArguments[$nameArg+1]-ne[string]$regionalRow.FRA-or$nameLanguage.Checks.EU.Checked-or-not$nameLanguage.Checks.FRA.Checked){throw 'RPG2 EU/FRA selection did not encode the French name.'}
  Set-DenpaEuLanguage $nameLanguage 'EU';$autoQrTimer.Stop();[void]$click.Invoke($displayButton,@([EventArgs]::Empty));$nameArg=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--name');if($nameArg-lt0-or$script:lastGenerateArguments[$nameArg+1]-ne[string]$regionalRow.EU-or-not$nameLanguage.Checks.EU.Checked-or$nameLanguage.Checks.FRA.Checked){throw 'RPG2 EU/English selection did not encode the English name.'};$euHash=(Get-FileHash $script:currentQrPath -Algorithm SHA256).Hash;if($jpHash-eq$euHash){throw 'RPG2 regional QR identity did not change.'};$regionButtons['JP'].Checked=$true;$autoQrTimer.Stop()
  $modeBox.SelectedIndex=1;if(-not$script:rpg2DateControlActive-or-not$qrDate.Enabled-or$qrDateLabel.Text-ne'QR日付'){throw 'RPG2 manual special date control was not enabled.'};$qrDate.Value=[datetime]'2030-01-02';$neckBox.SelectedIndex=0;$armBox.SelectedIndex=0;$backBox.SelectedIndex=0;$feetBox.SelectedIndex=0;$clothingBox.SelectedIndex=0;$autoQrTimer.Stop();[void]$click.Invoke($displayButton,@([EventArgs]::Empty));$noneArgIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--official-neck-equipment');if($noneArgIndex-lt0-or$script:lastGenerateArguments[$noneArgIndex+1]-ne'0000'){throw 'RPG2 neck (none) did not encode 0000.'};$dateArgIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--qr-date');if($dateArgIndex-lt0-or$script:lastGenerateArguments[$dateArgIndex+1]-ne'2030-01-02'){throw 'RPG2 manual special date argument failed.'}
  $modeBox.SelectedIndex=1;$neckBox.SelectedIndex=25;$armBox.SelectedIndex=1;$backBox.SelectedIndex=1;$feetBox.SelectedIndex=1;$clothingBox.SelectedIndex=1;Set-Rpg2ClaimSlot 256;$autoQrTimer.Stop();[void]$click.Invoke($displayButton,@([EventArgs]::Empty))
  $claimArgIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--official-claim-id');if($claimArgIndex-lt0-or$script:lastGenerateArguments[$claimArgIndex+1]-ne'0100'){throw 'RPG2 manual claim slot 256 was not written.'};$claim1=256
  $backBox.SelectedIndex=2;$autoQrTimer.Stop();[void]$click.Invoke($displayButton,@([EventArgs]::Empty));$claimArgIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--official-claim-id');$claim2=[Convert]::ToInt32([string]$script:lastGenerateArguments[$claimArgIndex+1],16);if($claim1-ne$claim2){throw 'RPG2 manual claim ID changed with equipment.'}
  Set-Rpg2ClaimSlot 309;$autoQrTimer.Stop();[void]$click.Invoke($displayButton,@([EventArgs]::Empty));$claimArgIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--official-claim-id');if($script:lastGenerateArguments[$claimArgIndex+1]-ne'0135'-or$claimSlotBox.Text-ne'309（いわた）'){throw 'RPG2 official Iwata claim slot 309 was not written.'}
  Set-Rpg2ClaimSlot 511;$autoQrTimer.Stop();[void]$click.Invoke($displayButton,@([EventArgs]::Empty));$claimArgIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--official-claim-id');if($script:lastGenerateArguments[$claimArgIndex+1]-ne'01FF'){throw 'RPG2 maximum claim slot 511 was not written.'}
  if($modeBox.Items.Count-ne2-or$modeBox.Items[1]-ne'特典QR'){throw 'RPG2 QR modes were not finalized.'}
  $regionButtons['NA'].Checked=$true;Set-Rpg2ClaimSlot 400;$autoQrTimer.Stop();[void]$click.Invoke($displayButton,@([EventArgs]::Empty));$regionIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--official-special-region');if($regionIndex-lt0-or$script:lastGenerateArguments[$regionIndex+1]-ne'NA'){throw 'RPG2 NA special QR region argument failed.'}
  Write-Output 'GUI_RPG2_ARM_41_BACK_63_FEET_29_CLOTHING_101_OK'
  Write-Output ('GUI_RPG2_MANUAL_EQUIPMENT_CLAIM_ID_OK {0}' -f $claim1)
  Write-Output 'GUI_RPG2_SPECIAL_REGION_AND_256_CLAIM_SLOTS_OK'
  $form.Dispose()
  return
}

if ($env:DENPA_EDITOR_EMBED -eq '1') {
  $script:EmbeddedEditorForm = $form
  return
}

if ((Split-Path -Leaf $PSScriptRoot) -eq 'internal') {
  [Windows.Forms.MessageBox]::Show('このファイルは統合版の内部部品です。Denpa QREditor2.3 v1.0.2.exeから起動してください。', 'Denpa QREditor2.3 v1.0.2') | Out-Null
  $form.Dispose()
  return
}

[void]$form.ShowDialog()
