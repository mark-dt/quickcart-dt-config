# quickcart-dt-config

Dynatrace configuration for [QuickCart](https://github.com/mark-dt/quickcart) — everything
Dynatrace needs to observe and gate the app, and nothing else. The app repo contains only
source code, deploy manifests and its pipeline.

| Folder | What | Applied by |
|---|---|---|
| `terraform/` | **Quality gate**: Site Reliability Guardian `payment-service quality gate (<cluster>)` (staging failure rate ≤ 2 %, p90 ≤ 500 ms) and the workflow `workshop-aiops-lab <cluster> payment-service quality gate` — triggered by the staging deployment event, waits for traffic, validates, and on FAIL starts the app's GitLab rollback pipeline | `.gitlab-ci.yml` in this repo (`terraform apply` on `main`) |
| `dashboards/` | **QuickCart — service performance across stages**: response time, failure rate, throughput per stage/service with deploy (blue) / rollback (red) markers | `dtctl apply -f dashboards/quickcart-stages.dashboard.json` (once per tenant) |
| `workflows/` | Dynatrace workflow templates (auto-remediation of payment-service, predictive PVC usage) | import in the Workflows app, or `share-workflows.py` in the aiops-lab repo |

## Pipeline (GitLab)

| Event | Job |
|---|---|
| merge request touching `terraform/` | `plan` — shows what would change |
| push to `main` touching `terraform/` | `apply` |
| manual, on `main` | `destroy` — removes the guardian and the workflow |

State: GitLab-managed Terraform state of the project. CI/CD variables the pipeline expects:

| Variable | Used for |
|---|---|
| `DT_ENV_URL`, `DT_APPS_URL`, `DT_SSO_URL`, `DT_ACCOUNT_ID` | tenant + OAuth endpoints |
| `DT_API_TOKEN`, `DT_CLIENT_ID`, `DT_CLIENT_SECRET` | provider credentials (settings / app-settings / automation write) |
| `K8_CLUSTER` | the cluster the quality gate watches |
| `APP_PROJECT` | URL-encoded GitLab path of the app project, e.g. `user1%2Fquickcart` |
| `REPO_PAT` | GitLab token the workflow uses to start the app's rollback pipeline |

Tuning the gate (`terraform/variables.tf`): `failure_rate_max_pct`, `p90_max_ms`, `soak_seconds`,
`window`. Change them in a merge request — `plan` shows the diff, merging applies it.

## In the AIOps workshop

Each workshop VM gets a GitLab repo `dynatrace-config` built from this repo plus a
`dynakube/` folder with that VM's DynaKube (synced by ArgoCD). Its pipeline applies
`terraform/` at boot, creating the VM's guardian and quality-gate workflow.
