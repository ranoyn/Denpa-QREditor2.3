# Raw RPG2/3 QR editor. Do not pass raw bytes back through Core.Edit:
# that would normalize known fields and defeat the purpose of debugging.
# Shared by all three embedded editors. Change only this setting to disable.
$global:DenpaNonoGuardEnabled = $true
function Assert-DenpaNonoGuard([int]$Hair,[int]$Eyes){
  if(-not$global:DenpaNonoGuardEnabled){return}
  if($Hair-eq25-and$Eyes-eq36){throw 'ののガードが適用されています。この組み合わせは生成出来ません。 / Nono Guard is active. This combination cannot be generated.'}
}
function Format-DenpaNumericFaceChoices($Boxes){
  foreach($key in @('--head-shape','--contour','--face-shape','--hair','--eyebrow','--eyes','--nose','--mouth','--cheeks','--glasses','--skin-color','--face-image','--hair-color')){
    $box=$Boxes[$key];if(-not$box){continue}
    for($i=0;$i-lt$box.Items.Count;$i++){$text=[string]$box.Items[$i];if($text-match'^\d$'){$box.Items[$i]='0'+$text}}
  }
}
function Register-DenpaNonoSelectionGuard($Boxes,[scriptblock]$ReadValues){
  $guardState=[pscustomobject]@{Resetting=$false;Resets=0}
  $hair=$Boxes['--hair'];$eyes=$Boxes['--eyes']
  $handler={
    if(-not$global:DenpaNonoGuardEnabled-or$guardState.Resetting-or$hair.SelectedIndex-lt0-or$eyes.SelectedIndex-lt0){return}
    $values=@(& $ReadValues)
    if($values.Count-ne2-or[int]$values[0]-ne25-or[int]$values[1]-ne36){return}
    $guardState.Resetting=$true
    try{$hair.SelectedIndex=0;$eyes.SelectedIndex=0;$guardState.Resets++}finally{$guardState.Resetting=$false}
  }.GetNewClosure()
  $hair.Add_SelectedIndexChanged($handler);$eyes.Add_SelectedIndexChanged($handler)
  & $handler
  return $guardState
}
function ConvertTo-DenpaDebugQr([byte[]]$Plain,[bool]$AutoCrc=$true,[int]$Game=3) {
  if($Game-eq2-and$Plain.Length-ge120){Assert-DenpaNonoGuard $Plain[0x66] $Plain[0x69]}
  if($Game-eq3-and$Plain.Length-ge88){Assert-DenpaNonoGuard $Plain[0x23] $Plain[0x25]}
  if($Game-eq1){
    if($null-eq$Plain-or$Plain.Length-ne53){throw 'RPG1 requires 53 decoded bytes.'}
    [byte[]]$bytes=$Plain.Clone()
    return [pscustomobject]@{Plain=$bytes;Payload=[DenpaQrVerification.Core]::Encrypt1($bytes)}
  }
  $lengths=if($Game-eq2){@(120,288)}elseif($Game-eq3){@(88,160)}else{@()}
  if($null-eq$Plain-or$Plain.Length-notin$lengths){throw 'Unsupported RPG2/3 QR format.'}
  [byte[]]$bytes=$Plain.Clone()
  $crcOffset=$bytes.Length-4
  if($AutoCrc){[BitConverter]::GetBytes([DenpaQrVerification.Core]::Crc($bytes,$crcOffset)).CopyTo($bytes,$crcOffset)}
  $method=[DenpaQrVerification.Core].GetMethod('Cipher',[Reflection.BindingFlags]'Static,NonPublic')
  $cipher=$method.Invoke($null,@())
  [byte[]]$payload=$cipher.Transform($bytes,$false)
  [pscustomobject]@{Plain=$bytes;Payload=$payload}
}

