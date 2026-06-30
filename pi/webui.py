#!/usr/bin/env python3
r"""pi-camera-live — browser WebUI: live camera + settings, lowest practical latency.

RUN ON THE PI (over SSH):
    python3 pi/webui.py

Then on your laptop, open a browser (or double-click laptop\open-webui.bat):
    http://<pi-ip>:8080/

WHY MJPEG: each frame is an independent JPEG shown in an <img>, so the browser
has no decode buffer to fill -> very low latency. Keep the resolution modest and
the framerate high for the snappiest feel while focusing the lens.

Stdlib only (no pip installs). Uses rpicam-vid (Bookworm) or libcamera-vid (older).
Stop with Ctrl+C.
"""
import http.server
import shutil
import socket
import socketserver
import subprocess
import threading
import time
import urllib.parse

PORT = 8080

# ---- live capture settings (changed from the web page) ----
settings = {
    "width": 1280, "height": 720, "fps": 30,
    "rotation": 0,            # 0 or 180 on the camera; 90/270 done in the browser (CSS)
    "hflip": 0, "vflip": 0,
    "zoom": 1.0,             # 1.0 = full frame; >1 = digital centre zoom (focus aid)
}


def cam_cmd():
    exe = "rpicam-vid" if shutil.which("rpicam-vid") else "libcamera-vid"
    s = settings
    cmd = [exe, "-t", "0", "-n", "--codec", "mjpeg",
           "--width", str(s["width"]), "--height", str(s["height"]),
           "--framerate", str(s["fps"]), "--flush", "-o", "-"]
    if int(s["rotation"]) == 180:
        cmd += ["--rotation", "180"]
    if int(s["hflip"]):
        cmd += ["--hflip"]
    if int(s["vflip"]):
        cmd += ["--vflip"]
    if float(s["zoom"]) > 1:
        f = round(1.0 / float(s["zoom"]), 4)
        off = round((1 - f) / 2, 4)
        cmd += ["--roi", f"{off},{off},{f},{f}"]
    return cmd


class Camera:
    """Runs the camera as a subprocess, splits its MJPEG byte stream into frames,
    and shares the latest frame with every connected browser."""

    SOI = b"\xff\xd8"   # JPEG start-of-image marker

    def __init__(self):
        self.proc = None
        self.frame = None
        self.cond = threading.Condition()
        self.running = True
        threading.Thread(target=self._run, daemon=True).start()

    def restart(self):
        """Apply new settings by respawning the camera process."""
        if self.proc:
            try:
                self.proc.kill()
            except Exception:
                pass

    def _run(self):
        while self.running:
            try:
                self.proc = subprocess.Popen(cam_cmd(), stdout=subprocess.PIPE,
                                             stderr=subprocess.DEVNULL, bufsize=0)
            except FileNotFoundError:
                print("ERROR: neither rpicam-vid nor libcamera-vid found. Run pi/diagnose.sh")
                return
            buf = b""
            while self.running:
                chunk = self.proc.stdout.read(4096)
                if not chunk:
                    break   # process died (e.g. settings changed) -> respawn below
                buf += chunk
                # cut out complete JPEGs: from one SOI marker to just before the next
                while True:
                    a = buf.find(self.SOI)
                    if a < 0:
                        break
                    b = buf.find(self.SOI, a + 2)
                    if b < 0:
                        break
                    with self.cond:
                        self.frame = buf[a:b]
                        self.cond.notify_all()
                    buf = buf[b:]
            time.sleep(0.2)

    def get(self, last):
        with self.cond:
            self.cond.wait_for(lambda: self.frame is not last, timeout=5)
            return self.frame


camera = Camera()


