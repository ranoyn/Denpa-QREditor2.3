function ConvertTo-DenpaTemplateValue {
  param([object]$Value)
  if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) { return $Value }
  if ($Value -is [Collections.IDictionary]) {
    $table = @{}
    foreach ($key in $Value.Keys) { $table[[string]$key] = ConvertTo-DenpaTemplateValue $Value[$key] }
    return $table
  }
  if ($Value -is [Management.Automation.PSCustomObject]) {
    $table = @{}
    foreach ($property in $Value.PSObject.Properties) { $table[$property.Name] = ConvertTo-DenpaTemplateValue $property.Value }
    return $table
  }
  if ($Value -is [Collections.IEnumerable]) {
    return @($Value | ForEach-Object { ConvertTo-DenpaTemplateValue $_ })
  }
  return $Value
}

. (Join-Path $PSScriptRoot 'DenpaTemplateSave.ps1')
. (Join-Path $PSScriptRoot 'DenpaRandomFace.ps1')

function Import-DenpaTemplateCatalog {
  param(
    [Parameter(Mandatory=$true)][string]$ApplicationRoot,
    [Parameter(Mandatory=$true)][ValidateSet('RPG1','RPG2','RPG3')][string]$Game
  )
  $directory = Join-Path (Join-Path $ApplicationRoot 'Denpatemplates') $Game
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) { return @() }
  $templates = @()
  foreach ($file in @(Get-ChildItem -LiteralPath $directory -Filter '*.json' -File | Sort-Object Name)) {
    try {
      $decoded = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
      $template = ConvertTo-DenpaTemplateValue $decoded
      if ([int]$template.formatVersion -ne 1) { throw 'formatVersion must be 1.' }
      if ([string]::IsNullOrWhiteSpace([string]$template.Name)) { throw 'Name is required.' }
      if (-not ($template.Fields -is [Collections.IDictionary])) { throw 'Fields is required.' }
      if ([string]::IsNullOrWhiteSpace([string]$template.Label)) { $template.Label = [string]$template.Name }
      if (-not $template.ContainsKey('Order')) { $template.Order = 9999 }
      $template['_sourceDirectory'] = $directory
      $template['_sourceFile'] = $file.FullName
      $templates += $template
    } catch {
      [Diagnostics.Debug]::WriteLine("Denpa template skipped: $($file.FullName): $($_.Exception.Message)")
    }
  }
  return @($templates | Sort-Object @{Expression={
    $label=[string]$_.Label
    if($label-match'[\uFF08(]\u516C\u5F0F[\uFF09)]$'){1}elseif($label-match'[\uFF08(]\u30B9\u30C8\u30FC\u30EA\u30FC(?:RPG[23])?[\uFF09)]$'){2}elseif($label-match'[\uFF08(]\u4E3B\u4EBA\u516C[\uFF09)]$'){3}else{0}
  }}, @{Expression={
    if([string]$_.Label-match'[\uFF08(]\u516C\u5F0F[\uFF09)]$'){
      if($Game-eq'RPG2'){if($_.ContainsKey('Claim')){return [int]$_.Claim};return -1}
      if($Game-eq'RPG3'-and$_.ContainsKey('Special')){return [Convert]::ToInt32([string]$_.Special,16)}
    }
    return [int]$_.Order
  }}, @{Expression={ [int]$_.Order }}, @{Expression={ [string]$_.Label }})
}

function Set-DenpaTemplateNames {
  param([object]$State,[Collections.IDictionary]$Template)
  $row=@($State.Rows|Where-Object JP -eq $Template.Name|Select-Object -First 1)
  if($row.Count){Sync-DenpaNameLanguageRow $State $row[0]}else{Set-DenpaNameRawText $State ([string]$Template.Name)}
  $State.Syncing=$true
  try{
    if($Template.ContainsKey('Names')){foreach($language in $Template.Names.Keys){$State.Boxes[$language].Text=[string]$Template.Names[$language]}}
  }finally{$State.Syncing=$false}
}
