@echo off
REM =====================================================================
REM  BatchOps RDP Setup - unduh lalu jalankan rdp-setup.ps1
REM
REM  Pakai di dalam RDP:
REM      batchops.bat 3
REM      batchops.bat 3 "D:\video"
REM      batchops.bat 3 "" https://pixeldrain.com/l/AbCdEf12
REM
REM  Tanpa angka, nomornya ditebak dari IP publik RDP ini:
REM  angka terakhir IP tersebut. Nomor yang ditebak ditampilkan dan
REM  dihitung mundur 10 detik, jadi masih bisa dibatalkan (Ctrl+C).
REM =====================================================================
setlocal enabledelayedexpansion
set NOMOR=%~1
set FOLDER=%~2

set URL=https://raw.githubusercontent.com/Aceptrade/MYrdp/main/rdp-setup.ps1
REM Link Pixeldrain bisa diganti tanpa mengubah file ini:
REM     set BATCHOPS_SUMBER=https://pixeldrain.com/l/AbCdEf12
REM atau langsung:  batchops.bat 7 "" https://pixeldrain.com/l/AbCdEf12
set SUMBER=%~3
if "%SUMBER%"=="" set SUMBER=%BATCHOPS_SUMBER%
REM Nama unik supaya tidak pernah memakai salinan lama dari %TEMP%.
set TARGET=%TEMP%\rdp-setup-%RANDOM%%RANDOM%.ps1

echo Mengunduh script...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%URL%' -OutFile '%TARGET%' -UseBasicParsing"
if not exist "%TARGET%" (
  echo Gagal mengunduh script dari %URL%
  exit /b 1
)

if not "%NOMOR%"=="" goto jalan

REM --- tebak nomor dari IP publik RDP ini ---
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "try { (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 15) } catch { '' }"`) do set IP=%%i
if "%IP%"=="" (
  echo Gagal membaca IP publik. Isi nomornya manual: batchops.bat 7
  del /q "%TARGET%" >nul 2>&1
  exit /b 1
)
for /f "tokens=1-4 delims=." %%a in ("%IP%") do set NOMOR=%%d
if %NOMOR% LSS 1 goto nomor_buruk
if %NOMOR% GTR 20 goto nomor_buruk

echo IP publik RDP ini: %IP%
echo Nomor yang dipakai: %NOMOR%
echo Membatalkan? Tekan Ctrl+C dalam 10 detik.
timeout /t 10 /nobreak >nul
goto jalan

:nomor_buruk
echo IP publik RDP ini: %IP%
echo Angka terakhir IP ini (%NOMOR%) tidak dipakai sebagai nomor video.
echo Isi nomornya manual, contoh: batchops.bat 7
del /q "%TARGET%" >nul 2>&1
exit /b 1

:jalan
if "%FOLDER%"=="" set FOLDER=%TEMP%
if "%SUMBER%"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%" -Nomor %NOMOR% -Tujuan "%FOLDER%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%TARGET%" -Nomor %NOMOR% -Tujuan "%FOLDER%" -SumberVideo "%SUMBER%"
)
del /q "%TARGET%" >nul 2>&1
endlocal
