# Claude Desktop の再インストール準備スクリプト
# 残骸ショートカット削除 + アイコンキャッシュ再構築

Write-Host "=== Claude Desktop クリーンアップ開始 ===" -ForegroundColor Cyan

# 1. 残骸ショートカット削除
Write-Host "[1/3] 残骸ショートカット/データを削除中..." -ForegroundColor Yellow
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Claude*" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\AnthropicClaude" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\Desktop\Claude*.lnk" -Force -ErrorAction SilentlyContinue

# 2. アイコンキャッシュ削除
Write-Host "[2/3] アイコンキャッシュを削除中..." -ForegroundColor Yellow
ie4uinit.exe -show
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force -ErrorAction SilentlyContinue

# 3. エクスプローラー再起動
Write-Host "[3/3] エクスプローラーを再起動中..." -ForegroundColor Yellow
Start-Process explorer

Write-Host ""
Write-Host "=== クリーンアップ完了 ===" -ForegroundColor Green
Write-Host ""
Write-Host "次のステップ:" -ForegroundColor Cyan
Write-Host "  1. 設定 > アプリ から ""Claude"" をアンインストール（残っていれば）"
Write-Host "  2. 最新の Claude Setup.exe を実行して再インストール"
Write-Host "  3. 検索バーで 'claude' と入力してアイコンが正しく表示されるか確認"
Write-Host ""
Pause
