# Masaustu uygulamasi olmadan: Discord'u ayri bir Edge penceresinde tunelle acar.
# Proxy sadece bu pencereye uygulanir; normal Edge'in ve diger programlarin baglantisi degismez.
# Pencere kapaninca tunel de kapanir.

$ErrorActionPreference = 'Stop'
$klasor = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $klasor 'Ayarlar.ps1')

$profil = Join-Path $env:LOCALAPPDATA 'DiscordTunel\EdgeProfil'
$edge = EdgeYolu
if (-not $edge) { Uyari 'Microsoft Edge bulunamadi.'; exit 1 }

$ssh = $null
if (-not (Dinliyor $socks)) { $ssh = TunelAc; if (-not $ssh) { TunelHatasi; exit 1 } }

# Yeni profilin ilk acilisinda Edge sertifika dogrulayicisini guncelliyor
# (ERR_CERT_VERIFIER_CHANGED) ve sayfa beyaz kaliyor; ilk seferde arka planda isit.
if (-not (Test-Path (Join-Path $profil 'Default'))) {
    Start-Process $edge -ArgumentList @('--headless=new', '--disable-gpu', "--user-data-dir=`"$profil`"", '--no-first-run',
        "--proxy-server=socks5://127.0.0.1:$socks", 'https://discord.com/app') -WindowStyle Hidden | Out-Null
    Start-Sleep 25
    Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -like "*$profil*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep 2
}

Start-Process $edge -ArgumentList @("--user-data-dir=`"$profil`"", '--no-first-run', '--no-default-browser-check',
    "--proxy-server=socks5://127.0.0.1:$socks", '--app=https://discord.com/app') | Out-Null

if ($ssh) {
    Start-Sleep 8
    while ($true) {
        $acik = Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -like "*$profil*" }
        if (-not $acik -or $ssh.HasExited) { break }
        Start-Sleep 5
    }
    if (-not $ssh.HasExited) { Stop-Process -Id $ssh.Id -Force -ErrorAction SilentlyContinue }
}
