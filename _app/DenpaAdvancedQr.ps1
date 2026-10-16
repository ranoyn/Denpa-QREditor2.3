# Advanced settings are input values, not stored QR payloads.
function Get-DenpaRpg1RawSpecs([bool]$English=$false) {
  $items=@()
  foreach($at in (4..7)+(50..52)){
    $label=if($at-eq4){if($English){'Explicit antenna (priority unconfirmed)'}else{'アンテナ明示指定（優先条件未確定）'}}elseif($at-eq5){if($English){'Generation class (receive behavior unconfirmed)'}else{'生成区分（受信時の扱い未確定）'}}elseif($at-in@(6,7)){if($English){'Name input (2 bytes; '+$(if($at-eq6){'low'}else{'high'})+')'}else{'名前生成入力（2バイト・'+$(if($at-eq6){'下位'}else{'上位'})+'）'}}else{if($English){'Random value (manual; default 00)'}else{'乱数値（手動設定・初期値00）'}}
    $items+=,@(('--qr1-byte-'+$at),(('0x{0:X2} '-f$at)+$label),255,$at,0,8,$false)
  }
  foreach($part in @(@(13,7,1),@(15,1,2),@(17,4,4),@(20,0,5),@(21,4,4),@(22,7,1))){
    $label=if($part[0]-in@(17,21)){if($English){'Unconfirmed [original QR values; identity check]'}else{'未確定［正規入力有り・個体照合対象］'}}elseif($part[0]-eq20){if($English){'Antenna selection input (partial)'}else{'アンテナ候補選択入力（一部）'}}else{if($English){'Packed appearance input'}else{'外見生成入力（ビット連結）'}}
    $items+=,@(('--qr1-bits-'+$part[0]),(('0x{0:X2} bit{1}..{2} '-f$part[0],$part[1],($part[1]+$part[2]-1))+$label),((1-shl$part[2])-1),$part[0],$part[1],$part[2],$false)
  }
  foreach($part in @(@(24,5,3),@(25,0,8))){$items+=,@(('--qr1-bits-'+$part[0]),(('0x{0:X2} bit{1}..{2} '-f$part[0],$part[1],($part[1]+$part[2]-1))+$(if($English){'Unconfirmed [original QR values; identity check]'}else{'未確定［正規入力有り・個体照合対象］'})),((1-shl$part[2])-1),$part[0],$part[1],$part[2],$false)}
  foreach($at in 38..49){$items+=,@(('--qr1-jp-byte-'+$at),(('0x{0:X2} '-f$at)+$(if($English){'JP name reading (phonetic symbols unconfirmed)'}else{'名前の読み（JP・発音記号の効果未確定）'})),255,$at,0,8,$true)}
  $items
}
function Apply-DenpaRpg1AdvancedValues([byte[]]$Plain,[string]$Region){
  $state=Get-DenpaAdvancedQrState
  foreach($spec in @(Get-DenpaRpg1RawSpecs)){
    if(-not$state.Unknown.ContainsKey($spec[0])-or($spec[6]-and$Region-ne'JP')){continue}
    $value=[int]$state.Unknown[$spec[0]]
    if($value-lt0-or$value-gt$spec[2]){throw ('RPG1 advanced value out of range: '+$spec[1])}
    Set-Rpg1Bits $Plain $spec[3] $spec[4] $spec[5] $value
  }
}
function Get-DenpaAdvancedQrState {
  if(-not$script:advancedQrState){$script:advancedQrState=@{Level=$null;Unknown=@{}}}
  $script:advancedQrState
}
function Get-DenpaRpg2AdvancedSpecs([bool]$English){
  $items=@(,@('--qr-meta-07',$(if($English){'0x07 Rebuild control (full rules unconfirmed) [original QR values]'}else{'0x07 再構成制御（全条件未確定）[正規入力有り]'}),255))
  foreach($at in 8..13){$items+=,@(('--qr-identity-'+('{0:X2}'-f$at)),(('0x{0:X2} '-f$at)+$(if($English){'Identity / generation input'}else{'識別・生成入力'})),255)}
  $items+=,@('--qr-meta-39',$(if($English){'0x39 Appearance class (full mapping unconfirmed) [original QR values]'}else{'0x39 外見生成区分（全分類未確定）[正規入力有り]'}),255)
  $items+=,@('--qr-meta-5e-upper',$(if($English){'0x5E bits3-7 Candidate groups M/U [original QR values]'}else{'0x5E bits3～7 候補表M/U（分類未確定）[正規入力有り]'}),31)
  $items+=,@('--qr2-raw-0E',$(if($English){'0x0E Priority antenna (conditions unconfirmed)'}else{'0x0E 優先アンテナ（全条件未確定）'}),255)
  $items+=,@('--qr2-equipment-reserved',$(if($English){'0x40 bit3-0x41 Reserved bits (unconfirmed)'}else{'0x40 bit3～0x41 装備上位13bit（用途未確定）'}),8191)
  foreach($at in 0x42..0x45){$label=if($at-eq0x42){if($English){'Fixed-character reference (conditions unconfirmed)'}else{'固定個体参照（全条件未確定）'}}else{if($English){'Reserved candidate (purpose unconfirmed)'}else{'予約領域候補（用途未確定）'}};$items+=,@(('--qr2-raw-'+('{0:X2}'-f$at)),(('0x{0:X2} '-f$at)+$label),255)}
  $items+=,@('--qr2-mode-low',$(if($English){'0x5E bits0-2 Generation mode (mapping unconfirmed)'}else{'0x5E 下位3bit 生成属性（全分類未確定）'}),7)
  $items+=,@('--qr2-raw-5F',$(if($English){'0x5F Experience table group (exceptions unconfirmed)'}else{'0x5F 経験値表区分（全例外未確定）'}),255)
  if($modeBox.SelectedIndex-eq0){foreach($at in 0x6E..0x73){$items+=,@(('--qr2-tail-'+('{0:X2}'-f$at)),(('0x{0:X2} '-f$at)+$(if($English){'Outside character copy (purpose unconfirmed)'}else{'人物コピー外（独立用途未確定）'})),255)}}
  $items
}
function Get-DenpaRpg3AdvancedSpecs([bool]$English){
  $items=@(@('--qr-meta-2b',$(if($English){'0x2B Appearance groups (full mapping unconfirmed) [original QR values]'}else{'0x2B 外見生成区分（全分類未確定）[正規入力有り]'}),255),@('--qr-meta-30',$(if($English){'0x30 Personality/dialogue groups (full mapping unconfirmed) [original QR values]'}else{'0x30 性格候補・会話区分（全分類未確定）[正規入力有り]'}),255))
  $special=$qrType.SelectedIndex-ne0
  $items+=,@('--qr-flags-52',$(if($special){if($English){'0x52 Origin low3 / upper bits unconfirmed'}else{'0x52 出自補助（下位3bit）・上位用途未確定'}}else{if($English){'0x52 3DS region (unconfirmed) [original QR values]'}else{'0x52 3DS地域（未確定）［正規入力有り］'}}),255)
  $items+=,@('--qr3-growth-low',$(if($English){'0x35 low4 Base-stat growth type (0B-0F unconfirmed)'}else{'0x35 下位4bit 基礎能力成長タイプ（0B～0F未確定）'}),15)
  $items+=,@('--qr3-origin-low',$(if($English){'Origin low3 (full mapping unconfirmed)'}else{'出自補助・下位3bit（全分類未確定）'}),7)
  foreach($at in 0x4E..0x4F){$items+=,@(('--qr3-raw-'+('{0:X2}'-f$at)),(('0x{0:X2} '-f$at)+$(if($English){'Outside character copy (purpose unconfirmed)'}else{'人物コピー外（用途未確定）'})),255)}
  if($special){foreach($at in 0x98..0x9B){$items+=,@(('--qr3-padding-'+('{0:X2}'-f$at)),(('0x{0:X2} '-f$at)+$(if($English){'Single-entry padding (purpose unconfirmed)'}else{'1エントリ時の余白（用途未確定）'})),255)}}
  $items
}
function Copy-DenpaAdvancedQrState($State){
  $copy=@{Level=$State.Level;Unknown=@{}}
  foreach($key in $State.Unknown.Keys){if($key-notin@('--qr-origin-53','--qr-special-meta-5e','--qr-special-meta-5f')){$copy.Unknown[$key]=[int]$State.Unknown[$key]}}
  if($State.Equipment){$copy.Equipment=@{};foreach($key in $State.Equipment.Keys){$copy.Equipment[$key]=[string]$State.Equipment[$key]}}
  $copy
}
function Get-DenpaAdvancedQrArguments([int]$Game){
  $state=Get-DenpaAdvancedQrState;$result=@()
  if($Game-eq2-and$null-ne$state.Level){$result+=@('--source-level',$state.Level.ToString())}
  if($Game-eq2-and$modeBox.SelectedIndex-eq0){
    foreach($at in 8..13){
      $key='--qr-identity-'+('{0:X2}'-f$at)
      $value=if($state.Unknown.ContainsKey($key)){[int]$state.Unknown[$key]}else{0}
      $result+=@($key,('{0:X2}'-f$value))
    }
    foreach($key in @('neck','arm','back','feet','clothing')){
      $code=if($state.Equipment-and$state.Equipment.ContainsKey($key)){[string]$state.Equipment[$key]}else{'0000'}
      $result+=@(('--qr-equipment-'+$key),$code)
    }
  }
  if($Game-eq3-and$qrType.SelectedIndex-eq0){
    $mode=if($qrDate.Checked){2}else{1}
    $result+=@('--qr-date-mode',('{0:X2}'-f$mode))
  }
  foreach($key in $state.Unknown.Keys){
    if($Game-eq2-and$key-in@('--qr-marker-70','--qr-marker-71','--qr-marker-72','--qr-marker-73')){continue}
    if($Game-eq2-and$modeBox.SelectedIndex-eq0-and$key.StartsWith('--qr-identity-')){continue}
    if($Game-eq2-and$key.StartsWith('--qr2-tail-')-and$modeBox.SelectedIndex-ne0){continue}
    if($Game-eq3-and$key.StartsWith('--qr3-padding-')-and$qrType.SelectedIndex-eq0){continue}
    if($key-in@('--qr-origin-53','--qr-special-meta-5e','--qr-special-meta-5f')){continue}
    if($key.StartsWith('--qr-special-meta-')-and($Game-ne3-or$qrType.SelectedIndex-eq0)){continue}
    $result+=@($key,('{0:X2}'-f[int]$state.Unknown[$key]))
  }
  $result
}
function Show-DenpaAdvancedQrSettings([string]$Game){
  if($script:advancedQrWindow-and-not$script:advancedQrWindow.IsDisposed){$script:advancedQrWindow.Activate();return}
  $english=$env:DENPA_EDITOR_LANGUAGE-eq'English'
  $state=Get-DenpaAdvancedQrState
  $window=New-Object Windows.Forms.Form
  $window.Text=$(if($english){'Advanced QR Settings'}else{'QR詳細設定'})+' - '+$Game
  $window.ClientSize=New-Object Drawing.Size(540,520);$window.StartPosition='CenterParent'
  $window.Font=New-Object Drawing.Font('Yu Gothic UI',10);$window.FormBorderStyle='FixedDialog';$window.MaximizeBox=$false
  if($form.Icon){$window.Icon=$form.Icon}
  $script:advancedQrWindow=$window
  $note=New-Object Windows.Forms.Label;$note.Location=New-Object Drawing.Point(20,15);$note.Size=New-Object Drawing.Size(500,65)
  $note.Text=if($english){'Set known or unidentified values. Initial input values are 00. Only checked fields are applied. Enter hexadecimal values. Changing settings may make the QR unreadable.'}else{'現在の未解析値などを設定できます。初期入力値は00です。チェックした項目だけ反映します。値は16進数です。設定の変更によりQRが読み取れなくなる場合があります。'}
  $window.Controls.Add($note)
  if($Game-ne'RPG1'){
  $levelLabel=New-Object Windows.Forms.Label;$levelLabel.Text=if($english){'Level'}else{'レベル'};$levelLabel.Location=New-Object Drawing.Point(20,90);$levelLabel.AutoSize=$true;$window.Controls.Add($levelLabel)
  $level=New-Object Windows.Forms.ComboBox;$level.DropDownStyle='DropDownList';$level.Location=New-Object Drawing.Point(200,85);$level.Size=New-Object Drawing.Size(180,27)
  $maximum=if($Game-eq'RPG3'){199}else{99};[void]$level.Items.AddRange([object[]](1..$maximum))
  $current=if($Game-eq'RPG3'){Get-Rpg3SourceLevel}elseif($null-ne$state.Level){[int]$state.Level}else{1}
  $level.SelectedIndex=$current-1;$window.Controls.Add($level)
  }
  $specs=if($Game-eq'RPG3'){@(Get-DenpaRpg3AdvancedSpecs $english)}else{@(Get-DenpaRpg2AdvancedSpecs $english)}
  $rawControls=@{};$y=135
  if($Game-eq'RPG1'){$specs=@(Get-DenpaRpg1RawSpecs $english);$y=10}
  foreach($spec in $specs){
    $check=New-Object Windows.Forms.CheckBox;$check.Text=$spec[1];$check.Location=New-Object Drawing.Point(25,$y);$check.Size=New-Object Drawing.Size(265,44)
    $input=New-Object Windows.Forms.NumericUpDown;$input.Hexadecimal=$true;$input.Maximum=$spec[2];$input.Location=New-Object Drawing.Point(310,($y+8));$input.Size=New-Object Drawing.Size(110,27)
    $check.Checked=$state.Unknown.ContainsKey($spec[0]);$input.Enabled=$check.Checked
    if($check.Checked){$input.Value=$state.Unknown[$spec[0]]}
    $check.Tag=$input;$check.Add_CheckedChanged({$this.Tag.Enabled=$this.Checked})
    $window.Controls.AddRange([Windows.Forms.Control[]]@($check,$input));$rawControls[$spec[0]]=@{Check=$check;Input=$input};$y+=52
  }
  if($Game-eq'RPG1'){
    $rawPanel=New-Object Windows.Forms.Panel;$rawPanel.Location=New-Object Drawing.Point(20,90);$rawPanel.Size=New-Object Drawing.Size(500,355);$rawPanel.AutoScroll=$true;$window.Controls.Add($rawPanel)
    foreach($pair in $rawControls.Values){foreach($control in @($pair.Check,$pair.Input)){$rawPanel.Controls.Add($control)}}
  }
  $equipmentControls=@{}
  if($Game-in@('RPG2','RPG3')){
    $tabs=New-Object Windows.Forms.TabControl;$tabs.Location=New-Object Drawing.Point(20,125);$tabs.Size=New-Object Drawing.Size(500,320)
    $rawPage=New-Object Windows.Forms.TabPage;$rawPage.Text=if($english){'Verification Values'}else{'検証値'};$rawPage.AutoScroll=$true
    $equipmentPage=New-Object Windows.Forms.TabPage;$equipmentPage.Text=if($english){'Equipment'}else{'装備'}
    [void]$tabs.TabPages.Add($rawPage);if($Game-eq'RPG2'){[void]$tabs.TabPages.Add($equipmentPage)};$window.Controls.Add($tabs)
    foreach($pair in $rawControls.Values){foreach($control in @($pair.Check,$pair.Input)){$control.Top-=130;$control.Left-=20;$rawPage.Controls.Add($control)}}
    if($Game-eq'RPG2'){
    $equipmentNote=New-Object Windows.Forms.Label;$equipmentNote.Text=if($english){'Always applied to normal QR. Special QR uses the main editor.'}else{'通常QRには常時反映します。特典QRは主画面の装備を使います。'};$equipmentNote.Location=New-Object Drawing.Point(10,8);$equipmentNote.Size=New-Object Drawing.Size(450,35);$equipmentPage.Controls.Add($equipmentNote)
    $equipmentSpecs=@(@('neck','首',$neckBox,$neckEquipmentCodes),@('arm','腕',$armBox,$armEquipmentCodes),@('back','背中',$backBox,$backEquipmentCodes),@('feet','足',$feetBox,$feetEquipmentCodes),@('clothing','服',$clothingBox,$clothingCodes))
    $row=0
    foreach($spec in $equipmentSpecs){
      $label=New-Object Windows.Forms.Label;$label.Text=if($english){@{neck='Neck';arm='Arms';back='Back';feet='Feet';clothing='Clothing'}[$spec[0]]}else{$spec[1]};$label.Location=New-Object Drawing.Point(10,(48+44*$row));$label.AutoSize=$true;$equipmentPage.Controls.Add($label)
      $combo=New-Object Windows.Forms.ComboBox;$combo.DropDownStyle='DropDownList';$combo.Location=New-Object Drawing.Point(100,(44+44*$row));$combo.Size=New-Object Drawing.Size(355,27);$combo.DropDownWidth=355
      [void]$combo.Items.AddRange([object[]]@($spec[2].Items));$combo.SelectedIndex=0
      if($state.Equipment-and$state.Equipment.ContainsKey($spec[0])){$index=[Array]::IndexOf([object[]]$spec[3],[object][string]$state.Equipment[$spec[0]]);if($index-ge0){$combo.SelectedIndex=$index}}
      $equipmentPage.Controls.Add($combo);$equipmentControls[$spec[0]]=@{Combo=$combo;Codes=$spec[3]};$row++
    }
    $equipmentPage.Tag=$equipmentControls
    }
  }
  $apply=New-Object Windows.Forms.Button;$apply.Text=if($english){'Apply Settings'}else{'設定反映'};$apply.Location=New-Object Drawing.Point(350,465);$apply.Size=New-Object Drawing.Size(160,35);$window.Controls.Add($apply)
  $commit={param($draft,$game)
    $script:advancedQrState=$draft
    if($game-eq'RPG3'){$sourceLevelInput.Value=[decimal]$draft.Level;$sourceLevelCheck.Checked=$true;Update-Rpg3AntennaEvolution}
    if($displayButton){
      $click=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'NonPublic,Instance')
      [void]$click.Invoke($displayButton,@([EventArgs]::Empty))
    }
  }
  $apply.Add_Click(({
    $draft=@{Level=$null;Unknown=@{}};if($Game-ne'RPG1'){$draft.Level=[int]$level.SelectedItem}
    foreach($key in $rawControls.Keys){if($rawControls[$key].Check.Checked){$draft.Unknown[$key]=[int]$rawControls[$key].Input.Value}}
    if($Game-eq'RPG2'){$draft.Equipment=@{};foreach($key in $equipmentControls.Keys){$pair=$equipmentControls[$key];$draft.Equipment[$key]=[string]$pair.Codes[$pair.Combo.SelectedIndex]}}
    & $commit $draft $Game
    $window.Close()
  }.GetNewClosure()))
  $window.Show($form)
}
