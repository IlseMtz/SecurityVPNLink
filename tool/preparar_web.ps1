param(
    [string]$Flutter = 'flutter',
    [string]$Node = 'node',
    [string]$ApiUrl = 'https://securelink-equipo1-incremento1-20261122.khakihymn8.chatgpt.site/api/v1'
)
$ErrorActionPreference = 'Stop'
$raiz = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
function Comprobar([string]$paso) {
    if ($LASTEXITCODE -ne 0) { throw "$paso fallo con codigo $LASTEXITCODE. No publicar." }
}
Push-Location $raiz
try {
    & $Flutter pub get
    Comprobar 'Dependencias'
    & $Flutter test --concurrency=1 --reporter expanded
    Comprobar 'Pruebas Flutter'
    & $Flutter analyze --no-fatal-infos
    Comprobar 'Analisis'
    & $Node --test hosting/test_worker.mjs
    Comprobar 'Pruebas del intermediario'
    & $Flutter build web --release --no-wasm-dry-run "--dart-define=SECURELINK_API_URL=$ApiUrl"
    Comprobar 'Compilacion web'

    $destino = [IO.Path]::GetFullPath((Join-Path $raiz 'hosting/web_build'))
    if (-not $destino.StartsWith($raiz + [IO.Path]::DirectorySeparatorChar)) { throw 'Destino fuera del proyecto.' }
    if (Test-Path -LiteralPath $destino) { Remove-Item -LiteralPath $destino -Recurse -Force }
    New-Item -ItemType Directory -Path $destino | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $raiz 'build/web') -Force | Copy-Item -Destination $destino -Recurse -Force
    Push-Location (Join-Path $raiz 'hosting')
    try {
        & $Node compilar_worker.mjs
        Comprobar 'Empaquetado Worker'
    } finally { Pop-Location }
    Write-Host 'Verificado y compilado: hosting/dist. Aun falta publicar en el sitio existente.' -ForegroundColor Green
} finally { Pop-Location }
