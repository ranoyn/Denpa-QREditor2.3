function New-Rpg3TwoDColorMatrix([Drawing.Color]$TargetColor, [Drawing.Color]$BaseColor, [switch]$Flat) {
  $matrix = New-Object Drawing.Imaging.ColorMatrix
  if ($Flat) {
    $matrix.Matrix00 = 0.0; $matrix.Matrix11 = 0.0; $matrix.Matrix22 = 0.0
    $matrix.Matrix40 = $TargetColor.R / 255.0
    $matrix.Matrix41 = $TargetColor.G / 255.0
    $matrix.Matrix42 = $TargetColor.B / 255.0
  } else {
    $matrix.Matrix00 = ($TargetColor.R / [Math]::Max(1.0, $BaseColor.R))
    $matrix.Matrix11 = ($TargetColor.G / [Math]::Max(1.0, $BaseColor.G))
    $matrix.Matrix22 = ($TargetColor.B / [Math]::Max(1.0, $BaseColor.B))
  }
  $matrix.Matrix33 = 1.0
  $matrix.Matrix44 = 1.0
  $matrix
}

function New-Rpg3TwoDTintedBitmap([string]$Path, [string]$TargetHex, [string]$BaseHex = '#FFFFFF', [switch]$Flat) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $source = [Drawing.Image]::FromFile($Path)
  try {
    $result = New-Object Drawing.Bitmap($source.Width, $source.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($result)
    $attributes = New-Object Drawing.Imaging.ImageAttributes
    try {
      $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceOver
      $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
      $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $target = [Drawing.ColorTranslator]::FromHtml($TargetHex)
      $base = [Drawing.ColorTranslator]::FromHtml($BaseHex)
      $matrix = New-Rpg3TwoDColorMatrix $target $base -Flat:$Flat
      $attributes.SetColorMatrix($matrix)
      $destination = New-Object Drawing.Rectangle(0, 0, $source.Width, $source.Height)
      $graphics.DrawImage($source, $destination, 0, 0, $source.Width, $source.Height, [Drawing.GraphicsUnit]::Pixel, $attributes)
    } finally {
      $attributes.Dispose()
      $graphics.Dispose()
    }
    $result
  } finally {
    $source.Dispose()
  }
}

function Add-Rpg3TwoDLayer([Drawing.Graphics]$Graphics, [string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $source = [Drawing.Image]::FromFile($Path)
  try {
    $destination = New-Object Drawing.Rectangle(0, 0, 600, 600)
    $Graphics.DrawImage($source, $destination, 0, 0, $source.Width, $source.Height, [Drawing.GraphicsUnit]::Pixel)
  } finally { $source.Dispose() }
}

function Add-Rpg3TwoDOffsetLayer([Drawing.Graphics]$Graphics, [string]$Path, [int]$OffsetY) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $source = [Drawing.Image]::FromFile($Path)
  try {
    $destination = New-Object Drawing.Rectangle(0, $OffsetY, 600, 600)
    $Graphics.DrawImage($source, $destination, 0, 0, $source.Width, $source.Height, [Drawing.GraphicsUnit]::Pixel)
  } finally { $source.Dispose() }
}

function Add-Rpg3TwoDTintedLayer([Drawing.Graphics]$Graphics, [string]$Path, [string]$TargetHex, [string]$BaseHex = '#FFFFFF', [switch]$Flat) {
  $layer = New-Rpg3TwoDTintedBitmap $Path $TargetHex $BaseHex -Flat:$Flat
  if ($null -eq $layer) { return }
  try {
    $destination = New-Object Drawing.Rectangle(0, 0, 600, 600)
    $Graphics.DrawImage($layer, $destination, 0, 0, $layer.Width, $layer.Height, [Drawing.GraphicsUnit]::Pixel)
  } finally { $layer.Dispose() }
}

