Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location -Path (Join-Path $PSScriptRoot '..\..')
node .\tools\playable-build.cjs install --clean @args
