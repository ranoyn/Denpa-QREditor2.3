Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$smokeMode = [string]$env:DENPA_UNIFIED_EDITOR_SMOKE
$script:applicationIcon=$null
$applicationIconPath=Join-Path $PSScriptRoot 'app-icon.ico'
if(Test-Path -LiteralPath $applicationIconPath){$script:applicationIcon=New-Object Drawing.Icon($applicationIconPath)}
# Keep the editor's taskbar group separate from its PowerShell host.
if(-not('DenpaPublicTaskbarIdentity'-as[type])){
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DenpaPublicTaskbarIdentity {
  [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
  public static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
}
'@
}
$script:taskbarIdentityResult=[DenpaPublicTaskbarIdentity]::SetCurrentProcessExplicitAppUserModelID('Denpa.QREditor.Public.1.0.1')

$startupWindow=$null;$startupLabel=$null;$script:startupStages=@()
if(-not$smokeMode-or$smokeMode-eq'template-layout'){
  $startupWindow=New-Object Windows.Forms.Form
  if($script:applicationIcon){$startupWindow.Icon=$script:applicationIcon}
  $startupWindow.Text='Denpa QREditor2.3 1.0.1'
  $startupWindow.StartPosition='CenterScreen';$startupWindow.FormBorderStyle='FixedDialog'
  $startupWindow.ControlBox=$false;$startupWindow.ClientSize=New-Object Drawing.Size(380,90)
  $startupWindow.BackColor=[Drawing.Color]::White
  $startupLabel=New-Object Windows.Forms.Label
  $startupLabel.Dock='Fill';$startupLabel.TextAlign='MiddleCenter'
  $startupLabel.Font=New-Object Drawing.Font('Yu Gothic UI',14)
  $startupLabel.Text='QREditor3 Loading...'
  $startupWindow.Controls.Add($startupLabel);$startupWindow.Show();$startupWindow.Refresh()
  [Windows.Forms.Application]::DoEvents()
}
function Set-StartupLoadingText([string]$Text){
  $script:startupStages+=$Text
  if($startupLabel){$startupLabel.Text=$Text;$startupWindow.Refresh();[Windows.Forms.Application]::DoEvents()}
}

# Temporary images are removed by their own generation routines.
# Do not delete pre-existing files based only on a shared name prefix.

$state = [pscustomobject]@{ ActiveGame='RPG3'; Shared=@{}; Syncing=$false; Language='Japanese' }
$script:editors = @{}
$script:modules = @()
$script:editorModules = @{}
$script:initTimers = @()
$script:languageStyles = @{}
$script:languageItemCache = @{}

function Find-NamedControl([Windows.Forms.Control]$Root, [string]$Name) {
  $found = $Root.Controls.Find($Name, $true)
  if ($found.Count) { return $found[0] }
  return $null
}

function Find-ButtonByText([Windows.Forms.Control]$Root, [string]$Text) {
  foreach ($control in $Root.Controls) {
    if ($control -is [Windows.Forms.Button] -and $control.Text -eq $Text) { return $control }
    $nested = Find-ButtonByText $control $Text
    if ($nested) { return $nested }
  }
  return $null
}

$script:editorLabelEnglish = [ordered]@{
  '名前'='Name';'性格'='Personality';'顔パーツ'='Face Parts';'補正'='Abilities';'アンテナ'='Antenna';'頭の形'='Head Shape';'髪'='Hair';'輪郭'='Face Shape';'眉'='Brow';'目'='Eye';'鼻'='Nose';'口'='Mouth';'頬'='Cheek';'顔装備'='Face Equip';'体格'='Body Type';'体色'='Body Color';'肌色'='Skin Color';'髪色'='Hair Color';'電波テンプレート'='Denpa Template';'プレビュー'='Preview';'特典'='Present';'特典ID'='Present ID';'くび'='Neck';'ふく'='Clothes';'うで'='Arm';'せなか'='Back';'あし'='Feet';'アイテム'='Item';'モンスター'='Monster';'ジュエル'='Jewels';'ジュエル個数'='Jewels';'デコレ'='Decorate';'QRコード'='QR Code';'QR保存'='Save QR';'カード表示'='Display Card';'テンプレート保存'='Save Template';'QR日付'='QR Date';'デコレを全選択する'='Select all Decorate';'正規候補に絞る'='Filter to Legitimate Denpa Men';'髪と輪郭を同期する'='Sync Hair and Face Shape';'未定義を選択しない'='Exclude Undefined'
}
$script:personalityEnglish = [ordered]@{'いちご'='Strawberry';'にがうり'='Bitter Gourd';'トウガラシ'='Pepper';'とうがらし'='Pepper';'レモン'='Lemon';'バナナ'='Banana';'ぶどう'='Grape';'かき'='Persimmon';'主人公'='Protagonist';'あかり'='Crystal';'テル'='Jasper';'ルナ'='Amber';'みちる'='Rick';'ひのわ'='Mary'}
$script:correctionEnglish = [ordered]@{'HPマスター！'='HP Master!';'APマスター！'='AP Master!';'ちからもち！'='Strong!';'がんじょう！'='Tough!';'しゅんそく！'='Speedy!';'かいひめいじん！'='Evade Master!';'アンテナへんか！'='Antenna Change!';'そうじゅく！'='Quick Grower!'}
$script:headShapeEnglish = [ordered]@{
  'まる'='Round';'よこまる'='Wide Oval';'たてまる'='Tall Oval';'さんかく'='Triangle';'おにぎり'='Rice Ball';'しかく'='Square';'かどまる'='Rounded Square';'しずく'='Drop';'つぼ'='Pot';'こぐま'='Bear Cub';'あまつゆ'='Rainy';'チューリップ'='Tulip';'ロボ'='Robot';'イカ'='Squid';'ロケット'='Rocket';'スター'='Star';'くま'='Bear';'ハート'='Heart';'ねこみみ'='Cat Ears';'デビル'='Devil';'みかづき'='Crescent';'とんがり'='Pointy';'でんち'='Battery';'トゲトゲ'='Spiky';'たまご'='Egg';'タワー'='Tower';'いぬみみ'='Dog Ears';'メラメラ'='Flame';'クワガタ'='Stag Beetle';'ダイヤ'='Diamond';'ルビー'='Ruby';'たいよう'='Sun';'うさみみ'='Rabbit Ears';'まきがい'='Snail Shell';'キャッスル'='Castle';'ブロック'='Block';'たまねぎ'='Onion';'わっか'='Ring';'コック'='Chef';'おさかな'='Fish';'クラッシュ'='Crash'
}
$script:colorEnglish = [ordered]@{'黒'='Black';'赤'='Red';'水色'='Light Blue';'緑'='Green';'オレンジ'='Orange';'黄'='Yellow';'青'='Blue';'白'='White';'紫'='Purple';'銀'='Silver';'金'='Gold';'桃'='Pink';'茶'='Brown';'黄茶'='Golden Brown';'赤茶'='Reddish Brown'}
$script:faceEquipmentEnglish=[ordered]@{
  'みどりのめがね'='Green Glasses';'ピンクのめがね'='Pink Glasses';'サングラス'='Sunglasses';'きいろいめがね'='Yellow Glasses';'しかくいめがね'='Square Glasses';
  'アイマスク'='Sleep Mask';'ふくろうめがね'='Owl Glasses';'あおいめがね'='Blue Glasses';'マスカレードマスク'='Masquerade Mask';'くろぶちめがね'='Black Glasses';
  'バタフライマスク'='Butterfly Glasses';'すいちゅうメガネ'='Water Goggles';'むしのめ'='Bug Eyes';'きんぴかグラス'='Gold Glasses';'ハートグラス'='Heart Glasses';
  'スターグラス'='Star Glasses';'あかぶちメガネ'='Red Glasses';'ワイルドグラス'='Wild Glasses';'ゴーグル'='Goggles';'カラーゴーグル'='Color Goggles';
  'まるめがね'='Round Glasses';'びんぞこめがね'='Thick Glasses';'パイロットゴーグル'='Pilot Goggles'
}
$script:antennaEnglish = [ordered]@{
  'アンテナなし'='No antenna';'おたから2ばい'='Treasure x2';'レアおたから2ばい'='Rare Treasure x2';'ゴールド2ばい'='Gold x2';'ちょっとステルス'='Stealthy';
  'ちょっとかいふく'='Tiny Heal';'みんなすこしかいふく'='Tiny Heal (All)';'ちょっとふっかつ'='Small Revive';'みんなちょっとふっかつ'='Small Revive (All)';
  'げどく'='Antidote';'やけどなおす'='Cure Burn';'かわかす'='Dry';'かぜなおす'='Cure Sniffles';'どろおとす'='Mud Off';'おはらい'='Purify';'かんでんなおす'='Cure Shock';
  'あたためる'='Hot Blanket';'しびれとる'='Mobilize';'めざめる'='Awaken';'めぐすり'='Eye Drops';'むてき'='Invincible';'みんなこうふん'='Excite (All)';'たくわえる'='Steroids';'わざはねかえす'='Reflect';
  'すこしつよくなれ'='Tiny Rage';'みんなつよめになれ'='Tiny Rage (All)';'すこしかたくなれ'='Tiny Wall';'みんなかためになれ'='Tiny Wall (All)';
  'すこしはやくなれ'='Tiny Haste';'みんなはやめになれ'='Tiny Haste (All)';'すこしかわしやすい'='Tiny Dodge';'みんなあてられにくい'='Tiny Dodge (All)';
  'どくどくシグナル'='Poison Signal';'もうどく'='Fatal';'ねむらせる'='Lullaby';'しびれさせる'='Paralyze';'めかくし'='Blindfold';'ブレスふうじ'='Breath Plug';
  'すこしよわくなれ'='Tiny Weaken';'みんなよわめになれ'='Tiny Weaken (All)';'すこしやわくなれ'='Tiny Insult';'みんなやわらかめ'='Tiny Insult (All)';
  'すこしおそくなれ'='Tiny Chain';'みんなおそめになれ'='Tiny Chain (All)';'ひのたま'='Fireball';'ばくはつ'='Fire Cracker';'やまかじ'='Forest Fire';
  'とがったこおり'='Icicle';'ロックアイス'='On the Rocks';'あられ'='Hailstorm';'つむじかぜ'='Whirlwind';'ビルかぜ'='Breeze';'かまいたち'='Twister';
  'らくせき'='Falling Rock';'いしつぶて'='Pebbles';'マグニチュード3'='Magnitude 3';'せいでんき'='Static';'いなづま'='Lightning';'ひゃくボルト'='100 Volts';
  'みずでっぽう'='Water Gun';'バケツのみず'='Bucket of Water';'たかなみ'='High Wave';'よわいこうせん'='Weak Flash';'スポットライト'='Spotlight';'ふゆのひざし'='Winter Sunlight';
  'おどかす'='Scare';'ダークボール'='Dark Ball';'くろいきり'='Dark Mist';'つかまえる'='Catch';
  'もえさかるこおり'='Scorched Ice';'かさいせんぷう'='Burning Wind';'だいふんか'='Eruption';'らくらいかさい'='Lightning Scorch';'ほのおのうみ'='Sea Of Fire';
  'こおりあらし'='Ice Storm';'こおりいんせき'='Frozen Fossil';'かみなりふぶき'='Shocking Snow';'ひさめ'='Hail';'つちけむり'='Dust Storm';'でんきあらし'='Lightning Storm';
  'ぼうふうう'='Horizontal Rain';'かみなりがんせき'='Shock Rock';'どせきりゅう'='Streaming Stones';'らいう'='Thunderstorm';'ならくのたいよう'='Black Sun'
}

function Convert-EditorMappedItem([string]$Text,[string]$Language,[Collections.IDictionary]$Map) {
  if($Language-eq'English'-and$Text-in@('なし','(なし)','（なし）')){return 'None'}
  if($Language-ne'English'-and$Text-eq'None'){return '(なし)'}
  $suffix='';$base=$Text
  if($Language-eq'English'-and$Text-match'^(.*)\((未定義\d*)\)$'){$base=$Matches[1];$suffix='(' + ($Matches[2]-replace'未定義','undefined') + ')'}
  elseif($Language-ne'English'-and$Text-match'^(.*)\((undefined\d*)\)$'){$base=$Matches[1];$suffix='(' + ($Matches[2]-replace'undefined','未定義') + ')'}
  if($Language-eq'English'){if($Map.Contains($base)){return ([string]$Map[$base])+$suffix}}
  else{foreach($entry in $Map.GetEnumerator()){if($base-eq[string]$entry.Value){return ([string]$entry.Key)+$suffix}}}
  if($Language-eq'English'){return ($Text-replace'未定義','undefined')}
  return ($Text-replace'undefined','未定義')
}

function Convert-EditorColorItem([string]$Text,[string]$Language) {
  $suffix='';$base=$Text
  if($Language-eq'English'-and$Text-match'^(.*)\((未定義\d*)\)$'){$base=$Matches[1];$suffix='(' + ($Matches[2]-replace'未定義','undefined') + ')'}
  elseif($Language-ne'English'-and$Text-match'^(.*)\((undefined\d*)\)$'){$base=$Matches[1];$suffix='(' + ($Matches[2]-replace'undefined','未定義') + ')'}
  $parts=if($Language-eq'English'){@($base-split'／')}else{@($base-split' / ')}
  $converted=@();foreach($part in $parts){$value=$null;if($Language-eq'English'){if($script:colorEnglish.Contains($part)){$value=[string]$script:colorEnglish[$part]}}else{foreach($entry in $script:colorEnglish.GetEnumerator()){if($part-eq[string]$entry.Value){$value=[string]$entry.Key;break}}};if($null-eq$value){if($Language-eq'English'){return ($Text-replace'未定義','undefined')}else{return ($Text-replace'undefined','未定義')}};$converted+=$value}
  (($converted-join$(if($Language-eq'English'){' / '}else{'／'}))+$suffix)
}

function Convert-EditorSkinItem([string]$Text,[string]$Language) {
  if($Language-eq'English'-and$Text-match'^髪色(\d+)髪\((未定義\d+)\)$'){
    return 'Hair Color '+$Matches[1]+' Hair(' + ($Matches[2]-replace'未定義','undefined') + ')'
  }
  if($Language-ne'English'-and$Text-match'^Hair Color (\d+) Hair\((undefined\d+)\)$'){
    return '髪色'+$Matches[1]+'髪(' + ($Matches[2]-replace'undefined','未定義') + ')'
  }
  if($Language-eq'English'-and$Text-match'^(.+)髪\((未定義\d+)\)$'){
    return (Convert-EditorColorItem $Matches[1] $Language)+' Hair(' + ($Matches[2]-replace'未定義','undefined') + ')'
  }
  if($Language-ne'English'-and$Text-match'^(.+) Hair\((undefined\d+)\)$'){
    return (Convert-EditorColorItem $Matches[1] $Language)+'髪(' + ($Matches[2]-replace'undefined','未定義') + ')'
  }
  Convert-EditorItemText $Text $Language
}

function Get-EditorControls([Windows.Forms.Control]$Root) {
  foreach($control in @($Root.Controls)){$control;if($control.Controls.Count){Get-EditorControls $control}}
}

$script:editorLabelEnglish['ドーピングフルーツ']='Doping Fruit'
$script:editorLabelEnglish['元個体のレベル']='Source Level'
$script:editorLabelEnglish['さいだいHP']='Max HP'
$script:editorLabelEnglish['さいだいAP']='Max AP'
$script:editorLabelEnglish['こうげきりょく']='Attack'
$script:editorLabelEnglish['ぼうぎょりょく']='Defend'
$script:editorLabelEnglish['すばやさ']='Speed'
$script:editorLabelEnglish['かいひりつ']='Evade'
$script:editorLabelEnglish['QRから電波入力']='Import Denpa from QR'
$script:editorLabelEnglish['QR詳細設定']='Advanced QR Settings'
$script:editorLabelEnglish['ランダムQR']='Random QR'
$script:editorLabelEnglish['デバッグモード']='Debug Mode'
$script:editorLabelEnglish['顔パーツ表']='Face Parts Table'
$script:editorLabelEnglish['ののガードを適用する']='Apply Nono Guard'
$script:editorLabelEnglish['名前を個別入力']='Enter Names Individually'
$script:editorLabelEnglish['RPG3 補正選択']='Select Ability for RPG3'
$script:editorLabelEnglish['アンテナへんか']=$script:correctionEnglish['アンテナへんか！'].TrimEnd('!')
$script:editorLabelEnglish['メモ']='Memo'
$script:editorLabelEnglish['メモ(特典QRのみ)']='Memo (special QR only)'
$script:editorLabelEnglish['装備']='Equipment'

function Convert-EditorControlText([string]$Text,[string]$Language) {
  if($Language-eq'English'){
    if($Text-in@('顔テンプレート','電波人間テンプレート')){$Text='電波テンプレート'}
    $short=@{'首装備'='くび';'服装備'='ふく';'腕装備'='うで';'背中装備'='せなか';'足装備'='あし'};if($short.ContainsKey($Text)){$Text=$short[$Text]}
    if($Text-match'^アイテム(\d+)$'){return 'Item'+$Matches[1]}
    if($Text-match'^デコレ(\d+)$'){return 'Decorate'+$Matches[1]}
    if($script:editorLabelEnglish.Contains($Text)){return [string]$script:editorLabelEnglish[$Text]}
    return $Text
  }
  if($Text-match'^Item(\d+)$'){return 'アイテム'+$Matches[1]}
  if($Text-match'^Decorate(\d+)$'){return 'デコレ'+$Matches[1]}
  foreach($entry in $script:editorLabelEnglish.GetEnumerator()){if($Text-eq$entry.Value){return [string]$entry.Key}}
  if($Text-in@('顔テンプレート','電波人間テンプレート')){return '電波テンプレート'}
  $short=@{'首装備'='くび';'服装備'='ふく';'腕装備'='うで';'背中装備'='せなか';'足装備'='あし'};if($short.ContainsKey($Text)){return [string]$short[$Text]}
  return $Text
}

function Convert-EditorItemText([string]$Text,[string]$Language) {
  $storyNotes=@{'主人公(注意)'='Protagonist(Caution)';'テル(頭身変化)'='Jasper(Proportion Change)';'ルナ(頭身変化)'='Amber(Proportion Change)'}
  if($Language-eq'English'-and$storyNotes.ContainsKey($Text)){return [string]$storyNotes[$Text]}
  if($Language-ne'English'){foreach($entry in $storyNotes.GetEnumerator()){if($Text-eq$entry.Value){return [string]$entry.Key}}}
  if($Language-eq'English'){
    if($Text-eq'通常QR'){return 'Normal QR'}
    if($Text-eq'特典QR'){return 'Present QR'}
    if($script:personalityEnglish.Contains($Text)){return [string]$script:personalityEnglish[$Text]}
    if($script:correctionEnglish.Contains($Text)){return [string]$script:correctionEnglish[$Text]}
    if($Text-in@('なし','(なし)','（なし）','(選択なし)','（選択なし）')){return 'None'}
    if($Text-in@('未調査（無効）','未実装','未実装（無効）')){return 'unimplemented'}
    return ($Text-replace'未定義','undefined')
  }
  if($Text-eq'Normal QR'){return '通常QR'}
  if($Text-eq'Present QR'){return '特典QR'}
  foreach($entry in $script:personalityEnglish.GetEnumerator()){if($Text-eq$entry.Value){return [string]$entry.Key}}
  foreach($entry in $script:correctionEnglish.GetEnumerator()){if($Text-eq$entry.Value){return [string]$entry.Key}}
  if($Text-eq'None'){return '(なし)'}
  if($Text-eq'unimplemented'){return '未実装'}
  return ($Text-replace'undefined','未定義')
}

function Convert-EditorLanguageItem([string]$Kind,[string]$Text,[string]$Language) {
  # Cache by input text, not by index: filtered lists can change between switches.
  if($Text-match'^\d+$'){return $Text}
  $bucketKey=$Language+'|'+$Kind
  if(-not$script:languageItemCache.ContainsKey($bucketKey)){$script:languageItemCache[$bucketKey]=@{}}
  $cache=$script:languageItemCache[$bucketKey]
  if($cache.ContainsKey($Text)){return [string]$cache[$Text]}
  $value=switch($Kind){
    '--head-shape' {Convert-EditorMappedItem $Text $Language $script:headShapeEnglish}
    '--antenna' {Convert-EditorMappedItem $Text $Language $script:antennaEnglish}
    '--glasses' {Convert-EditorMappedItem $Text $Language $script:faceEquipmentEnglish}
    '--body-color' {Convert-EditorColorItem $Text $Language}
    '--hair-color' {Convert-EditorColorItem $Text $Language}
    '--skin-color' {Convert-EditorSkinItem $Text $Language}
    '--face-image' {Convert-EditorSkinItem $Text $Language}
    '--stature' {
      $terms=[ordered]@{'最大'='Largest';'準大'='Large';'中間'='Average';'準速'='Fast';'最速'='Fastest'}
      $result=$Text
      foreach($entry in $terms.GetEnumerator()){
        if($Language-eq'English'){$result=$result.Replace([string]$entry.Key,[string]$entry.Value)}
        else{$result=$result -replace ([regex]::Escape([string]$entry.Value)+'$'),[string]$entry.Key}
      }
      $result
    }
    default {Convert-EditorItemText $Text $Language}
  }
  $cache[$Text]=[string]$value
  return [string]$value
}

function Set-EditorCachedFaceCatalogLanguage([string]$Language) {
  foreach($game in @('RPG1','RPG2','RPG3')){
    if(-not$script:editorModuleByGame-or-not$script:editorModuleByGame.ContainsKey($game)){continue}
    $catalog=& $script:editorModuleByGame[$game] {
      if($rpg1AllFaceNames){return [pscustomobject]@{Head=@($rpg1AllFaceNames['--head-shape']);Glasses=@($rpg1AllFaceNames['--glasses']);HairColor=@($rpg1AllFaceNames['--hair-color']);Skin=@($rpg1AllFaceNames['--skin-color'])}}
      if($rpg2FullFaceNames){return [pscustomobject]@{Head=@($rpg2FullFaceNames['--head-shape']);Glasses=@($rpg2FullFaceNames['--glasses']);HairColor=@($rpg2FullFaceNames['--hair-color']);Skin=@($rpg2FullFaceNames['--face-image'])}}
      if($rpg3FullFaceNames){return [pscustomobject]@{Head=@($rpg3FullFaceNames['--head-shape']);Glasses=@($rpg3FullFaceNames['--glasses']);HairColor=@($rpg3FullFaceNames['--hair-color']);Skin=@($rpg3FullFaceNames['--skin-color'])}}
      return $null
    }
    if(-not$catalog){continue}
    $localized=[pscustomobject]@{Head=@($catalog.Head|ForEach-Object{Convert-EditorLanguageItem '--head-shape' ([string]$_) $Language});Glasses=@($catalog.Glasses|ForEach-Object{Convert-EditorLanguageItem '--glasses' ([string]$_) $Language});HairColor=$(if($null-ne$catalog.HairColor){@($catalog.HairColor|ForEach-Object{Convert-EditorLanguageItem '--hair-color' ([string]$_) $Language})}else{$null});Skin=$(if($null-ne$catalog.Skin){@($catalog.Skin|ForEach-Object{Convert-EditorLanguageItem '--skin-color' ([string]$_) $Language})}else{$null})}
    & $script:editorModuleByGame[$game] {param($Values)
      if($rpg1AllFaceNames){$rpg1AllFaceNames['--head-shape']=@($Values.Head);$rpg1AllFaceNames['--glasses']=@($Values.Glasses);if($null-ne$Values.HairColor){$rpg1AllFaceNames['--hair-color']=@($Values.HairColor)};if($null-ne$Values.Skin){$rpg1AllFaceNames['--skin-color']=@($Values.Skin)};return}
      if($rpg2FullFaceNames){$rpg2FullFaceNames['--head-shape']=@($Values.Head);$rpg2FullFaceNames['--glasses']=@($Values.Glasses);if($null-ne$Values.HairColor){$rpg2FullFaceNames['--hair-color']=@($Values.HairColor)};if($null-ne$Values.Skin){$rpg2FullFaceNames['--face-image']=@($Values.Skin)};return}
      if($rpg3FullFaceNames){$rpg3FullFaceNames['--head-shape']=@($Values.Head);$rpg3FullFaceNames['--glasses']=@($Values.Glasses);if($null-ne$Values.HairColor){$rpg3FullFaceNames['--hair-color']=@($Values.HairColor)};if($null-ne$Values.Skin){$rpg3FullFaceNames['--skin-color']=@($Values.Skin)}}
    } $localized
  }
}

function Set-EditorLanguage([string]$Language) {
  if($script:appliedEditorLanguage-eq$Language){return}
  $previousSharedSyncing=$state.Syncing
  $state.Syncing=$true
  $preservedNames=@()
  foreach($module in @($script:editorModuleByGame.Values)){
    $snapshot=& $module {
      $texts=@{};foreach($key in $nameLanguage.ActiveLanguages){$texts[$key]=[string]$nameLanguage.Boxes[$key].Text}
      $previousSyncing=$nameLanguage.Syncing;$nameLanguage.Syncing=$true
      [pscustomobject]@{State=$nameLanguage;Texts=$texts;Syncing=$previousSyncing;SelectedId=$nameLanguage.SelectedId}
    }
    $preservedNames+=$snapshot
  }
  try{
  foreach($module in @($script:editorModuleByGame.Values)){& $module {$script:editorLanguageUpdating=$true}}
  $state.Language=$Language;$env:DENPA_EDITOR_LANGUAGE=$Language
  # These lists have code-based translators below; do not translate them twice.
  $contentBoxes=New-Object 'System.Collections.Generic.HashSet[System.Windows.Forms.Control]'
  if($script:editorModuleByGame.ContainsKey('RPG2')){
    foreach($box in @(& $script:editorModuleByGame.RPG2 {$neckBox;$armBox;$backBox;$feetBox;$clothingBox})){[void]$contentBoxes.Add($box)}
  }
  if($script:editorModuleByGame.ContainsKey('RPG3')){
    foreach($box in @(& $script:editorModuleByGame.RPG3 {$capturedMonster;foreach($box in $itemRewards){$box}})){[void]$contentBoxes.Add($box)}
  }
  foreach($editor in @($script:editors.Values)){
    if(-not$editor-or-not$editor.Form){continue}
    $editor.Form.SuspendLayout()
    try{
      foreach($control in @(Get-EditorControls $editor.Form)){
        if($control-is [Windows.Forms.Label]-or$control-is [Windows.Forms.Button]-or$control-is [Windows.Forms.CheckBox]-or$control-is [Windows.Forms.GroupBox]){$control.Text=Convert-EditorControlText ([string]$control.Text) $Language}
        if($control-is [Windows.Forms.ComboBox]){
          if($control.Name-eq'--name'-or$control.Name-like'nameLanguage*'-or$control.Name-eq'faceTemplate'-or$contentBoxes.Contains($control)){continue}
          $selected=$control.SelectedIndex;$control.BeginUpdate()
          try{for($i=0;$i-lt$control.Items.Count;$i++){$old=[string]$control.Items[$i];$new=Convert-EditorLanguageItem $control.Name $old $Language;if($new-ne$old){$control.Items[$i]=$new}}}finally{$control.EndUpdate()}
          if($selected-ge0-and$selected-lt$control.Items.Count){$control.SelectedIndex=$selected}
        }
      }
    } finally {$editor.Form.ResumeLayout($true)}
  }
  foreach($game in @($script:editors.Keys)){
    $editor=$script:editors[$game];$personalityLabel=Find-NamedControl $editor.Form 'label_--personality';$templateLabel=@(Get-EditorControls $editor.Form|Where-Object{$_.GetType().Name-eq'Label'-and$_.Text-in@('顔テンプレート','電波人間テンプレート','電波テンプレート','Denpa Template')}|Select-Object -First 1)[0]
    if($personalityLabel){$key=$game+'-personality';if(-not$script:languageStyles.ContainsKey($key)){$script:languageStyles[$key]=[pscustomobject]@{Left=$personalityLabel.Left;Size=$personalityLabel.Font.Size;Style=$personalityLabel.Font.Style}};$style=$script:languageStyles[$key];$personalityLabel.Left=if($Language-eq'English'){$style.Left-38}else{$style.Left};$old=$personalityLabel.Font;$personalityLabel.Font=New-Object Drawing.Font($old.FontFamily,$(if($Language-eq'English'){9}else{$style.Size}),$style.Style)}
    $personalityBox=$editor.Map.personality;if($personalityBox){$key=$game+'-personalityBox';if(-not$script:languageStyles.ContainsKey($key)){$script:languageStyles[$key]=[pscustomobject]@{Size=$personalityBox.Font.Size;Style=$personalityBox.Font.Style}};$style=$script:languageStyles[$key];$old=$personalityBox.Font;$personalityBox.Font=New-Object Drawing.Font($old.FontFamily,$(if($Language-eq'English'){8.5}else{$style.Size}),$style.Style)}
    if($templateLabel){$key=$game+'-template';if(-not$script:languageStyles.ContainsKey($key)){$script:languageStyles[$key]=[pscustomobject]@{Size=$templateLabel.Font.Size;Style=$templateLabel.Font.Style}};$style=$script:languageStyles[$key];$old=$templateLabel.Font;$templateLabel.Font=New-Object Drawing.Font($old.FontFamily,$(if($Language-eq'English'){8}else{$style.Size}),$style.Style)}
    foreach($code in @('DEU','FRA')){$box=Find-NamedControl $editor.Form ('nameLanguage'+$code);if($box){$key=$game+'-'+$code;if(-not$script:languageStyles.ContainsKey($key)){$script:languageStyles[$key]=[pscustomobject]@{Size=$box.Font.Size;Style=$box.Font.Style}};$style=$script:languageStyles[$key];$old=$box.Font;$box.Font=New-Object Drawing.Font($old.FontFamily,$(if($Language-eq'English'){8}else{$style.Size}),$style.Style)}}
  }
  Set-EditorCachedFaceCatalogLanguage $Language
  $labNames=@{};$labJapanese=@('','HPマスター！','APマスター！','ちからもち！','がんじょう！','しゅんそく！','かいひめいじん！','アンテナへんか！','そうじゅく！')
  for($i=1;$i-le8;$i++){$labNames[$i]=Convert-EditorItemText $labJapanese[$i] $Language}
  foreach($game in @('RPG1','RPG2')){if($script:editorModuleByGame.ContainsKey($game)){
    $antJapanese=& $script:editorModuleByGame[$game] {if($script:callLab){@($antennaNames|ForEach-Object{$_-replace'\(未定義\d+\)$',''})}}
    $antLocalized=@($antJapanese|ForEach-Object{Convert-EditorMappedItem ([string]$_) $Language $script:antennaEnglish})
    & $script:editorModuleByGame[$game] {param($n,$a,$l) Set-DenpaCallLabLanguage $n $a $l} $labNames $antLocalized $Language
  }}
  if($script:editorModuleByGame-and$script:editorModuleByGame.ContainsKey('RPG2')){& $script:editorModuleByGame.RPG2 {param($SelectedLanguage) Set-Rpg2EquipmentLanguage $SelectedLanguage;Set-Rpg2PaintLanguage $SelectedLanguage} $Language}
  if($script:editorModuleByGame-and$script:editorModuleByGame.ContainsKey('RPG3')){& $script:editorModuleByGame.RPG3 {param($SelectedLanguage) Set-Rpg3ContentLanguage $SelectedLanguage} $Language}
  if($script:japaneseButton){$script:japaneseButton.BackColor=if($Language-eq'Japanese'){[Drawing.Color]::FromArgb(196,225,248)}else{[Drawing.Color]::White}}
  if($script:englishButton){$script:englishButton.BackColor=if($Language-eq'English'){[Drawing.Color]::FromArgb(196,225,248)}else{[Drawing.Color]::White}}
  foreach($game in @($script:editorModuleByGame.Keys)){& $script:editorModuleByGame[$game] {param($game) Update-DenpaTemplateDisplayLabels $game} $game}
  $script:appliedEditorLanguage=$Language
  }finally{
    foreach($snapshot in $preservedNames){
      $snapshot.State.Syncing=$true
      try{foreach($key in $snapshot.Texts.Keys){$snapshot.State.Boxes[$key].Text=$snapshot.Texts[$key]};$snapshot.State.SelectedId=$snapshot.SelectedId}finally{$snapshot.State.Syncing=$snapshot.Syncing}
    }
    foreach($module in @($script:editorModuleByGame.Values)){& $module {$script:editorLanguageUpdating=$false}}
    $state.Syncing=$previousSharedSyncing
  }
}

function Import-EmbeddedPowerShellEditor([string]$FileName, [string]$ModuleName) {
  $path = Join-Path (Join-Path $PSScriptRoot 'internal') $FileName
  if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $PSScriptRoot $FileName }
  if (-not (Test-Path -LiteralPath $path)) { throw "$FileName が見つかりません。" }
  $oldEmbed = $env:DENPA_EDITOR_EMBED
  $env:DENPA_EDITOR_EMBED = '1'
  try {
    $moduleResults = @(New-Module -Name $ModuleName -ArgumentList $path -ScriptBlock {
      param($EditorPath)
      . $EditorPath
    })
    $module = @($moduleResults | Where-Object { $_ -is [System.Management.Automation.PSModuleInfo] } | Select-Object -Last 1)[0]
    if (-not $module) { throw "$FileName のPowerShellモジュールを作成できませんでした。" }
    $formResults = @(& $module { $script:EmbeddedEditorForm })
    $editorForm = @($formResults | Where-Object { $_ -is [Windows.Forms.Form] } | Select-Object -Last 1)[0]
    if (-not $editorForm) {
      $types = @($formResults | ForEach-Object { if ($null -eq $_) { '<null>' } else { $_.GetType().FullName } }) -join ', '
      throw "$FileName を埋め込みモードで初期化できませんでした。取得型: $types"
    }
    $script:modules += $module
    $script:editorModules[$ModuleName] = $module
    return $editorForm
  } finally {
    if ($null -eq $oldEmbed) { Remove-Item Env:DENPA_EDITOR_EMBED -ErrorAction SilentlyContinue }
    else { $env:DENPA_EDITOR_EMBED = $oldEmbed }
  }
}

