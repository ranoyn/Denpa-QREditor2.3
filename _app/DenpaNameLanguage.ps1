function Get-DenpaNameLanguageCatalog {
  param([string]$DataRoot,[string]$CatalogFile='')
  if($CatalogFile){
    $path=Join-Path $DataRoot $CatalogFile
    if(!(Test-Path -LiteralPath $path)){throw "地域別名前一覧が見つかりません: $CatalogFile"}
    return @(Import-Csv -LiteralPath $path -Delimiter "`t" -Encoding UTF8|ForEach-Object{[pscustomobject]@{Index=[int]$_.index;Source='RPG1';NameId=[int]$_.index;JP=[string]$_.JP;NA=[string]$_.NA;EU=[string]$_.EU;DEU=[string]$_.DEU;FRA=[string]$_.FRA}})
  }
  $naPath=Join-Path $DataRoot 'rpg3-name-catalog-na.tsv'
  $euPath=Join-Path $DataRoot 'rpg3-name-catalog-eu.tsv'
  if(!(Test-Path -LiteralPath $naPath)-or!(Test-Path -LiteralPath $euPath)){throw '地域別名前一覧が見つかりません。'}
  $naRows=@(Import-Csv -LiteralPath $naPath -Delimiter "`t" -Encoding UTF8)
  $euRows=@(Import-Csv -LiteralPath $euPath -Delimiter "`t" -Encoding UTF8)
  if($naRows.Count-ne$euRows.Count){throw 'EU／NA名前一覧の件数が一致しません。'}
  $rows=@()
  $rpg1RowsByIndex=@{}
  $rpg1Path=Join-Path $DataRoot 'rpg1-name-catalog.tsv'
  if(Test-Path -LiteralPath $rpg1Path){foreach($row in @(Import-Csv -LiteralPath $rpg1Path -Delimiter "`t" -Encoding UTF8)){$rpg1RowsByIndex[[int]$row.index]=$row}}
  for($i=0;$i-lt$naRows.Count;$i++){
    if($naRows[$i].source_table-ne$euRows[$i].source_table-or$naRows[$i].name_id-ne$euRows[$i].name_id-or$naRows[$i].name_ja-ne$euRows[$i].name_ja){throw "EU／NA名前IDが一致しません: $i"}
    $deu=[string]$euRows[$i].name_eu_en;$fra=$deu
    $nameId=[int]$naRows[$i].name_id
    if([string]$naRows[$i].source_table-eq'male_table'-and$rpg1RowsByIndex.ContainsKey($nameId)){
      $rpg1Row=$rpg1RowsByIndex[$nameId]
      if([string]$rpg1Row.JP-eq[string]$naRows[$i].name_ja){$deu=[string]$rpg1Row.DEU;$fra=[string]$rpg1Row.FRA}
    }
    $rows+=[pscustomobject]@{Index=$i;Source=[string]$naRows[$i].source_table;NameId=$nameId;JP=[string]$naRows[$i].name_ja;NA=[string]$naRows[$i].name_na;EU=[string]$euRows[$i].name_eu_en;DEU=$deu;FRA=$fra}
  }
  $rows
}

function Sort-DenpaNameLanguageRows {
  param([object[]]$Rows,[ValidateSet('JP','EU','NA','DEU','FRA')][string]$Language)
  $culture=if($Language-eq'JP'){'ja-JP'}else{'en-US'}
  @($Rows|Sort-Object -Culture $culture -Property @{Expression={[string]$_.PSObject.Properties[$Language].Value};Ascending=$true},@{Expression={[int]$_.Index};Ascending=$true})
}

function Set-DenpaNameAutoComplete {
  param([Windows.Forms.ComboBox]$Box,[object[]]$Rows,[ValidateSet('JP','EU','NA','DEU','FRA')][string]$Language)
  $source=New-Object Windows.Forms.AutoCompleteStringCollection
  [void]$source.AddRange([string[]]@($Rows|ForEach-Object{[string]$_.PSObject.Properties[$Language].Value}))
  $Box.AutoCompleteMode=[Windows.Forms.AutoCompleteMode]::SuggestAppend
  $Box.AutoCompleteSource=[Windows.Forms.AutoCompleteSource]::CustomSource
  $Box.AutoCompleteCustomSource=$source
}

function Set-DenpaNameRawText {
  param([object]$State,[string]$Text)
  if($null-eq$State){return}
  $State.Syncing=$true
  try{foreach($language in $State.ActiveLanguages){$State.Boxes[$language].Text=$Text}}finally{$State.Syncing=$false}
}

