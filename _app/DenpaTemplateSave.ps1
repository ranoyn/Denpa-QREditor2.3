function Get-DenpaCurrentTemplate([string]$Game){
  $fields=@{}
  foreach($key in $boxes.Keys){
    if($key-eq'--name'){continue}
    $control=$boxes[$key]
    if($control.SelectedIndex-lt0){throw ('Select a value for '+$key)}
    $fields[$key]=switch($Game){
      'RPG1' {if($key-eq'--skin-color'){([int]$rpg1SkinUiToStored[$control.SelectedIndex]).ToString()}else{$control.SelectedIndex.ToString()}}
      'RPG2' {Get-Code $control}
      'RPG3' {if($fieldCodesByKey.ContainsKey($key)){Get-FieldCode $control}else{'{0:X2}'-f$control.SelectedIndex}}
    }
  }
  $names=@{};foreach($language in $nameLanguage.ActiveLanguages){$names[$language]=[string]$nameLanguage.Boxes[$language].Text}
  if([string]::IsNullOrWhiteSpace($names.JP)){throw 'Enter a name before saving.'}
  $options=@{}
  if($regionButtons){$options.Region=($regionButtons.GetEnumerator()|Where-Object{$_.Value.Checked}|Select-Object -First 1).Key}
  # Stable variable names identify optional controls, not their translated labels.
  foreach($variableName in @('edition','modeBox','qrType','neckBox','armBox','backBox','feetBox','clothingBox','claimSlotBox','extendedSpecialCode','decorAllCheck','capturedCheck','capturedMonster','correctionBox','jewelQuantity','qrDate','towerCombinationCheck','definedFaceCheck','faceSyncCheck','legitimateFaceCheck')){
    $control=Get-Variable -Name $variableName -ValueOnly -ErrorAction SilentlyContinue
    if($control-is[Windows.Forms.ComboBox]){$options[$variableName]=@{Index=$control.SelectedIndex}}
    elseif($control-is[Windows.Forms.CheckBox]){$options[$variableName]=@{Checked=$control.Checked}}
    elseif($control-is[Windows.Forms.NumericUpDown]){$options[$variableName]=@{Value=[int]$control.Value}}
    elseif($control-is[Windows.Forms.DateTimePicker]){$options[$variableName]=@{Date=$control.Value.ToString('yyyy-MM-dd');Checked=$control.Checked}}
  }
  if($Game-eq'RPG3'){
    $options.Memo=[string]$rpg3MemoBox.Text
    $options.PaintColor=if($rpg3PaintBox.SelectedIndex-le0){-1}else{$rpg3PaintBox.SelectedIndex-1}
    $options.Equipment=@{};foreach($key in $rpg3EquipmentBoxes.Keys){$i=$rpg3EquipmentBoxes[$key].SelectedIndex;$options.Equipment[$key]=if($i-le0){0}else{[int]$rpg3EquipmentRows[$key][$i-1].internal_id}}
    $options.Rewards=@($itemRewards|ForEach-Object{$_.SelectedIndex})
    $options.Bonuses=@{};foreach($key in $statBonusControls.Keys){$options.Bonuses[$key]=[int]$statBonusControls[$key].Value}
    if($sourceLevelCheck){$options.SourceLevel=@{Checked=[bool]$sourceLevelCheck.Checked;Value=[int]$sourceLevelInput.Value}}
  }
  $options.IndividualNames=[bool]$nameLanguage.IndividualCheck.Checked
  if($Game-eq'RPG2'){$options.Memo=[string]$rpg2MemoBox.Text;$options.PaintColor=if($rpg2PaintBox.SelectedIndex-le0){-1}else{$rpg2PaintBox.SelectedIndex-1}}
  $options.AdvancedQR=Copy-DenpaAdvancedQrState (Get-DenpaAdvancedQrState)
  if($script:callLab){$options.CallLab=@{Checked=$script:callLab.Check.Checked;Ability=(Get-DenpaCallLabSelection)}}
  @{formatVersion=1;Order=10000;Label=$names.JP;Name=$names.JP;Names=$names;Fields=$fields;SavedOptions=$options;EuLanguage=(Get-DenpaSelectedEuLanguage $nameLanguage)}
}

