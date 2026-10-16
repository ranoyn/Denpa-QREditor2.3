Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()
$towerFilterModule = Join-Path $PSScriptRoot 'DenpaTowerFilter.ps1'
if (Test-Path -LiteralPath $towerFilterModule) { . $towerFilterModule }
$cardModule = Join-Path $PSScriptRoot 'Denpa3Card.ps1'
if (Test-Path -LiteralPath $cardModule) { . $cardModule }

$localAssetRoot = Join-Path $PSScriptRoot 'assets'
$assetRoot = if (Test-Path -LiteralPath $localAssetRoot) {
  $localAssetRoot
} else {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\assets'))
}
# Compatibility argument label only; no JavaScript file is required.
$editorTool = 'denpa3-qr-editor.mjs'
$localDataRoot = Join-Path $PSScriptRoot 'data'
$dataRoot = if (Test-Path -LiteralPath $localDataRoot) {
  $localDataRoot
} else {
  [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\data'))
}
$templateCatalogModule=Join-Path $PSScriptRoot 'DenpaTemplateCatalog.ps1'
if(!(Test-Path -LiteralPath $templateCatalogModule)){throw '電波テンプレート読込機能が見つかりません。'}
. $templateCatalogModule
$nameLanguageModule=Join-Path $PSScriptRoot 'DenpaNameLanguage.ps1'
if(!(Test-Path -LiteralPath $nameLanguageModule)){throw '多言語名前UIが見つかりません。'}
. $nameLanguageModule
$antennaCatalogPath = Join-Path $dataRoot 'antenna-catalog.json'
$antennaCatalog = if (Test-Path -LiteralPath $antennaCatalogPath) {
  Get-Content -LiteralPath $antennaCatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else { $null }
. (Join-Path $PSScriptRoot 'DenpaQrBackend.ps1')
$carriers = @{
  # Authentic Japanese normal QR (あいな). Hardware testing confirmed that
  # unchanged, name-only edited, and fully edited variants all show the
  # console's current date on the recruitment confirmation screen.
  JP = 'generated3:normal-jp'
  EU = 'generated3:normal-eu'
  NA = 'generated3:normal-na'
}
$specialCarrierPath = Join-Path $dataRoot 'official-special-jiya.hex'
$huntCarrierPath = Join-Path $dataRoot 'official-special-hunt.hex'
function Get-Rpg3SpecialCarrierValue([string]$Path){
  $file=[IO.Path]::GetFileName($Path)
  if($file-match'^official-special-(hunt|jiya|jack|kiki|rudolph|santa)\.hex$'){return ('generated:'+$Matches[1])}
  throw ('Unsupported reconstructed special QR: '+$file)
}
$officialFurnitureEvents = @(
  [pscustomobject]@{ Label = 'ジャック形式（コード34・家具1種類）'; Code = '34'; MaxItems = 1; Path = (Join-Path $dataRoot 'official-special-jack.hex'); Official = $true },
  [pscustomobject]@{ Label = 'キキ形式（コード35・家具3種類）'; Code = '35'; MaxItems = 3; Path = (Join-Path $dataRoot 'official-special-kiki.hex'); Official = $true },
  [pscustomobject]@{ Label = 'ルドルフ形式（コード36・家具1種類）'; Code = '36'; MaxItems = 1; Path = (Join-Path $dataRoot 'official-special-rudolph.hex'); Official = $true },
  [pscustomobject]@{ Label = 'さんた形式（コード37・家具3種類）'; Code = '37'; MaxItems = 3; Path = (Join-Path $dataRoot 'official-special-santa.hex'); Official = $true }
)
$multiItemEvents = @($officialFurnitureEvents)
$itemCatalogPath = Join-Path $dataRoot 'rpg3-item-catalog.tsv'
$nameCatalogPath = Join-Path $dataRoot 'rpg3-name-catalog.tsv'
$towerCompatibilityPath=Join-Path $dataRoot 'rpg3-tower-compatibility.json'
$towerCompatibility=if(Test-Path -LiteralPath $towerCompatibilityPath){Get-Content -Raw -LiteralPath $towerCompatibilityPath -Encoding UTF8|ConvertFrom-Json}else{$null}
$monsterCatalogPath = Join-Path $dataRoot 'rpg3-monster-catalog.tsv'
$naItemMap=@{};$naMonsterMap=@{}
$naItemMapPath=Join-Path $dataRoot 'rpg3-item-id-map-na.tsv';if(Test-Path -LiteralPath $naItemMapPath){foreach($row in (Import-Csv -LiteralPath $naItemMapPath -Delimiter "`t" -Encoding UTF8)){if($row.reward_hex-and$row.name_na){$naItemMap[[string]$row.reward_hex.ToUpperInvariant()]=[string]$row.name_na}}}
$naItemMap['0315']='Coliseum Wall'
$naMonsterMapPath=Join-Path $dataRoot 'rpg3-monster-catalog-na.tsv';if(Test-Path -LiteralPath $naMonsterMapPath){foreach($row in (Import-Csv -LiteralPath $naMonsterMapPath -Delimiter "`t" -Encoding UTF8)){if($row.capture_hex-and$row.name_na){$naMonsterMap[[string]$row.capture_hex.ToUpperInvariant()]=[string]$row.name_na}}}
$naMonsterMap['A5']='No antenna(Crash)'
function Get-Rpg3LocalizedRewardNames([object[]]$Codes,[object[]]$JapaneseNames,[string]$Language){
  $colorMap=@{'赤'='Red';'水'='Light Blue';'緑'='Green';'橙'='Orange';'黄'='Yellow';'青'='Blue';'白'='White';'紫'='Purple';'銀'='Silver';'金'='Gold';'桃'='Pink';'黒'='Black'}
  $result=@();for($i=0;$i-lt$Codes.Count;$i++){$code=[string]$Codes[$i];$jp=if($i-lt$JapaneseNames.Count){[string]$JapaneseNames[$i]}else{$code};if($Language-eq'English'-and$naItemMap.ContainsKey($code.ToUpperInvariant())){$localized=[string]$naItemMap[$code.ToUpperInvariant()];if($jp-match'（(赤|水|緑|橙|黄|青|白|紫|銀|金|桃|黒)）$'){$localized+=' ('+$colorMap[$Matches[1]]+')'};$result+=$localized}else{$result+=$jp}};@($result)
}
$legitimateNames = @('つかさ')
if (Test-Path -LiteralPath $nameCatalogPath) {
  $loadedNames = @(Import-Csv -LiteralPath $nameCatalogPath -Delimiter "`t" -Encoding UTF8 | ForEach-Object { $_.name } | Where-Object { $_ })
  if ($loadedNames.Count -gt 0) { $legitimateNames = $loadedNames }
}
$displayNames=@(Sort-DenpaJapaneseNames $legitimateNames)
$itemCatalogRows = @()
if (Test-Path -LiteralPath $itemCatalogPath) {
  $seenRewardCodes = @{}
  foreach ($entry in (Import-Csv -LiteralPath $itemCatalogPath -Delimiter "`t" -Encoding UTF8)) {
    if (-not $entry.name -or $entry.name -eq 'なし' -or [int]$entry.internal_id -eq 0) { continue }
    if ($seenRewardCodes[$entry.reward_hex]) { continue }
    $seenRewardCodes[$entry.reward_hex] = $true
    $itemCatalogRows += $entry
  }
}
# The game stores the following plant/seed/paint variants as twelve adjacent
# records, while their extracted Japanese base names are identical. Give every
# variant its in-game colour in record order instead of showing a generic
# "種類1" suffix in the editor.
$itemVariantColors = @('赤','水','緑','橙','黄','青','白','紫','銀','金','桃','黒')
$itemVariantBases = @(
  'ペイントざい','タンポポのたね','パンジーのたね','あじさいのたね','バラのたね',
  'すずらんのたね','サボテンのたね','ラフレシアのたね','タンポポ','パンジー',
  'あじさい','バラ','すずらん','サボテン','ラフレシア'
)
foreach ($variantBase in $itemVariantBases) {
  $variantRows = @($itemCatalogRows | Where-Object { $_.name -eq $variantBase } | Select-Object -First 12)
  if ($variantRows.Count -eq $itemVariantColors.Count) {
    for ($variantIndex = 0; $variantIndex -lt $itemVariantColors.Count; $variantIndex++) {
      $variantRows[$variantIndex].name = '{0}（{1}）' -f $variantBase, $itemVariantColors[$variantIndex]
    }
  }
}
$itemRewardNames = @()
$itemRewardCodes = @()
if ($itemCatalogRows.Count) {
  $nameTotals = @{}
  foreach ($entry in $itemCatalogRows) { $nameTotals[$entry.name] = 1 + [int]($nameTotals[$entry.name]) }
  $nameSeen = @{}
  foreach ($entry in $itemCatalogRows) {
    $nameSeen[$entry.name] = 1 + [int]($nameSeen[$entry.name])
    $label = if($entry.name-eq'クローバー'-and$nameSeen[$entry.name]-eq1){$entry.name}elseif ($nameTotals[$entry.name] -gt 1) { '{0}（種類{1}）' -f $entry.name, $nameSeen[$entry.name] } else { $entry.name }
    $itemRewardNames += $label
    $itemRewardCodes += $entry.reward_hex
  }
}
$furnitureCatalogRows = @($itemCatalogRows | Where-Object {
  $id = [int]$_.internal_id
  $id -ge 501 -and $id -le 788
})
$furnitureRewardNames = @($furnitureCatalogRows | ForEach-Object { $_.name })
$furnitureRewardCodes = @($furnitureCatalogRows | ForEach-Object { $_.reward_hex })
$decorFurnitureRows = @($furnitureCatalogRows | Where-Object { [int]$_.internal_id -ge 501 -and [int]$_.internal_id -le 690 })
$decorFloorRows = @($furnitureCatalogRows | Where-Object { [int]$_.internal_id -ge 691 -and [int]$_.internal_id -le 736 })
$decorWallRows = @($furnitureCatalogRows | Where-Object { [int]$_.internal_id -ge 741 -and [int]$_.internal_id -le 788 })
$decorFurnitureNames = @($decorFurnitureRows | ForEach-Object { $_.name }); $decorFurnitureCodes = @($decorFurnitureRows | ForEach-Object { $_.reward_hex })
$decorFloorNames = @($decorFloorRows | ForEach-Object { $_.name }); $decorFloorCodes = @($decorFloorRows | ForEach-Object { $_.reward_hex })
$decorWallNames = @($decorWallRows | ForEach-Object { $_.name }); $decorWallCodes = @($decorWallRows | ForEach-Object { $_.reward_hex })
if($decorWallCodes-notcontains'0315'){$decorWallNames+=@('コロシアムのかべ');$decorWallCodes+=@('0315')}
# 「デコレを全選択する」は屋根（内部ID 501～510）を除外し、
# 通常の壁範囲直後にあるコロシアムのかべ（内部ID 789）を含める。
$decorAllRows = @($furnitureCatalogRows | Where-Object { $id=[int]$_.internal_id; $id -lt 501 -or $id -gt 510 })
$coliseumWallRow = @($itemCatalogRows | Where-Object { [int]$_.internal_id -eq 789 } | Select-Object -First 1)
if($coliseumWallRow.Count -and -not($decorAllRows | Where-Object { $_.reward_hex -eq '0315' })){$decorAllRows += $coliseumWallRow[0]}
$decorAllNames = @($decorAllRows | ForEach-Object { $_.name }); $decorAllCodes = @($decorAllRows | ForEach-Object { $_.reward_hex })
# 旧検証枠は実機検証を終えたため、通常のアイテム一覧には表示しない。

$form = New-Object Windows.Forms.Form
  $form.Text = 'Denpa QREditor2.3 1.0.1 - RPG3'
$form.ClientSize = New-Object Drawing.Size(1260, 730)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Yu Gothic UI', 10)

$title = New-Object Windows.Forms.Label
  $title.Text = 'Denpa QREditor2.3 1.0.1'
$title.Font = New-Object Drawing.Font('Yu Gothic UI', 16, [Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(18, 14)
$form.Controls.Add($title)

$codeLabel = New-Object Windows.Forms.Label
$codeLabel.Text = '暗号・CRC・QR生成を内蔵（code.bin不要）'
$codeLabel.AutoSize = $true
$codeLabel.Location = New-Object Drawing.Point(20, 62)
$form.Controls.Add($codeLabel)

$editionLabel = New-Object Windows.Forms.Label
$editionLabel.Text = 'ゲーム版'
$editionLabel.AutoSize = $true
$editionLabel.Location = New-Object Drawing.Point(570, 62)
$form.Controls.Add($editionLabel)

$edition = New-Object Windows.Forms.ComboBox
$edition.DropDownStyle = 'DropDownList'
$edition.Location = New-Object Drawing.Point(645, 57)
$edition.Size = New-Object Drawing.Size(220, 27)
[void]$edition.Items.AddRange([object[]]@('日本版','NA版','EU版'))
$edition.SelectedIndex = 0
$form.Controls.Add($edition)

# 統合UIではQRの真上にJP／NA／EUをラジオボタンで表示する。
# 内部のComboBoxは既存のQR生成処理との互換のため保持する。
$editionRadioPanel = New-Object Windows.Forms.Panel
$editionRadioPanel.Name = 'editionRadioPanel'
$editionRadioPanel.Size = New-Object Drawing.Size(285, 28)
$editionRadioPanel.Visible = $false
$editionRadios = @()
$script:rpg3EditionSyncing = $false
$editionRadioIndexByEdition = @(0,1,2)
foreach($entry in @(@('JP',0,0),@('NA',1,1),@('EU',2,2))){
  $radio = New-Object Windows.Forms.RadioButton
  $radio.Text = $entry[0];$radio.AutoSize=$true;$radio.Location=New-Object Drawing.Point(($entry[2]*88),2)
  $targetIndex=[int]$entry[1]
  $radio.Add_CheckedChanged({
    if(-not$this.Checked-or$script:rpg3EditionSyncing-or$edition.SelectedIndex-eq$targetIndex){return}
    $script:rpg3EditionSyncing=$true
    try{$edition.SelectedIndex=$targetIndex}finally{$script:rpg3EditionSyncing=$false}
  }.GetNewClosure())
  $editionRadioPanel.Controls.Add($radio);$editionRadios += $radio
}
$editionRadios[0].Checked = $true
$edition.Add_SelectedIndexChanged({
  if($script:rpg3EditionSyncing-or$edition.SelectedIndex-lt0-or$edition.SelectedIndex-ge$editionRadios.Count){return}
  $script:rpg3EditionSyncing=$true
  try{$editionRadios[$editionRadioIndexByEdition[$edition.SelectedIndex]].Checked=$true}finally{$script:rpg3EditionSyncing=$false}
})
$form.Controls.Add($editionRadioPanel)

$freeNameCheck = New-Object Windows.Forms.CheckBox
$freeNameCheck.Text = '正規名以外を自由入力'
$freeNameCheck.AutoSize = $true
$freeNameCheck.Location = New-Object Drawing.Point(350, 61)
$freeNameCheck.Checked = $false
$form.Controls.Add($freeNameCheck)

$qrDateLabel = New-Object Windows.Forms.Label
$qrDateLabel.Text = 'QR日付'
$qrDateLabel.AutoSize = $true
$qrDateLabel.Location = New-Object Drawing.Point(890, 62)
$form.Controls.Add($qrDateLabel)

$qrDate = New-Object Windows.Forms.DateTimePicker
$qrDate.Format = [Windows.Forms.DateTimePickerFormat]::Custom
$qrDate.CustomFormat = 'yyyy/MM/dd'
$qrDate.Location = New-Object Drawing.Point(970, 57)
$qrDate.Size = New-Object Drawing.Size(160, 27)
$qrDate.Value = [DateTime]::Today
$qrDate.ShowCheckBox=$true;$qrDate.Checked=$false
$form.Controls.Add($qrDate)

function Get-Rpg3ActiveEditionIndex {
  if($null-ne$script:rpg3CardEditionOverride){return [int]$script:rpg3CardEditionOverride}
  return [int]$edition.SelectedIndex
}

function Get-ActiveCarrier {
  $activeEdition=Get-Rpg3ActiveEditionIndex
  if ($activeEdition -eq 1) { return $carriers.NA }
  if ($activeEdition -eq 2) { return $carriers.EU }
  return $carriers.JP
}

function Get-ActiveSpecialRegionMask {
  # 3DS本体地域番号をビット化: JP=bit0, NA=bit1, EU=bit2。
  $activeEdition=Get-Rpg3ActiveEditionIndex
  if ($activeEdition -eq 1) { return '0002' }
  if ($activeEdition -eq 2) { return '0004' }
  return '0001'
}

function New-HexOptions([int]$Maximum) {
  return @(0..$Maximum | ForEach-Object { $_.ToString('X2') })
}

function New-DecimalOptions([int]$Maximum) {
  return @(0..$Maximum | ForEach-Object { $_.ToString() })
}

function New-UncertainDecimalOptions([int]$Start, [int]$End) {
  if ($End -lt $Start) { return @() }
  return @($Start..$End | ForEach-Object { "未定義($_)" })
}

function New-OutOfRangeDecimalOptions([int]$Start, [int]$End) {
  if ($End -lt $Start) { return @() }
  return @($Start..$End | ForEach-Object { "未定義($_)" })
}

$headNames = @(
  'まる','よこまる','たてまる','さんかく','おにぎり','しかく','かどまる','しずく',
  'つぼ','こぐま','あまつゆ','チューリップ','ロボ','イカ','ロケット','スター',
  'くま','ハート','ねこみみ','デビル','みかづき','とんがり','でんち','トゲトゲ',
  'たまご','タワー','いぬみみ','メラメラ','クワガタ','ダイヤ','ルビー','たいよう',
  'うさみみ','まきがい','キャッスル','ブロック','たまねぎ','わっか','コック','おさかな',
  'クラッシュ(未定義40)'
)
$headOptions = $headNames
$headCodes = @(0..($headNames.Count - 1) | ForEach-Object { '{0:X2}' -f $_ })
$faceEquipmentNames = @(
  '(なし)','みどりのめがね','ピンクのめがね','サングラス','きいろいめがね','しかくいめがね',
  'アイマスク','ふくろうめがね','あおいめがね','マスカレードマスク','くろぶちめがね',
  'バタフライマスク','すいちゅうメガネ','むしのめ','きんぴかグラス','ハートグラス',
  'スターグラス','あかぶちメガネ','ワイルドグラス','ゴーグル','カラーゴーグル',
  'まるめがね','びんぞこめがね','パイロットゴーグル','未定義(24)','未定義(25)'
)
$faceEquipmentOptions = $faceEquipmentNames
$faceEquipmentCodes = @(0..($faceEquipmentNames.Count - 1) | ForEach-Object { '{0:X2}' -f $_ })
$bodyColorNames = @(
  '黒','赤','水色','緑','オレンジ','黄','青','白','赤／水色','赤／緑','赤／オレンジ',
  '赤／黄','赤／青','赤／白','水色／緑','水色／オレンジ','水色／黄','水色／青','水色／白',
  'オレンジ／緑','黄／緑','青／緑','白／緑','オレンジ／黄','オレンジ／青','オレンジ／白',
  '黄／青','黄／白','白／青','紫','銀','金','桃'
)
$bodyColorOptions = $bodyColorNames
$bodyColorCodes = @(0..($bodyColorNames.Count - 1) | ForEach-Object { '{0:X2}' -f $_ })
$statureNames = @(
  '0最速','0準速','0中間','0準大','0最大',
  '3+最速','3+準速','3+中間','3+準大','3+最大',
  '3-最速','3-準速','3-中間','3-準速','3-最大',
  '6+最速','6+準速','6+中間','6+準大','6+最大',
  '10最速','6-準速','6-中間','6-準大','6-最大',
  '15最速','15準速','15中間','10準大','10最大'
)
$statureCodes = @(0..($statureNames.Count - 1) | ForEach-Object { '{0:X2}' -f $_ })
$hairColorNames = @('黒','白','茶','黄茶','赤茶','黄','青','緑','紫','桃','オレンジ','赤','銀','銀(未定義13)','銀(未定義14)','銀(未定義15)')
$hairColorOptions = $hairColorNames
$hairColorCodes = @(0..($hairColorNames.Count - 1) | ForEach-Object { '{0:X2}' -f $_ })
$skinHairNames = @('黒','白','茶','黄茶','赤茶','黄','青','緑','紫','桃','オレンジ','赤','銀')
$skinNames = @(0..5 | ForEach-Object { $_.ToString() }) + @(0..($skinHairNames.Count-1) | ForEach-Object { '{0}髪(未定義{1})' -f $skinHairNames[$_], (6 + $_) })
$skinOptions = $skinNames
$skinCodes = @(0..($skinNames.Count - 1) | ForEach-Object { '{0:X2}' -f $_ })
$antennaAppearanceOptions = if ($antennaCatalog) {
  @($antennaCatalog.appearances | ForEach-Object {
    $label = if ($_.code -eq '18') { 'みんなふっかつ' } else { $_.name }
    '{0} {1}' -f ([Convert]::ToInt32($_.code, 16)), $label
  })
} else { New-DecimalOptions 0xDF }
$antennaAppearanceCodes = if ($antennaCatalog) {
  @($antennaCatalog.appearances | ForEach-Object { $_.code })
} else { New-HexOptions 0xDF }
$antennaAbilityNames = @(
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
  'ダークボール','くろいきり','つかまえる'
)
$antennaFinalNames = @(
  'アンテナなし','おたから5ばい','レアおたから5ばい','ゴールド5ばい','しばらくステルス',
  'ぜんぶかいふく','みんなぜんぶかいふく','かんぜんふっかつ','みんなかんぜんふっかつ',
  'みんなげどく','みんなやけどなおす','みんなかわかす','みんなかぜなおす','みんなどろおとす',
  'みんなおはらい','みんなかんでんなおす','みんなあたためる','みんなしびれとる',
  'みんなめざめる','みんなめぐすり','みんなむてき','みんなこうふん','みんなたくわえる',
  'みんなわざはねかえす','すごくつよくなれ','みんなムキムキ','すごくかたくなれ',
  'みんなガチガチ','すごくはやくなれ','みんなかぜになれ','すごくかわしやすい',
  'みんなでスルー','どくどくウェーブ','みんなもうどく','みんなねむらせる',
  'みんなしびれさせる','みんなめかくし','みんなブレスふうじ','すごくよわくなれ',
  'みんなげきよわ','すごくやわくなれ','みんなやわやわ','すごくおそくなれ','みんなのろのろ',
  'やきつくすほのお','ビッグバン','じごくのごうか','ひょうちゅうおとし','ダイヤモンドダスト',
  'もうふぶき','かみかぜ','ハリケーン','ダウンバースト','てんちほうらく','いんせきらっか',
  'マグニチュード12','でんきだま','せいてんのへきれき','いちおくボルト','げきりゅう',
  'ジェットスプラッシュ','おおつなみ','はかいこうせん','フレア','せきどうちょっか',
  'やみのしはいしゃ','ブラックホール','ならくのそこ','つかまえる3ばい'
)
$antennaAbilityOptions = @($antennaAbilityNames)
$antennaAbilityCodes = @(0..0x44 | ForEach-Object { '{0:X2}' -f $_ })
$specialAntennaOptions = @(
  'もえさかるこおり','かさいせんぷう','だいふんか','らくらいかさい',
  'ほのおのうみ','こおりあらし','こおりいんせき','かみなりふぶき',
  'ひさめ','つちけむり','でんきあらし','ぼうふうう',
  'かみなりがんせき','どせきりゅう','らいう','ならくのたいよう'
)
$specialAntennaCodes = @('45','46','47','48','49','4B','4C','4D','4E','51','52','53','57','58','5D','63')
$antennaAbilityOptions = @($antennaAbilityOptions) + $specialAntennaOptions
$antennaAbilityCodes = @($antennaAbilityCodes) + $specialAntennaCodes

# Hidden appearance selector must also represent later and two-element stages.
foreach($appearanceId in 0..0xDF){
  $appearanceCode='{0:X2}'-f$appearanceId
  if($antennaAppearanceCodes-notcontains$appearanceCode){
    $antennaAppearanceCodes+=@($appearanceCode)
    $antennaAppearanceOptions+=@($appearanceId.ToString()+' '+$appearanceCode)
  }
}

$personalityOptions = @('いちご','にがうり','トウガラシ','バナナ','レモン','ぶどう','かき','(なし)','主人公(注意)','あかり','テル(頭身変化)','ルナ(頭身変化)','みちる','ひのわ')
$personalityCodes = @((0..7 | ForEach-Object { '{0:X2}' -f $_ }) + @('64','65','66','67','68','69'))
$monsterNames = @(
  'はなもぐら','てっぽうオトシゴ','ばけギツネ','ドローン','どくキンチャク','あばれコブダイ',
  'したっぱキャット','カビまんじゅう','トライコーン','ウッドウォーカー','スモークボール','あかばなチョウ',
  'みどりマタンゴ','カーニバルイーグル','アイスサソリ','ダークディフェンダー','トロル','たからばこぞう',
  'クリムゾンキーパー','フロストキーパー','ダイジャーン','ファイアホッグ','りくガニ','ハンチプテラ',
  'ファイヤーころがし','だるまこぞう','ひつかいキツネ','レッドホーン','ほうおう','ビースト',
  'セピアランサー','ゴールデンハム','サラマンダー','アクアミスト','しびれマタンゴ','マジックエイプ',
  'ももいろハム','ゴルゴンシャーク','カミナリゴケ','にゅうし','ネズミはなもぐら','デストロル',
  'ナイト','リーフドール','リーフホッグ','ゾンビコンドル','もうどくキンチャク','オクトパイダー',
  'ドリルアンコウ','ゴースト','ダイころがし','ずきんぶたばな','はなざかりもぐら','ストーングラブ',
  'シールドナイト','トレジャーメイジ','しんドローン','ガイアドラゴン','キラービースト','ダークミスト',
  'ねばりけキンチャク','スチールアンコウ','おばけオトシゴ','よつめシャーク','ゼニこぞう','よるのチョウ',
  'すいりゅう','でんきフジツボ','アクアトータス','ももいろライノ','いなずまトライコーン','このはドール',
  'あなほりホッグ','ポイズンクラブ','いかしょうぐん','カーズウォーカー','いかれコブダイ','きんピカはなもぐら',
  'ダークどうけギツネ','ブルージャイアント','トーチゴースト','じょおうのは','くらやみのナイト','こおりマタンゴ',
  'アイスウォーカー','ポーラーぶたばな','アクアサソリ','アイスころがし','レフトサーパント','ライトサーパント',
  'ブリザードプテラ','えいきゅうし','アイスブロックス','アイスフェニックス','トルネードホース','どうけギツネ',
  'カビカビまんじゅう','グリーンポーク','エイプオラクル','はさみサボテン','れっぷうりゅう','トレジャーパラディン',
  'ファイヤーブロックス','テンペスター','ギガントコブダイ','イエローアイズプテラ','キャットシーフ','まじゅつギツネ',
  'かみなりキンチャク','アンテナシーラー','サンダーミスト','のろいイカせんし','あらくれきょじん','タフビースト',
  'きんば','おばけざいほう','アヴィド','ライジーン','りゅうのおんりょう','きぞくキャット',
  'おはなドール','サクラはなもぐら','ふうじこめツボ','おうさまのは','ビックリッチ','さいごのナイト',
  'ダークネスモーク','ダークゴースト','ダイジャーン・かい','アフラーマ','ジャシン','ポーン',
  'プチドラゴン','くろびかりザメ','みずふうせんこぞう','シールドヴァイキング','エルコーン','セピアーバーサーカー',
  'ホワイトホーン','みわくのチョウ','ドローンZ','じしょう・まおう','ダークホーン','ハードフジツボ',
  'よいやみのかめ','ビリリきん','デスイーグル','ひょうけつぶくれ','サンダーエイプ','ミラーアーマー',
  'ビッグホーン','アンコウ・ターボ','タコきぞく','あんこくきとうし','シャインミスト','ホワイトフジツボ',
  'ひかりのげんぶ','ジュエルのは','ブラックナイト','ルーク','クイーン','キング',
  'ジャシンパーフェクト','はかいりゅう'
)
$monsterCodes = @(0..($monsterNames.Count - 1) | ForEach-Object { '{0:X2}' -f $_ })
if (Test-Path -LiteralPath $monsterCatalogPath) {
  $monsterCatalogRows = @(Import-Csv -LiteralPath $monsterCatalogPath -Delimiter "`t" -Encoding UTF8)
  if ($monsterCatalogRows.Count -ne 164) { throw '捕獲モンスターID表が164件ではありません。' }
  $monsterNames = @($monsterCatalogRows | ForEach-Object { $_.name })
  $monsterCodes = @($monsterCatalogRows | ForEach-Object { $_.capture_hex })
}
$monsterNames = @('(なし)') + @($monsterNames)
$monsterCodes = @('00') + @($monsterCodes)
# 0xA5は実機でアンテナなし状態となり、利用時にクラッシュする検証枠。
$monsterNames += 'アンテナなし(クラッシュ)'
$monsterCodes += 'A5'

$fields = @(
  @{ Label='名前'; Key='--name'; Value='つかさ'; Name=$true; Options=$displayNames },
  @{ Label='アンテナの形'; Key='--antenna-appearance'; Value='18'; Options=$antennaAppearanceOptions; Codes=$antennaAppearanceCodes },
  @{ Label='頭の形'; Key='--head-shape'; Value='25'; Options=$headOptions; Codes=$headCodes },
  @{ Label='髪'; Key='--hair'; Value='14'; Options=@((New-DecimalOptions 0x27) + (New-UncertainDecimalOptions 0x28 0x3F)); Codes=(New-HexOptions 0x3F) },
  @{ Label='輪郭'; Key='--contour'; Value='00'; Options=@((New-DecimalOptions 0x0B) + @('未定義(12)')); Codes=(New-HexOptions 0x0C) },
  @{ Label='眉'; Key='--eyebrow'; Value='0E'; Options=@((New-DecimalOptions 0x13) + @('未定義(20)')); Codes=(New-HexOptions 0x14) },
  @{ Label='目'; Key='--eyes'; Value='17'; Options=@((New-DecimalOptions 0x2F) + @('未定義(48)')); Codes=(New-HexOptions 0x30) },
  @{ Label='鼻'; Key='--nose'; Value='1B'; Options=@((New-DecimalOptions 0x1F) + @('未定義(32)','未定義(33)')); Codes=(New-HexOptions 0x21) },
  @{ Label='口'; Key='--mouth'; Value='01'; Options=@((New-DecimalOptions 0x27) + (New-OutOfRangeDecimalOptions 0x28 0x29)); Codes=(New-HexOptions 0x29) },
  @{ Label='頬'; Key='--cheeks'; Value='03'; Options=(New-DecimalOptions 0x0B); Codes=(New-HexOptions 0x0B) },
  @{ Label='顔装備'; Key='--glasses'; Value='00'; Options=$faceEquipmentOptions; Codes=$faceEquipmentCodes },
  @{ Label='体格'; Key='--stature'; Value='03'; Options=$statureNames; Codes=$statureCodes },
  @{ Label='体色'; Key='--body-color'; Value='07'; Options=$bodyColorOptions; Codes=$bodyColorCodes },
  @{ Label='肌色'; Key='--skin-color'; Value='01'; Options=$skinOptions; Codes=$skinCodes },
  @{ Label='髪色'; Key='--hair-color'; Value='08'; Options=$hairColorOptions; Codes=$hairColorCodes },
  @{ Label='性格'; Key='--personality'; Value='01'; Options=$personalityOptions; Codes=$personalityCodes },
  @{ Label='アンテナ'; Key='--antenna'; Value='08'; Options=$antennaAbilityOptions; Codes=$antennaAbilityCodes }
)

$boxes = @{}
$fieldCodesByKey = @{}
for ($i = 0; $i -lt $fields.Count; $i++) {
  $column = [Math]::Floor($i / 6)
  $row = $i % 6
  $x = 20 + $column * 180
  $y = 105 + $row * 43
  $label = New-Object Windows.Forms.Label
  $label.Name = 'label_' + $fields[$i].Key
  $label.Text = $fields[$i].Label
  $label.AutoSize = $true
  $label.Location = New-Object Drawing.Point($x, ($y + 4))
  $form.Controls.Add($label)
  $box = if ($fields[$i].Options) { New-Object Windows.Forms.ComboBox } else { New-Object Windows.Forms.TextBox }
  $box.Name = $fields[$i].Key
  $box.Location = New-Object Drawing.Point(($x + 95), $y)
  if ($fields[$i].Options) {
    [void]$box.Items.AddRange([object[]]$fields[$i].Options)
    $box.DropDownStyle = 'DropDownList'
    $box.Size = New-Object Drawing.Size(78, 27)
    $box.DropDownWidth = if ($fields[$i].Key -eq '--antenna') { 310 } elseif ($fields[$i].Key-eq'--personality') { 240 } elseif ($fields[$i].Name) { 220 } else { 170 }
    if ($fields[$i].Codes) {
      $fieldCodesByKey[$fields[$i].Key] = @($fields[$i].Codes)
      $selectedCodeIndex = [Array]::IndexOf([object[]]$fieldCodesByKey[$fields[$i].Key], [object]$fields[$i].Value)
      if ($selectedCodeIndex -lt 0) { throw "初期コード $($fields[$i].Value) が $($fields[$i].Label) の一覧にありません。" }
      $box.SelectedIndex = $selectedCodeIndex
    } else {
      $selectedValueIndex = [Array]::IndexOf([object[]]$fields[$i].Options, [object]$fields[$i].Value)
      if ($selectedValueIndex -lt 0) { throw "初期値 $($fields[$i].Value) が $($fields[$i].Label) の一覧にありません。" }
      $box.SelectedIndex = $selectedValueIndex
    }
  } else {
    $box.Text = $fields[$i].Value
    $box.Size = New-Object Drawing.Size(72, 27)
    $box.MaxLength = 11
  }
  $form.Controls.Add($box)
  $boxes[$fields[$i].Key] = $box
}

$nameBox = $boxes['--name']
$nameBox.AutoCompleteSource = [Windows.Forms.AutoCompleteSource]::ListItems
$nameBox.AutoCompleteMode = [Windows.Forms.AutoCompleteMode]::SuggestAppend
$nameBox.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDown
$freeNameCheck.Checked = $true
$freeNameCheck.Visible = $false
$nameLanguage=New-DenpaNameLanguageState -Form $form -DataRoot $dataRoot -JpBox $nameBox

# 電波テンプレートはDenpatemplates/RPG3の人物別JSONから読み込む。
$faceTemplateLabel = New-Object Windows.Forms.Label
$faceTemplateLabel.Text = '顔テンプレート'
$faceTemplateLabel.AutoSize = $true
$faceTemplateLabel.Location = New-Object Drawing.Point(380, 406)
$form.Controls.Add($faceTemplateLabel)
$faceTemplateBox = New-Object Windows.Forms.ComboBox
$faceTemplateBox.Name = 'faceTemplate'
$faceTemplateBox.DropDownStyle = 'DropDownList'
$faceTemplateBox.Location = New-Object Drawing.Point(485, 401)
$faceTemplateBox.Size = New-Object Drawing.Size(170, 27)
$rpg3Templates=@(Import-DenpaTemplateCatalog -ApplicationRoot $PSScriptRoot -Game 'RPG3')
[void]$faceTemplateBox.Items.Add('(選択なし)')
if($rpg3Templates.Count-gt0){[void]$faceTemplateBox.Items.AddRange([object[]]@($rpg3Templates|ForEach-Object{$_.Label}))}
$faceTemplateBox.SelectedIndex = 0
$form.Controls.Add($faceTemplateBox)
$rpg3TemplateKeys = @('--antenna','--head-shape','--contour','--hair','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses','--stature','--body-color','--skin-color','--hair-color','--personality')
$script:rpg3TemplateSpecialCarrierPath = $null
$script:rpg3OfficialTemplateDate = $null
$script:rpg3ManualSpecialDate = $qrDate.Value.Date
function Clear-Rpg3OfficialTemplateDate {
  $wasOfficial = ($null -ne $script:rpg3OfficialTemplateDate)
  $script:rpg3OfficialTemplateDate = $null
  if($wasOfficial){$qrDate.Value=$script:rpg3ManualSpecialDate}
}
$faceTemplateBox.Add_SelectedIndexChanged({
  if($faceTemplateBox.SelectedIndex-ge1-and$faceTemplateBox.SelectedIndex-le$rpg3Templates.Count){
    Apply-Rpg3Template ($faceTemplateBox.SelectedIndex-1)
  }elseif($faceTemplateBox.SelectedIndex-eq0){$script:rpg3TemplateSpecialCarrierPath=$null;Clear-Rpg3OfficialTemplateDate}
  if($updateRewardControls){&$updateRewardControls}
})

$qrTypeLabel = New-Object Windows.Forms.Label
$qrTypeLabel.Text = 'QR種類'
$qrTypeLabel.AutoSize = $true
$qrTypeLabel.Location = New-Object Drawing.Point(20, 421)
$form.Controls.Add($qrTypeLabel)

$qrType = New-Object Windows.Forms.ComboBox
$qrType.DropDownStyle = 'DropDownList'
$qrType.Location = New-Object Drawing.Point(115, 416)
$qrType.Size = New-Object Drawing.Size(150, 27)
$qrType.DropDownWidth = 180
[void]$qrType.Items.AddRange([object[]]@(
  '通常QR',
  '特典QR'
))
$qrType.SelectedIndex = 0
$form.Controls.Add($qrType)

$jewelQuantityLabel = New-Object Windows.Forms.Label
$jewelQuantityLabel.Text = '個数'
$jewelQuantityLabel.AutoSize = $true
$jewelQuantityLabel.Location = New-Object Drawing.Point(485, 421)
$form.Controls.Add($jewelQuantityLabel)

$jewelQuantity = New-Object Windows.Forms.NumericUpDown
$jewelQuantity.Minimum = 1
$jewelQuantity.Maximum = 255
$jewelQuantity.Value = 255
$jewelQuantity.Enabled = $false
$jewelQuantity.Location = New-Object Drawing.Point(530, 416)
$jewelQuantity.Size = New-Object Drawing.Size(60, 27)
$form.Controls.Add($jewelQuantity)

$itemReward = New-Object Windows.Forms.ComboBox
$itemReward.DropDownStyle = 'DropDown'
$itemReward.AutoCompleteMode = [Windows.Forms.AutoCompleteMode]::SuggestAppend
$itemReward.AutoCompleteSource = [Windows.Forms.AutoCompleteSource]::ListItems
$itemReward.Location = New-Object Drawing.Point(115, 490)
$itemReward.Size = New-Object Drawing.Size(440, 27)
$itemReward.DropDownWidth = 440
$itemReward.Enabled = $false
$itemReward.Visible = $false
if ($itemRewardNames.Count) {
  [void]$itemReward.Items.AddRange([object[]](@('(なし)') + @($itemRewardNames)))
  $itemReward.SelectedIndex = 1
}
$form.Controls.Add($itemReward)

$itemRewardLabel = New-Object Windows.Forms.Label
$itemRewardLabel.Text = 'アイテム'
$itemRewardLabel.AutoSize = $true
$itemRewardLabel.Location = New-Object Drawing.Point(20, 495)
$itemRewardLabel.Visible = $false
$form.Controls.Add($itemRewardLabel)

$itemRewards = @($itemReward)
$itemRewardLabels = @($itemRewardLabel)
$optionalItemRewardNames = @('(なし)') + @($itemRewardNames)
for ($slot = 2; $slot -le 4; $slot++) {
  $slotY = 455 + ($slot * 35)
  $slotLabel = New-Object Windows.Forms.Label
  $slotLabel.Text = "アイテム$slot"
  $slotLabel.AutoSize = $true
  $slotLabel.Location = New-Object Drawing.Point(20, ($slotY + 5))
  $slotLabel.Visible = $false
  $form.Controls.Add($slotLabel)

  $slotBox = New-Object Windows.Forms.ComboBox
  $slotBox.DropDownStyle = 'DropDown'
  $slotBox.AutoCompleteMode = [Windows.Forms.AutoCompleteMode]::SuggestAppend
  $slotBox.AutoCompleteSource = [Windows.Forms.AutoCompleteSource]::ListItems
  $slotBox.Location = New-Object Drawing.Point(115, $slotY)
  $slotBox.Size = New-Object Drawing.Size(440, 27)
  $slotBox.DropDownWidth = 440
  $slotBox.Enabled = $false
  $slotBox.Visible = $false
  [void]$slotBox.Items.AddRange([object[]]$optionalItemRewardNames)
  $slotBox.SelectedIndex = 0
  $form.Controls.Add($slotBox)
  $itemRewards += $slotBox
  $itemRewardLabels += $slotLabel
}
$itemRewardLabel.Text = 'アイテム1'
$decorAllCheck = New-Object Windows.Forms.CheckBox
$decorAllCheck.Name = 'decorAllCheck'
$decorAllCheck.Text = 'デコレを全選択する'
$decorAllCheck.AutoSize = $true
$decorAllCheck.Checked = $false
$decorAllCheck.Location = New-Object Drawing.Point(115, 600)
$decorAllCheck.Visible = $false
$decorAllCheck.Enabled = $false
$form.Controls.Add($decorAllCheck)

$multiItemEventLabel = New-Object Windows.Forms.Label
$multiItemEventLabel.Text = '配布枠'
$multiItemEventLabel.AutoSize = $true
$multiItemEventLabel.Location = New-Object Drawing.Point(20, 600)
$multiItemEventLabel.Visible = $false
$form.Controls.Add($multiItemEventLabel)

$multiItemEvent = New-Object Windows.Forms.ComboBox
$multiItemEvent.DropDownStyle = 'DropDownList'
$multiItemEvent.Location = New-Object Drawing.Point(115, 595)
$multiItemEvent.Size = New-Object Drawing.Size(440, 27)
$multiItemEvent.DropDownWidth = 520
[void]$multiItemEvent.Items.AddRange([object[]]@($multiItemEvents | ForEach-Object { $_.Label }))
$multiItemEvent.SelectedIndex = 2
$multiItemEvent.Visible = $false
$form.Controls.Add($multiItemEvent)

$extendedSpecialCodeLabel = New-Object Windows.Forms.Label
$extendedSpecialCodeLabel.Text = '特典ID'
$extendedSpecialCodeLabel.AutoSize = $true
$extendedSpecialCodeLabel.Location = New-Object Drawing.Point(600, 465)
$extendedSpecialCodeLabel.Visible = $false
$form.Controls.Add($extendedSpecialCodeLabel)

# specialCode is one byte at plaintext offset 0x54. 実機で01..FFの受取を
# 確認済み。無効な00は表示せず、用途未確定コードも検証枠表記にしない。
$specialCodeValues = @(1..255 | ForEach-Object { '{0:X2}' -f $_ })
$specialCodeLabels = @(1..255 | ForEach-Object {
  $hex='{0:X2}'-f$_
  switch($hex){
    '31' {'31'};'32' {'32（ハント）'};'33' {'33（じいや）'};'34' {'34（ジャック）'}
    '35' {'35（キキ）'};'36' {'36（ルドルフ）'};'37' {'37（さんた）'}
    default { $hex }
  }
})
$extendedSpecialCode = New-Object Windows.Forms.ComboBox
$extendedSpecialCode.DropDownStyle = 'DropDownList'
[void]$extendedSpecialCode.Items.AddRange([object[]]$specialCodeLabels)
$extendedSpecialCode.SelectedIndex = [Array]::IndexOf([object[]]$specialCodeValues,[object]'01')
$extendedSpecialCode.Location = New-Object Drawing.Point(685, 460)
$extendedSpecialCode.Size = New-Object Drawing.Size(105, 27)
$extendedSpecialCode.DropDownWidth = 180
$extendedSpecialCode.Visible = $false
$form.Controls.Add($extendedSpecialCode)

$script:eventCatalogMode = 'All'
$script:activeFurnitureEvents = @($multiItemEvents)
$script:updatingEventCatalog = $false
function Set-FurnitureEventCatalog([string]$Mode) {
  if ($script:updatingEventCatalog -or $script:eventCatalogMode -eq $Mode) { return }
  $script:updatingEventCatalog = $true
  try {
    $selectedCode = if ($multiItemEvent.SelectedIndex -ge 0) {
      $script:activeFurnitureEvents[$multiItemEvent.SelectedIndex].Code
    } else { '34' }
    $events = @($officialFurnitureEvents)
    $multiItemEvent.BeginUpdate()
    try {
      $multiItemEvent.Items.Clear()
      [void]$multiItemEvent.Items.AddRange([object[]]@($events | ForEach-Object { $_.Label }))
      $selectedIndex = 0
      for($eventIndex=0;$eventIndex-lt$events.Count;$eventIndex++){
        if($events[$eventIndex].Code-eq$selectedCode){$selectedIndex=$eventIndex;break}
      }
      $multiItemEvent.SelectedIndex = $selectedIndex
    } finally { $multiItemEvent.EndUpdate() }
    $script:activeFurnitureEvents = @($events)
    $script:eventCatalogMode = $Mode
  } finally { $script:updatingEventCatalog = $false }
}

function Get-ItemRewardIndex([Windows.Forms.ComboBox]$Box) {
  if ($Box.SelectedIndex -ge 0) { return $Box.SelectedIndex }
  if ([string]::IsNullOrWhiteSpace($Box.Text)) { return 0 }
  return $Box.FindStringExact($Box.Text)
}

$script:activeItemRewardCodes = @($itemRewardCodes)
$script:extendedRewardCodes = @{0=@($itemRewardCodes);1=@($decorFurnitureCodes);2=@($decorFloorCodes);3=@($decorWallCodes)}
$script:rewardCatalogMode = 'all'
function Set-RewardCatalog([string]$Mode) {
  if ($script:rewardCatalogMode -eq $Mode) { return }
  $jpNames = if ($Mode -eq 'furniture') { $furnitureRewardNames } else { $itemRewardNames }
  $script:activeItemRewardCodes = if ($Mode -eq 'furniture') { @($furnitureRewardCodes) } else { @($itemRewardCodes) }
  $names=@(Get-Rpg3LocalizedRewardNames $script:activeItemRewardCodes $jpNames $env:DENPA_EDITOR_LANGUAGE);$noneText=if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'None'}else{'(なし)'}
  for ($slotIndex = 0; $slotIndex -lt $itemRewards.Count; $slotIndex++) {
    $box = $itemRewards[$slotIndex]
    $box.BeginUpdate()
    try {
      $box.Items.Clear()
      [void]$box.Items.AddRange([object[]](@($noneText) + @($names)))
      $box.SelectedIndex = if ($slotIndex -eq 0 -and $names.Count) { 1 } else { 0 }
    } finally { $box.EndUpdate() }
  }
  $script:rewardCatalogMode = $Mode
}

function Set-ExtendedRewardCatalog {
  if ($script:rewardCatalogMode -eq 'extended') { return }
  for ($slotIndex = 0; $slotIndex -lt $itemRewards.Count; $slotIndex++) {
    $box = $itemRewards[$slotIndex]
    if($slotIndex-eq0){$jpNames=$itemRewardNames;$codes=$itemRewardCodes}
    elseif($decorAllCheck.Checked){$jpNames=$decorAllNames;$codes=$decorAllCodes}
    elseif($slotIndex-eq1){$jpNames=$decorFurnitureNames;$codes=$decorFurnitureCodes}
    elseif($slotIndex-eq2){$jpNames=$decorFloorNames;$codes=$decorFloorCodes}
    else{$jpNames=$decorWallNames;$codes=$decorWallCodes}
    $names=@(Get-Rpg3LocalizedRewardNames $codes $jpNames $env:DENPA_EDITOR_LANGUAGE);$noneText=if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'None'}else{'(なし)'}
    $script:extendedRewardCodes[$slotIndex]=@($codes)
    $box.BeginUpdate()
    try {
      $box.Items.Clear()
      [void]$box.Items.AddRange([object[]](@($noneText) + @($names)))
      if($slotIndex-eq0){$defaultIndex=[Array]::IndexOf([object[]]$codes,[object]'0485');$box.SelectedIndex=if($defaultIndex-ge0){$defaultIndex+1}else{0}}else{$box.SelectedIndex=0}
    } finally { $box.EndUpdate() }
  }
  $script:activeItemRewardCodes = @($itemRewardCodes)
  $script:rewardCatalogMode = 'extended'
}
$decorAllCheck.Add_CheckedChanged({$script:rewardCatalogMode='';Set-ExtendedRewardCatalog})

$capturedCheck = New-Object Windows.Forms.CheckBox
$capturedCheck.Text = '捕獲モンスターを保持する（特典と併用可）'
$capturedCheck.AutoSize = $true
$capturedCheck.Enabled = $false
$capturedCheck.Location = New-Object Drawing.Point(20, 452)
$form.Controls.Add($capturedCheck)
$capturedLabel=New-Object Windows.Forms.Label
$capturedLabel.Name='capturedMonsterLabel';$capturedLabel.Text='モンスター';$capturedLabel.AutoSize=$true
$capturedLabel.Location=$capturedCheck.Location;$form.Controls.Add($capturedLabel)
$capturedCheck.Visible=$false

$capturedMonster = New-Object Windows.Forms.ComboBox
$capturedMonster.DropDownStyle = 'DropDownList'
$capturedMonster.Location = New-Object Drawing.Point(330, 447)
$capturedMonster.Size = New-Object Drawing.Size(165, 27)
$capturedMonster.DropDownWidth = 260
$capturedMonster.Enabled = $false
[void]$capturedMonster.Items.AddRange([object[]]$monsterNames)
$capturedMonster.SelectedIndex = 0
$form.Controls.Add($capturedMonster)

function Set-Rpg3ContentLanguage([string]$Language){
  if($rpg3EquipmentBoxes){Set-Rpg3EquipmentLanguage $Language}
  $monsterIndex=$capturedMonster.SelectedIndex;$localizedMonsters=@();for($i=0;$i-lt$monsterCodes.Count;$i++){$code=[string]$monsterCodes[$i];$localizedMonsters+=if($i-eq0){$(if($Language-eq'English'){'None'}else{'(なし)'})}elseif($Language-eq'English'-and$naMonsterMap.ContainsKey($code.ToUpperInvariant())){[string]$naMonsterMap[$code.ToUpperInvariant()]}else{[string]$monsterNames[$i]}}
  $capturedMonster.BeginUpdate();try{$capturedMonster.Items.Clear();[void]$capturedMonster.Items.AddRange([object[]]$localizedMonsters);$capturedMonster.SelectedIndex=if($monsterIndex-ge0-and$monsterIndex-lt$localizedMonsters.Count){$monsterIndex}else{0}}finally{$capturedMonster.EndUpdate()}
  for($slotIndex=0;$slotIndex-lt$itemRewards.Count;$slotIndex++){
    if($script:rewardCatalogMode-eq'extended'){
      if($slotIndex-eq0){$codes=@($itemRewardCodes);$jp=@($itemRewardNames)}elseif($decorAllCheck.Checked){$codes=@($decorAllCodes);$jp=@($decorAllNames)}elseif($slotIndex-eq1){$codes=@($decorFurnitureCodes);$jp=@($decorFurnitureNames)}elseif($slotIndex-eq2){$codes=@($decorFloorCodes);$jp=@($decorFloorNames)}else{$codes=@($decorWallCodes);$jp=@($decorWallNames)}
    }elseif($script:rewardCatalogMode-eq'furniture'){$codes=@($furnitureRewardCodes);$jp=@($furnitureRewardNames)}else{$codes=@($itemRewardCodes);$jp=@($itemRewardNames)}
    $localized=@(Get-Rpg3LocalizedRewardNames $codes $jp $Language);$box=$itemRewards[$slotIndex];$selected=$box.SelectedIndex;$raw=$box.Text;$box.BeginUpdate();try{$box.Items.Clear();[void]$box.Items.Add($(if($Language-eq'English'){'None'}else{'(なし)'}));[void]$box.Items.AddRange([object[]]$localized);if($selected-ge0-and$selected-lt$box.Items.Count){$box.SelectedIndex=$selected}else{$box.SelectedIndex=-1;$box.Text=$raw}}finally{$box.EndUpdate()}
  }
  if($updateRewardControls){&$updateRewardControls}
}

$correctionLabel = New-Object Windows.Forms.Label
$correctionLabel.Text = '補正'
$correctionLabel.AutoSize = $true
$correctionLabel.Location = New-Object Drawing.Point(380, 324)
$form.Controls.Add($correctionLabel)

$correctionBox = New-Object Windows.Forms.ComboBox
$correctionBox.DropDownStyle = 'DropDownList'
$correctionBox.Location = New-Object Drawing.Point(475, 320)
$correctionBox.Size = New-Object Drawing.Size(78, 27)
$correctionBox.DropDownWidth = 220
$correctionNames = @('(なし)','HPマスター！','APマスター！','ちからもち！','がんじょう！','しゅんそく！','かいひめいじん！','アンテナへんか！','そうじゅく！')
$correctionCodes = @('0','1','2','3','4','5','6','7','8')
[void]$correctionBox.Items.AddRange([object[]]$correctionNames)
$correctionBox.SelectedIndex = 0
$form.Controls.Add($correctionBox)

function Set-Rpg3TemplateCode([string]$Key,[string]$Code){
  $normalized=$Code.ToUpperInvariant()
  $index=if($fieldCodesByKey.ContainsKey($Key)){[Array]::IndexOf([object[]]$fieldCodesByKey[$Key],[object]$normalized)}else{[Convert]::ToInt32($normalized,16)}
  if($index-lt0-or$index-ge$boxes[$Key].Items.Count){throw "顔テンプレートの値が一覧にありません: $Key = $Code"}
  $boxes[$Key].SelectedIndex=$index
}
function Set-Rpg3RewardCode([Windows.Forms.ComboBox]$Box,[object[]]$Codes,[string]$Code){
  if($Code-eq'0000'){$Box.SelectedIndex=0;return}
  $index=[Array]::IndexOf([object[]]$Codes,[object]$Code.ToUpperInvariant())
  if($index-lt0){throw "公式特典が一覧にありません: $Code"}
  $Box.SelectedIndex=$index+1
}
function Apply-Rpg3Template([int]$TemplateIndex){
  if($script:templateCatalogRefreshing){return}
  if($TemplateIndex-lt0-or$TemplateIndex-ge$rpg3Templates.Count){return}
  $template=$rpg3Templates[$TemplateIndex]
  if($template.ContainsKey('SavedOptions')){Apply-DenpaSavedTemplate $template 'RPG3';return}
  # Restore the stored face, rather than rewriting a template's contour through hair sync.
  $restoreHairSync=$legitimateFaceCheck.Checked
  $towerCombinationCheck.Checked=$false;$legitimateFaceCheck.Checked=$false
  Set-DenpaTemplateNames $nameLanguage $template
  foreach($entry in $template.Fields.GetEnumerator()|Where-Object{$_.Key-ne'--antenna-appearance'}){Set-Rpg3TemplateCode $entry.Key $entry.Value}
  if($template.Fields.ContainsKey('--antenna-appearance')){Set-Rpg3TemplateCode '--antenna-appearance' $template.Fields['--antenna-appearance']}
  $hairCode=[Convert]::ToInt32($template.Fields['--hair'],16);$contourCode=[Convert]::ToInt32($template.Fields['--contour'],16)
  if($restoreHairSync-and(($hairCode-eq0-and$contourCode-le11)-or($legitimateHairContourMap.ContainsKey($hairCode)-and$legitimateHairContourMap[$hairCode]-eq$contourCode))){$legitimateFaceCheck.Checked=$true}
  if(-not$template.ContainsKey('Special')){
    $script:rpg3TemplateSpecialCarrierPath=$null
    Clear-Rpg3OfficialTemplateDate
    $qrType.SelectedIndex=0
    $capturedCheck.Checked=$false
    $correctionBox.SelectedIndex=0
    if($updateRewardControls){&$updateRewardControls}
    return
  }
  if($null-eq$script:rpg3OfficialTemplateDate){$script:rpg3ManualSpecialDate=$qrDate.Value.Date}
  $script:rpg3OfficialTemplateDate=[datetime]::ParseExact($template.Date,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)
  $qrDate.Value=$script:rpg3OfficialTemplateDate
  $script:rpg3TemplateSpecialCarrierPath=$null
  $qrType.SelectedIndex=1;Set-ExtendedRewardCatalog
  $extendedSpecialCode.SelectedIndex=[Array]::IndexOf([object[]]$specialCodeValues,[object]$template.Special)
  $jewelQuantity.Value=[decimal]$template.Quantity
  Set-Rpg3RewardCode $itemRewards[0] $itemRewardCodes $template.Items[0]
  for($slot=1;$slot-le3;$slot++){Set-Rpg3RewardCode $itemRewards[$slot] $script:extendedRewardCodes[$slot] $template.Items[$slot]}
  $monsterIndex=[Array]::IndexOf([object[]]$monsterCodes,[object]$template.Monster)
  $capturedMonster.SelectedIndex=if($monsterIndex-ge0){$monsterIndex}else{0}
  $capturedCheck.Checked=($template.Monster-ne'00')
  $correctionBox.SelectedIndex=0
  if($updateRewardControls){&$updateRewardControls}
}


$displayButton = New-Object Windows.Forms.Button
$displayButton.Text = 'QR表示'
$displayButton.Font = New-Object Drawing.Font('Yu Gothic UI', 11, [Drawing.FontStyle]::Bold)
$displayButton.Location = New-Object Drawing.Point(20, 650)
$displayButton.Size = New-Object Drawing.Size(145, 48)
$form.Controls.Add($displayButton)

$saveButton = New-Object Windows.Forms.Button
$saveButton.Text = 'QR保存'
$saveButton.Font = New-Object Drawing.Font('Yu Gothic UI', 11, [Drawing.FontStyle]::Bold)
$saveButton.Location = New-Object Drawing.Point(180, 650)
$saveButton.Size = New-Object Drawing.Size(145, 48)
$saveButton.Enabled = $false
$form.Controls.Add($saveButton)

$cardButton = New-Object Windows.Forms.Button
$cardButton.Text = 'カードで保存'
$cardButton.Font = New-Object Drawing.Font('Yu Gothic UI', 11, [Drawing.FontStyle]::Bold)
$cardButton.Location = New-Object Drawing.Point(340, 650)
$cardButton.Size = New-Object Drawing.Size(145, 48)
$cardButton.Enabled = $false
$form.Controls.Add($cardButton)

$status = New-Object Windows.Forms.Label
$status.Text = '「QR表示」は保存せず画面に表示します。必要な場合だけ「QR保存」を押してください。'
$status.Location = New-Object Drawing.Point(500, 657)
$status.Size = New-Object Drawing.Size(450, 45)
$form.Controls.Add($status)

$preview = New-Object Windows.Forms.PictureBox
$preview.Name = 'qrPreview'
$preview.Location = New-Object Drawing.Point(570, 95)
$preview.Size = New-Object Drawing.Size(380, 360)
$preview.SizeMode = 'Zoom'
$preview.BorderStyle = 'FixedSingle'
$form.Controls.Add($preview)

$facePreviewLabel = New-Object Windows.Forms.Label
$facePreviewLabel.Text = '2D試験プレビュー（自動反映）'
$facePreviewLabel.Font = New-Object Drawing.Font('Yu Gothic UI', 11, [Drawing.FontStyle]::Bold)
$facePreviewLabel.AutoSize = $true
$facePreviewLabel.Location = New-Object Drawing.Point(985, 62)
$form.Controls.Add($facePreviewLabel)

$facePreview = New-Object Windows.Forms.PictureBox
$facePreview.Location = New-Object Drawing.Point(985, 95)
$facePreview.Size = New-Object Drawing.Size(255, 255)
$facePreview.SizeMode = 'Zoom'
$facePreview.BackColor = [Drawing.SystemColors]::Window
$facePreview.BorderStyle = 'FixedSingle'
$form.Controls.Add($facePreview)
$discordLink=New-Object Windows.Forms.LinkLabel
$discordLink.Name='discordServerLink'
$discordLink.Text='Discord Server'
$discordLink.AutoSize=$true
$discordLink.Font=New-Object Drawing.Font('Yu Gothic UI',11,[Drawing.FontStyle]::Regular)
$discordLink.Location=New-Object Drawing.Point(985,365)
$discordLink.Add_LinkClicked({Start-Process 'https://discord.gg/ndf'})
$form.Controls.Add($discordLink)

$statBonusGroup=New-Object Windows.Forms.Panel
$statBonusGroup.Name='statBonusGroup'
$statBonusGroup.Location=New-Object Drawing.Point(985,390)
$statBonusGroup.Size=New-Object Drawing.Size(255,265)
$form.Controls.Add($statBonusGroup)
$statBonusCaption=New-Object Windows.Forms.Label
$statBonusCaption.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Doping Fruit'}else{'ドーピングフルーツ'})
$statBonusCaption.Font=New-Object Drawing.Font('Yu Gothic UI',10,[Drawing.FontStyle]::Bold)
$statBonusCaption.AutoSize=$true
$statBonusCaption.Location=New-Object Drawing.Point(5,5)
$statBonusGroup.Controls.Add($statBonusCaption)
$statBonusControls=[ordered]@{}
$statBonusSpecs=@(
  @('--hp-bonus','さいだいHP','Max HP'),
  @('--ap-bonus','さいだいAP','Max AP'),
  @('--strength-bonus','こうげきりょく','Attack'),
  @('--defense-bonus','ぼうぎょりょく','Defend'),
  @('--speed-bonus','すばやさ','Speed'),
  @('--evade-bonus','かいひりつ','Evade')
)
for($bonusIndex=0;$bonusIndex-lt$statBonusSpecs.Count;$bonusIndex++){
  $bonusSpec=$statBonusSpecs[$bonusIndex]
  $bonusLabel=New-Object Windows.Forms.Label
  $bonusLabel.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){$bonusSpec[2]}else{$bonusSpec[1]})
  $bonusLabel.AutoSize=$true
  $bonusLabel.Location=New-Object Drawing.Point(5,(39+($bonusIndex*37)))
  $statBonusGroup.Controls.Add($bonusLabel)
  $bonusInput=New-Object Windows.Forms.NumericUpDown
  $bonusInput.Name=('statBonus_'+$bonusSpec[0].TrimStart('-').Replace('-','_'))
  $bonusInput.Minimum=0;$bonusInput.Maximum=$(if($bonusSpec[0]-eq'--evade-bonus'){50}else{9999});$bonusInput.Value=0
  $bonusInput.Location=New-Object Drawing.Point(140,(34+($bonusIndex*37)))
  $bonusInput.Size=New-Object Drawing.Size(105,27)
  $bonusInput.TextAlign='Right'
  $statBonusGroup.Controls.Add($bonusInput)
  $statBonusControls[$bonusSpec[0]]=$bonusInput
}

