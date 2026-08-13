---
name: dflow-compact-matfield-label-overflow
description: dflow compact outline mat-form-field labels overflow the field top on some machines; pin line-height + float transform
metadata: 
  node_type: memory
  type: project
  originSessionId: bfac4dca-d90b-4965-82b1-d738ab694c96
---

On dflow toolbars that shrink Angular Material outline `mat-form-field`s (RFQ
`.toolbar-field`, itemLibrary `.cmd-field`, standardized/prod_tracking/licensing
filter bars), the POPULATED floating labels (Division/Status/View) can overflow
up out of the top of the field on some environments while looking fine on
dev/CI. Not reproducible where the toolbar font (Inter) is locally installed.

**Why:** Material positions the outlined floated label with `line-height: normal`
+ a font-relative `translateY(-106%)` (or the outlined-specific `-34.75px`)
transform, so the vertical spot depends on the RENDERED FONT'S METRICS and on
which competing Material rule wins. Setting `--mat-form-field-container-height`
only fixes the EMPTY/resting placeholder, NOT the floated case.

**How to apply:** pin the floated label deterministically so it's independent of
font/DPR/browser. In the component scss, inside the field's `::ng-deep` block:
`.mdc-floating-label { line-height: 16px !important; }` and
`.mdc-floating-label--float-above { transform: translateY(-24px) scale(0.75) !important; }`.
Verified: label centre lands 0px on the outline border, no overflow. Fixed for
RFQ in commit 4046694e (rfq.component.scss). Verify on a machine where the
toolbar font is NOT installed (headless/CI won't show the bug). Other toolbars
using the same compact pattern likely need the same pin.
