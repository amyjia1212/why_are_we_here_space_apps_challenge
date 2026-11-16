# serve_web.ps1
# Plays the web build in your browser without Python (2026-11-15).
# In PowerShell, from the game folder:
#     powershell -ExecutionPolicy Bypass -File serve_web.ps1
# then open http://localhost:8000 . Press Ctrl+C to stop.
param([int]$Port = 8000, [string]$Folder = (Join-Path $PSScriptRoot "build\web"))

$types = @{
  ".html" = "text/html"; ".js" = "application/javascript"; ".wasm" = "application/wasm";
  ".pck" = "application/octet-stream"; ".png" = "image/png"; ".svg" = "image/svg+xml";
  ".json" = "application/json"; ".css" = "text/css"; ".ico" = "image/x-icon"
}
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Folder at http://localhost:$Port/  (Ctrl+C to stop)"
try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $path = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart("/"))
    if ($path -eq "") { $path = "index.html" }
    $file = Join-Path $Folder $path
    $response = $context.Response
    if ((Test-Path $file -PathType Leaf) -and ([IO.Path]::GetFullPath($file)).StartsWith([IO.Path]::GetFullPath($Folder))) {
      $ext = [IO.Path]::GetExtension($file).ToLower()
      $response.ContentType = $(if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" })
      $bytes = [IO.File]::ReadAllBytes($file)
      $response.ContentLength64 = $bytes.Length
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $response.StatusCode = 404
    }
    $response.OutputStream.Close()
  }
} finally {
  $listener.Stop()
}