$sourceLevelCheck=New-Object Windows.Forms.CheckBox
$sourceLevelCheck.Name='sourceLevelCheck'
$sourceLevelCheck.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Source Level'}else{'元個体のレベル'})
$sourceLevelCheck.Checked=$false
$sourceLevelCheck.Location=New-Object Drawing.Point(5,224)
$sourceLevelCheck.Size=New-Object Drawing.Size(135,27)
$statBonusGroup.Controls.Add($sourceLevelCheck)
$sourceLevelInput=New-Object Windows.Forms.NumericUpDown
$sourceLevelInput.Name='sourceLevelInput'
$sourceLevelInput.Minimum=1;$sourceLevelInput.Maximum=199;$sourceLevelInput.Value=199
$sourceLevelInput.Enabled=$false
$sourceLevelInput.Location=New-Object Drawing.Point(140,224)
$sourceLevelInput.Size=New-Object Drawing.Size(105,27)
$sourceLevelInput.TextAlign='Right'
$statBonusGroup.Controls.Add($sourceLevelInput)
$sourceLevelCheck.Visible=$false;$sourceLevelInput.Visible=$false
. (Join-Path $PSScriptRoot 'Denpa3QrExtras.ps1')
function Get-Rpg3SourceLevel {if($sourceLevelCheck.Checked){[int]$sourceLevelInput.Value}else{199}}
function Update-Rpg3AntennaEvolution {
  $abilityCode=Get-FieldCode $boxes['--antenna']
  if(-not$abilityCode){return}
  $correction=if($correctionBox.SelectedIndex-ge0){[Convert]::ToInt32($correctionCodes[$correctionBox.SelectedIndex],16)}else{0}
  $evolution=[DenpaQrVerification.Core]::AntennaStage3([Convert]::ToInt32($abilityCode,16),(Get-Rpg3SourceLevel),$correction)
  $code='{0:X2}'-f$evolution[0]
  $index=[Array]::IndexOf([object[]]$antennaAppearanceCodes,[object]$code)
  if($index-lt0){throw ('Antenna appearance missing: '+$code)}
  $boxes['--antenna-appearance'].SelectedIndex=$index
}