function Set-ChildForm([Windows.Forms.Form]$Child) {
  if($script:applicationIcon){$Child.Icon=$script:applicationIcon}
  $Child.ShowInTaskbar=$false
  $Child.TopLevel = $false
  $Child.FormBorderStyle = 'None'
  $Child.Dock = 'Fill'
  $Child.AutoScroll = $false
  $Child.StartPosition = 'Manual'
  $Child.Visible = $false
  $contentHost.Controls.Add($Child)
}

function Set-CompactControlLayout([Windows.Forms.Control]$Root, [double]$ScaleX, [double]$ScaleY) {
  foreach ($control in @($Root.Controls)) {
    $control.Location = New-Object Drawing.Point(
      [int][Math]::Round($control.Left * $ScaleX),
      [int][Math]::Round($control.Top * $ScaleY)
    )
    if (-not $control.AutoSize) {
      $control.Size = New-Object Drawing.Size(
        [Math]::Max(1, [int][Math]::Round($control.Width * $ScaleX)),
        [Math]::Max(1, [int][Math]::Round($control.Height * 0.96))
      )
    }
    if ($control -is [Windows.Forms.PictureBox] -and $control.Name -eq 'qrPreview') {
      # QR images are square; do not leave letterbox strips after unequal UI scaling.
      $qrSide=[Math]::Min($control.Width,$control.Height)
      $control.Size=New-Object Drawing.Size($qrSide,$qrSide)
      $control.BackColor=[Drawing.Color]::White
    }
    if ($control.Controls.Count -gt 0) { Set-CompactControlLayout $control $ScaleX $ScaleY }
  }
}

function Add-Map($Info, [string]$Key, $Control) {
  if ($Control) { $Info.Map[$Key] = $Control }
}

