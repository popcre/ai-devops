1) can you make sure seafile client is removed everywhere from this code where it has to do with an end-user's computer?
2) regarding "Offline" - can we have a mix of the 2? can it cache locally all the files the user has been working on recently? Or will that mess up the check-in / check-out?
3) can you check if Entra app allows User.Read ?
4) i want want a pinned version hosted by us, but with our site periodically checking for new versions so that it only offers up the latest version.
5) yes i want the seahub_settings.py SSO + nav-link snippets next
6) make sure: a) you are following the parts of these ci/cd rules that apply to this app b) the parts of these ci/cd rules that apply to this app are in the correct place in this repo's .md files
CI/CD/DevOps Operating Rules
§1 Purpose
These rules exist so AI tools can safely assist with an application without creating production drift, hidden deployment state, brittle release logic, weak release gates, or unclear ownership between the repo, registry, deployment platform, and production host.
The goal is a release process that a non-developer owner can audit:

* one normal release path
* clear verification gates
* explicit deploy inputs
* traceable build artifacts
* deployment-platform-owned runtime configuration
* no mystery server state
* no routine SSH-based production deployment
§2 System of truth

* GitHub is the source of truth for code, Dockerfiles, Docker Compose files, infrastructure-as-code files, deployment documentation, and GitHub Actions workflows.
* The container registry is the source of truth for published build artifacts.
* The deployment platform is the source of truth for runtime environment variables, domains, health checks, restart policy, container runtime settings, deployment target settings, and deployment execution.
* Production servers are runtime hosts, not configuration sources.
* The live server must not become the place where production behavior is secretly defined.
For this environment, the preferred production pattern is:

1. GitHub Actions verifies the commit.
2. GitHub Actions builds the production image.
3. GitHub Actions publishes the image to the container registry.
4. GitHub Actions explicitly triggers the deployment platform.
5. The deployment platform pulls and runs the already-published image.
6. The server only runs what the deployment platform tells it to run.
§3 Core principle
GitHub Actions may publish production artifacts and trigger the deployment platform, but it must not directly mutate production infrastructure.
GitHub Actions must not, as part of the normal deployment path:

* SSH into the production server
* edit production files on the server
* run `docker run` on the production server
* run `docker compose up` on the production server
* restart production services directly
* change production runtime configuration directly on the server or through shell commands (runtime configuration belongs in the deployment platform, not in GitHub Actions shell steps)
* rely on manually maintained production server state
Allowed:

```text
GitHub Actions -> container registry
GitHub Actions -> deployment platform API/webhook
Deployment platform -> production server

```

Not allowed as the normal path:

```text
GitHub Actions -> SSH into production server -> run Docker commands

```

§4 Branch policy

* Follow the repo’s actual branch policy.
* If the repo uses a single-branch model, treat `main` as the only release branch.
* Do not invent extra branches or branch-based workflows unless the repo already uses them.
* Do not assume a staging branch exists unless it is already part of the repo’s documented process.
* Do not create a fake promotion model if the application does not actually have one.
§5 Core deployment policy
Production releases must follow one normal, repo-driven path:

1. Change files in the repo.
2. Commit through the repo’s approved branch flow.
3. GitHub Actions runs required verification.
4. Successful builds produce the release artifact.
5. The artifact is published to the container registry.
6. The approved deploy job explicitly triggers the deployment platform.
7. The deployment platform deploys that exact artifact to the production runtime host.
Do not propose alternate routine deployment methods unless the repo already documents them.
The normal production path should be explicit and auditable from:

* GitHub Actions run history
* container registry image history
* deployment platform deployment history
* repo commit history
§6 Preferred deployment-platform pattern
When a deployment platform such as Coolify is used, the preferred pattern is:

```text
push to main
  ↓
GitHub Actions
  lint
  test
  build production Docker image
  publish image to registry
  trigger deployment platform by API or webhook
  ↓
Deployment platform
  pulls the already-built image from the registry
  applies runtime environment/configuration
  starts or updates the production container
  ↓
Production server
  runs the deployed container as a runtime host

```

§6.1 Required behavior

* GitHub Actions should build the image.
* GitHub Actions should publish the image to the container registry.
* GitHub Actions should trigger the deployment platform only after required verification and publishing succeed.
* The deployment platform should deploy the image produced by the approved workflow.
* The deployment platform should own runtime environment variables and runtime deployment settings.
* The server should not be directly mutated by the workflow through routine SSH commands.
* The deployment platform should not secretly rebuild the repo if the approved workflow already built the release image.
§6.2 Preferred image tags
Each production image should be published with explicit, traceable tags, such as:

