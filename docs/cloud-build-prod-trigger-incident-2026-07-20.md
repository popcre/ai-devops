# Cloud Build production-trigger incident, 2026-07-20

## Outcome

The source and live state are safe now. No production change was made during
this investigation.

- GCP audit logs show Terraform 1.15.6, running from t16's public IP under
  `U2Giants@gmail.com`, set four production triggers to disabled between
  21:04 and 21:06 UTC on 2026-07-20.
- Infrastructure commit `0423d300a751408e77625d689193187ff6535db5`, authored
  with Albert's Git identity at 21:02 UTC, added `disabled = true` for core,
  item, tracking, and sync in `popcre/gcp/live/prod/terraform.tfvars`.
- Commit `52f25fdcccaa69bd783b9ca7aa1e0b8c19b43e44` removed those four flags.
  Current `develop` also hard-codes `disabled = false` in every Cloud Build
  module resource.
- A read-only GCP check on 2026-08-10 showed all six `*-prod` triggers enabled.

## Transcript conclusion

The t16 Claude and Codex stores were searched by date, source path, commit SHA,
Terraform command, trigger name, and disabled flag without printing transcript
contents. No transcript contains the actual commit or apply command. The exact
AI product/session therefore cannot be recovered from available local evidence.
The authoritative evidence still identifies the source commit, credential,
machine IP, provider, affected resources, and permanent source fix.

## Safety rule retained

AI sessions remain read-only for production/shared infrastructure. They must
not run Terraform apply or change any named production Cloud Build trigger
without explicit resource-and-action approval in the current chat.