function Apply-DenpaSavedTemplate([Collections.IDictionary]$Template,[string]$Game){
  if($Game-eq'RPG2'){Clear-Rpg2OfficialTemplateDate;$script:rpg2TemplateSpecialCarrierPath=$null}
  if($Game-eq'RPG3'){Clear-Rpg3OfficialTemplateDate;$script:rpg3TemplateSpecialCarrierPath=$null}
  $towerCombinationCheck.Checked=$false
  $definedFaceCheck.Checked=$false
  $syncControl=if($Game-eq'RPG3'){$legitimateFaceCheck}else{$faceSyncCheck}
  $syncControl.Checked=$false
  foreach($entry in $Template.Fields.GetEnumerator()|Where-Object{$_.Key-ne'--antenna-appearance'}){
    switch($Game){
      'RPG1' {if($entry.Key-eq'--skin-color'){$boxes[$entry.Key].SelectedIndex=[int]$rpg1SkinStoredToUi[[int]$entry.Value]}else{$boxes[$entry.Key].SelectedIndex=[int]$entry.Value}}
      'RPG2' {Set-Rpg2TemplateCode $entry.Key $entry.Value}
      'RPG3' {Set-Rpg3TemplateCode $entry.Key $entry.Value}
    }
  }
  if($Template.Fields.ContainsKey('--antenna-appearance')){
    switch($Game){
      'RPG1' {$boxes['--antenna-appearance'].SelectedIndex=[int]$Template.Fields['--antenna-appearance']}
      'RPG2' {Set-Rpg2TemplateCode '--antenna-appearance' $Template.Fields['--antenna-appearance']}
      'RPG3' {Set-Rpg3TemplateCode '--antenna-appearance' $Template.Fields['--antenna-appearance']}
    }
  }
  $options=$Template.SavedOptions
  if($Game-eq'RPG2'){$rpg2MemoBox.Text=if($options.ContainsKey('Memo')){[string]$options.Memo}else{''};$rpg2PaintBox.SelectedIndex=if($options.ContainsKey('PaintColor')){[int]$options.PaintColor+1}else{0}}
  $script:advancedQrState=@{Level=$null;Unknown=@{}}
  if($options.ContainsKey('AdvancedQR')){$script:advancedQrState=Copy-DenpaAdvancedQrState $options.AdvancedQR}
  foreach($variableName in @('edition','modeBox','qrType','decorAllCheck','neckBox','armBox','backBox','feetBox','clothingBox','claimSlotBox','extendedSpecialCode','capturedMonster','capturedCheck','correctionBox','jewelQuantity','qrDate')){
    if(-not$options.ContainsKey($variableName)){continue}
    $control=Get-Variable -Name $variableName -ValueOnly -ErrorAction SilentlyContinue
    $value=$options[$variableName]
    if($control-is[Windows.Forms.ComboBox]){$control.SelectedIndex=[int]$value.Index}
    elseif($control-is[Windows.Forms.CheckBox]){$control.Checked=[bool]$value.Checked}
    elseif($control-is[Windows.Forms.NumericUpDown]){$control.Value=[decimal]$value.Value}
    elseif($control-is[Windows.Forms.DateTimePicker]){$control.Value=[datetime]::ParseExact($value.Date,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);if($value.ContainsKey('Checked')){$control.Checked=[bool]$value.Checked}}
  }
  if($Game-eq'RPG3'){
    $rpg3MemoBox.Text=if($options.ContainsKey('Memo')){[string]$options.Memo}else{''}
    $paintColor=if($options.ContainsKey('PaintColor')){[int]$options.PaintColor}else{-1}
    $rpg3PaintBox.SelectedIndex=if($paintColor-ge0-and$paintColor-lt$bodyColorNames.Count){$paintColor+1}else{0}
    foreach($key in $rpg3EquipmentBoxes.Keys){$id=if($options.ContainsKey('Equipment')-and$options.Equipment.ContainsKey($key)){[int]$options.Equipment[$key]}else{0};$ids=@(0)+@($rpg3EquipmentRows[$key]|ForEach-Object{[int]$_.internal_id});$index=[Array]::IndexOf([object[]]$ids,[object]$id);$rpg3EquipmentBoxes[$key].SelectedIndex=[Math]::Max(0,$index)}
    for($i=0;$i-lt$options.Rewards.Count;$i++){$itemRewards[$i].SelectedIndex=[int]$options.Rewards[$i]}
    foreach($key in $statBonusControls.Keys){$statBonusControls[$key].Value=0}
    foreach($key in $options.Bonuses.Keys){if($statBonusControls.Contains($key)){$statBonusControls[$key].Value=[Math]::Min($statBonusControls[$key].Maximum,[Math]::Max(0,[decimal]$options.Bonuses[$key]))}}
    $capturedCheck.Checked=($capturedMonster.SelectedIndex-gt0)
    if($sourceLevelCheck){
      $sourceLevelCheck.Checked=$false;$sourceLevelInput.Value=199
      if($options.ContainsKey('SourceLevel')){$sourceLevelInput.Value=[Math]::Max(1,[Math]::Min(199,[int]$options.SourceLevel.Value));$sourceLevelCheck.Checked=[bool]$options.SourceLevel.Checked}
      Update-Rpg3AntennaEvolution
    }
  }
  # A template is input data only; legacy Carrier properties are intentionally ignored.
  if($options.ContainsKey('IndividualNames')){$nameLanguage.IndividualCheck.Checked=[bool]$options.IndividualNames}else{$nameLanguage.IndividualCheck.Checked=$false}
  if($script:callLab){
    $script:callLab.Check.Checked=$false;Update-DenpaCallLab
    if($options.ContainsKey('CallLab')-and$options.CallLab.Checked-and$script:callLab.Check.Enabled){
      $script:callLab.Check.Checked=$true
      $index=[Array]::IndexOf([object[]]$script:callLab.Codes,[object][int]$options.CallLab.Ability)
      if($index-ge0){$script:callLab.Combo.SelectedIndex=$index}
    }
  }
  foreach($variableName in @('faceSyncCheck','legitimateFaceCheck','definedFaceCheck','towerCombinationCheck')){
    if($options.ContainsKey($variableName)){$control=Get-Variable -Name $variableName -ValueOnly -ErrorAction SilentlyContinue;if($control){$control.Checked=[bool]$options[$variableName].Checked}}
  }
  Set-DenpaTemplateNames $nameLanguage $Template
  if($Template.ContainsKey('EuLanguage')){Set-DenpaEuLanguage $nameLanguage $Template.EuLanguage}
  if($options.Region-and$regionButtons.ContainsKey($options.Region)){$regionButtons[$options.Region].Checked=$true}
  if($Template.FacePartsPending-and-not$env:DENPA_UNIFIED_EDITOR_SMOKE){
    $notice=if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Face parts are not yet identified. Only the known head, body color and specified stature are applied; other appearance values remain unchanged.'}else{'顔パーツは未判明です。判明済みの頭・体色・指定された体格のみ反映しました。その他の外見設定は現在の値のままです。'}
    [void][Windows.Forms.MessageBox]::Show($notice,'QREditor','OK','Information')
  }
  if($Template.SkinColorPending-and-not$env:DENPA_UNIFIED_EDITOR_SMOKE){
    $skinLabel=[string]$Template.SourceSkinColor.EditorLabel
    $notice=if($env:DENPA_EDITOR_LANGUAGE-eq'English'){"Skin color $skinLabel from the original game data is not available in this Editor yet. Face parts have been applied, but the current skin color is kept."}else{"元データの肌色「$skinLabel」は現行Editorでは未対応です。顔パーツは反映しましたが、肌色は現在の設定を保持しています。"}
    [void][Windows.Forms.MessageBox]::Show($notice,'QREditor','OK','Information')
  }
}

