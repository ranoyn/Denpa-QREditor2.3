# Reads one prebuilt artwork sheet when the viewer is opened.
function Show-DenpaPartsTable([string]$ApplicationRoot,[Windows.Forms.Form]$Owner,[bool]$English,[string]$Game){
  if(-not('DenpaPartsCatalogue.PartsWindow'-as[type])){
    $source=Join-Path $ApplicationRoot 'native/DenpaPartsTable.cs'
    Add-Type -TypeDefinition ([IO.File]::ReadAllText($source)) -ReferencedAssemblies System.Drawing,System.Windows.Forms
  }
  $existing=@([Windows.Forms.Application]::OpenForms|Where-Object{$_.Name-eq'facePartsTableWindow'-and-not$_.IsDisposed})
  if($existing.Count){$existing[0].Activate();return}
  $assets=Join-Path $ApplicationRoot 'assets/rpg3-2d'
  $Owner.UseWaitCursor=$true
  try{$window=New-Object DenpaPartsCatalogue.PartsWindow($assets,$English,$Game)}finally{$Owner.UseWaitCursor=$false}
  if($Owner.Icon){$window.Icon=$Owner.Icon}
  if($env:DENPA_PARTS_TABLE_TEST-eq'1'){return $window}
  $window.Show($Owner)
}
