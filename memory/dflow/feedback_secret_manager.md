---
name: feedback-secret-manager
description: "When adding a new secret/API key to cloudbuild.yaml --set-secrets, always create the GCP secret and grant IAM in the same session — never leave it as a manual step for the user."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 012b52c3-78fe-4e78-9318-707ea60c143d
---

When adding a new `--set-secrets` entry to `cloudbuild.yaml` (e.g. a new API key like `DEEPSEEK_API_KEY`), do NOT tell the user "you must add this to Secret Manager manually." Do it immediately using gcloud:

```powershell
# 1. Create the secret
gcloud secrets create SECRET_NAME --replication-policy="automatic" --project=lithe-breaker-323913

# 2. Add the key value
echo -n "sk-..." | gcloud secrets versions add SECRET_NAME --data-file=- --project=lithe-breaker-323913

# 3. Grant the Cloud Run service account access
gcloud secrets add-iam-policy-binding SECRET_NAME \
  --member="serviceAccount:deployer@lithe-breaker-323913.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=lithe-breaker-323913
```

**Why:** Cloud Run's secrets access check runs at deploy time, before the container starts. If the secret doesn't exist, every revision fails with `SecretsAccessCheckFailed` and the service is broken immediately.

**How to apply:** Any time I touch `cloudbuild.yaml` to add a `--set-secrets` line, run the three gcloud commands above in the same commit session. The project is `lithe-breaker-323913`, the service account is `deployer@lithe-breaker-323913.iam.gserviceaccount.com`.
