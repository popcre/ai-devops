# Safety and evidence

## Environment boundary

- Use `https://alsand.designflow.app` for disposable QA records.
- Albert confirmed on 2026-08-15 that alsand does not write to the shared
  production database. This supersedes stale repository text stating otherwise.
- Treat `https://designflow.app` and other production endpoints as read-only
  unless Albert approves the exact mutation in the current request.
- Stop if the browser unexpectedly changes from the approved host to production.

## Test data

- Prefix created records with `AI-QA-<YYYYMMDD>-<journey>-`.
- Record every created RFQ, item, Art Piece, customer, user, factory assignment,
  sample, box, shipment, comment, photo, or other identifier.
- Use obviously disposable customers, factories, products, and attachments.
- Clean up through supported application controls. List anything intentionally
  left behind and why it could not be removed safely.

## Irreversible or external actions

Do not send email to a real person, publish a real invitation, modify an external
factory's business record, upload confidential artwork, or complete a production
action against real data. Inspect confirmation and cancellation behavior when the
final effect is not clearly disposable.

Sample movement history is append-only. Do not create a protected movement merely
to test deletion unless the resulting record is approved residue. Prefer lifecycle
closeout, dispose, or loss actions when that is the business-correct path.

## Evidence

For each finding capture:

- role and account type, without credentials;
- exact approved hostname and page;
- disposable record identifiers;
- numbered reproduction steps;
- expected and actual customer-visible results;
- screenshot path;
- related browser error or failed request, without tokens or private headers;
- reload or second-attempt result;
- cleanup result;
- reproduction confidence.

Keep passwords, tokens, cookies, authorization headers, private artwork, and
unrelated customer information out of screenshots and reports.
