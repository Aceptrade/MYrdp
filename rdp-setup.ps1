# =====================================================================
#  BatchOps RDP Setup  -  SATU SCRIPT, JALAN DI DALAM RDP
# =====================================================================
#  Dua cara pakai:
#
#  A. File (disarankan kalau mau diutak-atik):
#     powershell -ExecutionPolicy Bypass -File C:\rdp-setup.ps1 -Nomor 3
#
#  B. Tempel langsung di PowerShell, satu baris:
#     irm https://raw.githubusercontent.com/Aceptrade/MYrdp/main/rdp-setup.ps1 -OutFile "$env:TEMP\rdp-setup.ps1"; & "$env:TEMP\rdp-setup.ps1" -Nomor 3
#
#     Setelah itu file-nya ada di %TEMP%\rdp-setup.ps1 dan boleh diutak-atik.
#
#  Yang biasanya perlu diubah ada di blok "ATUR DI SINI" pada fungsi
#  Pasang-Video (pemilihan video) dan pada param di bawah (link sumber).
#
#  Nama file asli dari sumber dipertahankan, misalnya:
#     03.空伞之下，旧爱皆是过客_FULL.mp4
#
#  Tujuan unduhan default: folder Downloads milik user yang menjalankan script
#  (mis. C:\Users\RDP\Downloads). Ubah dengan -Tujuan "D:\lain".
#
#  Bila nama berisi karakter yang tidak boleh dipakai Windows (< > : " / \ | ? *),
#  hanya karakter itu yang diganti '_' . Nomor dan judul tetap utuh.
# =====================================================================

param(
    [Parameter(Mandatory = $true)]
    [int]$Nomor,

    [string]$SoftwareUrl = 'https://drive.usercontent.google.com/download?id=1Sz2vug-QiQCZ0XBIndW1fl4hwPmrbbQv&export=download&authuser=0',
    [string]$FolderUrl   = 'https://drive.google.com/drive/u/1/folders/1LAU9WRkHrIkoA1gLl4zQwFERto2MOyEZ',
    # Sumber video: Pixeldrain (list atau file). Bila diisi, $FolderUrl tidak
    # dipakai. Bisa juga ditimpa tanpa mengubah script, lewat variabel
    # lingkungan BATCHOPS_SUMBER (mis. di batchops.bat: set BATCHOPS_SUMBER=...).
    [string]$SumberVideo = '',
    [string]$Tujuan      = '',
    [switch]$TanpaSoftware,
    [switch]$TanpaVideo
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

# Sumber video yang dipakai: parameter -SumberVideo, lalu variabel lingkungan
# BATCHOPS_SUMBER, lalu nilai bawaan. Dengan begitu link bisa diganti tanpa
# menyentuh script sama sekali.
$SumberBawaan = 'https://pixeldrain.com/l/jbsdnP7W'
if (-not $SumberVideo) { $SumberVideo = $env:BATCHOPS_SUMBER }
if (-not $SumberVideo) { $SumberVideo = $SumberBawaan }
$TujuanBawaan = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
# Default: folder Downloads milik user yang menjalankan script
# (mis. C:\Users\RDP\Downloads).
if (-not $Tujuan) { $Tujuan = $TujuanBawaan }
$LogFile = Join-Path $Tujuan 'setup.log'
New-Item -ItemType Directory -Force -Path $Tujuan | Out-Null
# Jalur penuh: kalau $Tujuan relatif, file bisa mendarat di folder lain.
$Tujuan = (Get-Item -LiteralPath $Tujuan).FullName
# Hanya file unduhan yang ada di folder ini yang disentuh; file lain milik user
# di folder Downloads tidak pernah dihapus.
$LogFile = Join-Path $Tujuan 'setup.log'

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

function Buka-Folder([string]$Path) {
    # Tampilkan foldernya supaya tidak perlu mencari manual di Explorer.
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $Path + '"') } catch { }
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
function Halaman-Drive([string]$Url) {
    # Halaman Drive dibaca sebagai BYTE lalu di-decode UTF-8, karena
    # Invoke-WebRequest bisa salah menebak encoding-nya.
    $minta = [System.Net.WebRequest]::Create($Url)
    $minta.UserAgent = $UA
    $minta.Timeout = 60000
    $minta.ReadWriteTimeout = 120000
    $jawab = $minta.GetResponse()
    try {
        $alir = $jawab.GetResponseStream()
        $memori = New-Object System.IO.MemoryStream
        try {
            $alir.CopyTo($memori)
            return [System.Text.Encoding]::UTF8.GetString($memori.ToArray())
        } finally { $memori.Dispose(); $alir.Dispose() }
    } finally { $jawab.Close() }
}

