# がるちゃんアプリ (girlschan_app)

Flutter で開発された macOS ネイティブアプリケーションです。Apple Developer アカウントなしで簡単にインストール・実行できます。

## 📱 アプリケーション情報

- **対応OS**: macOS 10.11 以上
- **対応アーキテクチャ**: Intel Mac（x86_64）、Apple Silicon（arm64）
- **ビルドツール**: Flutter 3.35.6
- **ビルドサイズ**: 約 44MB

## 🚀 インストール方法

### 方法1：最も簡単（推奨）- .app を直接実行

1. **ビルド済みアプリケーションをダウンロード**
   - リリースページから `girlschan_app.app` をダウンロード

2. **アプリケーションを実行**
   ```bash
   # ターミナルから実行する場合
   open /path/to/girlschan_app.app
   ```
   
   または、Finder で `girlschan_app.app` をダブルクリック

### 方法2：DMG ファイルでインストール（推奨）

1. **DMG ファイルを取得**
   - リリースページから `girlschan_app.dmg` をダウンロード

2. **インストール**
   - ダウンロードした `girlschan_app.dmg` をダブルクリック
   - マウントされたボリュームから `girlschan_app.app` を Applications フォルダにドラッグ
   - Launchpad または Applications フォルダから起動

### 方法3：ソースコードからビルド

**要件:**
- Xcode Command Line Tools がインストール済み
- Flutter SDK（バージョン 3.0 以上）

**ビルド手順:**

```bash
# リポジトリをクローン
git clone https://github.com/kaeruko/girlschan_app.git
cd girlschan_app

# 依存関係をインストール
flutter pub get

# macOS アプリをビルド
flutter build macos --release

# ビルド済みアプリケーションの位置
# build/macos/Build/Products/Release/girlschan_app.app
```

ビルド後、`build/macos/Build/Products/Release/girlschan_app.app` をアプリケーションフォルダにコピーして使用できます。

## ⚠️ 重要：セキュリティ警告について

Apple Developer アカウントがないため、このアプリケーションは **署名されていない** または **自己署名** です。

### 初回実行時の対処方法

**macOS が「ファイルが破損している可能性があります」と表示する場合:**

1. **Finder で実行を試みた場合**
   - アプリケーションを右クリック
   - 「情報を見る」をクリック
   - 「このまま開く」をクリック

2. **ターミナルから実行**
   ```bash
   # セキュリティ警告を迂回して実行
   xattr -rd com.apple.quarantine /Applications/girlschan_app.app
   open /Applications/girlschan_app.app
   ```

3. **または、ターミナルから直接実行**
   ```bash
   /Applications/girlschan_app.app/Contents/MacOS/girlschan_app
   ```

## 📋 システム要件

- **最小 macOS バージョン**: 10.11（El Capitan）以上
- **推奨 macOS バージョン**: 12.0（Monterey）以上
- **メモリ**: 最小 2GB RAM
- **ディスク容量**: 100MB（アプリ + キャッシュ）

## 🔧 開発者向け情報

### ビルド環境のセットアップ

```bash
# Flutter のインストール確認
flutter doctor

# macOS サポートの確認
flutter config --enable-macos-desktop

# 依存関係の取得
flutter pub get
```

### デバッグビルド

```bash
# デバッグ版でビルド（開発用）
flutter build macos

# デバッグモードで実行
flutter run -d macos
```

### リリースビルド

```bash
# リリース版でビルド（最適化版）
flutter build macos --release

# ビルド成果物の確認
ls -lh build/macos/Build/Products/Release/girlschan_app.app
```

## 📦 配布方法

### 方法1：.app ファイルを ZIP で配布

```bash
cd build/macos/Build/Products/Release
zip -r girlschan_app.app.zip girlschan_app.app
# ユーザーは ZIP を解凍して実行
```

### 方法2：DMG ファイルの作成

```bash
# dmg コマンドまたは Disk Utility で .app から .dmg を作成
hdiutil create -volname "girlschan_app" -srcfolder build/macos/Build/Products/Release/girlschan_app.app -ov -format UDZO girlschan_app.dmg
```

### 方法3：GitHub Releases で配布

1. GitHub のリリースページで新しいリリースを作成
2. `girlschan_app.app` または `girlschan_app.dmg` をアップロード
3. ユーザーが直接ダウンロードできる状態に

## 🐛 トラブルシューティング

### 問題：「ファイルが破損している可能性があります」エラー

**解決方法:**
```bash
# キャッシュをクリア
xattr -rd com.apple.quarantine /Applications/girlschan_app.app

# または ターミナルから直接実行
/Applications/girlschan_app.app/Contents/MacOS/girlschan_app
```

### 問題：アプリが起動しない

1. ターミナルから実行して、エラーメッセージを確認
   ```bash
   /Applications/girlschan_app.app/Contents/MacOS/girlschan_app
   ```

2. ログをチェック
   ```bash
   # macOS アプリケーション ログを確認
   log stream --predicate 'process == "girlschan_app"'
   ```

### 問題：互換性の問題

- Intel Mac と Apple Silicon Mac の両方に対応しているため、ほぼどの macOS でも動作します
- 古い macOS バージョンの場合、アプリケーションを再ビルドしてください

## 📝 ライセンス

[ここにライセンス情報を記入]

## 🔗 リンク

- [Flutter 公式ドキュメント](https://flutter.dev)
- [macOS アプリ開発ガイド](https://flutter.dev/docs/get-started/install/macos)

## 💡 FAQ

### Q: Apple Developer アカウントがなくても大丈夫？
**A:** はい。このアプリは署名なしで実行できます。ただし、初回起動時にセキュリティ警告が表示されます（ターミナルから実行すれば回避可能）。

### Q: 署名してリリースしたい場合は？
**A:** Apple Developer アカウント（年間 99 USD）を取得し、以下のコマンドでコード署名を行えます：
```bash
codesign --deep --force --verify --verbose --sign "Developer ID Application" build/macos/Build/Products/Release/girlschan_app.app
```

### Q: アプリの更新はどうする？
**A:** 新しいバージョンをビルドして、GitHub Releases で新規リリースを作成し、ユーザーに手動でダウンロードしてもらいます。将来的にはスパークル（Sparkle）などの自動更新フレームワークを統合できます。

### Q: Windows や Linux では動作する？
**A:** 現在このアプリケーションは macOS のみの対応です。クロスプラットフォーム対応は Flutter の特性上、比較的簡単に追加できます。
