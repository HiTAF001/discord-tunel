# discord-tunel

Discord'u **kendi sunucun** üzerinden açan küçük bir Windows aracı. GoodbyeDPI gibi paket oynayan araçlar, VPN uygulaması ya da DNS değişikliği **gerekmez**.

- Sistemin ağ ayarlarına **dokunmaz**: TTL, IPv4/IPv6, DNS, sistem proxy'si olduğu gibi kalır.
- Proxy **yalnızca Discord'a** verilir; tarayıcın, oyunların ve diğer programlar normal internetten devam eder.
- Discord kapanınca tünel de kapanır.

> Gereken tek şey: SSH ile bağlanabildiğin bir Linux sunucu (örneğin Oracle Cloud'un ücretsiz sunucusu, ya da herhangi bir VPS).

## Neden gerekli?

Bazı ağlarda Discord iki katmanlı engelleniyor:

1. **DNS:** `discord.com` sahte bir IP'ye çözülüyor.
2. **SNI filtresi:** Gerçek IP'ye bağlansan bile TLS el sıkışmasındaki alan adı (SNI) görülüp bağlantı kesiliyor. Bu yüzden DNS değiştirmek ya da `hosts` dosyası tek başına yetmiyor.

HTTP/3 (QUIC) bazı ağlarda filtreye takılmıyor, ama Discord'un canlı bağlantısı (`wss://gateway.discord.gg`) TCP üzerinden WebSocket kullandığı için bu yol da yetmiyor.

Bu araç trafiği şifreli bir **SSH tüneliyle** kendi sunucuna taşır; engelleyici sadece sunucuna giden SSH bağlantısını görür.

## Nasıl çalışır?

```
Discord.exe ──(--proxy-server=socks5)──► 127.0.0.1:1080 ─┐
                                                          ├─ ssh -D ──► senin sunucun ──► discord.com
Discord güncelleyicisi ──(HTTPS_PROXY)──► 127.0.0.1:1081 ─┘
                                (kopru.cs: HTTP CONNECT → SOCKS5)
```

- `ssh -D` yerel bir SOCKS5 proxy açar.
- Discord'un Chromium kısmı `--proxy-server=socks5://…` ile bu proxy'yi kullanır (alan adları sunucuda çözülür, sahte DNS devreye girmez).
- Discord'un güncelleyicisi (`updater.node`) SOCKS tanımıyor, sadece `HTTPS_PROXY` ile HTTP proxy kullanıyor. `kopru.cs` bu yüzden küçük bir **HTTP CONNECT → SOCKS5 köprüsü** açar. Sadece `127.0.0.1`'i dinler, dışarıdan erişilemez.
- Sesli sohbetin UDP trafiği proxy'ye girmez, doğrudan gider (Discord'un ses sunucuları genelde engelli değil).

## Kurulum

### 1. Sunucu

Herhangi bir Linux sunucu olur. SSH ile anahtarla girebiliyor olman yeter; sunucuya ekstra bir şey kurman gerekmez (`AllowTcpForwarding` varsayılan olarak açıktır).

