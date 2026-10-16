# UI options share the existing item catalog; ID 0000 means unequipped.
$rpg3MemoLabel=New-Object Windows.Forms.Label
$rpg3MemoLabel.Name='rpg3MemoLabel';$rpg3MemoLabel.Text='メモ';$rpg3MemoLabel.AutoSize=$true
$rpg3MemoLabel.Location=New-Object Drawing.Point(5,270)
$statBonusGroup.Controls.Add($rpg3MemoLabel)
$rpg3MemoBox=New-Object Windows.Forms.TextBox
$rpg3MemoBox.Name='rpg3MemoBox';$rpg3MemoBox.MaxLength=16
$rpg3MemoBox.Location=New-Object Drawing.Point(5,296);$rpg3MemoBox.Size=New-Object Drawing.Size(240,27)
$statBonusGroup.Controls.Add($rpg3MemoBox)
$statBonusGroup.Height=330
$rpg3PaintPanel=New-Object Windows.Forms.Panel
$rpg3PaintPanel.Name='rpg3PaintPanel';$rpg3PaintPanel.Location=New-Object Drawing.Point(388,670);$rpg3PaintPanel.Size=New-Object Drawing.Size(360,32)
$form.Controls.Add($rpg3PaintPanel)
$rpg3PaintLabel=New-Object Windows.Forms.Label
$rpg3PaintLabel.Name='rpg3PaintLabel';$rpg3PaintLabel.AutoSize=$true;$rpg3PaintLabel.Location=New-Object Drawing.Point(0,4)
$rpg3PaintPanel.Controls.Add($rpg3PaintLabel)
$rpg3PaintBox=New-Object Windows.Forms.ComboBox
$rpg3PaintBox.Name='rpg3PaintBox';$rpg3PaintBox.DropDownStyle='DropDownList'
$rpg3PaintBox.Location=New-Object Drawing.Point(120,0);$rpg3PaintBox.Size=New-Object Drawing.Size(220,27);$rpg3PaintBox.DropDownWidth=260
$rpg3PaintPanel.Controls.Add($rpg3PaintBox)
function Set-Rpg3PaintLanguage([string]$Language){
 $selected=[Math]::Max(0,$rpg3PaintBox.SelectedIndex)
 $basePaint=@($itemCatalogRows|Where-Object{$_.name-match'^ペイントざい'}|Select-Object -First 1)
 $rpg3PaintLabel.Text=if($Language-eq'English'-and$basePaint.Count-and$naItemMap.ContainsKey([string]$basePaint[0].reward_hex)){[string]$naItemMap[[string]$basePaint[0].reward_hex]}else{'ペイントざい'}
 $colors=@{'黒'='Black';'赤'='Red';'水色'='Light Blue';'緑'='Green';'オレンジ'='Orange';'黄'='Yellow';'青'='Blue';'白'='White';'紫'='Purple';'銀'='Silver';'金'='Gold';'桃'='Pink'}
 $names=@($(if($Language-eq'English'){'None'}else{'(なし)'}))
 foreach($name in $bodyColorNames){
  if($Language-eq'English'){$names+=(@($name-split'／'|ForEach-Object{$colors[$_]})-join' / ')}else{$names+=$name}
 }
 $rpg3PaintBox.BeginUpdate();try{$rpg3PaintBox.Items.Clear();[void]$rpg3PaintBox.Items.AddRange([object[]]$names);$rpg3PaintBox.SelectedIndex=$selected}finally{$rpg3PaintBox.EndUpdate()}
}
Set-Rpg3PaintLanguage $env:DENPA_EDITOR_LANGUAGE
$rpg3EquipmentGroup=New-Object Windows.Forms.Panel
$rpg3EquipmentGroup.Name='rpg3EquipmentGroup';$rpg3EquipmentGroup.Text='装備'
$rpg3EquipmentGroup.Location=New-Object Drawing.Point(680,665);$rpg3EquipmentGroup.Size=New-Object Drawing.Size(555,100)
$form.Controls.Add($rpg3EquipmentGroup)
$rpg3EquipmentTitle=New-Object Windows.Forms.Label
$rpg3EquipmentTitle.Name='rpg3EquipmentTitle';$rpg3EquipmentTitle.Text='装備';$rpg3EquipmentTitle.AutoSize=$true
$rpg3EquipmentTitle.Location=New-Object Drawing.Point(10,0);$rpg3EquipmentGroup.Controls.Add($rpg3EquipmentTitle)
$rpg3EquipmentBoxes=[ordered]@{};$rpg3EquipmentRows=@{}
$rpg3EquipmentSpecs=@(
 @('--clothing-equipment','服装備',1081,1170),@('--neck-equipment','首装備',801,878),
 @('--back-equipment','背中装備',891,958),@('--arm-equipment','腕装備',971,1020),
 @('--feet-equipment','足装備',1031,1068)
)
for($i=0;$i-lt5;$i++){
 $spec=$rpg3EquipmentSpecs[$i];$key=$spec[0]
 $rows=@($itemCatalogRows|Where-Object{[int]$_.internal_id-ge$spec[2]-and[int]$_.internal_id-le$spec[3]}|Sort-Object {[int]$_.internal_id})
 $rpg3EquipmentRows[$key]=$rows
 $label=New-Object Windows.Forms.Label;$label.Text=$spec[1];$label.AutoSize=$true
 $x=10+185*($i%3);$y=30+39*[int][Math]::Floor($i/3)
 $label.Location=New-Object Drawing.Point($x,$y);$rpg3EquipmentGroup.Controls.Add($label)
 $box=New-Object Windows.Forms.ComboBox;$box.Name='rpg3'+$key.Replace('-','');$box.DropDownStyle='DropDownList'
 $box.Location=New-Object Drawing.Point(($x+50),($y-3));$box.Size=New-Object Drawing.Size(125,27);$box.DropDownWidth=260
 [void]$box.Items.Add('(なし)');[void]$box.Items.AddRange([object[]]@($rows|ForEach-Object{$_.name}));$box.SelectedIndex=0
 $rpg3EquipmentGroup.Controls.Add($box);$rpg3EquipmentBoxes[$key]=$box
}
function Update-Rpg3ExtrasControls {
 $editable=$qrType.SelectedIndex-ne5
 $rpg3MemoBox.Enabled=$editable-and$qrType.SelectedIndex-ne0
 $rpg3MemoLabel.Text=if($env:DENPA_EDITOR_LANGUAGE-eq'English'){'Memo'}else{'メモ'}
 foreach($box in $rpg3EquipmentBoxes.Values){$box.Enabled=$editable}
 $rpg3PaintBox.Enabled=$editable
}
function Get-Rpg3ExtrasArguments {
 '--paint-color';$(if($rpg3PaintBox.SelectedIndex-le0){'FF'}else{'{0:X2}'-f($rpg3PaintBox.SelectedIndex-1)})
 foreach($key in $rpg3EquipmentBoxes.Keys){
  $i=$rpg3EquipmentBoxes[$key].SelectedIndex
  if($i-lt0){throw 'Select equipment from the catalog.'}
  $code=if($i-eq0){'0000'}else{'{0:X4}'-f[int]$rpg3EquipmentRows[$key][$i-1].internal_id}
  $key;$code
 }
 if($qrType.SelectedIndex-ne0){'--memo';[string]$rpg3MemoBox.Text}
}
function Set-Rpg3EquipmentLanguage([string]$Language){
 Set-Rpg3PaintLanguage $Language
 foreach($key in $rpg3EquipmentBoxes.Keys){
  $box=$rpg3EquipmentBoxes[$key];$i=$box.SelectedIndex;$rows=$rpg3EquipmentRows[$key]
  $codes=@($rows|ForEach-Object{$_.reward_hex});$names=@($rows|ForEach-Object{$_.name})
  $box.BeginUpdate();try{$box.Items.Clear();[void]$box.Items.Add($(if($Language-eq'English'){'None'}else{'(なし)'}));[void]$box.Items.AddRange([object[]]@(Get-Rpg3LocalizedRewardNames $codes $names $Language));$box.SelectedIndex=$i}finally{$box.EndUpdate()}
 }
 Update-Rpg3ExtrasControls
}
$qrType.Add_SelectedIndexChanged({Update-Rpg3ExtrasControls})
Update-Rpg3ExtrasControls
