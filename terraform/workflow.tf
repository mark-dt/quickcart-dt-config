# Quality-gate workflow: staging deployment event -> soak -> validate -> on FAIL roll staging back.
resource "dynatrace_automation_workflow" "gate" {
  # The app pipeline finds this workflow by its exact title.
  title       = "workshop-aiops-lab ${var.k8s_cluster} ${var.service} quality gate"
  description = "Triggered by every ${var.service} deployment to staging on ${var.k8s_cluster}: validates the guardian after a traffic soak and, on FAIL, starts the GitLab rollback pipeline for staging."

  trigger {
    event {
      active = true
      config {
        event {
          event_type = "events"
          # Event fields are stored as deployment.<x>; rollback events don't match.
          query = "event.type == \"CUSTOM_DEPLOYMENT\" AND deployment.release_product == \"${var.release_product}\" AND deployment.release_stage == \"staging\" AND deployment.name == \"${var.service} deploy\" AND k8s.cluster.name == \"${var.k8s_cluster}\""
        }
      }
    }
  }

  tasks {
    task {
      name        = "validate"
      description = "Run the ${var.service} guardian on staging after the traffic soak"
      action      = "dynatrace.site.reliability.guardian:validate-guardian-action"
      active      = true
      wait_before = var.soak_seconds
      input = jsonencode({
        objectId           = dynatrace_site_reliability_guardian.gate.id
        executionId        = "{{ execution().id }}"
        timeframeInputType = "timeframeSelector"
        timeframeSelector  = { from = var.window, to = "now()" }
        expressionFrom     = ""
        expressionTo       = ""
      })
      position {
        x = 0
        y = 1
      }
    }
    task {
      name        = "rollback_staging"
      description = "On FAIL: start the GitLab rollback pipeline for staging (ArgoCD syncs the previous version)"
      action      = "dynatrace.automations:run-javascript"
      active      = true
      input = jsonencode({
        script = templatefile("${path.module}/scripts/rollback_staging.js", {
          cfg = jsonencode({
            appsUrl   = var.dt_apps_url
            gitlabUrl = var.gitlab_url
            projectId = var.gitlab_project
            gitlabPat = var.gitlab_pat
            service   = var.service
          })
        })
      })
      conditions {
        states = { validate = "OK" }
      }
      position {
        x = 0
        y = 2
      }
    }
  }
}