function Get-TransparentLogo([string]$Game) {
  $path = Join-Path (Join-Path $PSScriptRoot 'ui-logos') ($Game.ToLower() + '.jpg')
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $source = [Drawing.Bitmap]::FromFile($path)
  try {
    $result = New-Object Drawing.Bitmap($source.Width, $source.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $minX=$source.Width;$minY=$source.Height;$maxX=-1;$maxY=-1
    for ($y = 0; $y -lt $source.Height; $y++) {
      for ($x = 0; $x -lt $source.Width; $x++) {
        $pixel = $source.GetPixel($x, $y)
        # 添付されたロゴ画像の白背景だけを透明化する。ロゴ自体は再生成しない。
        if ($pixel.R -gt 248 -and $pixel.G -gt 248 -and $pixel.B -gt 248) { $result.SetPixel($x, $y, [Drawing.Color]::FromArgb(0,255,255,255)) }
        else {$result.SetPixel($x,$y,$pixel);if($x-lt$minX){$minX=$x};if($x-gt$maxX){$maxX=$x};if($y-lt$minY){$minY=$y};if($y-gt$maxY){$maxY=$y}}
      }
    }
    $scaled = New-Object Drawing.Bitmap(128,48,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($scaled)
    try {
      $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      if($maxX-ge$minX-and$maxY-ge$minY){
        $sourceRect=New-Object Drawing.Rectangle($minX,$minY,($maxX-$minX+1),($maxY-$minY+1))
        $ratio=[Math]::Min(124.0/$sourceRect.Width,44.0/$sourceRect.Height)
        $drawWidth=[int][Math]::Round($sourceRect.Width*$ratio);$drawHeight=[int][Math]::Round($sourceRect.Height*$ratio)
        $targetRect=New-Object Drawing.Rectangle(([int]((128-$drawWidth)/2)),([int]((48-$drawHeight)/2)),$drawWidth,$drawHeight)
        $graphics.DrawImage($result,$targetRect,$sourceRect,[Drawing.GraphicsUnit]::Pixel)
      }
    } finally { $graphics.Dispose();$result.Dispose() }
    return $scaled
  } finally { $source.Dispose() }
}

$form = New-Object Windows.Forms.Form
$form.Text = 'Denpa QREditor2.3 1.0.1'
$form.ClientSize = New-Object Drawing.Size(1160, 710)
$form.MinimumSize = New-Object Drawing.Size(1020, 680)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Yu Gothic UI', 10)
if($script:applicationIcon){$form.Icon=$script:applicationIcon}

$top = New-Object Windows.Forms.Panel
$top.Dock = 'Top'
$top.Height = 82
$top.BackColor = [Drawing.Color]::FromArgb(236, 247, 255)
$form.Controls.Add($top)

$title = New-Object Windows.Forms.Label
$title.Text = 'Denpa QREditor2.3 1.0.1'
$title.Font = New-Object Drawing.Font('Yu Gothic UI', 17, [Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object Drawing.Point(28, 16)
$top.Controls.Add($title)

$script:japaneseButton = New-Object Windows.Forms.Button
$script:japaneseButton.Name = 'LanguageJapanese'
$script:japaneseButton.Text = '日本語'
$script:japaneseButton.Location = New-Object Drawing.Point(315, 20)
$script:japaneseButton.Size = New-Object Drawing.Size(105, 38)
$script:japaneseButton.FlatStyle = 'Flat'
$top.Controls.Add($script:japaneseButton)

$script:englishButton = New-Object Windows.Forms.Button
$script:englishButton.Name = 'LanguageEnglish'
$script:englishButton.Text = 'English'
$script:englishButton.Location = New-Object Drawing.Point(430, 20)
$script:englishButton.Size = New-Object Drawing.Size(105, 38)
$script:englishButton.FlatStyle = 'Flat'
$top.Controls.Add($script:englishButton)
$script:japaneseButton.Add_Click({Set-EditorLanguage 'Japanese'})
$script:englishButton.Add_Click({Set-EditorLanguage 'English'})

$versionButtons = @{}
$x = 650
foreach ($game in @('RPG1','RPG2','RPG3')) {
  $button = New-Object Windows.Forms.Button
  $button.Name = "Switch$game"
  $button.Text = ''
  $button.FlatStyle = 'Flat'
  $button.FlatAppearance.BorderSize = 1
  $button.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(110, 82, 129, 169)
  $button.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(35, 92, 154, 210)
  $button.BackColor = [Drawing.Color]::FromArgb(24, 255, 255, 255)
  $button.Location = New-Object Drawing.Point($x, 6)
  $button.Size = New-Object Drawing.Size(144, 64)
  $button.Image = Get-TransparentLogo $game
  $button.ImageAlign = 'MiddleCenter'
  $button.AccessibleName = "$game 切替"
  $top.Controls.Add($button)
  $versionButtons[$game] = $button
  $x += 158
}

$compatibility = New-Object Windows.Forms.Label
$compatibility.Text = ''
$compatibility.Location = New-Object Drawing.Point(30, 69)
$compatibility.Size = New-Object Drawing.Size(330, 20)
$compatibility.ForeColor = [Drawing.Color]::FromArgb(65, 65, 80)
$compatibility.Visible = $false
$top.Controls.Add($compatibility)

$contentHost = New-Object Windows.Forms.Panel
$contentHost.Location = New-Object Drawing.Point(0, 82)
$contentHost.Size = New-Object Drawing.Size($form.ClientSize.Width, ($form.ClientSize.Height - 82))
$contentHost.Anchor = 'Top,Bottom,Left,Right'
$contentHost.BackColor = [Drawing.Color]::White
$form.Controls.Add($contentHost)
$top.BringToFront()

try{
  Set-StartupLoadingText 'QREditor3 Loading...'
  $rpg3Form = Import-EmbeddedPowerShellEditor 'Denpa3QREditor.ps1' 'DenpaRpg3Embedded'
  Set-StartupLoadingText 'QREditor2 Loading...'
  $rpg2Form = Import-EmbeddedPowerShellEditor 'Denpa2QREditor.ps1' 'DenpaRpg2Embedded'
  Set-StartupLoadingText 'QREditor Loading...'
  $rpg1Form = Import-EmbeddedPowerShellEditor 'Denpa1QREditor.ps1' 'DenpaRpg1Embedded'
}finally{if($startupWindow){$startupWindow.Close();$startupWindow.Dispose();$startupWindow=$null;$startupLabel=$null}}
function Set-EditorActionButtonLayout([Windows.Forms.Form]$Child){
  $defined=Find-NamedControl $Child 'definedFaceCheck'
  $guard=New-Object Windows.Forms.CheckBox;$guard.Name='nonoGuardCheck';$guard.Text='ののガードを適用する';$guard.AutoSize=$true
  $guard.Checked=$global:DenpaNonoGuardEnabled;$guard.Enabled=$false;$guard.TabStop=$false
  $guard.Location=New-Object Drawing.Point($defined.Left,($defined.Top+24));$Child.Controls.Add($guard)
  $save=Find-ButtonByText $Child 'QR保存';$card=Find-ButtonByText $Child 'カード表示'
  for($index=0;$index-lt3;$index++){
    $placeholder=New-Object Windows.Forms.Button
    $placeholder.Name=@('debugModeButton','advancedQrButton','templateSavePlaceholder')[$index]
    $placeholder.Text=$(if($index-eq0){'デバッグモード'}else{''});$placeholder.Enabled=($index-eq0);$placeholder.TabStop=($index-eq0)
    $placeholder.Font=New-Object Drawing.Font('Yu Gothic UI',8)
    $placeholder.Location=New-Object Drawing.Point(1124,(153+$index*58))
    $placeholder.Size=New-Object Drawing.Size(105,48);$Child.Controls.Add($placeholder)
  }
  $save.Location=New-Object Drawing.Point(1124,327);$save.Size=New-Object Drawing.Size(105,48)
  $card.Location=New-Object Drawing.Point(1124,385);$card.Size=New-Object Drawing.Size(105,48)
  for($index=0;$index-lt5;$index++){
    $leftButton=New-Object Windows.Forms.Button
    $leftButton.Name=@('randomQrButton','qrImportPlaceholder','leftReserved1','leftReserved2','facePartsTableButton')[$index]
    $leftButton.Text=@('ランダムQR','QRから電波入力','','','顔パーツ表')[$index]
    $leftButton.Enabled=($index-lt2);$leftButton.TabStop=($index-lt2)
    $leftButton.Font=New-Object Drawing.Font('Yu Gothic UI',8)
    $leftButton.Location=New-Object Drawing.Point(690,(153+$index*58))
    $leftButton.Size=New-Object Drawing.Size(105,48);$Child.Controls.Add($leftButton)
  }
}
foreach($child in @($rpg1Form,$rpg2Form,$rpg3Form)){Set-EditorActionButtonLayout $child}
Set-CompactControlLayout $rpg1Form 0.90 0.92
Set-CompactControlLayout $rpg2Form 0.90 0.92
Set-CompactControlLayout $rpg3Form 0.90 0.92
Set-ChildForm $rpg1Form
Set-ChildForm $rpg2Form
Set-ChildForm $rpg3Form

$rpg3 = @{ Form=$rpg3Form; Map=@{}; Display=(Find-ButtonByText $rpg3Form 'QR表示') }
foreach ($pair in @{
  name='--name'; antenna='--antenna'; personality='--personality'; body='--body-color'; head='--head-shape'; stature='--stature';
  contour='--contour'; hair='--hair'; hairColor='--hair-color'; brow='--eyebrow'; eyes='--eyes'; nose='--nose'; mouth='--mouth';
  cheeks='--cheeks'; glasses='--glasses'; skin='--skin-color'
}.GetEnumerator()) { Add-Map $rpg3 $pair.Key (Find-NamedControl $rpg3Form $pair.Value) }

$rpg2 = @{ Form=$rpg2Form; Map=@{}; Display=(Find-ButtonByText $rpg2Form 'QR表示') }
foreach ($pair in @{
  name='--name'; antenna='--antenna'; personality='--personality'; body='--body-color'; head='--head-shape'; stature='--stature'; contour='--face-shape';
  hair='--hair'; hairColor='--hair-color'; brow='--eyebrow'; eyes='--eyes'; nose='--nose'; mouth='--mouth'; cheeks='--cheeks'; glasses='--glasses'; skin='--face-image'
}.GetEnumerator()) { Add-Map $rpg2 $pair.Key (Find-NamedControl $rpg2Form $pair.Value) }

$rpg1 = @{ Form=$rpg1Form; Map=@{}; Display=(Find-ButtonByText $rpg1Form 'QR表示') }
foreach ($pair in @{
  name='--name'; antenna='--antenna'; personality='--personality'; body='--body-color'; head='--head-shape'; stature='--stature'; contour='--contour';
  hair='--hair'; hairColor='--hair-color'; eyes='--eyes'; brow='--eyebrow'; nose='--nose'; skin='--skin-color'; mouth='--mouth';
  cheeks='--cheeks'; glasses='--glasses'; qrPreview='qrPreview'
}.GetEnumerator()) { Add-Map $rpg1 $pair.Key (Find-NamedControl $rpg1Form $pair.Value) }
$rpg1Block = New-Object Windows.Forms.Label
$rpg1Block.Text = "この外見はRPG1にないパーツを含むため`r`nQRを表示できません。"
$rpg1Block.TextAlign = 'MiddleCenter'
$rpg1Block.ForeColor = [Drawing.Color]::FromArgb(170, 40, 40)
$rpg1Block.BackColor = [Drawing.Color]::MistyRose
$rpg1Block.BorderStyle = 'FixedSingle'
$rpg1Block.Location = $rpg1.Map.qrPreview.Location
$rpg1Block.Size = $rpg1.Map.qrPreview.Size
$rpg1Block.Visible = $false
$rpg1.Map.qrPreview.Parent.Controls.Add($rpg1Block)

$script:editors = @{ RPG1=$rpg1; RPG2=$rpg2; RPG3=$rpg3 }
$script:editorModuleByGame = @{
  RPG1=$script:editorModules['DenpaRpg1Embedded']
  RPG2=$script:editorModules['DenpaRpg2Embedded']
  RPG3=$script:editorModules['DenpaRpg3Embedded']
}
Set-EditorLanguage 'Japanese'

. (Join-Path $PSScriptRoot 'DenpaQrImport.ps1')
. (Join-Path $PSScriptRoot 'DenpaPartsTable.ps1')

foreach($game in @('RPG1','RPG2','RPG3')){
  $button=Find-NamedControl $script:editors[$game].Form 'templateSavePlaceholder'
  $button.Text='テンプレート保存';$button.Enabled=$true;$button.TabStop=$true
  $button.Font=New-Object Drawing.Font('Yu Gothic UI',8)
  $localGame=$game;$localModule=$script:editorModuleByGame[$game]
  $randomButton=Find-NamedControl $script:editors[$game].Form 'randomQrButton'
  $randomButton.Add_Click(({
    try{& $localModule {param($game) Set-DenpaRandomFace $game} $localGame}
    catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'QREditor','OK','Error')}
  }.GetNewClosure()))
  $debugButton=Find-NamedControl $script:editors[$game].Form 'debugModeButton'
  $debugButton.Add_Click(({
    try{
      & $localModule {param($game) Show-DenpaDebugQr ([int]$game.Substring(3))} $localGame
    }catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'QREditor','OK','Error')}
  }.GetNewClosure()))
  $advancedButton=Find-NamedControl $script:editors[$game].Form 'advancedQrButton'
  $advancedButton.Text='QR詳細設定';$advancedButton.Enabled=$true;$advancedButton.TabStop=$true
  $advancedButton.Font=New-Object Drawing.Font('Yu Gothic UI',8)
  $advancedButton.Add_Click(({
    try{& $localModule {param($game) Show-DenpaAdvancedQrSettings $game} $localGame}
    catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'QREditor','OK','Error')}
  }.GetNewClosure()))
  $importButton=Find-NamedControl $script:editors[$game].Form 'qrImportPlaceholder'
  $importButton.Text='QRから電波入力';$importButton.Enabled=$true;$importButton.TabStop=$false
  $importButton.Font=New-Object Drawing.Font('Yu Gothic UI',8)
  $importAction=${function:Show-DenpaQrFaceImport}
  $importContext=@{Form=$form;Editors=$script:editors;Modules=$script:editorModuleByGame;State=$state;OpenAction=${function:Open-DenpaImportBitmap};ApplyAction=${function:Set-DenpaImportedFace}}
  $importButton.Add_Click(({
    & $importAction $localGame $importContext
  }.GetNewClosure()))
  $partsButton=Find-NamedControl $script:editors[$game].Form 'facePartsTableButton'
  $partsButton.Enabled=$true;$partsButton.TabStop=$true
  $partsAction=${function:Show-DenpaPartsTable};$partsRoot=$PSScriptRoot;$partsOwner=$form
  $partsButton.Add_Click(({
    try{& $partsAction $partsRoot $partsOwner ($env:DENPA_EDITOR_LANGUAGE-eq'English') $localGame}
    catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'QREditor','OK','Error')}
  }.GetNewClosure()))
  $button.Add_Click(({
    try{& $localModule {param($game) Confirm-DenpaTemplateSave $game} $localGame}
    catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'QREditor',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)}
  }.GetNewClosure()))
}

function Get-CommonValue($Info, [string]$Key) {
  if ($Key -eq 'name') {
    $nameControl = $Info.Map.name
    return $(if ($nameControl) { $nameControl.Text } else { $null })
  }
  $control = $Info.Map[$Key]
  if (-not $control) { return $null }
  if ($control -is [Windows.Forms.TextBox]) { return $control.Text }
  return $control.SelectedIndex
}

function Set-CommonValue($Info, [string]$Key, $Value) {
  if ($null -eq $Value) { return $false }
  if ($Key -eq 'name') {
    $nameControl = $Info.Map.name
    if (-not $nameControl) { return $true }
    if ($nameControl -is [Windows.Forms.ComboBox]) {
      $target = $nameControl.Items.IndexOf([string]$Value)
      if ($target -lt 0) {
        $nameControl.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDown
        $nameControl.Text = [string]$Value
      } else { $nameControl.SelectedIndex = $target }
    } else {
      $nameControl.Text = [string]$Value
    }
    $nameControl.BackColor = [Drawing.SystemColors]::Window
    return $true
  }
  $control = $Info.Map[$Key]
  if (-not $control) { return $true }
  if ($control -is [Windows.Forms.TextBox]) { $control.Text = [string]$Value; $control.BackColor = [Drawing.SystemColors]::Window; return $true }
  if ([int]$Value -lt 0 -or [int]$Value -ge $control.Items.Count) {
    # A part that does not exist in the destination game is normalized to the
    # first valid choice.  Leaving SelectedIndex at -1 made the preview and QR
    # generator inherit a half-switched state.
    $control.SelectedIndex = $(if ($control.Items.Count -gt 0) { 0 } else { -1 })
    $control.BackColor = [Drawing.SystemColors]::Window
    return ($control.Items.Count -gt 0)
  }
  $control.SelectedIndex = [int]$Value
  $control.BackColor = [Drawing.SystemColors]::Window
  return $true
}

$commonKeys = @('name','antenna','personality','body','head','stature','hair','contour','hairColor','brow','eyes','nose','mouth','cheeks','glasses','skin')
$supportedMaxByGame = @{
  # 旧RPG1 Editor本体の実コンボ数から確定した上限。
  RPG1 = @{ antenna=45; head=23; contour=8; hair=23; hairColor=11; brow=7; eyes=31; nose=15; mouth=31; cheeks=7; glasses=15; skin=3 }
  # RPG2側で確認済みの値。別作品から未定義値が渡った場合の0変換に使う。
  RPG2 = @{ personality=11; head=31; stature=29; contour=11; hair=31; hairColor=15; brow=15; eyes=39; nose=23; mouth=31; cheeks=7; glasses=15; skin=5; antenna=67 }
}
$unimplementedByGame = @{
  RPG2 = @{
    head=@(32..39); contour=@(12..17); hair=@(32..63); hairColor=@(12..15)
    brow=@(16..20); eyes=@(40..48); nose=@(24..33); mouth=@(32..41)
    cheeks=@(8..11); glasses=@(16..25); skin=@(6..15); antenna=@(68..84)
  }
}
foreach ($key in $commonKeys) {
  $value = Get-CommonValue $rpg3 $key
  if ($null -ne $value) { $state.Shared[$key] = $value }
}

function Update-Compatibility([string]$Game) {
  $info = $script:editors[$Game]
  if ($Game -eq 'RPG1') {
    if ($info.Display) { $info.Display.Enabled = $true }
    $rpg1.Map.qrPreview.Visible = $true
    $rpg1Block.Visible = $false
    $compatibility.Text = 'RPG1：RPG2・RPG3とは同期せず、RPG1内の設定だけで生成します。'
    $compatibility.ForeColor = [Drawing.Color]::FromArgb(32, 105, 62)
    return $true
  }
  $issues = New-Object System.Collections.Generic.List[string]
  foreach ($key in $commonKeys) {
    if ($key -eq 'name' -and $Game -eq 'RPG2') { continue }
    $targetControl = $info.Map[$key]
    $supportedMax = $null
    if ($supportedMaxByGame.ContainsKey($Game) -and $supportedMaxByGame[$Game].ContainsKey($key)) {
      $supportedMax = [int]$supportedMaxByGame[$Game][$key]
    }
    if ($key -ne 'name' -and $targetControl -is [Windows.Forms.ComboBox]) {
      $sharedIndex = [int]$state.Shared[$key]
      # RPG1の24～39は3D確認用の名称付き未定義頭。手動選択時だけ表示を保持し、QR生成は止める。
      if($Game-eq'RPG1'-and$key-eq'head'-and$state.ActiveGame-eq'RPG1'-and((24..39)-contains$sharedIndex)){
        $targetControl.SelectedIndex=$sharedIndex;$targetControl.BackColor=[Drawing.Color]::MistyRose;$issues.Add('頭の形');continue
      }
      # RPG2画面で「未定義」枠を手動選択した場合だけは保持する。
      # RPG3からRPG2へ切り替える途中ではActiveGameがRPG3のままなので、
      # 同じ数値でも従来どおり0へ正規化される。
      $rpg2UnimplementedValues = if($Game -eq 'RPG2' -and $unimplementedByGame.RPG2.ContainsKey($key)){ @($unimplementedByGame.RPG2[$key]) }else{ @() }
      $isRpg2Unimplemented = ($rpg2UnimplementedValues -contains $sharedIndex)
      $manualRpg2Placeholder = ($Game -eq 'RPG2' -and $state.ActiveGame -eq 'RPG2' -and $isRpg2Unimplemented)
      if ($sharedIndex -lt 0 -or $sharedIndex -ge $targetControl.Items.Count -or ($isRpg2Unimplemented -and -not $manualRpg2Placeholder) -or ($null -ne $supportedMax -and $sharedIndex -gt $supportedMax -and -not $manualRpg2Placeholder)) {
        # The conversion is intentional and becomes the new shared value, so
        # a later version switch cannot restore the unsupported stale index.
        $state.Shared[$key] = 0
      }
    }
    # 髪が主入力。同期中かつ髪が0以外なら、輪郭は各作品の髪対応表で
    # 自動選択された値を保持し、共有輪郭で上書きしない。
    if ($key -eq 'contour') {
      $faceSync = Find-NamedControl $info.Form 'faceSyncCheck'
      $targetHair = Get-CommonValue $info 'hair'
      if ($faceSync -and $faceSync.Checked -and $null -ne $targetHair -and [int]$targetHair -gt 0) {
        $state.Shared.contour = Get-CommonValue $info 'contour'
        continue
      }
    }
    if (-not (Set-CommonValue $info $key $state.Shared[$key])) {
      $labels = @{ head='頭の形'; body='体色'; stature='体格'; contour='輪郭'; hair='髪'; hairColor='髪色'; brow='眉'; eyes='目'; nose='鼻'; mouth='口'; cheeks='頬'; glasses='顔装備'; skin='肌色'; antenna='アンテナ'; personality='性格'; name='名前' }
      $issues.Add($labels[$key])
    }
  }
  $valid = ($issues.Count -eq 0)
  if ($info.Display) { $info.Display.Enabled = $valid }
  if ($Game -eq 'RPG1') {
    $rpg1.Map.qrPreview.Visible = $valid
    $rpg1Block.Visible = -not $valid
    if (-not $valid) { $rpg1Block.BringToFront() }
  }
  if ($valid) {
    $compatibility.Text = "$Game：顔パーツを反映しました。この作品固有の項目だけ画面内容が切り替わります。"
    $compatibility.ForeColor = [Drawing.Color]::FromArgb(32, 105, 62)
  } else {
    $compatibility.Text = "$Game 未定義：$($issues -join '、')。対応するパーツへ変更するまでQR表示を停止します。"
    $compatibility.ForeColor = [Drawing.Color]::FromArgb(185, 45, 45)
  }
  return $valid
}

function Show-EditorChild([string]$Game) {
  foreach ($entry in $script:editors.GetEnumerator()) {
    $candidate = $entry.Value['Form']
    if ($candidate -is [Windows.Forms.Form]) { $candidate.Hide() }
  }
  $activeInfo = $script:editors[$Game]
  if (-not $activeInfo) { throw "Editor情報がありません: $Game" }
  $activeChild = $activeInfo['Form']
  if ($activeChild -isnot [Windows.Forms.Form]) {
    $actualType = if ($null -eq $activeChild) { '<null>' } else { $activeChild.GetType().FullName }
    throw "Editor画面の型が不正です: $Game / $actualType"
  }
  if ($activeChild.Parent -ne $contentHost) {
    if ($activeChild.Parent) { $activeChild.Parent.Controls.Remove($activeChild) }
    $contentHost.Controls.Add($activeChild)
  }
  $activeChild.TopLevel = $false
  $activeChild.FormBorderStyle = 'None'
  $activeChild.Dock = 'Fill'
  [void]$activeChild.CreateControl()
  $activeChild.Show()
  $activeChild.Visible = $true
  $activeChild.BringToFront()
  $contentHost.Controls.SetChildIndex($activeChild, 0)
  $contentHost.PerformLayout()
  $activeChild.Refresh()
}

