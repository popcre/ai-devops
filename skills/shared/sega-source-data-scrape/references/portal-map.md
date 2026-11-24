# Sega DSI portal map

## Authentication

- Entry: `https://sega.dsidrm.com/signin`
- Select DSI SSO, then authenticate through the id4 login page.
- Credentials: 1Password vault `vibe_coding`, item `Sega licensor style guide website for scrape`.

## IP registry

- Currently 110 records over 19 pages.
- Numeric IDs span 100 through 210 with a gap; never assume contiguous IDs.
- Fields: IP Title, Primary ID, Type, Language, Status, Licensor labels, and IP Components.
- This account can read the list but not open the IP detail editor.

## Product Approval submission vocabulary

- `ProductApprovalSubmission.aspx` lists POP's submissions; its grid has no Property/IP column.
- `New Submission` -> `Product Approval` opens `ProductApprovalSubmissionWnd.aspx?ApprovalID=0` without creating a record.
- Selecting active Contract `2478` populates the required `ddlIPs` picker with 6 exact IP choices.
- All 6 IDs and labels match records in the 110-item IP registry. The other 104 registry records are not selectable under this contract.
- Selecting each of the 6 IPs leaves `ddlChildIPs` empty. The form exposes no Character picker or canonical character links.
- Never click Save. Reload the list and compare visible submission numbers before and after; the 2026-08-21 capture proved no record was created.

## Content Library

- Currently 1,488 unique elements with `data-hierarchypath`, depths 2 through 10.
- Two top-level catalog families with modern/classic and legacy-console subdivisions.
- Nineteen folders conservatively recognized as style, trend, text, or packaging guide candidates.
- Hundreds of paths contain a Character-labelled branch, but no Character registry or stable Character ID was found.
- The IP association editor exposes the same 110 IP IDs as a selector.

### Verified read-only methods

- `ContentLibrary.aspx/GetAllCatalogs`
- `ContentLibrary.aspx/LoadImages`
- `ContentLibrary.aspx/GetAllImageData`
- `ContentLibrary.aspx/LoadAssetIpAssociation`
- `ContentLibrary.aspx/GetCatalogAccessRights`

`LoadImages` supports `currentPage`, `catalogId`, `searchText`, `recordsPerPage`, `orderBy`, `ignoreExpired`, and `purgeCache`. The portal uses pages of 100.

### Asset fields

Numeric ImageId, exact filename, Artist, Description, CreationDate, DateExpires, FileSize, Width, Height, ThumbPath, CanView, CanDownload, IsExpired, Catalogs, and Tags.

Block thumbnails and media. A path in metadata is evidence, not authorization to download the file.

## Verified relationships

- Catalog to parent catalog: direct.
- Asset to catalog: direct and many-to-many.
- Asset to tag: direct.
- Asset to IP: direct through `LoadAssetIpAssociation`.
- IP to licensor label: direct from the registry.
- Character candidate to catalog or asset: inferred only.

One inspected asset linked to seven different catalog IDs with the same leaf label. Numeric ID and full path are required; label-only joins are invalid.

## Scope caution

The IP registry is broader than the catalog content visible to this account. Do not conclude every registered IP has downloadable assets or a visible catalog branch.

## Failed approaches and lessons

- The first sign-in screen is an SSO selector, not the credential form.
- The former password required a reset; obtain current values at runtime.
- The first 100 assets are not a complete inventory.
- Repeated leaf names make label-based hierarchy reconstruction unsafe.
- No Character master was found, so character rows remain evidence-backed candidates.
