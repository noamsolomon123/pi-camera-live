#!/usr/bin/env python3
# pi-camera-live WebUI - live MJPEG + settings. Defaults: 1920x1080, flipV on.
# Run on the Pi:  python3 webui.py      Open:  http://10.55.0.1:8080/  (USB)
import http.server, socketserver, subprocess, threading, shutil, urllib.parse, time

PORT = 8080
S = {"width": 1920, "height": 1080, "fps": 30, "rotation": 0, "hflip": 0, "vflip": 1, "zoom": 1.0}


def cmd():
    exe = "rpicam-vid" if shutil.which("rpicam-vid") else "libcamera-vid"
    c = [exe, "-t", "0", "-n", "--codec", "mjpeg", "--width", str(S["width"]),
         "--height", str(S["height"]), "--framerate", str(S["fps"]), "--flush", "-o", "-"]
    if int(S["rotation"]) == 180: c += ["--rotation", "180"]
    if int(S["hflip"]): c += ["--hflip"]
    if int(S["vflip"]): c += ["--vflip"]
    if float(S["zoom"]) > 1:
        f = round(1 / float(S["zoom"]), 4); o = round((1 - f) / 2, 4)
        c += ["--roi", f"{o},{o},{f},{f}"]
    return c


class Cam:
    def __init__(self):
        self.proc = None; self.frame = None; self.cv = threading.Condition(); self.last = 0.0
        threading.Thread(target=self.loop, daemon=True).start()
        threading.Thread(target=self.watch, daemon=True).start()

    def restart(self):
        p = self.proc
        if p:
            try: p.kill()
            except Exception: pass

    def watch(self):
        while True:
            time.sleep(1)
            p = self.proc
            if p and self.last and time.monotonic() - self.last > 3:
                try: p.kill()
                except Exception: pass

    def loop(self):
        while True:
            try:
                self.proc = subprocess.Popen(cmd(), stdout=subprocess.PIPE,
                                             stderr=subprocess.DEVNULL, bufsize=0)
            except FileNotFoundError:
                print("ERROR: no rpicam-vid / libcamera-vid"); return
            self.last = time.monotonic(); buf = b""
            while True:
                ch = self.proc.stdout.read(4096)
                if not ch: break
                buf += ch
                while True:
                    a = buf.find(b"\xff\xd8")
                    if a < 0:
                        if len(buf) > 4000000: buf = b""
                        break
                    e = buf.find(b"\xff\xd9", a + 2)
                    if e < 0:
                        if a > 0: buf = buf[a:]
                        break
                    with self.cv:
                        self.frame = buf[a:e + 2]; self.last = time.monotonic(); self.cv.notify_all()
                    buf = buf[e + 2:]
            time.sleep(0.2)

    def get(self, last):
        with self.cv:
            self.cv.wait_for(lambda: self.frame is not last, timeout=5)
            return self.frame


cam = Cam()

PAGE = b"""<!doctype html><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1"><title>Pi Cam</title>
<style>
body{margin:0;background:#111;color:#eee;font-family:sans-serif;text-align:center}
img{max-width:100%;max-height:80vh;background:#000}
.bar{padding:8px;display:flex;gap:10px;justify-content:center;flex-wrap:wrap;align-items:center}
button,select{padding:6px 10px;background:#2a2a2a;color:#eee;border:1px solid #555;border-radius:6px}
</style>
<img id=v src="/stream.mjpg">
<div class=bar>
<select id=res onchange=a()><option>640x480<option>1280x720<option selected>1920x1080</select>
<select id=fps onchange=a()><option>15<option selected>30<option>60</select>
<label>zoom <input id=z type=range min=1 max=6 step=.5 value=1 onchange=a()></label>
<button onclick="r(0)">0</button><button onclick="r(90)">90</button>
<button onclick="r(180)">180</button><button onclick="r(270)">270</button>
<button id=bh onclick="fl(0)">flipH</button><button id=bv onclick="fl(1)">flipV</button>
</div>
<script>
let cr=0,rot=0,hf=0,vf=1;bv.style.background="#2ea043";
function a(){var s=res.value.split("x");
fetch("/set?width="+s[0]+"&height="+s[1]+"&fps="+fps.value+"&zoom="+z.value+"&rotation="+rot+"&hflip="+hf+"&vflip="+vf)}
function r(d){if(d==180){rot=180;cr=0}else{rot=0;cr=d}v.style.transform="rotate("+cr+"deg)";a()}
function fl(k){if(k==0){hf=hf?0:1;bh.style.background=hf?"#2ea043":""}
else{vf=vf?0:1;bv.style.background=vf?"#2ea043":""}a()}
</script>"""


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == "/":
            self.send_response(200); self.send_header("Content-Type", "text/html")
            self.end_headers(); self.wfile.write(PAGE)
        elif u.path == "/set":
            q = urllib.parse.parse_qs(u.query)
            for k in S:
                if k in q: S[k] = type(S[k])(q[k][0])
            cam.restart(); self.send_response(204); self.end_headers()
        elif u.path == "/stream.mjpg":
            self.send_response(200)
            self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=F")
            self.end_headers()
            last = None
            try:
                while True:
                    fr = cam.get(last); last = fr
                    if fr is None: continue
                    self.wfile.write(b"--F\r\nContent-Type: image/jpeg\r\nContent-Length: " +
                                     str(len(fr)).encode() + b"\r\n\r\n" + fr + b"\r\n")
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            self.send_error(404)


class Srv(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    try:
        ips = subprocess.run(["hostname", "-I"], capture_output=True, text=True).stdout.split()
    except Exception:
        ips = []
    print("=" * 50)
    for i in ips:
        print(f"  http://{i}:{PORT}/")
    print(f"  over USB cable:  http://10.55.0.1:{PORT}/")
    print("  Ctrl+C to stop")
    print("=" * 50)
    Srv(("0.0.0.0", PORT), H).serve_forever()
