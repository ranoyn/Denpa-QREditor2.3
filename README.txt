Denpa QREditor2.3 1.0.1

電波人間のRPG・電波人間のRPG2・電波人間のRPG3向けの非公式ツールです。
任天堂・ジニアス・ソノリティによる公式製品ではありません。

This is an unofficial tool for THE DENPAMEN, THE DENPAMEN2, and THE DENPAMEN3.
It is not an official product of Nintendo or Genius Sonority.

本ツールの使用によってセーブデータの破損、進行不能、予期しない挙動、その他の不具合が発生した場合でも、作者は責任を負いません。
ゲームへ読み込む前に必ずセーブデータをバックアップし、自己責任で使用してください。

The author accepts no responsibility for save data corruption, loss of game progress, unexpected behavior, or any other issues resulting from the use of this tool.
Always back up your save data before importing anything into the game, and use this tool at your own risk.

プレビューおよび顔パーツ表には、Tropic’s Radiocrew（Picrew）の画像素材を使用しています。
素材の権利・利用条件については、リンク先の案内をご確認ください。
これらの素材は、本ツールの自作コードに適用するMITライセンスの対象外です。
https://picrew.me/ja/image_maker/1920251

The previews and Face Parts Table use image assets from Tropic’s Radiocrew (Picrew).
Please check the linked page for information about the rights to these assets and their terms of use.
These assets are not covered by the MIT License that applies to the original code of this tool.
https://picrew.me/ja/image_maker/1920251

Tropic’s Radiocrew由来の画像素材の二次配布は許可されていません。
また、これらの画像素材を含んだ状態で本ツールを二次配布することも許可されていません。
改変版などを配布する場合は、該当する画像素材を含めないようにしてください。

Redistribution of image assets originating from Tropic’s Radiocrew is not permitted.
Redistribution of this tool with these image assets included is also not permitted.
If you distribute a modified version or similar package, do not include these image assets.

自作コードはMITライセンスです。
素材・フォント・ゲーム由来データは別扱いです。
README.md、LICENSE、LICENSE-SCOPE.md、THIRD_PARTY_NOTICES.mdを参照してください。

The original code is licensed under the MIT License.
Assets, fonts, and game-derived data are handled separately.
See README.md, LICENSE, LICENSE-SCOPE.md, and THIRD_PARTY_NOTICES.md.

動作確認環境：Windows 10／11。
Windows PowerShell 5.1と.NET Frameworkを使用します。
ZIPをすべて展開し、exeと_appを同じ場所に置いてください。
exe／DLLは未署名です。起動時に_app内のZone.Identifierを解除し、子PowerShellに-ExecutionPolicy Bypassを指定します。Windows全体の実行ポリシーは変更しません。

Tested on Windows 10 and Windows 11.
This tool uses Windows PowerShell 5.1 and the .NET Framework.
Extract the entire ZIP file and keep the executable and the _app folder in the same directory.
The executable and DLL files are unsigned. At startup, the launcher removes Zone.Identifier download markers from files under _app and starts its child PowerShell process with -ExecutionPolicy Bypass. It does not change the system-wide execution policy.

本ツールでは、ゲーム内で使用されているすべての値や組み合わせを完全に確認できているわけではありません。
Editor上で選択できない値や範囲外の数値を使用する場合は、デバッグモードから直接入力してください。

Not all values and combinations used in the games have been fully verified in this tool.
To use values that are unavailable in the Editor or outside its selectable ranges, enter them directly in Debug Mode.

名前リストから名前を選択した場合は、対応する他言語版の名前も自動的に入力されます。

When you select a name from the name list, its corresponding names in other language versions are also filled in automatically.

特典IDは、一度読み込むと使用済みになります。
使用済みになった特典IDでは、その後は特典を受け取ることができません。

A Present ID is marked as used once it has been redeemed.
Once a Present ID has been used, you cannot receive another present with that ID.

QR Editor3（電波人間のRPG3 QREditor）注意事項

QR Editor3 (THE DENPAMEN3 QREditor) — Important Notes

「主人公」の性格を持つ電波人間は、仲間にすると「さよならをする」「パーティから外す」ができません。

Once recruited, a Denpa Man with the "Protagonist" personality cannot be dismissed or removed from the party.

「あかり」「みちる」「ひのわ」の性格を持つ電波人間は、仲間にすると「さよならをする」ができません。

Denpa Men with the "Crystal," "Rick," or "Mary" personality cannot be dismissed once recruited.

これらの電波人間を読み込む場合はご注意ください。

Please use caution when importing these Denpa Men.

電波人間のRPG3では、通常QRから入手する「そうび」は、同じQRを使用することで繰り返し獲得できます。

In THE DENPAMEN3, equipment obtained from a Normal QR can be acquired repeatedly by using the same QR code.

特典QRに「そうび」を設定した場合は、設定した特典IDが未使用の場合に限り受け取ることができます。

Equipment included in a Present QR can only be received if the specified Present ID has not been used.

不具合報告・ご連絡は、Discord Server または X までお願いします。

For bug reports or other inquiries, please contact us through Discord Server or X.

Discord Server
https://discord.gg/ndf

X
https://x.com/ranobye_