function Add-Rpg3TwoDStripedLayer([Drawing.Graphics]$Graphics, [string]$Path, [string]$PrimaryHex, [string]$SecondaryHex) {
  $primary = New-Rpg3TwoDTintedBitmap $Path $PrimaryHex
  if ($null -eq $primary) { return }
  $secondary = New-Rpg3TwoDTintedBitmap $Path $SecondaryHex
  try {
    $bandHeight = 24
    for ($y = 0; $y -lt 600; $y += $bandHeight) {
      $source = if (([int]($y / $bandHeight) % 2) -eq 0) { $primary } else { $secondary }
      $clip = New-Object Drawing.Rectangle(0, $y, 600, [Math]::Min($bandHeight, 600 - $y))
      $Graphics.SetClip($clip, [Drawing.Drawing2D.CombineMode]::Replace)
      $destination = New-Object Drawing.Rectangle(0, 0, 600, 600)
      $Graphics.DrawImage($source, $destination, 0, 0, $source.Width, $source.Height, [Drawing.GraphicsUnit]::Pixel)
    }
    $Graphics.ResetClip()
  } finally {
    if ($null -ne $secondary) { $secondary.Dispose() }
    $primary.Dispose()
  }
}

function Get-DenpaTwoDPreviewPartCode([Windows.Forms.ComboBox]$Control, [int]$Code) {
  if($Control.SelectedIndex-lt0-or$Control.Text-match'\u672A\u5B9A\u7FA9|undefined'){return -1}
  return $Code
}

function Get-Rpg3TwoDPartPath([string]$Folder, [int]$Code) {
  Join-Path (Join-Path $script:rpg3TwoDAssetRoot $Folder) ('{0:D2}.png' -f $Code)
}

function Get-Rpg3TwoDColoredPartPath([string]$Folder, [int]$Code, [int]$ColorCode) {
  $partFolder = Join-Path (Join-Path $script:rpg3TwoDAssetRoot $Folder) ('{0:D2}' -f $Code)
  Join-Path $partFolder ('{0:D2}.png' -f $ColorCode)
}

function Get-Rpg3TwoDAntennaYOffset([int]$HeadCode) {
  if ($null -eq $script:rpg3TwoDAntennaHeadOffsets) {
    $script:rpg3TwoDAntennaHeadOffsets = @{}
    $offsetPath = Join-Path (Join-Path $script:rpg3TwoDAssetRoot 'antennas') 'head-y-offsets.json'
    if (Test-Path -LiteralPath $offsetPath) {
      try {
        $configuration = Get-Content -LiteralPath $offsetPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($property in $configuration.offsets.PSObject.Properties) {
          $script:rpg3TwoDAntennaHeadOffsets[[int]$property.Name] = [int]$property.Value
        }
      } catch {
        $script:rpg3TwoDAntennaHeadOffsets = @{}
      }
    }
  }
  if ($script:rpg3TwoDAntennaHeadOffsets.ContainsKey($HeadCode)) {
    return [int]$script:rpg3TwoDAntennaHeadOffsets[$HeadCode]
  }
  return 0
}

function Get-Rpg3TwoDAntennaArtworkYOffset([int]$AntennaCode) {
  if ($null -eq $script:rpg3TwoDAntennaArtworkOffsets) {
    $script:rpg3TwoDAntennaArtworkOffsets = @{}
    $offsetPath = Join-Path (Join-Path $script:rpg3TwoDAssetRoot 'antennas') 'antenna-y-offsets.json'
    if (Test-Path -LiteralPath $offsetPath) {
      try {
        $configuration = Get-Content -LiteralPath $offsetPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($property in $configuration.offsets.PSObject.Properties) {
          $script:rpg3TwoDAntennaArtworkOffsets[[int]$property.Name] = [int]$property.Value
        }
      } catch {
        $script:rpg3TwoDAntennaArtworkOffsets = @{}
      }
    }
  }
  if ($script:rpg3TwoDAntennaArtworkOffsets.ContainsKey($AntennaCode)) {
    return [int]$script:rpg3TwoDAntennaArtworkOffsets[$AntennaCode]
  }
  return 0
}

