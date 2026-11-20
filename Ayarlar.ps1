# Ortak ayar yukleyici. Diger script'ler bunu ". (Join-Path $klasor 'Ayarlar.ps1')" ile yukler.
# ayarlar.json yoksa kullaniciya ayarlar.ornek.json'dan kopyalamasini soyler.

Add-Type -AssemblyName PresentationFramework
function Uyari($m) { [System.Windows.MessageBox]::Show($m, 'Discord Tunel') | Out-Null }

$ayarDosyasi = Join-Path $klasor 'ayarlar.json'
if (-not (Test-Path $ayarDosyasi)) {
    Uyari "ayarlar.json bulunamadi.`n`nayarlar.ornek.json dosyasini ayarlar.json adiyla kopyala, icine kendi sunucunu ve SSH anahtarinin yolunu yaz, sonra tekrar dene.`n`nKlasor: $klasor"
    exit 1
}
try { $ayar = Get-Content -Raw -Encoding UTF8 $ayarDosyasi | ConvertFrom-Json }
catch { Uyari "ayarlar.json okunamadi (JSON hatasi):`n$($_.Exception.Message)"; exit 1 }

if (-not $ayar.sunucu -or $ayar.sunucu -like '*ornek*') { Uyari 'ayarlar.json icindeki "sunucu" alanini kendi sunucunla doldur (or. ubuntu@1.2.3.4).'; exit 1 }

$sunucu    = [string]$ayar.sunucu
$anahtar   = [Environment]::ExpandEnvironmentVariables([string]$ayar.anahtar)
$sshPort   = if ($ayar.sshPort) { [int]$ayar.sshPort } else { 22 }
$socks     = if ($ayar.socksPort) { [int]$ayar.socksPort } else { 1080 }
$http      = if ($ayar.httpPort) { [int]$ayar.httpPort } else { 1081 }

if (-not (Test-Path $anahtar)) { Uyari "SSH anahtari bulunamadi: $anahtar`nayarlar.json icindeki ""anahtar"" yolunu kontrol et."; exit 1 }

function Dinliyor($p) { [bool](Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $p -State Listen -ErrorAction SilentlyContinue) }

# ssh -D ile SOCKS tuneli acar; basarisizsa $null doner.
function TunelAc {
    $a = @('-N', '-D', "127.0.0.1:$socks", '-p', "$sshPort", '-i', "`"$anahtar`"",
        '-o', 'BatchMode=yes', '-o', 'ExitOnForwardFailure=yes',
        '-o', 'ServerAliveInterval=20', '-o', 'ServerAliveCountMax=3',
        '-o', 'ConnectTimeout=15', $sunucu)
    $p = Start-Process ssh -ArgumentList $a -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 30 -and -not (Dinliyor $socks) -and -not $p.HasExited; $i++) { Start-Sleep -Milliseconds 500 }
    if (Dinliyor $socks) { return $p }
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    return $null
}

function TunelHatasi {
    Uyari "Sunucuya baglanilamadi ($sunucu).`n`nInternet bagli mi? Sunucu acik mi? Elle denemek icin PowerShell'de:`nssh -p $sshPort -i `"$anahtar`" $sunucu`n`nIlk baglantida sunucunun parmak izini onaylaman gerekir (yes yaz)."
}

function EdgeYolu {
    foreach ($y in "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") {
        if (Test-Path $y) { return $y }
    }
    return $null
}
