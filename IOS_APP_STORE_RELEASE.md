# iOS App Store リリース手順（Flutter / GitHub Actions）

このドキュメントは、がるなびでの初回 iOS リリース作業をもとにした再利用用の手順書です。

今後、`kaeruko/minapp`（みんアプ）や `kaeruko/bittra`（びっとら）など別アプリをリリースするときも、この手順をベースにします。

> **重要**: `.p12`、`.mobileprovision`、`.p8`、各種パスワードや Base64 化した秘密情報は Git にコミットしないこと。GitHub Actions の Repository secrets に保存する。

## 1. アプリごとに用意するもの

### Bundle ID

Apple Developer の Identifiers でアプリ固有の Bundle ID を登録する。

例（がるなび）:

```text
jp.cloxs.girlschanApp
```

Bundle ID は App Store Connect、Xcode/Flutter、Provisioning Profile、GitHub Actions で一致させる。

### Apple Distribution 証明書

同じ Apple Developer Team の複数アプリで、同じ有効な `Apple Distribution` 証明書を再利用できる。

がるなびで現在使用しているもの:

```text
Apple Distribution: CLOXS LLC
Team ID: H5B52RL9R2
```

GitHub Actions で使用する場合は、証明書と秘密鍵を Keychain から `.p12` として書き出す。

### App Store 用 Provisioning Profile

**アプリごとに作成する。**

GitHub Actions で手動署名する場合、Xcode が自動生成した `iOS Team Store Provisioning Profile` をそのまま使わない。

Apple Developer → Certificates, Identifiers & Profiles → Profiles → `+` から App Store / App Store Connect 配布用 Profile を手動作成し、以下を選ぶ。

```text
App ID: そのアプリの Bundle ID
Certificate: GitHub Actions で使う Apple Distribution 証明書
```

Provisioning Profile Name は管理用の任意名でよい。

例:

```text
Garunavi App Store Distribution
Minapp App Store Distribution
Bittra App Store Distribution
```

### なぜ手動 Profile が必要だったか

がるなびでは最初、Bundle ID / Team ID / `get-task-allow=false` が正しい Xcode managed Profile を使っていたが、GitHub Actions の手動署名で次のエラーになった。

```text
Provisioning profile ... doesn't include signing certificate "Apple Distribution: CLOXS LLC (...)"
Provisioning profile ... is Xcode managed, but signing settings require a manually managed profile.
```

つまり、App Store 用であるだけでは不十分で、**その Profile に CI で使用する Distribution 証明書が含まれていること**が必要。

## 2. GitHub Actions Secrets

各アプリの GitHub repository → Settings → Secrets and variables → Actions に登録する。

### 署名用（必須）

```text
IOS_DISTRIBUTION_CERTIFICATE_BASE64
IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
IOS_PROVISIONING_PROFILE_BASE64
```

- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`: `.p12` を Base64 化したもの
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`: `.p12` 書き出し時のパスワード
- `IOS_PROVISIONING_PROFILE_BASE64`: **そのアプリ専用**の手動 App Store Provisioning Profile を Base64 化したもの

Distribution certificate とその password は同じ Team 内の複数 repository で再利用できるが、Provisioning Profile は Bundle ID ごとに別にする。

### macOS で Base64 をクリップボードへ入れる

`.mobileprovision`:

```bash
base64 < ~/Downloads/Your_App.mobileprovision | tr -d '\n' | pbcopy
```

`.p12`:

```bash
base64 < ~/Desktop/distribution.p12 | tr -d '\n' | pbcopy
```

GitHub の Secret Value へ貼り付ける。

## 3. App Store Connect 自動アップロード用（任意）

GitHub Actions から App Store Connect へ直接アップロードする場合は API Key を作成して以下を登録する。

```text
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_API_KEY_P8_BASE64
```

`.p8` はダウンロードできる回数に制限があるため、安全に保管する。

同じ API Key が複数アプリへのアクセス権を持っていれば再利用できる。アプリ単位でアクセス制限している場合は権限を確認する。

## 4. Flutter / CocoaPods の準備

CI では使用するバージョンを固定する。

がるなびで確認した組み合わせ:

```text
Flutter: 3.47.0
Xcode: 26.6
CocoaPods: 1.16.2
```

依存関係を勝手に更新せず、`pubspec.lock` / `Podfile.lock` と同じ構成でビルドする。

### Swift Package Manager と CocoaPods の混在に注意

がるなびでは `google_mobile_ads` → `webview_flutter_wkwebview` の解決で CocoaPods がローカル Flutter plugin を見失った。

CI では現在、Flutter plugin の統合を CocoaPods に揃えるため Swift Package Manager を無効化している。

```bash
flutter config --no-enable-swift-package-manager
flutter pub get
```

その後、`webview_flutter_wkwebview` 等の必要 plugin が `.flutter-plugins-dependencies` に存在することを確認してから `pod install` する。

これは全アプリに必須とは限らない。各アプリの plugin 構成に応じて判断する。

## 5. 署名は Runner ターゲットだけに設定する

`xcodebuild` のコマンドラインに以下をグローバル build setting として渡すと、Pods にも Provisioning Profile が適用されることがある。

```text
PROVISIONING_PROFILE_SPECIFIER
CODE_SIGN_STYLE
CODE_SIGN_IDENTITY
```

がるなびではこれにより次のようなエラーが出た。

```text
DKPhotoGallery does not support provisioning profiles
share_plus does not support provisioning profiles
SwiftyGif does not support provisioning profiles
```

