param(
    [Parameter(Mandatory=$true)]
    [string]$InputDir,

    [Parameter(Mandatory=$true)]
    [string]$OutputDir,

    [ValidateSet("sfx", "bgm")]
    [string]$Kind = "sfx",

    [string]$FfmpegPath = "ffmpeg",

    [double]$SfxTargetLufs = -18.0,
    [double]$BgmTargetLufs = -16.0,
    [double]$TruePeakDb = -1.5,
    [double]$SilenceDb = -45.0,
    [double]$SilenceSeconds = 0.03,
    [int]$OggQuality = 5,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-ToSnakeCase {
    param([string]$Name)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name).ToLowerInvariant()
    $base = $base -replace '[^a-z0-9]+', '_'
    $base = $base.Trim('_')
    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = "audio_asset"
    }
    return "$base.ogg"
}

if (-not (Test-Path -LiteralPath $InputDir -PathType Container)) {
    throw "InputDir does not exist: $InputDir"
}

$ffmpegCommand = $null
if (-not $WhatIf) {
    $ffmpegCommand = Get-Command $FfmpegPath -ErrorAction Stop
}
$resolvedOutput = New-Item -ItemType Directory -Path $OutputDir -Force
$targetLufs = if ($Kind -eq "bgm") { $BgmTargetLufs } else { $SfxTargetLufs }
$extensions = @(".wav", ".mp3", ".ogg", ".flac", ".m4a", ".aiff", ".aif")
$sources = @(Get-ChildItem -LiteralPath $InputDir -File | Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() })

foreach ($source in $sources) {
    $outputName = Convert-ToSnakeCase $source.Name
    $outputPath = Join-Path $resolvedOutput.FullName $outputName
    $filters = @(
        "silenceremove=start_periods=1:start_threshold=${SilenceDb}dB:start_silence=$SilenceSeconds",
        "areverse",
        "silenceremove=start_periods=1:start_threshold=${SilenceDb}dB:start_silence=$SilenceSeconds",
        "areverse",
        "loudnorm=I=${targetLufs}:TP=${TruePeakDb}:LRA=11"
    ) -join ","
    $args = @(
        "-y",
        "-i", $source.FullName,
        "-vn",
        "-af", $filters,
        "-ar", "48000",
        "-c:a", "libvorbis",
        "-q:a", "$OggQuality",
        $outputPath
    )
    if ($WhatIf) {
        Write-Host "Would convert: $($source.FullName) -> $outputPath"
    } else {
        Write-Host "Converting: $($source.Name) -> $outputName"
        & $ffmpegCommand.Source @args
    }
}

Write-Host "Processed $($sources.Count) file(s). Output: $($resolvedOutput.FullName)"
