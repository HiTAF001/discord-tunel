# Discord masaustu uygulamasini kendi sunucun uzerinden (SSH SOCKS tuneli) acar.
#  - ssh -D <socksPort> : SOCKS tuneli (Discord'un Chromium kismi bunu kullanir)
#  - kopru <httpPort>   : HTTP->SOCKS koprusu (Discord'un guncelleyicisi sadece HTTP proxy taniyor)
# Sistem ayarlarina (TTL, IPv4/IPv6, DNS, sistem proxy'si) DOKUNMAZ; proxy sadece Discord'a verilir.
# Discord tamamen kapaninca (tepsiden de cikinca) tunel ve kopru kapanir.

$ErrorActionPreference = 'Stop'
$klasor = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $klasor 'Ayarlar.ps1')

$update = Join-Path $env:LOCALAPPDATA 'Discord\Update.exe'
$log    = Join-Path $klasor 'son_calisma.log'
function Yaz($m) { try { "[{0:yyyy-MM-dd HH:mm:ss}] $m" -f (Get-Date) | Out-File -Append -Encoding utf8 $log } catch {} }
function DiscordSureclari { @(Get-CimInstance Win32_Process -Filter "Name='Discord.exe'" -ErrorAction SilentlyContinue) }

if (-not (Test-Path $update)) { Uyari "Discord kurulu degil.`nOnce Kur.cmd'yi calistir."; exit 1 }

# Baska bir baslatici zaten tuneli ve kopruyu tutuyorsa sadece Discord'u one getirip cik.
$sahip = -not ((Dinliyor $socks) -and (Dinliyor $http))

# Discord proxy'siz acilmissa (or. kendi guncellemesi, davet linki) kapat, tunelle yeniden ac.
$proxysiz = DiscordSureclari | Where-Object { $_.CommandLine -notlike '*--proxy-server=*' -and $_.CommandLine -notlike '*--type=*' }
if ($proxysiz) { Yaz 'proxy''siz Discord bulundu, kapatiliyor'; Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2 }

$ssh = $null
if ($sahip) {
    if (-not (Dinliyor $socks)) {
        $ssh = TunelAc
        if (-not $ssh) { Yaz 'tunel acilamadi'; TunelHatasi; exit 1 }
        Yaz "tunel acildi (pid $($ssh.Id))"
    }
    if (-not (Dinliyor $http)) {
        Add-Type -TypeDefinition (Get-Content -Raw (Join-Path $klasor 'kopru.cs'))
        [DiscordKopru]::Baslat($http, $socks)
        Yaz 'kopru acildi'
    }
}

# Discord'u proxy ile baslat (guncelleyici ortam degiskenlerini okur)
$env:HTTPS_PROXY = "http://127.0.0.1:$http"; $env:HTTP_PROXY = $env:HTTPS_PROXY; $env:ALL_PROXY = $env:HTTPS_PROXY
$env:NO_PROXY = 'localhost,127.0.0.1'
Start-Process $update -ArgumentList @('--processStart', 'Discord.exe', '--process-start-args', "`"--proxy-server=socks5://127.0.0.1:$socks`"") | Out-Null
Yaz 'Discord baslatildi'
function KisayolDuzelt { try { & (Join-Path $klasor 'Kur.ps1') -SadeceKisayol } catch { Yaz "kisayol duzeltme hatasi: $_" } }
if (-not $sahip) { Start-Sleep 20; KisayolDuzelt; exit 0 }

# Discord acilista kendi "Discord" kaydini ve guncellemede kisayollarini geri yazabiliyor;
# onlari tekrar tunelli baslaticiya yonlendir (yoksa tunelsiz acilip takilir).
Start-Sleep 20
KisayolDuzelt

# Discord acik oldukca bekle; tunel duserse yeniden ac.
$bos = 0; $tur = 0
while ($true) {
    Start-Sleep 5
    $tur++; if ($tur % 12 -eq 0) { KisayolDuzelt }
    if ((DiscordSureclari).Count -eq 0) { $bos++; if ($bos -ge 3) { break } } else { $bos = 0 }
    if (-not (Dinliyor $socks)) {
        Yaz 'tunel dustu, yeniden aciliyor'
        if ($ssh -and -not $ssh.HasExited) { Stop-Process -Id $ssh.Id -Force -ErrorAction SilentlyContinue }
        $ssh = TunelAc
    }
}
if ($ssh -and -not $ssh.HasExited) { Stop-Process -Id $ssh.Id -Force -ErrorAction SilentlyContinue }
Yaz 'Discord kapandi, tunel kapatildi'