* `main`
* `sha-<commit-sha>`
* optionally a semantic version or release tag if the repo has a real release process
The immutable commit-based tag is important for auditability and rollback.
Mutable tags such as `main` or `latest` are convenient pointers, but they are not sufficient audit records by themselves.
§6.3 Rollback preference
Rollback should preferably happen by redeploying a previously published immutable image tag through the deployment platform.
Rollback should not normally happen by:

* manually editing containers on the server
* manually editing files on the server
* manually running `docker run`
* manually running `docker compose up`
* pushing unreviewed code directly to production
* bypassing the deployment platform
§7 Deployment trigger rule
The preferred deploy trigger is:
GitHub Actions calls the deployment platform API or webhook after the image has been successfully built and pushed.
This is preferred over direct server access because it keeps responsibilities clean:

* GitHub Actions owns verification, build, artifact publication, and release orchestration.
* The container registry owns the build artifact.
* The deployment platform owns runtime configuration and deployment execution.
* The server only runs containers.
The deploy job should be downstream of required jobs using native GitHub Actions `needs` dependencies.
Preferred shape:

```text
lint -> test -> build -> publish -> deploy

```

The deploy job should not rediscover whether another workflow passed by searching workflow runs, polling status checks, or guessing based on recent SHA history.
§8 CI/CD enforcement rule
The approved workflow must make the intended deployment path enforceable, not merely documented.
Rules without enforcement tend to drift. The workflow and secrets setup should make the correct path the easiest path and the wrong path hard to reintroduce.
Required enforcement:

* remove routine production SSH deploy steps from GitHub Actions
* remove routine production SSH keys from GitHub Actions secrets when they are no longer needed for the approved path
* use deployment-platform API/webhook credentials instead of server SSH credentials for normal deploys
* make the deploy job depend on successful verification, build, and publish jobs using native `needs` dependencies
* document the deployment-platform app/project ID used by the workflow
* keep the deployment-platform trigger in the approved production workflow
* do not allow a second workflow to deploy the same app by SSH
* do not leave old SSH deployment workflows enabled as a fallback normal path
* do not keep unused production deploy credentials in GitHub Secrets
The workflow should enforce this path:

```text
verify -> build -> publish image -> trigger deployment platform

```

Not this path:

```text
verify -> build -> publish image -> SSH into server -> run docker commands

```

§8.1 Credential enforcement
GitHub Secrets should contain only the credentials needed for the approved CI/CD path.
For a deployment-platform-based setup, that usually means GitHub may store:

* registry publish credentials
* deployment-platform API token
* deployment-platform webhook secret
* deployment-platform application ID or project ID, if needed by the workflow
GitHub should not keep routine production SSH credentials unless the repo explicitly documents why they are still required.
If production SSH credentials are retained for emergency use, they must not be used by the normal production deployment workflow.
§9 Registry-watch caution
A deployment platform may watch the container registry for new image pushes only if all of the following are true:

* the repo explicitly documents this as the approved release method
* only images produced by the approved GitHub Actions workflow can trigger production deployment
* the image tag being deployed is explicit and auditable
* the deployment cannot be triggered accidentally by unrelated image pushes
* required verification cannot be bypassed
* the deployment platform history clearly shows what image was deployed
* manual pushes to the registry cannot accidentally deploy to production
* the registry-watch rule does not create a hidden second release path
If those conditions are not guaranteed, do not rely on generic registry watching as the normal production deployment method.
The safer default is an explicit GitHub Actions deploy job that calls the deployment platform API or webhook.
§10 SSH rule
SSH must not be used as the normal production deployment path.
Forbidden as routine deployment:

* GitHub Actions SSHes into the server and runs `docker run`
* GitHub Actions SSHes into the server and runs `docker compose up`
* GitHub Actions SSHes into the server and edits production files
* GitHub Actions SSHes into the server and changes environment variables
* an AI assistant SSHes into the server to change environment variables or feature flags instead of using the deployment platform (Coolify is the right path for runtime configuration; bypassing it via SSH breaks the single source of truth just as much as bypassing GitHub for code changes)
* GitHub Actions SSHes into the server and restarts services directly
* GitHub Actions SSHes into the server and performs app deployment logic
* an AI assistant SSHes into the production server to deploy as the normal fix
Allowed only as exception or emergency access:

