# ===========================================================
#  focus-gui.ps1  —  tiny control panel for the live camera view.
# ===========================================================
#  WHY this design: the actual video is drawn by FFPLAY (the
#  lowest-latency player there is). This little window is JUST a
#  control panel that launches ffplay with the right flags.
#  No custom video decoder here = ZERO added latency. The video
#  opens in its own ffplay window.
#
#  STEP 1 - on the Pi (over SSH) start a stream, e.g.:
#     bash pi/stream.sh          (full frame)
#     bash pi/stream-focus.sh    (center zoom - best to nail focus)
#  STEP 2 - here, click  > Live.
#
#  Easiest launch: double-click  focus-gui.bat
# ===========================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:proc = $null

function Test-Ffplay { [bool](Get-Command ffplay -ErrorAction SilentlyContinue) }

function Stop-Stream {
  if ($script:proc -and -not $script:proc.HasExited) { try { $script:proc.Kill() } catch {} }
  $script:proc = $null
}

function Start-Stream($PiHost, $Port, $Fps, $Mode, $Rotate, $Zoom) {
  Stop-Stream
  $vf = @()
  if ($Mode -eq 'h264') { $vf += "setpts=N/$Fps" }      # raw H.264 carries no timestamps
  if ($Zoom -gt 1) {
    $f = [math]::Round(1.0 / $Zoom, 4)                   # center-crop fraction (digital zoom)
    $vf += "crop=iw*${f}:ih*${f}"
    $vf += "scale=1280:-2"
  }
  switch ($Rotate) {
    90  { $vf += "transpose=1" }                          # 90 clockwise
    180 { $vf += "transpose=2,transpose=2" }              # 180
    270 { $vf += "transpose=2" }                          # 90 counter-clockwise
  }
  # the low-latency flag set (same as view.bat / view.ps1)
  $a = @('-hide_banner','-fflags','nobuffer','-flags','low_delay','-framedrop',
         '-probesize','32','-analyzeduration','0','-sync','ext','-an')
  if ($Mode -eq 'mjpeg') { $a += @('-f','mjpeg') }
  if ($vf.Count) { $a += @('-vf', ($vf -join ',')) }
  $a += @('-window_title', "Pi Camera Focus (${Zoom}x)", "tcp://${PiHost}:$Port")
  $script:proc = Start-Process ffplay -ArgumentList $a -PassThru
}

# ---------------- build the window ----------------
$form = New-Object Windows.Forms.Form
$form.Text = "Pi Camera - Focus"
$form.Size = New-Object Drawing.Size(380, 310)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.Topmost = $true

function Add-Label($text, $x, $y, $w = 70) {
  $l = New-Object Windows.Forms.Label
  $l.Text = $text; $l.Location = New-Object Drawing.Point($x, $y)
  $l.Size = New-Object Drawing.Size($w, 22); $form.Controls.Add($l); $l
}
function Add-Text($val, $x, $y, $w) {
  $t = New-Object Windows.Forms.TextBox
  $t.Text = $val; $t.Location = New-Object Drawing.Point($x, $y)
  $t.Size = New-Object Drawing.Size($w, 22); $form.Controls.Add($t); $t
}

Add-Label "Pi host:" 14 18 | Out-Null
$tbHost = Add-Text "raspberrypi.local" 90 16 180
Add-Label "Port:" 14 48 | Out-Null
$tbPort = Add-Text "8888" 90 46 60
Add-Label "FPS:" 170 48 35 | Out-Null
$tbFps  = Add-Text "30" 210 46 60

Add-Label "Mode:" 14 80 | Out-Null
$cbMode = New-Object Windows.Forms.ComboBox
$cbMode.Location = New-Object Drawing.Point(90, 78); $cbMode.Size = New-Object Drawing.Size(80, 22)
$cbMode.DropDownStyle = "DropDownList"; @('h264','mjpeg','ts') | ForEach-Object { [void]$cbMode.Items.Add($_) }
$cbMode.SelectedIndex = 0; $form.Controls.Add($cbMode)

Add-Label "Rotate:" 185 80 50 | Out-Null
$cbRot = New-Object Windows.Forms.ComboBox
$cbRot.Location = New-Object Drawing.Point(240, 78); $cbRot.Size = New-Object Drawing.Size(70, 22)
$cbRot.DropDownStyle = "DropDownList"; @('0','90','180','270') | ForEach-Object { [void]$cbRot.Items.Add($_) }
$cbRot.SelectedIndex = 0; $form.Controls.Add($cbRot)

$lblZoom = Add-Label "Zoom: 1.0x" 14 116 120
$zoomBar = New-Object Windows.Forms.TrackBar
$zoomBar.Location = New-Object Drawing.Point(120, 110); $zoomBar.Size = New-Object Drawing.Size(230, 40)
$zoomBar.Minimum = 10; $zoomBar.Maximum = 60; $zoomBar.Value = 10; $zoomBar.TickFrequency = 10
$form.Controls.Add($zoomBar)

$status = Add-Label "" 14 210 350
$status.ForeColor = [Drawing.Color]::DimGray

$btnLive = New-Object Windows.Forms.Button
$btnLive.Text = "> Live"; $btnLive.Location = New-Object Drawing.Point(14, 158)
$btnLive.Size = New-Object Drawing.Size(160, 44); $btnLive.BackColor = [Drawing.Color]::FromArgb(46,160,67)
$btnLive.ForeColor = [Drawing.Color]::White; $btnLive.Font = New-Object Drawing.Font("Segoe UI", 11, [Drawing.FontStyle]::Bold)
$form.Controls.Add($btnLive)

$btnStop = New-Object Windows.Forms.Button
$btnStop.Text = "[] Stop"; $btnStop.Location = New-Object Drawing.Point(190, 158)
$btnStop.Size = New-Object Drawing.Size(160, 44); $btnStop.Font = New-Object Drawing.Font("Segoe UI", 11)
$form.Controls.Add($btnStop)

# ---------------- behaviour ----------------
$go = {
  if (-not (Test-Ffplay)) {
    $status.Text = "ffplay not found -> winget install -e --id Gyan.FFmpeg (then reopen)"
    return
  }
  $z = [math]::Round($zoomBar.Value / 10.0, 1)
  $p = 8888; [int]::TryParse($tbPort.Text, [ref]$p) | Out-Null
  $fp = 30; [int]::TryParse($tbFps.Text, [ref]$fp) | Out-Null
  Start-Stream $tbHost.Text $p $fp $cbMode.SelectedItem ([int]$cbRot.SelectedItem) $z
  $status.Text = "Live  tcp://$($tbHost.Text):$p   zoom ${z}x   rot $($cbRot.SelectedItem)   mode $($cbMode.SelectedItem)"
}
# relaunch live when zoom/rotate/mode change, so tweaks take effect instantly
$reapply = { if ($script:proc -and -not $script:proc.HasExited) { & $go } }

$btnLive.Add_Click($go)
$btnStop.Add_Click({ Stop-Stream; $status.Text = "Stopped." })
$zoomBar.Add_Scroll({ $lblZoom.Text = "Zoom: $([math]::Round($zoomBar.Value/10.0,1))x"; & $reapply })
$cbRot.Add_SelectedIndexChanged($reapply)
$cbMode.Add_SelectedIndexChanged($reapply)
$form.Add_FormClosing({ Stop-Stream })

$status.Text = "On the Pi run a stream (pi/stream-focus.sh), then click > Live."
[void]$form.ShowDialog()
