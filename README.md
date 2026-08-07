# Sahseh Source

Sahseh Source is the canonical repository for Sahseh menu data and shared visual assets. The two application repositories consume deploy copies from this repository.

## Contents

- `data/menu.json`: canonical categories, products, prices, availability, images, and ingredients.
- `assets/brand/`: canonical Sahseh brand images.
- `assets/beauty/`: shared background and category icons.
- `assets/img/products/`: product-image source directory.
- `tools/`: synchronization and validation utilities.

## How It Works

Menu and shared asset changes are made here first, then synchronized into `sahseh_menu` and `sahseh_ordering`. The validation process checks the source data, deploy copies, fallback static HTML, asset consistency, category/product counts, and price slots.

## Editing Rule

Treat this repository as the source of truth. Do not make normal menu or shared-asset changes directly in an application repository. Product images should use paths relative to the deployed app root, and product ingredients belong on the product records in `data/menu.json`.

## Current Scope

The source currently supports the static QR menu and the ordering frontend. Backend, database, restaurant dashboard, and delivery operations are outside this repository’s current scope.