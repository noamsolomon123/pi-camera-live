# Headless USB setup (no keyboard, no monitor)

Goal: prepare the SD card on your computer so the **Pi Zero 2 W** boots, enables SSH, and shows up over **one USB cable** as `raspberrypi.local`. You never touch a keyboard or screen on the Pi.

Written for **current Raspberry Pi OS Lite ("Bookworm")**. Notes for the older "Bullseye" are added where they differ.

---

## Step 0 — Flash the SD card (the easy, reliable way)

Use **Raspberry Pi Imager** (https://www.raspberrypi.com/software/). Choose:

- **Device:** Raspberry Pi Zero 2 W
- **OS:** Raspberry Pi OS **Lite**
- **Storage:** your SD card

Before writing, click the **gear / "Edit Settings"** (OS customisation):

- **General tab:** set Hostname = `raspberrypi`; set a **Username + Password** (write them down!).
- **Services tab:** Enable **SSH** → "Use password authentication".

Write the card. Imager creates the user, turns on SSH, and writes a `firstrun.sh` for you. **Leave the card in your computer** and do the steps below.

> On Bookworm the old `pi` / `raspberry` login no longer exists. You MUST set a user (Imager does this). Skipping it makes a headless first boot hang forever.

---

## Where the files live

After flashing, the small FAT partition shows up on your computer as a drive named **`bootfs`** (older images call it `boot`). Every edit below is a file at the **root of that drive**.

(On the running Pi later, that same partition is `/boot/firmware/` — not `/boot/`. Only matters if you edit files over SSH afterwards.)

---

## Step 1 — Enable SSH *(skip if you used Imager's SSH toggle)*

Create an empty file named exactly `ssh` (no extension) at the root of `bootfs`.

Windows PowerShell (if `bootfs` is drive `E:`):
```powershell
New-Item -ItemType File -Path E:\ssh
```
Make sure Windows didn't secretly name it `ssh.txt`.

## Step 2 — Create the user *(skip if you used Imager)*

Create `userconf.txt` at the root of `bootfs` with a single line:
```
yourusername:ENCRYPTED-PASSWORD
```
Generate the hash on any Linux / WSL / Git-Bash:
```
openssl passwd -6
```
Type your password; paste the resulting `$6$...` string after `yourusername:`.

---

## Step 3 — Turn on USB gadget mode

### 3a. `config.txt`
Open `config.txt` on `bootfs`. At the very bottom, under the `[all]` section, add:
```
[all]
dtoverlay=dwc2,dr_mode=peripheral
```
(If there's no `[all]` line, add one just above this line.)

> `dr_mode=peripheral` explicitly forces "device" mode — the safe, predictable choice for the Zero 2 W. Plain `dtoverlay=dwc2` also works on the Zero 2 W; the explicit form just avoids surprises.

### 3b. `cmdline.txt`
Open `cmdline.txt` on `bootfs`. It is **ONE long line — never add a line break.** Find `rootwait` and insert `modules-load=dwc2,g_ether` right after it (spaces separate the tokens):
```
... rootwait modules-load=dwc2,g_ether quiet ...
```
Add only that one token; leave everything else exactly as it was.

---

## Step 4 — Let the gadget get an IP (the Bookworm gotcha)

On Bookworm, **NetworkManager ignores the `usb0` interface by default**, so `raspberrypi.local` often won't work until you fix it. This is the #1 reason people can't connect.

If you used Imager, you have `firstrun.sh` on `bootfs`. Open it and paste this block **just before** the line `rm -f /boot/firstrun.sh`:

```sh
# --- make the USB gadget interface usable by NetworkManager ---
cp /usr/lib/udev/rules.d/85-nm-unmanaged.rules /etc/udev/rules.d/85-nm-unmanaged.rules
sed 's/^[^#]*gadget/#\ &/' -i /etc/udev/rules.d/85-nm-unmanaged.rules

CONNFILE1=/etc/NetworkManager/system-connections/usb0-dhcp.nmconnection
UUID1=$(cat /proc/sys/kernel/random/uuid)
cat <<- EOF >${CONNFILE1}
[connection]
id=usb0-dhcp
uuid=${UUID1}
type=ethernet
interface-name=usb0
autoconnect-priority=100
[ipv4]
dhcp-timeout=3
method=auto
[ipv6]
method=auto
EOF

CONNFILE2=/etc/NetworkManager/system-connections/usb0-ll.nmconnection
UUID2=$(cat /proc/sys/kernel/random/uuid)
cat <<- EOF >${CONNFILE2}
[connection]
id=usb0-ll
uuid=${UUID2}
type=ethernet
interface-name=usb0
autoconnect-priority=50
[ipv4]
method=link-local
EOF

chmod 600 ${CONNFILE1} ${CONNFILE2}
# --- end gadget fix ---
```

> This tries DHCP for 3 seconds, then falls back to a link-local `169.254.x.x` address. We use `cat /proc/sys/kernel/random/uuid` (always present on Lite) instead of the `uuid` tool, which is **not** installed on a Lite image — using `uuid -v4` here would silently produce broken profiles.

(No `firstrun.sh`? Then either use Imager, or do a one-time HDMI+keyboard boot and create those two `.nmconnection` files by hand.)

---

## Step 5 — Plug into the right port

Eject the SD card, put it in the Pi. Connect the USB cable from the laptop to the Pi's **INNER** micro-USB port, labelled **`USB`** (the one closest to the mini-HDMI connector).

Do **NOT** use the outer port labelled `PWR IN` — it has no data lines. The inner `USB` port carries **both power and data**, so a single cable to the laptop is all you need.

Wait ~1–2 minutes for the first boot.

---

## Step 6 — Connect from the laptop

```
ssh yourusername@raspberrypi.local
```
Accept the fingerprint the first time, enter your password. You're in — and no keyboard ever touched the Pi.

If the name doesn't resolve:
```
ping raspberrypi.local        # note the 169.254.x.x it prints
arp -a                        # or find the 169.254.x.x entry here
ssh yourusername@169.254.X.Y
```

> Windows 10 (build 1803+) and Windows 11 resolve `.local` names natively — no Bonjour needed.

---

## Step 7 — Check the camera

```
rpicam-hello --list-cameras
```
(Bullseye: `libcamera-hello --list-cameras`.) Your camera should be listed. Bookworm auto-detects official Pi cameras (`camera_auto_detect=1` is already on) — nothing to enable.

Now run the streaming scripts in `pi/` (see the main [README](../README.md)).

---

## Notes & gotchas

- **Power:** feed the Pi from a real laptop USB port or a powered hub. The Zero 2 W spikes current on boot; a weak port causes boot loops.
- **Windows driver:** the gadget appears to Windows as a "USB Ethernet/RNDIS" device. Windows 10/11 install the driver automatically; very old setups may need a manual RNDIS driver.
- **Bookworm `libcamera-*` removed:** the June 2025 update removed the old `libcamera-vid` / `libcamera-hello` names. On current Bookworm use the `rpicam-*` names (the scripts handle this automatically).
- Bookworm point releases change over time — if something differs, check the official Raspberry Pi documentation.