function Queue-GameInitialization([string]$Game) {
  if ($smokeMode -and $smokeMode -notin @('live','startup','switch-ready')) { return }
  foreach($pendingTimer in $script:initTimers){$pendingTimer.Stop();$pendingTimer.Dispose()}
  $script:initTimers=@()
  $localGame = $Game
  $localModule = $script:editorModuleByGame[$Game]
  if (-not $localModule) { return }
  $timer = New-Object Windows.Forms.Timer
  # Let the controls paint before QR generation, then render the heavier 3D
  # preview later. This keeps low-end dual-core PCs responsive while switching.
  $timer.Interval = 650
  $timer.Add_Tick({
    $this.Stop()
    try {
      if($state.ActiveGame-ne$localGame){return}
      switch ($localGame) {
        'RPG1' { & $localModule { $autoQrTimer.Stop();$autoQrTimer.Interval=80;$autoQrTimer.Start();$modelPreviewTimer.Stop();$modelPreviewTimer.Interval=900;$modelPreviewTimer.Start() } }
        'RPG2' { & $localModule { $autoQrTimer.Stop();$autoQrTimer.Interval=80;$autoQrTimer.Start();$facePreviewTimer.Stop();$facePreviewTimer.Interval=900;$facePreviewTimer.Start() } }
        'RPG3' { & $localModule { $autoQrTimer.Stop();$autoQrTimer.Interval=80;$autoQrTimer.Start();$modelPreviewTimer.Stop();$modelPreviewTimer.Interval=900;$modelPreviewTimer.Start() } }
      }
    } catch {
      $compatibility.Text = "$localGame の初期描画エラー: $($_.Exception.Message)"
      $compatibility.ForeColor = [Drawing.Color]::FromArgb(185,45,45)
      $compatibility.Visible = $true
    } finally { $this.Dispose() }
  }.GetNewClosure())
  $script:initTimers += $timer
  $timer.Start()
}

function Show-Game([string]$Game) {
  $state.Syncing = $true
  try {
    # Read the editor that is actually on screen immediately before switching.
    # This makes version changes deterministic even when a child ComboBox event
    # was suppressed while the unified shell was synchronizing controls.
    if ($state.ActiveGame -and $state.ActiveGame -ne $Game -and $state.ActiveGame -ne 'RPG1' -and $script:editors.ContainsKey($state.ActiveGame)) {
      $sourceInfo = $script:editors[$state.ActiveGame]
      foreach ($key in $commonKeys) {
        $current = Get-CommonValue $sourceInfo $key
        if ($null -ne $current -and ($key -eq 'name' -or [int]$current -ge 0)) { $state.Shared[$key] = $current }
      }
    }
    foreach ($entry in $script:editors.GetEnumerator()) { $entry.Value.Form.Visible = $false }
    [void](Update-Compatibility $Game)
    $state.ActiveGame = $Game
    if ($form.Visible -or $smokeMode -eq 'live') {
      Show-EditorChild $Game
      Queue-GameInitialization $Game
    }
    foreach ($entry in $versionButtons.GetEnumerator()) {
      $selected = ($entry.Key -eq $Game)
      $entry.Value.BackColor = if ($selected) { [Drawing.Color]::FromArgb(76, 34, 93, 173) } else { [Drawing.Color]::FromArgb(24, 255, 255, 255) }
      $entry.Value.FlatAppearance.BorderColor = if ($selected) { [Drawing.Color]::FromArgb(215, 32, 105, 196) } else { [Drawing.Color]::FromArgb(110, 82, 129, 169) }
    }
    $form.Text = "Denpa QREditor2.3 1.0.1 - $Game"
  } finally { $state.Syncing = $false }
}

function Register-SharedEvents($Info, [string]$Game) {
  foreach ($key in $commonKeys) {
    $control = $Info.Map[$key]
    if (-not $control) { continue }
    $localKey = $key; $localInfo = $Info; $localGame = $Game
    $handler = {
      if ($state.Syncing -or $state.ActiveGame -ne $localGame) { return }
      # 同期チェック中の輪郭変更は、髪の選択イベントが自動で発生させたもの。
      # 先に輪郭イベントで古い共有髪を再適用すると、選んだ髪が元へ戻るため無視する。
      if($localKey-eq'contour'){
        $localFaceSync=Find-NamedControl $localInfo.Form 'faceSyncCheck'
        $localHair=Get-CommonValue $localInfo 'hair'
        if($localFaceSync-and$localFaceSync.Checked-and$null-ne$localHair-and[int]$localHair-gt0){return}
      }
      $value = Get-CommonValue $localInfo $localKey
      if ($null -ne $value) { $state.Shared[$localKey] = $value }
      # 正規候補フィルターは顔パーツ変更の途中で名前・性格を先に更新する。
      # ここで全項目を再適用すると、まだ共有状態へ届いていない新しい顔パーツを
      # 古い値で上書きしてしまう。名前・性格は状態だけ保存し、顔を再同期しない。
      if($localKey-eq'name'-or$localKey-eq'personality'){return}
      if ($localKey -eq 'hair') {
        $state.Shared.contour = Get-CommonValue $localInfo 'contour'
      }
      $state.Syncing = $true
      try { [void](Update-Compatibility $localGame) } finally { $state.Syncing = $false }
    }.GetNewClosure()
    if ($localKey -eq 'name' -or $control -is [Windows.Forms.TextBox]) { $control.Add_TextChanged($handler) } else { $control.Add_SelectedIndexChanged($handler) }
  }
}

Register-SharedEvents $rpg2 'RPG2'
Register-SharedEvents $rpg3 'RPG3'
foreach ($game in @('RPG1','RPG2','RPG3')) {
  $localGame = $game
  $versionButtons[$game].Add_Click(({ Show-Game $localGame }.GetNewClosure()))
}

$form.Add_FormClosed({
  foreach ($entry in $script:editors.GetEnumerator()) { try { $entry.Value.Form.Close(); $entry.Value.Form.Dispose() } catch {} }
  foreach ($module in $script:modules) { try { Remove-Module $module -Force } catch {} }
  if ($script:applicationIcon) { $script:applicationIcon.Dispose(); $script:applicationIcon = $null }
})