function Get-DenpaDebugByteLabelCore([int]$Game,[int]$Length,[int]$At,[bool]$English) {
  if($Game-eq1){
    if($At-lt4){return $(if($English){'Format header'}else{'形式ヘッダー'})}
    if($At-eq4){return $(if($English){'Explicit antenna (priority conditions unconfirmed)'}else{'アンテナ明示指定（優先条件未確定）'})}
    if($At-eq5){return $(if($English){'Generation class (full receive behavior unconfirmed)'}else{'生成区分（受信時の扱い未確定）'})}
    if($At-in@(6,7)){return $(if($English){'Name-generation input (2 bytes; '+$(if($At-eq6){'low'}else{'high'})+')'}else{'名前生成入力（2バイト・'+$(if($At-eq6){'下位'}else{'上位'})+'）'})}
    if($At-eq24){return $(if($English){'Packed appearance; bits5-7 unconfirmed [original QR values; identity comparison]'}else{'外見（ビット連結）・上位3bit未確定［正規入力有り・個体照合対象］'})}
    if($At-eq25){return $(if($English){'Unconfirmed bits [original QR values; identity comparison]'}else{'未確定ビット［正規入力有り・個体照合対象］'})}
    if($At-in@(17,21)){return $(if($English){'Packed appearance; bits4-7 unconfirmed [original QR values; identity comparison]'}else{'外見（ビット連結）・上位4bit未確定［正規入力有り・個体照合対象］'})}
    if($At-ge8-and$At-le24){return $(if($English){'Appearance / antenna / stature (packed bits)'}else{'外見・アンテナ・体格(ビット連結)'})}
    if($At-ge26-and$At-le37){return $(if($English){'Name (JP: UTF-16LE; region-dependent)'}else{'名前（JP：UTF-16LE・地域依存）'})}
    if($At-ge38-and$At-le49){return $(if($English){'JP name reading (phonetic symbols unconfirmed) / overseas name area'}else{'名前の読み（JP・発音記号の効果未確定）／海外版の名前領域'})}
    if($At-ge50-and$At-le52){return $(if($English){'Random value (default 00) [original QR values]'}else{'乱数値（初期値00）［正規入力有り］'})}
    return $(if($English){'Unconfirmed / reserved'}else{'用途未確定・予約領域'})
  }
  if($At-ge($Length-4)){return 'CRC-32/BZIP2'}
  if($At-lt4){return $(if($English){'Format header'}else{'形式ヘッダー'})}
  if($Game-eq3){
    if($At-eq47){return $(if($English){'Paint state: bit 0 = active; bits 1-7 = body color ID'}else{'ペイント状態：下位1ビット=適用、上位7ビット=体色ID'})}
    if($At-ge68-and$At-le77){$slot=[int][Math]::Floor(($At-68)/2);return $(if($English){@('Neck','Arms','Feet','Back','Clothing')[$slot]+' equipment (2 bytes)'}else{@('首','腕','足','背中','服')[$slot]+'装備(2バイト)'})}
    if($Length-eq160-and$At-ge120-and$At-le151){return $(if($English){'Memo (UTF-16LE, 16 code units)'}else{'メモ(UTF-16LE・最大16文字)'})}
    if($Length-eq160-and$At-eq83){return $(if($English){'Region/language entry count'}else{'地域・言語エントリ数'})}
    if($Length-eq160-and$At-eq94){return $(if($English){'Name/memo entry language'}else{'名前・メモの言語識別値'})}
    if($Length-eq160-and$At-eq95){return $(if($English){'Name/memo entry region'}else{'名前・メモの地域識別値'})}
    if($At-eq43){return $(if($English){'Appearance class (low4) / generation modifier (high4); full mapping unconfirmed'}else{'外見生成区分(下位4bit)・外見補助区分(上位4bit)／全分類未確定'})}
    if($At-eq48){return $(if($English){'Personality candidate group (low4) / generation-dialogue group (high4); full mapping unconfirmed'}else{'性格候補区分(下位4bit)・生成／会話区分(上位4bit)／全分類未確定'})}
    if($At-eq53){return $(if($English){'Correction (high4) / base-stat growth type (low4; 0B-0F unconfirmed)'}else{'補正(上位4bit)・基礎能力成長タイプ(下位4bit・0B～0F未確定)'})}
    if($At-in@(78,79)){return $(if($English){'Outside character copy (purpose unconfirmed)'}else{'人物コピー対象外（用途未確定）'})}
    if($Length-eq160-and$At-ge152-and$At-le155){return $(if($English){'Single-entry padding (purpose unconfirmed); next entry if multi-entry'}else{'1エントリ時の余白（用途未確定）／複数時は次エントリ'})}
    $jp=@{32='アンテナ外見';33='頭';34='輪郭';35='髪';36='眉';37='目';38='鼻';39='口';40='頬';41='顔装備';42='体格';44='体色';45='肌色';46='髪色';49='性格';50='アンテナ';52='モンスター';53='補正';82='フラグ';83='日付区分・補助情報'}
    $en=@{32='Antenna appearance';33='Head';34='Contour';35='Hair';36='Eyebrow';37='Eyes';38='Nose';39='Mouth';40='Cheeks';41='Glasses';42='Stature';44='Body color';45='Skin color';46='Hair color';49='Personality';50='Antenna';52='Monster';53='Correction';82='Flags';83='Date mode / metadata'}
    if($At-lt8){return $(if($English){'Timestamp (4 bytes)'}else{'日時(4バイト)'})}
    if($At-eq51){return $(if($English){'Antenna evolution stage'}else{'アンテナ進化段階'})}
    if($At-eq82){return $(if($Length-eq160){if($English){'Origin metadata (low3; full mapping unconfirmed) / upper bits unconfirmed'}else{'出自補助区分(下位3bit・全分類未確定)／上位用途未確定'}}else{if($English){'3DS region (unconfirmed) [original QR values]'}else{'3DS地域（未確定）［正規入力有り］'}})}
    if($At-eq83){return $(if($English){'Origin metadata (low3; full mapping unconfirmed) / upper bits unconfirmed'}else{'出自補助区分(下位3bit・全分類未確定)／上位用途未確定'})}
    if(($At-ge8-and$At-lt32)-or($Length-eq160-and$At-ge96-and$At-lt120)){return $(if($English){'Name (UTF-16LE)'}else{'名前(UTF-16LE)'})}
    if($jp.ContainsKey($At)){return $(if($English){$en[$At]}else{$jp[$At]})}
    if($At-ge54-and$At-le55){return $(if($English){'Source level (2 bytes)'}else{'元個体レベル(2バイト)'})}
    if($At-ge56-and$At-le67){
      $index=[int][Math]::Floor(($At-56)/2)
      return $(if($English){@('Max HP','Max AP','Strength','Defense','Speed','Evade')[$index]+' (2 bytes)'}else{@('さいだいHP','さいだいAP','こうげきりょく','ぼうぎょりょく','すばやさ','かいひりつ')[$index]+'(2バイト)'})
    }
    if($At-eq80-or$At-eq81){return $(if($English){'Region mask (2 bytes)'}else{'地域マスク(2バイト)'})}
    if($Length-eq160){
      if($At-eq84){return $(if($English){'Special ID'}else{'特典ID'})}
      if($At-eq85){return $(if($English){'Jewel quantity'}else{'ジュエル個数'})}
      if($At-eq86-or$At-eq87){return $(if($English){'Item (2 bytes)'}else{'アイテム(2バイト)'})}
      if($At-ge88-and$At-le93){return $(if($English){'Furniture '+([int][Math]::Floor(($At-88)/2)+1)+' (2 bytes)'}else{'家具'+([int][Math]::Floor(($At-88)/2)+1)+'(2バイト)'})}
    }
  }else{
    if($At-eq15){return $(if($English){'Paint: 00 = none; body color ID + 1'}else{'ペイントざい：00=なし・体色ID+1'})}
    if($At-eq4-or$At-eq5){return $(if($English){'Region mask (2 bytes)'}else{'地域マスク(2バイト)'})}
    if($At-eq6){return $(if($English){'Region identifier'}else{'地域識別値'})}
    if($At-eq7){return $(if($English){'Character reconstruction control (full conditions unconfirmed)'}else{'個体再構成の制御値（全条件未確定）'})}
    if($At-eq14){return $(if($English){'Priority antenna override (full conditions unconfirmed)'}else{'優先アンテナ指定（全条件未確定）'})}
    if($At-eq57){return $(if($English){'Appearance generation class (full mapping unconfirmed)'}else{'外見生成区分（全分類未確定）'})}
    if($At-eq64){return $(if($English){'Clothing upper 2 bits / valid bit 2 / reserved bits 3-7 (unconfirmed)'}else{'服ID上位2ビット・装備有効bit2・予約候補bit3～7（未確定）'})}
    if($At-eq65){return $(if($English){'Equipment reserved bits (purpose unconfirmed)'}else{'装備欄の予約ビット候補（用途未確定）'})}
    if($At-eq66){return $(if($English){'Fixed-character reference number (full conditions unconfirmed)'}else{'固定個体の参照番号（全条件未確定）'})}
    if($At-ge67-and$At-le69){return $(if($English){'Reserved area candidate (purpose unconfirmed)'}else{'予約領域候補（用途未確定）'})}
    $jp=@{96='性格';97='アンテナ';98='体色';99='頭';100='体格';101='肌色(上位4ビット)・輪郭(下位4ビット)';102='髪';103='髪色';104='眉';105='目';106='鼻';107='口';108='頬';109='顔装備';94='アンテナ補助情報';95='アンテナ段階・補助情報'}
    $en=@{96='Personality';97='Antenna';98='Body color';99='Head';100='Stature';101='Skin (upper 4 bits) / contour (lower 4 bits)';102='Hair';103='Hair color';104='Eyebrow';105='Eyes';106='Nose';107='Mouth';108='Cheeks';109='Glasses';94='Antenna metadata';95='Antenna stage / metadata'}
    if($At-eq94){return $(if($English){'Generation mode (bits0-2, normal 03) / candidate M (bits3-4), U (bits5-7); full mapping unconfirmed'}else{'生成属性(下位3bit・通常03)・候補表M(bit3～4)／U(bit5～7)（全分類未確定）'})}
    if($At-eq95){return $(if($English){'Experience / growth table group (full exceptions unconfirmed)'}else{'経験値表の区分（全例外未確定）'})}
    if($jp.ContainsKey($At)){return $(if($English){$en[$At]}else{$jp[$At]})}
    if($At-ge8-and$At-le13){return $(if($English){'Identity / generation seed (6 bytes; origin unconfirmed)'}else{'識別・生成の種入力(6バイト・取得元未確定)'})}
    if($At-ge16-and$At-le47){return $(if($English){'Memo (UTF-16LE, 16 code units)'}else{'メモ(UTF-16LE・最大16文字)'})}
    if($At-ge48-and$At-le55){return $(if($English){'Timestamp (8 bytes)'}else{'日時(8バイト)'})}
    if($At-eq56){return $(if($English){'Source level'}else{'元個体レベル'})}
    if($At-ge58-and$At-le63){return $(if($English){'Packed equipment IDs (10 bits each)'}else{'各部位の装備ID(各10ビット)'})}
    if($At-ge70-and$At-le93){return $(if($English){'Name (UTF-16LE, 24-byte buffer)'}else{'名前(UTF-16LE・24バイト領域)'})}
    if($Length-eq288){
      if($At-eq110){return $(if($English){'Special receipt code (1 byte)'}else{'特典受取コード(1バイト)'})}
      if($At-eq111){return $(if($English){'Allowed region count'}else{'許可地域数'})}
      if($At-ge112-and$At-le115){return $(if($English){'Allowed region list'}else{'許可地域リスト'})}
      if($At-ge116-and$At-le187){$slot=[int][Math]::Floor(($At-116)/24)+1;return $(if($English){'Regional name slot '+$slot+' (24 bytes)'}else{'地域別の名前'+$slot+'(24バイト)'})}
      if($At-ge188-and$At-le283){$slot=[int][Math]::Floor(($At-188)/32)+1;return $(if($English){'Regional memo slot '+$slot+' (32 bytes)'}else{'地域別のメモ'+$slot+'(32バイト)'})}
    }
    if($Length-eq120-and$At-ge110-and$At-le111){return $(if($English){'Zero-initialized padding (outside character copy)'}else{'0初期化領域(人物コピー対象外)'})}
    if($Length-eq120-and$At-ge112-and$At-le115){return $(if($English){'Working-buffer residue candidate (source unconfirmed; outside character copy)'}else{'作業領域の残存値候補（残存元未確定・人物コピー対象外）'})}
  }
  return $(if($English){'Unconfirmed / reserved'}else{'用途未確定・予約領域'})
}

