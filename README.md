# quickcart-dt-config

Dynatrace configuration for [QuickCart](https://github.com/mark-dt/quickcart) — everything
Dynatrace needs to observe and gate the app, and nothing else. The app repo contains only
source code, deploy manifests and its pipeline.

| Folder | What | Applied by |
|---|---|---|
| `terraform/` | **Quality gate**: Site Reliability Guardian `payment-service quality gate (<cluster>)` (staging failure rate ≤ 1 %, p90 ≤ 500 ms — from the `dt.service.request.*` service metrics) and the workflow `workshop-aiops-lab <cluster> payment-service quality gate` — triggered by the staging deployment event, waits for traffic, validates, and on FAIL triggers the app's GitLab rollback pipeline via the GitLab connector (connection `gitlab <cluster>`) | `.gitlab-ci.yml` in this repo (`terraform apply` on `main`) |
| `collector/` | **Pipeline traces**: OpenTelemetry Collector (contrib, `gitlab` receiver) turning GitLab pipeline webhooks into traces (pipeline → stages → jobs) and sending them to Dynatrace via OTLP | ArgoCD app `otel-collector` |
| `dashboards/` | **GitLab pipelines** (runs, success rate, rollbacks, durations, quality-gate wait) and **QuickCart — service performance across stages**: response time, failure rate, throughput per stage/service, plus pipeline runs, job durations and pipeline duration — with deploy (blue) / rollback (red) markers | `dtctl apply -f dashboards/<file>.dashboard.json` (once per tenant) |

## Contract with the app repo

The quality gate only works if this repo and [quickcart](https://github.com/mark-dt/quickcart)
agree on these names. Change them together.

| What | Value | Set by | Used by |
|---|---|---|---|
| Deployment event type / product | `CUSTOM_DEPLOYMENT`, `dt.event.deployment.release_product = quickcart-demo` | quickcart `ci/dt.py` | workflow trigger (`terraform/workflow.tf`) |
| Event name / stage | `dt.event.deployment.name = "<service> deploy"`, `release_stage = staging` | quickcart `ci/dt.py` | workflow trigger |
| Field names in Grail | the classic events API stores `dt.event.deployment.<x>` as **`deployment.<x>`** | Dynatrace | workflow trigger query |
| Cluster | `k8s.cluster.name` on the event = `K8_CLUSTER` CI variable in both repos | both | trigger + guardian queries |
| Workflow title | `workshop-aiops-lab <K8_CLUSTER> <service> quality gate` | `terraform/workflow.tf` | quickcart `quality-gate` job finds the workflow by this exact title |
| Validate task / result | task `validate`; result `validation_status`, `validation_details[]` | `terraform/workflow.tf`, SRG | quickcart `ci/dt.py gate` |
| Rollback request | GitLab connector "Trigger a new pipeline" on `main` of `APP_PROJECT`, variables `ROLLBACK=true`, `ROLLBACK_STAGE=staging`, `ROLLBACK_FROM_VERSION`, `ROLLBACK_REASON`, `DT_VALIDATION_URL` | `terraform/workflow.tf` (task `rollback_staging`) | quickcart `rollback` job |

## Collector

Expects a secret `otel-collector` in namespace `otel` (not in git):

| Key | Value |
|---|---|
| `GITLAB_WEBHOOK_SECRET` | token of the GitLab project webhooks |
| `DT_OTLP_ENDPOINT` | `https://<tenant>/api/v2/otlp` |
| `DT_OTLP_TOKEN` | API token with `openTelemetryTrace.ingest` |
| `K8_CLUSTER` | added to every span as `k8s.cluster.name` |

GitLab side: a project webhook (Pipeline events) to `http://otel-collector.otel.svc.cluster.local:19418/events`
with the same secret, and "Allow requests to the local network from webhooks" enabled. In Dynatrace the
spans have `service.name = <group>/<project>`, `cicd.pipeline.*`, `vcs.*` and `gitlab.pipeline.source`
(`api` = rollback started by Dynatrace).

## Pipeline (GitLab)

| Event | Job |
|---|---|
| merge request touching `terraform/` | `plan` — shows what would change |
| push to `main` touching `terraform/` | `apply` |
| manual, on `main` | `destroy` — removes the guardian and the workflow |

**State:** GitLab-managed Terraform state of the project (HTTP backend, configured by the
pipeline; locking included). Find it under **Operate → Terraform states** (state name `dynatrace`) —
download, lock/unlock or remove it there. It is deliberately not committed to the repo: the state
holds every value in plain text, including the GitLab token the workflow uses.

CI/CD variables the pipeline expects:

| Variable | Used for |
|---|---|
| `DT_ENV_URL`, `DT_APPS_URL`, `DT_SSO_URL`, `DT_ACCOUNT_ID` | tenant + OAuth endpoints |
| `DT_API_TOKEN`, `DT_CLIENT_ID`, `DT_CLIENT_SECRET` | provider credentials (settings / app-settings / automation write) |
| `K8_CLUSTER` | the cluster the quality gate watches |
| `APP_PROJECT` | numeric GitLab ID of the app project |
| `REPO_PAT` | token of the GitLab connection the workflow uses (`api` scope) |

Tuning the gate (`terraform/variables.tf`): `failure_rate_max_pct`, `p90_max_ms`, `soak_seconds`,
`window`. Change them in a merge request — `plan` shows the diff, merging applies it.

## In the AIOps workshop

Each workshop VM gets a GitLab repo `dynatrace-config` built from this repo plus a
`dynakube/` folder with that VM's DynaKube (synced by ArgoCD). Its pipeline applies
`terraform/` at boot, creating the VM's guardian and quality-gate workflow.