function Link-KonfirmasiDrive([string]$Url) {
    # File di atas ~100 MB dikirim sebagai halaman "Virus scan warning" dengan
    # formulir konfirmasi ("Download anyway"). Link hasil konfirmasi dipakai
    # untuk unduhan sebenarnya.
    $halaman = Halaman-Drive $Url
    $form = [regex]::Match($halaman, '<form[^>]*action="([^"]+)"[^>]*>(.*?)</form>', 'Singleline,IgnoreCase')
    if (-not $form.Success) { return $null }

    $aksi = $form.Groups[1].Value -replace '&amp;', '&'
    $pasangan = @()
    foreach ($i in [regex]::Matches($form.Groups[2].Value, '<input[^>]*name="([^"]+)"[^>]*value="([^"]*)"', 'IgnoreCase')) {
        $pasangan += ('{0}={1}' -f [uri]::EscapeDataString($i.Groups[1].Value), [uri]::EscapeDataString($i.Groups[2].Value))
    }
    if (-not $pasangan) { return $null }
    return $aksi + '?' + ($pasangan -join '&')
}

function Pesan-Drive([string]$Url) {
    # Menerjemahkan halaman kesalahan Drive menjadi satu kalimat yang jelas,
    # misalnya kuota unduhan Google habis.
    try { $halaman = Halaman-Drive $Url } catch { return $null }
    $judul = [regex]::Match($halaman, '<title>(.*?)</title>', 'Singleline')
    if ($judul.Success -and $judul.Groups[1].Value -match 'Quota exceeded') {
        return 'kuota unduhan Google Drive habis untuk file ini (terlalu banyak orang mengunduhnya dalam 24 jam) - coba lagi nanti atau pakai akun/link lain'
    }
    if ($judul.Success -and $judul.Groups[1].Value -match 'Virus scan warning') {
        return 'Drive meminta konfirmasi "Download anyway" tetapi halaman konfirmasi tidak terbaca'
    }
    return $null
}

function Ambil-File([string]$Url, [string]$Simpan) {
    # .NET menyimpan dengan nama ANSI (ANSI_NAME) bila jalurnya dianggap bukan
    # Unicode; disini nama file justru berisi CJK, jadi unduhan ditulis ke nama
    # sementara ASCII lalu diganti namanya. Rename lewat PowerShell memakai
    # Unicode, sehingga nama CJK tetap utuh.
    $sementara = Join-Path (Split-Path -Parent $Simpan) ('.unduh-' + [guid]::NewGuid().ToString('N') + '.part')
    try {
        $link = $Url
        if ($Url -match 'drive\.(usercontent\.)?google\.com') {
            $konfirmasi = Link-KonfirmasiDrive $Url
            if ($konfirmasi) { $link = $konfirmasi }
        }
        $klien = New-Object System.Net.WebClient
        try {
            $klien.Headers.Add('User-Agent', $UA)
            $klien.Headers.Add('Accept', '*/*')
            $klien.DownloadFile($link, $sementara)
        } finally {
            $klien.Dispose()
        }
        if (-not (Test-Path -LiteralPath $sementara)) { throw 'file hasil unduhan tidak ditemukan' }
        $ukuran = (Get-Item -LiteralPath $sementara).Length
        if ($ukuran -lt 65536) {
            $sebab = if ($Url -match 'drive\.') { Pesan-Drive $link } else { $null }
            if (-not $sebab) { $sebab = "server mengirim halaman kecil ($ukuran byte), bukan file" }
            throw $sebab
        }

        if (Test-Path -LiteralPath $Simpan) { Remove-Item -LiteralPath $Simpan -Force }
        Move-Item -LiteralPath $sementara -Destination $Simpan -Force
        return $ukuran
    } finally {
        Remove-Item -LiteralPath $sementara -Force -ErrorAction SilentlyContinue
    }
}