# Annotation reflects differences between previously compared original samples,
# not differences from the current editor defaults. Do not flag known fields
# merely because their values differ between characters.
function Get-DenpaDebugByteLabel([int]$Game,[int]$Length,[int]$At,[bool]$English) {
  $label=Get-DenpaDebugByteLabelCore $Game $Length $At $English
  $varies=$false
  if($Game-eq2){
    if($Length-eq120){
      $varies=$At-in@(7,14,57,94,95)
    }elseif($Length-eq288){
      $varies=$At-in@(57,94,95)
    }
  }elseif($Game-eq3){
    $varies=$At-in@(43,48,53)
  }
  if($varies){$label+=if($English){' [values observed in original QR]'}else{' [正規入力有り]'}}
  return $label
}

function Get-DenpaDebugInitial([int]$Game,[int]$Format=-1) {
  if($Game-eq1){Sync-Rpg1Backend;return ,([byte[]]$script:rpg1GeneratedPlain.Clone())}
  $modeControl=if($Game-eq3){$qrType}else{$modeBox}
  $previous=$modeControl.SelectedIndex
  try{
    if($Format-ge0){$modeControl.SelectedIndex=$Format}
    if($Game-eq3){& $displayAction}else{[void]$script:rpg2DisplayOnClick.Invoke($displayButton,@([EventArgs]::Empty))}
    if(-not$script:currentQrPath-or-not$saveButton.Enabled){throw 'QRを生成できませんでした / Could not generate a QR.'}
    $values=New-Object 'Collections.Generic.Dictionary[string,string]'
    $argsCopy=@($script:lastGenerateArguments);$start=if($argsCopy[0]-like'*.mjs'){2}else{1}
    for($i=$start;$i-lt$argsCopy.Count;$i+=2){if($argsCopy[$i]-notin@('--png','--hex-out')){$values[$argsCopy[$i]]=$argsCopy[$i+1]}}
    return ,([DenpaQrVerification.Core]::Plain($Game,[DenpaQrVerification.Core]::Hex([DenpaQrVerification.Core]::Edit($Game,$values))))
  }finally{
    if($modeControl.SelectedIndex-ne$previous){
      $modeControl.SelectedIndex=$previous
      if($Game-eq3){& $displayAction}else{[void]$script:rpg2DisplayOnClick.Invoke($displayButton,@([EventArgs]::Empty))}
    }
  }
}