* debugging a production incident
* one-time migration away from an old deployment path
* emergency break-glass repair
* collecting logs when the deployment platform cannot provide them
* verifying server state during a migration
If SSH is used for an emergency action, the permanent fix must be committed back to the repo or recorded in the deployment platform immediately afterward so the live server does not remain a hidden source of truth.
Emergency SSH must not become a second normal deployment path.
§11 Universal requirements
These rules should hold across all applications:

* production deploys must be gated by successful required verification
* release logic must be explicit and auditable
* there must be one obvious normal release path
* repo state must remain authoritative
* required failures must not be suppressed just to keep pipelines green
* deploy inputs must be explicit
* production changes must be reproducible from repo, registry, pipeline, and deployment-platform history
* runtime settings must not be hidden inside ad hoc server commands
* the deployment platform must not become an undocumented second build system
* CI must not execute commands on production infrastructure as part of the normal deployment path
* production deployment must be traceable to a specific repo commit and image tag
* deployment credentials must match the approved deployment architecture
* disabled or legacy deployment paths must not remain available as accidental fallbacks
§12 CI/CD Structure Decision Rule
Use the default pattern unless the repository clearly needs something else.
§12.1 Default
Use one orchestrated production workflow when all of these are true:

* one commit normally leads to one production release
* the same workflow can run verification, build, publish, and deploy
* deploy is simply downstream of successful checks for that same commit
* there is no real promotion model across multiple environments
* there is no manual approval or release-management layer that must sit between build and deploy
In that case:

* keep production release logic in one workflow graph
* use native GitHub Actions `needs` dependencies
* make later jobs depend directly on earlier required jobs
* prefer one bad commit failing once at the real failing stage
* do not split CI and CD into separate workflows just for neatness
* do not use one workflow to rediscover whether another workflow passed
* do not make the deployment platform rebuild the repo if GitHub Actions already built the release image
* do not add a second deployment mechanism as a fallback unless the repo explicitly documents why it is necessary
Preferred job shape:

1. `lint`
2. `test`
3. `build`
4. `publish`
5. `deploy`
For containerized apps using a deployment platform, the preferred deployment behavior is:

1. Build the Docker image in GitHub Actions.
2. Push the image to the container registry.
3. Trigger the deployment platform by API or webhook.
4. Let the deployment platform pull and run that image.
§12.2 Use a split CI/CD model only if the repo clearly has one of these needs
A split model may make sense if the repository has:

* artifact promotion across environments such as dev -> staging -> prod
* manual approval gates between build and deploy
* one build artifact deployed many times to different targets
* releases created once and consumed later by separate deployment workflows
* multiple services or systems depending on the same published artifact
* a formal release process where deploy is not tied directly to every successful commit
If that is true:

* make the handoff explicit with artifacts, versions, tags, or release records
* keep the release chain auditable end to end
* give each workflow a clearly defined responsibility
* prefer reusable workflows or an explicit top-level orchestrator
* do not gate deploy by searching recent workflow runs or polling CI status by SHA
* do not create a split model just for neatness
§12.3 Hard anti-pattern
Do not use this pattern unless a repo already depends on it and there is no safe replacement yet:

* workflow A runs CI
* workflow B runs build
* workflow C runs later and checks whether workflow A passed by looking up the same SHA
That pattern is brittle and noisy.
Replace it with either:

* one orchestrated workflow
* split workflows with explicit artifact/version handoff
§13 Pull request validation
PR workflows are allowed to differ from the production release workflow, but they should still enforce meaningful quality gates.
Rules:

* PR workflows may run lint, tests, typechecks, builds, or targeted verification.
* PR workflows must not become hidden alternate deploy paths.
* PR workflows should mirror production gates where practical.
* PR workflows must not deploy to production unless the repo explicitly documents a controlled preview or release process.
* PR workflows must not mutate production infrastructure.
* PR workflows must not publish production tags unless the repo explicitly documents that behavior.
§14 Database schema changes

* Schema changes must be committed through the repo’s approved migration path.
* Do not use direct production-only schema edits as the normal path.
* If an emergency manual database action is ever required, the repo-backed permanent migration or fix must be created immediately afterward and documented.
* Deployment should not depend on manual database changes that are not represented in repo history.
* Database migration behavior must be explicit in the deployment process.
* Do not hide schema changes inside one-off production server commands.
§15 Secrets rule

