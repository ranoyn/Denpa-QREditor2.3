# Local selected-image import only. No camera, external decoder, folder scan or network.
function Open-DenpaImportBitmap([string]$Path){
  if((Get-Item -LiteralPath $Path).Length-gt32MB){throw '画像は32MB以下にしてください。 / Maximum file size: 32 MB.'}
  try{$image=[Drawing.Image]::FromFile($Path);try{return New-Object Drawing.Bitmap($image)}finally{$image.Dispose()}}
  catch{
    # Windows' built-in image decoder can accept some JPEG metadata GDI+ rejects.
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    $stream=[IO.File]::OpenRead($Path);$memory=New-Object IO.MemoryStream
    try{
      $decoder=[Windows.Media.Imaging.BitmapDecoder]::Create($stream,[Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
      $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
      $encoder.Frames.Add($decoder.Frames[0]);$encoder.Save($memory);$memory.Position=0
      $image=[Drawing.Image]::FromStream($memory)
      try{return New-Object Drawing.Bitmap($image)}finally{$image.Dispose()}
    }finally{$memory.Dispose();$stream.Dispose()}
  }
}
function Set-DenpaImportedFace([string]$Game,$Imported,[bool]$IncludeName,$Context=$null){
  if($Imported.Game-ne[int]$Game.Substring(3)){throw '同じ作品のEditorで読み込んでください。 / Open the matching game editor.'}
  if(-not$Context){$Context=@{Editors=$script:editors;Modules=$script:editorModuleByGame;State=$state}}
  $info=$Context.Editors[$Game];$module=$Context.Modules[$Game];$sharedState=$Context.State
  if($Imported.Plain){
    if($global:DenpaNonoGuardEnabled-and$Imported.Parts['hair']-eq25-and$Imported.Parts['eyes']-eq36){throw 'ののガードが適用されています。この組み合わせは生成出来ません。'}
    $prior=$sharedState.Syncing;$sharedState.Syncing=$true
    try{
      & $module {
        param($source,$game)
        $before=Get-DenpaCurrentTemplate $game;$draft=Get-DenpaCurrentTemplate $game
        $o=$draft.SavedOptions
        if($game-eq'RPG1'){
          $aliases=@{hair='--hair';contour='--contour';brow='--eyebrow';eyes='--eyes';nose='--nose';mouth='--mouth';cheeks='--cheeks';glasses='--glasses';skin='--skin-color';hairColor='--hair-color';antenna='--antenna';head='--head-shape';body='--body-color'}
          foreach($key in $source.Parts.Keys){$draft.Fields[$aliases[$key]]=[string]$source.Parts[$key]}
          $draft.Fields['--antenna-appearance']=$draft.Fields['--antenna']
          $index=[Array]::IndexOf([object[]]$rpg1StatsValues,[object]$source.StatureValue)
          if($index-ge0){$draft.Fields['--stature']=[string]$index}
          $o.Region=$source.Language
        }else{
          foreach($key in $source.Fields.Keys){if($boxes.ContainsKey($key)){$draft.Fields[$key]=$source.Fields[$key]}}
          $o.edition=@{Index=@{JP=0;NA=1;EU=2}[$source.Language]}
          $o.Memo=$source.Memo;$o.PaintColor=$source.Paint
          $o.AdvancedQR=@{Level=$(if($source.Level-ge1-and$source.Level-le$(if($game-eq'RPG2'){99}else{199})){$source.Level}else{$null});Unknown=@{}}
          if($source.Date){$o.qrDate=@{Date=$source.Date;Checked=$true}}
          if($game-eq'RPG2'){
            $o.modeBox=@{Index=[int]$source.Special}
            if($source.Special){$index=[Array]::IndexOf([object[]]$rpg2ClaimSlotValues,[object]$source.Claim);if($index-lt0){throw 'Unsupported RPG2 claim ID.'};$o.claimSlotBox=@{Index=$index}}
            foreach($slot in @('neck','arm','back','feet','clothing')){
              $code='{0:X4}'-f$source.Equipment[$slot]
              if($slot-eq'clothing'-and$source.Equipment[$slot]-eq0){$code='0400'}
              $codes=Get-Variable -Name (@{neck='neckEquipmentCodes';arm='armEquipmentCodes';back='backEquipmentCodes';feet='feetEquipmentCodes';clothing='clothingCodes'}[$slot]) -ValueOnly
              $index=[Array]::IndexOf([object[]]$codes,[object]$code);if($index-lt0){throw ('Unsupported equipment: '+$slot+' '+$code)}
              $o[@{neck='neckBox';arm='armBox';back='backBox';feet='feetBox';clothing='clothingBox'}[$slot]]=@{Index=$index}
            }
          }else{
            $o.qrType=@{Index=[int]$source.Special}
            $index=-1;for($i=0;$i-lt$correctionCodes.Count;$i++){if([Convert]::ToInt32($correctionCodes[$i],16)-eq$source.Correction){$index=$i;break}}
            if($index-lt0){throw 'Unsupported correction value.'};$o.correctionBox=@{Index=$index}
            $index=[Array]::IndexOf([object[]]$monsterCodes,[object]('{0:X2}'-f$source.Monster));if($index-lt0){throw 'Unsupported captured monster.'};$o.capturedMonster=@{Index=$index}
            $o.SourceLevel=@{Checked=($source.Level-ge1-and$source.Level-le199);Value=$(if($source.Level-ge1-and$source.Level-le199){$source.Level}else{199})}
            $o.Bonuses=@{};foreach($key in $source.Bonuses.Keys){$value=$source.Bonuses[$key];if($value-gt$statBonusControls[$key].Maximum){throw ('Stat exceeds editor range: '+$key)};$o.Bonuses[$key]=$value}
            $o.Equipment=@{};foreach($slot in @('neck','arm','back','feet','clothing')){
              $key=if($slot-eq'clothing'){'--clothing-equipment'}else{'--'+$slot+'-equipment'}
              $id=$source.Equipment[$slot];if($id-ne0-and-not($rpg3EquipmentRows[$key]|Where-Object{[int]$_.internal_id-eq$id})){throw ('Unsupported equipment: '+$slot)};$o.Equipment[$key]=$id
            }
            if($source.Special){
              $index=[Array]::IndexOf([object[]]$specialCodeValues,[object]('{0:X2}'-f$source.Claim));if($index-lt0){throw 'Unsupported RPG3 claim ID.'};$o.extendedSpecialCode=@{Index=$index};$o.jewelQuantity=@{Value=$source.Quantity}
              $o.Rewards=@();for($i=0;$i-lt4;$i++){$index=0;if($source.Rewards[$i]-ne0){$index=1+[Array]::IndexOf([object[]]$script:extendedRewardCodes[$i],[object]('{0:X4}'-f$source.Rewards[$i]));if($index-le0){throw ('Unsupported item/decoration slot '+$i)}};$o.Rewards+=,$index}
            }
          }
        }
        $draft.Names[$source.Language]=$source.Name
        # Preserve the user's filter/synchronization choices captured in SavedOptions.
        # Apply-DenpaSavedTemplate temporarily disables them while assigning fields,
        # then restores the captured values rather than permanently clearing them.
        try{
          Apply-DenpaSavedTemplate $draft $game
          # Appearance may intentionally differ from ability; keep the stored field.
          if($game-eq'RPG3'-and$source.Fields.ContainsKey('--antenna-appearance')){Set-Rpg3TemplateCode '--antenna-appearance' $source.Fields['--antenna-appearance']}
        }catch{Apply-DenpaSavedTemplate $before $game;throw}
      } $Imported $Game
    }finally{$sharedState.Syncing=$prior}
    if($Game-ne'RPG1'){foreach($key in $info.Map.Keys){if($key-ne'name'-and$info.Map[$key]-is[Windows.Forms.ComboBox]){$sharedState.Shared[$key]=$info.Map[$key].SelectedIndex}}}
    return
  }
  $keys=@('hair','eyes','brow','nose','mouth','cheeks','glasses','skin','hairColor','contour')
  $targetParts=@{};foreach($key in $keys){$targetParts[$key]=[int]$Imported.Parts[$key]}
  if($Game-eq'RPG1'){$targetParts.skin=& $module {param($value) if($value-lt0-or$value-ge$rpg1SkinStoredToUi.Count){throw 'Unsupported RPG1 skin.'};[int]$rpg1SkinStoredToUi[$value]} $targetParts.skin}
  foreach($key in $keys){$box=$info.Map[$key];$value=$targetParts[$key];if(-not$box-or$value-lt0-or$value-ge$box.Items.Count){throw ('現在の選択肢にないパーツです。 / Part unavailable: '+$key)}}
  if($global:DenpaNonoGuardEnabled-and$Imported.Parts['hair']-eq25-and$Imported.Parts['eyes']-eq36){throw 'ののガードが適用されています。この組み合わせは生成出来ません。'}
  $before=@{};foreach($key in $keys){$before[$key]=$info.Map[$key].SelectedIndex}
  $nameSnapshot=$null
  if($IncludeName){$nameSnapshot=& $module {param($lang) if(-not$nameLanguage-or-not$nameLanguage.Boxes.ContainsKey($lang)){throw 'Name language is unavailable.'};[pscustomobject]@{Box=$nameLanguage.Boxes[$lang];Text=$nameLanguage.Boxes[$lang].Text;State=$nameLanguage}} $Imported.Language}
  $prior=$sharedState.Syncing;$sharedState.Syncing=$true
  try{
    # Avoid triggering the guard on an intermediate mixture of old/new parts.
    $info.Map.hair.SelectedIndex=0;$info.Map.eyes.SelectedIndex=0
    foreach($key in $keys){$info.Map[$key].SelectedIndex=$targetParts[$key]}
    foreach($key in $keys){if($info.Map[$key].SelectedIndex-ne$targetParts[$key]){throw ('既存の同期・候補制限で変更されました。設定を確認してください。 / Existing filter changed: '+$key)}}
    if($IncludeName){$oldSync=$nameSnapshot.State.Syncing;$nameSnapshot.State.Syncing=$true;try{$nameSnapshot.Box.Text=$Imported.Name}finally{$nameSnapshot.State.Syncing=$oldSync}}
  }catch{
    $failure=$_;$info.Map.hair.SelectedIndex=0;$info.Map.eyes.SelectedIndex=0
    foreach($key in $keys){$info.Map[$key].SelectedIndex=$before[$key]}
    if($nameSnapshot){$oldSync=$nameSnapshot.State.Syncing;$nameSnapshot.State.Syncing=$true;try{$nameSnapshot.Box.Text=$nameSnapshot.Text}finally{$nameSnapshot.State.Syncing=$oldSync}}
    throw $failure
  }finally{$sharedState.Syncing=$prior}
  # Share only the imported face fields, not equipment, dates, stats or other state.
  if($Game-ne'RPG1'){foreach($key in $keys){$sharedState.Shared[$key]=$info.Map[$key].SelectedIndex}}
}
function Show-DenpaQrFaceImport([string]$Game,$Context){
  $form=$Context.Form
  $english=$env:DENPA_EDITOR_LANGUAGE-eq'English'
  $file=New-Object Windows.Forms.OpenFileDialog
  $file.Filter='Images (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp';$file.Multiselect=$false
  $file.Title=if($english){'Choose one screenshot or QR image'}else{'ゲーム内スクショ・QR単体・Editor画像を1枚選択'}
  $bitmap=$null;$cropWindow=$null;$confirmation=$null
  try{
    if($file.ShowDialog($form)-ne'OK'){return}
    $bitmap=& $Context.OpenAction $file.FileName
    if($bitmap.Width-gt4096-or$bitmap.Height-gt4096){throw '画像の一辺は4096px以下にしてください。 / Maximum image dimension: 4096 px.'}
    $cropWindow=New-Object DenpaQrVerification.QrCropForm($bitmap,$english)
    if($cropWindow.ShowDialog($form)-ne'OK'){return}
    $form.UseWaitCursor=$true
    try{$payload=[DenpaQrVerification.Core]::ReadQrImage($bitmap,$cropWindow.Crop);$imported=[DenpaQrVerification.Core]::ReadFace($payload)}finally{$form.UseWaitCursor=$false}
    if($imported.Game-ne[int]$Game.Substring(3)){throw ('RPG'+$imported.Game+'のQRです。同じ作品のEditorで読み込んでください。 / Select the matching game editor.')}
    $confirmation=New-Object Windows.Forms.Form;$confirmation.Text=if($english){'Confirm QR import'}else{'QRの取り込み確認'}
    $confirmation.ClientSize=New-Object Drawing.Size(450,390);$confirmation.StartPosition='CenterParent';$confirmation.FormBorderStyle='FixedDialog';$confirmation.MaximizeBox=$false;$confirmation.MinimizeBox=$false
    $description=New-Object Windows.Forms.TextBox;$description.Multiline=$true;$description.ReadOnly=$true;$description.ScrollBars='Vertical';$description.SetBounds(15,15,420,310)
    $labels=@{hair='髪';eyes='目';brow='眉';nose='鼻';mouth='口';cheeks='頬';glasses='顔装備';skin='肌色';hairColor='髪色';contour='輪郭'}
    $lines=@(('RPG'+$imported.Game+' / '+$imported.Language),$imported.Name)
    foreach($key in @('hair','contour','brow','eyes','nose','mouth','cheeks','glasses','skin','hairColor')){$lines+=($(if($english){$key}else{$labels[$key]})+': '+('{0:D2}'-f$imported.Parts[$key]))}
    foreach($key in @('antenna','head','body')){if($imported.Parts.ContainsKey($key)){$lines+=$key+': '+$imported.Parts[$key]}}
    foreach($key in @('--antenna','--head-shape','--body-color','--stature','--personality')){if($imported.Fields.ContainsKey($key)){$lines+=$key+': '+$imported.Fields[$key]}}
    foreach($key in $imported.Bonuses.Keys){$lines+=$key+': '+$imported.Bonuses[$key]}
    foreach($key in $imported.Equipment.Keys){$lines+=$key+': '+('{0:X4}'-f$imported.Equipment[$key])}
    if($imported.Memo){$lines+='メモ / Memo: '+$imported.Memo};if($imported.Date){$lines+='日付 / Date: '+$imported.Date}
    if($imported.Special){$lines+='特典ID / ID: '+('{0:X2}'-f$imported.Claim);$lines+='ジュエル / Jewels: '+$imported.Quantity}
    $description.Text=$lines-join"`r`n";$confirmation.Controls.Add($description)
    $apply=New-Object Windows.Forms.Button;$apply.Text=if($english){'Apply'}else{'反映'};$apply.DialogResult='OK';$apply.SetBounds(160,340,130,32);$confirmation.Controls.Add($apply)
    $cancel=New-Object Windows.Forms.Button;$cancel.Text=if($english){'Cancel'}else{'キャンセル'};$cancel.DialogResult='Cancel';$cancel.SetBounds(305,340,130,32);$confirmation.Controls.Add($cancel);$confirmation.CancelButton=$cancel
    if($confirmation.ShowDialog($form)-eq'OK'){& $Context.ApplyAction $Game $imported $true $Context}
  }catch{$message=if($english){$_.Exception.Message}else{"読み取り、または反映ができませんでした。画像の場合はQRと白い余白だけを選び直してください。`r`n"+$_.Exception.Message};[void][Windows.Forms.MessageBox]::Show($message,'QR Import','OK','Error')}
  finally{if($confirmation){$confirmation.Dispose()};if($cropWindow){$cropWindow.Dispose()};if($bitmap){$bitmap.Dispose()};$file.Dispose();$form.UseWaitCursor=$false}
}
