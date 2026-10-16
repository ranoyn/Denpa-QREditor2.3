# In-process verification backend. No Node.js launch or silent fallback.
. (Join-Path $PSScriptRoot 'DenpaAdvancedQr.ps1')
. (Join-Path $PSScriptRoot 'DenpaDebugQr.ps1')
$backendAssembly=Join-Path $PSScriptRoot 'native/DenpaQrBackend.dll'
if(-not('DenpaQrVerification.Core'-as[type])) {
  if(-not(Test-Path -LiteralPath $backendAssembly)){throw ([regex]::Unescape('QR\u51e6\u7406\u306b\u5fc5\u8981\u306a\u5185\u90e8\u30d5\u30a1\u30a4\u30eb\u304c\u898b\u3064\u304b\u308a\u307e\u305b\u3093\u3002'))}
  Add-Type -Path $backendAssembly
}
[DenpaQrVerification.Core]::Initialize($PSScriptRoot)
function Invoke-DenpaQrBackend {
  param([int]$Game,[string[]]$Arguments)
  try {
    $result=[DenpaQrVerification.Core]::Run($Game,$Arguments)
    $global:LASTEXITCODE=0
    return $result
  } catch {
    $global:LASTEXITCODE=2
    $detail=if($_.Exception.InnerException){$_.Exception.InnerException.Message}else{$_.Exception.Message}
    throw $detail
  }
}
