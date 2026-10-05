# Quality-gate workflow: staging deployment event -> soak -> validate -> on FAIL roll staging back.
# GitLab connection used by the rollback task.
resource "dynatrace_gitlab_connection" "gitlab" {
  name  = "gitlab ${var.k8s_cluster}"
  url   = var.gitlab_url
  token = var.gitlab_pat
}

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
      description = "On FAIL: trigger the app's GitLab rollback pipeline for staging"
      action      = "dynatrace.gitlab.connector:gitlab-trigger-pipeline"
      active      = true
      input = jsonencode({
        connection = dynatrace_gitlab_connection.gitlab.id
        projectId  = var.gitlab_project
        branchId   = "main"
        variables = [
          { key = "ROLLBACK", value = "true" },
          { key = "ROLLBACK_STAGE", value = "staging" },
          { key = "ROLLBACK_FROM_VERSION", value = "{{ event()[\"deployment.version\"] }}" },
          { key = "ROLLBACK_REASON", value = "Site Reliability Guardian: FAIL for {{ event()[\"deployment.version\"] }}" },
          { key = "DT_VALIDATION_URL", value = "{{ result(\"validate\").validation_url }}" },
        ]
      })
      conditions {
        states = { validate = "OK" }
        custom = "{{ result(\"validate\").validation_status == \"fail\" }}"
      }
      position {
        x = 0
        y = 2
      }
    }
  }
}