function New-DenpaTwoDPreviewPng {
  param(
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [switch]$Transparent,
    [int]$HeadCode,
    [int]$OutlineCode,
    [int]$HairCode,
    [int]$BrowCode,
    [int]$EyeCode,
    [int]$NoseCode,
    [int]$MouthCode,
    [int]$CheekCode,
    [int]$GlassesCode,
    [int]$AntennaCode,
    [Parameter(Mandatory=$true)][string]$BodyHex,
    [AllowNull()][string]$SecondaryBodyHex,
    [Parameter(Mandatory=$true)][string]$SkinHex,
    [Parameter(Mandatory=$true)][string]$HairHex,
    [int]$ArtHairColorCode
  )
  if (-not (Test-Path -LiteralPath $script:rpg3TwoDAssetRoot)) { throw 'RPG3 2D preview assets were not found.' }

  $canvas = New-Object Drawing.Bitmap(600, 600, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [Drawing.Graphics]::FromImage($canvas)
  try {
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    if (-not $Transparent) { $graphics.Clear([Drawing.Color]::FromArgb(255, 244, 248, 255)) }

    $bodyPath = Join-Path $script:rpg3TwoDAssetRoot 'body-base.png'
    $headPath = Get-Rpg3TwoDPartPath 'heads' $headCode
    # Antennae sit behind the body/head so the head naturally hides their base.
    # Missing artwork is intentionally ignored until a replacement PNG is supplied.
    $antennaPath = Get-Rpg3TwoDPartPath 'antennas' $antennaCode
    $antennaOffsetY = (Get-Rpg3TwoDAntennaYOffset $headCode) + (Get-Rpg3TwoDAntennaArtworkYOffset $antennaCode)
    Add-Rpg3TwoDOffsetLayer $graphics $antennaPath $antennaOffsetY
    foreach ($path in @($bodyPath, $headPath)) {
      if ($secondaryBodyHex) { Add-Rpg3TwoDStripedLayer $graphics $path $bodyHex $secondaryBodyHex } else { Add-Rpg3TwoDTintedLayer $graphics $path $bodyHex }
    }

    Add-Rpg3TwoDTintedLayer $graphics (Get-Rpg3TwoDPartPath 'outlines' $outlineCode) $skinHex '#F8DBC7'
    Add-Rpg3TwoDLayer $graphics (Get-Rpg3TwoDPartPath 'cheeks' $cheekCode)
    Add-Rpg3TwoDLayer $graphics (Get-Rpg3TwoDPartPath 'eyes' $eyeCode)
    Add-Rpg3TwoDLayer $graphics (Get-Rpg3TwoDPartPath 'brows' $browCode)
    Add-Rpg3TwoDLayer $graphics (Get-Rpg3TwoDPartPath 'noses' $noseCode)
    if ($mouthCode -ge 25 -and $mouthCode -le 27) {
      $coloredMouthPath = Get-Rpg3TwoDColoredPartPath 'mouths-colored' $mouthCode $artHairColorCode
      if (Test-Path -LiteralPath $coloredMouthPath) {
        Add-Rpg3TwoDLayer $graphics $coloredMouthPath
      } else {
        Add-Rpg3TwoDTintedLayer $graphics (Get-Rpg3TwoDPartPath 'mouths' $mouthCode) $hairHex '#FFFFFF'
      }
    } else {
      Add-Rpg3TwoDLayer $graphics (Get-Rpg3TwoDPartPath 'mouths' $mouthCode)
    }

    if ($hairCode -eq 28) {
      # Hair 28 is intentionally identical for every hair color.
      Add-Rpg3TwoDLayer $graphics (Get-Rpg3TwoDPartPath 'hairs-common' $hairCode)
    } elseif ($hairCode -gt 0) {
      $coloredHairPath = Get-Rpg3TwoDColoredPartPath 'hairs-colored' $hairCode $artHairColorCode
      if (Test-Path -LiteralPath $coloredHairPath) {
        Add-Rpg3TwoDLayer $graphics $coloredHairPath
      } else {
        Add-Rpg3TwoDTintedLayer $graphics (Get-Rpg3TwoDPartPath 'hairs' $hairCode) $hairHex '#FFFFFF'
      }
    }
    Add-Rpg3TwoDLayer $graphics (Get-Rpg3TwoDPartPath 'glasses' $glassesCode)

    $outputDirectory = Split-Path -Parent $OutputPath
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
    $canvas.Save($OutputPath, [Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $canvas.Dispose()
  }
  $OutputPath
}

function New-Rpg3TwoDPreviewPng([string]$OutputPath, [switch]$Transparent) {
  # These colors were sampled from the supplied, author-approved body/hair color references.
  $bodyPalette = @('#282828','#D7090C','#30D0F0','#079927','#F26522','#FCFD30','#0E24FF','#FFFFFF')
  $bodyPairs = @(@(1,2),@(1,3),@(1,4),@(1,5),@(1,6),@(1,7),@(2,3),@(2,4),@(2,5),@(2,6),@(2,7),@(3,4),@(3,5),@(3,6),@(3,7),@(4,5),@(4,6),@(4,7),@(5,6),@(5,7),@(6,7))
  $skinPalette = @('#FFE7D2','#FFD2AF','#FFBEAA','#CB8964','#9D6044','#673C2E')
  $hairPalette = @('#282828','#FFFFFF','#804507','#CD902A','#942A00','#FFDD20','#0059FF','#09A600','#A128FF','#FF6E80','#F75700','#F00011','#BBBBBB','#BBBBBB','#BBBBBB','#BBBBBB')

  $bodyCode = [Convert]::ToInt32((Get-FieldCode $boxes['--body-color']), 16)
  $skinCode = [Convert]::ToInt32((Get-FieldCode $boxes['--skin-color']), 16)
  $hairColorCode = [Convert]::ToInt32((Get-FieldCode $boxes['--hair-color']), 16)
  $secondaryBodyHex = $null
  if ($bodyCode -ge 8 -and $bodyCode -le 28) {
    $pair = $bodyPairs[$bodyCode - 8]
    $bodyHex = $bodyPalette[$pair[0]]
    $secondaryBodyHex = $bodyPalette[$pair[1]]
  } elseif ($bodyCode -lt 8) {
    $bodyHex = $bodyPalette[$bodyCode]
  } elseif ($bodyCode -eq 29) {
    $bodyHex = '#500096'
  } elseif ($bodyCode -eq 30) {
    $bodyHex = '#6E7F7F'
  } elseif ($bodyCode -eq 31) {
    $bodyHex = '#A27A01'
  } else {
    $bodyHex = '#FF82AC'
  }

  New-DenpaTwoDPreviewPng -OutputPath $OutputPath -Transparent:$Transparent `
    -HeadCode ([Convert]::ToInt32((Get-FieldCode $boxes['--head-shape']),16)) `
    -OutlineCode ([Convert]::ToInt32((Get-FieldCode $boxes['--contour']),16)) `
    -HairCode ([Convert]::ToInt32((Get-FieldCode $boxes['--hair']),16)) `
    -BrowCode ([Convert]::ToInt32((Get-FieldCode $boxes['--eyebrow']),16)) `
    -EyeCode ([Convert]::ToInt32((Get-FieldCode $boxes['--eyes']),16)) `
    -NoseCode ([Convert]::ToInt32((Get-FieldCode $boxes['--nose']),16)) `
    -MouthCode ([Convert]::ToInt32((Get-FieldCode $boxes['--mouth']),16)) `
    -CheekCode ([Convert]::ToInt32((Get-FieldCode $boxes['--cheeks']),16)) `
    -GlassesCode ([Convert]::ToInt32((Get-FieldCode $boxes['--glasses']),16)) `
    -AntennaCode ([Convert]::ToInt32((Get-FieldCode $boxes['--antenna']),16)) `
    -BodyHex $bodyHex -SecondaryBodyHex $secondaryBodyHex `
    -SkinHex $(if($skinCode-lt$skinPalette.Count){$skinPalette[$skinCode]}else{$hairPalette[[Math]::Min(($skinCode-$skinPalette.Count),12)]}) `
    -HairHex ($hairPalette[[Math]::Min($hairColorCode,$hairPalette.Count-1)]) `
    -ArtHairColorCode ([Math]::Min($hairColorCode,12))
}
