# =====================================================================
#  BatchOps RDP Setup  -  SATU SCRIPT, JALAN DI DALAM RDP
# =====================================================================
#  Cara pakai (di dalam RDP):
#     powershell -ExecutionPolicy Bypass -File C:\BatchOps-setup.ps1 -Nomor 3
#
#  Nama file asli dari Google Drive dipertahankan, misalnya:
#     03.空伞之下，旧爱皆是过客_FULL.mp4
#
#  Bila nama berisi karakter yang tidak boleh dipakai Windows (< > : " / \ | ? *),
#  hanya karakter itu yang diganti '_' . Nomor dan judul tetap utuh.
# =====================================================================

param(
    [Parameter(Mandatory = $true)]
    [int]$Nomor,

    [string]$SoftwareUrl = 'https://drive.usercontent.google.com/download?id=1Sz2vug-QiQCZ0XBIndW1fl4hwPmrbbQv&export=download&authuser=0',
    [string]$FolderUrl   = 'https://drive.google.com/drive/u/1/folders/1LAU9WRkHrIkoA1gLl4zQwFERto2MOyEZ',
    [string]$Tujuan      = 'C:\BatchOps\downloads',
    [switch]$TanpaSoftware,
    [switch]$TanpaVideo
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

$LogFile = Join-Path (Split-Path -Parent $Tujuan) 'setup.log'
New-Item -ItemType Directory -Force -Path $Tujuan | Out-Null

# PowerShell 5.1 membaca .ps1 sebagai ANSI kalau tidak ada BOM, sehingga nama
# CJK dari Drive rusak. Kembalikan ke UTF-8 untuk semua output teks.
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

function Tulis([string]$Pesan) {
    $baris = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Pesan
    Write-Host $baris
    Add-Content -LiteralPath $LogFile -Value $baris -Encoding UTF8
}

function Ukuran([double]$Byte) {
    if ($Byte -ge 1GB) { return '{0:N2} GB' -f ($Byte / 1GB) }
    if ($Byte -ge 1MB) { return '{0:N1} MB' -f ($Byte / 1MB) }
    return '{0:N0} KB' -f ($Byte / 1KB)
}

function Nama-Aman([string]$Nama) {
    # Hanya karakter terlarang Windows yang diganti; judul & nomor tetap utuh.
    $bersih = $Nama -replace '[<>:"/\\|?*\x00-\x1F]', '_'
    $bersih = $bersih.Trim().TrimEnd('.')
    if (-not $bersih) { $bersih = 'video.mp4' }
    # Windows membatasi 255 karakter per nama file.
    if ($bersih.Length -gt 180) {
        $ext = [System.IO.Path]::GetExtension($bersih)
        $bersih = $bersih.Substring(0, 180 - $ext.Length) + $ext
    }
    return $bersih
}

# ---------------------------------------------------------------- unduh
function Ambil-File([string]$Url, [string]$Simpan) {
    $link = $Url
    if ($Url -match 'drive\.(usercontent\.)?google\.com') {
        $halaman = (Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 60 -Headers @{ 'User-Agent' = $UA }).Content
        $form = [regex]::Match($halaman, '<form[^>]*action="([^"]+)"[^>]*>(.*?)</form>', 'Singleline,IgnoreCase')
        if ($form.Success) {
            $aksi = $form.Groups[1].Value -replace '&amp;', '&'
            $pasangan = @()
            foreach ($i in [regex]::Matches($form.Groups[2].Value, '<input[^>]*name="([^"]+)"[^>]*value="([^"]*)"', 'IgnoreCase')) {
                $pasangan += ('{0}={1}' -f [uri]::EscapeDataString($i.Groups[1].Value), [uri]::EscapeDataString($i.Groups[2].Value))
            }
            if ($pasangan) { $link = $aksi + '?' + ($pasangan -join '&') }
        }
    }
    $klien = New-Object System.Net.WebClient
    try {
        $klien.Headers.Add('User-Agent', $UA)
        $klien.Headers.Add('Accept', '*/*')
        $klien.DownloadFile($link, $Simpan)
    } finally {
        $klien.Dispose()
    }
    if (-not (Test-Path -LiteralPath $Simpan)) { throw 'file hasil unduhan tidak ditemukan' }
    $ukuran = (Get-Item -LiteralPath $Simpan).Length
    if ($ukuran -lt 65536) {
        Remove-Item -LiteralPath $Simpan -Force -ErrorAction SilentlyContinue
        throw "server mengirim halaman kecil ($ukuran byte), bukan file"
    }
    return $ukuran
}

function Unduh-Dengan-Ulang([string]$Url, [string]$Simpan) {
    for ($coba = 1; $coba -le 3; $coba++) {
        try {
            return (Ambil-File -Url $Url -Simpan $Simpan)
        } catch {
            Tulis "  gagal (percobaan $coba/3): $($_.Exception.Message)"
            Remove-Item -LiteralPath $Simpan -Force -ErrorAction SilentlyContinue
            if ($coba -lt 3) { Start-Sleep -Seconds (5 * $coba) }
        }
    }
    throw "unduhan gagal: $Url"
}

# ---------------------------------------------------------------- software
function Pasang-Software {
    Tulis '=== SOFTWARE ==='
    $id = if ($SoftwareUrl -match '/file/d/([A-Za-z0-9_-]+)') { $Matches[1] }
          elseif ($SoftwareUrl -match '[?&]id=([A-Za-z0-9_-]+)') { $Matches[1] }
          else { throw 'link software Google Drive tidak dikenali' }
    $langsung = "https://drive.usercontent.google.com/download?id=$id&export=download&authuser=0"

    $terpasang = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                               'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                               'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' `
                               -ErrorAction SilentlyContinue |
        Get-ItemProperty -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'Hybrid|VideOCR' } | Select-Object -First 1
    if ($terpasang) {
        Tulis "Sudah terinstal: $($terpasang.DisplayName) - dilewati."
        return
    }

    $tujuan = Join-Path $Tujuan 'HybridStudio-Setup.exe'
    if (-not (Test-Path -LiteralPath $tujuan)) {
        Tulis 'Mengunduh installer...'
        $ukuran = Unduh-Dengan-Ulang -Url $langsung -Simpan $tujuan
        Tulis "Installer siap: $(Ukuran $ukuran)"
    } else {
        Tulis 'Installer sudah ada, memakai file lama.'
    }

    $buffer = New-Object byte[] (2MB)
    $stream = [System.IO.File]::OpenRead($tujuan)
    try { $n = $stream.Read($buffer, 0, $buffer.Length) } finally { $stream.Dispose() }
    $isi = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $n)

    if ($isi -match 'Inno Setup Setup Data') { $argumen = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /ALLUSERS' }
    elseif ($isi -match 'NullsoftInstallSystem') { $argumen = '/S' }
    elseif ($isi -match 'InstallShield') { $argumen = '/s /v"/qn"' }
    elseif ($isi -match 'WixBundle|Burn') { $argumen = '/quiet /norestart' }
    elseif ($isi -match '7-Zip SFX') { $argumen = '-y -gm2' }
    else {
        Tulis 'Installer tidak dikenali; membuka instalasi manual.'
        Start-Process -FilePath $tujuan
        return
    }

    Tulis "Menginstal (silent): $argumen"
    $p = Start-Process -FilePath $tujuan -ArgumentList ($argumen -split '\s+' | Where-Object { $_ }) -PassThru -Wait
    if ($p.ExitCode -notin @(0, 3010, 1641)) { throw "installer keluar dengan kode $($p.ExitCode)" }
    Tulis "Instalasi selesai (exit $($p.ExitCode))."
}