$facePreviewNote = New-Object Windows.Forms.Label
$facePreviewNote.Text = "顔・輪郭・頭・体格・体色・アンテナを`r`n選択内容に合わせて自動描画します。"
$facePreviewNote.Location = New-Object Drawing.Point(985, 360)
$facePreviewNote.Size = New-Object Drawing.Size(255, 48)
$form.Controls.Add($facePreviewNote)
$facePreviewNote.Visible=$false

# 正規に生成される電波人間では、髪1以降の輪郭は髪ごとに固定される。
# 「顔パーツ一覧.xlsx」の D列（輪郭）+ E列（髪）から復元した対応表。
# 髪0だけは C列にある輪郭0～11を自由に選べる。
$legitimateHairContourMap = @{
  1=0; 2=0; 3=4; 4=0; 5=7; 6=6; 7=1; 8=0; 9=2; 10=0
  11=7; 12=2; 13=7; 14=4; 15=1; 16=3; 17=1; 18=5; 19=3; 20=0
  21=8; 22=8; 23=0; 24=0; 25=0; 26=0; 27=0; 28=1; 29=0; 30=0; 31=3
  32=1; 33=0; 34=10; 35=3; 36=0; 37=4; 38=3; 39=0
}

$towerCombinationCheck=New-Object Windows.Forms.CheckBox
$towerCombinationCheck.Name='towerCombinationCheck'
$towerCombinationCheck.Text='正規候補に絞る'
$towerCombinationCheck.AutoSize=$true
$towerCombinationCheck.Checked=$false
$towerCombinationCheck.Enabled=($null-ne$towerCompatibility)
$towerCombinationCheck.Location=New-Object Drawing.Point(20,587)
$form.Controls.Add($towerCombinationCheck)
$legitimateFaceCheck = New-Object Windows.Forms.CheckBox
$legitimateFaceCheck.Name = 'faceSyncCheck'
$legitimateFaceCheck.Text = '髪と輪郭を同期する'
$legitimateFaceCheck.AutoSize = $true
$legitimateFaceCheck.Checked = $true
$legitimateFaceCheck.Location = New-Object Drawing.Point(20, 615)
$form.Controls.Add($legitimateFaceCheck)
$definedFaceCheck = New-Object Windows.Forms.CheckBox
$definedFaceCheck.Name = 'definedFaceCheck'
$definedFaceCheck.Text = '未定義を選択しない'
$definedFaceCheck.AutoSize = $true
$definedFaceCheck.Checked = $true
$definedFaceCheck.Location = New-Object Drawing.Point(20, 643)
$form.Controls.Add($definedFaceCheck)
Format-DenpaNumericFaceChoices $boxes
$rpg3FullFaceNames=@{};$rpg3FullFaceCodes=@{}
foreach($key in @('--head-shape','--contour','--hair','--eyebrow','--eyes','--nose','--mouth','--glasses','--skin-color','--hair-color')){$rpg3FullFaceNames[$key]=@($boxes[$key].Items|ForEach-Object{[string]$_});$rpg3FullFaceCodes[$key]=@($fieldCodesByKey[$key])}

$hairContourStatus = New-Object Windows.Forms.Label
$hairContourStatus.Location = New-Object Drawing.Point(245, 587)
$hairContourStatus.Size = New-Object Drawing.Size(705, 26)
$hairContourStatus.ForeColor = [Drawing.Color]::FromArgb(55, 80, 65)
$form.Controls.Add($hairContourStatus)
$script:legitimateHairContourValid = $true

function Get-FieldCode($control) {
  $codes = $fieldCodesByKey[$control.Name]
  if ($codes) {
    if ($control.SelectedIndex -lt 0) { return '' }
    return $codes[$control.SelectedIndex]
  }
  return (($control.Text.Trim() -split '\s+', 2)[0])
}

$rpg3AllNames=@($legitimateNames);$rpg3AllPersonalityNames=@($boxes['--personality'].Items|ForEach-Object{[string]$_});$rpg3AllPersonalityCodes=@($fieldCodesByKey['--personality'])
$rpg3TowerFieldMap=@{'--contour'='createSelectFace';'--head-shape'='createSelectHead';'--eyes'='createSelectEye';'--nose'='createSelectNose';'--mouth'='createSelectMouth';'--cheeks'='createSelectCheek';'--eyebrow'='createSelectBrow';'--glasses'='createSelectGlass'}
$rpg3TowerValueOffsets=@{'--cheeks'=1;'--glasses'=1}
$rpg3TowerPersonalityFields=@(@{Key='--contour';Base=0x00},@{Key='--hair-color';Base=0x30},@{Key='--hair';Base=0x58},@{Key='--stature';Base=0x78},@{Key='--eyebrow';Base=0x8C},@{Key='--eyes';Base=0x98},@{Key='--body-color';Base=0xB0})
$script:rpg3UpdatingTowerFilter=$false;$script:rpg3TowerFilterActive=$false;$script:rpg3TowerCandidates=$null
function Update-Rpg3TowerChoices{if($script:rpg3UpdatingTowerFilter-or(-not$towerCombinationCheck.Checked-and-not$script:rpg3TowerFilterActive)){return};$script:rpg3UpdatingTowerFilter=$true;try{$candidates=Get-DenpaTowerCandidates $towerCompatibility $boxes $fieldCodesByKey $rpg3TowerFieldMap $rpg3TowerPersonalityFields $rpg3TowerValueOffsets;$script:rpg3TowerCandidates=$candidates;Set-DenpaTowerCandidateChoices $towerCombinationCheck.Checked $candidates $nameBox $rpg3AllNames $boxes['--personality'] $fieldCodesByKey '--personality' $rpg3AllPersonalityNames $rpg3AllPersonalityCodes;$script:rpg3TowerFilterActive=$towerCombinationCheck.Checked}finally{$script:rpg3UpdatingTowerFilter=$false}}
function Assert-Rpg3TowerCombination{if(-not$towerCombinationCheck.Checked){return};$candidates=Get-DenpaTowerCandidates $towerCompatibility $boxes $fieldCodesByKey $rpg3TowerFieldMap $rpg3TowerPersonalityFields $rpg3TowerValueOffsets;if($candidates.Rows.Count-eq0){throw '現在の顔パーツには、アンテナ塔で出現する正規組み合わせがありません。'};$allowedNames=@($candidates.NameIds|ForEach-Object{$rpg3AllNames[[int]$_]});if($allowedNames-notcontains$nameBox.Text){throw '現在の顔パーツからアンテナ塔で出現する名前を選択してください。'};$personalityCode=Get-FieldCode $boxes['--personality'];if($candidates.PersonalityIds-notcontains[Convert]::ToInt32($personalityCode,16)){throw '現在の顔パーツから決まる正規の性格を選択してください。'}}

function Update-Rpg3DefinedFaceChoices {
  $maximum=@{'--head-shape'=39;'--contour'=11;'--hair'=39;'--eyebrow'=19;'--eyes'=47;'--nose'=31;'--mouth'=39;'--glasses'=23;'--skin-color'=5;'--hair-color'=12}
  foreach($key in $maximum.Keys){
    $current=if($boxes[$key].SelectedIndex-ge0){$fieldCodesByKey[$key][$boxes[$key].SelectedIndex]}else{'00'}
    $names=@();$codes=@()
    for($i=0;$i-lt$rpg3FullFaceCodes[$key].Count;$i++){if(-not$definedFaceCheck.Checked-or[Convert]::ToInt32($rpg3FullFaceCodes[$key][$i],16)-le[int]$maximum[$key]){$names+=$rpg3FullFaceNames[$key][$i];$codes+=$rpg3FullFaceCodes[$key][$i]}}
    $boxes[$key].BeginUpdate();try{$boxes[$key].Items.Clear();[void]$boxes[$key].Items.AddRange([object[]]$names);$fieldCodesByKey[$key]=@($codes);$idx=[Array]::IndexOf([object[]]$codes,[object]$current);$boxes[$key].SelectedIndex=if($idx-ge0){$idx}else{0}}finally{$boxes[$key].EndUpdate()}
  }
  Update-HairContourLock
  Update-Rpg3TowerChoices
}
$definedFaceCheck.Add_CheckedChanged({Update-Rpg3DefinedFaceChoices})
$towerCombinationCheck.Add_CheckedChanged({if($towerCombinationCheck.Checked){$legitimateFaceCheck.Checked=$true;$definedFaceCheck.Checked=$true};Update-Rpg3TowerChoices})
foreach($key in @($rpg3TowerFieldMap.Keys)+@('--hair','--hair-color','--stature','--body-color')){$boxes[$key].Add_SelectedIndexChanged({Update-Rpg3TowerChoices})}

