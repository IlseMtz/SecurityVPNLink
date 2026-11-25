param([string]$Flutter = '')

$ErrorActionPreference = 'Stop'
$raiz = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $Flutter) {
    $local = Join-Path $raiz '.tools\flutter\bin\flutter.bat'
    $Flutter = if (Test-Path -LiteralPath $local) { $local } else { 'flutter' }
}

Push-Location $raiz
try {
    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron obtener las dependencias.' }
    & $Flutter test test/tdd_rojo/vs22_actividad_test.dart --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'VS-22 tiene pruebas fallidas. Revisa la salida anterior.' }
    Write-Host 'VS-22: las 7 pruebas de actividad pasaron correctamente.' -ForegroundColor Green
} finally {
    Pop-Location
}
