# Sahseh Source

Source-of-truth repo for Sahseh menu data and shared visual assets.

This repo should be edited before the static menu or ordering app when changing menu content, product images, icons, logo, background, prices, ingredients, or visibility.

## Contents

- data/menu.json - canonical category and product data.
- assets/brand/brand-art.png - canonical Sahseh logo.
- assets/beauty/background-pattern.svg - shared decorative background.
- assets/beauty/icons/ - shared category and section icons.
- assets/img/products/ - future product images.
- tools/Sync-Apps.ps1 - copies deploy-ready data/assets into app repos.
- tools/Validate-MenuRepos.ps1 - validates source data/assets and app deploy copies.

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
