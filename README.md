# pi-camera-live

Watch your **Raspberry Pi Zero 2 W** camera **live, with the lowest practical latency** (~0.1–0.2 s), over **one USB cable** to a laptop — made for **focusing the lens** while you watch.

No keyboard or monitor on the Pi. You prepare the SD card once from your computer, plug in a single USB cable, and run a viewer on the laptop.

> "0 latency" isn't physically possible — the Pi has to encode the video, the cable has to carry it, and the laptop has to decode it. This gets as close as practical: smooth enough to turn the lens and see the focus change in real time.

## The big picture

```
[ Pi Zero 2 W + camera ]  --- one USB cable --->  [ laptop ]
   runs:  pi/stream.sh                              runs:  laptop\view.bat
   (waits, then sends video)                        (opens the live window)
```

The Pi pretends to be a small **USB network device** (a "USB Ethernet gadget"), so one cable gives it both power and a network link. It streams H.264 video; the laptop shows it.

## What's in here

```
pi/       scripts that run ON the Pi (over SSH)
laptop/   viewers that run ON the laptop
setup/    one-time headless setup (no keyboard needed)
```

---

## 1) First time only: set up the Pi (no keyboard)

Follow **[setup/headless-usb-setup.md](setup/headless-usb-setup.md)** once. It walks you through preparing the SD card on your computer so the Pi enables SSH and shows up over the USB cable as `raspberrypi.local` — no keyboard or screen ever needed.

Then get these scripts onto the Pi. Easiest:
```
git clone https://github.com/noamsolomon123/pi-camera-live.git
```
(or copy the `pi/` folder over with `scp -r pi yourname@raspberrypi.local:~/`).

## 2) Every time: see the camera

**On the Pi** (over SSH) — start the camera; it then waits:
```
bash pi/diagnose.sh     # first time: tells you which stream script fits
bash pi/stream.sh       # the default; the Pi now waits for the laptop
```

**On the laptop** — open the view:
```
laptop\view.bat
```
A window pops up with the live camera. Turn the lens until it's sharp, then lock the focus.

> Start the **Pi first** — it waits for the laptop to connect.

---

## Easiest viewer: the focus GUI (Windows)

Prefer buttons over typing? Double-click **`laptop\focus-gui.bat`** for a tiny control panel:
- **host / port / fps** fields, big **▶ Live** / **■ Stop** buttons
- **Zoom** slider (magnify the centre to nail focus) + **Rotate** (0/90/180/270), applied live

It does **not** add latency — the panel just launches `ffplay` (the lowest-latency player) with the tuned low-latency flags, and the video shows in ffplay's own window. Start a stream on the Pi first (`bash pi/stream-focus.sh` is best for focusing), then click **▶ Live**.

## Which stream script? (the fallbacks you asked for)

Run `pi/diagnose.sh`; it recommends one. Quick table:

| If…                                       | On the Pi run                   | On the laptop run     |
|-------------------------------------------|---------------------------------|-----------------------|
| Normal (recommended)                      | `bash pi/stream.sh`             | `laptop\view.bat`     |
| **Focusing the lens** (center zoom)       | `bash pi/stream-focus.sh`       | `laptop\view.bat`     |
| Force the **new** command (Bookworm)      | `bash pi/stream-rpicam.sh`      | `laptop\view.bat`     |
| Force the **old** command (Bullseye)      | `bash pi/stream-libcamera.sh`   | `laptop\view.bat`     |
| H.264 looks black / glitchy               | `bash pi/stream-mjpeg.sh`       | `laptop\view.bat mjpeg` |
| Viewer refuses raw H.264                  | `bash pi/stream-mpegts.sh`      | `laptop\view.bat ts`  |
| Using a **USB webcam** (not the Pi camera)| `bash pi/stream-usb-ffmpeg.sh`  | `laptop\view.bat ts`  |

`stream.sh` already auto-detects `rpicam-vid` vs `libcamera-vid`. The "force" scripts are there for when you want to be explicit — e.g. *"libcamera isn't working, use rpicam."*

---

## Rotate / flip the image

Camera mounted upside-down or sideways? Two ways:

- **On the Pi** (no extra latency) — edit the settings block at the top of the stream script:
  `ROTATION=180`, `HFLIP=1`, or `VFLIP=1`. (The Pi can do 0 or 180 only.)
- **On the laptop** (any angle, change instantly while you focus) — use `view.ps1`:
  ```
  powershell -ExecutionPolicy Bypass -File laptop\view.ps1 -Rotate 90
  ```
  `-Rotate` accepts `0`, `90`, `180`, `270`.

---

## Focusing the lens (resolution & zoom)

- **Focus is the same at any resolution.** The lens position is what matters, not how many pixels are read out. Set it sharp in the live view and it'll be sharp in your full-res photos at that distance.
- **Video resolution is smaller than photo resolution** (video mode is binned/cropped for speed) — that does **not** move the focus point. It only means you see less fine detail on screen.
- **Don't crank max resolution to focus.** On the Zero 2 W that just adds lag and drops the framerate, making focusing harder. Instead use **`pi/stream-focus.sh`**, which digitally zooms into the center (`--roi`) so the smallest blur is obvious while staying smooth. Lower `ZOOM` (e.g. `0.25`) to magnify more.

## Want even less latency?

Edit the settings block at the top of the stream script:
- Lower the resolution: `WIDTH=640  HEIGHT=480` (or `320 240`).
- It's already tuned: hardware H.264 encoder, no B-frames (`--profile baseline`), and `--flush` sends every frame immediately.

---

## Troubleshooting

- **Laptop can't reach the Pi** — the USB cable must be in the Pi's **inner** micro-USB port (labelled `USB`, nearest the mini-HDMI), **not** `PWR IN`. Give it ~1 min to boot. If `raspberrypi.local` won't resolve: run `ping raspberrypi.local`, then `arp -a`, find the `169.254.x.x` address, and use it (set `PIHOST` in `view.bat`, or `view.ps1 -PiHost 169.254.x.x`).
- **`ffplay` not found** — `winget install -e --id Gyan.FFmpeg`, then open a **new** terminal.
- **Video won't start / "could not find codec"** — the low-latency probe is tiny. Try `view.bat ts` with `pi/stream-mpegts.sh`, or in `view.ps1` remove `-probesize 32 -analyzeduration 0`.
- **`usb0` gets no IP on Bookworm** — that's the NetworkManager gotcha; see **step 4** in the setup guide.
- **No camera found** — `rpicam-hello --list-cameras`. Reseat the ribbon cable in the CSI port (metal contacts facing the right way).

## Latency, honestly

End-to-end delay is mostly the Pi's encoder (~1 frame on the Zero 2 W's hardware H.264) plus a little for the cable and the laptop decoder — expect roughly **100–200 ms**. Dropping the resolution helps the most.
