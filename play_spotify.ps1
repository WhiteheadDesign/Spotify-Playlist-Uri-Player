param(
    [Parameter(Mandatory=$true)]
    [string]$PlaylistUri,

    [string]$DeviceName,

    [switch]$Shuffle
)

# ===== CONFIG =====
$CLIENT_ID = ""
$CLIENT_SECRET = ""
$REFRESH_TOKEN = "" 

# ===== GET ACCESS TOKEN =====
$pair = "${CLIENT_ID}:${CLIENT_SECRET}"
$base64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair))

$tokenResponse = Invoke-RestMethod -Method Post `
    -Uri "https://accounts.spotify.com/api/token" `
    -Headers @{ Authorization = "Basic $base64" } `
    -Body @{
        grant_type    = "refresh_token"
        refresh_token = $REFRESH_TOKEN
    } `
    -ContentType "application/x-www-form-urlencoded"

$ACCESS_TOKEN = $tokenResponse.access_token

if (-not $ACCESS_TOKEN) {
    Write-Host "Failed to get access token"
    exit 1
}

# ===== GET DEVICES =====
$devicesResponse = Invoke-RestMethod -Method Get `
    -Uri "https://api.spotify.com/v1/me/player/devices" `
    -Headers @{ Authorization = "Bearer $ACCESS_TOKEN" }

$devices = $devicesResponse.devices

if (-not $devices -or $devices.Count -eq 0) {
    Write-Host "No Spotify devices found. Open Spotify first."
    exit 1
}

# ===== SELECT DEVICE =====
if ($DeviceName) {
    $device = $devices | Where-Object { $_.name -like "*$DeviceName*" } | Select-Object -First 1

    if (-not $device) {
        Write-Host "Device '$DeviceName' not found."
        Write-Host "Available devices:"
        $devices | ForEach-Object { Write-Host " - $($_.name)" }
        exit 1
    }
} else {
    $device = $devices | Select-Object -First 1
}

$DEVICE_ID = $device.id
Write-Host "Using device: $($device.name)"

# ===== ENABLE SHUFFLE (optional) =====
if ($Shuffle) {
    Invoke-RestMethod -Method Put `
        -Uri "https://api.spotify.com/v1/me/player/shuffle?state=true&device_id=$DEVICE_ID" `
        -Headers @{ Authorization = "Bearer $ACCESS_TOKEN" }
}

# ===== START PLAYBACK =====
Invoke-RestMethod -Method Put `
    -Uri "https://api.spotify.com/v1/me/player/play?device_id=$DEVICE_ID" `
    -Headers @{
        Authorization = "Bearer $ACCESS_TOKEN"
        "Content-Type" = "application/json"
    } `
    -Body (@{
        context_uri = $PlaylistUri
    } | ConvertTo-Json)

Write-Host "Playing $PlaylistUri"