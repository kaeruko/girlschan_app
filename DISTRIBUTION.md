# 配布ガイド

Apple Developer アカウントなしで macOS アプリを配布・インストールする完全ガイドです。

## 📦 配布ファイル

### ユーザー向け

- **`girlschan_app.dmg`** - 推奨配布形式
  - 標準的な macOS インストール形式
  - ドラッグ&ドロップで簡単にインストール可能
  - ファイルサイズ: 約 56MB

- **`girlschan_app.app`** - 直接実行版
  - ビルドディレクトリ: `build/macos/Build/Products/Release/girlschan_app.app`
  - ファイルサイズ: 約 44MB
  - ZIP にしても配布可能

### 開発者向け

- **`INSTALL.md`** - ユーザー向けインストールガイド
- **`README.md`** - 詳細なドキュメント
- **`scripts/install.sh`** - インストール/実行補助スクリプト
- **`scripts/create_dmg.sh`** - DMG ファイル生成スクリプト

## 🚀 配布方法

### 方法1：GitHub Releases で配布（推奨）

1. **GitHub リポジトリに移動**
   ```bash
   cd /Users/yokina/work/girlschan_app
   git remote -v
   ```

2. **新しいリリースを作成**
   - GitHub のリポジトリページで「Releases」をクリック
   - 「New release」をクリック
   - タグバージョンを入力（例: `v1.0.0`）
   - リリースタイトルと説明を入力
   - 以下のファイルをアップロード：
     - `girlschan_app.dmg`
     - `INSTALL.md`

3. **ユーザーがダウンロード**
   - Releases ページから DMG ファイルをダウンロード
   - ダブルクリックでインストール

### 方法2：ウェブサイトで配布

1. **サーバーにアップロード**
   ```bash
   # 例: SCP でアップロード
   scp girlschan_app.dmg user@server:/var/www/html/downloads/
   ```

2. **ダウンロードリンクを提供**
   ```html
   <a href="https://example.com/downloads/girlschan_app.dmg">
     Download girlschan_app
   </a>
   ```

3. **INSTALL.md の内容をページに表示**

### 方法3：クラウドストレージで配布

- **Google Drive**
  - ファイルをアップロード
  - 共有リンクを取得
  - ユーザーに共有リンクを配布

- **Dropbox**
  - ファイルをアップロード
  - 公開リンクを生成
  - ユーザーに配布

- **OneDrive**
  - ファイルをアップロード
  - 共有リンクを生成
  - ユーザーに配布

## 📋 ユーザーへのインストール説明

### シンプル版（推奨）

```markdown
## インストール方法

1. `girlschan_app.dmg` をダウンロード
2. ダブルクリックで開く
3. `girlschan_app.app` を Applications フォルダにドラッグ
4. Launchpad または Applications から起動
```

### セキュリティ警告が出た場合

```markdown
## ファイルが破損していると言われる場合

以下の **いずれか** の方法で解決できます：

### 方法1（簡単）
1. アプリを右クリック
2. 「情報を見る」をクリック
3. 「このまま開く」をクリック

### 方法2（ターミナル）
```bash
xattr -rd com.apple.quarantine /Applications/girlschan_app.app
open /Applications/girlschan_app.app
```
```

## 🔄 更新方法

### 新バージョンのリリース手順

```bash
# 1. アプリを修正・改善
# (コード変更など)

# 2. バージョン番号を更新
# pubspec.yaml の version フィールドを更新

# 3. 再ビルド
flutter build macos --release

# 4. 新しい DMG を作成
bash scripts/create_dmg.sh

# 5. Git にコミット・プッシュ
git add .
git commit -m "Release v1.1.0"
git push origin main

# 6. GitHub Release を作成
# （手動で GitHub ウェブサイトから）
```

## 📊 配布統計情報の追跡

### 簡易的な方法

- **Google Analytics** - ウェブサイトのダウンロードリンクにスクリプトを追加
- **GitHub Release Downloads** - GitHub Releases のダウンロード数を確認
- **Dropbox/Google Drive** - 共有リンクのアクセス統計

## ✅ チェックリスト

配布前に確認：

- [ ] アプリが正常に起動するか確認
- [ ] macOS 互換性をテスト（複数バージョンで）
- [ ] Intel Mac と Apple Silicon Mac の両方でテスト
- [ ] セキュリティ警告の対処方法をドキュメント化
- [ ] INSTALL.md が最新か確認
- [ ] README.md が最新か確認
- [ ] ビルドが成功しているか確認

## 🆚 配布形式の比較

| 形式 | サイズ | 配布方法 | インストール難易度 |
|------|--------|---------|-------------------|
| DMG | 56MB | GitHub/Web | 簡単 |
| .app ZIP | 44MB | メール/Web | 中程度 |
| GitHub Releases | 変動 | GitHub | 簡単 |
| インストーラー | 大 | Web | 簡単 |

## 📝 ライセンス注記

Apple Developer アカウントがなくても配布可能ですが、以下の制限があります：

- **署名なし** - ユーザーが初回起動時に確認が必要
- **公証化なし** - 新しい macOS で警告が表示される可能性
- **更新通知なし** - 手動でダウンロードしてもらう必要がある

## 💰 今後のステップ（オプション）

### Apple Developer アカウント取得時

- Developer ID で署名（年間 99 USD）
- App Store での配布
- 自動更新機能の追加

### 初回配布時の無料選択肢

- **現在のセットアップのまま配布** - 署名なし
- **オンラインで無料コード署名** - Web ベースのツール
- **コミュニティツール** - オープンソースの署名ツール

---

**このドキュメントを参考に、ユーザーへの配布を進めてください！**
