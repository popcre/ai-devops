---
name: aggrid-v36-legacy-theming
description: AG Grid theming in designflow-frontend — migrated from legacy CSS to the v36 Theming API (themeAlpine)
metadata: 
  node_type: memory
  type: project
  originSessionId: 51f8b191-2b39-43aa-b40a-10964ec7da3b
---

**As of 2026-06-30 `designflow-frontend` uses AG Grid v36's new Theming API**, NOT legacy CSS. (This reverses the earlier 2026-06-29 legacy-CSS pin — that state is gone.) Migrated on `sandbox-albert` in commits `ffd28c92` + `edcd8903` + `a19055d9`.

How it works now (`src/app/helpers/ag-grid/`):
1. `grid-themes.config.ts` defines `APP_GRID_THEME` = `themeAlpine.withParams({ fontFamily: Hanken })` + `columnDropStyleBordered`/`buttonStyleQuartz` parts (v36's builder drops button/column-drop styles). Dark variant `APP_GRID_THEME_DARK` adds `colorSchemeDarkBlue`.
2. `ag-grid-modules.ts`: `provideGlobalGridOptions({ theme: APP_GRID_THEME })` (was `'legacy'`).
3. `grid-ui.service.ts` `bootstrapTheme()`: applies `APP_GRID_THEME_DARK` only when `--background-card` === `#1a202e` (dark mode); otherwise the global default applies.
4. Legacy CSS (`ag-grid.css` + `ag-theme-alpine.css`) is **removed** from `styles.scss` AND `angular.json` — loading it alongside the Theming API causes **error #106 / blank grids**. Never re-add it.

**Key trick:** the `.ag-theme-alpine` class is **kept** on every grid element as a plain styling hook (NOT removed). So the redesign's ~17 per-component SCSS files (`.ag-theme-alpine .ag-row` etc.) keep applying unchanged on top of the new base. AG Grid docs explicitly allow keeping the class. This is why the migration touched ~5 files, not ~35. Dark mode was already light-only in the redesign CSS (overrides target `.ag-theme-alpine`, not `-dark`), so dark grids fall back to the dark base — not polished, but pre-existing.

Still light-only/unpolished: dark mode. License watermark is unrelated known noise. The vendored `src/@vex/styles/ag-grid/` SASS tree is orphaned dead code (safe to delete). See [[aggrid-version-drift-local-install]] and [[git-commit-identity]].