**App Store の署名設定は Runner target のみに設定し、Pods には適用しない。**

## 6. Provisioning Profile の事前検証

CI で Archive に進む前に Profile をデコードして確認する。

```bash
security cms -D -i profile.mobileprovision > profile.plist
```

最低限、以下を fail-fast で確認する。

```text
TeamIdentifier == 使用する Team ID
application-identifier == TEAM_ID.BundleID
get-task-allow == false
```

さらに、Archive 時には Profile が使用する `Apple Distribution` 証明書を含んでいる必要がある。

## 7. iOS Deployment Target

Flutter / Xcode / Apple の最低 OS 要件を揃える。

がるなびの CI では Flutter 3.47.0 の Pod から次の警告が出た。

```text
Flutter (1.0.0) has a minimum requirement of iOS 15.0
```

今後の新規アプリは原則として iOS 15.0 以上に揃える方向で扱う。

`Podfile`、Flutter の xcconfig、Xcode project の `IPHONEOS_DEPLOYMENT_TARGET` がバラバラにならないよう確認する。

## 8. Archive / IPA で検証する項目

Archive / Export 後、IPA をそのままアップロードせず、少なくとも以下を検証する。

```text
CFBundleIdentifier
CFBundleShortVersionString
CFBundleVersion
codesign --verify
必要な Info.plist purpose string
```

App Store Connect の「Version」と `CFBundleShortVersionString` は一致させる。

例:

```text
App Store Connect Version: 1.0
CI BUILD_NAME: 1.0
CI BUILD_NUMBER: 15
```

## 9. Info.plist の Privacy Purpose String

アプリ自身が直接写真機能を使っていなくても、依存 SDK が該当 API を参照すると Apple の静的解析で Purpose String を要求されることがある。

がるなび Build 14 では次のエラーになった。

```text
ITMS-90683: Missing purpose string in Info.plist
NSPhotoLibraryUsageDescription is required
```

`file_picker` が iOS で `DKImagePickerController` / `DKPhotoGallery` を依存として含むため、アプリの意図とは別に検出された。

Apple のアップロード結果メールを必ず確認し、警告と必須エラーを区別する。

## 10. App Store Connect 側の初回準備

初回リリースではビルド以外に次の項目も必要。

- App record 作成
- Bundle ID 選択
- SKU
- App 名 / Subtitle / Description / Keywords
- スクリーンショット
- Support URL
- Privacy Policy URL
- Primary / Secondary Category
- Age Rating
- App Privacy
- Pricing and Availability
- App Review Information
- Export Compliance
- Release method

ビルドが App Store Connect の処理で拒否された場合、その Build は Version 画面で選択できない。

## 11. 新しい Flutter アプリをリリースするときのチェックリスト

- [ ] Apple Developer Team を確認
- [ ] App 固有 Bundle ID を登録
- [ ] App Store Connect に App record を作成
- [ ] 有効な Apple Distribution certificate を確認
- [ ] App 固有の **手動 App Store Provisioning Profile** を作成
- [ ] Profile 作成時に CI 用 Distribution certificate を選択
- [ ] `.p12` を Base64 化して GitHub Secret に登録
- [ ] `.p12` password を GitHub Secret に登録
- [ ] `.mobileprovision` を Base64 化して GitHub Secret に登録
- [ ] Flutter / Xcode / CocoaPods バージョンを固定
- [ ] Bundle ID / Team ID / Profile を CI で fail-fast 検証
- [ ] Runner target のみに署名を設定
- [ ] Pods に Provisioning Profile を押し付けていないことを確認
- [ ] Deployment Target を揃える
- [ ] Archive 成功
- [ ] IPA の Bundle ID / Version / Build Number / Code Sign を検証
- [ ] Info.plist の Privacy Purpose String を確認
- [ ] GitHub artifact として IPA を保存
- [ ] App Store Connect に upload
- [ ] Apple の processing 結果 / メールを確認
- [ ] TestFlight に Build が出ることを確認
- [ ] App Store version に Build を紐付ける
- [ ] Metadata / Privacy / Review 情報を完成
- [ ] Submit for Review

## 12. がるなびで実際に踏んだ問題

### 1. CocoaPods が `webview_flutter_wkwebview` を見つけられない

```text
Unable to find a specification for `webview_flutter_wkwebview` depended upon by `google_mobile_ads`
```

CocoaPods のバージョンだけが原因ではなかった。Flutter plugin discovery / CocoaPods integration を確認し、SwiftPM と CocoaPods の混在を避けた。

### 2. Provisioning Profile が全 Pods に適用された

```text
DKPhotoGallery does not support provisioning profiles
share_plus does not support provisioning profiles
```

署名設定を Runner target のみに限定して解決。

### 3. Xcode managed Profile と手動署名が衝突

```text
Provisioning profile ... is Xcode managed, but signing settings require a manually managed profile.
```

手動 App Store Profile を作成し、CI で使う Distribution certificate を明示的に含める。

### 4. App Store の Privacy Purpose String 不足

```text
ITMS-90683: Missing purpose string in Info.plist
```

依存 SDK も含めて Apple が静的解析するため、必要な Purpose String を追加して再ビルドする。

---

## 運用方針

新しい問題が出たら、その場しのぎの workaround だけで終わらせず、原因・確認方法・再発防止をこの手順書へ追記する。

各アプリ固有の値（Bundle ID、App Store ID、Profile 名、Deployment Target、必要な Privacy Key）は各 repository 側に記録し、証明書・秘密鍵・password・API key 本体は記録しない。
