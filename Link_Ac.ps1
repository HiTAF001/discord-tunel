# Panodaki linki (or. Discord'un "yeni konumdan giris" dogrulama e-postasindaki link) tunelden acar.
# click.discord.com da engelli oldugu icin bu linkler normal tarayicida acilmaz.
# Tunel acik olmali (Discord_Baslat veya Discord_Web calisiyor olmali).

$klasor = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $klasor 'Ayarlar.ps1')

$profil = Join-Path $env:LOCALAPPDATA 'DiscordTunel\EdgeProfil'
$link = (Get-Clipboard -Raw) -as [string]
if ($link) { $link = $link.Trim() }
if (-not $link -or $link -notmatch '^https?://\S+$') { Uyari "Panoda link yok.`nE-postadaki butona sag tikla > 'Baglanti adresini kopyala', sonra tekrar calistir."; exit 1 }
if (-not (Dinliyor $socks)) { Uyari 'Tunel kapali. Once Discord''u (Discord_Baslat ya da Discord_Web) ac.'; exit 1 }

$edge = EdgeYolu
if (-not $edge) { Uyari 'Microsoft Edge bulunamadi.'; exit 1 }
Start-Process $edge -ArgumentList @("--user-data-dir=`"$profil`"", "--proxy-server=socks5://127.0.0.1:$socks", "`"$link`"") | Out-Null
