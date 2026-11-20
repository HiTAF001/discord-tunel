// Yerel HTTP CONNECT proxy -> SOCKS5 (ssh -D) koprusu.
// Discord'un guncelleyicisi (updater.node) SOCKS degil HTTP proxy tanidigi icin gerekli.
// Sadece 127.0.0.1'i dinler; disaridan erisilemez.
using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

public static class DiscordKopru
{
    static int socksPort;

    public static void Baslat(int dinlePort, int socksPortu)
    {
        socksPort = socksPortu;
        var l = new TcpListener(IPAddress.Loopback, dinlePort);
        l.Start();
        var t = new Thread(() => {
            while (true)
            {
                try { var c = l.AcceptTcpClient(); ThreadPool.QueueUserWorkItem(_ => Isle(c)); }
                catch { Thread.Sleep(200); }
            }
        });
        t.IsBackground = true;
        t.Start();
    }

    static void Oku(NetworkStream s, byte[] b, int n)
    {
        int o = 0;
        while (o < n) { int r = s.Read(b, o, n - o); if (r <= 0) throw new Exception("kapandi"); o += r; }
    }

    static void Isle(TcpClient c)
    {
        TcpClient s = null;
        try
        {
            c.NoDelay = true;
            var cs = c.GetStream();
            // HTTP basligini oku
            var hdr = new StringBuilder(); var one = new byte[1];
            while (!hdr.ToString().EndsWith("\r\n\r\n"))
            {
                if (cs.Read(one, 0, 1) <= 0) return;
                hdr.Append((char)one[0]);
                if (hdr.Length > 16384) return;
            }
            var ilk = hdr.ToString().Split(new[] { "\r\n" }, StringSplitOptions.None)[0].Split(' ');
            if (ilk.Length < 2 || !ilk[0].Equals("CONNECT", StringComparison.OrdinalIgnoreCase))
            {
                var hata = Encoding.ASCII.GetBytes("HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\n\r\n");
                cs.Write(hata, 0, hata.Length); return;
            }
            string host = ilk[1]; int port = 443;
            int ix = host.LastIndexOf(':');
            if (ix > 0) { port = int.Parse(host.Substring(ix + 1)); host = host.Substring(0, ix); }
            host = host.Trim('[', ']');

            // SOCKS5 el sikismasi (kimlik dogrulamasiz, alan adi uzakta cozulur)
            s = new TcpClient("127.0.0.1", socksPort); s.NoDelay = true;
            var ss = s.GetStream();
            ss.Write(new byte[] { 5, 1, 0 }, 0, 3);
            var b = new byte[512]; Oku(ss, b, 2);
            if (b[1] != 0) throw new Exception("socks auth");
            var hb = Encoding.ASCII.GetBytes(host);
            var req = new byte[7 + hb.Length];
            req[0] = 5; req[1] = 1; req[2] = 0; req[3] = 3; req[4] = (byte)hb.Length;
            Buffer.BlockCopy(hb, 0, req, 5, hb.Length);
            req[5 + hb.Length] = (byte)(port >> 8); req[6 + hb.Length] = (byte)(port & 255);
            ss.Write(req, 0, req.Length);
            Oku(ss, b, 4);
            if (b[1] != 0) throw new Exception("socks connect " + b[1]);
            int alen = b[3] == 1 ? 4 : b[3] == 4 ? 16 : -1;
            if (alen < 0) { Oku(ss, b, 1); alen = b[0]; }
            Oku(ss, b, alen + 2);

            var ok = Encoding.ASCII.GetBytes("HTTP/1.1 200 Connection Established\r\n\r\n");
            cs.Write(ok, 0, ok.Length);

            var sc = s;
            var t = new Thread(() => Aktar(ss, cs, c, sc)); t.IsBackground = true; t.Start();
            Aktar(cs, ss, c, s);
        }
        catch
        {
            try { c.Close(); } catch { }
            try { if (s != null) s.Close(); } catch { }
        }
    }

    static void Aktar(NetworkStream from, NetworkStream to, TcpClient a, TcpClient b)
    {
        var buf = new byte[65536];
        try { int n; while ((n = from.Read(buf, 0, buf.Length)) > 0) to.Write(buf, 0, n); }
        catch { }
        try { a.Close(); } catch { }
        try { b.Close(); } catch { }
    }
}