* GitHub Secrets are for CI/CD and build-time secrets.
* The deployment platform stores production runtime environment variables unless the repo explicitly documents another model.
* Do not move runtime secrets into GitHub without a clear reason.
* Do not put production runtime secrets inside Docker images.
* Do not put production runtime secrets into server-side shell scripts as the normal path.
* If GitHub Actions needs to call the deployment platform, store only the deployment-platform API token or webhook secret needed for that CI/CD action.
* Remove old deploy secrets when the deployment path changes and those secrets are no longer needed.
* Do not keep routine production SSH credentials in GitHub Secrets after moving to deployment-platform-based deploys.
Typical split:

* GitHub Actions: registry credentials, deployment-platform API token, webhook secret, build-time secrets if truly needed
* deployment platform: production app environment variables, domains, ports, health checks, restart policy, deployment target settings
* server: no manually maintained app secrets unless explicitly documented as part of the deployment platform setup
§16 Compose/infrastructure rule

* The repo copy of `docker-compose.yml`, `docker-compose.yaml`, or other declared infrastructure config is authoritative.
* If a service exists in production, it should be represented in repo-managed infrastructure config or explicitly documented as managed by the deployment platform.
* Do not treat ad hoc server-side infrastructure edits as valid long-term state.
* If the deployment platform manages a container directly instead of using repo Compose, that ownership must be documented.
* Runtime configuration that lives in the deployment platform should not be duplicated in server-side scripts.
* Do not use production-only Compose files on the server as the hidden source of truth.
The important distinction:

* repo = desired application and infrastructure definition
* registry = built artifact
* deployment platform = runtime configuration and deployment execution
* server = runtime host
§17 Deployment platform ownership rule
When a deployment platform is used, it should own:

* app/container identity
* production domain bindings
* runtime environment variables
* health checks
* restart policy
* deployment target settings
* container update/restart behavior
* rollback target selection when supported
* mapping from published artifact to running production service
It should not secretly own:

* source code changes
* production-only source files
* undocumented Dockerfile variants
* undocumented Compose variants
* build logic that differs from the repo’s approved pipeline
* hidden deployment scripts that replace the approved workflow
If the deployment platform is configured through its UI, the repo should still include enough documentation for an owner or developer to understand and recreate the intended deployment topology.
At minimum, the repo documentation should identify:

* deployment platform used
* app/project name or ID
* registry image name
* expected image tag pattern
* production domain
* deploy trigger method
* where runtime environment variables are managed
* rollback approach
§18 Container registry rule
The container registry should contain the artifacts that production can deploy.
Rules:

* production images should be built by the approved CI workflow
* production images should be tagged with the commit SHA or another immutable identifier
* mutable tags such as `latest` or `main` are convenient pointers, not sufficient audit records by themselves
* production deployment should be traceable back to a specific repo commit
* avoid deploying images that were built locally or pushed manually unless it is an emergency and is documented afterward
* manual image pushes must not accidentally trigger production deployment
* registry permissions should be narrow enough to protect production artifact integrity
§19 Build versus runtime rule
Build-time configuration and runtime configuration must not be mixed casually.
Build-time belongs in GitHub Actions only when needed to produce the artifact.
Runtime configuration belongs in the deployment platform unless the repo explicitly documents another model.
Examples of runtime configuration:

* production database URL
* production API keys
* domain bindings
* port mappings
* health checks
* restart policy
* persistent volumes
* production feature flags
* app environment variables
Examples of build/release configuration:

* Docker build context
* Dockerfile path
* registry image name
* image tags
* build arguments that are safe and necessary
* deployment-platform webhook/API credentials
Do not bake production runtime secrets into Docker images.
§20 Deployment platform direct-action rule
The single-source-of-truth rule means: each category of configuration must have exactly one owner, and changes must go through that owner’s authoritative path. It does not mean “everything must go through GitHub.”
The deployment platform (Coolify) is the source of truth for runtime configuration. That means changes to runtime configuration must go through Coolify directly — not through GitHub. Routing them through GitHub would violate single source of truth, not protect it.
AI may directly modify in Coolify (these are Coolify’s authoritative domain and cannot go through GitHub):

* runtime environment variables (e.g. ISSUE_PIPELINE_V2=true)
* feature flags and behavior switches that control runtime behavior without changing code
* domain bindings and port mappings
* health check settings
* restart policy
* container resource limits
* deployment target settings
AI must not directly modify in Coolify (these belong in GitHub and deploying them outside the repo would create drift):

