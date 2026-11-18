@echo off
REM =====================================================================
REM  BatchOps RDP Setup - unduh lalu jalankan rdp-setup.ps1
REM  Pakai di dalam RDP:
REM      batchops.bat 3
REM  (3 = nomor urut RDP ini)
REM =====================================================================
setlocal
set NOMOR=%~1
if "%NOMOR%"=="" (
  set /p NOMOR=Nomor urut RDP ini: 
)
if "%NOMOR%"=="" (
  echo Nomor kosong. Contoh: batchops.bat 3
  exit /b 1
)

set URL=https://raw.githubusercontent.com/Aceptrade/MYrdp/main/rdp-setup.ps1
set TARGET=%TEMP%\rdp-setup.ps1

echo Mengunduh script...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%URL%' -OutFile '%TARGET%' -UseBasicParsing"
if not exist "%TARGET%" (
  echo Gagal mengunduh script dari %URL%
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%" -Nomor %NOMOR%
endlocal
