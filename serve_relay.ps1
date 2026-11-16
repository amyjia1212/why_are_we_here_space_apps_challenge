# serve_relay.ps1
# Runs the party relay on this computer (MULTIPLAYER_PLAN_V6 section 4), so
# game windows on this computer (or on the same Wi-Fi) can make and join parties.
# In PowerShell, from the game folder:
#     powershell -ExecutionPolicy Bypass -File serve_relay.ps1
# Leave the window open while you play. Press Ctrl+C to stop.
# The game finds it at ws://localhost:9080 while data/multiplayer.json
# "relay_url" still says PLACEHOLDER.
param(
  [int]$Port = 9080,
  [string]$Godot = "C:\Users\holde\Downloads\Godot_v4.7.2-stable_win64 (1).exe"
)
if (-not (Test-Path $Godot)) {
  Write-Host "Godot was not found at $Godot. Run again with -Godot ""<path to Godot.exe>""."
  exit 1
}
$relay = Join-Path $PSScriptRoot "relay"
Write-Host "Party relay on port $Port. Keep this window open while you play (Ctrl+C stops it)."
& $Godot --headless --path $relay -s relay.gd -- $Port
