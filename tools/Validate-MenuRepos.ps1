$ErrorActionPreference = "Stop"

$SourceRoot = Split-Path -Parent $PSScriptRoot
$MenuRoot = Split-Path -Parent $SourceRoot
$StaticRoot = Join-Path $MenuRoot "sahseh_menu"
$OrderingRoot = Join-Path $MenuRoot "sahseh_ordering"
$SourceDataPath = Join-Path $SourceRoot "data\menu.json"
$StaticDataPath = Join-Path $StaticRoot "data\menu.json"
$HtmlPath = Join-Path $StaticRoot "index.html"
$StylesPath = Join-Path $StaticRoot "styles.css"
$ScriptPath = Join-Path $StaticRoot "script.js"
$Errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
  param([string]$Message)
  $script:Errors.Add($Message) | Out-Null
}

function Decode-HtmlText {
  param([string]$Value)
  return [System.Net.WebUtility]::HtmlDecode($Value).Trim()
}

function Test-RequiredProperty {
  param(
    [object]$Object,
    [string]$PropertyName,
    [string]$Context
  )

  if (-not ($Object.PSObject.Properties.Name -contains $PropertyName)) {
    Add-ValidationError "$Context is missing required property '$PropertyName'."
    return $false
  }

  return $true
}

function Test-SameFileHash {
  param(
    [string]$Source,
    [string]$Copy,
    [string]$Label
  )

  if (-not (Test-Path -LiteralPath $Source)) {
    Add-ValidationError "$Label source file is missing: $Source"
    return
  }

  if (-not (Test-Path -LiteralPath $Copy)) {
    Add-ValidationError "$Label deploy copy is missing: $Copy"
    return
  }

  $SourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash
  $CopyHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Copy).Hash
  if ($SourceHash -ne $CopyHash) {
    Add-ValidationError "$Label deploy copy is out of sync. Run sahseh_source/tools/Sync-Apps.ps1."
  }
}

foreach ($RequiredFile in @($SourceDataPath, $StaticDataPath, $HtmlPath, $StylesPath, $ScriptPath)) {
  if (-not (Test-Path -LiteralPath $RequiredFile)) {
    throw "Missing required file: $RequiredFile"
  }
}

$Menu = Get-Content -Raw -LiteralPath $SourceDataPath | ConvertFrom-Json
$Html = Get-Content -Raw -LiteralPath $HtmlPath
$Styles = Get-Content -Raw -LiteralPath $StylesPath
$Script = Get-Content -Raw -LiteralPath $ScriptPath
$Categories = @($Menu.categories)

Test-SameFileHash $SourceDataPath $StaticDataPath "Menu data"
Test-SameFileHash (Join-Path $SourceRoot "assets\brand\brand-art.png") (Join-Path $StaticRoot "assets\brand\brand-art.png") "Brand logo"
Test-SameFileHash (Join-Path $SourceRoot "assets\beauty\background-pattern.svg") (Join-Path $StaticRoot "assets\beauty\background-pattern.svg") "Background pattern"

if (-not (Test-Path -LiteralPath (Join-Path $StaticRoot "assets\qr\menu.png"))) {
  Add-ValidationError "Static QR PNG is missing from sahseh_menu/assets/qr."
}

if (-not (Test-Path -LiteralPath (Join-Path $StaticRoot "assets\qr\menu.pdf"))) {
  Add-ValidationError "Static QR PDF is missing from sahseh_menu/assets/qr."
}

if (-not (Test-Path -LiteralPath $OrderingRoot)) {
  Add-ValidationError "Ordering folder is missing: $OrderingRoot"
}

$SharedRelativePaths = [System.Collections.Generic.List[string]]::new()
$SharedRelativePaths.Add("data\menu.json") | Out-Null
foreach ($SharedDirectory in @("assets\brand", "assets\beauty", "assets\img\products")) {
  $SharedSourceDirectory = Join-Path $SourceRoot $SharedDirectory
  if (Test-Path -LiteralPath $SharedSourceDirectory) {
    Get-ChildItem -LiteralPath $SharedSourceDirectory -Recurse -File | ForEach-Object {
      $SharedRelativePaths.Add($_.FullName.Substring($SourceRoot.Length + 1)) | Out-Null
    }
  }
}

foreach ($SharedRelativePath in @($SharedRelativePaths | Sort-Object -Unique)) {
  Test-SameFileHash (Join-Path $SourceRoot $SharedRelativePath) (Join-Path $StaticRoot $SharedRelativePath) "Static shared copy $SharedRelativePath"

  if (Test-Path -LiteralPath $OrderingRoot) {
    Test-SameFileHash (Join-Path $SourceRoot $SharedRelativePath) (Join-Path $OrderingRoot (Join-Path "public" $SharedRelativePath)) "Ordering shared copy $SharedRelativePath"
  }
}

if ($Categories.Count -ne 13) {
  Add-ValidationError "Expected 13 categories in source data, found $($Categories.Count)."
}

if ($Html -notmatch 'data-menu-source="data/menu\.json"') {
  Add-ValidationError "Static index.html must fetch the static deploy copy at data/menu.json."
}

