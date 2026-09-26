# build.ps1
# Combines the three .vstheme files into a single XML with <Themes> root,
# then compiles them into AyuTheme.pkgdef using the VSIX Color Compiler.

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

# --- Locate VsixColorCompiler ---
$compilerPaths = @(
    "C:\Program Files\Microsoft Visual Studio\18\Community\VSSDK\VisualStudioIntegration\Tools\Bin\VsixColorCompiler.exe",
    "C:\Program Files\Microsoft Visual Studio\18\Enterprise\VSSDK\VisualStudioIntegration\Tools\Bin\VsixColorCompiler.exe",
    "C:\Program Files\Microsoft Visual Studio\18\Professional\VSSDK\VisualStudioIntegration\Tools\Bin\VsixColorCompiler.exe"
)
$compiler = $compilerPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $compiler) {
    throw "VsixColorCompiler.exe not found. Install the Visual Studio extension development workload."
}
Write-Host "Using compiler: $compiler"

# --- Build the combined XML ---
$themes = @("ayu_dark.vstheme", "ayu_mirage.vstheme", "ayu_light.vstheme")
$combined = New-Object System.Text.StringBuilder
[void]$combined.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
[void]$combined.AppendLine('<Themes>')

foreach ($theme in $themes) {
    if (-not (Test-Path $theme)) { throw "Missing theme file: $theme" }

    $content = Get-Content $theme -Raw -Encoding UTF8
    # Strip only the XML declaration. Keep the <Theme>...</Theme> root intact.
    $content = $content -replace '^\s*<\?xml[^>]*\?>\s*', ''

    # Schema requires <Background> before <Foreground> inside <Color>.
    # Swap any Foreground-then-Background pair to Background-then-Foreground.
    $content = [regex]::Replace(
        $content,
        '(<Color\b[^>]*>)\s*(<Foreground\b[^>]*/>)\s*(<Background\b[^>]*/>)\s*(</Color>)',
        '$1$3$2$4'
    )

    $content = $content.Trim()

    [void]$combined.AppendLine($content)
}

[void]$combined.AppendLine('</Themes>')

$combinedPath = Join-Path $projectRoot "AyuTheme.xml"
[System.IO.File]::WriteAllText($combinedPath, $combined.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote combined XML: $combinedPath"

# --- Compile to pkgdef ---
$pkgdefPath = Join-Path $projectRoot "AyuTheme.pkgdef"
& $compiler $combinedPath $pkgdefPath

if ($LASTEXITCODE -ne 0) {
    throw "VsixColorCompiler failed with exit code $LASTEXITCODE"
}
Write-Host "Wrote pkgdef: $pkgdefPath"