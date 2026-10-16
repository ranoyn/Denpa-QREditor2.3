# Run on Windows with .NET Framework 4.x installed. No Node.js is required.
$ErrorActionPreference='Stop'
$releaseRoot=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
if(-not(Test-Path -LiteralPath $compiler)){throw '.NET Framework C# compiler was not found.'}
$nativeRoot=Join-Path $releaseRoot '_app/native'
& $compiler /nologo /target:library /platform:anycpu /optimize+ /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Web.Extensions.dll ('/out:'+(Join-Path $nativeRoot 'DenpaQrBackend.dll')) (Join-Path $nativeRoot 'DenpaQrCore.cs') (Join-Path $nativeRoot 'DenpaQrImage.cs') (Join-Path $nativeRoot 'DenpaCallLab.cs') (Join-Path $nativeRoot 'DenpaQrRead.cs')
if($LASTEXITCODE-ne0){throw 'QR backend build failed.'}
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ('/win32icon:'+(Join-Path $releaseRoot '_app/app-icon.ico')) ('/out:'+(Join-Path $releaseRoot 'Denpa QREditor2.3 1.0.1.exe')) (Join-Path $PSScriptRoot 'DenpaQREditorLauncher.cs')
if($LASTEXITCODE-ne0){throw 'Launcher build failed.'}
Write-Output 'BUILD_OK Denpa QREditor2.3 1.0.1'