function Update-HairContourLock {
  $hairCode = [Convert]::ToInt32((Get-FieldCode $boxes['--hair']), 16)
  $contourBox = $boxes['--contour']
  $script:legitimateHairContourValid = $true

  if (-not $legitimateFaceCheck.Checked) {
    $contourBox.Enabled = $true
    $hairContourStatus.Text = '調査モード：髪と輪郭を自由に組み合わせられます。'
    $hairContourStatus.ForeColor = [Drawing.Color]::FromArgb(135, 85, 20)
    return
  }

  if ($hairCode -eq 0) {
    $contourBox.Enabled = $true
    $contourCode = [Convert]::ToInt32((Get-FieldCode $contourBox), 16)
    if ($contourCode -gt 11) { $script:legitimateHairContourValid = $false }
    $hairContourStatus.Text = if ($script:legitimateHairContourValid) {
      '髪0：輪郭0～11から選択できます。'
    } else {
      '髪0の正規輪郭は0～11です。輪郭を変更してください。'
    }
  } elseif ($legitimateHairContourMap.ContainsKey($hairCode)) {
    $contourCode = [int]$legitimateHairContourMap[$hairCode]
    $contourIndex = [Array]::IndexOf([object[]]$fieldCodesByKey['--contour'], [object]('{0:X2}' -f $contourCode))
    if ($contourIndex -lt 0) { throw "輪郭$contourCode が一覧にありません。" }
    if ($contourBox.SelectedIndex -ne $contourIndex) { $contourBox.SelectedIndex = $contourIndex }
    $contourBox.Enabled = $false
    $hairContourStatus.Text = "髪$hairCode：正規の輪郭$contourCodeを自動選択しました。"
  } else {
    $contourBox.Enabled = $false
    $script:legitimateHairContourValid = $false
    $hairContourStatus.Text = "髪$hairCode：正規組み合わせが表に未登録です。調査モードでのみ使用できます。"
  }

  $hairContourStatus.ForeColor = if ($script:legitimateHairContourValid) {
    [Drawing.Color]::FromArgb(55, 80, 65)
  } else {
    [Drawing.Color]::FromArgb(185, 45, 45)
  }
}

$script:rpg3TwoDAssetRoot = Join-Path $assetRoot 'rpg3-2d'
. (Join-Path $PSScriptRoot 'Rpg3TwoDPreview.ps1')

function New-Rpg3ModelPng([string]$OutputPath,[switch]$Transparent) {
  [void](New-Rpg3TwoDPreviewPng -OutputPath $OutputPath -Transparent:$Transparent)
  return $OutputPath
}

function Update-Rpg3ModelPreview {
  $modelPath=Join-Path ([IO.Path]::GetTempPath()) ('denpa3-live-'+[Guid]::NewGuid().ToString('N')+'.png')
  try {
    [void](New-Rpg3TwoDPreviewPng $modelPath -Transparent)
    $source=[Drawing.Image]::FromFile($modelPath)
    try{$image=New-Object Drawing.Bitmap($source)}finally{$source.Dispose()}
    if($facePreview.Image){$oldFace=$facePreview.Image;$facePreview.Image=$null;$oldFace.Dispose()}
    $facePreview.Image=$image
  } catch {
    $facePreviewNote.Text='2D試験プレビューエラー: '+$_.Exception.Message
  } finally {
    if(Test-Path -LiteralPath $modelPath){Remove-Item -LiteralPath $modelPath -Force}
  }
}

$boxes['--hair'].Add_SelectedIndexChanged({ Update-HairContourLock })
$boxes['--contour'].Add_SelectedIndexChanged({
  if ($legitimateFaceCheck.Checked -and (Get-FieldCode $boxes['--hair']) -eq '00') { Update-HairContourLock }
})
$legitimateFaceCheck.Add_CheckedChanged({ Update-HairContourLock; if($form.Visible-or$env:DENPA3_QR_EDITOR_SMOKE){$modelPreviewTimer.Stop(); $modelPreviewTimer.Start()} })
Update-Rpg3DefinedFaceChoices

$modelPreviewTimer=New-Object Windows.Forms.Timer
$modelPreviewTimer.Interval=320
$modelPreviewTimer.Add_Tick({$modelPreviewTimer.Stop();$modelPreviewTimer.Interval=320;Update-Rpg3ModelPreview})
$facePreviewKeys = @('--head-shape','--contour','--hair','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses','--skin-color','--hair-color','--body-color','--stature','--antenna')
foreach ($key in $facePreviewKeys) { $boxes[$key].Add_SelectedIndexChanged({if(-not$script:editorLanguageUpdating-and($form.Visible-or$env:DENPA3_QR_EDITOR_SMOKE)){$modelPreviewTimer.Stop();$modelPreviewTimer.Start()}}) }
if($env:DENPA3_QR_EDITOR_SMOKE){Update-Rpg3ModelPreview}elseif($env:DENPA_EDITOR_EMBED-ne'1'){$form.Add_Shown({$modelPreviewTimer.Stop();$modelPreviewTimer.Interval=50;$modelPreviewTimer.Start()})}

if ($antennaCatalog) {
  $boxes['--antenna'].Add_SelectedIndexChanged({Update-Rpg3AntennaEvolution})
}
$boxes['--antenna-appearance'].Enabled = $false
Update-Rpg3AntennaEvolution

$script:currentQrPath = $null
$script:rpg3AutoReady = $false

$markQrDirty = {
  if($script:editorLanguageUpdating){return}
  if ($script:currentQrPath) {
    $saveButton.Enabled = $false
    $cardButton.Enabled = $false
    $status.Text = '設定が変更されました。QRを自動更新しています…'
  }
  if($script:rpg3AutoReady-and($form.Visible-or$env:DENPA3_QR_EDITOR_SMOKE)){$autoQrTimer.Stop();$autoQrTimer.Start()}
}
function Get-Rpg3ProtagonistCautionMessage {
  if($env:DENPA_EDITOR_LANGUAGE-eq'English'){
    'Caution: Denpa with the “Protagonist” personality cannot use “Say Goodbye” or “Remove” after joining your party. Please be careful when loading them.'
  }else{
    '「主人公」の性格を持つ電波人間は、仲間にすると「さよならをする」「パーティから外す」ができません。読み込みにはご注意ください。'
  }
}
function Show-Rpg3ProtagonistCaution {
  $message=Get-Rpg3ProtagonistCautionMessage
  [void][Windows.Forms.MessageBox]::Show($form,$message,$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Caution'}else{'注意'}),[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Warning)
}
$script:rpg3PreviousPersonalityCode=Get-FieldCode $boxes['--personality']
$boxes['--personality'].Add_SelectedIndexChanged({
  if($boxes['--personality'].SelectedIndex-lt0){return}
  $code=Get-FieldCode $boxes['--personality'];$previous=$script:rpg3PreviousPersonalityCode
  $script:rpg3PreviousPersonalityCode=$code
  if($code-eq'64'-and$previous-ne'64'-and-not$nameLanguage.Syncing-and-not$script:rpg3UpdatingTowerFilter){Show-Rpg3ProtagonistCaution}
})
foreach ($field in $fields) {
  $control = $boxes[$field.Key]
  if ($field.Name) { $control.Add_TextChanged($markQrDirty) }
  else { $control.Add_SelectedIndexChanged($markQrDirty) }
}
foreach($language in @('EU','NA','DEU','FRA')){$nameLanguage.Boxes[$language].Add_TextChanged($markQrDirty)}
foreach($language in @('EU','DEU','FRA')){$nameLanguage.Checks[$language].Add_CheckedChanged($markQrDirty)}
$qrType.Add_SelectedIndexChanged($markQrDirty)
$edition.Add_SelectedIndexChanged($markQrDirty)
$qrDate.Add_ValueChanged({
  if($qrType.SelectedIndex-eq1-and-not$qrDate.Checked){$qrDate.Checked=$true}
  if($null-eq$script:rpg3OfficialTemplateDate){$script:rpg3ManualSpecialDate=$qrDate.Value.Date}
  & $markQrDirty
})
$jewelQuantity.Add_ValueChanged($markQrDirty)
foreach($bonusInput in $statBonusControls.Values){$bonusInput.Add_ValueChanged($markQrDirty)}
$rpg3MemoBox.Add_TextChanged($markQrDirty)
$rpg3PaintBox.Add_SelectedIndexChanged($markQrDirty)
foreach($equipmentBox in $rpg3EquipmentBoxes.Values){$equipmentBox.Add_SelectedIndexChanged($markQrDirty)}
$sourceLevelCheck.Add_CheckedChanged({$sourceLevelInput.Enabled=$sourceLevelCheck.Checked;Update-Rpg3AntennaEvolution;& $markQrDirty})
$sourceLevelInput.Add_ValueChanged({Update-Rpg3AntennaEvolution;& $markQrDirty})
for ($slotIndex = 0; $slotIndex -lt $itemRewards.Count; $slotIndex++) {
  $rewardBox = $itemRewards[$slotIndex]
  $rewardBox.Add_SelectedIndexChanged($markQrDirty)
  $rewardBox.Add_TextChanged($markQrDirty)
}
$capturedCheck.Add_CheckedChanged($markQrDirty)
$capturedMonster.Add_SelectedIndexChanged($markQrDirty)
$correctionBox.Add_SelectedIndexChanged({Update-Rpg3AntennaEvolution;& $markQrDirty})
$multiItemEvent.Add_SelectedIndexChanged($markQrDirty)
$extendedSpecialCode.Add_SelectedIndexChanged($markQrDirty)
$legitimateFaceCheck.Add_CheckedChanged($markQrDirty)
$definedFaceCheck.Add_CheckedChanged($markQrDirty)
$towerCombinationCheck.Add_CheckedChanged($markQrDirty)
$decorAllCheck.Add_CheckedChanged($markQrDirty)
$updateRewardControls = {
  if ($script:updatingEventCatalog) { return }
  $isExtendedReward = ($qrType.SelectedIndex -eq 1)
  $isJewel = $isExtendedReward
  $isItem = $isExtendedReward
  $isFurniture = $false
  $isOfficialOriginal = $false
  Set-ExtendedRewardCatalog
  $itemSlotLimit = 4
  $jewelQuantityLabel.Text = if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Jewels'}else{'ジュエル'}
  $jewelQuantity.Minimum = 0
  $jewelQuantity.Enabled = $isJewel
  $jewelQuantity.Visible = $true
  $jewelQuantityLabel.Visible = $true
  for ($slotIndex = 0; $slotIndex -lt $itemRewards.Count; $slotIndex++) {
    $rewardBox = $itemRewards[$slotIndex]
    $itemRewardLabels[$slotIndex].Text = if($env:DENPA_EDITOR_LANGUAGE-eq'English'){$(if($slotIndex-eq0){'Item'}else{'Decorate'+$slotIndex})}else{$(if($slotIndex-eq0){'アイテム'}else{'デコレ'+$slotIndex})}
    $rewardBox.Enabled = ($isItem -and $slotIndex -lt $itemSlotLimit)
    $rewardBox.Visible = $true
    $itemRewardLabels[$slotIndex].Visible = $true
  }
  $multiItemEvent.Visible = $false
  $multiItemEventLabel.Visible = $false
  $extendedSpecialCode.Visible = $true
  $extendedSpecialCodeLabel.Visible = $true
  $extendedSpecialCode.Enabled = $isExtendedReward
  $decorAllCheck.Visible = $true
  $decorAllCheck.Enabled = $isExtendedReward
  $qrDateLabel.Visible = $true
  $qrDate.Visible = $true
  $script:rpg3DateControlActive = $isExtendedReward
  if($isExtendedReward-or$null-ne$script:rpg3OfficialTemplateDate){$qrDate.Checked=$true}
  $qrDate.Enabled = ($null -eq $script:rpg3OfficialTemplateDate)
  $qrDateLabel.Text = $(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'QR Date'}else{'QR日付'})
}
$qrType.Add_SelectedIndexChanged($updateRewardControls)
$multiItemEvent.Add_SelectedIndexChanged($updateRewardControls)

$updateCapturedControls = {
  # Hardware verified: the captured-monster field works with any antenna.
  $capturedCheck.Enabled = $true
  $capturedMonster.Enabled = $true
  $qrType.Enabled = $true
  $jewelQuantity.Enabled = ($qrType.SelectedIndex -eq 1)
  $isExtendedReward = ($qrType.SelectedIndex -eq 1)
  $itemSlotLimit = if ($isExtendedReward) { 4 } else { 0 }
  for ($slotIndex = 0; $slotIndex -lt $itemRewards.Count; $slotIndex++) {
    $itemRewards[$slotIndex].Enabled = ($isExtendedReward -and $slotIndex -lt $itemSlotLimit)
  }
}
$boxes['--antenna'].Add_SelectedIndexChanged($updateCapturedControls)
$capturedCheck.Add_CheckedChanged($updateCapturedControls)
$capturedMonster.Add_SelectedIndexChanged({$capturedCheck.Checked=($capturedMonster.SelectedIndex-gt0)})
$edition.Add_SelectedIndexChanged({
  if ($edition.SelectedIndex -ne 0) {
    $status.Text = 'EU／NA版の通常QR・地域指定付き特典QR・捕獲済みモンスターQRを生成できます。'
  }
  & $updateCapturedControls
})
& $updateCapturedControls
& $updateRewardControls

