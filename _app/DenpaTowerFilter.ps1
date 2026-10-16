function Sort-DenpaJapaneseNames {
  param([object[]]$Names)
  [string[]]$sorted=@($Names|ForEach-Object{[string]$_})
  [Array]::Sort($sorted,[StringComparer]::Create([Globalization.CultureInfo]::GetCultureInfo('ja-JP'),$false))
  return @($sorted)
}

function Get-DenpaTowerSelectedCode {
  param([hashtable]$Controls,[hashtable]$CodeTables,[string]$Key)
  $control=$Controls[$Key]
  if($null-eq$control-or$control.SelectedIndex-lt0){return -1}
  $codes=$CodeTables[$Key]
  if($null-eq$codes-or$control.SelectedIndex-ge$codes.Count){return -1}
  return [Convert]::ToInt32([string]$codes[$control.SelectedIndex],16)
}

function Get-DenpaTowerPossibleRows {
  param([object]$TowerData,[hashtable]$Controls,[hashtable]$CodeTables,[hashtable]$FieldTableMap,[hashtable]$ValueOffsets)
  if($null-eq$TowerData){return @()}
  $possible=@(0..8)
  foreach($key in $FieldTableMap.Keys){
    $value=Get-DenpaTowerSelectedCode $Controls $CodeTables $key
    if($value-lt0){return @()}
    if($null-ne$ValueOffsets-and$ValueOffsets.ContainsKey($key)){$value+=[int]$ValueOffsets[$key]}
    $tableName=[string]$FieldTableMap[$key]
    $tableProperty=$TowerData.tables.PSObject.Properties[$tableName]
    if($null-eq$tableProperty){return @()}
    $rows=@($tableProperty.Value.rows)
    $possible=@($possible|Where-Object{
      $row=[int]$_
      $row-lt$rows.Count-and(@($rows[$row]) -contains $value)
    })
    if($possible.Count-eq0){break}
  }
  return @($possible)
}

function Repair-DenpaTowerCombination {
  param(
    [object]$TowerData,[hashtable]$Controls,[hashtable]$CodeTables,
    [hashtable]$FieldTableMap,[string]$PreferredKey
  )
  if($null-eq$TowerData){return -1}
  $bestRow=0;$bestScore=[int]::MinValue
  foreach($row in 0..8){
    $score=0
    foreach($key in $FieldTableMap.Keys){
      $value=Get-DenpaTowerSelectedCode $Controls $CodeTables $key
      $tableName=[string]$FieldTableMap[$key]
      $tableRows=@($TowerData.tables.PSObject.Properties[$tableName].Value.rows)
      if($value-ge0-and(@($tableRows[$row]) -contains $value)){$score+=if($key-eq$PreferredKey){20}else{1}}
    }
    if($score-gt$bestScore){$bestScore=$score;$bestRow=$row}
  }
  foreach($key in $FieldTableMap.Keys){
    $value=Get-DenpaTowerSelectedCode $Controls $CodeTables $key
    $tableName=[string]$FieldTableMap[$key]
    $allowed=@($TowerData.tables.PSObject.Properties[$tableName].Value.rows[$bestRow])
    if($allowed-contains$value){continue}
    foreach($candidate in $allowed){
      $code='{0:X2}'-f[int]$candidate
      $index=[Array]::IndexOf([object[]]$CodeTables[$key],[object]$code)
      if($index-ge0){$Controls[$key].SelectedIndex=$index;break}
    }
  }
  return [int]$bestRow
}

