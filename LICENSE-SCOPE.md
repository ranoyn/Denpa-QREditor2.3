# MITライセンスの適用範囲 / MIT License scope

## 対象 / Covered

MITライセンスは、`_app/*.ps1`、`_app/native/*.cs`、`src/*.cs`、`src/*.ps1`に含まれる自作コードと、そこから生成したexe／DLLの対応部分に適用します。条件は[LICENSE](LICENSE)をご覧ください。

The MIT License applies to the original code in `_app/*.ps1`, `_app/native/*.cs`, `src/*.cs`, and `src/*.ps1`, and the corresponding portions of executables and DLLs built from that code. See [LICENSE](LICENSE) for its terms.

## 対象外 / Not covered

- `_app/assets`の画像・フォント・カード素材。
- `_app/ui-logos`、`_app/app-icon.ico`。
- `_app/data`の名称・候補・対応表などのデータ。
- `_app/Denpatemplates`の登録人物・特典等の入力データ。
- ソース内に含まれるゲーム固有鍵・ゲーム由来データ・第三者由来の素材や表現。

Image assets, fonts, card artwork, UI logos, the app icon, name and lookup tables, character and present template data, game-specific keys, game-derived data, and other third-party materials are not covered by the MIT License for the original code.

フォント・画像素材には、それぞれのライセンス・許諾条件が適用されます。素材を加工・結合するコードがMIT対象でも、生成した画像素材がMIT対象になるわけではありません。[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)もご覧ください。

Fonts and image assets are subject to their own licenses and permissions. MIT licensing of code that processes or combines artwork does not place the resulting artwork under MIT. See also [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