$script:rpg3Generating=$false
$displayAction = {
  if($script:rpg3Generating){return}
  $script:rpg3Generating=$true
  try {
    if (-not (Test-Path -LiteralPath $backendAssembly)) { throw 'QR編集ツール本体が見つかりません。' }
    # 正規候補が0件の場合は性格欄も空になるため、16進数検査より先に
    # アンテナ塔の組み合わせとして成立するかを案内する。
    Assert-DenpaNonoGuard ([Convert]::ToInt32((Get-FieldCode $boxes['--hair']),16)) ([Convert]::ToInt32((Get-FieldCode $boxes['--eyes']),16))
    Assert-Rpg3TowerCombination
    foreach ($field in $fields | Where-Object { -not $_.Name }) {
      if ((Get-FieldCode $boxes[$field.Key]) -notmatch '^[0-9A-Fa-f]{1,2}$') { throw "$($field.Label)は16進数2桁以内で入力してください。" }
    }
    # IME入力中に一時的に空欄になっても、エラーを出さず次の更新を待つ。
    $activeNameRegion=@('JP','NA','EU')[(Get-Rpg3ActiveEditionIndex)]
    $activeName=Get-DenpaNameForRegion $nameLanguage $activeNameRegion
    if ([string]::IsNullOrWhiteSpace($activeName)) {
      $saveButton.Enabled=$false;$cardButton.Enabled=$false;$status.Text='名前を入力するとQRを自動更新します。';return
    }
    if ($legitimateFaceCheck.Checked -and -not $script:legitimateHairContourValid) {
      throw 'この髪と輪郭の正規組み合わせは未登録です。正規の値へ変更するか、「髪と輪郭を同期する」を外して調査モードにしてください。'
    }
    $carrier = Get-ActiveCarrier
    $newQrPath = Join-Path ([IO.Path]::GetTempPath()) ('denpa3-qr-' + [guid]::NewGuid().ToString('N') + '.png')
    $withCapturedMonster = ($capturedMonster.SelectedIndex -gt 0 -and $monsterCodes[$capturedMonster.SelectedIndex] -ne '00')
    if ($withCapturedMonster) {
      if ($capturedMonster.SelectedIndex -lt 0) { throw '捕獲するモンスターを選択してください。' }
    }
    $encodedItemCodes = @()
    if ($qrType.SelectedIndex -in @(2, 3, 4)) {
      $itemSlotCount = if ($qrType.SelectedIndex -eq 4) { [int]$script:activeFurnitureEvents[$multiItemEvent.SelectedIndex].MaxItems } else { 1 }
      for ($slotIndex = 0; $slotIndex -lt $itemSlotCount; $slotIndex++) {
        $rewardIndex = Get-ItemRewardIndex $itemRewards[$slotIndex]
        if ($rewardIndex -lt 0) { throw "アイテム$($slotIndex + 1)は候補一覧から選択してください。" }
        if ($rewardIndex -eq 0) { continue }
        $rewardCode = $script:activeItemRewardCodes[$rewardIndex - 1]
        if ($encodedItemCodes -contains $rewardCode) { throw '同じアイテムを複数枠へ入れても1個しか増えません。異なるアイテムを選択してください。' }
        $encodedItemCodes += $rewardCode
      }
      if (-not $encodedItemCodes.Count) { throw '付与するアイテムを1種類以上選択してください。' }
    }
    $extendedItemCode = '0000'
    $extendedFurnitureCodes = @('0000','0000','0000')
    if ($qrType.SelectedIndex -eq 1) {
      $normalRewardIndex = Get-ItemRewardIndex $itemRewards[0]
      if ($normalRewardIndex -lt 0) { throw 'アイテムは候補一覧から選択してください。' }
      if ($normalRewardIndex -gt 0) { $extendedItemCode = $itemRewardCodes[$normalRewardIndex - 1] }
      $seenFurnitureCodes = @()
      for ($furnitureSlot = 0; $furnitureSlot -lt 3; $furnitureSlot++) {
        $boxIndex = $furnitureSlot + 1
        $rewardIndex = Get-ItemRewardIndex $itemRewards[$boxIndex]
        if ($rewardIndex -lt 0) { throw "デコレ$($furnitureSlot + 1)は候補一覧から選択してください。" }
        if ($rewardIndex -eq 0) { continue }
        $rewardCode = $script:extendedRewardCodes[$boxIndex][$rewardIndex - 1]
        if ($seenFurnitureCodes -contains $rewardCode) { throw '同じ家具を複数枠へ入れても1個しか増えません。異なる家具を選択してください。' }
        $seenFurnitureCodes += $rewardCode
        $extendedFurnitureCodes[$furnitureSlot] = $rewardCode
      }
      if ($extendedItemCode -eq '0000' -and @($extendedFurnitureCodes | Where-Object { $_ -ne '0000' }).Count -eq 0 -and
          [int]$jewelQuantity.Value -eq 0 -and -not $withCapturedMonster -and
          -not($rpg3EquipmentBoxes.Values|Where-Object{$_.SelectedIndex-gt0}) -and -not$rpg3MemoBox.Text -and $rpg3PaintBox.SelectedIndex-le0) {
        throw 'ジュエル・アイテム・家具・捕獲モンスターのいずれかを設定してください。'
      }
    }
    if ($qrType.SelectedIndex -eq 0) {
      $arguments = @($editorTool, 'edit', '--carrier', $carrier, '--png', $newQrPath)
    } elseif ($qrType.SelectedIndex -eq 5) {
      $selectedOfficialOriginal = $script:activeFurnitureEvents[$multiItemEvent.SelectedIndex]
      $officialOriginalCarrier = Get-Rpg3SpecialCarrierValue $selectedOfficialOriginal.Path
      $arguments = @($editorTool, 'edit', '--carrier', $officialOriginalCarrier, '--png', $newQrPath)
    } elseif ($false) {
      $specialCarrier = Get-Rpg3SpecialCarrierValue $specialCarrierPath
      $quantity = [int]$jewelQuantity.Value
      $arguments = @(
        $editorTool, 'edit', '--carrier', $specialCarrier,
        '--character-carrier', $carrier,
        '--special-code', '33', '--special-quantity', $quantity.ToString(),
        '--special-region-mask', (Get-ActiveSpecialRegionMask),
        '--png', $newQrPath
      )
    } else {
      $selectedMultiItemEvent = if ($qrType.SelectedIndex -eq 4) { $script:activeFurnitureEvents[$multiItemEvent.SelectedIndex] } else { $null }
      $activeItemCarrierPath = if($qrType.SelectedIndex-eq1){Join-Path $dataRoot 'official-special-santa.hex'}elseif($selectedMultiItemEvent){$selectedMultiItemEvent.Path}else{$specialCarrierPath}
      if (-not $itemCatalogRows.Count) { throw 'アイテム一覧が見つかりません。' }
      $specialCarrier = Get-Rpg3SpecialCarrierValue $activeItemCarrierPath
      $isFurnitureReward = ($qrType.SelectedIndex -eq 4)
      $combinedJewelQuantity = if ($qrType.SelectedIndex -eq 1) { ([int]$jewelQuantity.Value).ToString() } else { '0' }
      $specialCode = if ($qrType.SelectedIndex -eq 1) { $specialCodeValues[$extendedSpecialCode.SelectedIndex] } elseif ($selectedMultiItemEvent) { $selectedMultiItemEvent.Code } else { '31' }
      $specialItem1 = if ($qrType.SelectedIndex -eq 1) { $extendedItemCode } elseif ($isFurnitureReward) { '0000' } elseif($encodedItemCodes.Count-ge1) { $encodedItemCodes[0] } else { '0000' }
      $specialItem2 = if ($qrType.SelectedIndex -eq 1) { $extendedFurnitureCodes[0] } elseif ($isFurnitureReward -and $encodedItemCodes.Count -ge 1) { $encodedItemCodes[0] } else { '0000' }
      $specialItem3 = if ($qrType.SelectedIndex -eq 1) { $extendedFurnitureCodes[1] } elseif ($isFurnitureReward -and $encodedItemCodes.Count -ge 2) { $encodedItemCodes[1] } else { '0000' }
      $specialItem4 = if ($qrType.SelectedIndex -eq 1) { $extendedFurnitureCodes[2] } elseif ($isFurnitureReward -and $encodedItemCodes.Count -ge 3) { $encodedItemCodes[2] } else { '0000' }
      $arguments = @(
        $editorTool, 'edit', '--carrier', $specialCarrier,
        '--character-carrier', $carrier,
        '--special-code', $specialCode, '--special-quantity', $combinedJewelQuantity,
        '--special-item', $specialItem1,
        '--special-item-2', $specialItem2,
        '--special-item-3', $specialItem3,
        '--special-item-4', $specialItem4,
        '--special-region-mask', (Get-ActiveSpecialRegionMask),
        '--png', $newQrPath
      )
    }
    if ($withCapturedMonster -and $qrType.SelectedIndex -ne 5) {
      # 捕獲IDは通常キャラクター領域0x34、特典アイテムは拡張領域
      # 0x56..0x5Dにあり、同じ160バイトQR内で重ならない。
      $arguments += @('--captured-monster', $monsterCodes[$capturedMonster.SelectedIndex])
    }
    if ($qrType.SelectedIndex -ne 5) {
      foreach ($field in $fields) {
        $value = if ($field.Name) { $activeName } else { Get-FieldCode $boxes[$field.Key] }
        $arguments += @($field.Key, $value)
      }
      $arguments += @('--correction', $correctionCodes[$correctionBox.SelectedIndex])
      foreach($bonusOption in $statBonusControls.Keys){$arguments+=@($bonusOption,([int]$statBonusControls[$bonusOption].Value).ToString([Globalization.CultureInfo]::InvariantCulture))}
      $arguments+=@('--source-level',(Get-Rpg3SourceLevel).ToString([Globalization.CultureInfo]::InvariantCulture))
      $arguments+=@(Get-DenpaAdvancedQrArguments 3)
      $arguments+=@(Get-Rpg3ExtrasArguments)
    }
    if($qrType.SelectedIndex-eq1-or$qrDate.Checked-or$null-ne$script:rpg3OfficialTemplateDate){
      $arguments += @('--qr-date',$qrDate.Value.ToString('yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture))
    }
    # Unchecked normal QRs retain their carrier timestamp (legacy behaviour).
    # Only an explicit date selection rewrites it; official dates remain fixed.
    $script:lastGenerateArguments = @($arguments)
    $status.Text = '生成中…'
    $form.Refresh()
    $result = Invoke-DenpaQrBackend -Game 3 -Arguments ([string[]]$arguments)
    if ($LASTEXITCODE -ne 0) { throw ($result -join [Environment]::NewLine) }

    if ($preview.Image) { $old = $preview.Image; $preview.Image = $null; $old.Dispose() }
    $source = [Drawing.Image]::FromFile($newQrPath)
    $preview.Image = New-Object Drawing.Bitmap($source)
    $source.Dispose()
    if ($script:currentQrPath -and (Test-Path -LiteralPath $script:currentQrPath)) {
      Remove-Item -LiteralPath $script:currentQrPath -Force
    }
    $script:currentQrPath = $newQrPath
    $saveButton.Enabled = $true
    $cardButton.Enabled = $true
    $status.Text = if ($withCapturedMonster -and $qrType.SelectedIndex -eq 1) {
      "捕獲済み「$($capturedMonster.Text)」＋特典コード$($specialCodeValues[$extendedSpecialCode.SelectedIndex])のQRを表示しました。"
    } elseif ($withCapturedMonster -and $qrType.SelectedIndex -eq 4) {
      "捕獲済み「$($capturedMonster.Text)」＋$($multiItemEvent.Text)の家具特典QRを表示しました。"
    } elseif ($withCapturedMonster -and $qrType.SelectedIndex -eq 3) {
      "捕獲済み「$($capturedMonster.Text)」＋ジュエル＋アイテム1個QRを表示しました（三者同時は実機確認待ち）。"
    } elseif ($withCapturedMonster -and $qrType.SelectedIndex -eq 2) {
      "捕獲済み「$($capturedMonster.Text)」＋アイテム1個QRを表示しました（実機確認待ち）。"
    } elseif ($withCapturedMonster -and $qrType.SelectedIndex -eq 1) {
      "捕獲済み「$($capturedMonster.Text)」＋ジュエル特典QRを表示しました（実機確認済み）。"
    } elseif ($withCapturedMonster) {
      "捕獲済み「$($capturedMonster.Text)」のQRを表示しました（まだ保存していません）。"
    } elseif ($qrType.SelectedIndex -eq 0) {
      '通常QRを表示しました（まだ保存していません）。'
    } elseif ($qrType.SelectedIndex -eq 1) {
      "特典コード$($specialCodeValues[$extendedSpecialCode.SelectedIndex])を表示しました。ジュエル・アイテム・家具を個別または同時に設定できます。"
    } elseif ($qrType.SelectedIndex -eq 3) {
      'ジュエル＋アイテム1個特典QRを表示しました（実機確認済み）。'
    } elseif ($qrType.SelectedIndex -eq 4) {
      "$($multiItemEvent.Text)の家具特典QRを表示しました。家具だけを公式枠数で設定しています。"
    } elseif ($qrType.SelectedIndex -eq 5) {
      "公式原本「$($multiItemEvent.Text)」を1バイトも変更せず表示しました。これで増えなければQR改変が原因ではありません。"
    } elseif ($qrType.SelectedIndex -eq 1) {
      "特典コード$($specialCodeValues[$extendedSpecialCode.SelectedIndex])を表示しました。ジュエル・アイテム・家具を個別または同時に設定できます。"
    } else {
      "アイテム特典「$($itemReward.Text)」を表示しました。同じセーブでは最初の1回だけ受領できます。"
    }
  } catch {
    $script:lastDisplayError=$_.Exception.Message
    if($script:lastDisplayError-match 'ENOSPC|no space left on device'){
      $script:lastDisplayError='保存先ドライブの空き容量が不足しているため、QR用の一時画像を書き込めませんでした。不要なファイルを整理してから再試行してください。アプリ専用の古い一時画像は次回起動時に自動整理されます。'
    }
    $status.Text = '生成できませんでした。'
    [Windows.Forms.MessageBox]::Show($script:lastDisplayError, 'エラー', 'OK', 'Error') | Out-Null
  } finally {
    $script:rpg3Generating=$false
  }
}
$displayButton.Add_Click($displayAction)
$script:rpg3DisplayOnClick = [Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance')
$autoQrTimer = New-Object Windows.Forms.Timer
$autoQrTimer.Interval = 260
$autoQrTimer.Add_Tick({
  $autoQrTimer.Stop()
  if(-not$script:rpg3Generating){[void]$script:rpg3DisplayOnClick.Invoke($displayButton,@([EventArgs]::Empty))}
})
$script:rpg3AutoReady = $true

function Get-Rpg3SelectedRewardText([Windows.Forms.ComboBox]$Box) {
  $index=Get-ItemRewardIndex $Box
  if($index-le0){return ''}
  $Box.Text
}

function New-Rpg3CurrentCardBundle {
  if(-not(Get-Command New-Rpg3CardBitmap -ErrorAction SilentlyContinue)){throw 'RPG3カード描画部品が見つかりません。'}
  $tempRoot=Join-Path([IO.Path]::GetTempPath())('denpa3-card-'+[Guid]::NewGuid().ToString('N'));[void](New-Item -ItemType Directory -Path $tempRoot)
  try{
    $autoQrTimer.Stop()
    $qrPaths=@{}
    foreach($region in @([pscustomobject]@{Name='JP';Index=0},[pscustomobject]@{Name='NA';Index=1},[pscustomobject]@{Name='EU';Index=2})){
      $script:rpg3CardEditionOverride=[int]$region.Index
      & $displayAction
      if(-not$saveButton.Enabled-or-not$script:currentQrPath-or-not(Test-Path -LiteralPath $script:currentQrPath)){throw "$($region.Name)版QRをカード用に生成できませんでした。"}
      $target=Join-Path $tempRoot ($region.Name+'.png');Copy-Item -LiteralPath $script:currentQrPath -Destination $target -Force;$qrPaths[$region.Name]=$target
    }
    $script:rpg3CardEditionOverride=$null;& $displayAction
    $modelPath=Join-Path $tempRoot 'model.png';[void](New-Rpg3ModelPng $modelPath -Transparent)
    $isFurniture=($qrType.SelectedIndex-eq4)
    $isExtended=($qrType.SelectedIndex-eq1)
    $decor=@('','','')
    if($isFurniture){for($i=0;$i-lt3;$i++){$decor[$i]=Get-Rpg3SelectedRewardText $itemRewards[$i]}}
    if($isExtended){for($i=0;$i-lt3;$i++){$decor[$i]=Get-Rpg3SelectedRewardText $itemRewards[$i+1]}}
    $itemText=if($isExtended){Get-Rpg3SelectedRewardText $itemRewards[0]}else{''}
    $monsterText=if($capturedMonster.SelectedIndex-gt0){$capturedMonster.Text}else{''}
    $jewelCount=if($isExtended){[int]$jewelQuantity.Value}else{0}
    $correctionText=if($correctionBox.SelectedIndex-gt0){$correctionBox.Text}else{''}
    $specialIdText=if($isExtended){$specialCodeValues[$extendedSpecialCode.SelectedIndex]}else{''}
    $cardEquipment=@{}
    foreach($slot in @('clothing','neck','back','arm','feet')){$cardEquipment[$slot]=$rpg3EquipmentBoxes['--'+$slot+'-equipment'].Text}
    $card=New-Rpg3CardBitmap -IsNormal:($qrType.SelectedIndex-eq0) -Equipment $cardEquipment -AssetRoot $assetRoot -ModelPath $modelPath -QrPaths $qrPaths -Name (Get-DenpaCardDisplayName $nameLanguage) `
      -Personality $boxes['--personality'].Text -Stature $boxes['--stature'].Text -Antenna $boxes['--antenna'].Text -Correction $correctionText `
      -SpecialId $specialIdText -Monster $monsterText -Item $itemText -Decor1 $decor[0] -Decor2 $decor[1] -Decor3 $decor[2] -JewelCount $jewelCount -IssueDate $qrDate.Value `
      -HpBonus ([int]$statBonusControls['--hp-bonus'].Value) -ApBonus ([int]$statBonusControls['--ap-bonus'].Value) `
      -AttackBonus ([int]$statBonusControls['--strength-bonus'].Value) -DefenseBonus ([int]$statBonusControls['--defense-bonus'].Value) -SpeedBonus ([int]$statBonusControls['--speed-bonus'].Value) -EvadeBonus ([int]$statBonusControls['--evade-bonus'].Value)
    [pscustomobject]@{Bitmap=$card;TempRoot=$tempRoot}
  }catch{
    $script:rpg3CardEditionOverride=$null
    if(Test-Path -LiteralPath $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}
    throw
  }finally{
    $script:rpg3CardEditionOverride=$null
    $autoQrTimer.Stop()
  }
}

$cardButton.Add_Click({
  $bundle=$null
  try{
    $status.Text='JP／NA／EUのQRと2Dプレビューをカードへ反映中…';$form.Refresh();$bundle=New-Rpg3CurrentCardBundle
    $workingArea=[Windows.Forms.Screen]::FromControl($form).WorkingArea
    $cardWindowWidth=[Math]::Min(900,[Math]::Max(620,$workingArea.Width-120))
    $cardWindowHeight=[Math]::Min(680,[Math]::Max(500,$workingArea.Height-120))
    $window=New-Object Windows.Forms.Form;$window.Icon=$form.Icon;$window.Text='RPG3 カードプレビュー';$window.ClientSize=New-Object Drawing.Size($cardWindowWidth,$cardWindowHeight);$window.MinimumSize=New-Object Drawing.Size(620,500);$window.StartPosition='CenterParent'
    $buttonPanel=New-Object Windows.Forms.Panel;$buttonPanel.Dock='Bottom';$buttonPanel.Height=52;$window.Controls.Add($buttonPanel)
    $picture=New-Object Windows.Forms.PictureBox;$picture.Dock='Fill';$picture.Padding=New-Object Windows.Forms.Padding(10);$picture.SizeMode='Zoom';$picture.Image=$bundle.Bitmap;$window.Controls.Add($picture);$picture.BringToFront();$buttonPanel.BringToFront()
    $saveCard=New-Object Windows.Forms.Button;$saveCard.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Save PNG'}else{'カードをPNG保存'});$saveCard.Location=New-Object Drawing.Point(430,9);$saveCard.Size=New-Object Drawing.Size(170,34);$buttonPanel.Controls.Add($saveCard)
    $buttonPanel.Add_Resize({$saveCard.Left=[Math]::Max(0,[int](($buttonPanel.ClientSize.Width-$saveCard.Width)/2))})
    $saveCard.Add_Click({$dialog=New-Object Windows.Forms.SaveFileDialog;$dialog.Filter='PNG画像 (*.png)|*.png';$dialog.FileName=($boxes['--name'].Text+'_RPG3カード.png');if($dialog.ShowDialog()-eq'OK'){if(Test-Path -LiteralPath $dialog.FileName){[Windows.Forms.MessageBox]::Show('安全のため既存ファイルは上書きしません。別の名前を指定してください。','保存エラー','OK','Error')|Out-Null;return};$picture.Image.Save($dialog.FileName,[Drawing.Imaging.ImageFormat]::Png);$status.Text="カードを保存しました: $($dialog.FileName)"}})
    [void]$window.ShowDialog($form);if($picture.Image){$picture.Image.Dispose();$picture.Image=$null};$window.Dispose();$status.Text='RPG3カードへ現在の設定をすべて反映しました。'
  }catch{$status.Text='カード生成に失敗しました。';[Windows.Forms.MessageBox]::Show($_.Exception.Message,'カード生成エラー','OK','Error')|Out-Null}
  finally{if($bundle-and$bundle.TempRoot-and(Test-Path -LiteralPath $bundle.TempRoot)){Remove-Item -LiteralPath $bundle.TempRoot -Recurse -Force}}
})

$saveButton.Add_Click({
  try {
    if (-not $script:currentQrPath -or -not (Test-Path -LiteralPath $script:currentQrPath)) { throw '先に「QR表示」を押してください。' }
    $save = New-Object Windows.Forms.SaveFileDialog
    $save.Filter = 'PNG image (*.png)|*.png'
    $safeName = ($boxes['--name'].Text -replace '[\\/:*?"<>|]', '_')
    $save.FileName = $safeName + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.png'
    if ($save.ShowDialog() -ne 'OK') { return }
    if (Test-Path -LiteralPath $save.FileName) { throw '安全のため既存ファイルは上書きしません。別の名前を指定してください。' }
    [IO.File]::Copy($script:currentQrPath, $save.FileName, $false)
    $status.Text = "保存しました: $($save.FileName)"
  } catch {
    [Windows.Forms.MessageBox]::Show($_.Exception.Message, '保存エラー', 'OK', 'Error') | Out-Null
  }
})

function Apply-UnifiedRpg3Layout {
  $form.BackColor=[Drawing.Color]::FromArgb(214,235,251)
  $title.Visible=$false;$codeLabel.Visible=$false;$edition.Visible=$false
  $facePreviewNote.Visible=$false;$legitimateFaceCheck.Visible=$true;$definedFaceCheck.Visible=$true;$hairContourStatus.Visible=$false
  foreach($panelSpec in @(@(20,4,320,625),@(362,4,285,625),@(666,4,585,89),@(666,103,585,361),@(666,480,585,190))){
    $panel=New-Object Windows.Forms.Panel;$panel.Location=New-Object Drawing.Point($panelSpec[0],$panelSpec[1]);$panel.Size=New-Object Drawing.Size($panelSpec[2],$panelSpec[3]);$panel.BackColor=[Drawing.Color]::FromArgb(178,255,255,255);$panel.BorderStyle='FixedSingle';$form.Controls.Add($panel);$panel.SendToBack();$panel.Visible=$false
  }
  foreach($control in @($form.Controls)){if(-not($control -is [Windows.Forms.Panel])){$control.BringToFront()}}
  $commonCaption=New-Object Windows.Forms.Label;$commonCaption.Text='顔パーツ';$commonCaption.Font=New-Object Drawing.Font('Yu Gothic UI',11,[Drawing.FontStyle]::Bold);$commonCaption.AutoSize=$true;$commonCaption.Location=New-Object Drawing.Point(42,17);$form.Controls.Add($commonCaption)
  $leftKeys=@('--antenna','--head-shape','--hair','--contour','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses','--stature','--body-color','--skin-color','--hair-color')
  for($i=0;$i-lt$leftKeys.Count;$i++){$key=$leftKeys[$i];$box=$boxes[$key];$label=$form.Controls.Find('label_'+$key,$true)[0];$y = 47 + ($i * 36);$label.Location=New-Object Drawing.Point(40,($y + 4));$box.Location=New-Object Drawing.Point(145,$y);$box.Size=New-Object Drawing.Size(170,27)}
  $faceTemplateLabel.Location=New-Object Drawing.Point(40,555);$faceTemplateBox.Location=New-Object Drawing.Point(145,551);$faceTemplateBox.Size=New-Object Drawing.Size(170,27);$towerCombinationCheck.Location=New-Object Drawing.Point(40,582);$legitimateFaceCheck.Location=New-Object Drawing.Point(40,606);$definedFaceCheck.Location=New-Object Drawing.Point(40,630)
  $boxes['--antenna-appearance'].Visible=$false;$form.Controls.Find('label_--antenna-appearance',$true)[0].Visible=$false
  $nameLabel=$form.Controls.Find('label_--name',$true)[0];$nameLabel.Text='名前';$nameLabel.Visible=$true;$nameLabel.Font=New-Object Drawing.Font('Yu Gothic UI',11,[Drawing.FontStyle]::Bold);$nameLabel.Location=New-Object Drawing.Point(690,17)
  $freeNameCheck.Visible=$false
  $personalityLabel=$form.Controls.Find('label_--personality',$true)[0];Set-DenpaNameLanguageLayout $nameLanguage $personalityLabel $boxes['--personality']
  $facePreviewLabel.Text='プレビュー';$facePreviewLabel.Location=New-Object Drawing.Point(385,17);$facePreview.Location=New-Object Drawing.Point(388,38);$facePreview.Size=New-Object Drawing.Size(233,300);$statBonusGroup.Location=New-Object Drawing.Point(378,365);$statBonusGroup.Size=New-Object Drawing.Size(255,265);$discordLink.Location=New-Object Drawing.Point(388,640)
  $editionLabel.Text='QRコード';$editionLabel.Location=New-Object Drawing.Point(690,111);$editionLabel.Visible=$true;$editionRadioPanel.Location=New-Object Drawing.Point(856,109);$editionRadioPanel.Visible=$true;$editionRadioPanel.BringToFront()
  $preview.Location=New-Object Drawing.Point(803,143);$preview.Size=New-Object Drawing.Size(310,300)
  $displayButton.Visible=$false;$saveButton.Location=New-Object Drawing.Point(1124,218);$saveButton.Size=New-Object Drawing.Size(105,48);$cardButton.Text='カード表示';$cardButton.Location=New-Object Drawing.Point(1124,282);$cardButton.Size=New-Object Drawing.Size(105,48);$status.Visible=$false
  $qrTypeLabel.Text='特典';$qrTypeLabel.Location=New-Object Drawing.Point(689,472);$qrTypeLabel.Font=New-Object Drawing.Font('Yu Gothic UI',11,[Drawing.FontStyle]::Bold)
  $qrDateLabel.Location=New-Object Drawing.Point(970,640);$qrDate.Location=New-Object Drawing.Point(1070,634);$qrDate.Size=New-Object Drawing.Size(160,27)
  $qrType.Location=New-Object Drawing.Point(809,467);$qrType.Size=New-Object Drawing.Size(140,27);$extendedSpecialCodeLabel.Text='特典ID';$extendedSpecialCodeLabel.Location=New-Object Drawing.Point(955,472);$extendedSpecialCode.Location=New-Object Drawing.Point(1040,467);$extendedSpecialCode.Size=New-Object Drawing.Size(140,27)
  $correctionLabel.Location=New-Object Drawing.Point(689,511);$correctionBox.Location=New-Object Drawing.Point(763,505);$correctionBox.Size=New-Object Drawing.Size(181,27)
  $jewelQuantityLabel.Location=New-Object Drawing.Point(959,550);$jewelQuantity.Location=New-Object Drawing.Point(1060,544);$jewelQuantity.Size=New-Object Drawing.Size(70,27)
  $itemRewardLabel.Text='アイテム';$itemRewardLabel.Location=New-Object Drawing.Point(689,550);$itemReward.Location=New-Object Drawing.Point(763,544);$itemReward.Size=New-Object Drawing.Size(181,27)
  $capturedCheck.Text='モンスター';$capturedCheck.Location=New-Object Drawing.Point(959,511);$capturedMonster.Location=New-Object Drawing.Point(1043,505);$capturedMonster.Size=New-Object Drawing.Size(139,27)
  for($i=1;$i-lt$itemRewards.Count;$i++){$slotX = 754 + (($i - 1) * 203);$itemRewardLabels[$i].Text=('デコレ'+$i);$itemRewardLabels[$i].Location=New-Object Drawing.Point(($slotX-65),589);$itemRewards[$i].Location=New-Object Drawing.Point($slotX,583);$itemRewards[$i].Size=New-Object Drawing.Size($(if($i-eq3){108}else{126}),27)}
  $decorAllCheck.Location=New-Object Drawing.Point(689,615);$decorAllCheck.Visible=$true
  $multiItemEventLabel.Visible=$false;$multiItemEvent.Visible=$false
  &$updateRewardControls
}
if($env:DENPA_EDITOR_EMBED-eq'1'){Apply-UnifiedRpg3Layout}
$statBonusGroup.Height=330
$rpg3EquipmentGroup.Location=New-Object Drawing.Point(680,670)
$form.AutoScroll=$true
if($env:DENPA_EDITOR_EMBED-eq'1'){
  $statBonusGroup.Height=264
  $discordLink.Location=New-Object Drawing.Point(388,640)
  $rpg3OptionsScroll=New-Object Windows.Forms.Panel
  $rpg3OptionsScroll.Name='rpg3OptionsScroll';$rpg3OptionsScroll.AutoScroll=$true
  $rpg3OptionsScroll.Location=New-Object Drawing.Point(680,462)
  $rpg3OptionsScroll.Size=New-Object Drawing.Size(580,190)
  $rpg3OptionsScroll.BackColor=$form.BackColor
  $rpg3EquipmentGroup.Size=New-Object Drawing.Size(548,115)
  $rpg3EquipmentTitle.Location=New-Object Drawing.Point(10,0)
  $slotIndex=0
  foreach($key in $rpg3EquipmentBoxes.Keys){
    $box=$rpg3EquipmentBoxes[$key]
    $positionIndex=$slotIndex+1
    $row=[int][Math]::Floor($positionIndex/3)
    $box.Location=New-Object Drawing.Point((10+180*($positionIndex%3)),(26+58*$row))
    $box.Width=170;$slotIndex++
  }
  $slotIndex=0
  foreach($label in @($rpg3EquipmentGroup.Controls|Where-Object{$_-is[Windows.Forms.Label]-and$_-ne$rpg3EquipmentTitle})){
    $positionIndex=$slotIndex+1;$row=[int][Math]::Floor($positionIndex/3)
    $label.Location=New-Object Drawing.Point((10+180*($positionIndex%3)),(58*$row));$slotIndex++
  }
  for($i=1;$i-lt$itemRewards.Count;$i++){
    $slotX=745+188*($i-1);$itemRewardLabels[$i].Left=$slotX-65;$itemRewards[$i].Left=$slotX
  }
  $scrollControls=@($qrTypeLabel,$qrType,$extendedSpecialCodeLabel,$extendedSpecialCode,
    $correctionLabel,$correctionBox,$capturedCheck,$capturedMonster,
    $itemRewardLabel,$itemReward,$jewelQuantityLabel,$jewelQuantity,
    $decorAllCheck,$qrDateLabel,$qrDate,$rpg3EquipmentGroup)
  for($i=1;$i-lt$itemRewards.Count;$i++){$scrollControls+=@($itemRewardLabels[$i],$itemRewards[$i])}
  $rpg3OptionsScroll.SuspendLayout()
  foreach($control in $scrollControls){
    $position=New-Object Drawing.Point(($control.Left-680),($control.Top-462))
    $rpg3OptionsScroll.Controls.Add($control);$control.Location=$position
  }
  # Local scroll order: correction/monster, equipment, QR type/ID, rewards/date.
  foreach($control in @($correctionLabel,$correctionBox,$capturedCheck,$capturedMonster)){$control.Top-=38}
  $rpg3EquipmentGroup.Top=78
  foreach($control in @($qrTypeLabel,$qrType,$extendedSpecialCodeLabel,$extendedSpecialCode)){$control.Top+=192}
  foreach($control in @($itemRewardLabel,$itemReward,$jewelQuantityLabel,$jewelQuantity)){$control.Top+=154}
  for($i=1;$i-lt$itemRewards.Count;$i++){
    $columnX=10+180*($i-1)
    $itemRewardLabels[$i].Location=New-Object Drawing.Point($columnX,280)
    $itemRewards[$i].Location=New-Object Drawing.Point($columnX,306)
    $itemRewards[$i].Size=New-Object Drawing.Size(170,27)
  }
  $decorAllCheck.Location=New-Object Drawing.Point(10,338)
  $qrDateLabel.Location=New-Object Drawing.Point(290,371)
  $qrDate.Location=New-Object Drawing.Point(290,397)
  $qrDate.Width=250
  $form.Controls.Add($rpg3OptionsScroll);$rpg3OptionsScroll.ResumeLayout($true)
  # Top row: correction, monster, paint. Captions above all three selectors.
  $correctionLabel.Location=New-Object Drawing.Point(10,11)
  $correctionBox.Location=New-Object Drawing.Point(10,40);$correctionBox.Width=170
  $rpg3OptionsScroll.Controls.Add($capturedLabel);$capturedLabel.Location=New-Object Drawing.Point(190,11)
  $capturedMonster.Location=New-Object Drawing.Point(190,40);$capturedMonster.Width=170
  $capturedCheck.Visible=$false
  $rpg3OptionsScroll.Controls.Add($rpg3PaintPanel);$rpg3PaintPanel.Location=New-Object Drawing.Point(370,11);$rpg3PaintPanel.Size=New-Object Drawing.Size(170,56)
  $rpg3PaintLabel.Location=New-Object Drawing.Point(0,0)
  $rpg3PaintBox.Location=New-Object Drawing.Point(0,29);$rpg3PaintBox.Width=170
  $rpg3OptionsScroll.Controls.Add($rpg3MemoLabel);$rpg3MemoLabel.Location=New-Object Drawing.Point(9,$qrDateLabel.Top)
  $rpg3OptionsScroll.Controls.Add($rpg3MemoBox);$rpg3MemoBox.Location=New-Object Drawing.Point(9,$qrDate.Top);$rpg3MemoBox.Width=260
  # Leave a full text-row gap after the second equipment row.
  foreach($control in @($rpg3OptionsScroll.Controls)){if($control.Top-ge197){$control.Top+=30}}
  $form.AutoScroll=$false
  $discordLink.BringToFront()
}
if(-not$env:DENPA3_QR_EDITOR_SMOKE-and$env:DENPA_EDITOR_EMBED-ne'1'){$form.Add_Shown({$autoQrTimer.Stop();$autoQrTimer.Interval=50;$autoQrTimer.Start()})}
$script:nonoSelectionGuard=Register-DenpaNonoSelectionGuard $boxes {[Convert]::ToInt32((Get-FieldCode $boxes['--hair']),16);[Convert]::ToInt32((Get-FieldCode $boxes['--eyes']),16)}

if($env:DENPA3_QR_EDITOR_SMOKE-eq'paint'){
  if($rpg3PaintBox.Items.Count-ne34){throw 'Paint color catalog count failed'}
  $boxes['--body-color'].SelectedIndex=7;$rpg3PaintBox.SelectedIndex=5
  $qrType.SelectedIndex=0;& $displayAction
  if(-not$saveButton.Enabled){throw ('Normal paint generation failed: '+$status.Text)}
  $normal=Get-DenpaDebugInitial 3 0
  if($normal[0x2c]-ne7-or$normal[0x2f]-ne9){throw 'Normal paint mismatch'}
  $qrType.SelectedIndex=1;$jewelQuantity.Value=0;foreach($reward in $itemRewards){$reward.SelectedIndex=0};$capturedCheck.Checked=$false;& $displayAction
  if(-not$saveButton.Enabled){throw ('Paint-only special generation failed: '+$status.Text)}
  $special=Get-DenpaDebugInitial 3 1
  if($special[0x2c]-ne7-or$special[0x2f]-ne9){throw 'Special paint mismatch'}
  $saved=Get-DenpaCurrentTemplate 'RPG3';$rpg3PaintBox.SelectedIndex=0;Apply-DenpaSavedTemplate $saved 'RPG3'
  if($rpg3PaintBox.SelectedIndex-ne5){throw 'Paint template restore failed'}
  Set-Rpg3PaintLanguage 'English'
  if($rpg3PaintLabel.Text-ne'Paint'-or$rpg3PaintBox.Items[5]-ne'Orange'-or$rpg3PaintBox.Items[9]-ne'Red / Light Blue'){throw 'Paint translation failed'}
  Set-Rpg3PaintLanguage 'Japanese'
  foreach($length in @(88,160)){if((Get-DenpaDebugByteLabel 3 $length 47 $false)-notmatch'ペイント状態'){throw 'Debug paint label failed'}}
  foreach($format in @('generated3:normal-jp','generated:santa')){
    foreach($color in @(255)+(0..32)){
      $values=New-Object 'Collections.Generic.Dictionary[string,string]';$values['--carrier']=$format;$values['--paint-color']='{0:X2}'-f$color
      $payload=[DenpaQrVerification.Core]::Edit(3,$values)
      $plain=[DenpaQrVerification.Core]::Plain(3,[DenpaQrVerification.Core]::Hex($payload))
      $expected=if($color-eq255){0}else{($color-shl1)-bor1}
      if($plain[0x2f]-ne$expected){throw "Paint candidate encoding failed: color=$color actual=$($plain[0x2f]) expected=$expected format=$format"}
    }
  }
  $qrType.SelectedIndex=0;$rpg3PaintBox.SelectedIndex=0;& $displayAction
  if((Get-DenpaDebugInitial 3 0)[0x2f]-ne0){throw 'Paint clearing failed'}
  $autoQrTimer.Stop();$modelPreviewTimer.Stop();Write-Output 'GUI_RPG3_PAINT_NORMAL_SPECIAL_68_VALUES_TEMPLATE_LANGUAGE_DEBUG_CLEAR_OK';$form.Dispose();return
}
if($env:DENPA3_QR_EDITOR_SMOKE-eq'evade'){
  if($statBonusControls['--evade-bonus'].Maximum-ne50){throw 'Evade UI maximum failed'}
  foreach($format in @('generated3:normal-jp','generated:santa')){
    foreach($value in @(0,1,49,50)){
      $values=New-Object 'Collections.Generic.Dictionary[string,string]';$values['--carrier']=$format;$values['--evade-bonus']=[string]$value
      $payload=[DenpaQrVerification.Core]::Edit(3,$values)
      $plain=[DenpaQrVerification.Core]::Plain(3,[DenpaQrVerification.Core]::Hex($payload))
      if([BitConverter]::ToUInt16($plain,0x42)-ne$value){throw 'Evade two-byte encoding failed'}
    }
    $values['--evade-bonus']='51';$rejected=$false
    try{[void][DenpaQrVerification.Core]::Edit(3,$values)}catch{$rejected=$true}
    if(-not$rejected){throw 'Evade over-limit accepted'}
  }
  $statBonusControls['--evade-bonus'].Value=50
  foreach($type in @(0,1)){
    $qrType.SelectedIndex=$type;$jewelQuantity.Value=1;& $displayAction
    if(-not$saveButton.Enabled-or[BitConverter]::ToUInt16((Get-DenpaDebugInitial 3 $type),0x42)-ne50){throw ('Evade GUI generation failed: '+$status.Text)}
  }
  $saved=Get-DenpaCurrentTemplate 'RPG3';$statBonusControls['--evade-bonus'].Value=0;Apply-DenpaSavedTemplate $saved 'RPG3'
  if($statBonusControls['--evade-bonus'].Value-ne50){throw 'Evade template restore failed'}
  $saved.SavedOptions.Bonuses.Remove('--evade-bonus');Apply-DenpaSavedTemplate $saved 'RPG3'
  if($statBonusControls['--evade-bonus'].Value-ne0){throw 'Old template Evade default failed'}
  $qrType.SelectedIndex=0;$capturedCheck.Checked=$false;$capturedMonster.SelectedIndex=1;& $displayAction
  if(-not$capturedMonster.Enabled-or(Get-DenpaDebugInitial 3 0)[0x34]-ne[Convert]::ToInt32($monsterCodes[1],16)){throw 'Monster without checkbox failed'}
  $capturedMonster.SelectedIndex=0;& $displayAction
  if((Get-DenpaDebugInitial 3 0)[0x34]-ne0){throw 'Monster none clearing failed'}
  foreach($length in @(88,160)){foreach($at in @(66,67)){
    if((Get-DenpaDebugByteLabel 3 $length $at $false)-notmatch'かいひりつ\(2バイト\)' -or(Get-DenpaDebugByteLabel 3 $length $at $true)-notmatch'Evade \(2 bytes\)'){throw 'Evade debug label failed'}
  }}
  $autoQrTimer.Stop();$modelPreviewTimer.Stop();Write-Output 'GUI_RPG3_EVADE_NORMAL_SPECIAL_LIMIT_TEMPLATE_DEBUG_MONSTER_OK';$form.Dispose();return
}
if($env:DENPA3_QR_EDITOR_SMOKE-eq'memo-equipment'){
  $expected=@(847,978,1054,905,1157);$keys=@('--neck-equipment','--arm-equipment','--feet-equipment','--back-equipment','--clothing-equipment')
  for($i=0;$i-lt5;$i++){$ids=@(0)+@($rpg3EquipmentRows[$keys[$i]]|ForEach-Object{[int]$_.internal_id});$ix=[Array]::IndexOf([object[]]$ids,[object]$expected[$i]);if($ix-lt1){throw 'Equipment ID missing'};$rpg3EquipmentBoxes[$keys[$i]].SelectedIndex=$ix}
  $rpg3MemoBox.Text='たちつてとなにぬねのはひふへほま'
  $qrType.SelectedIndex=0;& $displayAction
  if(-not$saveButton.Enabled-or$rpg3MemoBox.Enabled-or$script:lastGenerateArguments-contains'--memo'){throw ('Normal extras failed: '+$status.Text)}
  $normal=Get-DenpaDebugInitial 3 0
  for($i=0;$i-lt5;$i++){if([BitConverter]::ToUInt16($normal,0x44+2*$i)-ne$expected[$i]){throw 'Normal equipment mismatch'}}
  $qrType.SelectedIndex=1;$jewelQuantity.Value=0;foreach($reward in $itemRewards){$reward.SelectedIndex=0};$capturedCheck.Checked=$false;& $displayAction
  if(-not$saveButton.Enabled-or-not$rpg3MemoBox.Enabled){throw ('Special equipment-only failed: '+$status.Text)}
  $special=Get-DenpaDebugInitial 3 1
  if([Text.Encoding]::Unicode.GetString($special,0x78,32)-ne$rpg3MemoBox.Text){throw 'Special memo mismatch'}
  for($i=0;$i-lt5;$i++){if([BitConverter]::ToUInt16($special,0x44+2*$i)-ne$expected[$i]){throw 'Special equipment mismatch'}}
  $saved=Get-DenpaCurrentTemplate 'RPG3';$rpg3MemoBox.Clear();foreach($box in $rpg3EquipmentBoxes.Values){$box.SelectedIndex=0};Apply-DenpaSavedTemplate $saved 'RPG3'
  if($rpg3MemoBox.Text-ne'たちつてとなにぬねのはひふへほま'){throw 'Template memo restore failed'}
  for($i=0;$i-lt5;$i++){if([int]$rpg3EquipmentRows[$keys[$i]][$rpg3EquipmentBoxes[$keys[$i]].SelectedIndex-1].internal_id-ne$expected[$i]){throw 'Template equipment restore failed'}}
  Set-Rpg3EquipmentLanguage 'English';Set-Rpg3EquipmentLanguage 'Japanese'
  if((Get-DenpaDebugByteLabel 3 160 120 $false)-notmatch'メモ'-or(Get-DenpaDebugByteLabel 3 88 68 $false)-notmatch'首装備'){throw 'Debug label failed'}
  $autoQrTimer.Stop();$modelPreviewTimer.Stop();$form.Opacity=0;$form.Show();[Windows.Forms.Application]::DoEvents()
  $shot=New-Object Drawing.Bitmap($form.Width,$form.Height)
  try{$form.DrawToBitmap($shot,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$shot.Save([IO.Path]::GetFullPath('outputs/tests/rpg3-memo-equipment-ui.png'),[Drawing.Imaging.ImageFormat]::Png)}finally{$shot.Dispose()}
  $form.Hide();Write-Output 'GUI_RPG3_NORMAL_SPECIAL_MEMO_EQUIPMENT_TEMPLATE_LANGUAGE_DEBUG_OK';$form.Dispose();return
}
if($env:DENPA3_QR_EDITOR_SMOKE-eq'tower-filter'){
  foreach($entry in @{'--contour'='00';'--head-shape'='1E';'--eyes'='04';'--nose'='00';'--mouth'='00';'--cheeks'='00';'--eyebrow'='09';'--glasses'='00';'--hair'='00';'--hair-color'='00';'--stature'='00';'--body-color'='00'}.GetEnumerator()){$index=[Array]::IndexOf([object[]]$fieldCodesByKey[$entry.Key],[object]$entry.Value);if($index-lt0){throw "RPG3 regular smoke value missing: $($entry.Key)"};$boxes[$entry.Key].SelectedIndex=$index}
  $towerCombinationCheck.Checked=$true
  if(-not$legitimateFaceCheck.Checked-or-not$definedFaceCheck.Checked-or$towerCombinationCheck.Text-ne'正規候補に絞る'-or$towerCombinationCheck.Top-ge$legitimateFaceCheck.Top-or$script:rpg3TowerCandidates.Rows.Count-ne1-or[int]$script:rpg3TowerCandidates.Rows[0]-ne0-or$nameBox.Items.Count-ge$rpg3AllNames.Count-or$boxes['--personality'].Items.Count-ne1-or$boxes['--personality'].Text-ne'にがうり'){throw "RPG3 regular-candidate filtering failed: rows=$($script:rpg3TowerCandidates.Rows -join ',') names=$($nameBox.Items.Count) personalities=$($boxes['--personality'].Items.Count) selected=$($boxes['--personality'].Text)"}
  $headOne=[Array]::IndexOf([object[]]$fieldCodesByKey['--head-shape'],[object]'01');$boxes['--head-shape'].SelectedIndex=$headOne;if((Get-FieldCode $boxes['--head-shape'])-ne'01'-or(Get-FieldCode $boxes['--glasses'])-ne'00'){throw 'RPG3 regular-candidate filter changed prioritized face parts.'};$boxes['--head-shape'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--head-shape'],[object]'1E')
  Assert-Rpg3TowerCombination
  $nameBox.Text='正規候補外テスト';$failed=$false;try{Assert-Rpg3TowerCombination}catch{$failed=$true};if(-not$failed){throw 'RPG3 antenna-tower generation validation failed.'}
  $towerCombinationCheck.Checked=$false
  if($nameBox.Items.Count-ne1917-or$boxes['--personality'].Items.Count-ne14){throw 'RPG3 antenna-tower free-selection restore failed.'}
  Write-Output 'GUI_RPG3_REGULAR_CANDIDATE_FILTER_OK row=0 personality=にがうり';if($facePreview.Image){$facePreview.Image.Dispose()};$form.Dispose();return
}

$form.Add_FormClosed({
  $autoQrTimer.Stop(); $autoQrTimer.Dispose()
  $modelPreviewTimer.Stop(); $modelPreviewTimer.Dispose()
  if ($preview.Image) { $preview.Image.Dispose() }
  if ($facePreview.Image) { $facePreview.Image.Dispose() }
  if ($script:currentQrPath -and (Test-Path -LiteralPath $script:currentQrPath)) { Remove-Item -LiteralPath $script:currentQrPath -Force }
})
if ($env:DENPA3_QR_EDITOR_SMOKE -eq 'source-level') {
  if($sourceLevelCheck.Checked-or$sourceLevelInput.Enabled-or(Get-Rpg3SourceLevel)-ne199){throw 'Source level default failed.'}
  if($sourceLevelInput.Maximum-ne199-or$sourceLevelInput.Minimum-ne1-or$sourceLevelInput.Bottom-gt$statBonusGroup.Height){throw 'Source level bounds/layout failed.'}
  $boxes['--antenna'].SelectedIndex=[Array]::IndexOf([object[]]$antennaAbilityCodes,[object]'14')
  $sourceLevelCheck.Checked=$true;$sourceLevelInput.Value=1
  if(-not$sourceLevelInput.Enabled-or(Get-FieldCode $boxes['--antenna-appearance'])-ne'01'){throw 'Root appearance failed.'}
  $sourceLevelInput.Value=10
  if((Get-FieldCode $boxes['--antenna-appearance'])-ne'30'){throw 'Stage 1 appearance failed.'}
  $sourceLevelInput.Value=77
  if((Get-FieldCode $boxes['--antenna-appearance'])-ne'30'){throw 'Normal threshold changed.'}
  $correctionBox.SelectedIndex=8
  if((Get-FieldCode $boxes['--antenna-appearance'])-ne'31'){throw 'Early Maturation threshold failed.'}
  $correctionBox.SelectedIndex=7
  if((Get-FieldCode $boxes['--antenna-appearance'])-ne'30'){throw 'Other correction applied early maturation.'}
  $correctionBox.SelectedIndex=8;$sourceLevelInput.Value=7
  if((Get-FieldCode $boxes['--antenna-appearance'])-ne'01'){throw 'Early Maturation changed first-stage threshold.'}
  $correctionBox.SelectedIndex=0
  $sourceLevelInput.Value=80
  if((Get-FieldCode $boxes['--antenna-appearance'])-ne'31'){throw 'Stage 2 appearance failed.'}
  $saved=Get-DenpaCurrentTemplate 'RPG3'
  $sourceLevelCheck.Checked=$false
  Apply-DenpaSavedTemplate $saved 'RPG3'
  if(-not$sourceLevelCheck.Checked-or$sourceLevelInput.Value-ne80-or(Get-FieldCode $boxes['--antenna-appearance'])-ne'31'){throw 'Source level template restore failed.'}
  $sourceLevelCheck.Checked=$false
  $boxes['--antenna'].SelectedIndex=[Array]::IndexOf([object[]]$antennaAbilityCodes,[object]'2C')
  if((Get-FieldCode $boxes['--antenna-appearance'])-ne'B5'){throw 'Stage 4 appearance failed.'}
  & $displayAction
  $ix=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--source-level')
  if($ix-lt0-or$script:lastGenerateArguments[$ix+1]-ne'199'-or-not$saveButton.Enabled){throw 'Source level generation failed.'}
  $sourceLevelCheck.Checked=$true;$sourceLevelInput.Value=35
  & $displayAction
  $ix=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--source-level')
  if($script:lastGenerateArguments[$ix+1]-ne'35'-or-not$saveButton.Enabled){throw 'Checked level generation failed.'}
  $sourceLevelCheck.Checked=$false
  $sourceLevelInput.Value=199
  $autoQrTimer.Stop();$modelPreviewTimer.Stop()
  $form.Opacity=0;$form.Show();[Windows.Forms.Application]::DoEvents()
  $form.CreateControl()
  $snapshot=New-Object Drawing.Bitmap $form.Width,$form.Height
  try{$form.DrawToBitmap($snapshot,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$snapshot.Save((Join-Path (Get-Location) 'outputs/tests/rpg3-source-level-ui.png'),[Drawing.Imaging.ImageFormat]::Png)}finally{$snapshot.Dispose()}
  $form.Hide()
  Write-Output 'GUI_RPG3_SOURCE_LEVEL_DEFAULT_ROOT_STAGE4_TEMPLATE_AND_GENERATION_OK'
  $form.Dispose();return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq 'region-click') {
  foreach($entry in @(@('NA',1,1),@('EU',2,2),@('JP',0,0))){
    $radio=$editionRadios[[int]$entry[2]];$radio.Checked=$true
    $deadline=[DateTime]::UtcNow.AddSeconds(8);while(($autoQrTimer.Enabled-or$script:rpg3Generating)-and[DateTime]::UtcNow-lt$deadline){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 20}
    if(-not$radio.Checked-or$edition.SelectedIndex-ne[int]$entry[1]-or$autoQrTimer.Enabled-or$script:rpg3Generating-or-not$saveButton.Enabled){throw "RPG3 region click failed: region=$($entry[0]) checked=$($radio.Checked) edition=$($edition.SelectedIndex) expected=$($entry[1]) timer=$($autoQrTimer.Enabled) generating=$script:rpg3Generating save=$($saveButton.Enabled) status=$($status.Text) error=$script:lastDisplayError"}
  }
  Write-Output 'GUI_RPG3_REGION_CLICK_JP_NA_EU_OK';$form.Dispose();return
}

if ($env:DENPA3_QR_EDITOR_SMOKE -eq 'card') {
  $script:advancedQrState=@{Level=$null;Unknown=@{'--qr-special-meta-5e'=255;'--qr-special-meta-5f'=255;'--qr-meta-2b'=0}}
  $qrType.SelectedIndex=1
  if((@(Get-DenpaAdvancedQrArguments 3)-join' ')-match'--qr-special-meta-5[ef]'){throw 'Retired language/region overrides still applied'}
  $copied=Copy-DenpaAdvancedQrState $script:advancedQrState
  if($copied.Unknown.Count-ne1-or-not$copied.Unknown.ContainsKey('--qr-meta-2b')){throw 'Advanced old-state migration failed'}
  Show-DenpaAdvancedQrSettings 'RPG3'
  if(@($script:advancedQrWindow.Controls|Where-Object{$_.Text-match'0x5[EF]'}).Count){throw 'Known language/region fields remain in advanced UI'}
  $script:advancedQrWindow.Close();$script:advancedQrState=@{Level=$null;Unknown=@{}}
  if($correctionBox.Items.Count-ne9-or$correctionBox.Items[0]-ne'(なし)'-or$correctionBox.Items[5]-ne'しゅんそく！'-or$correctionBox.Items[6]-ne'かいひめいじん！'-or$correctionBox.Items[7]-ne'アンテナへんか！'-or$correctionBox.Items[8]-ne'そうじゅく！'){throw 'Correction dropdown smoke test failed.'}
  $statBonusControls['--evade-bonus'].Value=50;$capturedMonster.SelectedIndex=1
  $correctionBox.SelectedIndex=7;$qrType.SelectedIndex=1;$multiItemEvent.SelectedIndex=3
  $itemRewards[0].SelectedIndex=1+[Array]::IndexOf([object[]]$itemRewardCodes,[object]'0028')
  $itemRewards[1].SelectedIndex=1+[Array]::IndexOf([object[]]$decorFurnitureCodes,[object]'0231')
  $itemRewards[2].SelectedIndex=1+[Array]::IndexOf([object[]]$decorFloorCodes,[object]'02CF')
  $itemRewards[3].SelectedIndex=1+[Array]::IndexOf([object[]]$decorWallCodes,[object]'0304')
  $originalEdition=$edition.SelectedIndex;$bundle=New-Rpg3CurrentCardBundle;if($edition.SelectedIndex-ne$originalEdition){throw 'RPG3 card generation changed the visible region selection.'}
  try{
    $previewOutputRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\previews'));[IO.Directory]::CreateDirectory($previewOutputRoot)|Out-Null
    $previewOutput=Join-Path $previewOutputRoot 'RPG3-card-auto-smoke.png';$bundle.Bitmap.Save($previewOutput,[Drawing.Imaging.ImageFormat]::Png)
    if($bundle.Bitmap.Width-ne1280-or$bundle.Bitmap.Height-ne1009-or-not(Test-Path -LiteralPath $previewOutput)-or(Get-Item $previewOutput).Length-lt100000){throw 'RPG3 automatic card render smoke test failed.'}
    Write-Output('GUI_RPG3_AUTO_CARD_OK '+$previewOutput)
  }finally{$bundle.Bitmap.Dispose();if(Test-Path -LiteralPath $bundle.TempRoot){Remove-Item -LiteralPath $bundle.TempRoot -Recurse -Force}}
  $qrType.SelectedIndex=0;$capturedCheck.Checked=$true;$capturedMonster.SelectedIndex=1
  $gearIds=@{ '--clothing-equipment'=1157;'--neck-equipment'=847;'--back-equipment'=905;'--arm-equipment'=978;'--feet-equipment'=1054 }
  foreach($key in $gearIds.Keys){$codes=@($rpg3EquipmentRows[$key]|ForEach-Object{[int]$_.internal_id});$rpg3EquipmentBoxes[$key].SelectedIndex=1+[Array]::IndexOf($codes,$gearIds[$key])}
  foreach($key in $statBonusControls.Keys){$statBonusControls[$key].Value=[Math]::Min(123,$statBonusControls[$key].Maximum)}
  foreach($language in @('Japanese','English')){
    $env:DENPA_EDITOR_LANGUAGE=$language;Set-Rpg3ContentLanguage $language
    $bundle=New-Rpg3CurrentCardBundle
    try{
      $previewOutput=Join-Path $previewOutputRoot ('RPG3-card-normal-equipment-'+$language+'.png')
      $bundle.Bitmap.Save($previewOutput,[Drawing.Imaging.ImageFormat]::Png)
      if($bundle.Bitmap.Width-ne1280-or$bundle.Bitmap.Height-ne1009){throw 'Normal card size changed'}
      Write-Output ('GUI_RPG3_NORMAL_EQUIPMENT_CARD_OK '+$previewOutput)
    }finally{$bundle.Bitmap.Dispose();if(Test-Path -LiteralPath $bundle.TempRoot){Remove-Item -LiteralPath $bundle.TempRoot -Recurse -Force}}
  }
  $qrType.SelectedIndex=1
  foreach($language in @('Japanese','English')){
    $env:DENPA_EDITOR_LANGUAGE=$language;Set-Rpg3ContentLanguage $language
    $bundle=New-Rpg3CurrentCardBundle
    try{$previewOutput=Join-Path $previewOutputRoot ('RPG3-card-special-evade-'+$language+'.png');$bundle.Bitmap.Save($previewOutput,[Drawing.Imaging.ImageFormat]::Png);Write-Output ('GUI_RPG3_SPECIAL_EVADE_CARD_OK '+$previewOutput)}finally{$bundle.Bitmap.Dispose();if(Test-Path -LiteralPath $bundle.TempRoot){Remove-Item -LiteralPath $bundle.TempRoot -Recurse -Force}}
  }
  if($preview.Image){$preview.Image.Dispose();$preview.Image=$null};if($facePreview.Image){$facePreview.Image.Dispose();$facePreview.Image=$null};$form.Dispose();return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq '2d-antennas') {
  $legitimateFaceCheck.Checked=$false
  $antennaAssetRoot=Join-Path $script:rpg3TwoDAssetRoot 'antennas'
  if((Get-ChildItem -LiteralPath $antennaAssetRoot -File -Filter '*.png').Count-lt84){throw 'RPG3 2D antenna asset count failed.'}
  if((Get-Rpg3TwoDAntennaYOffset 8)-ne-40-or(Get-Rpg3TwoDAntennaYOffset 20)-ne20){throw 'RPG3 2D antenna head offset mapping failed.'}
  foreach($antennaId in @(1,2,3,4,11,21,26,27,28,29,30,31,33,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,75,76,77,78,81,82,83,87,88,93,99)){if((Get-Rpg3TwoDAntennaArtworkYOffset $antennaId)-ne-20){throw("RPG3 2D generated antenna offset mapping failed: "+$antennaId)}}
  if((Get-Rpg3TwoDAntennaArtworkYOffset 32)-ne-10){throw 'RPG3 2D poison-signal offset mapping failed.'}
  foreach($antennaId in @(6,10,13,14,15,16,17,18,19)){if((Get-Rpg3TwoDAntennaArtworkYOffset $antennaId)-ne0){throw("RPG3 2D original antenna was moved unexpectedly: "+$antennaId)}}
  foreach($entry in @{'--head-shape'='08';'--contour'='00';'--hair'='00';'--eyebrow'='01';'--eyes'='00';'--nose'='01';'--mouth'='00';'--cheeks'='01';'--glasses'='00';'--body-color'='01';'--skin-color'='03';'--hair-color'='00'}.GetEnumerator()){
    $index=[Array]::IndexOf([object[]]$fieldCodesByKey[$entry.Key],[object]$entry.Value)
    if($index-lt0){throw("2D antenna smoke value missing: "+$entry.Key+'='+$entry.Value)}
    $boxes[$entry.Key].SelectedIndex=$index
  }
  $previewOutputRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\qr'));[IO.Directory]::CreateDirectory($previewOutputRoot)|Out-Null
  $boxes['--antenna'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--antenna'],[object]'00')
  $withoutAntenna=Join-Path $previewOutputRoot 'rpg3-2d-antenna-none-head08.png';[void](New-Rpg3TwoDPreviewPng $withoutAntenna)
  $boxes['--antenna'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--antenna'],[object]'2C')
  $withAntenna=Join-Path $previewOutputRoot 'rpg3-2d-antenna-fireball-head08.png';[void](New-Rpg3TwoDPreviewPng $withAntenna)
  if((Get-FileHash -LiteralPath $withoutAntenna -Algorithm SHA256).Hash-eq(Get-FileHash -LiteralPath $withAntenna -Algorithm SHA256).Hash){throw 'RPG3 2D antenna artwork was not composited.'}
  foreach($antennaCode in @('0A','0D','0E','0F','10','11','12','13')){
    $antennaIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--antenna'],[object]$antennaCode)
    if($antennaIndex-lt0){throw("RPG3 2D restored antenna code missing: "+$antennaCode)}
    $boxes['--antenna'].SelectedIndex=$antennaIndex
    $restoredOutput=Join-Path $previewOutputRoot ('rpg3-2d-antenna-restored-'+$antennaCode+'.png');[void](New-Rpg3TwoDPreviewPng $restoredOutput)
    if((Get-FileHash -LiteralPath $withoutAntenna -Algorithm SHA256).Hash-eq(Get-FileHash -LiteralPath $restoredOutput -Algorithm SHA256).Hash){throw("RPG3 2D restored antenna artwork was not composited: "+$antennaCode)}
  }
  Write-Output("GUI_RPG3_2D_ANTENNAS_OK image=$withAntenna assets="+(Get-ChildItem -LiteralPath $antennaAssetRoot -File -Filter '*.png').Count)
  if($facePreview.Image){$facePreview.Image.Dispose();$facePreview.Image=$null};$form.Dispose();return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq '2d-colored-parts') {
  $legitimateFaceCheck.Checked=$false
  if($boxes['--hair'].Items[37]-ne'37'-or$boxes['--hair'].Items[38]-ne'38'-or$boxes['--hair'].Items[39]-ne'39'){
    throw ('RPG3 hair 37-39 must be shown as implemented entries: '+$boxes['--hair'].Items[37]+' / '+$boxes['--hair'].Items[38]+' / '+$boxes['--hair'].Items[39])
  }
  $coloredHairRoot=Join-Path $script:rpg3TwoDAssetRoot 'hairs-colored'
  $coloredMouthRoot=Join-Path $script:rpg3TwoDAssetRoot 'mouths-colored'
  if((Get-ChildItem -LiteralPath $coloredHairRoot -File -Recurse -Filter '*.png').Count-ne494){throw 'RPG3 colored hair asset count failed.'}
  if((Get-ChildItem -LiteralPath $coloredMouthRoot -File -Recurse -Filter '*.png').Count-ne39){throw 'RPG3 colored mouth asset count failed.'}
  if(-not(Test-Path -LiteralPath (Join-Path $script:rpg3TwoDAssetRoot 'hairs-common\28.png'))){throw 'RPG3 common hair 28 asset is missing.'}

  foreach($entry in @{'--head-shape'='00';'--contour'='00';'--hair'='10';'--eyebrow'='01';'--eyes'='00';'--nose'='01';'--mouth'='00';'--cheeks'='01';'--glasses'='00';'--body-color'='01';'--skin-color'='03';'--hair-color'='00'}.GetEnumerator()){
    $index=[Array]::IndexOf([object[]]$fieldCodesByKey[$entry.Key],[object]$entry.Value)
    if($index-lt0){throw("2D colored-parts smoke value missing: "+$entry.Key+'='+$entry.Value)}
    $boxes[$entry.Key].SelectedIndex=$index
  }
  $previewOutputRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\qr'));[IO.Directory]::CreateDirectory($previewOutputRoot)|Out-Null
  $hairBlack=Join-Path $previewOutputRoot 'rpg3-2d-colored-hair16-black.png';[void](New-Rpg3TwoDPreviewPng $hairBlack)
  $boxes['--hair-color'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--hair-color'],[object]'06')
  $hairBlue=Join-Path $previewOutputRoot 'rpg3-2d-colored-hair16-blue.png';[void](New-Rpg3TwoDPreviewPng $hairBlue)
  if((Get-FileHash -LiteralPath $hairBlack -Algorithm SHA256).Hash-eq(Get-FileHash -LiteralPath $hairBlue -Algorithm SHA256).Hash){throw 'RPG3 colored hair images did not change with hair color.'}

  $boxes['--hair'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--hair'],[object]'1C')
  $boxes['--hair-color'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--hair-color'],[object]'00')
  $hair28Black=Join-Path $previewOutputRoot 'rpg3-2d-common-hair28-black.png';[void](New-Rpg3TwoDPreviewPng $hair28Black)
  $boxes['--hair-color'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--hair-color'],[object]'06')
  $hair28Blue=Join-Path $previewOutputRoot 'rpg3-2d-common-hair28-blue.png';[void](New-Rpg3TwoDPreviewPng $hair28Blue)
  if((Get-FileHash -LiteralPath $hair28Black -Algorithm SHA256).Hash-ne(Get-FileHash -LiteralPath $hair28Blue -Algorithm SHA256).Hash){throw 'RPG3 hair 28 must remain identical for every hair color.'}

  $boxes['--hair'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--hair'],[object]'00')
  $boxes['--mouth'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--mouth'],[object]'19')
  $boxes['--hair-color'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--hair-color'],[object]'00')
  $mouthBlack=Join-Path $previewOutputRoot 'rpg3-2d-colored-mouth25-black.png';[void](New-Rpg3TwoDPreviewPng $mouthBlack)
  $boxes['--hair-color'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--hair-color'],[object]'06')
  $mouthBlue=Join-Path $previewOutputRoot 'rpg3-2d-colored-mouth25-blue.png';[void](New-Rpg3TwoDPreviewPng $mouthBlue)
  if((Get-FileHash -LiteralPath $mouthBlack -Algorithm SHA256).Hash-eq(Get-FileHash -LiteralPath $mouthBlue -Algorithm SHA256).Hash){throw 'RPG3 colored mouth images did not change with hair color.'}
  Write-Output("GUI_RPG3_2D_COLORED_PARTS_OK hair=$hairBlue common=$hair28Blue mouth=$mouthBlue")
  if($facePreview.Image){$facePreview.Image.Dispose();$facePreview.Image=$null};$form.Dispose();return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq '2d-palette') {
  $legitimateFaceCheck.Checked=$false
  foreach($entry in @{'--head-shape'='00';'--contour'='00';'--hair'='02';'--eyebrow'='01';'--eyes'='00';'--nose'='01';'--mouth'='00';'--cheeks'='01';'--glasses'='10';'--body-color'='01';'--skin-color'='03';'--hair-color'='06'}.GetEnumerator()){
    $index=[Array]::IndexOf([object[]]$fieldCodesByKey[$entry.Key],[object]$entry.Value)
    if($index-lt0){throw("2D palette smoke value missing: "+$entry.Key+'='+$entry.Value)}
    $boxes[$entry.Key].SelectedIndex=$index
  }
  $previewOutputRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\qr'));[IO.Directory]::CreateDirectory($previewOutputRoot)|Out-Null
  $singleOutput=Join-Path $previewOutputRoot 'rpg3-2d-single-color-test.png'
  [void](New-Rpg3TwoDPreviewPng $singleOutput)
  $single=[Drawing.Bitmap]::FromFile($singleOutput)
  try{
    $red=0;$blue=0;$skin=0
    for($y=0;$y-lt$single.Height;$y+=3){for($x=0;$x-lt$single.Width;$x+=3){$pixel=$single.GetPixel($x,$y);$hex=('{0:X2}{1:X2}{2:X2}'-f$pixel.R,$pixel.G,$pixel.B);if($hex-eq'D7090C'){$red++};if($hex-eq'0059FF'){$blue++};if($hex-eq'CB8964'){$skin++}}}
    if($red-lt50-or$blue-lt10-or$skin-lt20){throw("2D single-color recolor failed: body=$red hair=$blue skin=$skin")}
  }finally{$single.Dispose()}
  $boxes['--body-color'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--body-color'],[object]'08')
  $stripedOutput=Join-Path $previewOutputRoot 'rpg3-2d-striped-color-test.png'
  [void](New-Rpg3TwoDPreviewPng $stripedOutput)
  $striped=[Drawing.Bitmap]::FromFile($stripedOutput)
  try{
    $red=0;$lightBlue=0
    for($y=0;$y-lt$striped.Height;$y+=3){for($x=0;$x-lt$striped.Width;$x+=3){$pixel=$striped.GetPixel($x,$y);$hex=('{0:X2}{1:X2}{2:X2}'-f$pixel.R,$pixel.G,$pixel.B);if($hex-eq'D7090C'){$red++};if($hex-eq'30D0F0'){$lightBlue++}}}
    if($red-lt20-or$lightBlue-lt20){throw("2D striped recolor failed: primary=$red secondary=$lightBlue")}
  }finally{$striped.Dispose()}
  foreach($mouthCode in @('19','1A','1B')){
    $boxes['--mouth'].SelectedIndex=[Array]::IndexOf([object[]]$fieldCodesByKey['--mouth'],[object]$mouthCode)
    $mouthOutput=Join-Path $previewOutputRoot ('rpg3-2d-hair-color-mouth-'+$mouthCode+'.png')
    [void](New-Rpg3TwoDPreviewPng $mouthOutput)
    $mouthProbe=[Drawing.Bitmap]::FromFile($mouthOutput)
    try{
      $hairColored=0;$outlineBlack=0
      for($y=295;$y-lt350;$y++){for($x=250;$x-lt350;$x++){$pixel=$mouthProbe.GetPixel($x,$y);$hex=('{0:X2}{1:X2}{2:X2}'-f$pixel.R,$pixel.G,$pixel.B);if($hex-eq'0059FF'){$hairColored++};if($hex-eq'000000'){$outlineBlack++}}}
      if($hairColored-lt5-or$outlineBlack-lt5){throw("2D hair-colored mouth failed: code=$mouthCode fill=$hairColored outline=$outlineBlack")}
    }finally{$mouthProbe.Dispose()}
  }
  Write-Output("GUI_RPG3_2D_PALETTE_OK single=$singleOutput striped=$stripedOutput")
  if($facePreview.Image){$facePreview.Image.Dispose();$facePreview.Image=$null};$form.Dispose();return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq 'face-preview') {
  if (-not $facePreview.Image) { throw 'Live 2D preview image was not created.' }
  $previewOutputRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\qr'))
  [IO.Directory]::CreateDirectory($previewOutputRoot) | Out-Null
  $previewOutput = Join-Path $previewOutputRoot 'rpg3-live-2d-preview-default.png'
  $facePreview.Image.Save($previewOutput, [Drawing.Imaging.ImageFormat]::Png)
  Write-Output ('GUI_LIVE_2D_PREVIEW_OK ' + $previewOutput)
  $facePreview.Image.Dispose(); $facePreview.Image = $null
  $form.Dispose()
  return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq 'hair-contour') {
  if (-not $legitimateFaceCheck.Checked) { throw 'Legitimate hair/contour mode should be enabled by default.' }
  if($legitimateFaceCheck.Text-ne'髪と輪郭を同期する'){throw 'RPG3 hair/contour wording failed.'}
  if($boxes['--hair'].Top-ge$boxes['--contour'].Top){throw 'RPG3 hair must be displayed above contour.'}
  if ((Get-FieldCode $boxes['--hair']) -ne '14' -or (Get-FieldCode $boxes['--contour']) -ne '00' -or $boxes['--contour'].Enabled) {
    throw 'Default hair 20 / contour 0 lock failed.'
  }
  $boxes['--hair'].SelectedIndex = 3
  if ((Get-FieldCode $boxes['--contour']) -ne '04' -or $boxes['--contour'].Enabled -or -not $script:legitimateHairContourValid) {
    throw 'Hair 3 / contour 4 lock failed.'
  }
  $boxes['--hair'].SelectedIndex = 7
  if ((Get-FieldCode $boxes['--contour']) -ne '01') { throw 'Hair 7 / contour 1 lock failed.' }
  $boxes['--hair'].SelectedIndex = 0
  if (-not $boxes['--contour'].Enabled -or -not $script:legitimateHairContourValid) { throw 'Hair 0 contour selection should be enabled.' }
  $definedFaceCheck.Checked=$false
  $boxes['--contour'].SelectedIndex = [Array]::IndexOf([object[]]$fieldCodesByKey['--contour'],[object]'0C')
  if ($script:legitimateHairContourValid) { throw 'Hair 0 / bug contour should be rejected in legitimate mode.' }
  $boxes['--contour'].SelectedIndex = [Array]::IndexOf([object[]]$fieldCodesByKey['--contour'],[object]'0B')
  if (-not $script:legitimateHairContourValid) { throw 'Hair 0 / contour 11 should be legitimate.' }
  $definedFaceCheck.Checked=$true
  $boxes['--hair'].SelectedIndex = 28
  if (-not $script:legitimateHairContourValid -or $boxes['--contour'].Enabled -or (Get-FieldCode $boxes['--contour']) -ne '01') { throw 'Hair 28 / contour 1 lock failed.' }
  $legitimateFaceCheck.Checked = $false
  if (-not $boxes['--contour'].Enabled -or -not $script:legitimateHairContourValid) { throw 'Research mode should unlock contour.' }
  Write-Output 'GUI_HAIR_CONTOUR_LOCK_OK'
  if ($facePreview.Image) { $facePreview.Image.Dispose(); $facePreview.Image = $null }
  $form.Dispose()
  return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq 'name-catalog') {
  if ($legitimateNames.Count -ne 1917) { throw "RPG3 legitimate-name count mismatch: $($legitimateNames.Count)" }
  if ($boxes['--name'] -isnot [Windows.Forms.ComboBox] -or $boxes['--name'].DropDownStyle -ne 'DropDown') {
    throw 'RPG3 name field must allow both list selection and direct input.'
  }
  if ($boxes['--name'].Text -ne 'つかさ') { throw 'Default legitimate name selection failed.' }
  foreach ($expectedName in @('るか','つかさ','りりあ')) {
    if (-not $boxes['--name'].Items.Contains($expectedName)) { throw "Legitimate name is missing: $expectedName" }
  }
  $boxes['--name'].Text = '自由名テスト'
  if ($boxes['--name'].DropDownStyle -ne 'DropDown' -or $boxes['--name'].Text -ne '自由名テスト') { throw 'Free-name input mode failed.' }
  if($freeNameCheck.Visible){throw 'Legacy free-name checkbox must be hidden.'}
  if($faceTemplateBox.Items.Count-ne10-or$faceTemplateBox.Items[4]-ne'ハント(公式)'-or$faceTemplateBox.Items[9]-ne'さんた(公式)'){throw 'RPG3 official template catalog failed.'}
  $faceTemplateBox.SelectedIndex=2
  if($boxes['--name'].Text-ne'まさじ'-or$boxes['--personality'].Text-ne'トウガラシ'-or$boxes['--head-shape'].Text-ne'よこまる'-or$boxes['--eyes'].Text-ne'43'){throw 'RPG3 Masaji face template failed.'}
  $faceTemplateBox.SelectedIndex=3
  if($boxes['--name'].Text-ne'ゆかり'-or$boxes['--antenna'].Text-ne'アンテナなし'-or$boxes['--head-shape'].SelectedIndex-ne0x1C-or$boxes['--hair'].SelectedIndex-ne0x1B-or$boxes['--eyes'].SelectedIndex-ne0x1C-or$boxes['--stature'].SelectedIndex-ne0-or$boxes['--personality'].Text-ne'トウガラシ'-or$qrType.SelectedIndex-ne0){throw 'RPG3 Yukari normal-QR face template failed.'}
  $faceTemplateBox.SelectedIndex=4
  if($nameBox.Text-ne'ハント'-or$qrType.SelectedIndex-ne1-or$extendedSpecialCode.Text-notmatch'^32'-or-not$capturedCheck.Checked-or$monsterCodes[$capturedMonster.SelectedIndex]-ne'67'-or-not$script:rpg3TemplateSpecialCarrierPath.EndsWith('official-special-hunt.hex')-or$qrDate.Value.ToString('yyyy-MM-dd')-ne'2013-08-07'-or$qrDate.Enabled-or$qrDateLabel.Text-ne'QR日付'){throw 'RPG3 Hunt official special template/date failed.'}
  $faceTemplateBox.SelectedIndex=7
  if($nameBox.Text-ne'キキ'-or$extendedSpecialCode.Text-notmatch'^35'-or$script:extendedRewardCodes[1][$itemRewards[1].SelectedIndex-1]-ne'029A'-or$script:extendedRewardCodes[2][$itemRewards[2].SelectedIndex-1]-ne'02D0'-or$script:extendedRewardCodes[3][$itemRewards[3].SelectedIndex-1]-ne'0305'-or$qrDate.Value.ToString('yyyy-MM-dd')-ne'2013-10-31'){throw 'RPG3 Kiki official furniture template/date failed.'}
  foreach($officialCheck in @(@(5,'じいや','33','2013-08-07'),@(6,'ジャック','34','2013-10-23'),@(8,'ルドルフ','36','2013-12-13'),@(9,'さんた','37','2013-12-24'))){
    $faceTemplateBox.SelectedIndex=[int]$officialCheck[0]
    if($nameBox.Text-ne$officialCheck[1]-or$extendedSpecialCode.Text-notmatch('^'+$officialCheck[2])-or$qrDate.Value.ToString('yyyy-MM-dd')-ne$officialCheck[3]-or$qrDate.Enabled){throw("RPG3 official template/date failed: "+$officialCheck[1])}
  }
  &$displayAction
  $officialCarrierIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--carrier')
  $expectedOfficialCarrier=Get-Rpg3SpecialCarrierValue (Join-Path $dataRoot 'official-special-santa.hex')
  if($officialCarrierIndex-lt0-or$script:lastGenerateArguments[$officialCarrierIndex+1]-ne$expectedOfficialCarrier-or$script:lastGenerateArguments-contains'--qr-date'){
    throw 'RPG3 official template generation did not preserve the original Santa carrier date.'
  }
  Write-Output 'GUI_NAME_CATALOG_OK male=1000 female=917 total=1917'
  if ($facePreview.Image) { $facePreview.Image.Dispose(); $facePreview.Image = $null }
  $form.Dispose()
  return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq 'generate') {
  if($qrType.Items.Count-ne2-or$qrType.Items[0]-ne'通常QR'-or$qrType.Items[1]-ne'特典QR'){throw 'RPG3 QR type simplification failed.'}
  $code31Index=[Array]::IndexOf([object[]]$specialCodeValues,[object]'31');$code33Index=[Array]::IndexOf([object[]]$specialCodeValues,[object]'33');if($extendedSpecialCode.Items.Count-ne255-or$specialCodeValues.Count-ne255-or$specialCodeValues[0]-ne'01'-or$specialCodeValues[-1]-ne'FF'-or$specialCodeLabels[$code31Index]-ne'31'-or$specialCodeLabels[$code33Index]-notmatch'じいや'-or($specialCodeLabels|Where-Object{$_-match'検証枠'})){throw 'RPG3 special-code dropdown/name mapping failed.'}
  if($monsterNames.Count-ne166-or$monsterCodes[0]-ne'00'-or$monsterNames[0]-ne'(なし)'-or$monsterCodes[-1]-ne'A5'-or$monsterNames[-1]-ne'アンテナなし(クラッシュ)'){throw 'RPG3 capture-monster none/crash slot failed.'}
  if($itemRewardNames|Where-Object{$_-like'検証枠*'}){throw 'RPG3 item probe slots were retained.'}
  foreach($variantBase in $itemVariantBases){foreach($variantColor in $itemVariantColors){if($itemRewardNames-notcontains("$variantBase（$variantColor）")){throw("RPG3 coloured item label is missing: $variantBase（$variantColor）")}}}
  $redPaintIndex=[Array]::IndexOf([object[]]$itemRewardNames,[object]'ペイントざい（赤）');$localizedRed=@(Get-Rpg3LocalizedRewardNames @($itemRewardCodes[$redPaintIndex]) @($itemRewardNames[$redPaintIndex]) 'English');if($redPaintIndex-lt0-or$localizedRed[0]-notmatch'\(Red\)$'){throw 'RPG3 English coloured-item suffix failed.'}
  if($itemRewardNames-notcontains'クローバー'-or$decorWallCodes-notcontains'0315'-or$decorAllCodes-notcontains'0315'-or$decorAllCodes-contains'01F5'-or$decorAllCodes-contains'01FE'){throw 'RPG3 clover/Coliseum/roof Decorate correction failed.'}
  $regionalRow=@($nameLanguage.Rows|Where-Object JP -eq 'つかさ'|Select-Object -First 1)[0];Sync-DenpaNameLanguageRow $nameLanguage $regionalRow
  $edition.SelectedIndex=2;Set-DenpaEuLanguage $nameLanguage 'DEU';& $displayAction
  $regionalNameIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--name');if($regionalNameIndex-lt0-or$script:lastGenerateArguments[$regionalNameIndex+1]-ne[string]$regionalRow.DEU){throw 'EU/German QR did not encode the German name.'}
  Set-DenpaEuLanguage $nameLanguage 'EU';& $displayAction
  $regionalNameIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--name');if($regionalNameIndex-lt0-or$script:lastGenerateArguments[$regionalNameIndex+1]-ne[string]$regionalRow.EU){throw 'EU/English QR did not encode the English name.'}
  $statBonusControls['--hp-bonus'].Value=100;$statBonusControls['--ap-bonus'].Value=200;$statBonusControls['--strength-bonus'].Value=300;$statBonusControls['--defense-bonus'].Value=400;$statBonusControls['--speed-bonus'].Value=9999
  $edition.SelectedIndex=0;& $displayAction
  if(-not$preview.Image-or-not$saveButton.Enabled-or-not$cardButton.Enabled){throw 'RPG3 normal QR generation or save/card button activation failed.'}
  foreach($expect in @(@('--hp-bonus','100'),@('--ap-bonus','200'),@('--strength-bonus','300'),@('--defense-bonus','400'),@('--speed-bonus','9999'))){$idx=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]$expect[0]);if($idx-lt0-or$script:lastGenerateArguments[$idx+1]-ne$expect[1]){throw("RPG3 permanent-bonus argument mismatch: "+$expect[0])}}
  if($script:lastGenerateArguments-contains'--qr-date'){throw 'RPG3 normal QR unexpectedly overwrote the authentic carrier timestamp.'}
  if($extendedSpecialCode.Enabled-or$extendedSpecialCode.Width-ne105-or$jewelQuantityLabel.Text-ne'ジュエル'-or$jewelQuantity.Enabled-or($itemRewards|Where-Object{$_.Enabled})-or$script:rpg3DateControlActive){throw ("RPG3 always-present disabled special controls failed: codeEnabled=$($extendedSpecialCode.Enabled), width=$($extendedSpecialCode.Width), jewelLabel=$($jewelQuantityLabel.Text), jewelEnabled=$($jewelQuantity.Enabled), rewardEnabled=$(@($itemRewards|ForEach-Object{$_.Enabled})-join','), dateActive=$($script:rpg3DateControlActive)")}
  $qrType.SelectedIndex=1;$extendedSpecialCode.SelectedIndex=[Array]::IndexOf([object[]]$specialCodeValues,[object]'38');$jewelQuantity.Value=5
  if(-not$extendedSpecialCode.Enabled-or-not$jewelQuantity.Enabled-or($itemRewards|Where-Object{-not$_.Enabled})-or-not$script:rpg3DateControlActive-or-not$qrDate.Enabled-or$qrDateLabel.Text-ne'QR日付'){throw("RPG3 special controls/date were not enabled: active=$($script:rpg3DateControlActive) enabled=$($qrDate.Enabled) label=$($qrDateLabel.Text) official=$($script:rpg3OfficialTemplateDate)")}
  $qrDate.Value=[datetime]'2030-01-02'
  $itemRewards[0].SelectedIndex=1+[Array]::IndexOf([object[]]$itemRewardCodes,[object]'0028')
  $itemRewards[1].SelectedIndex=1+[Array]::IndexOf([object[]]$decorFurnitureCodes,[object]'0231')
  $itemRewards[2].SelectedIndex=1+[Array]::IndexOf([object[]]$decorFloorCodes,[object]'02CF')
  $itemRewards[3].SelectedIndex=1+[Array]::IndexOf([object[]]$decorWallCodes,[object]'0304')
  & $displayAction
  foreach($expect in @(@('--special-code','38'),@('--special-quantity','5'),@('--special-item','0028'),@('--special-item-2','0231'),@('--special-item-3','02CF'),@('--special-item-4','0304'))){$idx=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]$expect[0]);if($idx-lt0-or$script:lastGenerateArguments[$idx+1]-ne$expect[1]){throw("RPG3 special argument mismatch: "+$expect[0])}}
  $dateArg=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--qr-date');if($dateArg-lt0-or$script:lastGenerateArguments[$dateArg+1]-ne'2030-01-02'){throw 'RPG3 manual special date argument failed.'}
  $extendedSpecialCode.SelectedIndex=$extendedSpecialCode.Items.Count-1;& $displayAction;$idx=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--special-code');if($idx-lt0-or$script:lastGenerateArguments[$idx+1]-ne'FF'){throw 'RPG3 codeFF (decimal 255) generation failed.'}
  if(-not$script:rpg3AutoReady-or-not$autoQrTimer){throw 'RPG3 instant QR timer is unavailable.'}
  $oldNose=$boxes['--nose'].SelectedIndex;$boxes['--nose'].SelectedIndex=($oldNose+1)%$boxes['--nose'].Items.Count;$modelPreviewTimer.Stop();if(-not$autoQrTimer.Enabled-or$saveButton.Enabled-or$cardButton.Enabled){throw 'RPG3 part change did not disable save/card buttons and schedule instant QR update.'};$deadline=[DateTime]::UtcNow.AddSeconds(8);while(($autoQrTimer.Enabled-or-not$saveButton.Enabled-or-not$cardButton.Enabled)-and[DateTime]::UtcNow-lt$deadline){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 25};if($autoQrTimer.Enabled-or-not$saveButton.Enabled-or-not$cardButton.Enabled){throw("RPG3 scheduled instant QR update did not reactivate save/card buttons. status="+$status.Text+" error="+$script:lastDisplayError)}
  Write-Output 'GUI_RPG3_NORMAL_AND_SPECIAL_INSTANT_QR_OK'
  Write-Output 'GUI_RPG3_SPECIAL_CODES_01_TO_FF_AND_ALL_REWARDS_OK'
  if($preview.Image){$preview.Image.Dispose();$preview.Image=$null};if($facePreview.Image){$facePreview.Image.Dispose();$facePreview.Image=$null};$form.Dispose();return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq 'generate-legacy') {
  $expectedDefaults = @{
    '--antenna-appearance'='18'; '--head-shape'='25'; '--contour'='00'; '--hair'='14';
    '--eyebrow'='0E'; '--eyes'='17'; '--nose'='1B'; '--mouth'='01'; '--cheeks'='03';
    '--glasses'='00'; '--stature'='03'; '--body-color'='07'; '--skin-color'='01';
    '--hair-color'='08'; '--personality'='01'; '--antenna'='08'
  }
  if ($boxes['--name'].Text -ne 'つかさ') { throw 'Default name smoke test failed.' }
  if ($qrType.Items.Count -ne 7 -or $qrType.Items[3] -notmatch 'ジュエル＋アイテム1個' -or $qrType.Items[4] -notmatch '家具特典QR' -or $qrType.Items[5] -notmatch '公式原本' -or $qrType.Items[6] -notmatch 'コード38～255・全報酬') { throw 'Reward QR type smoke test failed.' }
  for ($slotIndex = 1; $slotIndex -lt $itemRewards.Count; $slotIndex++) {
    if ($itemRewards[$slotIndex].Top -le ($itemRewards[$slotIndex - 1].Bottom + 4)) { throw 'Item selector rows overlap.' }
  }
  if ($itemRewards[3].Bottom -ge $displayButton.Top) { throw 'Last item selector overlaps the action buttons.' }
  foreach ($entry in $expectedDefaults.GetEnumerator()) {
    if ((Get-FieldCode $boxes[$entry.Key]) -ne $entry.Value) { throw "Default mapping smoke test failed: $($entry.Key)" }
  }
  if ($boxes['--antenna-appearance'].Text -notmatch 'みんなふっかつ$') { throw 'Default antenna appearance label smoke test failed.' }
  if ($boxes['--antenna-appearance'].Enabled) { throw 'Antenna appearance must be locked.' }
  if ($boxes['--head-shape'].Text -ne 'わっか') { throw 'Default ring head label smoke test failed.' }
  if ($boxes['--stature'].Text -ne '0準大' -or $boxes['--body-color'].Text -ne '白' -or $boxes['--skin-color'].Text -ne '1') { throw 'Default body mapping smoke test failed.' }
  $boxes['--glasses'].SelectedIndex = 0x17
  if ((Get-FieldCode $boxes['--glasses']) -ne '17') { throw 'Face-equipment name/code mapping smoke test failed.' }
  $boxes['--glasses'].SelectedIndex = 0
  $boxes['--body-color'].SelectedIndex = 0x1E
  if ($boxes['--body-color'].Text -ne '銀' -or (Get-FieldCode $boxes['--body-color']) -ne '1E') { throw 'Body-color silver mapping smoke test failed.' }
  $boxes['--body-color'].SelectedIndex = 0x20
  if ($boxes['--body-color'].Text -ne '桃' -or (Get-FieldCode $boxes['--body-color']) -ne '20') { throw 'Body-color peach mapping smoke test failed.' }
  $boxes['--body-color'].SelectedIndex = 0x06
  $boxes['--stature'].SelectedIndex = 0x1D
  if ($boxes['--stature'].Text -ne '10最大' -or (Get-FieldCode $boxes['--stature']) -ne '1D') { throw 'Stature mapping smoke test failed.' }
  $boxes['--stature'].SelectedIndex = 0x04
  $boxes['--hair-color'].SelectedIndex = 0x0D
  if ($boxes['--hair-color'].Text -ne '未定義(13)' -or (Get-FieldCode $boxes['--hair-color']) -ne '0D') { throw 'Hair-color undefined mapping smoke test failed.' }
  $boxes['--hair-color'].SelectedIndex = 0x01
  $boxes['--personality'].SelectedIndex = 0x04
  if ($boxes['--personality'].Text -ne 'レモン' -or (Get-FieldCode $boxes['--personality']) -ne '04') { throw 'Personality hidden-code mapping smoke test failed.' }
  $boxes['--personality'].SelectedIndex = 0
  if ($headOptions.Count -ne 41 -or $headOptions[40] -ne 'クラッシュ(未定義40)') { throw 'Head undefined mapping smoke test failed.' }
  $definedFaceCheck.Checked=$false
  if ($boxes['--contour'].Items.Count -ne 13 -or $boxes['--contour'].Items[12] -ne '未定義(12)') { throw 'Contour undefined mapping smoke test failed.' }
  if ($boxes['--hair'].Items.Count -ne 64 -or $boxes['--hair'].Items[63] -ne '未定義(63)') { throw 'Hair expanded decimal range smoke test failed.' }
  if ($boxes['--nose'].Items.Count -ne 34 -or $boxes['--nose'].Items[32] -ne '未定義(32)' -or $boxes['--nose'].Items[33] -ne '未定義(33)') { throw 'Nose undefined range smoke test failed.' }
  if ($boxes['--mouth'].Items.Count -ne 42 -or $boxes['--mouth'].Items[40] -ne '未定義(40)') { throw 'Mouth undefined range smoke test failed.' }
  if ($boxes['--skin-color'].Items.Count -ne 19 -or $boxes['--skin-color'].Items[0] -ne '0' -or $boxes['--skin-color'].Items[5] -ne '5' -or $boxes['--skin-color'].Items[6] -ne '黒髪(未定義6)' -or $boxes['--skin-color'].Items[18] -ne '銀髪(未定義18)') { throw 'Skin/hair overflow range smoke test failed.' }
  if ($boxes['--hair-color'].Items.Count-ne16-or$boxes['--hair-color'].Items[2] -ne '茶' -or $boxes['--hair-color'].Items[13]-ne'銀(未定義13)'-or$boxes['--hair-color'].Items[15]-ne'銀(未定義15)') { throw 'Hair color naming smoke test failed.' }
  $skinPaletteSmoke=@('#FFE7D2','#FFD2AF','#FFBEAA','#CB8964','#9D6044','#673C2E');$hairPaletteSmoke=@('#17151D','#F2F2F2','#804507','#CD902A','#942A00','#F0D238','#2667C9','#3C9A4F','#7E4AB5','#E875A5','#F75700','#F00011','#AEB8C8');foreach($skinCodeSmoke in 6..18){$mappedSkinSmoke=if($skinCodeSmoke-lt$skinPaletteSmoke.Count){$skinPaletteSmoke[$skinCodeSmoke]}else{$hairPaletteSmoke[$skinCodeSmoke-$skinPaletteSmoke.Count]};if($mappedSkinSmoke-ne$hairPaletteSmoke[$skinCodeSmoke-6]){throw "Skin-to-hair preview color mapping failed: $skinCodeSmoke"}}
  $definedFaceCheck.Checked=$true
  if ($personalityOptions.Count -ne 14 -or $personalityOptions[7] -ne '(なし)' -or $personalityOptions[8] -ne '主人公(注意)' -or $personalityOptions[13] -ne 'ひのわ' -or $personalityCodes[8] -ne '64' -or $personalityCodes[13] -ne '69') { throw 'Personality story mapping smoke test failed.' }
  $boxes['--antenna'].SelectedIndex = 0x44
  if ($boxes['--antenna'].Text -ne 'つかまえる' -or (Get-FieldCode $boxes['--antenna']) -ne '44') { throw 'Antenna Japanese mapping smoke test failed.' }
  if($antennaAbilityCodes-contains'64'-or$antennaAbilityCodes-contains'6D'){throw 'RPG3 antenna 100+ slots were retained.'}
  $thunderSquallIndex = [Array]::IndexOf([object[]]$antennaAbilityCodes,[object]'5D')
  if ($thunderSquallIndex -lt 0 -or $antennaAbilityOptions[$thunderSquallIndex] -ne 'らいう') { throw 'Dual-element evolution mapping smoke test failed.' }
  if ((Get-FieldCode $boxes['--antenna-appearance']) -ne 'DD') { throw 'Capture ability did not automatically select the Catch appearance.' }
  $boxes['--antenna'].SelectedIndex = 0x2C
  if ((Get-FieldCode $boxes['--antenna-appearance']) -ne '6D') { throw 'Fireball ability did not automatically select the Fireball appearance.' }
  $boxes['--antenna'].SelectedIndex = 0x44
  $tempesterIndex=[Array]::IndexOf([object[]]$monsterCodes,[object]'67');$gigantoIndex=[Array]::IndexOf([object[]]$monsterCodes,[object]'68')
  if ($monsterNames.Count -ne 166 -or $monsterNames[0] -ne '(なし)' -or $tempesterIndex-lt0-or$monsterNames[$tempesterIndex] -ne 'テンペスター' -or $gigantoIndex-lt0-or$monsterNames[$gigantoIndex] -ne 'ギガントコブダイ' -or $monsterCodes[-1] -ne 'A5' -or $monsterNames[-1] -ne 'アンテナなし(クラッシュ)') { throw 'Captured-monster museum/none/probe mapping smoke test failed.' }
  if($itemRewardNames|Where-Object{$_-like'検証枠*'}){throw 'RPG3 item probe slots failed.'}
  if($multiItemEvents.Count-ne4-or$multiItemEvents[0].Code-ne'34'-or$multiItemEvents[-1].Code-ne'37'){throw 'RPG3 official furniture distribution slots failed.'}
  $expectedCaptureCodes = @{
    'はなもぐら'='01'; 'カーニバルイーグル'='26'; 'ダークホーン'='47'; 'カーズウォーカー'='8E';
    'アイスサソリ'='95'; 'ミラーアーマー'='96'; 'ビッグホーン'='97'; 'じしょう・まおう'='8D'; 'ジュエルのは'='A4'
  }
  foreach ($captureEntry in $expectedCaptureCodes.GetEnumerator()) {
    $captureIndex = [Array]::IndexOf([object[]]$monsterNames, [object]$captureEntry.Key)
    if ($captureIndex -lt 0 -or $monsterCodes[$captureIndex] -ne $captureEntry.Value) {
      throw "Captured-monster code mismatch: $($captureEntry.Key)"
    }
  }
  $boxes['--antenna'].SelectedIndex = $thunderSquallIndex
  if ($boxes['--antenna'].Text -ne 'らいう' -or (Get-FieldCode $boxes['--antenna']) -ne '5D') { throw 'Extended antenna evolution mapping smoke test failed.' }
  $boxes['--antenna'].SelectedIndex = 0x44
  $correctionBox.SelectedIndex = 1
  $edition.SelectedIndex = 2
  if ((Get-ActiveCarrier) -ne $carriers.EU) { throw 'EU carrier selection smoke test failed.' }
  & $displayAction
  if (-not $script:currentQrPath -or -not (Test-Path -LiteralPath $script:currentQrPath) -or -not $preview.Image -or -not $saveButton.Enabled -or -not $cardButton.Enabled) {
    throw ('GUI generation smoke test failed: status=' + $status.Text + '; path=' + $script:currentQrPath + '; preview=' + [bool]$preview.Image + '; save=' + $saveButton.Enabled + '; card=' + $cardButton.Enabled)
  }
  if ($preview.Image.Width -ne 392) { throw ('Normal QR image width mismatch: ' + $preview.Image.Width) }
  $correctionArgumentIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--correction');if($correctionArgumentIndex-lt0-or$script:lastGenerateArguments[$correctionArgumentIndex+1]-ne'1'){throw 'HP correction code argument failed.'}
  Write-Output ('GUI_EU_GENERATE_OK ' + $script:currentQrPath)
  $qrType.SelectedIndex = 1
  $jewelQuantity.Value = 2
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 456) {
    throw ('GUI EU jewel-special generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_EU_JEWEL_SPECIAL_GENERATE_OK ' + $script:currentQrPath)
  $qrType.SelectedIndex = 0
  $capturedCheck.Checked = $true
  $capturedMonster.SelectedIndex = [Array]::IndexOf([object[]]$monsterCodes,[object]'67')
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 392) {
    throw ('GUI EU captured-monster generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_EU_CAPTURED_MONSTER_GENERATE_OK ' + $script:currentQrPath)
  $capturedCheck.Checked = $false
  $edition.SelectedIndex = 1
  if ((Get-ActiveCarrier) -ne $carriers.NA) { throw 'NA carrier selection smoke test failed.' }
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 392) {
    throw ('GUI NA generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_NA_GENERATE_OK ' + $script:currentQrPath)
  $qrType.SelectedIndex = 1
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 456) {
    throw ('GUI NA jewel-special generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_NA_JEWEL_SPECIAL_GENERATE_OK ' + $script:currentQrPath)
  $qrType.SelectedIndex = 0
  $capturedCheck.Checked = $true
  $capturedMonster.SelectedIndex = [Array]::IndexOf([object[]]$monsterCodes,[object]'67')
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 392) {
    throw ('GUI NA captured-monster generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_NA_CAPTURED_MONSTER_GENERATE_OK ' + $script:currentQrPath)
  $capturedCheck.Checked = $false
  $edition.SelectedIndex = 0
  $capturedCheck.Checked = $true
  $capturedMonster.SelectedIndex = [Array]::IndexOf([object[]]$monsterCodes,[object]'68')
  & $displayAction
  if (-not $script:currentQrPath -or -not (Test-Path -LiteralPath $script:currentQrPath) -or -not $preview.Image -or $preview.Image.Width -ne 392) {
    throw ('GUI captured-monster generation smoke test failed: status=' + $status.Text + '; width=' + $(if ($preview.Image) { $preview.Image.Width } else { 0 }))
  }
  Write-Output ('GUI_CAPTURED_MONSTER_GENERATE_OK ' + $script:currentQrPath)
  $capturedCheck.Checked = $false
  $qrType.SelectedIndex = 1
  $jewelQuantity.Value = 255
  & $displayAction
  if (-not $script:currentQrPath -or -not (Test-Path -LiteralPath $script:currentQrPath) -or -not $preview.Image -or $preview.Image.Width -ne 456) {
    throw ('GUI special generation smoke test failed: status=' + $status.Text + '; width=' + $(if ($preview.Image) { $preview.Image.Width } else { 0 }))
  }
  Write-Output ('GUI_SPECIAL_GENERATE_OK ' + $script:currentQrPath)
  $capturedCheck.Checked = $true
  $capturedMonster.SelectedIndex = [Array]::IndexOf([object[]]$monsterCodes,[object]'67')
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 456) {
    throw ('GUI captured-monster + jewel-special generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_CAPTURED_MONSTER_JEWEL_SPECIAL_GENERATE_OK ' + $script:currentQrPath)
  $capturedCheck.Checked = $false
  $qrType.SelectedIndex = 2
  if ($itemRewards[0].DropDownStyle -ne [Windows.Forms.ComboBoxStyle]::DropDown -or $itemRewards[0].AutoCompleteMode -ne [Windows.Forms.AutoCompleteMode]::SuggestAppend) {
    throw 'Searchable item selector smoke test failed.'
  }
  $itemReward.SelectedIndex = 1 + [Array]::IndexOf([object[]]$itemRewardCodes, [object]'0028')
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 456) {
    throw ('GUI one-item special generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_ONE_ITEM_SPECIAL_GENERATE_OK ' + $script:currentQrPath)
  $qrType.SelectedIndex = 5
  $multiItemEvent.SelectedIndex = 0
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 456) {
    throw ('GUI untouched official QR generation smoke test failed: status=' + $status.Text)
  }
  $carrierArgumentIndex = [Array]::IndexOf([object[]]$script:lastGenerateArguments, [object]'--carrier')
  $expectedJackCarrier = Get-Rpg3SpecialCarrierValue $multiItemEvents[0].Path
  if ($carrierArgumentIndex -lt 0 -or $script:lastGenerateArguments[$carrierArgumentIndex + 1] -ne $expectedJackCarrier) {
    throw 'Untouched official QR generation did not use the official Jack carrier.'
  }
  foreach ($forbiddenArgument in @('--character-carrier', '--special-code', '--special-item', '--name', '--qr-date')) {
    if ($script:lastGenerateArguments -contains $forbiddenArgument) { throw "Untouched official QR unexpectedly used $forbiddenArgument." }
  }
  Write-Output ('GUI_UNTOUCHED_OFFICIAL_JACK_GENERATE_OK ' + $script:currentQrPath)
  $qrType.SelectedIndex = 4
  foreach ($formatCheck in @(
    [pscustomobject]@{ Index = 0; Slots = 1 },
    [pscustomobject]@{ Index = 1; Slots = 3 },
    [pscustomobject]@{ Index = 2; Slots = 1 },
    [pscustomobject]@{ Index = 3; Slots = 3 }
  )) {
    $multiItemEvent.SelectedIndex = $formatCheck.Index
    $expectedSlots = $formatCheck.Slots
    for ($slotIndex = 0; $slotIndex -lt 4; $slotIndex++) {
      $shouldEnable = ($slotIndex -lt $expectedSlots)
      if ($itemRewards[$slotIndex].Enabled -ne $shouldEnable) {
        throw "Furniture format slot-count smoke test failed: format=$($formatCheck.Index) slot=$slotIndex expected=$shouldEnable enabled=$($itemRewards[$slotIndex].Enabled)"
      }
    }
  }
  $multiItemEvent.SelectedIndex = 3
  if ($script:rewardCatalogMode -ne 'furniture' -or $script:activeItemRewardCodes.Count -ne $furnitureRewardCodes.Count) {
    throw 'Furniture-only catalog was not activated.'
  }
  $itemRewards[0].SelectedIndex = 1 + [Array]::IndexOf([object[]]$furnitureRewardCodes, [object]'0231')
  $itemRewards[1].SelectedIndex = 1 + [Array]::IndexOf([object[]]$furnitureRewardCodes, [object]'02CF')
  $itemRewards[2].SelectedIndex = 1 + [Array]::IndexOf([object[]]$furnitureRewardCodes, [object]'0304')
  $itemRewards[3].SelectedIndex = 0
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 456) {
    throw ('GUI item-special generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_OFFICIAL_SANTA_CODE37_THREE_FURNITURE_GENERATE_OK ' + $script:currentQrPath)
  $carrierArgumentIndex = [Array]::IndexOf([object[]]$script:lastGenerateArguments, [object]'--carrier')
  $expectedSantaCarrier = Get-Rpg3SpecialCarrierValue $multiItemEvents[3].Path
  if ($carrierArgumentIndex -lt 0 -or $script:lastGenerateArguments[$carrierArgumentIndex + 1] -ne $expectedSantaCarrier) {
    throw 'Code37 furniture generation did not use the official Santa carrier.'
  }
  $specialCodeArgumentIndex = [Array]::IndexOf([object[]]$script:lastGenerateArguments, [object]'--special-code')
  if ($specialCodeArgumentIndex -lt 0 -or $script:lastGenerateArguments[$specialCodeArgumentIndex + 1] -ne '37') {
    throw 'Selected furniture distribution code was not emitted.'
  }
  if ($script:lastGenerateArguments -contains '--qr-date') { throw 'Code37 furniture generation overwrote the official Santa distribution timestamp.' }
  $qrType.SelectedIndex = 6
  $extendedSpecialCode.Value = 38
  $jewelQuantity.Value = 5
  $itemRewards[0].SelectedIndex = 1 + [Array]::IndexOf([object[]]$itemRewardCodes, [object]'0028')
  $itemRewards[1].SelectedIndex = 1 + [Array]::IndexOf([object[]]$furnitureRewardCodes, [object]'0231')
  $itemRewards[2].SelectedIndex = 1 + [Array]::IndexOf([object[]]$furnitureRewardCodes, [object]'02CF')
  $itemRewards[3].SelectedIndex = 1 + [Array]::IndexOf([object[]]$furnitureRewardCodes, [object]'0304')
  & $displayAction
  $probeCodeIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--special-code')
  $probeQuantityIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--special-quantity')
  $probeItemIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--special-item')
  $probeFurniture2Index=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--special-item-2')
  $probeFurniture3Index=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--special-item-3')
  $probeFurniture4Index=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--special-item-4')
  if(-not$script:currentQrPath-or-not$preview.Image-or$preview.Image.Width-ne456-or
     $probeCodeIndex-lt0-or$script:lastGenerateArguments[$probeCodeIndex+1]-ne'38'-or
     $probeQuantityIndex-lt0-or$script:lastGenerateArguments[$probeQuantityIndex+1]-ne'5'-or
     $probeItemIndex-lt0-or$script:lastGenerateArguments[$probeItemIndex+1]-ne'0028'-or
     $probeFurniture2Index-lt0-or$script:lastGenerateArguments[$probeFurniture2Index+1]-ne'0231'-or
     $probeFurniture3Index-lt0-or$script:lastGenerateArguments[$probeFurniture3Index+1]-ne'02CF'-or
     $probeFurniture4Index-lt0-or$script:lastGenerateArguments[$probeFurniture4Index+1]-ne'0304'-or
     $script:lastGenerateArguments-contains'--qr-date'){
    throw ('GUI code38 all-reward generation failed: status='+$status.Text)
  }
  Write-Output ('GUI_CODE38_ALL_REWARDS_OK '+$script:currentQrPath)
  $extendedSpecialCode.Value = 255
  & $displayAction
  $probeCodeIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]'--special-code')
  if($probeCodeIndex-lt0-or$script:lastGenerateArguments[$probeCodeIndex+1]-ne'255'){throw 'GUI maximum special-code 255 generation failed.'}
  Write-Output ('GUI_SPECIAL_CODE_255_OK '+$script:currentQrPath)
  $qrType.SelectedIndex = 4
  $multiItemEvent.SelectedIndex = 3
  $capturedCheck.Checked = $true
  $capturedMonster.SelectedIndex = [Array]::IndexOf([object[]]$monsterCodes,[object]'67')
  if ($qrType.SelectedIndex -ne 4 -or -not $itemRewards[0].Enabled -or -not $itemRewards[2].Enabled -or $itemRewards[3].Enabled) {
    throw 'Captured-monster selection incorrectly disabled or changed item-special mode.'
  }
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 456) {
    throw ('GUI captured-monster + item-special generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_CAPTURED_MONSTER_SANTA_THREE_FURNITURE_GENERATE_OK ' + $script:currentQrPath)
  $capturedCheck.Checked = $false
  $qrType.SelectedIndex = 3
  $jewelQuantity.Value = 7
  $itemRewards[0].SelectedIndex = 1 + [Array]::IndexOf([object[]]$itemRewardCodes, [object]'0028')
  for ($slotIndex = 1; $slotIndex -lt 4; $slotIndex++) {
    $itemRewards[$slotIndex].SelectedIndex = 0
  }
  $capturedCheck.Checked = $true
  if (-not $jewelQuantity.Enabled -or -not $itemRewards[0].Enabled -or $itemRewards[1].Enabled) {
    throw 'Combined jewel/item/captured controls smoke test failed.'
  }
  & $displayAction
  if (-not $script:currentQrPath -or -not $preview.Image -or $preview.Image.Width -ne 456) {
    throw ('GUI jewel + one-item + captured-monster generation smoke test failed: status=' + $status.Text)
  }
  Write-Output ('GUI_JEWEL_ONE_ITEM_CAPTURED_MONSTER_GENERATE_OK ' + $script:currentQrPath)
  $capturedCheck.Checked = $false
  $preview.Image.Dispose()
  $preview.Image = $null
  Remove-Item -LiteralPath $script:currentQrPath -Force
  $script:currentQrPath = $null
  $form.Dispose()
  return
}
if ($env:DENPA3_QR_EDITOR_SMOKE -eq '1') {
  Write-Output 'GUI_INIT_OK'
  $form.Dispose()
  return
}
if ($env:DENPA_EDITOR_EMBED -eq '1') {
  $script:EmbeddedEditorForm = $form
  return
}
if ((Split-Path -Leaf $PSScriptRoot) -eq 'internal') {
  [Windows.Forms.MessageBox]::Show('このファイルは統合版の内部部品です。Denpa QREditor2.3 1.0.1.exeから起動してください。', 'Denpa QREditor2.3 1.0.1') | Out-Null
  $form.Dispose()
  return
}
[void]$form.ShowDialog()
