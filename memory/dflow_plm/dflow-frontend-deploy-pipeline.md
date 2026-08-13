---
name: dflow-frontend-deploy-pipeline
description: "Where the designflow-frontend sandbox-albert deploy actually runs (GCP project, region, Cloud Run service) — for verifying deploys"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7c1d3d28-5adf-4d34-a3f3-8995a80005d1
---

Pushing `designflow-frontend` `sandbox-albert` auto-triggers a **Cloud Build** that deploys to Cloud Run. The pipeline is easy to hunt for in the wrong place:

- **GCP project:** `lithe-breaker-323913` (NOT `dflow-plm` — that project has Cloud Build API disabled).
- **Region:** `us-east4` (the build triggers are regional; `gcloud builds triggers list` with no `--region` shows 0).
- **Cloud Run service (Albert's sandbox / alsand):** `popcre-albert-frontend-sandbox`. The alsand2 variant is `popcre-albert-frontend-sandbox2`; prod is `popcre-frontend-prod`.
- **Live URL:** https://alsand.designflow.app (custom domain) → that service.

Verify a deploy:
```
gcloud builds list --project=lithe-breaker-323913 --region=us-east4 --limit=5 \
  --format="value(id,status,createTime,substitutions.BRANCH_NAME,substitutions._APP_NAME,substitutions.SHORT_SHA)"
```
The build image tag ends in the full commit SHA, and the deployed site prints the short SHA in the top nav bar, so you can confirm the live commit directly. Local visual checks without a backend: `yarn start:preview` (see [[dflow-delivery-workflow]]).