if ($Html -notmatch 'assets/brand/brand-art\.png') {
  Add-ValidationError "Static index.html must use the synced source logo path assets/brand/brand-art.png."
}

if ($Styles -notmatch 'assets/beauty/background-pattern\.svg') {
  Add-ValidationError "Static styles.css must use the synced source background path assets/beauty/background-pattern.svg."
}

if ($Script -notmatch 'fetch\(menuSourceUrl' -or $Script -notmatch 'menuPage\.replaceChildren') {
  Add-ValidationError "Static script.js does not appear to render from menu data."
}

$CategoryIds = [System.Collections.Generic.HashSet[string]]::new()
$SectionIds = [System.Collections.Generic.HashSet[string]]::new()
$ProductIds = [System.Collections.Generic.HashSet[string]]::new()
$ProductCount = 0
$PriceCount = 0

for ($CategoryIndex = 0; $CategoryIndex -lt $Categories.Count; $CategoryIndex++) {
  $Category = $Categories[$CategoryIndex]
  $Context = "Category index $CategoryIndex"

  foreach ($Property in @("id", "sectionId", "name", "order", "icon", "visibleInDineIn", "visibleInOrdering", "products")) {
    Test-RequiredProperty $Category $Property $Context | Out-Null
  }

  if (-not [string]::IsNullOrWhiteSpace($Category.id) -and -not $CategoryIds.Add([string]$Category.id)) {
    Add-ValidationError "Duplicate category id '$($Category.id)'."
  }

  if (-not [string]::IsNullOrWhiteSpace($Category.sectionId) -and -not $SectionIds.Add([string]$Category.sectionId)) {
    Add-ValidationError "Duplicate section id '$($Category.sectionId)'."
  }

  $ExpectedCategoryOrder = $CategoryIndex + 1
  $ExpectedSectionId = "section-{0:D2}" -f $ExpectedCategoryOrder

  if ([int]$Category.order -ne $ExpectedCategoryOrder) {
    Add-ValidationError "Category '$($Category.id)' has order $($Category.order), expected $ExpectedCategoryOrder."
  }

  if ($Category.sectionId -ne $ExpectedSectionId) {
    Add-ValidationError "Category '$($Category.id)' has sectionId '$($Category.sectionId)', expected '$ExpectedSectionId'."
  }

  if (-not [string]::IsNullOrWhiteSpace($Category.icon)) {
    $SourceIconPath = Join-Path $SourceRoot $Category.icon
    $StaticIconPath = Join-Path $StaticRoot $Category.icon
    Test-SameFileHash $SourceIconPath $StaticIconPath "Icon $($Category.icon)"
  }

  $Products = @($Category.products)
  $ProductCount += $Products.Count
  $PreviousProduct = $null

  for ($ProductIndex = 0; $ProductIndex -lt $Products.Count; $ProductIndex++) {
    $Product = $Products[$ProductIndex]
    $ProductContext = "Product index $ProductIndex in category '$($Category.id)'"

    foreach ($Property in @("id", "name", "price", "priceText", "order", "image", "ingredients", "available", "visibleInDineIn", "visibleInOrdering")) {
      Test-RequiredProperty $Product $Property $ProductContext | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($Product.id) -and -not $ProductIds.Add([string]$Product.id)) {
      Add-ValidationError "Duplicate product id '$($Product.id)'."
    }

    if ([string]::IsNullOrWhiteSpace($Product.name)) {
      Add-ValidationError "$ProductContext has an empty product name."
    }

    $ExpectedProductOrder = $ProductIndex + 1
    if ([int]$Product.order -ne $ExpectedProductOrder) {
      Add-ValidationError "Product '$($Product.id)' has order $($Product.order), expected $ExpectedProductOrder."
    }

    if ([string]::IsNullOrWhiteSpace($Product.priceText)) {
      Add-ValidationError "Product '$($Product.id)' has an empty priceText."
    } else {
      $PriceCount++

      if ($Product.priceText -notmatch '^\d+$') {
        Add-ValidationError "Product '$($Product.id)' priceText '$($Product.priceText)' is not formatted as a whole-number price."
      }

      if ([decimal]$Product.price -ne [decimal]$Product.priceText) {
        Add-ValidationError "Product '$($Product.id)' price $($Product.price) does not match priceText $($Product.priceText)."
      }
    }

    if ($null -ne $Product.image -and -not [string]::IsNullOrWhiteSpace($Product.image)) {
      Test-SameFileHash (Join-Path $SourceRoot $Product.image) (Join-Path $StaticRoot $Product.image) "Product image $($Product.image)"
    }

    if ($PreviousProduct) {
      $PreviousPrice = [decimal]$PreviousProduct.price
      $CurrentPrice = [decimal]$Product.price
      if ($PreviousPrice -gt $CurrentPrice) {
        Add-ValidationError "Product '$($Product.id)' is priced lower than the previous product in '$($Category.id)'."
      }
    }

    $PreviousProduct = $Product
  }
}

