@echo off
setlocal
cd /d "%~dp0"
if not exist "build\windows\x64\runner\Release\memora.exe" (
  echo Memora doit etre compile une premiere fois avec flutter build windows --release --no-tree-shake-icons.
  pause
  exit /b 1
)
start "Memora" /D "%~dp0" "%~dp0build\windows\x64\runner\Release\memora.exe"