function Save-DenpaCurrentTemplate([string]$Game,[string]$ApplicationRoot=$PSScriptRoot){
  $template=Get-DenpaCurrentTemplate $Game
  $directory=Join-Path (Join-Path $ApplicationRoot 'Denpatemplates') $Game
  [void][IO.Directory]::CreateDirectory($directory)
  $path=Join-Path $directory ('user-'+[Guid]::NewGuid().ToString('N')+'.json')
  [IO.File]::WriteAllText($path,($template|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
  $catalog=@(Import-DenpaTemplateCatalog -ApplicationRoot $ApplicationRoot -Game $Game)
  switch($Game){'RPG1' {$script:rpg1Templates=$catalog};'RPG2' {$script:rpg2Templates=$catalog};'RPG3' {$script:rpg3Templates=$catalog}}
  $script:templateCatalogRefreshing=$true
  try{
    $faceTemplateBox.BeginUpdate();$faceTemplateBox.Items.Clear()
    [void]$faceTemplateBox.Items.Add($(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'None'}else{[regex]::Unescape('(\u9078\u629e\u306a\u3057)')}))
    [void]$faceTemplateBox.Items.AddRange([object[]]@($catalog|ForEach-Object{Get-DenpaTemplateDisplayLabel $_}))
    $faceTemplateBox.SelectedIndex=0
    for($i=0;$i-lt$catalog.Count;$i++){if($catalog[$i]._sourceFile-eq$path){$faceTemplateBox.SelectedIndex=$i+1;break}}
  }finally{$faceTemplateBox.EndUpdate();$script:templateCatalogRefreshing=$false}
  $path
}

function Confirm-DenpaTemplateSave([string]$Game){
  $denpaName=[string]$nameLanguage.Boxes.JP.Text
  if($env:DENPA_EDITOR_LANGUAGE-eq'English'){
    $denpaName=Get-DenpaNameForRegion $nameLanguage 'NA'
    $message='Save '+$denpaName+' to Denpa Template?';$title='Save Template'
  }else{
    $message=$denpaName+[regex]::Unescape('\u3092\u96fb\u6ce2\u30c6\u30f3\u30d7\u30ec\u30fc\u30c8\u306b\u4fdd\u5b58\u3057\u307e\u3059\u304b\uff1f')
    $title=[regex]::Unescape('\u30c6\u30f3\u30d7\u30ec\u30fc\u30c8\u4fdd\u5b58')
  }
  $answer=Show-DenpaYesNoDialog $form $message $title
  if($answer-eq[Windows.Forms.DialogResult]::Yes){[void](Save-DenpaCurrentTemplate $Game)}
}

function Show-DenpaYesNoDialog([Windows.Forms.Form]$Owner,[string]$Message,[string]$Title){
  $dialog=New-Object Windows.Forms.Form
  $dialog.Icon=$Owner.Icon
  $dialog.Text=$Title;$dialog.StartPosition='CenterParent';$dialog.FormBorderStyle='FixedDialog'
  $dialog.MinimizeBox=$false;$dialog.MaximizeBox=$false;$dialog.ShowInTaskbar=$false
  $dialog.ClientSize=New-Object Drawing.Size(440,155)
  $label=New-Object Windows.Forms.Label;$label.Text=$Message;$label.Location=New-Object Drawing.Point(20,20);$label.Size=New-Object Drawing.Size(400,70)
  $dialog.Controls.Add($label)
  $yes=New-Object Windows.Forms.Button;$no=New-Object Windows.Forms.Button
  $yes.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Yes'}else{[regex]::Unescape('\u306f\u3044')})
  $no.Text=$(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'No'}else{[regex]::Unescape('\u3044\u3044\u3048')})
  $yes.Location=New-Object Drawing.Point(218,108);$no.Location=New-Object Drawing.Point(324,108)
  foreach($button in @($yes,$no)){$button.Size=New-Object Drawing.Size(96,30);$dialog.Controls.Add($button)}
  $yes.DialogResult='Yes';$no.DialogResult='No';$dialog.AcceptButton=$yes;$dialog.CancelButton=$no
  $dialog.Add_Shown({$no.Focus()})
  try{$dialog.ShowDialog($Owner)}finally{$dialog.Dispose()}
}

