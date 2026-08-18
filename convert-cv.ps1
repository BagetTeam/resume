# Archive EwenGueguen.pdf into OldCV, then compile EwenGueguen.tex to EwenGueguen.pdf.
# Archive names: EwenGueguen_oldYYYYMM.pdf, then EwenGueguen_oldYYYYMM_2.pdf, _3, ...

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Root = $PSScriptRoot
$Name = "EwenGueguen"
$TexFile = Join-Path $Root "$Name.tex"
$CurrentPdf = Join-Path $Root "$Name.pdf"
$OldCvDir = Join-Path $Root "OldCV"

function Get-ArchivePath {
    param([string]$Directory, [string]$BaseName)

    $stamp = Get-Date -Format "yyyyMM"
    $stem = Join-Path $Directory "${BaseName}_old${stamp}"
    $first = "$stem.pdf"
    if (-not (Test-Path -LiteralPath $first)) {
        return $first
    }

    $idx = 2
    while (Test-Path -LiteralPath "${stem}_${idx}.pdf") {
        $idx++
    }
    return "${stem}_${idx}.pdf"
}

if (-not (Test-Path -LiteralPath $TexFile)) {
    throw "Missing TeX source: $TexFile"
}

$pdflatex = Get-Command pdflatex -ErrorAction SilentlyContinue
if (-not $pdflatex) {
    throw "pdflatex not found. Install MiKTeX and ensure pdflatex is on PATH."
}

# Avoid hanging on MiKTeX's "install missing package?" GUI prompt.
$initexmf = Get-Command initexmf -ErrorAction SilentlyContinue
if ($initexmf) {
    & initexmf --set-config-value=[MPM]AutoInstall=1 | Out-Null
}

$archivedPdf = $null
if (Test-Path -LiteralPath $CurrentPdf) {
    New-Item -ItemType Directory -Force -Path $OldCvDir | Out-Null
    $archivedPdf = Get-ArchivePath -Directory $OldCvDir -BaseName $Name
    Move-Item -LiteralPath $CurrentPdf -Destination $archivedPdf
    Write-Host "Archived current CV -> $(Split-Path -Leaf $archivedPdf)"
} else {
    Write-Host "No existing $Name.pdf to archive."
}

Push-Location $Root
try {
    $pdfArgs = @(
        "-interaction=nonstopmode",
        "-halt-on-error",
        "-file-line-error",
        "--enable-installer",
        $TexFile
    )
    function Invoke-PdfLaTeX {
        param([int]$Pass)
        $output = & pdflatex @pdfArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            $output | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
            throw "pdflatex pass $Pass failed with exit code $LASTEXITCODE"
        }
    }
    Invoke-PdfLaTeX -Pass 1
    Invoke-PdfLaTeX -Pass 2
    foreach ($ext in @("aux", "log", "out", "toc", "synctex.gz")) {
        $aux = Join-Path $Root "$Name.$ext"
        if (Test-Path -LiteralPath $aux) { Remove-Item -LiteralPath $aux }
    }

    if (-not (Test-Path -LiteralPath $CurrentPdf)) {
        throw "Compilation finished but $Name.pdf was not produced."
    }
    Write-Host "Wrote $Name.pdf"
} catch {
    if ($archivedPdf -and (Test-Path -LiteralPath $archivedPdf) -and -not (Test-Path -LiteralPath $CurrentPdf)) {
        Move-Item -LiteralPath $archivedPdf -Destination $CurrentPdf
        Write-Host "Compile failed; restored previous PDF to the root folder."
    }
    throw
} finally {
    Pop-Location
}
