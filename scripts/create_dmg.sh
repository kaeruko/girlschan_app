#!/bin/bash

# girlschan_app DMG 作成スクリプト
# Apple Developer アカウントなしで配布可能な DMG ファイルを作成します

set -e

# 変数
APP_NAME="girlschan_app"
BUILD_DIR="build/macos/Build/Products/Release"
OUTPUT_DMG="${APP_NAME}.dmg"
MOUNT_DIR="/tmp/${APP_NAME}_dmg_mount"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== girlschan_app DMG 作成スクリプト ===${NC}"
echo ""

# Step 1: ビルドの確認
if [ ! -d "${BUILD_DIR}/${APP_NAME}.app" ]; then
    echo -e "${RED}エラー: ビルド済みアプリケーションが見つかりません${NC}"
    echo "先に以下のコマンドを実行してください:"
    echo "  flutter build macos --release"
    exit 1
fi

echo -e "${GREEN}✓ ビルド済みアプリケーションを確認しました${NC}"

# Step 2: 既存の DMG があれば削除
if [ -f "${OUTPUT_DMG}" ]; then
    echo -e "${YELLOW}既存の DMG ファイルを削除します: ${OUTPUT_DMG}${NC}"
    rm -f "${OUTPUT_DMG}"
fi

# Step 3: 一時ディレクトリを準備
if [ -d "${MOUNT_DIR}" ]; then
    rm -rf "${MOUNT_DIR}"
fi
mkdir -p "${MOUNT_DIR}"

# Step 4: アプリケーションをコピー
echo -e "${GREEN}アプリケーションを一時ディレクトリにコピーしています...${NC}"
cp -r "${BUILD_DIR}/${APP_NAME}.app" "${MOUNT_DIR}/"

# Step 5: Applications へのシンボリックリンクを作成
echo -e "${GREEN}Applications シンボリックリンクを作成しています...${NC}"
ln -s /Applications "${MOUNT_DIR}/Applications"

# Step 6: DMG ファイルを作成
echo -e "${GREEN}DMG ファイルを作成しています...${NC}"
echo "このプロセスには数秒かかる場合があります..."

# 一時的な DMG を作成
TEMP_DMG="temp_${APP_NAME}.dmg"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${MOUNT_DIR}" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "${TEMP_DMG}" \
    > /dev/null 2>&1

# DMG をマウント
DEVICE=$(hdiutil attach "${TEMP_DMG}" | grep "/Volumes/${APP_NAME}" | awk '{print $1}')

# マウント確認
if [ -z "${DEVICE}" ]; then
    echo -e "${RED}警告: DMG マウントが不完全ですが、続行します${NC}"
    sleep 2
    DEVICE=$(hdiutil attach "${TEMP_DMG}" 2>/dev/null | head -1 | awk '{print $1}')
fi

echo -e "${YELLOW}DMG をセットアップしています...${NC}"
sleep 1

# アンマウント（レイアウト調整スキップ）
if [ -n "${DEVICE}" ]; then
    hdiutil detach "${DEVICE}" > /dev/null 2>&1 || true
    sleep 1
fi

# 圧縮された DMG に変換
echo -e "${GREEN}DMG ファイルを圧縮しています...${NC}"
hdiutil convert "${TEMP_DMG}" \
    -format UDZO \
    -o "${OUTPUT_DMG}" \
    > /dev/null 2>&1

# 一時ファイルをクリーンアップ
rm -f "${TEMP_DMG}"
rm -rf "${MOUNT_DIR}"

# Step 7: 完了
echo ""
echo -e "${GREEN}=== DMG 作成完了 ===${NC}"
echo -e "${GREEN}✓ ファイル: ${OUTPUT_DMG}${NC}"
echo -e "${GREEN}✓ サイズ: $(du -h "${OUTPUT_DMG}" | cut -f1)${NC}"
echo ""
echo "配布方法:"
echo "1. DMG ファイルをサーバーやクラウドにアップロード"
echo "2. ユーザーが DMG をダウンロード"
echo "3. DMG をダブルクリック"
echo "4. アプリケーションフォルダにドラッグ"
echo ""
echo "詳細は README.md を参照してください。"