function Show-DenpaDebugQr([int]$Game=3,[int]$Format=-1) {
  if($script:debugQrWindow-and-not$script:debugQrWindow.IsDisposed){$script:debugQrWindow.Activate();return}
  [byte[]]$initial=Get-DenpaDebugInitial $Game $Format
  $length=$initial.Length;$crcOffset=if($Game-eq1){$length}else{$length-4}
  $special=if($Game-eq3){$length-eq160}elseif($Game-eq2){$length-eq288}else{$false}
  $english=$env:DENPA_EDITOR_LANGUAGE-eq'English'
  $window=New-Object Windows.Forms.Form
  $kind=if($english){if($special){'Special QR'}else{'Normal QR'}}else{if($special){'特典QR'}else{'通常QR'}}
  $window.Text=$(if($english){'Debug Mode'}else{'デバッグモード'})+' - RPG'+$Game+' '+$kind
  $window.ClientSize=New-Object Drawing.Size(930,750);$window.MinimumSize=$window.Size
  $window.StartPosition='CenterParent';$window.Font=New-Object Drawing.Font('Yu Gothic UI',10)
  if($form.Icon){$window.Icon=$form.Icon}
  $script:debugQrWindow=$window
  $state=@{Result=$null;Dirty=$false}
  $debugOwnerModule=$ExecutionContext.SessionState.Module
  $formatBox=New-Object Windows.Forms.ComboBox;$formatBox.Name='debugQrFormat';$formatBox.DropDownStyle='DropDownList'
  $formatBox.Location=New-Object Drawing.Point(20,600);$formatBox.Size=New-Object Drawing.Size(175,28)
  [void]$formatBox.Items.Add($(if($english){'Normal QR'}else{'通常QR'}))
  if($Game-ne1){[void]$formatBox.Items.Add($(if($english){'Special QR'}else{'特典QR'}))}
  $formatBox.SelectedIndex=if($special){1}else{0};$formatBox.Enabled=$Game-ne1;$window.Controls.Add($formatBox)
  $formatBox.Add_SelectedIndexChanged(({
    if($state.Switching){return}
    if($state.Dirty){
      $answer=[Windows.Forms.MessageBox]::Show($(if($english){'Discard ungenerated edits and switch format?'}else{'未生成の編集を破棄して形式を切り替えますか？'}),$window.Text,'YesNo','Question')
      if($answer-ne'Yes'){$state.Switching=$true;try{$formatBox.SelectedIndex=if($special){1}else{0}}finally{$state.Switching=$false};return}
    }
    $next=$formatBox.SelectedIndex;$window.Close()
    if($debugOwnerModule){& $debugOwnerModule {param($number,$format) Show-DenpaDebugQr $number $format} $Game $next}
    else{Show-DenpaDebugQr $Game $next}
  }.GetNewClosure()))
  $picture=New-Object Windows.Forms.PictureBox
  $picture.Location=New-Object Drawing.Point(20,100);$picture.Size=New-Object Drawing.Size(370,370)
  $picture.SizeMode='Zoom';$picture.BackColor=[Drawing.Color]::White;$window.Controls.Add($picture)
  $note=New-Object Windows.Forms.Label
  $note.Location=New-Object Drawing.Point(20,16);$note.Size=New-Object Drawing.Size(875,70)
  $note.Text=if($english){'Edit every decrypted byte in offset order (00-FF). Packed fields share bytes; multi-byte values use little-endian order. Invalid values can make the QR unusable. Changes affect only this debug window, not the main editor.'}else{'復号した全バイトを位置順に00～FFで編集します。同じバイトに複数の項目が入る場合があります。複数バイトの値は下位から順番です。不正な値では読み込めない場合があります。変更はこの画面だけに反映され、通常画面の設定は変更しません。'}
  $window.Controls.Add($note)
  $contact=New-Object Windows.Forms.LinkLabel;$contact.Name='debugDiscoveryContact'
  $contact.Text='新たな発見があった場合はDiscord / X までご連絡ください。'
  $contact.Location=New-Object Drawing.Point(20,650);$contact.Size=New-Object Drawing.Size(890,27);$window.Controls.Add($contact)
  $contact.LinkArea=New-Object Windows.Forms.LinkArea(0,0)
  [void]$contact.Links.Add($contact.Text.IndexOf('Discord'),7,'https://discord.gg/ndf')
  [void]$contact.Links.Add($contact.Text.IndexOf('X'),1,'https://x.com/ranobye_')
  $contact.Add_LinkClicked({param($sender,$event) Start-Process ([string]$event.Link.LinkData)})
  $research=New-Object Windows.Forms.Label;$research.Name='debugResearchNotes';$research.Location=New-Object Drawing.Point(20,687);$research.Size=New-Object Drawing.Size(890,52)
  $research.Text=if($english){'Fields marked Unconfirmed include inferred meanings that have not been fully verified and may be incorrect. Changing values may make the QR unreadable.'}else{'「未確定」の項目は推測を含み、十分な確認が取れていないため、説明が誤っている可能性があります。設定の変更によりQRが読み取れなくなる場合があります。'}
  $window.Controls.Add($research)
  $research.Height=100;$window.ClientSize=New-Object Drawing.Size(930,800)
  $grid=New-Object Windows.Forms.DataGridView
  $grid.Name='debugByteGrid';$grid.Location=New-Object Drawing.Point(410,100);$grid.Size=New-Object Drawing.Size(500,480)
  $grid.Anchor='Top,Bottom,Left,Right';$grid.AllowUserToAddRows=$false;$grid.AllowUserToDeleteRows=$false
  $grid.AllowUserToOrderColumns=$false;$grid.RowHeadersVisible=$false;$grid.SelectionMode='CellSelect'
  [void]$grid.Columns.Add('offset','Offset');[void]$grid.Columns.Add('value',$(if($english){'Hex (editable)'}else{'値（編集可）'}))
  [void]$grid.Columns.Add('meaning',$(if($english){'Field'}else{'項目'}))
  $grid.Columns[0].ReadOnly=$true;$grid.Columns[0].Width=80
  $grid.Columns[1].Width=110;$grid.Columns[1].MaxInputLength=2
  $grid.EditMode='EditOnEnter'
  $grid.Columns[0].DefaultCellStyle.BackColor=[Drawing.Color]::Gainsboro
  $grid.Columns[2].DefaultCellStyle.BackColor=[Drawing.Color]::Gainsboro
  $grid.Columns[1].DefaultCellStyle.BackColor=[Drawing.Color]::LightYellow
  $grid.Columns[1].DefaultCellStyle.SelectionBackColor=[Drawing.Color]::Khaki
  $grid.Columns[1].DefaultCellStyle.SelectionForeColor=[Drawing.Color]::Black
  $note.Text+=if($english){' Yellow values are editable: click and enter 00-FF. Gray cells are read-only or calculated automatically.'}else{' 黄色の値をクリックすると00～FFで編集できます。灰色は編集不可、または自動計算です。'}
  $grid.Columns[2].ReadOnly=$true;$grid.Columns[2].AutoSizeMode='Fill'
  $grid.Columns[2].DefaultCellStyle.WrapMode='True';$grid.AutoSizeRowsMode='AllCells'
  foreach($column in $grid.Columns){$column.SortMode='NotSortable'}
  for($i=0;$i-lt$length;$i++){
    $label=Get-DenpaDebugByteLabel $Game $length $i $english
    [void]$grid.Rows.Add(('0x{0:X2}'-f$i),('{0:X2}'-f$initial[$i]),$label)
    $grid.Rows[$i].Cells[2].ToolTipText=$label
  }
  $window.Controls.Add($grid)
  $auto=New-Object Windows.Forms.CheckBox;$auto.Text=if($english){'Recalculate CRC automatically'}else{'チェックサムを自動計算'}
  $auto.Location=New-Object Drawing.Point(20,490);$auto.Size=New-Object Drawing.Size(370,28);$auto.Checked=$true;$window.Controls.Add($auto)
  if($Game-eq1){$auto.Checked=$false;$auto.Enabled=$false;$auto.Text=if($english){'RPG1: no RPG2/3 CRC recalculation'}else{'RPG1：RPG2・3のCRC自動計算は対象外'}}
  $help=New-Object Windows.Forms.ToolTip
  $help.SetToolTip($auto,$(if($english){'Recomputes the four-byte integrity value after edits. It does not validate game values or guarantee game acceptance.'}else{'編集後のデータから末尾4バイトの検査値を計算し直します。値の正しさや実機での反映を保証するものではありません。'}))
  $help.SetToolTip($grid,$(if($english){'Edit hexadecimal values from 00 to FF. Changing values may make the QR unreadable.'}else{'00～FFの16進数で編集します。値によってはQRを読み取れなくなる場合があります。'}))
  $status=New-Object Windows.Forms.Label;$status.Location=New-Object Drawing.Point(20,530);$status.Size=New-Object Drawing.Size(370,65);$window.Controls.Add($status)
  $generate=New-Object Windows.Forms.Button;$generate.Text=if($english){'Generate QR'}else{'QR生成'};$generate.Location=New-Object Drawing.Point(410,600);$generate.Size=New-Object Drawing.Size(145,38);$window.Controls.Add($generate)
  $save=New-Object Windows.Forms.Button;$save.Text=if($english){'Save PNG'}else{'PNG保存'};$save.Location=New-Object Drawing.Point(565,600);$save.Size=New-Object Drawing.Size(145,38);$window.Controls.Add($save)
  $reset=New-Object Windows.Forms.Button;$reset.Text=if($english){'Reset'}else{'開いた時の値に戻す'};$reset.Location=New-Object Drawing.Point(720,600);$reset.Size=New-Object Drawing.Size(190,38);$window.Controls.Add($reset)
  $dirty={ $state.Dirty=$true;$save.Enabled=$false;$status.Text=if($english){'Edited. Generate QR to update the preview.'}else{'編集中です。QR生成で左のQRを更新します。'} }.GetNewClosure()
  $grid.Add_CellValueChanged($dirty)
  $updateCrc={for($i=$crcOffset;$i-lt$length;$i++){$cell=$grid.Rows[$i].Cells[1];$cell.ReadOnly=$auto.Checked;$cell.Style.BackColor=if($auto.Checked){[Drawing.Color]::Gainsboro}else{[Drawing.Color]::LightYellow};$cell.Style.SelectionBackColor=if($auto.Checked){[Drawing.Color]::Silver}else{[Drawing.Color]::Khaki};$cell.ToolTipText=if($auto.Checked){'自動計算 / Automatically calculated'}else{'編集可 00-FF / Editable'}}}.GetNewClosure()
  & $updateCrc
  $auto.Add_CheckedChanged(({& $updateCrc;& $dirty}.GetNewClosure()))
  $render={
    try{
      [void]$grid.EndEdit();[byte[]]$plain=New-Object byte[] $length
      for($i=0;$i-lt$length;$i++){
        $value=([string]$grid.Rows[$i].Cells[1].Value).Trim()
        if($value-notmatch'\A[0-9a-fA-F]{2}\z'){throw ('0x{0:X2}: 00-FFの2桁で入力してください / Enter two hex digits.'-f$i)}
        $plain[$i]=[Convert]::ToByte($value,16)
      }
      $result=ConvertTo-DenpaDebugQr $plain $auto.Checked $Game
      $bitmap=[DenpaQrVerification.Core]::Bitmap($result.Payload)
      $old=$picture.Image;$picture.Image=$bitmap;if($old){$old.Dispose()}
      for($i=0;$i-lt$length;$i++){$grid.Rows[$i].Cells[1].Value=('{0:X2}'-f$result.Plain[$i])}
      $state.Result=$result;$state.Dirty=$false;$save.Enabled=$true
      $status.Text=if($english){"Generated: $length bytes. Game acceptance requires testing."}else{"$length バイトのQRを生成しました。実機の読み取り可否は別途確認が必要です。"}
    }catch{$save.Enabled=$false;if($env:DENPA_UNIFIED_EDITOR_SMOKE-like'debug-*'){throw};[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,$window.Text,'OK','Error')}
  }.GetNewClosure()
  $generate.Add_Click($render)
  $reset.Add_Click(({for($i=0;$i-lt$length;$i++){$grid.Rows[$i].Cells[1].Value=('{0:X2}'-f$initial[$i])};& $render}.GetNewClosure()))
  $save.Add_Click(({
    if($state.Dirty-or-not$state.Result){return}
    $dialog=New-Object Windows.Forms.SaveFileDialog;$dialog.Filter='PNG (*.png)|*.png';$dialog.FileName=('RPG'+$Game+'-debug-'+$(if($special){'special'}else{'normal'})+'.png')
    try{if($dialog.ShowDialog($window)-eq'OK'){$picture.Image.Save($dialog.FileName,[Drawing.Imaging.ImageFormat]::Png)}}finally{$dialog.Dispose()}
  }.GetNewClosure()))
  $window.Add_FormClosed(({if($picture.Image){$picture.Image.Dispose();$picture.Image=$null};$help.Dispose();$window.Dispose()}.GetNewClosure()))
  & $render
  $window.Tag=@{Render=$render;State=$state}
  $window.Show($form)
}