PAGE = """<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pi Camera - Focus</title>
<style>
 body{margin:0;background:#111;color:#eee;font-family:system-ui,Segoe UI,Arial}
 header{padding:8px 12px;background:#1b1b1b;font-weight:600}
 #wrap{display:flex;justify-content:center;align-items:center;padding:10px;overflow:hidden}
 #cam{max-width:100%;max-height:78vh;background:#000;border:1px solid #333;
      transition:transform .1s}
 .bar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;padding:10px 12px;background:#1b1b1b}
 .bar label{font-size:13px;color:#bbb}
 select,button,input{background:#2a2a2a;color:#eee;border:1px solid #444;border-radius:6px;
      padding:6px 9px;font-size:13px}
 button{cursor:pointer} button:hover{background:#333}
 button.on{background:#2ea043;border-color:#2ea043}
 .tip{color:#888;font-size:12px;padding:0 12px 10px}
</style></head><body>
<header>Pi Camera — live focus view</header>
<div id="wrap"><img id="cam" src="/stream.mjpg"></div>
<div class="bar">
 <label>Res</label>
 <select id="res" onchange="apply()">
   <option value="640x480">640x480 (snappiest)</option>
   <option value="1280x720" selected>1280x720</option>
   <option value="1920x1080">1920x1080</option>
 </select>
 <label>FPS</label>
 <select id="fps" onchange="apply()">
   <option>15</option><option selected>30</option><option>60</option>
 </select>
 <label>Zoom</label>
 <input id="zoom" type="range" min="1" max="6" step="0.5" value="1" oninput="zl.textContent=this.value+'x'" onchange="apply()">
 <span id="zl">1x</span>
 <label>Rotate</label>
 <button onclick="rot(0)">0</button><button onclick="rot(90)">90</button>
 <button onclick="rot(180)">180</button><button onclick="rot(270)">270</button>
 <button id="fh" onclick="flip('hflip',this)">Flip H</button>
 <button id="fv" onclick="flip('vflip',this)">Flip V</button>
</div>
<div class="tip">Tip: zoom in + lower the resolution for the lowest-latency, easiest focusing. Rotate 90/270 is applied in the browser (no extra latency). Lock focus, then glue.</div>
<script>
 let st={rotation:0,hflip:0,vflip:0,cssrot:0};
 const cam=document.getElementById('cam');
 function draw(){cam.style.transform='rotate('+st.cssrot+'deg)';}
 function send(extra){
   const [w,h]=document.getElementById('res').value.split('x');
   const q=new URLSearchParams({width:w,height:h,fps:document.getElementById('fps').value,
     zoom:document.getElementById('zoom').value,rotation:st.rotation,
     hflip:st.hflip,vflip:st.vflip,...extra});
   fetch('/set?'+q.toString());
 }
 function apply(){send({});}
 function rot(d){            // 0/180 on the camera, 90/270 in CSS (free + instant)
   if(d===180){st.rotation=180;st.cssrot=0;}
   else{st.rotation=0;st.cssrot=d;}
   draw(); apply();
 }
 function flip(k,btn){st[k]=st[k]?0:1;btn.classList.toggle('on',!!st[k]);apply();}
</script>
</body></html>"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == "/":
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif u.path == "/set":
            q = urllib.parse.parse_qs(u.query)
            for k in settings:
                if k in q:
                    settings[k] = type(settings[k])(q[k][0])
            camera.restart()
            self.send_response(204)
            self.end_headers()
        elif u.path == "/stream.mjpg":
            self.send_response(200)
            self.send_header("Cache-Control", "no-cache, private")
            self.send_header("Pragma", "no-cache")
            self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=FRAME")
            self.end_headers()
            last = None
            try:
                while True:
                    frame = camera.get(last)
                    last = frame
                    if frame is None:
                        continue
                    self.wfile.write(b"--FRAME\r\n")
                    self.wfile.write(b"Content-Type: image/jpeg\r\n")
                    self.wfile.write(f"Content-Length: {len(frame)}\r\n\r\n".encode())
                    self.wfile.write(frame)
                    self.wfile.write(b"\r\n")
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            self.send_error(404)


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def my_ips():
    ips = []
    try:
        out = subprocess.run(["hostname", "-I"], capture_output=True, text=True, timeout=5)
        ips = out.stdout.split()
    except Exception:
        pass
    if not ips:
        ips = [socket.gethostbyname(socket.gethostname())]
    return ips


if __name__ == "__main__":
    print("=" * 56)
    print(" Pi Camera WebUI is running. Open one of these in a browser:")
    for ip in my_ips():
        print(f"     http://{ip}:{PORT}/")
    print(f"     http://raspberrypi.local:{PORT}/   (if mDNS works)")
    print(" Ctrl+C to stop.")
    print("=" * 56)
    Server(("0.0.0.0", PORT), Handler).serve_forever()
