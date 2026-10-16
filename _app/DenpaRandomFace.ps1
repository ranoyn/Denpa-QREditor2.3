# Randomize appearance parts only; never change name, antenna, body or reward data.
function Set-DenpaRandomFace([string]$Game){
  $maximum=switch($Game){
    'RPG1' {@{'--hair'=23;'--contour'=8;'--eyebrow'=7;'--eyes'=31;'--nose'=15;'--mouth'=31;'--cheeks'=7;'--glasses'=15}}
    'RPG2' {@{'--hair'=31;'--face-shape'=8;'--eyebrow'=15;'--eyes'=39;'--nose'=23;'--mouth'=31;'--cheeks'=7;'--glasses'=15}}
    'RPG3' {@{'--hair'=39;'--contour'=11;'--eyebrow'=19;'--eyes'=47;'--nose'=31;'--mouth'=39;'--cheeks'=7;'--glasses'=23}}
    default {throw 'Unknown game.'}
  }
  # Tower filtering can indirectly alter the name/personality. Turn it off first.
  $towerCombinationCheck.Checked=$false
  $syncControl=if($Game-eq'RPG3'){$legitimateFaceCheck}else{$faceSyncCheck}
  $restoreSync=$syncControl.Checked;$syncControl.Checked=$false
  try{
    foreach($key in $maximum.Keys){
      $candidates=@()
      for($i=0;$i-lt$boxes[$key].Items.Count;$i++){
        $code=switch($Game){
          'RPG1' {$i}
          'RPG2' {[Convert]::ToInt32($codesByKey[$key][$i],16)}
          'RPG3' {[Convert]::ToInt32($fieldCodesByKey[$key][$i],16)}
        }
        if($code-le$maximum[$key]){$candidates+=$i}
      }
      if($candidates.Count-eq0){throw ('No valid face values for '+$key)}
      $boxes[$key].SelectedIndex=$candidates[(Get-Random -Minimum 0 -Maximum $candidates.Count)]
    }
  }finally{
    # If enabled, preserve hair/contour compatibility rather than a random mismatch.
    $syncControl.Checked=$restoreSync
  }
}

function Show-DenpaDebugPlaceholder([string]$Game){
  if($script:debugPlaceholder-and-not$script:debugPlaceholder.IsDisposed){$script:debugPlaceholder.Activate();return}
  $english=($env:DENPA_EDITOR_LANGUAGE-eq'English')
  $window=New-Object Windows.Forms.Form
  $window.Text=$(if($english){'Debug Mode'}else{'デバッグモード'})+' - '+$Game
  $window.ClientSize=New-Object Drawing.Size(460,150);$window.StartPosition='CenterParent'
  $window.Font=New-Object Drawing.Font('Yu Gothic UI',10)
  $label=New-Object Windows.Forms.Label;$label.Location=New-Object Drawing.Point(20,20)
  $label.Size=New-Object Drawing.Size(420,100)
  $label.Text=if($english){'Not implemented yet. Editing all QR values from 00 to FF will be added later. No QR settings are changed by this window.'}else{'まだ未実装です。00～FFで全項目を編集する機能は、後ほど追加します。この画面ではQR設定は変更されません。'}
  $window.Controls.Add($label);$script:debugPlaceholder=$window
  $window.Show($form)
}