function Get-DenpaTowerPersonality {
  param(
    [object]$TowerData,[hashtable]$Controls,[hashtable]$CodeTables,
    [object[]]$PersonalityFields,[int]$ClassA
  )
  $allowed=if($ClassA-eq0){@(1,2,3,5,6)}elseif($ClassA-eq2){@(0,4)}else{@(0..6)}
  $scores=New-Object int[] 7
  $winner=if($ClassA-eq0){1}else{0}
  foreach($field in $PersonalityFields){
    $value=Get-DenpaTowerSelectedCode $Controls $CodeTables ([string]$field.Key)
    $recordIndex=[int]$field.Base+$value
    if($value-lt0-or$recordIndex-lt0-or$recordIndex-ge$TowerData.personalityWeights.rows.Count){return -1}
    $weights=@($TowerData.personalityWeights.rows[$recordIndex])
    $previous=@($scores)
    $next=New-Object int[] 7
    $bestScore=0;$best=0
    for($personality=0;$personality-lt7;$personality++){
      if($allowed-notcontains$personality){continue}
      $score=[int]$previous[$personality]+[int]$weights[$personality]
      $next[$personality]=$score
      if($score-gt$bestScore-or($score-eq$bestScore-and[int]$previous[$best]-lt[int]$previous[$personality])){$bestScore=$score;$best=$personality}
    }
    $unchanged=$true
    foreach($score in $next){if([int]$score-ne[int]$previous[0]){$unchanged=$false;break}}
    $winner=if($unchanged){if($ClassA-eq0){1}else{0}}else{$best}
    $scores=$next
  }
  return [int]$winner
}

function Get-DenpaTowerCandidates {
  param(
    [object]$TowerData,[hashtable]$Controls,[hashtable]$CodeTables,
    [hashtable]$FieldTableMap,[object[]]$PersonalityFields,[hashtable]$ValueOffsets
  )
  $rows=@(Get-DenpaTowerPossibleRows $TowerData $Controls $CodeTables $FieldTableMap $ValueOffsets)
  $nameIds=New-Object 'System.Collections.Generic.HashSet[int]'
  $personalityIds=New-Object 'System.Collections.Generic.HashSet[int]'
  foreach($row in $rows){
    foreach($nameId in @($TowerData.name.rows[[int]$row])){[void]$nameIds.Add([int]$nameId)}
    $personality=Get-DenpaTowerPersonality $TowerData $Controls $CodeTables $PersonalityFields ([Math]::Floor([int]$row/3))
    if($personality-ge0){[void]$personalityIds.Add($personality)}
  }
  return [pscustomobject]@{
    Rows=@($rows)
    NameIds=@($nameIds|Sort-Object)
    PersonalityIds=@($personalityIds|Sort-Object)
  }
}

function Set-DenpaTowerCandidateChoices {
  param(
    [bool]$Enabled,[object]$Candidates,[Windows.Forms.ComboBox]$NameBox,[string[]]$AllNames,
    [Windows.Forms.ComboBox]$PersonalityBox,[hashtable]$CodeTables,[string]$PersonalityKey,
    [string[]]$AllPersonalityNames,[string[]]$AllPersonalityCodes
  )
  $currentName=$NameBox.Text
  $currentPersonalityCode=if($PersonalityBox.SelectedIndex-ge0-and$PersonalityBox.SelectedIndex-lt$CodeTables[$PersonalityKey].Count){[string]$CodeTables[$PersonalityKey][$PersonalityBox.SelectedIndex]}else{''}
  $names=if($Enabled){@($Candidates.NameIds|Where-Object{$_-ge0-and$_-lt$AllNames.Count}|ForEach-Object{$AllNames[[int]$_]})}else{@($AllNames)}
  $names=@(Sort-DenpaJapaneseNames $names)
  $personalityIds=if($Enabled){@($Candidates.PersonalityIds)}else{@(0..($AllPersonalityNames.Count-1))}
  $personalityNames=@($personalityIds|ForEach-Object{$AllPersonalityNames[[int]$_]})
  $personalityCodes=@($personalityIds|ForEach-Object{$AllPersonalityCodes[[int]$_]})
  $NameBox.BeginUpdate();try{$NameBox.Items.Clear();if($names.Count){[void]$NameBox.Items.AddRange([object[]]$names)};if($names-contains$currentName){$NameBox.Text=$currentName}elseif($names.Count){$NameBox.SelectedIndex=0}else{$NameBox.Text=''}}finally{$NameBox.EndUpdate()}
  $PersonalityBox.BeginUpdate();try{$PersonalityBox.Items.Clear();if($personalityNames.Count){[void]$PersonalityBox.Items.AddRange([object[]]$personalityNames)};$CodeTables[$PersonalityKey]=@($personalityCodes);$index=[Array]::IndexOf([object[]]$personalityCodes,[object]$currentPersonalityCode);$PersonalityBox.SelectedIndex=if($index-ge0){$index}elseif($personalityNames.Count){0}else{-1}}finally{$PersonalityBox.EndUpdate()}
}