* application source code changes
* Dockerfile changes
* Docker Compose or infrastructure config changes
* GitHub Actions workflow changes
* undocumented build logic overrides that differ from the repo’s approved pipeline
* production-only source files or Dockerfile variants that are not in the repo
The test: would putting this change in GitHub instead of Coolify make it more auditable and reproducible, with no loss of runtime flexibility? If yes, it belongs in GitHub. If the change is inherently runtime state that has no meaningful representation in the repo (env values, switch states), it belongs in Coolify and must go there directly.
§21 Allowed AI actions
AI may help with:

* editing application code
* editing Dockerfiles and Compose or infrastructure config
* editing GitHub Actions workflows
* editing deployment documentation
* improving CI/CD reliability and clarity
* recommending secrets usage for CI/CD
* applying deployment-platform runtime configuration changes directly (env vars, feature flags, switches, health checks, restart policy, domain bindings, and other settings Coolify owns)
* implementing deployment-platform API/webhook deployment patterns
* triggering deployment only through the repo’s approved release path
* replacing SSH-based deployment with deployment-platform API/webhook deployment
* documenting deployment-platform settings that must be recreated or audited
* removing obsolete SSH deployment steps from workflows
* identifying CI/CD drift between rules and actual workflow files
* recommending deletion or rotation of now-unused deployment secrets
§22 Forbidden AI actions
AI must not:

* use SSH as the normal deployment path
* hand-edit production files as the final fix
* assume the live server is the source of truth
* create undocumented hotfixes on the live machine
* create a second deployment system without explicit approval
* bypass required checks
* suppress real failures to make pipelines appear healthy
* introduce hidden release state or indirect deploy gating when a native workflow dependency can express the same rule
* configure production so any arbitrary registry push can deploy without the approved workflow and required verification
* move runtime configuration out of the deployment platform and into GitHub Actions shell commands without a clear documented reason
* make Coolify or another deployment platform rebuild the repo when the approved workflow is supposed to publish the release image
* leave legacy SSH deploy workflows active after replacing them with deployment-platform deploys
* keep production deployment credentials that no longer match the approved deployment architecture
* create a deployment path that cannot be audited from repo, registry, workflow, and deployment-platform history
§23 Change discipline
When making CI/CD changes:

* prefer small, explicit edits
* keep the release path simple
* reduce hidden state
* reduce duplicate failure surfaces
* use native platform features before custom polling logic
* update documentation when build, release, or runtime topology changes
* prefer API/webhook deployment-platform triggers over direct server mutation
* make image tags, app IDs, deployment targets, and trigger inputs explicit
* keep emergency actions separate from the normal production path
* remove obsolete deployment paths instead of leaving them as confusing fallbacks
* remove obsolete secrets when no longer needed
* verify that workflow structure enforces the policy, not just documents it
§24 Decision preference
When multiple valid options exist, prefer the one that:

* keeps repo state authoritative
* keeps production behavior reproducible
* minimizes hidden state
* minimizes duplicate or misleading failures
* is easy for a non-developer owner to audit
* expresses gating directly instead of indirectly
* fits the app’s real release needs without unnecessary complexity
* separates build concerns from runtime concerns
* lets the deployment platform manage runtime configuration instead of GitHub Actions SSH commands
* makes rollback possible through published artifacts and deployment-platform history
* makes the intended path enforceable
* reduces the chance that someone can accidentally reintroduce direct server deployment
§25 Repo-specific override
If a specific repository already documents a justified CI/CD exception, follow the repo-specific rule over the generic default.
The default is:

* one orchestrated production workflow
* GitHub Actions verifies, builds, publishes, and then explicitly triggers deployment
* the deployment platform pulls and runs the published artifact
* the server is only a runtime host
* CI does not execute commands on production infrastructure
The exception must be justified by the repo’s actual release model, not by habit or aesthetics.
Any exception must document:

* why the default model does not fit
* what the replacement release path is
* how verification is enforced
* what artifact is deployed
* how rollback works
* where runtime configuration lives
* how the path is audited
* how hidden server state is avoided
§26 Recommended wording for Coolify-based apps
For apps deployed through Coolify or a similar deployment platform, use this policy unless the repo documents a stronger reason not to:
GitHub Actions is responsible for verification, image build, registry publication, and release orchestration. Coolify is responsible for runtime configuration and deployment execution. GitHub Actions must not SSH into the production server for routine deployment. After publishing the approved image to the registry, GitHub Actions should trigger Coolify through its API or webhook. Coolify should pull and run the already-built image. Production deployment should be traceable to a specific Git commit and image tag.
Recommended normal path:

