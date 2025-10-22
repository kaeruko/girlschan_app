#!/bin/bash

# girlschan_app インストール/実行スクリプト
# Apple Developer アカウントなしで簡単にセットアップ・実行できます

set -e

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 変数
APP_NAME="girlschan_app"
APP_BUNDLE="${APP_NAME}.app"
APPS_DIR="/Applications"
INSTALL_DIR="${APPS_DIR}/${APP_BUNDLE}"

show_menu() {
    echo -e "${BLUE}==================================${NC}"
    echo -e "${GREEN}${APP_NAME} - セットアップメニュー${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo ""
    echo "1) ビルド済みアプリを実行（カレントディレクトリから）"
    echo "2) アプリケーションフォルダにインストール"
    echo "3) インストール済みアプリを実行"
    echo "4) セキュリティ警告を解除して実行"
    echo "5) アプリケーションフォルダからアンインストール"
    echo "6) 終了"
    echo ""
    read -p "選択してください [1-6]: " choice
}

run_from_build() {
    echo -e "${YELLOW}ビルド済みアプリを実行しています...${NC}"
    
    BUILD_APP="build/macos/Build/Products/Release/${APP_BUNDLE}"
    
    if [ ! -d "${BUILD_APP}" ]; then
        echo -e "${RED}エラー: ビルド済みアプリが見つかりません${NC}"
        echo "先に以下のコマンドを実行してください:"
        echo "  flutter build macos --release"
        return 1
    fi
    
    echo -e "${GREEN}起動中...${NC}"
    open "${BUILD_APP}"
    echo -e "${GREEN}✓ アプリが起動しました${NC}"
}

install_app() {
    echo -e "${YELLOW}アプリケーションをインストールしています...${NC}"
    
    BUILD_APP="build/macos/Build/Products/Release/${APP_BUNDLE}"
    
    if [ ! -d "${BUILD_APP}" ]; then
        echo -e "${RED}エラー: ビルド済みアプリが見つかりません${NC}"
        echo "先に以下のコマンドを実行してください:"
        echo "  flutter build macos --release"
        return 1
    fi
    
    # 既存インストールがあれば削除
    if [ -d "${INSTALL_DIR}" ]; then
        echo -e "${YELLOW}既存インストール（${INSTALL_DIR}）を削除します${NC}"
        sudo rm -rf "${INSTALL_DIR}"
    fi
    
    # アプリをコピー
    echo "ファイルをコピーしています..."
    sudo cp -r "${BUILD_APP}" "${APPS_DIR}/"
    
    # セキュリティ属性をクリア
    echo "セキュリティ属性をクリアしています..."
    sudo xattr -rd com.apple.quarantine "${INSTALL_DIR}"
    
    echo -e "${GREEN}✓ インストール完了: ${INSTALL_DIR}${NC}"
    echo ""
    echo "起動方法:"
    echo "  - Launchpad または Applications フォルダから起動"
    echo "  - ターミナルから: open '${INSTALL_DIR}'"
}

run_installed() {
    echo -e "${YELLOW}インストール済みアプリを実行しています...${NC}"
    
    if [ ! -d "${INSTALL_DIR}" ]; then
        echo -e "${RED}エラー: インストール済みアプリが見つかりません${NC}"
        echo "先に 'インストール' オプションを実行してください"
        return 1
    fi
    
    echo -e "${GREEN}起動中...${NC}"
    open "${INSTALL_DIR}"
    echo -e "${GREEN}✓ アプリが起動しました${NC}"
}

run_with_security_bypass() {
    echo -e "${YELLOW}セキュリティ警告を解除して実行します...${NC}"
    
    EXECUTABLE="${INSTALL_DIR}/Contents/MacOS/${APP_NAME}"
    
    if [ ! -f "${EXECUTABLE}" ]; then
        echo -e "${RED}エラー: 実行ファイルが見つかりません${NC}"
        echo "${EXECUTABLE}"
        return 1
    fi
    
    echo "セキュリティ属性をクリアしています..."
    xattr -rd com.apple.quarantine "${INSTALL_DIR}" 2>/dev/null || true
    
    echo -e "${GREEN}起動中...${NC}"
    "${EXECUTABLE}" &
    echo -e "${GREEN}✓ アプリが起動しました${NC}"
}

uninstall_app() {
    echo -e "${YELLOW}アプリケーションをアンインストールしています...${NC}"
    
    if [ ! -d "${INSTALL_DIR}" ]; then
        echo -e "${RED}エラー: インストール済みアプリが見つかりません${NC}"
        return 1
    fi
    
    read -p "本当に削除しますか？ (y/n): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        sudo rm -rf "${INSTALL_DIR}"
        echo -e "${GREEN}✓ アンインストール完了${NC}"
    else
        echo -e "${YELLOW}キャンセルしました${NC}"
    fi
}

# メインループ
while true; do
    show_menu
    
    case $choice in
        1)
            run_from_build
            ;;
        2)
            install_app
            ;;
        3)
            run_installed
            ;;
        4)
            run_with_security_bypass
            ;;
        5)
            uninstall_app
            ;;
        6)
            echo -e "${GREEN}終了します${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}無効な選択です${NC}"
            ;;
    esac
    
    echo ""
    read -p "Enterキーを押して続行..."
    clear
done
