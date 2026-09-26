$ErrorActionPreference = "Stop"

$SourceRoot = Split-Path -Parent $PSScriptRoot
$MenuRoot = Split-Path -Parent $SourceRoot
$StaticRoot = Join-Path $MenuRoot "sahseh_menu"
$OrderingRoot = Join-Path $MenuRoot "sahseh_ordering"
$SourceDataPath = Join-Path $SourceRoot "data\menu.json"

if (-not (Test-Path -LiteralPath $SourceDataPath)) {
  throw "Missing source menu data: $SourceDataPath"
}

$Menu = Get-Content -Raw -LiteralPath $SourceDataPath | ConvertFrom-Json
$CategoryCount = @($Menu.categories).Count
$ProductCount = 0
foreach ($Category in @($Menu.categories)) {
  $ProductCount += @($Category.products).Count
}

if ($CategoryCount -ne 13 -or $ProductCount -ne 105) {
  throw "Source menu data has $CategoryCount categories and $ProductCount products; expected 13 categories and 105 products."
}

function Copy-RequiredFile {
  param(
    [string]$Source,
    [string]$Destination
  )

  if (-not (Test-Path -LiteralPath $Source)) {
    throw "Missing source file: $Source"
  }

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
  Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Copy-RequiredDirectoryContents {
  param(
    [string]$SourceDir,
    [string]$DestinationDir
  )

  if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "Missing source directory: $SourceDir"
  }

  New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
  Copy-Item -Path (Join-Path $SourceDir "*") -Destination $DestinationDir -Recurse -Force
}

if (-not (Test-Path -LiteralPath $StaticRoot)) {
  throw "Static menu folder not found: $StaticRoot"
}

Copy-RequiredFile $SourceDataPath (Join-Path $StaticRoot "data\menu.json")
Copy-RequiredDirectoryContents (Join-Path $SourceRoot "assets\brand") (Join-Path $StaticRoot "assets\brand")
Copy-RequiredDirectoryContents (Join-Path $SourceRoot "assets\beauty") (Join-Path $StaticRoot "assets\beauty")
New-Item -ItemType Directory -Force -Path (Join-Path $StaticRoot "assets\img\products") | Out-Null
if ((Get-ChildItem -LiteralPath (Join-Path $SourceRoot "assets\img\products") -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
  Copy-RequiredDirectoryContents (Join-Path $SourceRoot "assets\img\products") (Join-Path $StaticRoot "assets\img\products")
}
Write-Host "Synced static menu deploy files."

$OrderingPackage = Join-Path $OrderingRoot "package.json"
$OrderingPublic = Join-Path $OrderingRoot "public"
if ((Test-Path -LiteralPath $OrderingPackage) -or (Test-Path -LiteralPath $OrderingPublic)) {
  Copy-RequiredFile $SourceDataPath (Join-Path $OrderingRoot "public\data\menu.json")
  Copy-RequiredDirectoryContents (Join-Path $SourceRoot "assets\brand") (Join-Path $OrderingRoot "public\assets\brand")
  Copy-RequiredDirectoryContents (Join-Path $SourceRoot "assets\beauty") (Join-Path $OrderingRoot "public\assets\beauty")
  New-Item -ItemType Directory -Force -Path (Join-Path $OrderingRoot "public\assets\img\products") | Out-Null
  if ((Get-ChildItem -LiteralPath (Join-Path $SourceRoot "assets\img\products") -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
    Copy-RequiredDirectoryContents (Join-Path $SourceRoot "assets\img\products") (Join-Path $OrderingRoot "public\assets\img\products")
  }
  Write-Host "Synced ordering app public files."
} else {
  Write-Host "Ordering app is empty; skipped ordering sync."
}

Write-Host "Sync complete: $CategoryCount categories, $ProductCount products."