function Get-DenpaTemplateDisplayLabel([Collections.IDictionary]$Template){
  if($env:DENPA_EDITOR_LANGUAGE-ne'English'){return [string]$Template.Label}
  $englishName=[string]$Template.Name
  if($Template.ContainsKey('Names')-and$Template.Names.NA){$englishName=[string]$Template.Names.NA}
  else{$row=@($nameLanguage.Rows|Where-Object JP -eq $Template.Name|Select-Object -First 1);if($row.Count-and$row[0].NA){$englishName=[string]$row[0].NA}}
  $suffix=''
  if($Template.Label-match'[\uFF08(]\u516c\u5f0f[\uFF09)]$'){$suffix='(Official)'}
  elseif($Template.Label-match'[\uFF08(]\u30b9\u30c8\u30fc\u30ea\u30fc(?<game>RPG[23])?[\uFF09)]$'){$suffix='(Story'+$Matches.game+')'}
  elseif($Template.Label-match'[\uFF08(]\u4e3b\u4eba\u516c[\uFF09)]$'){$suffix='(Protagonist)'}
  $englishName+$suffix
}

function Update-DenpaTemplateDisplayLabels([string]$Game){
  $catalog=switch($Game){'RPG1' {$rpg1Templates};'RPG2' {$rpg2Templates};'RPG3' {$rpg3Templates}}
  $selected=$faceTemplateBox.SelectedIndex
  $script:templateCatalogRefreshing=$true
  $faceTemplateBox.BeginUpdate()
  try{
    $faceTemplateBox.Items.Clear()
    [void]$faceTemplateBox.Items.Add($(if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'None'}else{[regex]::Unescape('(\u9078\u629e\u306a\u3057)')}))
    if(@($catalog).Count){[void]$faceTemplateBox.Items.AddRange([object[]]@($catalog|ForEach-Object{Get-DenpaTemplateDisplayLabel $_}))}
    $faceTemplateBox.SelectedIndex=$selected
  }finally{$faceTemplateBox.EndUpdate();$script:templateCatalogRefreshing=$false}
}