function Sync-DenpaNameLanguageRow {
  param([object]$State,[object]$Row)
  if($null-eq$State-or$null-eq$Row){return}
  $State.Syncing=$true
  try{foreach($language in $State.ActiveLanguages){$State.Boxes[$language].Text=[string]$Row.PSObject.Properties[$language].Value};$State.SelectedId=[int]$Row.Index}finally{$State.Syncing=$false}
}

function Get-DenpaSelectedNameRow {
  param([object]$State,[ValidateSet('JP','EU','NA','DEU','FRA')][string]$Language,[Windows.Forms.ComboBox]$Box)
  $rows=@($State.Sorted[$Language]);$text=[string]$Box.Text
  if($Box.Items.Count-eq$rows.Count-and$Box.SelectedIndex-ge0-and$Box.SelectedIndex-lt$rows.Count){return $rows[$Box.SelectedIndex]}
  $same=@($rows|Where-Object{[string]$_.PSObject.Properties[$Language].Value-eq$text})
  if($same.Count){return $same[0]}
  $null
}

function Set-DenpaEuLanguage {
  param([object]$State,[ValidateSet('EU','DEU','FRA')][string]$Language)
  if($null-eq$State){return}
  $State.Syncing=$true
  try{
    foreach($other in @('EU','DEU','FRA')){$State.Checks[$other].Checked=($other-eq$Language);$State.Boxes[$other].Enabled=($other-eq$Language)}
  }finally{$State.Syncing=$false}
}

function New-DenpaNameLanguageState {
  param([Windows.Forms.Form]$Form,[string]$DataRoot,[Windows.Forms.ComboBox]$JpBox,[string]$CatalogFile='',[string[]]$AdditionalLanguages=@())
  $initialText=if([string]::IsNullOrWhiteSpace($JpBox.Text)){'つかさ'}else{[string]$JpBox.Text}
  $rows=@(Get-DenpaNameLanguageCatalog $DataRoot $CatalogFile)
  $activeLanguages=@('JP','NA','EU','DEU','FRA')
  $sorted=@{};foreach($language in $activeLanguages){$sorted[$language]=@(Sort-DenpaNameLanguageRows $rows $language)}
  $checks=@{};$boxes=@{JP=$JpBox};$labels=@{}
  foreach($language in @('JP','EU','NA','DEU','FRA')){
    $check=New-Object Windows.Forms.CheckBox;$check.Name=('nameLanguageCheck'+$language);$check.Text=$language;$check.AutoSize=$true;$check.Checked=($language-in@('JP','NA','EU'));$check.Enabled=($language-in@('EU','DEU','FRA'));$check.Visible=($language-in@('EU','DEU','FRA'));if($language-in@('EU','DEU','FRA')){$check.AutoCheck=$false};$Form.Controls.Add($check);$checks[$language]=$check
    if($language-in@('JP','NA')){$label=New-Object Windows.Forms.Label;$label.Name=('nameLanguageLabel'+$language);$label.Text=$language;$label.AutoSize=$true;$Form.Controls.Add($label);$labels[$language]=$label}
    if($language-ne'JP'){
      $box=New-Object Windows.Forms.ComboBox;$box.Name=('nameLanguage'+$language);$box.DropDownStyle=[Windows.Forms.ComboBoxStyle]::DropDown;$box.Size=New-Object Drawing.Size(120,27);$box.DropDownWidth=170;$box.MaxDropDownItems=12;$Form.Controls.Add($box);$boxes[$language]=$box
    }
  }
  $JpBox.DropDownStyle=[Windows.Forms.ComboBoxStyle]::DropDown;$JpBox.DropDownWidth=170;$JpBox.MaxDropDownItems=12
  foreach($language in $activeLanguages){$box=$boxes[$language];$box.BeginUpdate();try{$box.Items.Clear();[void]$box.Items.AddRange([object[]]@($sorted[$language]|ForEach-Object{[string]$_.PSObject.Properties[$language].Value}))}finally{$box.EndUpdate()};Set-DenpaNameAutoComplete $box $sorted[$language] $language}
  $JpBox.Text=$initialText
  $individual=New-Object Windows.Forms.CheckBox;$individual.Name='individualNames';$individual.Text='名前を個別入力';$individual.Checked=$false;$individual.AutoSize=$true;$individual.Font=New-Object Drawing.Font('Yu Gothic UI',9);$individual.Location=New-Object Drawing.Point(775,15);$Form.Controls.Add($individual)
  $state=[pscustomobject]@{Rows=$rows;Sorted=$sorted;Checks=$checks;Boxes=$boxes;Labels=$labels;IndividualCheck=$individual;ActiveLanguages=$activeLanguages;EuLanguages=@('EU','DEU','FRA');Syncing=$false;SelectedId=-1}
  $boxes.JP.Enabled=$true;$boxes.NA.Enabled=$true;$boxes.EU.Enabled=$true;$boxes.DEU.Enabled=$false;$boxes.FRA.Enabled=$false
  foreach($language in $activeLanguages){
    $localLanguage=$language;$localBox=$boxes[$language]
    $localBox.Add_TextUpdate(({if($state.Syncing-or$state.IndividualCheck.Checked){return};$typed=[string]$localBox.Text;$state.Syncing=$true;try{foreach($target in $state.ActiveLanguages){if($target-ne$localLanguage){$state.Boxes[$target].Text=$typed}}}finally{$state.Syncing=$false}}.GetNewClosure()))
    $localBox.Add_TextChanged(({if($state.Syncing-or$state.IndividualCheck.Checked-or$localBox.Focused){return};$typed=[string]$localBox.Text;$state.Syncing=$true;try{foreach($target in $state.ActiveLanguages){if($target-ne$localLanguage){$state.Boxes[$target].Text=$typed}}}finally{$state.Syncing=$false}}.GetNewClosure()))
    $localBox.Add_SelectionChangeCommitted(({if($state.Syncing-or$state.IndividualCheck.Checked){return};$row=Get-DenpaSelectedNameRow $state $localLanguage $localBox;if($row){Sync-DenpaNameLanguageRow $state $row}}.GetNewClosure()))
    $localBox.Add_KeyDown(({if($_.KeyCode-ne[Windows.Forms.Keys]::Enter-or$state.Syncing-or$state.IndividualCheck.Checked){return};$row=Get-DenpaSelectedNameRow $state $localLanguage $localBox;if($row){Sync-DenpaNameLanguageRow $state $row;$_.SuppressKeyPress=$true}}.GetNewClosure()))
  }
  foreach($language in @('EU','DEU','FRA')){$localLanguage=$language;$checks[$language].Add_Click(({Set-DenpaEuLanguage $state $localLanguage}.GetNewClosure()))}
  $default=@($sorted.JP|Where-Object JP -eq $initialText|Select-Object -First 1);if($default.Count){Sync-DenpaNameLanguageRow $state $default[0]}else{Set-DenpaNameRawText $state $initialText}
  $state
}

