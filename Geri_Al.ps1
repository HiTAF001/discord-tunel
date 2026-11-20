# Kur.ps1'in yaptiklarini geri alir: kisayollari ve Discord acilis kaydini eski haline getirir.
$klasor = Split-Path -Parent $MyInvocation.MyCommand.Path
$yedek  = Join-Path $klasor 'yedek'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
Add-Type -AssemblyName PresentationFramework

Remove-ItemProperty $runKey -Name 'DiscordTunel' -ErrorAction SilentlyContinue
$run = Join-Path $yedek 'run_Discord.txt'
if (Test-Path $run) { Set-ItemProperty $runKey -Name 'Discord' -Value ((Get-Content -Raw $run).Trim()) }

$yerler = @(
    (Join-Path ([Environment]::GetFolderPath('Programs')) 'Discord Inc\Discord.lnk'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Discord.lnk')
)
foreach ($lnk in $yerler) {
    $y = Join-Path $yedek ($lnk -replace '[:\\]', '_')
    if (Test-Path $y) { Copy-Item $y $lnk -Force }
}
Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'Discord Tunel.lnk') -Force -ErrorAction SilentlyContinue
[System.Windows.MessageBox]::Show('Kisayollar ve acilis kaydi eski haline getirildi.', 'Discord Tunel') | Out-Null
