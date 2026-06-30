# ===========================================================
#  view.ps1  —  open the live camera view (PowerShell, more options)
# ===========================================================
#  Examples:
#     .\view.ps1
#     .\view.ps1 -PiHost 169.254.10.20
#     .\view.ps1 -Rotate 90
#     .\view.ps1 -Codec mjpeg
#     .\view.ps1 -Codec ts
#
#  Run from a terminal in the 'laptop' folder. If Windows blocks
#  the script, start it like this:
#     powershell -ExecutionPolicy Bypass -File view.ps1 -Rotate 90
# ===========================================================
param(
  [string]$PiHost = "raspberrypi.local",
  [int]$Port = 8888,
  [int]$Fps = 30,
  [ValidateSet("h264","mjpeg","ts")] [string]$Codec = "h264",
  [ValidateSet(0,90,180,270)] [int]$Rotate = 0
)

# 1) is ffplay installed?
if (-not (Get-Command ffplay -ErrorAction SilentlyContinue)) {
  Write-Host "ffplay not found. Install FFmpeg, then reopen this window:" -ForegroundColor Yellow
  Write-Host "    winget install -e --id Gyan.FFmpeg" -ForegroundColor Cyan
  exit 1
}

# 2) can we reach the Pi?
Write-Host "Checking $PiHost ..."
if (-not (Test-Connection -ComputerName $PiHost -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
  Write-Host "Could not ping $PiHost." -ForegroundColor Yellow
  Write-Host "Check: USB cable in the Pi's INNER 'USB' port? Pi booted (~1 min)?" -ForegroundColor Yellow
  Write-Host "If the name won't resolve: run 'ping $PiHost', then 'arp -a', find the" -ForegroundColor Yellow
  Write-Host "169.254.x.x address and pass it with  -PiHost 169.254.x.x" -ForegroundColor Yellow
}

# 3) build the -vf filter chain
#    - raw H.264 has no timestamps, so we add setpts (must match the Pi's fps)
#    - rotation is done here so you can spin the image without restarting the Pi
$filters = @()
if ($Codec -eq "h264") { $filters += "setpts=N/$Fps" }
switch ($Rotate) {
  90  { $filters += "transpose=1" }              # 90 clockwise
  180 { $filters += "transpose=2,transpose=2" }  # 180
  270 { $filters += "transpose=2" }              # 90 counter-clockwise
}

# 4) assemble ffplay arguments
$ff = @("-hide_banner","-fflags","nobuffer","-flags","low_delay","-framedrop",
        "-probesize","32","-analyzeduration","0","-sync","ext","-an")
if ($Codec -eq "mjpeg") { $ff += @("-f","mjpeg") }
if ($filters.Count -gt 0) { $ff += @("-vf", ($filters -join ",")) }
$ff += @("-window_title","Pi Camera (focus me)","tcp://${PiHost}:$Port")

Write-Host "Opening live view from tcp://${PiHost}:$Port   (codec=$Codec rotate=$Rotate)"
Write-Host "Close the video window or press Ctrl+C to stop."
ffplay @ff