function Unduh-Dengan-Ulang([string]$Url, [string]$Simpan) {
    for ($coba = 1; $coba -le 3; $coba++) {
        try {
            return (Ambil-File -Url $Url -Simpan $Simpan)
        } catch {
            $pesan = $_.Exception.Message
            Tulis "  gagal (percobaan $coba/3): $pesan"
            Remove-Item -LiteralPath $Simpan -Force -ErrorAction SilentlyContinue
            # Kuota habis tidak akan sembuh dalam hitungan detik; mengulang
            # hanya membuat log ramai.
            if ($pesan -match 'kuota') { break }
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
    # Unduh halaman folder sebagai BYTE, lalu decode sendiri sebagai UTF-8.
    # Inilah satu-satunya cara yang mempertahankan nama CJK di PowerShell 5.1:
    #  - Invoke-WebRequest memakai charset dari header; Drive mengirim tanpa
    #    charset, jadi teksnya dibaca Latin-1 dan CJK berubah jadi '?'.
    #  - Mengubah header Content-Type setelah response tidak berpengaruh.
    # Dengan byte mentah, hasilnya persis seperti yang dikirim Google.
    $url = "https://drive.google.com/drive/folders/$FolderId"
    $minta = [System.Net.WebRequest]::Create($url)
    $minta.UserAgent = $UA
    $minta.Timeout = 60000
    $minta.ReadWriteTimeout = 120000
    $jawab = $minta.GetResponse()
    try {
        $alir = $jawab.GetResponseStream()
        $memori = New-Object System.IO.MemoryStream
        try {
            $alir.CopyTo($memori)
            $byte = $memori.ToArray()
        } finally { $memori.Dispose(); $alir.Dispose() }
    } finally { $jawab.Close() }

    $halaman = [System.Text.Encoding]::UTF8.GetString($byte)
    if ($halaman -notmatch '_DRIVE_ivd') {
        # Cadangan: kalau UTF-8 bukan encoding-nya, coba Latin-1 seperti dulu.
        $halaman = [System.Text.Encoding]::GetEncoding(28591).GetString($byte)
    }

    $m = [regex]::Match($halaman, 'window\[''_DRIVE_ivd''\]\s*=\s*''(.*?)'';', 'Singleline')
    if (-not $m.Success) { throw "folder Drive tidak bisa dibaca (pastikan 'Anyone with the link')" }
    $raw = $m.Groups[1].Value
    $raw = [regex]::Replace($raw, '\\x([0-9a-fA-F]{2})', { param($x) [string][char][Convert]::ToInt32($x.Groups[1].Value, 16) })
    $raw = [regex]::Replace($raw, '\\u([0-9a-fA-F]{4})', { param($x) [string][char][Convert]::ToInt32($x.Groups[1].Value, 16) })
    $raw = $raw.Replace('\\', '\').Replace("\'", "'").Replace('\"', '"').Replace('\/', '/').Replace('\=', '=')
    $data = ConvertFrom-Json -InputObject $raw

    # Entri folder berupa baris [id, [induk], nama, mime, ..., ukuran, ...].
    # Indeks ukuran TIDAK tetap, jadi dicari dengan aturan: angka besar pertama
    # setelah posisi 4. (Indeks 10 berisi timestamp, bukan ukuran.)
    $hasil = New-Object System.Collections.ArrayList
    $antre = New-Object System.Collections.Queue
    $antre.Enqueue(@($data, 0))
    while ($antre.Count -gt 0) {
        $kini = $antre.Dequeue()
        $node = $kini[0]
        $level = [int]$kini[1]
        if ($null -eq $node) { continue }
        if ($node -is [System.Array]) {
            if ($node.Count -ge 5) {
                $id = $node[0]
                $nama = $node[2]
                $mime = $node[3]
                if ($id -is [string] -and $nama -is [string] -and ("$mime" -match 'video|octet-stream')) {
                    $ukuran = 0
                    for ($i = 4; $i -lt $node.Count; $i++) {
                        $v = $node[$i]
                        if ($v -is [int] -or $v -is [long]) {
                            $n = [long]$v
                            # Timestamp dalam milidetik jauh lebih besar dari ukuran file.
                            if ($n -ge 1000000 -and $n -lt 100000000000) { $ukuran = $n; break }
                        }
                    }
                    [void]$hasil.Add([pscustomobject]@{
                        id = $id
                        nama = $nama
                        ukuran = $ukuran
                        url = "https://drive.usercontent.google.com/download?id=$id&export=download&authuser=0"
                    })
                    continue
                }
            }
            if ($level -lt 6) {
                foreach ($anak in $node) {
                    if ($null -ne $anak -and $anak -is [System.Array]) { $antre.Enqueue(@($anak, ($level + 1))) }
                }
            }
        }
    }
    if ($hasil.Count -eq 0) { throw "folder Drive kosong atau tidak bisa dibaca" }
    return , $hasil.ToArray()
}

function Ambil-DaftarPixeldrain([string]$Link) {
    # Daftar file dibaca dari API Pixeldrain (JSON UTF-8). Bisa berupa list
    # (/l/<id>) maupun satu file (/u/<id>).
    $id = if ($Link -match '/l/([A-Za-z0-9_-]+)') { $Matches[1] }
          elseif ($Link -match '/u/([A-Za-z0-9_-]+)') { $Matches[1] }
          else { throw "link Pixeldrain tidak dikenali: $Link" }
    $hasil = New-Object System.Collections.ArrayList
    try {
        $json = Halaman-Drive "https://pixeldrain.com/api/list/$id"
        $data = ConvertFrom-Json -InputObject $json
        foreach ($f in @($data.files)) {
            if ($null -eq $f) { continue }
            $nama = [string]$f.name
            if (-not $nama) { continue }
            [void]$hasil.Add([pscustomobject]@{
                id = [string]$f.id
                nama = $nama
                ukuran = [long]$f.size
                url = "https://pixeldrain.com/api/file/$($f.id)?download"
            })
        }
    } catch {
        throw "list Pixeldrain '$id' tidak bisa dibaca (404 = list dihapus/kedaluwarsa, atau link-nya salah): $($_.Exception.Message)"
    }
    if ($hasil.Count -eq 0) { throw "list Pixeldrain '$id' kosong atau tidak bisa dibaca" }
    return , $hasil.ToArray()
}

function Pasang-Video {
    Tulis '=== VIDEO ==='
    if ($SumberVideo) {
        $daftar = Ambil-DaftarPixeldrain $SumberVideo
        Tulis "$($daftar.Count) file di Pixeldrain."
    } else {
        $folderId = if ($FolderUrl -match 'folders/([A-Za-z0-9_-]+)') { $Matches[1] } else { throw 'link folder Drive tidak dikenali' }
        $daftar = Ambil-DaftarDrive $folderId
        Tulis "$($daftar.Count) file di folder Drive."
    }

    # --- ATUR DI SINI: video mana yang diunduh ---
    # Bawaan: file yang namanya diawali nomor $Nomor (mis. 03.xxx.mp4 untuk RDP 3).
    # Mau ganti aturannya? Ubah satu baris $cocok di bawah. Contoh:
    #   semua file:          $cocok = @($daftar)
    #   hanya yang memuat X: $cocok = @($daftar | Where-Object { $_.nama -match 'X' })
    #   dua nomor sekaligus: $cocok = @($daftar | Where-Object { $_.nama -match '^(03|04)\.' })
    $cocok = @()
    foreach ($f in $daftar) {
        $angka = [regex]::Match($f.nama, '^\s*0*(\d{1,4})(?!\d)')
        if ($angka.Success -and [int]$angka.Groups[1].Value -eq $Nomor) { $cocok += $f }
    }
    # --- akhir bagian atur ---

    if ($cocok.Count -eq 0) { throw "video nomor $Nomor tidak ditemukan di folder" }

    # Video bisa diganti di Drive (hari lain, judul lain, nomor sama), jadi
    # semua file lama bernomor sama dibuang dulu. Tanpa ini isi folder menumpuk.
    $namaBaru = @($cocok | ForEach-Object { Nama-Aman $_.nama })
    foreach ($lama in @(Get-ChildItem -LiteralPath $Tujuan -File -ErrorAction SilentlyContinue)) {
        if ($namaBaru -contains $lama.Name) { continue }
        $nomorLama = [regex]::Match($lama.Name, '^\s*0*(\d{1,4})(?!\d)')
        if ($nomorLama.Success -and [int]$nomorLama.Groups[1].Value -eq $Nomor) {
            Tulis "file lama nomor $Nomor dihapus: $($lama.Name)"
            Remove-Item -LiteralPath $lama.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    foreach ($f in $cocok) {
        $namaFile = Nama-Aman $f.nama
        $tujuan = Join-Path $Tujuan $namaFile
        Tulis "Video nomor $Nomor -> $namaFile"

        if (Test-Path -LiteralPath $tujuan) {
            Tulis "  sudah ada ($(Ukuran (Get-Item -LiteralPath $tujuan).Length)), unduh ulang untuk memastikan lengkap."
            Remove-Item -LiteralPath $tujuan -Force
        }
        $ukuran = Unduh-Dengan-Ulang -Url $f.url -Simpan $tujuan
        if ($f.ukuran -gt 0 -and $ukuran -ne $f.ukuran) {
            Tulis "  PERINGATAN: ukuran $ukuran byte, seharusnya $($f.ukuran) byte."
        }
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

Tulis "LOKASI FILE: $Tujuan"
Buka-Folder $Tujuan

if ($gagal) {
    Tulis 'SELESAI DENGAN MASALAH. Baca baris GAGAL di atas.'
} else {
    Tulis 'SELESAI. Semua langkah berhasil.'
}
