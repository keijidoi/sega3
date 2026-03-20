# SEGA Mark III Emulator

A Sega Master System (Mark III) emulator built with Flutter and Dart.

セガ・マークIII / マスターシステム エミュレータ。Flutter/Dart で開発されています。

---

## Features / 機能

- **Z80 CPU emulation** - Full Zilog Z80 CPU core implementation / Z80 CPU コアの完全実装
- **VDP (Video Display Processor)** - TMS9918A-derived VDP rendering with sprites, tiles, and scrolling / スプライト、タイル、スクロール対応の VDP レンダリング
- **PSG Audio** - SN76489 Programmable Sound Generator emulation / SN76489 PSG サウンドエミュレーション
- **Virtual gamepad** - On-screen D-pad and button controls / 画面上の仮想ゲームパッド
- **Save states** - Save and load emulator state at any time / いつでもセーブ・ロード可能なステートセーブ
- **ROM file loading** - Load ROMs from device storage / 端末ストレージからROMファイルを読み込み
- **Cross-platform** - Runs on Android (primary target) / Android をメインターゲットとしたクロスプラットフォーム対応

## Screenshots / スクリーンショット

<!-- TODO: Add screenshots -->
*Screenshots coming soon / スクリーンショットは準備中です*

## Supported ROM Formats / 対応ROMフォーマット

| Format | Description |
|--------|-------------|
| `.sms` | Sega Master System ROMs / セガ・マスターシステム ROM |
| `.sg`  | SG-1000 ROMs / SG-1000 ROM |

## Target Games / 対象ゲーム

The following classic titles are primary targets for compatibility:

以下のクラシックタイトルの互換性を主な目標としています：

- **Alex Kidd in Miracle World** - アレックスキッドのミラクルワールド
- **Hang-On** - ハングオン
- **Fantasy Zone** - ファンタジーゾーン
- **Shinobi** - 忍 -SHINOBI-

## Build / ビルド方法

### Prerequisites / 前提条件

- Flutter SDK 3.10 or later / Flutter SDK 3.10 以降
- Android SDK

### Build APK / APK ビルド

```bash
flutter pub get
flutter build apk
```

The built APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

ビルドされた APK は `build/app/outputs/flutter-apk/app-release.apk` に出力されます。

### Run in debug mode / デバッグモードで実行

```bash
flutter run
```

## Project Structure / プロジェクト構成

```
lib/
  ├── cpu/          # Z80 CPU emulation / Z80 CPUエミュレーション
  ├── vdp/          # Video Display Processor / ビデオディスプレイプロセッサ
  ├── psg/          # Programmable Sound Generator / サウンドジェネレータ
  ├── memory/       # Memory mapping / メモリマッピング
  └── ui/           # Flutter UI and virtual gamepad / UI・仮想ゲームパッド
```

## License / ライセンス

This project is licensed under the MIT License.

このプロジェクトは MIT ライセンスの下で公開されています。

```
MIT License

Copyright (c) 2025 sega3

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