function Set-DenpaNameLanguageLayout {
  param([object]$State,[Windows.Forms.Label]$PersonalityLabel,[Windows.Forms.ComboBox]$PersonalityBox)
  $PersonalityLabel.Location=New-Object Drawing.Point(680,51);$PersonalityBox.Location=New-Object Drawing.Point(730,46);$PersonalityBox.Size=New-Object Drawing.Size(112,27)
  # 各チェックボックスと入力欄の間に余白を取り、隣の言語欄とも重ならない配置にする。
  # 上下段の列を揃える。JPはDEU列、NAはFRA列と同じX座標を使う。
  $layout=@{JP=@(865,46,925);NA=@(1050,46,1110);EU=@(680,78,730);DEU=@(865,78,925);FRA=@(1050,78,1110)}
  foreach($language in $layout.Keys){$spec=$layout[$language];if($language-in@('JP','NA')){$State.Labels[$language].Location=New-Object Drawing.Point($spec[0],($spec[1]+5))}else{$State.Checks[$language].Location=New-Object Drawing.Point($spec[0],($spec[1]+3))};$State.Boxes[$language].Location=New-Object Drawing.Point($spec[2],$spec[1]);$State.Boxes[$language].Size=New-Object Drawing.Size(112,27)}
}

function Get-DenpaSelectedEuLanguage {
  param([object]$State)
  foreach($language in @('EU','DEU','FRA')){if($State.Checks[$language].Checked){return $language}}
  'EU'
}

function Get-DenpaNameForRegion {
  param([object]$State,[ValidateSet('JP','EU','NA')][string]$Region)
  $language=if($Region-eq'EU'){Get-DenpaSelectedEuLanguage $State}else{$Region}
  if(-not[string]::IsNullOrWhiteSpace($State.Boxes[$language].Text)){return [string]$State.Boxes[$language].Text}
  [string]$State.Boxes.JP.Text
}

function Get-DenpaCardDisplayName {
  param([object]$State)
  if($null-eq$State){return ''}
  $jp=[string]$State.Boxes.JP.Text
  $euLanguage=Get-DenpaSelectedEuLanguage $State
  $names=foreach($region in @('JP','NA',$euLanguage)){
    $value=[string]$State.Boxes[$region].Text
    if([string]::IsNullOrWhiteSpace($value)){$value=$jp}
    $value.Trim()
  }
  if(@($names).Count-eq0){return $jp.Trim()}
  $names -join ' / '
}
