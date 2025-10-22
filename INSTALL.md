# girlschan_app - クイックスタートガイド

Apple Developer アカウントなしで、macOS にインストール・実行できます。

## 🚀 最も簡単な方法（推奨）

### 方法A：DMG ファイルを使用（最も推奨）

1. **DMG ファイルをダウンロード**
   - リリースページから `girlschan_app.dmg` をダウンロード

2. **インストール**
   - ダウンロードした `girlschan_app.dmg` をダブルクリック
   - 開いたウィンドウで `girlschan_app.app` を Applications フォルダにドラッグ

3. **起動**
   - Launchpad または Applications フォルダから起動

### 方法B：.app ファイルを直接実行

1. **ZIP ファイルをダウンロード**
   - リリースページから `girlschan_app.app.zip` をダウンロード
   - ZIP を解凍

2. **初回実行時の対処**
   ```bash
   # ターミナルを開いて実行
   xattr -rd com.apple.quarantine ~/Downloads/girlschan_app.app
   open ~/Downloads/girlschan_app.app
   ```

3. **永続的にインストール（オプション）**
   ```bash
   # Applications フォルダにコピー
   cp -r ~/Downloads/girlschan_app.app /Applications/
   ```

## ⚠️ セキュリティ警告が出た場合

Apple Developer アカウントなしでビルドしているため、初回起動時に警告が表示される場合があります。

### 対処方法1：Finder から開く

1. アプリケーションを **右クリック**
2. 「情報を見る」をクリック
3. 「このまま開く」ボタンをクリック

### 対処方法2：ターミナルから実行

```bash
# セキュリティ属性をクリア
xattr -rd com.apple.quarantine /Applications/girlschan_app.app

# 起動
open /Applications/girlschan_app.app
```

### 対処方法3：ターミナルから直接起動

```bash
/Applications/girlschan_app.app/Contents/MacOS/girlschan_app
```

## 📋 システム要件

- **OS**: macOS 10.11（El Capitan）以上
- **推奨**: macOS 12.0（Monterey）以上
- **CPU**: Intel または Apple Silicon（M1/M2 など）
- **メモリ**: 2GB 以上
- **ディスク**: 100MB 以上の空き容量

## 🔧 自分でビルドする場合

### 要件
- Xcode Command Line Tools
- Flutter SDK（3.0 以上）

### ビルド手順

```bash
# リポジトリをクローン
git clone https://github.com/kaeruko/girlschan_app.git
cd girlschan_app

# 依存関係をインストール
flutter pub get

# ビルド
flutter build macos --release

# アプリが完成
ls -lh build/macos/Build/Products/Release/girlschan_app.app
```

### インストールスクリプトを使用

```bash
# スクリプトから選択
bash scripts/install.sh
```

## 📦 DMG ファイルの作成（開発者向け）

ビルド後、DMG ファイルを作成できます：

```bash
bash scripts/create_dmg.sh
```

## 🐛 トラブルシューティング

### Q: 「ファイルが破損している可能性があります」と表示される

**A:** 以下のコマンドで解決します：
```bash
xattr -rd com.apple.quarantine /Applications/girlschan_app.app
```

### Q: アプリが起動しない

**A:** ターミナルから直接実行してエラーを確認：
```bash
/Applications/girlschan_app.app/Contents/MacOS/girlschan_app
```

### Q: M1/M2 Mac で動作しない

**A:** このアプリは Intel および Apple Silicon の両方に対応しています。ターミナルから実行してエラーを確認してください。

## 📝 詳細情報

より詳しい情報は `README.md` を参照してください。

## 🤝 サポート

問題が発生した場合は、GitHub Issues で報告してください。

---

**Apple Developer アカウントがなくても、これで macOS アプリとして配布・使用できます！**