Show-Game 'RPG3'
# A nested WinForms Form shown before its parent handle exists can remain blank
# on some Windows/graphics environments. Reattach and show the active editor
# once the unified shell is actually visible.
$form.Add_Shown({
  $showTimer = New-Object Windows.Forms.Timer
  $showTimer.Interval = 40
  $showTimer.Add_Tick({
    $this.Stop()
    try {
      Show-EditorChild $state.ActiveGame
      Queue-GameInitialization $state.ActiveGame
      $contentHost.Invalidate($true)
      $contentHost.Update()
    } catch {
      $compatibility.Text = '画面表示エラー: ' + $_.Exception.Message
      $compatibility.ForeColor = [Drawing.Color]::FromArgb(185,45,45)
      $compatibility.Visible = $true
    } finally { $this.Dispose() }
  })
  $script:initTimers += $showTimer
  $showTimer.Start()
})
if($smokeMode-eq'nono-selection'){
  foreach($game in @('RPG1','RPG2','RPG3')){
    Show-Game $game
    & $script:editorModuleByGame[$game] {
      param($gameName)
      $towerCombinationCheck.Checked=$false;$definedFaceCheck.Checked=$false
      if($faceSyncCheck){$faceSyncCheck.Checked=$false};if($legitimateFaceCheck){$legitimateFaceCheck.Checked=$false}
      $hairIndex=if($gameName-eq'RPG1'){25}elseif($gameName-eq'RPG2'){[Array]::IndexOf([object[]]$codesByKey['--hair'],[object]'19')}else{[Array]::IndexOf([object[]]$fieldCodesByKey['--hair'],[object]'19')}
      $eyeIndex=if($gameName-eq'RPG1'){36}elseif($gameName-eq'RPG2'){[Array]::IndexOf([object[]]$codesByKey['--eyes'],[object]'24')}else{[Array]::IndexOf([object[]]$fieldCodesByKey['--eyes'],[object]'24')}
      foreach($reverse in @($false,$true)){
        $boxes['--hair'].SelectedIndex=0;$boxes['--eyes'].SelectedIndex=0
        if($reverse){$boxes['--eyes'].SelectedIndex=$eyeIndex;$boxes['--hair'].SelectedIndex=$hairIndex}else{$boxes['--hair'].SelectedIndex=$hairIndex;$boxes['--eyes'].SelectedIndex=$eyeIndex}
        if($boxes['--hair'].SelectedIndex-ne0-or$boxes['--eyes'].SelectedIndex-ne0){throw "$gameName forbidden selection did not reset both parts"}
      }
      if($script:nonoSelectionGuard.Resets-lt2){throw "$gameName selection guard did not run"}
      foreach($key in @('--hair','--eyes','--eyebrow','--nose','--mouth','--cheeks')){
        if([string]$boxes[$key].Items[0]-ne'00'){throw "$gameName unpadded zero in $key"}
        foreach($text in $boxes[$key].Items){if([string]$text-match'^\d$'){throw "$gameName unpadded numeric face option"}}
      }
    } $game
  }
  foreach($language in @('English','Japanese')){
    Set-EditorLanguage $language
    foreach($game in @('RPG1','RPG2','RPG3')){& $script:editorModuleByGame[$game] {if($boxes['--hair'].Items[0]-ne'00'){throw 'Language switch lost numeric padding'}}}
  }
  & $script:editorModuleByGame.RPG3 {
    foreach($length in @(88,160)){
      foreach($at in @(43,48)){if((Get-DenpaDebugByteLabel 3 $length $at $false)-notmatch'未確定.*正規入力有り'){throw 'Unknown character label failed'}}
      if((Get-DenpaDebugByteLabel 3 $length 51 $false)-ne'アンテナ進化段階'){throw 'Antenna evolution label failed'}
      if((Get-DenpaDebugByteLabel 3 $length 82 $false)-match'旧フラグ'){throw 'Obsolete flags label remains'}
    }
  }
  $global:DenpaNonoGuardEnabled=$false
  foreach($game in @('RPG1','RPG2','RPG3')){
    $child=$script:editors[$game].Form
    $guard=Find-NamedControl $child 'nonoGuardCheck';$guard.Checked=$global:DenpaNonoGuardEnabled
    if($guard.Enabled-or$guard.Checked-or(Find-NamedControl $child 'xProfileLink')){throw 'Disabled guard UI / main X removal failed'}
    & $script:editorModuleByGame[$game] {
      param($gameName)
      Assert-DenpaNonoGuard 25 36
      $hairIndex=if($gameName-eq'RPG1'){25}elseif($gameName-eq'RPG2'){[Array]::IndexOf([object[]]$codesByKey['--hair'],[object]'19')}else{[Array]::IndexOf([object[]]$fieldCodesByKey['--hair'],[object]'19')}
      $eyeIndex=if($gameName-eq'RPG1'){36}elseif($gameName-eq'RPG2'){[Array]::IndexOf([object[]]$codesByKey['--eyes'],[object]'24')}else{[Array]::IndexOf([object[]]$fieldCodesByKey['--eyes'],[object]'24')}
      $boxes['--hair'].SelectedIndex=$hairIndex;$boxes['--eyes'].SelectedIndex=$eyeIndex
      if($boxes['--hair'].SelectedIndex-ne$hairIndex-or$boxes['--eyes'].SelectedIndex-ne$eyeIndex){throw 'Guard disabled but selection reset'}
      if($gameName-ne'RPG1'){
        $plain=Get-DenpaDebugInitial ([int]$gameName.Substring(3)) 0
        if($gameName-eq'RPG2'){$plain[0x66]=25;$plain[0x69]=36}else{$plain[0x23]=25;$plain[0x25]=36}
        [void](ConvertTo-DenpaDebugQr $plain $true ([int]$gameName.Substring(3)))
      }
    } $game
  }
  $global:DenpaNonoGuardEnabled=$true
  Write-Output 'NONO_ON_OFF_SELECTION_RAW_DEBUG_DISABLED_UI_MAIN_X_REMOVED_OK'
  Write-Output 'NONO_SELECTION_RESET_BOTH_ORDERS_ALL_GAMES_PADDING_LANGUAGE_DEBUG_OK'
  $form.Dispose();return
}
if($smokeMode-eq'protagonists-random'){
  foreach($game in @('RPG1','RPG2','RPG3')){
    $child=$script:editors[$game].Form
    foreach($buttonName in @('randomQrButton','debugModeButton','leftReserved1','leftReserved2','facePartsTableButton')){
      if(-not(Find-NamedControl $child $buttonName)){throw ('Missing left button '+$game+' '+$buttonName)}
    }
    $random=Find-NamedControl $child 'randomQrButton';$import=Find-NamedControl $child 'qrImportPlaceholder'
    if($random.Bottom-ge$import.Top-or$random.Right-ge$script:editors[$game].Map.qrPreview.Left-and$game-eq'RPG1'){throw 'Left button overlap'}
    & $script:editorModuleByGame[$game] {
      param($game)
      # Exercise selection without interactive caution dialogs.
      function Show-Rpg3ProtagonistCaution {}
      $catalog=@(Import-DenpaTemplateCatalog -ApplicationRoot $PSScriptRoot -Game $game)
      $protagonists=@($catalog|Where-Object{$_.Label-like'*(主人公)'})
      $expected=switch($game){'RPG1'{31};'RPG2'{47};'RPG3'{79}}
      if($protagonists.Count-ne$expected-or$protagonists[3].Name-ne'ピッド'){throw ('Protagonist count/order failed '+$game)}
      foreach($template in @($protagonists|Where-Object FacePartsPending)){
        $before=@{};foreach($key in @('--hair','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses')){$before[$key]=$boxes[$key].SelectedIndex}
        Apply-DenpaSavedTemplate $template $game
        foreach($key in $before.Keys){if($boxes[$key].SelectedIndex-ne$before[$key]){throw ('Pending template overwrote face '+$template.Name)}}
        foreach($entry in $template.Fields.GetEnumerator()){
          $actual=switch($game){'RPG1'{$boxes[$entry.Key].SelectedIndex.ToString()};'RPG2'{Get-Code $boxes[$entry.Key]};'RPG3'{Get-FieldCode $boxes[$entry.Key]}}
          if($actual-ne$entry.Value){throw ('Template mapping failed '+$template.Name+' '+$entry.Key)}
        }
        foreach($language in $template.Names.Keys){if($nameLanguage.Boxes[$language].Text-ne$template.Names[$language]){throw ('Regional name failed '+$template.Name+' '+$language)}}
      }
      if($game-eq'RPG1'){
        if(($rpg1StatsValues-join',')-ne'384,320,321,322,385,325,3,0,1,2,326,324,9,10,6,7,11,327,8,330,328,329,333,387,386,331,332'){throw 'RPG1 packed body values changed'}
        if($boxes['--stature'].Items[5]-ne'3-最速'-or$boxes['--stature'].Items[23]-ne'10最大'){throw 'RPG1 corrected stature labels failed'}
      }
      $keep=@{};foreach($key in @('--name','--head-shape','--body-color','--stature','--antenna','--skin-color','--face-image','--hair-color')){if($boxes.ContainsKey($key)){$keep[$key]=$boxes[$key].Text}}
      $syncControl=if($game-eq'RPG3'){$legitimateFaceCheck}else{$faceSyncCheck}
      $syncControl.Checked=$true
      for($iteration=0;$iteration-lt30;$iteration++){
        Set-DenpaRandomFace $game
        foreach($key in $keep.Keys){if($boxes[$key].Text-ne$keep[$key]){throw ('Random changed unrelated field '+$game+' '+$key)}}
        foreach($key in @('--hair','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses')){if($boxes[$key].Text-match'未定義'){throw ('Random undefined face '+$game+' '+$key)}}
      }
      Show-DenpaDebugPlaceholder $game
      if($game-eq'RPG1'){
        Sync-Rpg1Backend
        if(-not$script:rpg1GeneratedCipher){throw 'Random RPG1 QR encoding failed'}
      }else{
        $autoQrTimer.Stop()
        $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance')
        [void]$click.Invoke($displayButton,@([EventArgs]::Empty))
        if(-not$script:currentQrPath-or-not(Test-Path $script:currentQrPath)-or-not$saveButton.Enabled){throw ('Random QR generation failed '+$game)}
      }
      if(-not$script:debugPlaceholder-or$script:debugPlaceholder.Controls.Count-ne1){throw 'Debug placeholder failed'}
      $script:debugPlaceholder.Close();$script:debugPlaceholder.Dispose()
      Write-Output ($game+'_PROTAGONISTS_RANDOM_OK count='+$expected)
    } $game
  }
  Set-EditorLanguage 'English'
  if((Find-NamedControl $rpg3Form 'randomQrButton').Text-ne'Random QR'-or(Find-NamedControl $rpg3Form 'debugModeButton').Text-ne'Debug Mode'){throw 'New button translation failed'}
  Set-EditorLanguage 'Japanese'
  Write-Output 'PROTAGONISTS_RANDOM_DEBUG_TRANSLATION_OK'
  $form.Dispose();return
}
if ($smokeMode -eq 'rpg1') {
  Show-Game 'RPG1'
  $rpg1State = & $script:editorModuleByGame.RPG1 {
    Sync-Rpg1Backend
    [pscustomobject]@{
      QrReady = [bool]$qr.Image
      CipherLength = $script:rpg1GeneratedCipher.Length
      Header = [Text.Encoding]::ASCII.GetString($script:rpg1GeneratedPlain, 0, 4)
    }
  }
  if ($state.ActiveGame -ne 'RPG1') { throw 'RPG1 child editor did not become active.' }
  if (-not $rpg1State.QrReady -or $rpg1State.CipherLength -ne 106 -or $rpg1State.Header -ne 'bX80') { throw 'RPG1 independent QR did not initialize in the unified editor.' }
  Write-Output 'UNIFIED_RPG1_INDEPENDENT_CODEC_AND_QR_OK'
  $form.Close()
  return
}
if($smokeMode-eq'hair-contour'){
  Show-Game 'RPG2'
  $rpg2.Map.contour.SelectedIndex=8;$rpg2.Map.hair.SelectedIndex=3
  if($rpg2.Map.hair.SelectedIndex-ne3-or$rpg2.Map.contour.SelectedIndex-ne4-or$rpg2.Map.contour.Enabled){throw "Unified RPG2 hair-primary synchronization failed: hair=$($rpg2.Map.hair.SelectedIndex) contour=$($rpg2.Map.contour.SelectedIndex) enabled=$($rpg2.Map.contour.Enabled) sharedHair=$($state.Shared.hair) sharedContour=$($state.Shared.contour)"}
  Show-Game 'RPG3'
  if($rpg3.Map.hair.SelectedIndex-ne3-or$rpg3.Map.contour.SelectedIndex-ne4-or$rpg3.Map.contour.Enabled){throw 'Unified RPG2 to RPG3 hair-primary synchronization failed.'}
  $rpg3.Map.hair.SelectedIndex=7
  if($rpg3.Map.contour.SelectedIndex-ne1){throw 'Unified RPG3 hair-primary synchronization failed.'}
  Show-Game 'RPG2'
  if($rpg2.Map.hair.SelectedIndex-ne7-or$rpg2.Map.contour.SelectedIndex-ne1){throw 'Unified RPG3 to RPG2 hair-primary synchronization failed.'}
  Write-Output 'UNIFIED_HAIR_PRIMARY_CONTOUR_SYNC_OK';$form.Close();return
}
if($smokeMode-eq'language'){
  Set-EditorLanguage 'English'
  $compositeCardName=& $script:editorModuleByGame.RPG3 {$old=@($nameLanguage.Boxes.JP.Text,$nameLanguage.Boxes.NA.Text,$nameLanguage.Boxes.EU.Text);try{$nameLanguage.Syncing=$true;$nameLanguage.Boxes.JP.Text='A';$nameLanguage.Boxes.NA.Text='B';$nameLanguage.Boxes.EU.Text='B';$nameLanguage.Syncing=$false;Get-DenpaCardDisplayName $nameLanguage}finally{$nameLanguage.Syncing=$true;try{$nameLanguage.Boxes.JP.Text=$old[0];$nameLanguage.Boxes.NA.Text=$old[1];$nameLanguage.Boxes.EU.Text=$old[2]}finally{$nameLanguage.Syncing=$false}}}
  if($compositeCardName-ne'A / B / B'){throw "Regional card-name composition failed: $compositeCardName"}
  foreach($game in @('RPG1','RPG2','RPG3')){
    $controls=@(Get-EditorControls $script:editors[$game].Form)
    $hasFace=[bool]($controls|Where-Object{$_.Text-eq'Face Parts'});$hasTemplate=[bool]($controls|Where-Object{$_.Text-eq'Denpa Template'});$hasPreview=[bool]($controls|Where-Object{$_.Text-eq'Preview'});$hasDiscord=[bool]($controls|Where-Object{$_.Name-eq'discordServerLink'-and$_.Text-eq'Discord Server'});if(-not$hasFace-or-not$hasTemplate-or-not$hasPreview-or-not$hasDiscord){throw "$game English control translation failed: face=$hasFace template=$hasTemplate preview=$hasPreview discord=$hasDiscord"}
    if($script:editors[$game].Map.personality.Items-notcontains'Strawberry'-or$script:editors[$game].Map.personality.Items-notcontains'None'){throw "$game English personality-none translation failed."}
    if($game-eq'RPG2'-and($script:editors[$game].Map.personality.Items-notcontains'Protagonist'-or$script:editors[$game].Map.personality.Items[-1]-ne'Amber')){throw 'RPG2 English story-personality translation failed.'}
    if($game-eq'RPG3'-and($script:editors[$game].Map.personality.Items-notcontains'Protagonist(Caution)'-or$script:editors[$game].Map.personality.Items[-1]-ne'Mary')){throw 'RPG3 English story-personality translation failed.'}
    if($script:editors[$game].Map.head.Items[0]-ne'Round'-or$script:editors[$game].Map.head.Items[1]-ne'Wide Oval'-or$script:editors[$game].Map.head.Items[2]-ne'Tall Oval'-or$script:editors[$game].Map.head.Items[3]-ne'Triangle'){throw "$game English head-shape translation failed."}
    if($script:editors[$game].Map.body.Items[0]-ne'Black'-or$script:editors[$game].Map.body.Items[8]-ne'Red / Light Blue'-or$script:editors[$game].Map.hairColor.Items[2]-ne'Brown'){throw "$game English body/hair-color translation failed."}
    $definedCheck=Find-NamedControl $script:editors[$game].Form 'definedFaceCheck';if(-not$definedCheck.Checked){throw "$game defined-only startup default failed."};$definedCheck.Checked=$false
    if($game-eq'RPG1'){
      if($script:editors[$game].Map.hairColor.Items.Count-ne12-or$script:editors[$game].Map.skin.Items.Count-ne6){throw 'RPG1 legitimate hair/skin color range failed.'}
      if($script:editors[$game].Map.glasses.Items[0]-ne'None'-or$script:editors[$game].Map.glasses.Items[1]-ne'Green Glasses'-or$script:editors[$game].Map.antenna.Items[0]-ne'No antenna'){throw 'RPG1 English face/antenna translation failed.'}
      $deu=Find-NamedControl $script:editors[$game].Form 'nameLanguageDEU';$fra=Find-NamedControl $script:editors[$game].Form 'nameLanguageFRA';$deuCheck=Find-NamedControl $script:editors[$game].Form 'nameLanguageCheckDEU';$fraCheck=Find-NamedControl $script:editors[$game].Form 'nameLanguageCheckFRA';if(-not$deuCheck.Enabled-or-not$fraCheck.Enabled-or$deu.Items.Count-ne1000-or$fra.Items.Count-ne1000){throw 'RPG1 DEU/FRA name catalog activation failed.'}
    }else{
      if($script:editors[$game].Map.head.Items[32]-notlike'Rabbit Ears*'){throw "$game English named undefined-head restore failed: $($script:editors[$game].Map.head.Items[32])"};if($script:editors[$game].Map.glasses.Items[0]-ne'None'-or$script:editors[$game].Map.glasses.Items[1]-ne'Green Glasses'-or$script:editors[$game].Map.glasses.Items[16]-notlike'Star Glasses*'){throw "$game English face-equipment translation failed."};if($script:editors[$game].Map.antenna.Items[0]-ne'No antenna'-or$script:editors[$game].Map.antenna.Items[67]-ne'Dark Mist'){throw "$game English antenna translation failed."}
      $deu=Find-NamedControl $script:editors[$game].Form 'nameLanguageDEU';$fra=Find-NamedControl $script:editors[$game].Form 'nameLanguageFRA';if($deu.Items.Count-ne1917-or$fra.Items.Count-ne1917){throw "$game DEU/FRA name catalog activation failed: $($deu.Items.Count)/$($fra.Items.Count)"}
    };$definedCheck.Checked=$true
  }
  if((Convert-EditorItemText '未定義(12)' 'English')-ne'undefined(12)'){throw 'English undefined translation failed.'}
  if((Convert-EditorItemText 'HPマスター！' 'English')-ne'HP Master!'-or(Convert-EditorItemText 'そうじゅく！' 'English')-ne'Quick Grower!'){throw 'English correction translation failed.'}
  if($env:DENPA_EDITOR_LANGUAGE-ne'English'-or$script:englishButton.BackColor-ne[Drawing.Color]::FromArgb(196,225,248)){throw 'English language state/button failed.'}
  $localizedEquipment=& $script:editorModuleByGame.RPG2 {
    [pscustomobject]@{
      Neck=$neckBox.Items[[Array]::IndexOf([object[]]$neckEquipmentCodes,[object]'0180')]
      Arm=$armBox.Items[[Array]::IndexOf([object[]]$armEquipmentCodes,[object]'0200')]
      Back=$backBox.Items[[Array]::IndexOf([object[]]$backEquipmentCodes,[object]'01BA')]
      Feet=$feetBox.Items[[Array]::IndexOf([object[]]$feetEquipmentCodes,[object]'0230')]
      Clothing=$clothingBox.Items[[Array]::IndexOf([object[]]$clothingCodes,[object]'0654')]
    }
  }
  if($localizedEquipment.Neck-ne'Wakeup Scarf'-or$localizedEquipment.Arm-ne'Cheap Watch'-or$localizedEquipment.Back-ne'Fan'-or$localizedEquipment.Feet-ne'Speed Anklet'-or$localizedEquipment.Clothing-ne'Stripes'){throw("RPG2 English equipment-ID localization failed: "+($localizedEquipment|ConvertTo-Json -Compress))}
  $localizedContent=& $script:editorModuleByGame.RPG3 {
    $monsterIndex=[Array]::IndexOf([object[]]$monsterCodes,[object]'01');$itemIndex=[Array]::IndexOf([object[]]$script:activeItemRewardCodes,[object]'0001')
    $script:rewardCatalogMode='';Set-ExtendedRewardCatalog;Set-Rpg3ContentLanguage 'English';$decorIndex=[Array]::IndexOf([object[]]$script:extendedRewardCodes[1],[object]'0296')
    [pscustomobject]@{Monster=$capturedMonster.Items[$monsterIndex];Crash=$capturedMonster.Items[$capturedMonster.Items.Count-1];Item=$itemRewards[0].Items[$itemIndex+1];Decor=$itemRewards[1].Items[$decorIndex+1]}
  }
  if($localizedContent.Monster-ne'Flower Mole'-or$localizedContent.Crash-ne'No antenna(Crash)'-or$localizedContent.Item-ne'Potion'-or[string]::IsNullOrWhiteSpace($localizedContent.Decor)-or$localizedContent.Decor-match'[ぁ-んァ-ヶ一-龠]'){throw("RPG3 English content-ID localization failed: "+($localizedContent|ConvertTo-Json -Compress))}
  $localizedRewardLabels=& $script:editorModuleByGame.RPG3 {[pscustomobject]@{Jewel=$jewelQuantityLabel.Text;Item=$itemRewardLabels[0].Text;Decor1=$itemRewardLabels[1].Text}}
  if($localizedRewardLabels.Jewel-ne'Jewels'-or$localizedRewardLabels.Item-ne'Item'-or$localizedRewardLabels.Decor1-ne'Decorate1'){throw("RPG3 English reward-label translation failed: "+($localizedRewardLabels|ConvertTo-Json -Compress))}
  $monsterLabel=& $script:editorModuleByGame.RPG3 {$capturedCheck.Text};if($monsterLabel-ne'Monster'){throw "RPG3 Monster label translation failed: $monsterLabel"}
  $form.Show();Show-Game 'RPG3';[Windows.Forms.Application]::DoEvents();$capture=New-Object Drawing.Bitmap($form.Width,$form.Height);$form.DrawToBitmap($capture,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$capturePath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\tests\unified-editor-english-rpg3.png'));[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($capturePath))|Out-Null;$capture.Save($capturePath,[Drawing.Imaging.ImageFormat]::Png);$capture.Dispose()
  Set-EditorLanguage 'Japanese'
  foreach($game in @('RPG1','RPG2','RPG3')){$controls=@(Get-EditorControls $script:editors[$game].Form);if(-not($controls|Where-Object{$_.Text-eq'電波テンプレート'})-or-not($controls|Where-Object{$_.Text-eq'プレビュー'})){throw "$game Japanese terminology failed."};if($script:editors[$game].Map.head.Items[0]-ne'まる'-or$script:editors[$game].Map.body.Items[0]-ne'黒'-or$script:editors[$game].Map.hairColor.Items[2]-ne'茶'){throw "$game Japanese head/body/hair restore failed."}}
  $restoredEquipment=& $script:editorModuleByGame.RPG2 {[pscustomobject]@{Neck=$neckBox.Items[1];Arm=$armBox.Items[1];Back=$backBox.Items[1];Feet=$feetBox.Items[1];Clothing=$clothingBox.Items[1]}}
  if($restoredEquipment.Neck-ne'めざましのスカーフ'-or$restoredEquipment.Arm-ne'やすいとけい'-or$restoredEquipment.Back-ne'うちわ'-or$restoredEquipment.Feet-ne'すばやさアンクレット'-or$restoredEquipment.Clothing-ne'ストライプ'){throw("RPG2 Japanese equipment restore failed: "+($restoredEquipment|ConvertTo-Json -Compress))}
  Write-Output ('UNIFIED_JAPANESE_ENGLISH_TRANSLATION_OK '+$capturePath);$form.Close();return
}
if($smokeMode-eq'advanced-qr'){
  & $script:editorModuleByGame.RPG3 {if($specialCodeValues[$extendedSpecialCode.SelectedIndex]-ne'01'){throw 'RPG3 default special ID is not 01'}}
  & $script:editorModuleByGame.RPG1 {
    $regionButtons['JP'].Checked=$true;Sync-Rpg1Backend
    $before=[byte[]]$script:rpg1GeneratedPlain.Clone()
    Show-DenpaAdvancedQrSettings 'RPG1';$w=$script:advancedQrWindow
    $panel=@($w.Controls|Where-Object{$_-is[Windows.Forms.Panel]})[0]
    $checks=@($panel.Controls|Where-Object{$_-is[Windows.Forms.CheckBox]})
    if($checks.Count-ne25-or@($checks|Where-Object Checked).Count-ne0){throw 'RPG1 advanced fields/default failed'}
    $shot=New-Object Drawing.Bitmap $w.Width,$w.Height
    try{$w.DrawToBitmap($shot,(New-Object Drawing.Rectangle(0,0,$w.Width,$w.Height)));$shot.Save([IO.Path]::GetFullPath('work/rpg1-advanced-settings-20261005.png'),[Drawing.Imaging.ImageFormat]::Png)}finally{$shot.Dispose()}
    foreach($check in $checks){$check.Checked=$true;$check.Tag.Value=$check.Tag.Maximum}
    @($w.Controls|Where-Object{$_-is[Windows.Forms.Button]-and$_.Text-eq'設定反映'})[0].PerformClick()
    Sync-Rpg1Backend;$after=$script:rpg1GeneratedPlain
    foreach($spec in @(Get-DenpaRpg1RawSpecs)){
      if((($after[$spec[3]]-shr$spec[4])-band$spec[2])-ne$spec[2]){throw ('RPG1 advanced raw output failed: '+$spec[1])}
    }
    $masks=New-Object byte[] 53
    foreach($spec in @(Get-DenpaRpg1RawSpecs)){$masks[$spec[3]]=$masks[$spec[3]]-bor($spec[2]-shl$spec[4])}
    for($i=0;$i-lt53;$i++){if((($before[$i]-bxor$after[$i])-band(255-bxor$masks[$i]))-ne0){throw 'RPG1 known field changed'} }
    if([DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Decrypt1($script:rpg1GeneratedCipher))-ne[DenpaQrVerification.Core]::Hex($after)){throw 'RPG1 advanced encode roundtrip failed'}
    $template=Get-DenpaCurrentTemplate 'RPG1';$script:advancedQrState=@{Level=$null;Unknown=@{}};Apply-DenpaSavedTemplate $template 'RPG1'
    if((Get-DenpaAdvancedQrState).Unknown.Count-ne25){throw 'RPG1 advanced template restore failed'}
    foreach($region in @('NA','EU')){
      $regionButtons[$region].Checked=$true;Sync-Rpg1Backend;$with=$script:rpg1GeneratedPlain.Clone()
      $saved=$script:advancedQrState;$script:advancedQrState=@{Level=$null;Unknown=@{}};Sync-Rpg1Backend;$without=$script:rpg1GeneratedPlain.Clone();$script:advancedQrState=$saved
      for($i=38;$i-lt50;$i++){if($with[$i]-ne$without[$i]){throw 'RPG1 JP override changed NA/EU name'} }
    }
    $script:advancedQrState=@{Level=$null;Unknown=@{}};$regionButtons['JP'].Checked=$true;Sync-Rpg1Backend
    Write-Output 'ADVANCED_QR_RPG1_25_FIELDS_MASKS_REGIONS_TEMPLATE_OK'
  }
  $form.Show();Show-Game 'RPG3';Show-EditorChild 'RPG3'
  foreach($game in @('RPG1','RPG2','RPG3')){
    $child=$script:editors[$game].Form
    $advanced=Find-NamedControl $child 'advancedQrButton';$import=Find-NamedControl $child 'qrImportPlaceholder'
    $debug=Find-NamedControl $child 'debugModeButton'
    if($advanced.Text-ne'QR詳細設定'-or$debug.Bottom-ge$advanced.Top-or$advanced.Top-ne$import.Top){throw 'Advanced button layout failed'}
  }
  Set-EditorLanguage 'English'
  if((Find-NamedControl $rpg3Form 'advancedQrButton').Text-ne'Advanced QR Settings'){throw 'Advanced translation failed'}
  Set-EditorLanguage 'Japanese'
  & $script:editorModuleByGame.RPG3 {
    $qrType.SelectedIndex=0;$qrDate.Checked=$false
    if($sourceLevelCheck.Visible-or$sourceLevelInput.Visible){throw 'Old level controls still visible'}
    if($capturedCheck.Top-ge$jewelQuantityLabel.Top){throw 'Monster/jewel order failed'}
    Show-DenpaAdvancedQrSettings 'RPG3';$w=$script:advancedQrWindow
    if(@($w.Controls|Where-Object{$_-is[Windows.Forms.GroupBox]}).Count){throw 'Removed date display controls remain'}
    $combo=@($w.Controls|Where-Object{$_-is[Windows.Forms.ComboBox]})[0]
    $combo.SelectedIndex=9
    @($w.Controls|Where-Object{$_-is[Windows.Forms.Button]-and$_.Text-eq'設定反映'})[0].PerformClick()
    if((Get-Rpg3SourceLevel)-ne10){throw 'Advanced level apply failed'}
    $dateArgs=@(Get-DenpaAdvancedQrArguments 3);if(($dateArgs-join' ')-notmatch'--qr-date-mode 01'){throw 'Unchecked date mode failed'}
    $qrDate.Checked=$true
    Show-DenpaAdvancedQrSettings 'RPG3';$w=$script:advancedQrWindow
    $check=@($w.Controls|Where-Object{$_-is[Windows.Forms.CheckBox]-and$_.Text-eq'0x30'})[0]
    $check.Checked=$true;$check.Tag.Value=0x12
    $specialCheck=@($w.Controls|Where-Object{$_-is[Windows.Forms.CheckBox]-and$_.Text-like'0x5E*'})[0]
    if(-not$specialCheck.Enabled){throw 'Special settings should be editable before selecting special QR'}
    $specialCheck.Checked=$true;$specialCheck.Tag.Value=2
    $w.Refresh();$shot=New-Object Drawing.Bitmap($w.Width,$w.Height)
    try{$w.DrawToBitmap($shot,(New-Object Drawing.Rectangle(0,0,$w.Width,$w.Height)));$shot.Save([IO.Path]::GetFullPath('work/advanced-qr-settings.png'),[Drawing.Imaging.ImageFormat]::Png)}finally{$shot.Dispose()}
    @($w.Controls|Where-Object{$_-is[Windows.Forms.Button]-and$_.Text-eq'設定反映'})[0].PerformClick()
    $dateArgs=@(Get-DenpaAdvancedQrArguments 3);if(($dateArgs-join' ')-notmatch'--qr-date-mode 02'-or($dateArgs-join' ')-notmatch'--qr-meta-30 12'){throw 'Advanced date/raw apply failed'}
    if('--qr-special-meta-5e'-in$dateArgs-or(Get-DenpaAdvancedQrState).Unknown['--qr-special-meta-5e']-ne2){throw 'Special setting should be saved but not applied to normal QR'}
    $capturedCheck.Checked=$true;$capturedMonster.SelectedIndex=[Array]::IndexOf([object[]]$monsterCodes,[object]'A3')
    & $displayAction
    $v=New-Object 'Collections.Generic.Dictionary[string,string]'
    for($i=2;$i-lt$script:lastGenerateArguments.Count;$i+=2){$v[$script:lastGenerateArguments[$i]]=$script:lastGenerateArguments[$i+1]}
    $v.Remove('--png')|Out-Null
    $b=[DenpaQrVerification.Core]::Plain(3,[DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Edit(3,$v)))
    if($b.Length-ne88-or$b[0x34]-ne0xA3-or$b[0x53]-ne2-or$b[0x30]-ne0x12-or[BitConverter]::ToUInt16($b,0x36)-ne10){throw 'Advanced normal output failed'}
    $template=Get-DenpaCurrentTemplate 'RPG3';if($template.SavedOptions.AdvancedQR.ContainsKey('DateMode')){throw 'Removed date choice still saved'}
    $template.SavedOptions.AdvancedQR.DateMode=3
    $script:advancedQrState=@{Level=$null;DateMode=$null;Unknown=@{}};Apply-DenpaSavedTemplate $template 'RPG3'
    if((Get-DenpaAdvancedQrState).Unknown['--qr-meta-30']-ne0x12){throw 'Advanced template restore failed'}
    $qrDate.Checked=$false
    if((@(Get-DenpaAdvancedQrArguments 3)-join' ')-notmatch'--qr-date-mode 01'){throw 'Date unchecked after Entry Date failed'}
    $qrDate.Checked=$true
    if((@(Get-DenpaAdvancedQrArguments 3)-join' ')-notmatch'--qr-date-mode 02'){throw 'QR date mode failed'}
    $qrType.SelectedIndex=1
    if((@(Get-DenpaAdvancedQrArguments 3)-join' ')-notmatch'--qr-special-meta-5e 02'){throw 'Saved special setting was not applied after selecting special QR'}
    $qrType.SelectedIndex=0
    Write-Output 'ADVANCED_QR_LEVEL_DATE_RAW_TEMPLATE_NORMAL_MONSTER_OK'
  }
  & $script:editorModuleByGame.RPG2 {
    $modeBox.SelectedIndex=0
    if((@(Get-DenpaAdvancedQrArguments 2)-join' ')-notmatch'--qr-equipment-neck 0000'){throw 'RPG2 default normal equipment is not zero'}
    Show-DenpaAdvancedQrSettings 'RPG2';$w=$script:advancedQrWindow
    $tabs=@($w.Controls|Where-Object{$_-is[Windows.Forms.TabControl]})[0]
    if(@($tabs.TabPages[0].Controls|Where-Object{$_-is[Windows.Forms.CheckBox]}).Count-ne7){throw 'RPG2 differing unknown settings missing'}
    if(@($tabs.TabPages[1].Controls|Where-Object{$_-is[Windows.Forms.CheckBox]}).Count-ne0){throw 'RPG2 equipment checkbox remains'}
    foreach($pair in $tabs.TabPages[1].Tag.Values){$pair.Combo.SelectedIndex=1}
    @($w.Controls|Where-Object{$_-is[Windows.Forms.ComboBox]})[0].SelectedIndex=98
    @($w.Controls|Where-Object{$_-is[Windows.Forms.Button]-and$_.Text-eq'設定反映'})[0].PerformClick()
    if((@(Get-DenpaAdvancedQrArguments 2)-join' ')-notmatch'--source-level 99'){throw 'RPG2 advanced apply failed'}
    if((@(Get-DenpaAdvancedQrArguments 2)-join' ')-notmatch'--qr-equipment-neck 0180'){throw 'RPG2 advanced equipment apply failed'}
    $v=New-Object 'Collections.Generic.Dictionary[string,string]';$v['--carrier']='generated2:normal-shiroganemaru';$v['--source-level']='99'
    $b=[DenpaQrVerification.Core]::Plain(2,[DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Edit(2,$v)))
    if($b[0x38]-ne99){throw 'RPG2 level output failed'}
    $ea=@(Get-DenpaAdvancedQrArguments 2);for($i=0;$i-lt$ea.Count;$i+=2){$v[$ea[$i]]=$ea[$i+1]}
    $b=[DenpaQrVerification.Core]::Plain(2,[DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Edit(2,$v)))
    $packed=[BitConverter]::ToUInt64($b,0x3a)
    if(($packed-band1023)-ne0x180-or($b[0x40]-band4)-ne4){throw ('RPG2 normal equipment packed output failed: {0:X}, flag {1:X}, args {2}'-f $packed,$b[0x40],($ea-join' '))}
    $v['--carrier']='generated2:special-yamana'
    $b=[DenpaQrVerification.Core]::Plain(2,[DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Edit(2,$v)))
    $packed=[BitConverter]::ToUInt64($b,0x3a)
    foreach($slot in @(@('neck',0),@('arm',10),@('feet',20),@('back',30),@('clothing',40))){
      $expected=[Convert]::ToInt32($v['--qr-equipment-'+$slot[0]],16);if($slot[0]-eq'clothing'){$expected-=0x400}
      if((($packed-shr$slot[1])-band1023)-ne$expected){throw ('RPG2 special equipment slot failed: '+$slot[0])}
    }
    foreach($slot in @('neck','arm','feet','back','clothing')){$v['--qr-equipment-'+$slot]='0000'}
    $b=[DenpaQrVerification.Core]::Plain(2,[DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Edit(2,$v)))
    if(([BitConverter]::ToUInt64($b,0x3a)-band0x7FFFFFFFFFFFF)-ne0){throw 'RPG2 empty equipment flag failed'}
    $template=Get-DenpaCurrentTemplate 'RPG2';Apply-DenpaSavedTemplate $template 'RPG2'
    if((Get-DenpaAdvancedQrState).Equipment.neck-ne'0180'){throw 'RPG2 equipment template restore failed'}
    if((Get-Rpg2CardEquipmentNames).Neck-ne$neckBox.Items[1]){throw 'RPG2 normal QR/card equipment text mismatch'}
    $modeBox.SelectedIndex=1
    if((Get-Rpg2CardEquipmentNames).Neck-ne$neckBox.Text){throw 'RPG2 special card equipment text mismatch'}
    if((@(Get-DenpaAdvancedQrArguments 2)-join' ')-match'--qr-equipment-'){throw 'RPG2 detailed equipment overrode special main equipment'}
    Write-Output 'ADVANCED_QR_RPG2_OK'
  }
  $form.Close();return
}
if($smokeMode-eq'template-layout'){
  if($script:taskbarIdentityResult-ne0){throw 'Taskbar identity setup failed'}
  if(-not[object]::ReferenceEquals($form.Icon,$script:applicationIcon)){throw 'Main window icon mismatch'}
  if(($script:startupStages-join'|')-ne'QREditor3 Loading...|QREditor2 Loading...|QREditor Loading...'){throw 'Startup loading sequence mismatch'}
  $form.Show()
  foreach($game in @('RPG1','RPG2','RPG3')){
    Show-Game $game;Show-EditorChild $game
    $child=$script:editors[$game].Form
    if(-not[object]::ReferenceEquals($child.Icon,$script:applicationIcon)-or$child.ShowInTaskbar){throw 'Embedded editor icon/taskbar mismatch'}
    $first=Find-NamedControl $child 'qrImportPlaceholder';$second=Find-NamedControl $child 'templateSavePlaceholder'
    if($first.Text-ne'QRから電波入力'-or-not$first.Enabled-or$second.Text-ne'テンプレート保存'-or-not$second.Enabled){throw 'Import / Save Template button mismatch'}
    $save=Find-ButtonByText $child 'QR保存';$card=Find-ButtonByText $child 'カード表示'
    if($first.Bottom-ge$second.Top-or$second.Bottom-ge$save.Top-or$save.Bottom-ge$card.Top){throw 'Action buttons overlap'}
    $euBox=Find-NamedControl $child 'nameLanguageEU'
    if($script:editors[$game].Map.personality.Size-ne$euBox.Size){throw ($game+' personality/EU size mismatch')}
    if(-not(& $script:editorModuleByGame[$game] {Get-Command Confirm-DenpaTemplateSave -ErrorAction SilentlyContinue})){throw 'Save Template handler unavailable'}
    $advanced=Find-NamedControl $child 'advancedQrButton';if($advanced.Bottom-ge$second.Top){throw 'Five action buttons overlap'}
    Write-Output ($game+' FIVE_BUTTON_LAYOUT_OK')
  }
  foreach($game in @('RPG1','RPG2','RPG3')){
    & $script:editorModuleByGame[$game] {
      $nameLanguage.Syncing=$true
      try{$nameLanguage.Boxes.JP.Text='テル';$nameLanguage.Boxes.NA.Text='Jasper';$nameLanguage.Boxes.EU.Text='Luna';$nameLanguage.Boxes.DEU.Text='Leo';$nameLanguage.Boxes.FRA.Text='Mars'}finally{$nameLanguage.Syncing=$false}
    }
  }
  foreach($language in @('English','Japanese','English','Japanese')){
    Set-EditorLanguage $language
    foreach($game in @('RPG1','RPG2','RPG3')){
      $expectedButton=if($language-eq'English'){'Save Template'}else{'テンプレート保存'}
      if((Find-NamedControl $script:editors[$game].Form 'templateSavePlaceholder').Text-ne$expectedButton){throw 'Save Template translation mismatch'}
      $expectedImport=if($language-eq'English'){'Import Denpa from QR'}else{'QRから電波入力'}
      if((Find-NamedControl $script:editors[$game].Form 'qrImportPlaceholder').Text-ne$expectedImport){throw 'QR import placeholder translation mismatch'}
      if($game-eq'RPG3'){
        $expectedStory=if($language-eq'English'){@('Protagonist(Caution)','Jasper(Proportion Change)','Amber(Proportion Change)')}else{@('主人公(注意)','テル(頭身変化)','ルナ(頭身変化)')}
        foreach($text in $expectedStory){if($script:editors[$game].Map.personality.Items-notcontains$text){throw ('Story annotation translation mismatch: '+$text)}}
      }
      if(-not(Get-Command Show-DenpaQrFaceImport -ErrorAction SilentlyContinue)){throw 'QR import handler unavailable'}
      $names=& $script:editorModuleByGame[$game] {$nameLanguage.Boxes.JP.Text,$nameLanguage.Boxes.NA.Text,$nameLanguage.Boxes.EU.Text,$nameLanguage.Boxes.DEU.Text,$nameLanguage.Boxes.FRA.Text}
      if(($names-join'|')-ne'テル|Jasper|Luna|Leo|Mars'){throw ('Language switching changed character names: '+$game+' '+($names-join'|'))}
    }
  }
  Write-Output 'NAME_FIELDS_PRESERVED_ON_LANGUAGE_SWITCH_OK'
  [Windows.Forms.Application]::DoEvents()
  $capture=New-Object Drawing.Bitmap($form.Width,$form.Height)
  $form.DrawToBitmap($capture,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
  $capturePath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..\work\template-button-layout.png'))
  $capture.Save($capturePath,[Drawing.Imaging.ImageFormat]::Png);$capture.Dispose()
  Write-Output ('STARTUP_LOADING_SEQUENCE_OK '+$capturePath);$form.Close();return
}
if($smokeMode-eq'switch-ready'){
  $form.Show()
  try{
    foreach($game in @('RPG3','RPG2','RPG3','RPG2','RPG3')){
      $module=$script:editorModuleByGame[$game]
      $oldPath=& $module {$script:currentQrPath}
      Show-Game $game
      $deadline=[DateTime]::UtcNow.AddSeconds(20)
      do{
        [Windows.Forms.Application]::DoEvents()
        $ready=& $module {[pscustomobject]@{Path=$script:currentQrPath;Save=$saveButton.Enabled;Card=$cardButton.Enabled;Model=[bool]$facePreview.Image;Status=$status.Text}}
        if($ready.Path-and$ready.Path-ne$oldPath-and$ready.Save-and$ready.Card-and$ready.Model){break}
        Start-Sleep -Milliseconds 20
      }while([DateTime]::UtcNow-lt$deadline)
      if(-not$ready.Path-or$ready.Path-eq$oldPath-or-not$ready.Save-or-not$ready.Card-or-not$ready.Model){throw("$game switch readiness failed: "+($ready|ConvertTo-Json -Compress))}
      Write-Output ("SWITCH_QR_SAVE_CARD_READY "+$game)
    }
    foreach($language in @('English','Japanese')){
      Set-EditorLanguage $language
      $labels=@(Get-EditorControls $rpg3.Form|Where-Object{$_-is[Windows.Forms.Label]}|ForEach-Object{$_.Text})
      $expected=if($language-eq'English'){@('Doping Fruit','Max HP','Max AP','Attack','Defend','Speed')}else{@('ドーピングフルーツ','さいだいHP','さいだいAP','こうげきりょく','ぼうぎょりょく','すばやさ')}
      foreach($text in $expected){if($labels-notcontains$text){throw("Missing translated label: "+$text)}}
    }
    $rpg1White=& $script:editorModuleByGame.RPG1 {$face.BackColor.ToArgb()-eq[Drawing.Color]::White.ToArgb()}
    $rpg2White=& $script:editorModuleByGame.RPG2 {$facePreview.BackColor.ToArgb()-eq[Drawing.Color]::White.ToArgb()}
    if(-not$rpg1White-or-not$rpg2White){throw 'RPG1/RPG2 preview background is not white.'}
    $rpg3.Map.personality.SelectedIndex=11
    Show-Game 'RPG2'
    if($rpg2.Map.personality.SelectedIndex-ne11){throw 'Story personality was lost on version switch.'}
    Write-Output 'SWITCH_TRANSLATION_WHITE_PREVIEW_AND_STORY_OK'
  }finally{$form.Close()}
  return
}
if ($smokeMode -eq 'release-101') {
  & $script:editorModuleByGame.RPG1 {
    if($antenna[24]-ne'ふゆのひざし'-or$rpg1AntennaGroupCodes[24]-ne64){throw 'RPG1 Winter Sunlight label/preview failed'}
    $boxes['--antenna'].SelectedIndex=24
    Sync-Rpg1Backend
    $low=$script:rpg1GeneratedPlain[8]-band63
    $high=(($script:rpg1GeneratedPlain[19]-shr6)-bor($script:rpg1GeneratedPlain[20]-shl2))-band127
    if($low-ne11-or$high-ne90){throw 'RPG1 Winter Sunlight QR ID changed'}
    $path=Join-Path ([IO.Path]::GetTempPath()) ('denpa-winter-'+[Guid]::NewGuid().ToString('N')+'.png')
    try{[void](New-Rpg1ModelPng $path);if(-not(Test-Path $path)){throw 'Winter preview missing'}}finally{if(Test-Path $path){Remove-Item -LiteralPath $path}}
  }
  foreach($game in @('RPG2','RPG3')){
    & $script:editorModuleByGame[$game] {
      param($game)
      $catalog=if($game-eq'RPG2'){$rpg2Templates}else{$rpg3Templates}
      $luna=@($catalog|Where-Object Name -eq 'ルナ')
      if($luna.Count-ne1){throw 'Amber template missing or duplicated'}
      $index=[Array]::IndexOf([object[]]$catalog,[object]$luna[0])
      $faceTemplateBox.SelectedIndex=$index+1
      foreach($entry in $luna[0].Fields.GetEnumerator()){
        $actual=if($game-eq'RPG2'){Get-Code $boxes[$entry.Key]}else{Get-FieldCode $boxes[$entry.Key]}
        if($actual-ne$entry.Value){throw ("Amber field mismatch: "+$game+" "+$entry.Key+" "+$actual)}
      }
      $autoQrTimer.Stop()
      $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance')
      [void]$click.Invoke($displayButton,@([EventArgs]::Empty))
      if(-not$script:currentQrPath-or-not(Test-Path $script:currentQrPath)-or-not$saveButton.Enabled){throw ('Amber QR generation failed: '+$game)}
      if($luna[0].Fields['--body-color']-ne'20'-or$boxes['--body-color'].Text-ne'桃'){throw 'Amber pink body-color failed'}
      foreach($key in @('--hair','--personality','--antenna','--body-color')){
        $argIndex=[Array]::IndexOf([object[]]$script:lastGenerateArguments,[object]$key)
        if($argIndex-lt0-or$script:lastGenerateArguments[$argIndex+1]-ne$luna[0].Fields[$key]){throw ('Amber QR field mismatch: '+$key)}
      }
      foreach($lang in @('JP','NA','EU','DEU','FRA')){
        $expected=if($lang-eq'JP'){'ルナ'}else{'Amber'}
        if($nameLanguage.Boxes[$lang].Text-ne$expected){throw ('Amber name mismatch: '+$lang)}
      }
    } $game
  }
  Set-EditorLanguage 'English'
  if($script:editors.RPG1.Map.antenna.Items[24]-ne'Winter Sunlight'){throw 'Winter Sunlight translation failed'}
  foreach($game in @('RPG2','RPG3')){
    & $script:editorModuleByGame[$game] {if($faceTemplateBox.Text-ne'Amber(Story)'){throw 'Amber Story translation failed'}}
  }
  Set-EditorLanguage 'Japanese'
  Write-Output 'RELEASE_101_WINTER_QR_PREVIEW_TRANSLATION_AMBER_TEMPLATES_OK'
  $form.Dispose()
  return
}
if ($smokeMode -eq 'startup') {
  $form.Show()
  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  $startupState = $null
  while ([DateTime]::UtcNow -lt $deadline) {
    [Windows.Forms.Application]::DoEvents()
    $startupState = & $script:editorModuleByGame.RPG3 {
      [pscustomobject]@{ QrReady=[bool]$preview.Image; ModelReady=[bool]$facePreview.Image }
    }
    if ($rpg3.Form.Visible -and $startupState.QrReady -and $startupState.ModelReady) { break }
    Start-Sleep -Milliseconds 25
  }
  if (-not $rpg3['Form'].Visible) { throw 'RPG3 child editor did not become visible after the shell was shown.' }
  if (-not $startupState.QrReady) { throw 'RPG3 initial QR was not generated.' }
  if (-not $startupState.ModelReady) { throw 'RPG3 initial 3D preview was not generated.' }
  Write-Output 'UNIFIED_RPG3_VISIBLE_INITIAL_QR_AND_3D_OK'
  $form.Close()
  return
}
if($smokeMode-eq'input-templates'){
  foreach($game in @('RPG1','RPG2','RPG3')){& $script:editorModuleByGame[$game] {
    if($nameLanguage.IndividualCheck.Checked){throw 'Individual-name checkbox must default to unchecked'}
    $nameLanguage.IndividualCheck.Checked=$true
    foreach($l in $nameLanguage.ActiveLanguages){$nameLanguage.Boxes[$l].Text=$l+'Test'}
  }}
  Set-EditorLanguage 'English'
  foreach($game in @('RPG1','RPG2','RPG3')){& $script:editorModuleByGame[$game] {
    if($nameLanguage.IndividualCheck.Text-ne'Enter Names Individually'){throw 'Individual-name checkbox translation failed'}
    foreach($l in $nameLanguage.ActiveLanguages){if($nameLanguage.Boxes[$l].Text-ne($l+'Test')){throw 'Language switch overwrote regional name'}}
  }}
  Set-EditorLanguage 'Japanese'
  foreach($game in @('RPG1','RPG2','RPG3')){& $script:editorModuleByGame[$game] {if($nameLanguage.IndividualCheck.Text-ne'名前を個別入力'){throw 'Individual-name Japanese restore failed'}}}
  Write-Output 'UNIFIED_INDIVIDUAL_NAMES_LANGUAGE_OK';$form.Close();return
}
if($smokeMode-eq'call-lab'){
  Show-Game 'RPG2'
  & $script:editorModuleByGame.RPG2 {Set-Rpg2TemplateCode '--personality' '00';Set-Rpg2TemplateCode '--antenna' '2C';$script:callLab.Check.Checked=$true;$script:callLab.Combo.SelectedIndex=3}
  Set-EditorLanguage 'English'
  & $script:editorModuleByGame.RPG2 {
    if($script:callLab.Check.Text-ne'Select Ability for RPG3'-or$script:callLab.Combo.Text-ne'Antenna Change!'-or$script:callLab.Target.Text-ne'Fire Cracker'){throw ('Call lab English translation failed: '+$script:callLab.Check.Text+' / '+$script:callLab.Combo.Text+' / '+$script:callLab.Target.Text)}
    Set-Rpg2TemplateCode '--antenna' '03';if($script:callLab.Combo.Text-ne'Quick Grower!'){throw 'Dynamic English ability translation failed'}
  }
  Set-EditorLanguage 'Japanese'
  & $script:editorModuleByGame.RPG2 {if($script:callLab.Combo.Text-ne'そうじゅく！'){throw 'Japanese ability restore failed'}}
  Show-Game 'RPG1';Set-EditorLanguage 'English'
  & $script:editorModuleByGame.RPG1 {if($script:callLab.Check.Text-ne'Select Ability for RPG3'-or$script:callLab.Combo.Items-notcontains'Strong!'){throw 'RPG1 ability translation failed'}}
  Show-Game 'RPG3';Show-Game 'RPG2'
  Write-Output 'UNIFIED_CALL_LAB_LANGUAGE_AND_SWITCH_OK';$form.Close();return
}
if($smokeMode-eq'language-performance'){
  function Get-LanguageQrHashes([switch]$Generate) {
    $hashes=@()
    foreach($game in @('RPG1','RPG2','RPG3')){
      $editor=$script:editors[$game]
      if($Generate){[void][Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance').Invoke($editor.Display,@([EventArgs]::Empty))}
      $qrImage=& $script:editorModuleByGame[$game] {if($preview){$preview.Image}else{$qr.Image}}
      if(-not$qrImage){throw ($game+' QR generation failed.')}
      $stream=New-Object IO.MemoryStream;$sha=[Security.Cryptography.SHA256]::Create()
      try{$qrImage.Save($stream,[Drawing.Imaging.ImageFormat]::Png);$hashes+=([BitConverter]::ToString($sha.ComputeHash($stream.ToArray())))}finally{$sha.Dispose();$stream.Dispose()}
    }
    $hashes-join'|'
  }
  function Get-LanguageSelectionSnapshot {
    $snapshot=@()
    foreach($game in @('RPG1','RPG2','RPG3')){
      foreach($control in @(Get-EditorControls $script:editors[$game].Form)){
        if($control-is[Windows.Forms.ComboBox]){$snapshot+=($game+'|'+$control.Name+'|'+$control.SelectedIndex)}
        if($control-is[Windows.Forms.Button]){$snapshot+=($game+'|button|'+$control.Name+'|'+$control.Enabled)}
      }
      $snapshot+=(& $script:editorModuleByGame[$game] {foreach($key in $nameLanguage.ActiveLanguages){$key+'|'+$nameLanguage.Boxes[$key].Text}})
    }
    $snapshot-join"`n"
  }
  # RPG2 deliberately randomizes an identity byte on generation. Compare the
  # displayed QR without generating again: a language-only switch must retain it.
  $qrBefore=Get-LanguageQrHashes -Generate
  $before=Get-LanguageSelectionSnapshot
  foreach($language in @('English','Japanese','English','Japanese')){
    $watch=[Diagnostics.Stopwatch]::StartNew();Set-EditorLanguage $language;$watch.Stop()
    Write-Output ('LANGUAGE_'+$language+'_MS='+$watch.ElapsedMilliseconds)
    if((Get-LanguageSelectionSnapshot)-cne$before){throw 'Language switch changed selected values or names.'}
  }
  if((Get-LanguageQrHashes)-cne$qrBefore){throw 'Language switch changed generated QR images.'}
  foreach($module in @($script:editorModuleByGame.Values)){& $module {if($script:editorLanguageUpdating){throw 'Language update guard was not cleared.'}}}
  Write-Output 'LANGUAGE_SELECTIONS_AND_NAMES_PRESERVED'
  Write-Output 'LANGUAGE_QR_IMAGES_AND_BUTTON_STATES_PRESERVED'
  $form.Close();return
}
if($smokeMode-eq'debug-formats'){
  $form.Show()
  foreach($pair in @(@('最大','Largest'),@('準大','Large'),@('中間','Average'),@('準速','Fast'),@('最速','Fastest'))){
    foreach($prefix in @('','3-','6+','16')){
      $jp=$prefix+$pair[0];$en=$prefix+$pair[1]
      if((Convert-EditorLanguageItem '--stature' $jp 'English')-ne$en-or(Convert-EditorLanguageItem '--stature' $en 'Japanese')-ne$jp){throw 'Stature translation mismatch'}
    }
  }
  foreach($game in @('RPG1','RPG2','RPG3')){
    Show-Game $game;Show-EditorChild $game
    & $script:editorModuleByGame[$game] {
      param($number)
      Show-DenpaDebugQr $number 0
      $w=$script:debugQrWindow;$g=$w.Controls.Find('debugByteGrid',$true)[0];$selector=$w.Controls.Find('debugQrFormat',$true)[0]
      $expected=if($number-eq1){53}elseif($number-eq2){120}else{88}
      if($g.Rows.Count-ne$expected){throw 'Normal debug length failed'}
      if($g.Columns[1].DefaultCellStyle.BackColor-ne[Drawing.Color]::LightYellow-or$g.Columns[0].DefaultCellStyle.BackColor-ne[Drawing.Color]::Gainsboro){throw 'Debug edit colors missing'}
      $links=$w.Controls.Find('debugDiscoveryContact',$true)[0]
      if($links-isnot[Windows.Forms.LinkLabel]-or$links.Links.Count-ne2){throw 'Debug contact links missing'}
      Assert-DenpaNonoGuard 25 35;Assert-DenpaNonoGuard 24 36
      $blocked=$false;try{Assert-DenpaNonoGuard 25 36}catch{$blocked=$_.Exception.Message-like'*ののガード*'}
      if(-not$blocked){throw 'Nono Guard did not reject forbidden pair'}
      if($number-gt1){
        $ha=if($number-eq2){0x66}else{0x23};$ea=if($number-eq2){0x69}else{0x25}
        $probe=[byte[]]$w.Tag.State.Result.Plain.Clone();$probe[$ha]=25;$probe[$ea]=36
        $blocked=$false;try{[void](ConvertTo-DenpaDebugQr $probe $true $number)}catch{$blocked=$_.Exception.Message-like'*ののガード*'}
        if(-not$blocked){throw 'Debug bypasses Nono Guard'}
      }
      if($w.Controls.Find('debugDiscoveryContact',$true)[0].Text-ne'新たな発見があった場合はDiscord / X までご連絡ください。'){throw 'Contact notice missing'}
      if($number-eq2-and($g.Rows[94].Cells[2].Value-notlike'個体属性*'-or$g.Rows[95].Cells[2].Value-notlike'アンテナ段階*'-or$g.Rows[113].Cells[2].Value-notlike'セーブHP*')){throw 'RPG2 research labels missing'}
      if($number-eq3-and($g.Rows[51].Cells[2].Value-ne'アンテナ進化段階'-or$g.Rows[83].Cells[2].Value-ne'日付区分')){throw 'RPG3 stage / date labels missing'}
      $original=[byte[]]$w.Tag.State.Result.Plain.Clone()
      $g.Rows[8].Cells[1].Value='FF';& $w.Tag.Render
      if($w.Tag.State.Result.Plain[8]-ne255){throw 'Raw FF lost'}
      if($number-eq1){
        if($selector.Enabled-or$w.Tag.State.Result.Payload.Length-ne106){throw 'RPG1 format failed'}
        $decoded=[DenpaQrVerification.Core]::Decrypt1($w.Tag.State.Result.Payload)
        if([DenpaQrVerification.Core]::Hex($decoded)-ne[DenpaQrVerification.Core]::Hex($w.Tag.State.Result.Plain)){throw 'RPG1 roundtrip failed'}
        for($i=0;$i-lt53;$i++){if($i-ne8-and$decoded[$i]-ne$original[$i]){throw 'RPG1 CRC altered data'}}
      }else{
        $selector.SelectedIndex=1
        $w=$script:debugQrWindow;$g=$w.Controls.Find('debugByteGrid',$true)[0]
        if($g.Rows.Count-ne$(if($number-eq2){288}else{160})-or$w.Text-notlike'*特典QR'){throw 'Format selector special failed'}
        if($number-eq3-and($g.Rows[85].Cells[2].Value-ne'ジュエル個数'-or$g.Rows[86].Cells[2].Value-ne'アイテム(2バイト)'-or$g.Rows[88].Cells[2].Value-ne'家具1(2バイト)'-or$g.Rows[92].Cells[2].Value-ne'家具3(2バイト)')){throw 'RPG3 reward labels mismatch'}
        $w.Controls.Find('debugQrFormat',$true)[0].SelectedIndex=0
        $w=$script:debugQrWindow
        if($w.Controls.Find('debugByteGrid',$true)[0].Rows.Count-ne$expected){throw 'Format selector normal failed'}
      }
      $dir=[IO.Path]::GetFullPath('outputs/qr/debug-formats-20261011');[void][IO.Directory]::CreateDirectory($dir)
      $payload=$w.Tag.State.Result.Payload;$bitmap=[DenpaQrVerification.Core]::Bitmap($payload)
      try{$bitmap.Save((Join-Path $dir ('RPG'+$number+'.png')))}finally{$bitmap.Dispose()}
      [IO.File]::WriteAllText((Join-Path $dir ('RPG'+$number+'.hex')),[DenpaQrVerification.Core]::Hex($payload))
      [Windows.Forms.Application]::DoEvents();$shot=New-Object Drawing.Bitmap($w.Width,$w.Height)
      try{$w.DrawToBitmap($shot,(New-Object Drawing.Rectangle(0,0,$w.Width,$w.Height)));$shot.Save((Join-Path $dir ('RPG'+$number+'-screen.png')))}finally{$shot.Dispose()}
      $w.Close();Write-Output ('RPG'+$number+' DEBUG_FORMAT_RAW_ROUNDTRIP_OK')
    } ([int]$game.Substring(3))
  }
  Set-EditorLanguage 'English'
  & $script:editorModuleByGame.RPG1 {Show-DenpaDebugQr 1;if($script:debugQrWindow.Text-notlike'*RPG1 Normal QR'){throw 'RPG1 English failed'};$script:debugQrWindow.Close()}
  Write-Output 'DEBUG_FORMATS_ALL_GAMES_OK';$form.Close();return
}
if($smokeMode-eq'rpg2-paint'){
  $form.Show();Show-Game 'RPG2';Show-EditorChild 'RPG2'
  & $script:editorModuleByGame.RPG2 {$rpg2PaintBox.SelectedIndex=32;$autoQrTimer.Stop()}
  foreach($paintLanguage in @('Japanese','English')){
    Set-EditorLanguage $paintLanguage
    & $script:editorModuleByGame.RPG2 {
      if($rpg2PaintBox.SelectedIndex-ne32-or$rpg2PaintBox.Items.Count-ne34){throw 'Paint language changed selection'}
      if($rpg2PaintLabel.Top-le$rpg2MemoBox.Bottom-or$rpg2PaintBox.Left-ne$rpg2MemoBox.Left-or$rpg2PaintLabel.Bottom-ge$rpg2PaintBox.Top-or$rpg2PaintBox.Bottom-gt$form.ClientSize.Height){throw ('Paint layout clips or overlaps: labelBottom='+$rpg2PaintLabel.Bottom+' boxTop='+$rpg2PaintBox.Top+' boxBottom='+$rpg2PaintBox.Bottom+' clientHeight='+$form.ClientSize.Height)}
      [Windows.Forms.Application]::DoEvents()
    }
    $shot=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try{
      $folder=[IO.Path]::GetFullPath('outputs/verification/rpg2-paint-ui-20261013');[IO.Directory]::CreateDirectory($folder)|Out-Null
      $form.DrawToBitmap($shot,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
      $shot.Save((Join-Path $folder ('unified-paint-'+$paintLanguage+'.png')))
    }finally{$shot.Dispose()}
  }
  Write-Output 'RPG2_PAINT_UNIFIED_JAPANESE_ENGLISH_LAYOUT_OK';$form.Close();return
}
if($smokeMode-eq'rpg2-memo'){
  $form.Show();Show-Game 'RPG2';Show-EditorChild 'RPG2'
  & $script:editorModuleByGame.RPG2 {$rpg2MemoBox.Text='名前';$autoQrTimer.Stop()}
  Set-EditorLanguage 'English'
  & $script:editorModuleByGame.RPG2 {
    if($rpg2MemoLabel.Text-ne'Memo'-or$rpg2MemoBox.Text-ne'名前'){throw 'Memo translation changed input'}
    $modeBox.SelectedIndex=0;$autoQrTimer.Stop();Show-DenpaDebugQr 2
    if($script:debugQrWindow.Controls.Find('debugByteGrid',$true)[0].Rows[16].Cells[2].Value-notlike'Memo*'){throw 'English memo debug label missing'}
    $script:debugQrWindow.Close()
  }
  Set-EditorLanguage 'Japanese'
  & $script:editorModuleByGame.RPG2 {
    if($rpg2MemoLabel.Text-ne'メモ'-or$rpg2MemoBox.Text-ne'名前'){throw 'Memo Japanese restore failed'}
    [Windows.Forms.Application]::DoEvents()
    $shot=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try{$form.DrawToBitmap($shot,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$shot.Save([IO.Path]::GetFullPath('outputs/qr/rpg2-memo-editor-20261011/unified-memo-screen.png'))}finally{$shot.Dispose()}
  }
  Write-Output 'RPG2_MEMO_UNIFIED_LANGUAGE_INPUT_PRESERVED_OK';$form.Close();return
}
if($smokeMode-eq'debug-all'){
  $form.Show()
  foreach($game in @('RPG3','RPG2')){
    Show-Game $game;Show-EditorChild $game
    foreach($specialMode in @(0,1)){
      & $script:editorModuleByGame[$game] {
        param($game,$specialMode)
        $number=[int]$game.Substring(3)
        if($number-eq3){$qrType.SelectedIndex=$specialMode}else{$modeBox.SelectedIndex=$specialMode}
        Show-DenpaDebugQr $number
        $w=$script:debugQrWindow;$grid=$w.Controls.Find('debugByteGrid',$true)[0]
        $length=if($number-eq3){if($specialMode){160}else{88}}else{if($specialMode){288}else{120}}
        if($grid.Rows.Count-ne$length){throw 'Debug row count mismatch'}
        for($i=0;$i-lt$length;$i++){if($grid.Rows[$i].Cells[0].Value-ne('0x{0:X2}'-f$i)){throw 'Offset order failed'}}
        if($number-eq3){
          if($grid.Rows[53].Cells[2].Value-ne'補正(上位4bit)・基礎能力成長タイプ(下位4bit・0B～0F未確定) [正規入力有り]'-or$grid.Rows[56].Cells[2].Value-ne'さいだいHP(2バイト)'-or$grid.Rows[58].Cells[2].Value-ne'さいだいAP(2バイト)'-or$grid.Rows[60].Cells[2].Value-ne'こうげきりょく(2バイト)'-or$grid.Rows[62].Cells[2].Value-ne'ぼうぎょりょく(2バイト)'-or$grid.Rows[64].Cells[2].Value-ne'すばやさ(2バイト)'){throw 'Stat labels mismatch'}
          if($specialMode-and$grid.Rows[84].Cells[2].Value-ne'特典ID'){throw 'Special ID confused with normal CRC'}
        }elseif($grid.Rows[62].Cells[2].Value-match'ぼうぎょ|Defense'){throw 'RPG2 equipment mislabeled as stats'}
        $at=if($number-eq3){0x2c}else{0x62};$grid.Rows[$at].Cells[1].Value='FF'
        & $w.Tag.Render
        $result=$w.Tag.State.Result
        if($result.Plain[$at]-ne255-or$w.Tag.State.Dirty){throw 'Raw edit normalized or generation failed'}
        if([DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Plain($number,[DenpaQrVerification.Core]::Hex($result.Payload)))-ne[DenpaQrVerification.Core]::Hex($result.Plain)){throw 'Cipher roundtrip failed'}
        if([BitConverter]::ToUInt32($result.Plain,$length-4)-ne[DenpaQrVerification.Core]::Crc($result.Plain,$length-4)){throw 'Auto CRC failed'}
        $auto=@($w.Controls|Where-Object{$_-is[Windows.Forms.CheckBox]})[0];$auto.Checked=$false
        for($i=0;$i-lt$length;$i++){$grid.Rows[$i].Cells[1].Value='FF'}
        & $w.Tag.Render
        if([DenpaQrVerification.Core]::Hex($w.Tag.State.Result.Plain)-ne('ff'*$length)){throw 'All-byte editing failed'}
        @($w.Controls|Where-Object{$_-is[Windows.Forms.Button]-and$_.Text-eq'開いた時の値に戻す'})[0].PerformClick()
        $auto.Checked=$true;& $w.Tag.Render
        $dir=[IO.Path]::GetFullPath('outputs/qr/debug-all-20261011');[void][IO.Directory]::CreateDirectory($dir)
        $stem=$game+'-'+$(if($specialMode){'special'}else{'normal'})
        $picture=@($w.Controls|Where-Object{$_-is[Windows.Forms.PictureBox]})[0]
        $picture.Image.Save((Join-Path $dir ($stem+'.png')),[Drawing.Imaging.ImageFormat]::Png)
        [IO.File]::WriteAllText((Join-Path $dir ($stem+'.hex')),[DenpaQrVerification.Core]::Hex($w.Tag.State.Result.Payload))
        [Windows.Forms.Application]::DoEvents();$shot=New-Object Drawing.Bitmap($w.Width,$w.Height)
        try{$w.DrawToBitmap($shot,(New-Object Drawing.Rectangle(0,0,$w.Width,$w.Height)));$shot.Save((Join-Path $dir ($stem+'-screen.png')),[Drawing.Imaging.ImageFormat]::Png)}finally{$shot.Dispose()}
        $w.Close();Write-Output ($stem+' '+$length+' BYTE_RAW_EDIT_CRC_ROUNDTRIP_UI_OK')
      } $game $specialMode
    }
  }
  Set-EditorLanguage 'English'
  & $script:editorModuleByGame.RPG2 {
    Show-DenpaDebugQr 2
    if($script:debugQrWindow.Text-notlike'*RPG2 Special QR'){throw 'English title failed'}
    $script:debugQrWindow.Close()
  }
  Write-Output 'DEBUG_ALL_FOUR_FORMATS_OK';$form.Close();return
}
if($smokeMode-eq'debug-qr'){
  $form.Show();Show-Game 'RPG3';Show-EditorChild 'RPG3'
  Set-EditorLanguage 'English'
  if((Find-NamedControl $rpg3Form 'debugModeButton').Text-ne'Debug Mode'){throw 'Debug button translation failed'}
  Set-EditorLanguage 'Japanese'
  & $script:editorModuleByGame.RPG3 {
    $qrType.SelectedIndex=0;Write-Output 'DEBUG_OPEN_START';Show-DenpaDebugQr;Write-Output 'DEBUG_OPEN_OK'
    $w=$script:debugQrWindow;$grid=$w.Controls.Find('debugByteGrid',$true)[0]
    if($grid.Rows.Count-ne88){throw 'Debug must expose all 88 bytes'}
    for($i=0;$i-lt88;$i++){if($grid.Rows[$i].Cells[0].Value-ne('0x{0:X2}'-f$i)){throw 'Offset ordering failed'}}
    $grid.Rows[0x30].Cells[1].Value='FF'
    & $w.Tag.Render
    if(-not$w.Tag.State.Result-or$w.Tag.State.Dirty-or$w.Tag.State.Result.Plain[0x30]-ne255){throw 'Debug generation failed'}
    Write-Output 'DEBUG_FF_GENERATE_OK'
    if($grid.Rows[0x30].Cells[1].Value-ne'FF'){throw 'Raw byte was normalized'}
    $cipher=$w.Tag.State.Result.Payload
    if([DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Plain(3,[DenpaQrVerification.Core]::Hex($cipher)))-ne[DenpaQrVerification.Core]::Hex($w.Tag.State.Result.Plain)){throw 'Debug QR cipher roundtrip failed'}
    [byte[]]$all=New-Object byte[] 88;for($i=0;$i-lt88;$i++){$all[$i]=255}
    $raw=ConvertTo-DenpaDebugQr $all $false
    if([DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Plain(3,[DenpaQrVerification.Core]::Hex($raw.Payload)))-ne('ff'*88)){throw 'Full raw edit range or manual CRC failed'}
    $auto=@($w.Controls|Where-Object{$_-is[Windows.Forms.CheckBox]})[0]
    $auto.Checked=$false
    if($grid.Rows[84].Cells[1].ReadOnly){throw 'Manual CRC not editable'}
    $auto.Checked=$true
    & $w.Tag.Render
    $output=[IO.Path]::GetFullPath('outputs/qr/rpg3-debug-normal-20261011')
    [void][IO.Directory]::CreateDirectory($output)
    $initial=ConvertTo-DenpaDebugQr ([DenpaQrVerification.Core]::Plain(3,'generated3:normal-jp')) $true
    $bitmap=[DenpaQrVerification.Core]::Bitmap($initial.Payload)
    try{$bitmap.Save((Join-Path $output 'RPG3-normal-baseline.png'),[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
    [IO.File]::WriteAllText((Join-Path $output 'RPG3-normal-baseline.hex'),[DenpaQrVerification.Core]::Hex($initial.Payload))
    [Windows.Forms.Application]::DoEvents()
    $shot=New-Object Drawing.Bitmap($w.Width,$w.Height)
    try{$w.DrawToBitmap($shot,(New-Object Drawing.Rectangle(0,0,$w.Width,$w.Height)));$shot.Save([IO.Path]::GetFullPath('work/rpg3-debug-qr.png'),[Drawing.Imaging.ImageFormat]::Png)}finally{$shot.Dispose()}
    $w.Close()
  }
  Write-Output 'RPG3_DEBUG_QR_UI_88_BYTES_OFFSET_ORDER_FF_CRC_OK';$form.Close();return
}
if($smokeMode-eq'parts-table'){
  $form.StartPosition='Manual';$form.Location=New-Object Drawing.Point(-5000,-5000);$form.ShowInTaskbar=$false;$form.Show()
  $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance')
  foreach($game in @('RPG1','RPG2','RPG3')){
    Show-Game $game
    $before=& $script:editorModuleByGame[$game] {param($game) Get-DenpaCurrentTemplate $game|ConvertTo-Json -Depth 20 -Compress} $game
    $button=Find-NamedControl $script:editors[$game].Form 'facePartsTableButton'
    if(-not$button.Enabled){throw 'Face parts button disabled'}
    [void]$click.Invoke($button,@([EventArgs]::Empty));[Windows.Forms.Application]::DoEvents()
    $viewer=@([Windows.Forms.Application]::OpenForms|Where-Object{$_.Name-eq'facePartsTableWindow'})
    if($viewer.Count-ne1-or$viewer[0].PartCount-ne240){throw "$game actual button did not open viewer"}
    $viewer[0].ZoomControl.SelectedItem='150%'
    $viewer[0].Grid.FirstDisplayedScrollingRowIndex=24
    [void]$click.Invoke($button,@([EventArgs]::Empty));[Windows.Forms.Application]::DoEvents()
    if(@([Windows.Forms.Application]::OpenForms|Where-Object{$_.Name-eq'facePartsTableWindow'}).Count-ne1){throw 'Duplicate viewer opened'}
    $viewer[0].Close();$viewer[0].Dispose()
    $after=& $script:editorModuleByGame[$game] {param($game) Get-DenpaCurrentTemplate $game|ConvertTo-Json -Depth 20 -Compress} $game
    if($before-cne$after){throw "$game viewer changed editor inputs"}
    Write-Output ($game+'_PARTS_TABLE_ACTUAL_BUTTON_SINGLE_WINDOW_NO_EDITOR_CHANGES_OK')
  }
  $form.Close();return
}
if ($smokeMode -in @('1','visual','live') -or $env:DENPA_QR_EDITOR_SMOKE -eq '1') {
  Write-Output ('UNIFIED_SMOKE_MODE=' + $smokeMode)
  if ($rpg3.Map.head.SelectedIndex -ne 37) { throw 'Unified default RPG3 head sync failed.' }
  Show-Game 'RPG2'
  if (-not $rpg2.Display.Enabled -or $rpg2.Map.head.SelectedIndex -ne 0 -or $state.Shared.head -ne 0) { throw 'RPG2 unsupported head fallback-to-zero failed.' }
  $rpg2DefinedCheck=Find-NamedControl $rpg2.Form 'definedFaceCheck'
  $rpg2DefinedCheck.Checked=$false
  $rpg2.Map.head.SelectedIndex = 32
  if($rpg2.Map.head.SelectedIndex-ne32-or$state.Shared.head-ne32-or$rpg2.Map.head.Text-notlike'*未定義*'){throw 'RPG2 manual undefined slot was not retained.'}
  Show-Game 'RPG3'
  Show-Game 'RPG2'
  if($rpg2.Map.head.SelectedIndex-ne0-or$state.Shared.head-ne0){throw 'RPG3-to-RPG2 unimplemented value was not normalized to zero.'}
  $rpg2.Map.head.SelectedIndex = 1
  $rpg2.Map.nose.SelectedIndex = 1
  $rpg2DefinedCheck.Checked=$true
  if (-not $rpg2.Display.Enabled) { throw ('RPG2 supported head should enable QR display. ' + $compatibility.Text) }
  Show-Game 'RPG1'
  if ($rpg1.Map.head.SelectedIndex -ne 0) { throw "RPG1 standalone head was overwritten. actual=$($rpg1.Map.head.SelectedIndex)" }
  $rpg1.Map.head.SelectedIndex = 2
  Show-Game 'RPG3'
  if ($rpg3.Map.head.SelectedIndex -ne 1) { throw 'RPG3 round-trip head synchronization failed.' }
  if ($rpg1.Map.head.SelectedIndex -ne 2) { throw 'RPG1 standalone state was not retained.' }
  $rpg3.Map.brow.SelectedIndex=15
  $towerFilter=Find-NamedControl $rpg3.Form 'towerCombinationCheck'
  $towerFilter.Checked=$true
  $rpg3.Map.brow.SelectedIndex=6
  if($rpg3.Map.brow.SelectedIndex-ne6-or$state.Shared.brow-ne6){throw "RPG3 candidate filter rolled eyebrow back: selected=$($rpg3.Map.brow.SelectedIndex) shared=$($state.Shared.brow)"}
  $towerFilter.Checked=$false
  Write-Output 'UNIFIED_SINGLE_APP_RPG1_RPG2_RPG3_OK'
  Write-Output 'UNIFIED_SHARED_MODEL_AND_COMPATIBILITY_GUARD_OK'
  Write-Output 'UNIFIED_CANDIDATE_FILTER_NO_FACE_ROLLBACK_OK'
  foreach($game in @('RPG1','RPG2','RPG3')){
    $qrControl=Find-NamedControl $script:editors[$game].Form 'qrPreview'
    if(-not$qrControl-or$qrControl.Width-ne$qrControl.Height-or$qrControl.BackColor.ToArgb()-ne[Drawing.Color]::White.ToArgb()){
      throw "$game QR frame must fit a square image without background strips."
    }
    if($qrControl.Location.X-ne723-or$qrControl.Location.Y-ne132-or$qrControl.Width-ne279){throw "$game QR frame unexpectedly moved or grew."}
  }
  Write-Output 'UNIFIED_QR_SQUARE_FRAME_NO_BACKGROUND_STRIPS_OK'
  if ($smokeMode -eq 'visual') {
    $form.Show()
    foreach ($visualGame in @('RPG1','RPG2','RPG3')) {
      Show-Game $visualGame
      [Windows.Forms.Application]::DoEvents()
      $visualChild=$script:editors[$visualGame].Form
      $guard=Find-NamedControl $visualChild 'nonoGuardCheck';$xLink=Find-NamedControl $visualChild 'xProfileLink'
      if($guard.Checked-ne$global:DenpaNonoGuardEnabled-or$guard.Enabled-or$xLink){throw 'Fixed guard state / main X link removal mismatch'}
      $leftNames=@('randomQrButton','qrImportPlaceholder','leftReserved1','leftReserved2','facePartsTableButton')
      $rightNames=@('debugModeButton','advancedQrButton','templateSavePlaceholder')
      for($i=0;$i-lt5;$i++){
        $left=Find-NamedControl $visualChild $leftNames[$i]
        if($left.Top-ne[int][Math]::Round((153+$i*58)*0.92)){throw 'Left action button order mismatch'}
        if($i-lt3){$right=Find-NamedControl $visualChild $rightNames[$i];if($right.Top-ne$left.Top-or$right.Left-le$left.Left){throw 'Right action button order mismatch'}}
      }
      if(-not(Find-NamedControl $visualChild 'facePartsTableButton').Enabled){throw 'Face parts table button must be enabled'}
      $capture = New-Object Drawing.Bitmap($form.Width, $form.Height)
      $form.DrawToBitmap($capture, (New-Object Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
      $capturePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ("..\tests\unified-editor-$($visualGame.ToLower()).png")))
      [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($capturePath)) | Out-Null
      $capture.Save($capturePath, [Drawing.Imaging.ImageFormat]::Png)
      $capture.Dispose()
      Write-Output ('UNIFIED_VISUAL_OK ' + $capturePath)
      if($visualGame-eq'RPG3'){
        $equipment=Find-NamedControl $rpg3.Form 'rpg3EquipmentGroup'
        $options=Find-NamedControl $rpg3.Form 'rpg3OptionsScroll'
        if(-not$options-or$equipment.Parent-ne$options){throw 'Equipment is outside the local scroll panel'}
        if($rpg3.Form.AutoScroll){throw 'RPG3 whole-form scrolling must remain disabled'}
        if($options.HorizontalScroll.Visible){throw 'QR options must only scroll vertically'}
        $link3=Find-NamedControl $rpg3.Form 'discordServerLink'
        $link2=Find-NamedControl $rpg2.Form 'discordServerLink'
        if($link3.Location-ne$link2.Location){throw 'Discord link position differs from RPG2'}
        $date=Find-NamedControl $rpg3.Form 'qrDate'
        if(-not$date){$date=@($options.Controls|Where-Object{$_-is[Windows.Forms.DateTimePicker]}|Select-Object -First 1)[0]}
        $options.ScrollControlIntoView($date)
        [Windows.Forms.Application]::DoEvents()
        $capture=New-Object Drawing.Bitmap($form.Width,$form.Height)
        try{
          $form.DrawToBitmap($capture,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
          $capture.Save((Join-Path ([IO.Path]::GetDirectoryName($capturePath)) 'unified-editor-rpg3-equipment.png'),[Drawing.Imaging.ImageFormat]::Png)
        }finally{$capture.Dispose()}
        $paint=Find-NamedControl $rpg3.Form 'rpg3PaintPanel'
        if(-not$paint-or$paint.Parent-ne$options){throw 'Paint control is outside local settings scroll'}
        & $script:editorModuleByGame.RPG3 {$rpg3PaintBox.SelectedIndex=5}
        foreach($paintLanguage in @('Japanese','English')){
          Set-EditorLanguage $paintLanguage
          & $script:editorModuleByGame.RPG3 {
            if($correctionLabel.Bottom-ge$correctionBox.Top){throw 'Correction caption overlaps its input'}
            if($capturedLabel.Bottom-ge$capturedMonster.Top-or$capturedCheck.Visible-or-not$capturedMonster.Enabled){throw 'Monster selector layout/state failed'}
            if($rpg3PaintLabel.Bottom-ge$rpg3PaintBox.Top){throw 'Paint caption overlaps its input'}
            if($statBonusControls['--evade-bonus'].Maximum-ne50-or$statBonusControls['--evade-bonus'].Bottom-gt$statBonusGroup.Height){throw 'Evade range/layout failed'}
            if($qrType.Top-$rpg3EquipmentGroup.Bottom-lt25){throw 'Equipment/reward spacing is too small'}
            if($env:DENPA_EDITOR_LANGUAGE-ne'English'-and$correctionBox.Items[0]-ne'(なし)'){throw 'Correction none label failed'}
            foreach($key in $rpg3EquipmentBoxes.Keys){
              $box=$rpg3EquipmentBoxes[$key]
              $label=@($rpg3EquipmentGroup.Controls|Where-Object{$_-is[Windows.Forms.Label]-and$_-ne$rpg3EquipmentTitle-and$_.Left-eq$box.Left-and$_.Top-lt$box.Top}|Sort-Object Top -Descending)[0]
              if(-not$label-or$label.Bottom-ge$box.Top-or$box.Right-gt$rpg3EquipmentGroup.ClientSize.Width){throw 'Equipment stacked layout overlaps or clips'}
            }
            for($i=1;$i-lt$itemRewards.Count;$i++){if($itemRewardLabels[$i].Bottom-ge$itemRewards[$i].Top){throw 'Decoration caption overlaps its input'}}
            if($rpg3MemoLabel.Bottom-ge$rpg3MemoBox.Top-or$qrDateLabel.Bottom-ge$qrDate.Top){throw 'Memo/date caption overlaps its input'}
          }
          $options.ScrollControlIntoView($paint);[Windows.Forms.Application]::DoEvents()
          $capture=New-Object Drawing.Bitmap($form.Width,$form.Height)
          try{$form.DrawToBitmap($capture,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$capture.Save((Join-Path ([IO.Path]::GetDirectoryName($capturePath)) ('unified-editor-rpg3-paint-'+$paintLanguage+'.png')),[Drawing.Imaging.ImageFormat]::Png)}finally{$capture.Dispose()}
          $options.ScrollControlIntoView($date);[Windows.Forms.Application]::DoEvents()
          $capture=New-Object Drawing.Bitmap($form.Width,$form.Height)
          try{$form.DrawToBitmap($capture,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$capture.Save((Join-Path ([IO.Path]::GetDirectoryName($capturePath)) ('unified-editor-rpg3-settings-'+$paintLanguage+'.png')),[Drawing.Imaging.ImageFormat]::Png)}finally{$capture.Dispose()}
        }
        Set-EditorLanguage 'Japanese'
      }
    }
  }
  if ($smokeMode -eq 'live') {
    Show-Game 'RPG2'
    $rpg2.Map.nose.SelectedIndex = 2
    $save = Find-ButtonByText $rpg2.Form 'QR保存'
    $qr = Find-NamedControl $rpg2.Form 'qrPreview'
    $qrStatus = Find-NamedControl $rpg2.Form 'qrStatus'
    $deadline = [DateTime]::UtcNow.AddSeconds(12)
    while ([DateTime]::UtcNow -lt $deadline -and (-not $save.Enabled -or -not $qr.Image)) {
      [Windows.Forms.Application]::DoEvents()
    }
    if (-not $save.Enabled -or -not $qr.Image) { throw ('RPG2 live timer did not regenerate the visible QR. ' + $qrStatus.Text) }
    Write-Output 'UNIFIED_RPG2_LIVE_SWITCH_AND_INSTANT_QR_OK'
  }
  if($env:DENPA_QR_IMPORT_SMOKE-eq'1'){
    $ErrorActionPreference='Stop'
    foreach($game in @('RPG1','RPG2','RPG3')){
      $info=$script:editors[$game]
      $probe=New-Object DenpaQrVerification.FaceImport;$probe.Game=[int]$game.Substring(3);$probe.Name='つかさ'
      foreach($key in @('hair','contour','brow','eyes','nose','mouth','cheeks','glasses','skin','hairColor')){$probe.Parts[$key]=[Math]::Max(0,$info.Map[$key].SelectedIndex)}
      if($game-eq'RPG1'){$probe.Parts['skin']=& $script:editorModuleByGame[$game] {[int]$rpg1SkinUiToStored[$boxes['--skin-color'].SelectedIndex]}}
      $probe.Parts['nose']=1
      $unrelated=@{};foreach($key in @('antenna','head','body','stature','personality')){$unrelated[$key]=$info.Map[$key].SelectedIndex}
      Set-DenpaImportedFace $game $probe $true
      if($info.Map.nose.SelectedIndex-ne1){throw 'Imported nose was not applied'}
      foreach($key in $unrelated.Keys){if($info.Map[$key].SelectedIndex-ne$unrelated[$key]){throw ('Import changed unrelated field '+$game+'/'+$key)}}
      $payload=& $script:editorModuleByGame[$game] {param($number) (ConvertTo-DenpaDebugQr (Get-DenpaDebugInitial $number) $true $number).Payload} ([int]$game.Substring(3))
      $decoded=[DenpaQrVerification.Core]::ReadFace($payload)
      foreach($key in $decoded.Parts.Keys){$expected=[int]$decoded.Parts[$key];if($game-eq'RPG1'-and$key-eq'skin'){$expected=& $script:editorModuleByGame[$game] {param($value) [int]$rpg1SkinStoredToUi[$value]} $expected};if($info.Map[$key].SelectedIndex-ne$expected){throw ('Face extraction roundtrip mismatch '+$game+'/'+$key+': '+$info.Map[$key].SelectedIndex+' vs '+$expected)}}
    }
    $bitmap=New-Object Drawing.Bitmap(400,240)
    try{$crop=New-Object DenpaQrVerification.QrCropForm($bitmap,$false);try{$crop.CreateControl();if($crop.Controls.Count-lt4){throw 'Crop UI failed'}}finally{$crop.Dispose()}}finally{$bitmap.Dispose()}
    Write-Output 'UNIFIED_QR_IMPORT_FACE_NAME_ONLY_AND_CROP_OK'
    if($env:DENPA_QR_IMPORT_FILTER_SMOKE-eq'1'){
      foreach($game in @('RPG1','RPG2','RPG3')){
        foreach($pattern in 0..2){
          $snapshot=& $script:editorModuleByGame[$game] {
            param($game,$pattern)
            $towerCombinationCheck.Checked=$false
            $sync=if($game-eq'RPG3'){$legitimateFaceCheck}else{$faceSyncCheck}
            $sync.Checked=($pattern-ge1);$definedFaceCheck.Checked=($pattern-ge1)
            $towerCombinationCheck.Checked=($pattern-eq2)
            Get-DenpaCurrentTemplate $game
          } $game $pattern
          $payload=& $script:editorModuleByGame[$game] {param($number) (ConvertTo-DenpaDebugQr (Get-DenpaDebugInitial $number) $true $number).Payload} ([int]$game.Substring(3))
          $decoded=[DenpaQrVerification.Core]::ReadFace($payload)
          Set-DenpaImportedFace $game $decoded $true
          $after=& $script:editorModuleByGame[$game] {param($game) Get-DenpaCurrentTemplate $game} $game
          foreach($flag in @('towerCombinationCheck','definedFaceCheck','faceSyncCheck','legitimateFaceCheck')){
            if($snapshot.SavedOptions.ContainsKey($flag)-and$after.SavedOptions[$flag].Checked-ne$snapshot.SavedOptions[$flag].Checked){throw "Import changed $game $flag, pattern $pattern"}
          }
          foreach($key in $decoded.Parts.Keys){$expected=[int]$decoded.Parts[$key];if($game-eq'RPG1'-and$key-eq'skin'){$expected=& $script:editorModuleByGame[$game] {param($value) [int]$rpg1SkinStoredToUi[$value]} $expected};if($script:editors[$game].Map[$key].SelectedIndex-ne$expected){throw "Filter-preserving import changed $game $key"}}
        }
        Write-Output ($game+'_QR_IMPORT_FILTER_CHECKS_PRESERVED_ON_AND_OFF')
      }
    }
    if($env:DENPA_QR_IMPORT_EXPANDED_SMOKE-eq'1'){
      $fixturePath=$env:DENPA_QR_IMPORT_TEST_IMAGE
      if([string]::IsNullOrWhiteSpace($fixturePath)-or-not(Test-Path -LiteralPath $fixturePath -PathType Leaf)){throw 'Set DENPA_QR_IMPORT_TEST_IMAGE to the local test card image.'}
      $image=Open-DenpaImportBitmap $fixturePath
      try{$raw=[DenpaQrVerification.Core]::ReadQrImage($image,(New-Object Drawing.Rectangle(425,390,230,227)))}finally{$image.Dispose()}
      $source=[DenpaQrVerification.Core]::ReadFace($raw)
      Set-DenpaImportedFace 'RPG3' $source $true
      & $script:editorModuleByGame.RPG3 {
        if($qrType.SelectedIndex-ne1-or$extendedSpecialCode.SelectedIndex-ne221-or$jewelQuantity.Value-ne255){throw 'Imported special type/ID/jewels mismatch'}
        if($statBonusControls['--hp-bonus'].Value-ne9999-or$statBonusControls['--ap-bonus'].Value-ne2400-or$statBonusControls['--evade-bonus'].Value-ne50){throw 'Imported bonuses mismatch'}
        if($nameLanguage.Boxes.JP.Text-ne'まさじ'){throw 'Imported name mismatch'}
      }
      Write-Output 'UNIFIED_IMPORT_MASAJI_SPECIAL_STATS_REWARDS_OK'
    }
  }
  $form.Close()
  return
}
[void]$form.ShowDialog()
