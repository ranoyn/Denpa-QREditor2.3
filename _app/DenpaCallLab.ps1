# Optional research-institute selection; shared only by the verification RPG1/2 editors.
function Get-DenpaCallLabSelection {
  if($script:callLab -and $script:callLab.Check.Checked -and $script:callLab.Combo.SelectedIndex -ge 0){return [int]$script:callLab.Codes[$script:callLab.Combo.SelectedIndex]}
  return -1
}
function Get-DenpaCallLabCardText {
  if((Get-DenpaCallLabSelection)-ge0){return [string]$script:callLab.Combo.Text}
  return ''
}
function Update-DenpaCallLab {
  $s=$script:callLab;if(-not$s-or$s.Updating){return};$s.Updating=$true
  try {
    $previous=-1;if($s.Combo.SelectedIndex-ge0-and$s.Combo.SelectedIndex-lt$s.Codes.Count){$previous=[int]$s.Codes[$s.Combo.SelectedIndex]}
    $body=if($s.Game-eq1){[DenpaQrVerification.Core]::CallLabBodyFromStature1($boxes['--stature'].SelectedIndex)}else{Get-Rpg2Int '--stature'}
    $ant=0;$person=0;if($s.Game-eq2){$ant=Get-Rpg2Int '--antenna';$person=Get-Rpg2Int '--personality'}
    $s.Codes=@([DenpaQrVerification.Core]::CallLabChoices($s.Game,$body,$ant,$person))
    if($s.Game-eq2-and$s.Codes-notcontains$previous){
      if($ant-eq0-and$previous-in@(2,7,8)){$previous=1}
      elseif($previous-eq7-and$s.Codes-contains8){$previous=8}
      elseif($previous-eq8-and$s.Codes-contains7){$previous=7}
    }
    $s.Combo.Items.Clear();foreach($code in $s.Codes){[void]$s.Combo.Items.Add($s.Names[[int]$code])}
    $s.Check.Enabled=$s.Codes.Count-gt0
    if($s.Codes.Count){$index=[Array]::IndexOf([object[]]$s.Codes,[object]$previous);$s.Combo.SelectedIndex=[Math]::Max(0,$index)}else{$s.Check.Checked=$false;[void]$s.Combo.Items.Add($(if($person-in@(100,101)){$s.Blocked}else{$s.None}));$s.Combo.SelectedIndex=0}
    $s.Combo.Enabled=$s.Check.Checked-and$s.Check.Enabled
    if($s.Target){$next=[DenpaQrVerification.Core]::CallLabNext($ant);$s.Target.Items.Clear();$text=if($person-in@(100,101)){$s.Blocked}elseif($next-gt0){$s.AntNames[$next]}else{$s.None};[void]$s.Target.Items.Add($text);$s.Target.SelectedIndex=0}
  } finally {$s.Updating=$false}
}
function Set-DenpaCallLabLanguage($Names,$AntNames,[string]$Language) {
  if(-not$script:callLab){return};$script:callLab.Names=$Names
  if($AntNames){$script:callLab.AntNames=$AntNames}
  $script:callLab.None=if($Language-eq'English'){'None'}else{'なし'}
  $script:callLab.Blocked=if($Language-eq'English'){'Cannot be called'}else{'呼び出し不可'}
  Update-DenpaCallLab
}
function New-DenpaCallLab([int]$Game) {
  $picture=if($Game-eq1){$face}else{$facePreview};$x=$picture.Left;$y=$picture.Bottom+16;$width=$picture.Width
  # Match the caption of RPG3's doping-fruit panel in the unified editor.
  if($env:DENPA_EDITOR_EMBED-eq'1'){$x=383;$y=370}
  $check=New-Object Windows.Forms.CheckBox;$check.Name='callLabCheck';$check.Text='RPG3 補正選択';$check.Location=New-Object Drawing.Point($x,$y);$check.Size=New-Object Drawing.Size($width,24);$check.Font=New-Object Drawing.Font('Yu Gothic UI',9)
  $combo=New-Object Windows.Forms.ComboBox;$combo.Name='callLabAbility';$combo.DropDownStyle='DropDownList';$combo.Location=New-Object Drawing.Point($x,($y+29));$combo.Size=New-Object Drawing.Size($width,27)
  $script:callLab=[pscustomobject]@{Game=$Game;Check=$check;Combo=$combo;Codes=@();Updating=$false;Names=@{1='HPマスター！';2='APマスター！';3='ちからもち！';4='がんじょう！';5='しゅんそく！';6='かいひめいじん！';7='アンテナへんか！';8='そうじゅく！'};AntNames=@();None='なし';Blocked='呼び出し不可';Target=$null}
  $form.Controls.Add($check);$form.Controls.Add($combo)
  if($Game-eq2){
    $script:callLab.AntNames=@($antennaNames|ForEach-Object{$_-replace'\(未定義\d+\)$',''})
    $label=New-Object Windows.Forms.Label;$label.Text='アンテナへんか';$label.Location=New-Object Drawing.Point($x,($y+64));$label.Size=New-Object Drawing.Size($width,23);$form.Controls.Add($label)
    $target=New-Object Windows.Forms.ComboBox;$target.Name='callLabAntenna';$target.DropDownStyle='DropDownList';$target.Enabled=$false;$target.Location=New-Object Drawing.Point($x,($y+89));$target.Size=New-Object Drawing.Size($width,27);$form.Controls.Add($target);$script:callLab.Target=$target
  }
  $changed={if($script:callLab.Updating){return};Update-DenpaCallLab;if($script:callLab.Game-eq1){Queue-Rpg1QrUpdate}else{& $markDirty}}
  $check.Add_CheckedChanged($changed)
  $combo.Add_SelectedIndexChanged({if($script:callLab.Updating){return};if($script:callLab.Game-eq1){Queue-Rpg1QrUpdate}else{& $markDirty}})
  foreach($key in @('--stature','--antenna','--personality')){if($boxes.ContainsKey($key)){$boxes[$key].Add_SelectedIndexChanged({Update-DenpaCallLab})}}
  Update-DenpaCallLab
}
