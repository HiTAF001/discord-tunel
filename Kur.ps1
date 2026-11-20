# Discord masaustu uygulamasini kurar ve her acilista tunelle calismasini saglar.
#  1) Discord kurulu degilse resmi kurulum dosyasini TUNEL UZERINDEN indirir, imzasini dogrular, kurar
#  2) Baslat menusu / masaustu Discord kisayollarini Discord_Baslat.vbs'ye yonlendirir (asillari yedek\ klasorune)
#  3) Windows acilisindaki "Discord" kaydini "DiscordTunel" ile degistirir
# Sistem ag ayarlarina dokunmaz. Geri almak icin Geri_Al.cmd.
param([switch]$SadeceKisayol)

$ErrorActionPreference = 'Stop'
$klasor = Split-Path -Parent $MyInvocation.MyCommand.Path
$vbs    = Join-Path $klasor 'Discord_Baslat.vbs'
$update = Join-Path $env:LOCALAPPDATA 'Discord\Update.exe'
$ikon   = Join-Path $env:LOCALAPPDATA 'Discord\app.ico'
$yedek  = Join-Path $klasor 'yedek'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

function KisayolDuzelt {
    $sh = New-Object -ComObject WScript.Shell
    $baslat = Join-Path ([Environment]::GetFolderPath('Programs')) 'Discord Inc\Discord.lnk'
    $masaustu = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Discord.lnk'
    if (-not (Test-Path (Split-Path $baslat))) { New-Item -ItemType Directory -Force (Split-Path $baslat) | Out-Null }
    foreach ($lnk in @($baslat, $masaustu)) {
        # Masaustune yeni kisayol ekleme; sadece varsa degistir. Baslat menusu her zaman olusturulur.
        if (-not (Test-Path $lnk) -and $lnk -ne $baslat) { continue }
        if (Test-Path $lnk) {
            $mevcut = $sh.CreateShortcut($lnk)
            if ($mevcut.TargetPath -like '*wscript.exe' -and $mevcut.Arguments -like '*Discord_Baslat.vbs*') { continue }
            New-Item -ItemType Directory -Force $yedek | Out-Null
            Copy-Item $lnk (Join-Path $yedek ($lnk -replace '[:\\]', '_')) -Force
        }
        $k = $sh.CreateShortcut($lnk)
        $k.TargetPath = "$env:WINDIR\System32\wscript.exe"
        $k.Arguments = "`"$vbs`""
        $k.WorkingDirectory = $klasor
        if (Test-Path $ikon) { $k.IconLocation = "$ikon,0" }
        $k.Description = 'Discord (tunelle)'
        $k.Save()
    }
    # Discord kendi kisayollarini acilista/guncellemede yeniden yaziyor; onun dokunmadigi ayri kisayol
    $ayri = Join-Path ([Environment]::GetFolderPath('Programs')) 'Discord Tunel.lnk'
    $k = $sh.CreateShortcut($ayri)
    $k.TargetPath = "$env:WINDIR\System32\wscript.exe"; $k.Arguments = "`"$vbs`""; $k.WorkingDirectory = $klasor
    if (Test-Path $ikon) { $k.IconLocation = "$ikon,0" }
    $k.Description = 'Discord (tunelle)'; $k.Save()
    $eski = (Get-ItemProperty $runKey -Name 'Discord' -ErrorAction SilentlyContinue).Discord
    if ($eski) {
        New-Item -ItemType Directory -Force $yedek | Out-Null
        $eski | Out-File -Encoding utf8 (Join-Path $yedek 'run_Discord.txt')
        Remove-ItemProperty $runKey -Name 'Discord'
    }
    Set-ItemProperty $runKey -Name 'DiscordTunel' -Value "wscript.exe `"$vbs`""
}

if ($SadeceKisayol) { KisayolDuzelt; exit 0 }

. (Join-Path $klasor 'Ayarlar.ps1')

if (-not (Test-Path $update)) {
    # discord.com engelli oldugu icin kurulum dosyasi da tunelden indirilir.
    $ssh = $null
    if (-not (Dinliyor $socks)) { $ssh = TunelAc; if (-not $ssh) { TunelHatasi; exit 1 } }
    $kurulum = Join-Path $env:TEMP 'DiscordSetup.exe'
    try {
        $api = 'https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64'
        & curl.exe -s -f -L -m 600 --socks5-hostname "127.0.0.1:$socks" -o $kurulum $api
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $kurulum)) { Uyari "Discord kurulum dosyasi indirilemedi (curl kodu $LASTEXITCODE)."; exit 1 }
        $imza = Get-AuthenticodeSignature $kurulum
        if ($imza.Status -ne 'Valid' -or $imza.SignerCertificate.Subject -notlike 'CN=Discord Inc.*') {
            Remove-Item $kurulum -Force -ErrorAction SilentlyContinue
            Uyari "Indirilen dosyanin imzasi gecersiz ya da Discord Inc. degil; kurulum durduruldu."; exit 1
        }
        Start-Process $kurulum -Wait
        # Kurulum Discord'u tunelsiz baslatir; kapat (birazdan tunelle acilacak)
        for ($i = 0; $i -lt 30 -and -not (Get-Process Discord -ErrorAction SilentlyContinue); $i++) { Start-Sleep 1 }
        Start-Sleep 3
        Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    finally {
        if ($ssh -and -not $ssh.HasExited) { Stop-Process -Id $ssh.Id -Force -ErrorAction SilentlyContinue }
        Remove-Item $kurulum -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $update)) { Uyari 'Discord kurulamadi.'; exit 1 }
}

KisayolDuzelt
Start-Process wscript.exe -ArgumentList "`"$vbs`""
Uyari "Tamam. Discord tunelle aciliyor.`nBundan sonra Baslat menusundeki Discord kisayolu ve Windows acilisi hep tunelle acar."
