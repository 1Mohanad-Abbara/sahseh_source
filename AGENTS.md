# Agent Handoff: Sahseh Source

Source-of-truth repo for Sahseh menu data and shared visual assets.

This repo should be edited before the static menu or ordering app when changing menu content, product images, icons, brand images, background, prices, ingredients, or visibility.

## Contents

- data/menu.json - canonical category and product data.
- assets/brand/ - canonical Sahseh brand images, including brand-art.png and brand-art-removebg-preview.png.
- assets/beauty/background-pattern.svg - shared decorative background.
- assets/beauty/icons/ - shared category and section icons.
- assets/img/products/ - future product images.
- tools/Sync-Apps.ps1 - copies deploy-ready data/assets and shared brand/beauty/product image directories into app repos.
- tools/Validate-MenuRepos.ps1 - validates source data/assets, app deploy copies, and static fallback HTML.

## Expected Sibling Folders

This repo expects app repos next to it:

```text
FILES/menu/
  sahseh_source/
  sahseh_menu/
  sahseh_ordering/
```

`sahseh_ordering` can be empty until the ordering app is built.

## Workflow

Edit canonical files here first, then sync app deploy copies:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sahseh_source\tools\Sync-Apps.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\sahseh_source\tools\Validate-MenuRepos.ps1
```

The static menu and future ordering app need deploy copies because each hosted site can only serve files included in that app repo or fetched from public URLs.

## Product Images

Put future product images in:

```text
assets/img/products/
```

Use paths in `data/menu.json` relative to the deployed app root, for example:

```json
"image": "assets/img/products/mojito-001.webp"
```

Prefer WebP images around 800x600 or 900x600, ideally 50KB to 150KB when possible.

## Ingredients

Ingredients belong directly in `data/menu.json` on each product:

```json
"ingredients": "نعنع، ليمون، سفن أب، ثلج"
```

Use `null` when ingredients are not available yet.

## Agent Handoff Notes

- This repository is the editable source of truth. Normal menu, price, availability, ingredient, image, icon, brand, and background changes start here and are synchronized into both app repositories.
- Deploy copies are `sahseh_menu/data/menu.json`, `sahseh_ordering/public/data/menu.json`, and the corresponding shared asset directories. QR assets are owned by `sahseh_menu` and are not synchronized into the other repositories.
- Current menu expectations are 13 categories, 105 products, 105 whole-number price slots, and no empty price slots. `priceText` must match numeric `price` and use the current whole-number display format.
- Keep category order, section identifiers, icon mappings, Arabic RTL text, manually adjusted product order, prices, and visibility intact unless the user explicitly requests a change.
- Product image paths remain relative to the deployed app root and product images belong under `assets/img/products/`. Prefer practical WebP dimensions and file sizes.
- Ingredients belong directly on each product record. Use `null` when ingredients are not available.
- Run synchronization and validation after source changes. Validation checks source/app data and assets, static fallback HTML, category/product counts, and price consistency.
- The source repository does not contain backend, database, delivery operations, or restaurant dashboard implementation.