if ($ProductCount -ne 105) {
  Add-ValidationError "Expected 105 products in source data, found $ProductCount."
}

if ($PriceCount -ne 105) {
  Add-ValidationError "Expected 105 price slots in source data, found $PriceCount."
}

$NavMatches = [regex]::Matches($Html, '<a href="#([^"]+)"><img src="([^"]+)"[^>]*><span class="nav-label">([\s\S]*?)</span></a>')
$SectionMatches = [regex]::Matches($Html, '<article class="menu-section" id="([^"]+)">([\s\S]*?)</article>')

if ($NavMatches.Count -ne 13) {
  Add-ValidationError "Expected 13 fallback category navigation links in static index.html, found $($NavMatches.Count)."
}

if ($SectionMatches.Count -ne 13) {
  Add-ValidationError "Expected 13 fallback menu sections in static index.html, found $($SectionMatches.Count)."
}

for ($CategoryIndex = 0; $CategoryIndex -lt $Categories.Count; $CategoryIndex++) {
  if ($CategoryIndex -ge $NavMatches.Count -or $CategoryIndex -ge $SectionMatches.Count) {
    continue
  }

  $Category = $Categories[$CategoryIndex]
  $Nav = $NavMatches[$CategoryIndex]
  $Section = $SectionMatches[$CategoryIndex]
  $NavSectionId = Decode-HtmlText $Nav.Groups[1].Value
  $NavIcon = Decode-HtmlText $Nav.Groups[2].Value
  $NavName = Decode-HtmlText $Nav.Groups[3].Value
  $HtmlSectionId = Decode-HtmlText $Section.Groups[1].Value
  $SectionBody = $Section.Groups[2].Value
  $HeadingMatch = [regex]::Match($SectionBody, '<h3><span class="section-icon"><img src="([^"]+)"[^>]*></span><span>([\s\S]*?)</span></h3>')

  if ($NavSectionId -ne $Category.sectionId) {
    Add-ValidationError "Fallback navigation item $($CategoryIndex + 1) href '$NavSectionId' does not match source sectionId '$($Category.sectionId)'."
  }

  if ($NavIcon -ne $Category.icon) {
    Add-ValidationError "Fallback navigation item '$($Category.id)' icon '$NavIcon' does not match source icon '$($Category.icon)'."
  }

  if ($NavName -ne $Category.name) {
    Add-ValidationError "Fallback navigation item '$($Category.id)' label '$NavName' does not match source name '$($Category.name)'."
  }

  if ($HtmlSectionId -ne $Category.sectionId) {
    Add-ValidationError "Fallback HTML section $($CategoryIndex + 1) id '$HtmlSectionId' does not match source sectionId '$($Category.sectionId)'."
  }

  if (-not $HeadingMatch.Success) {
    Add-ValidationError "Fallback HTML section '$($Category.sectionId)' is missing the expected heading markup."
  } else {
    $HeadingIcon = Decode-HtmlText $HeadingMatch.Groups[1].Value
    $HeadingName = Decode-HtmlText $HeadingMatch.Groups[2].Value

    if ($HeadingIcon -ne $Category.icon) {
      Add-ValidationError "Fallback HTML section '$($Category.sectionId)' icon '$HeadingIcon' does not match source icon '$($Category.icon)'."
    }

    if ($HeadingName -ne $Category.name) {
      Add-ValidationError "Fallback HTML section '$($Category.sectionId)' title '$HeadingName' does not match source name '$($Category.name)'."
    }
  }

  $HtmlProducts = [regex]::Matches($SectionBody, '<li><span>([\s\S]*?)</span><span class="price-slot">([\s\S]*?)</span></li>')
  $DataProducts = @($Category.products)

  if ($HtmlProducts.Count -ne $DataProducts.Count) {
    Add-ValidationError "Fallback section '$($Category.sectionId)' has $($HtmlProducts.Count) HTML products but $($DataProducts.Count) source products."
    continue
  }

  for ($ProductIndex = 0; $ProductIndex -lt $DataProducts.Count; $ProductIndex++) {
    $HtmlProduct = $HtmlProducts[$ProductIndex]
    $DataProduct = $DataProducts[$ProductIndex]
    $HtmlName = Decode-HtmlText $HtmlProduct.Groups[1].Value
    $HtmlPrice = Decode-HtmlText $HtmlProduct.Groups[2].Value

    if ($HtmlName -ne $DataProduct.name) {
      Add-ValidationError "Product '$($DataProduct.id)' fallback name mismatch: HTML '$HtmlName', source '$($DataProduct.name)'."
    }

    if ($HtmlPrice -ne $DataProduct.priceText) {
      Add-ValidationError "Product '$($DataProduct.id)' fallback price mismatch: HTML '$HtmlPrice', source '$($DataProduct.priceText)'."
    }
  }
}

if ($Errors.Count -gt 0) {
  foreach ($ValidationError in $Errors) {
    Write-Host "ERROR: $ValidationError" -ForegroundColor Red
  }
  exit 1
}

Write-Host "Source/app split validation passed: source data/assets, app deploy copies, fallback HTML, 13 categories, 105 products, 105 prices."
