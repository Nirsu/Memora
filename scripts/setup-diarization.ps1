$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $projectRoot '.runtime/runtime.json'
if (-not (Test-Path -LiteralPath $configPath)) { throw 'Run scripts/setup.ps1 first' }
$engineRoot = Join-Path $projectRoot '.runtime/diarization'
New-Item -ItemType Directory -Force -Path $engineRoot | Out-Null

function Get-EngineFile([string]$Url, [string]$Name) {
    $destination = Join-Path $engineRoot $Name
    if (-not (Test-Path -LiteralPath $destination)) {
        Write-Host "Download: $Name"
        & curl.exe --silent --show-error --fail --location --retry 3 --output "$destination.partial" $Url
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Name" }
        Move-Item -LiteralPath "$destination.partial" -Destination $destination
    }
    return $destination
}

$version = '1.13.7'
$archiveName = "sherpa-onnx-v$version-win-x64-shared-MT-Release-no-tts"
$archive = Get-EngineFile "https://github.com/k2-fsa/sherpa-onnx/releases/download/v$version/$archiveName.tar.bz2" "$archiveName.tar.bz2"
$segmentation = Get-EngineFile 'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2' 'segmentation.tar.bz2'
$embedding = Get-EngineFile 'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/nemo_en_titanet_large.onnx' 'nemo_en_titanet_large.onnx'
foreach ($item in @($archive, $segmentation)) {
    $entries = & tar.exe -tf $item
    if ($LASTEXITCODE -ne 0 -or ($entries | Where-Object { $_ -match '(^[/\\]|^[a-zA-Z]:|(^|[/\\])\.\.([/\\]|$))' })) {
        throw 'Invalid archive paths'
    }
    & tar.exe -xf $item -C $engineRoot
    if ($LASTEXITCODE -ne 0) { throw 'Archive extraction failed' }
}
$exe = Get-ChildItem -LiteralPath (Join-Path $engineRoot $archiveName) -Recurse -Filter 'sherpa-onnx-offline-speaker-diarization.exe' | Select-Object -First 1
$model = Join-Path $engineRoot 'sherpa-onnx-pyannote-segmentation-3-0/model.onnx'
if (-not $exe -or -not (Test-Path -LiteralPath $model)) { throw 'Diarization files missing' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$config | Add-Member -NotePropertyName diarization -NotePropertyValue $exe.FullName -Force
$config | Add-Member -NotePropertyName speakerSegmentation -NotePropertyValue $model -Force
$config | Add-Member -NotePropertyName speakerEmbedding -NotePropertyValue $embedding -Force
$config | ConvertTo-Json | Set-Content -LiteralPath "$configPath.tmp" -Encoding utf8
Move-Item -LiteralPath "$configPath.tmp" -Destination $configPath -Force
Write-Host 'Speaker detection installed locally. No recording is uploaded.'