Anahtarın yoksa PowerShell'de oluştur:

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\discord_tunel"
```

Oluşan `discord_tunel.pub` içeriğini sunucunda `~/.ssh/authorized_keys` dosyasına ekle (bulut sağlayıcılar bunu sunucu oluştururken de soruyor).

Bir kez elle bağlanıp sunucunun parmak izini onayla (`yes` yaz):

```powershell
ssh -i "$env:USERPROFILE\.ssh\discord_tunel" kullanici@sunucu-ip
```

### 2. Ayarlar

Repoyu indir (**Code → Download ZIP**) ve bir klasöre çıkar. Sonra `ayarlar.ornek.json` dosyasını **`ayarlar.json`** adıyla kopyala ve doldur:

```json
{
  "sunucu": "ubuntu@1.2.3.4",
  "anahtar": "%USERPROFILE%\\.ssh\\discord_tunel",
  "sshPort": 22,
  "socksPort": 1080,
  "httpPort": 1081
}
```

`ayarlar.json` `.gitignore` içinde; sunucu bilgin repoya girmez.

### 3. Kur

`Kur.cmd`'ye çift tıkla. Şunları yapar:

1. Discord kurulu değilse resmi kurulum dosyasını **tünel üzerinden** indirir (discord.com engelli olduğu için), **Discord Inc. imzasını doğrular** ve kurar.
2. Başlat menüsündeki (ve varsa masaüstündeki) Discord kısayolunu tünelli başlatıcıya (`Discord_Baslat.vbs`) çevirir. Asılları `yedek\` klasörüne alır.
3. Windows açılışındaki `Discord` kaydını `DiscordTunel` ile değiştirir.
4. Başlat menüsüne ayrıca **Discord Tunel** kısayolu ekler.

Bundan sonra Discord'u Başlat menüsünden aç. En sağlamı **Discord Tunel** kısayolu: Discord açılışta ve güncellemede kendi kısayollarını yeniden yazabiliyor (başlatıcı bunları Discord açıkken her dakika tekrar düzeltir), ama bu kısayola dokunmuyor. Görev çubuğuna sabitlemek için onu kullan.

> Klasörü kurduktan sonra taşıma; kısayollar bu klasörü gösteriyor. Taşırsan `Kur.cmd`'yi yeniden çalıştır.

## Dosyalar

| Dosya | Ne yapar |
|---|---|
| `Kur.cmd` | Discord'u kurar, kısayolları ve açılış kaydını tünelli başlatıcıya çevirir |
| `Discord_Baslat.vbs` / `.ps1` | Tüneli + köprüyü açar, Discord'u proxy ile başlatır; tünel düşerse yeniden açar, Discord kapanınca hepsini kapatır |
| `kopru.cs` | HTTP CONNECT → SOCKS5 köprüsü (güncelleyici için) |
| `Discord_Web.cmd` | Masaüstü uygulaması olmadan, ayrı bir Edge penceresinde Discord |
| `Link_Ac.cmd` | Panodaki linki (ör. "yeni konumdan giriş" doğrulama e-postası) tünelden açar |
| `Geri_Al.cmd` | Kısayolları ve açılış kaydını eski haline getirir |
| `Ayarlar.ps1` | Ortak ayar yükleyici |

## Sık karşılaşılanlar

- **"Sunucuya bağlanılamadı"**: `ssh -i <anahtar> kullanici@sunucu` komutunu elle dene. İlk bağlantıda parmak izini onaylaman gerekiyor; araç `BatchMode` ile çalıştığı için soru soramaz.
- **Discord doğrulama e-postası istiyor**: Artık sunucunun IP'sinden giriyorsun, Discord bunu "yeni konum" sayıyor. E-postadaki butona sağ tıkla → *Bağlantı adresini kopyala* → `Link_Ac.cmd`. (`click.discord.com` da engelli olduğu için telefondan ya da normal tarayıcıdan açılmaz.) Gelmezse spam klasörüne bak.
- **Discord davet linkinden açıldı, bağlanmıyor**: Tunelsiz açılmış olabilir; Başlat menüsünden aç, başlatıcı tunelsiz Discord'u kapatıp yeniden açar.
- **Web sürümünde ilk açılışta beyaz ekran**: Yeni Edge profilinin ilk açılışında görülen `ERR_CERT_VERIFIER_CHANGED` hatası. Başlatıcı ilk seferde profili arka planda ısıtıyor; yine olursa `Ctrl+Shift+R`.
- **Günlük**: `son_calisma.log` dosyasında başlatıcının ne yaptığı yazar.

## Kaldırma

`Geri_Al.cmd`'yi çalıştır, sonra klasörü sil. Discord'u da kaldırmak istersen Windows *Uygulamalar* bölümünden kaldır.

## Gereksinimler

- Windows 10/11 (PowerShell 5.1, OpenSSH istemcisi ve `curl.exe` Windows ile birlikte gelir)
- SSH ile erişilebilen bir sunucu
- Web sürümü ve `Link_Ac` için Microsoft Edge

## Uyarı

Bu araç kişisel kullanım içindir; trafiği **senin kendi sunucun** üzerinden geçirir. Bulunduğun ülkedeki yasalara ve kullandığın hizmetlerin koşullarına uymak senin sorumluluğundadır. Discord ile bir bağlantısı yoktur.

## Lisans

[MIT](LICENSE)
