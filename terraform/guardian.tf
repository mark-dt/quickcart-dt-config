# Site Reliability Guardian: is the new version in staging good enough?
resource "dynatrace_site_reliability_guardian" "gate" {
  name        = "${var.service} quality gate (${var.k8s_cluster})"
  description = "Quality gate for ${var.service} in staging on ${var.k8s_cluster}; run by the quality-gate workflow after every staging deployment."
  tags        = ["service:${var.service}", "stage:staging", "k8s.cluster.name:${var.k8s_cluster}"]

  objectives {
    objective {
      name                = "Failure rate"
      description         = "Share of failed server requests (%)"
      objective_type      = "DQL"
      comparison_operator = "LESS_THAN_OR_EQUAL"
      target              = var.failure_rate_max_pct
      dql_query           = <<-DQL
        fetch spans
        | filter k8s.cluster.name == "${var.k8s_cluster}" and k8s.namespace.name == "${var.staging_namespace}"
            and k8s.workload.name == "${var.service}" and span.kind == "server"
        | summarize failure_rate = 100.0 * countIf(request.is_failed == true) / count()
      DQL
    }
    objective {
      name                = "Response time p90 (ms)"
      description         = "90th percentile of server request duration"
      objective_type      = "DQL"
      comparison_operator = "LESS_THAN_OR_EQUAL"
      target              = var.p90_max_ms
      dql_query           = <<-DQL
        fetch spans
        | filter k8s.cluster.name == "${var.k8s_cluster}" and k8s.namespace.name == "${var.staging_namespace}"
            and k8s.workload.name == "${var.service}" and span.kind == "server"
        | summarize p90_ms = toDouble(percentile(duration, 90)) / 1000000.0
      DQL
    }
  }
}
