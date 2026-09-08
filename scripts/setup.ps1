$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$runtimeRoot = Join-Path $projectRoot '.runtime'
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null

function Get-Download([string]$Url, [string]$Destination) {
    if (Test-Path -LiteralPath $Destination) { return }
    Write-Host "Download: $Url"
    & curl.exe --silent --show-error --fail --location --retry 3 --output "$Destination.partial" $Url
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
    Move-Item -LiteralPath "$Destination.partial" -Destination $Destination
}

$ffmpegZip = Join-Path $runtimeRoot 'ffmpeg.zip'
Get-Download 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' $ffmpegZip
if (-not (Test-Path "$runtimeRoot/ffmpeg")) {
    Expand-Archive -LiteralPath $ffmpegZip -DestinationPath "$runtimeRoot/ffmpeg"
}
$whisperZip = Join-Path $runtimeRoot 'whisper.zip'
Get-Download 'https://github.com/ggml-org/whisper.cpp/releases/download/b4938/whisper-cublas-12.4.0-bin-x64.zip' $whisperZip
if (-not (Test-Path "$runtimeRoot/whisper")) {
    Expand-Archive -LiteralPath $whisperZip -DestinationPath "$runtimeRoot/whisper"
}
$ollamaZip = Join-Path $runtimeRoot 'ollama.zip'
Get-Download 'https://github.com/ollama/ollama/releases/download/v0.33.3/ollama-windows-amd64.zip' $ollamaZip
if (-not (Test-Path "$runtimeRoot/ollama/ollama.exe")) {
    Expand-Archive -LiteralPath $ollamaZip -DestinationPath "$runtimeRoot/ollama" -Force
}
Get-Download 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin' "$runtimeRoot/ggml-large-v3-turbo.bin"
Get-Download 'https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin' "$runtimeRoot/ggml-silero-v5.1.2.bin"
$ffmpegExe = Get-ChildItem "$runtimeRoot/ffmpeg" -Filter ffmpeg.exe -Recurse | Select-Object -First 1
$ffprobeExe = Get-ChildItem "$runtimeRoot/ffmpeg" -Filter ffprobe.exe -Recurse | Select-Object -First 1
$whisperExe = Get-ChildItem "$runtimeRoot/whisper" -Filter whisper-cli.exe -Recurse | Select-Object -First 1
if (-not $ffmpegExe -or -not $ffprobeExe -or -not $whisperExe) { throw 'Missing downloaded executable' }
$runtimeConfig = @{
    ffmpeg = $ffmpegExe.FullName
    ffprobe = $ffprobeExe.FullName
    whisper = $whisperExe.FullName
    whisperModel = "$runtimeRoot/ggml-large-v3-turbo.bin"
    vadModel = "$runtimeRoot/ggml-silero-v5.1.2.bin"
    ollama = "$runtimeRoot/ollama/ollama.exe"
    ollamaUrl = 'http://127.0.0.1:11435'
    summaryModel = 'qwen3:8b'
    useGpu = $true
}
# Preserve the optional voice engine when reinstalling the base engines.
if (Test-Path -LiteralPath "$runtimeRoot/runtime.json") {
    $previousConfig = Get-Content -LiteralPath "$runtimeRoot/runtime.json" -Raw | ConvertFrom-Json
    foreach ($key in @('diarization', 'speakerSegmentation', 'speakerEmbedding')) {
        if ($previousConfig.$key) { $runtimeConfig[$key] = $previousConfig.$key }
    }
}
$runtimeConfig | ConvertTo-Json | Set-Content -LiteralPath "$runtimeRoot/runtime.json.tmp" -Encoding utf8
Move-Item -LiteralPath "$runtimeRoot/runtime.json.tmp" -Destination "$runtimeRoot/runtime.json" -Force

$env:OLLAMA_HOST = '127.0.0.1:11435'
$env:OLLAMA_MODELS = "$runtimeRoot/ollama-models"
$env:OLLAMA_NO_CLOUD = '1'
try { $null = Invoke-RestMethod 'http://127.0.0.1:11435/api/tags' } catch {
    Start-Process -FilePath "$runtimeRoot/ollama/ollama.exe" -ArgumentList 'serve' -WindowStyle Hidden -RedirectStandardOutput "$runtimeRoot/ollama-server.log" -RedirectStandardError "$runtimeRoot/ollama-server-error.log"
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        try { $null = Invoke-RestMethod 'http://127.0.0.1:11435/api/tags'; $ready = $true; break } catch { Start-Sleep -Seconds 1 }
    }
    if (-not $ready) { throw 'Ollama did not start; inspect .runtime/ollama-server-error.log' }
}
& "$runtimeRoot/ollama/ollama.exe" pull qwen3:8b
if ($LASTEXITCODE -ne 0) { throw 'Model download failed' }
Write-Host 'Local engines ready. No cloud model enabled.'
