# Site Reliability Guardian for the service in staging.
resource "dynatrace_site_reliability_guardian" "gate" {
  name        = "${var.service} quality gate (${var.k8s_cluster})"
  description = "Quality gate for ${var.service} in staging on ${var.k8s_cluster}; run by the quality-gate workflow after every staging deployment."
  tags        = ["service:${var.service}", "stage:staging", "k8s.cluster.name:${var.k8s_cluster}"]

  # Objectives on service metrics (dt.service.request.*), incl. /health probes.
  objectives {
    objective {
      name                = "Failure rate"
      description         = "Share of failed requests (%), incl. health probes"
      objective_type      = "DQL"
      comparison_operator = "LESS_THAN_OR_EQUAL"
      target              = var.failure_rate_max_pct
      dql_query           = <<-DQL
        timeseries {total = sum(dt.service.request.count), failed = sum(dt.service.request.failure_count)},
          filter: k8s.cluster.name == "${var.k8s_cluster}" and k8s.namespace.name == "${var.staging_namespace}" and k8s.workload.name == "${var.service}",
          interval: 1m
        | fields failure_rate = 100.0 * arraySum(failed) / arraySum(total)
      DQL
    }
    objective {
      name                = "Response time p90 (ms)"
      description         = "90th percentile response time (average of the 1-minute p90 values)"
      objective_type      = "DQL"
      comparison_operator = "LESS_THAN_OR_EQUAL"
      target              = var.p90_max_ms
      dql_query           = <<-DQL
        timeseries p90 = percentile(dt.service.request.response_time, 90),
          filter: k8s.cluster.name == "${var.k8s_cluster}" and k8s.namespace.name == "${var.staging_namespace}" and k8s.workload.name == "${var.service}",
          interval: 1m
        | fields p90_ms = arrayAvg(p90) / 1000.0
      DQL
    }
  }
}
