param(
    [ValidateRange(1024, 65535)][int]$Puerto = 8765,
    [switch]$SinCompilar
)

$ErrorActionPreference = 'Stop'
$raiz = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$local = Join-Path $raiz '.tools\flutter\bin\flutter.bat'
$flutter = if (Test-Path -LiteralPath $local) { $local } else { 'flutter' }

Push-Location $raiz
try {
    if (-not $SinCompilar) {
        & $flutter build web --release --no-wasm-dry-run '--dart-define=SECURELINK_API_URL=/api/v1'
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar la aplicacion web.' }

        Push-Location hosting
        try {
            & node compilar_worker.mjs --local
            if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el servidor local.' }
        } finally { Pop-Location }
    }
    & node hosting/servidor_local.mjs $Puerto
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar el servidor local.' }
} finally { Pop-Location }