```text
main branch commit
  ↓
GitHub Actions verification
  ↓
Docker image build
  ↓
Push image to GHCR
  ↓
Trigger Coolify API/webhook
  ↓
Coolify pulls GHCR image
  ↓
Coolify updates production container

```

Forbidden normal path:

```text
main branch commit
  ↓
GitHub Actions build
  ↓
GitHub Actions SSHes into VPS
  ↓
GitHub Actions runs docker commands directly

```

Coolify should be the runtime deployment owner.
GitHub Actions should be the build and release orchestrator.
The VPS should only be the runtime host. §27 Optional acceleration patterns (repo-specific, not universal defaults) Some repositories benefit from CI/CD acceleration patterns that reduce turnaround time without changing the core release model. These are optional and should be adopted only when the repository’s file boundaries, test strategy, and runtime behavior make them safe.

* cancel superseded in-progress runs on the same branch so newer commits do not wait behind obsolete builds
* use Docker layer caching in CI to reuse intermediate build work while still producing a fresh image for the current commit
* publish explicit image tags such as `latest`, `main`, and `sha-<commit-sha>` when that matches the repo’s release model
* add narrow changed-file fast paths only when the repo has clear boundaries, so for example frontend-only changes can skip backend-heavy validation
* keep these fast paths conservative at first, then expand them only after successful runs show they are safe
* do not turn optional speedups into hidden policy; document exactly when they apply and what they skip §27.1 u2giants/twenty — approved fast-path exceptions The u2giants/twenty application (GitHub: u2giants/twenty, deployed to crm.designflow.app) uses two commit-scope fast paths implemented in .github/workflows/build-and-push.yml. These are approved exceptions under §27 and §25. Fast path 1 — frontend_fast_path. Trigger: ALL changed files are under packages/twenty-front/** or packages/twenty-front-component-renderer/. What is skipped: the build-and-push-full job (backend compile, backend smoke tests). What still runs: lint, twenty-front Jest suite, frontend-only Docker build, Coolify deploy. Rationale: frontend source is isolated from backend source; a UI-only commit cannot alter server behavior. Fast path 2 — backend_only_path. Trigger: ALL changed files are under packages/twenty-server/ or packages/twenty-emails/**. What is skipped: the 'Test twenty-front in band' Jest step; the frontend Vite prebuild (replaced by a GHA actions/cache restore keyed on twenty-front/twenty-ui/twenty-shared/twenty-front-component-renderer source hashes + yarn.lock). What still runs: backend lint, backend tests, server smoke test, Docker build, Coolify deploy. Rationale: a backend-only change cannot alter the frontend bundle; the cache is content-addressed so a hit proves the bundle is identical to the last verified build. Neither fast path skips the Docker image build or the Coolify deployment trigger. Any commit touching files outside the fast-path boundaries runs the full pipeline. Mixed commits (both frontend and backend files changed) always run the full path. §28 Documentation and AI-guidance files Operational documentation, architecture notes, AI-guidance files, and similar repo knowledge files are not the same thing as production runtime assets.
* files such as `AGENTS.md`, `CLAUDE.md`, architecture notes, and pitfall guides should normally be kept current by committing them to the repo and updating local repo checkouts with `git pull` before future AI or developer sessions
* these files do not normally require an application deploy unless the running application itself directly serves or consumes them at runtime
* do not use a blanket rule such as ignoring all `*.md` changes in CI/CD unless the repo has confirmed that Markdown files are never runtime-relevant
* if a Markdown file is user-facing application content or is consumed by the running system, treat it as application content and let normal build/deploy rules apply §29 Safe default for docs-only CI skips If a repository wants to skip routine production builds for documentation-only changes, the skip rules should be narrow and explicit.
* prefer ignoring clearly documentary paths such as `docs/**`, runbooks, or named top-level guidance files
* avoid broad path-ignore patterns that may accidentally exclude runtime-relevant files
* when in doubt, do not skip the workflow until the repo has proved the files are non-runtime documentation §30 Speed versus safety rule The default CI/CD model should stay simple: verify, build, publish, deploy. Performance optimizations are worthwhile when they preserve that model rather than replacing it with a second release path.
* prefer optimizations that reduce repeated work inside the approved workflow
* avoid optimizations that create hidden sources of truth, such as server-side hot state, ad hoc file uploads, or undocumented rebuild behavior in the deployment platform
* if a speed optimization changes what is verified or skipped, document that scope precisely and keep the conservative path available for broader changes