# ---------------------------------------------------------------- video
function Ambil-DaftarDrive([string]$FolderId) {
    $halaman = (Invoke-WebRequest -Uri "https://drive.google.com/drive/folders/$FolderId" `
            -UseBasicParsing -TimeoutSec 60 -Headers @{ 'User-Agent' = $UA }).Content
    # Windows PowerShell membaca respons tanpa charset sebagai Latin-1.
    $halaman = [System.Text.Encoding]::UTF8.GetString(
        [System.Text.Encoding]::GetEncoding(28591).GetBytes($halaman))
    $m = [regex]::Match($halaman, 'window\[''_DRIVE_ivd''\]\s*=\s*''(.*?)'';', 'Singleline')
    if (-not $m.Success) { throw "folder Drive tidak bisa dibaca (pastikan 'Anyone with the link')" }
    $raw = $m.Groups[1].Value
    $raw = [regex]::Replace($raw, '\\x([0-9a-fA-F]{2})', { param($x) [string][char][Convert]::ToInt32($x.Groups[1].Value, 16) })
    $raw = [regex]::Replace($raw, '\\u([0-9a-fA-F]{4})', { param($x) [string][char][Convert]::ToInt32($x.Groups[1].Value, 16) })
    $raw = $raw.Replace('\\', '\').Replace("\'", "'").Replace('\"', '"').Replace('\/', '/').Replace('\=', '=')
    # Satu nama file pun berupa array JSON: [$id, [$induk], "nama", "mime", ...].
    # Seluruh array itu diturunkan menjadi array PowerShell biasa di sini, jadi
    # bisa dipakai langsung tanpa mengurai ulang per entri.
    $data = ConvertFrom-Json -InputObject $raw

    $stack = New-Object System.Collections.Stack
    $stack.Push($data)
    $hasil = New-Object System.Collections.ArrayList
    while ($stack.Count -gt 0) {
        $node = $stack.Pop()
        if ($null -eq $node) { continue }
        $arr = $node -as [System.Array]
        if ($null -ne $arr) {
            if ($arr.Length -ge 4 -and $arr[0] -is [string] -and $arr[2] -is [string] -and $arr[3] -is [string]) {
                if ($arr[3] -match 'video|octet-stream') {
                    [void]$hasil.Add([pscustomobject]@{ id = [string]$arr[0]; nama = [string]$arr[2] })
                }
                continue
            }
            foreach ($item in $arr) {
                if ($null -ne ($item -as [System.Array])) { $stack.Push($item) }
            }
        }
    }
    return , $hasil.ToArray()
}

function Pasang-Video {
    Tulis '=== VIDEO ==='
    $folderId = if ($FolderUrl -match 'folders/([A-Za-z0-9_-]+)') { $Matches[1] } else { throw 'link folder Drive tidak dikenali' }
    $daftar = Ambil-DaftarDrive $folderId
    Tulis "$($daftar.Count) file di folder Drive."

    $cocok = @()
    foreach ($f in $daftar) {
        $angka = [regex]::Match($f.nama, '^\s*0*(\d{1,4})(?!\d)')
        if ($angka.Success -and [int]$angka.Groups[1].Value -eq $Nomor) { $cocok += $f }
    }
    if ($cocok.Count -eq 0) { throw "video nomor $Nomor tidak ditemukan di folder" }

    foreach ($f in $cocok) {
        $namaFile = Nama-Aman $f.nama
        $tujuan = Join-Path $Tujuan $namaFile
        Tulis "Video nomor $Nomor -> $namaFile"
        if (Test-Path -LiteralPath $tujuan) {
            Tulis "  sudah ada ($(Ukuran (Get-Item -LiteralPath $tujuan).Length)), unduh ulang untuk memastikan lengkap."
            Remove-Item -LiteralPath $tujuan -Force
        }
        $ukuran = Unduh-Dengan-Ulang -Url "https://drive.usercontent.google.com/download?id=$($f.id)&export=download&authuser=0" -Simpan $tujuan
        Tulis "  selesai: $(Ukuran $ukuran) -> $namaFile"
    }
}

# ------------------------------------------------------------------ jalan
Tulis "===== BatchOps setup: NOMOR $Nomor di $env:COMPUTERNAME ====="
$gagal = $false

if (-not $TanpaSoftware) {
    try { Pasang-Software } catch { $gagal = $true; Tulis "SOFTWARE GAGAL: $($_.Exception.Message)" }
} else { Tulis 'Software dilewati (-TanpaSoftware).' }

if (-not $TanpaVideo) {
    try { Pasang-Video } catch { $gagal = $true; Tulis "VIDEO GAGAL: $($_.Exception.Message)" }
} else { Tulis 'Video dilewati (-TanpaVideo).' }

Tulis '--- isi folder ---'
Get-ChildItem -LiteralPath $Tujuan -File | ForEach-Object { Tulis ("  {0}  {1}" -f $_.Name, (Ukuran $_.Length)) }

if ($gagal) {
    Tulis 'SELESAI DENGAN MASALAH. Baca baris GAGAL di atas.'
} else {
    Tulis 'SELESAI. Semua langkah berhasil.'
}
