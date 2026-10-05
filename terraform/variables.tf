# Provided by the pipeline as TF_VAR_* from this repo's CI/CD variables.
variable "dt_env_url" { type = string }
variable "dt_apps_url" { type = string }
variable "dt_sso_url" { type = string }
variable "dt_account_id" { type = string }
variable "dt_api_token" {
  type      = string
  sensitive = true
}
variable "dt_client_id" { type = string }
variable "dt_client_secret" {
  type      = string
  sensitive = true
}

variable "k8s_cluster" {
  type        = string
  description = "Kubernetes cluster (DynaKube) name of this workshop VM"
}
variable "gitlab_url" {
  type        = string
  description = "Public GitLab URL of this VM, e.g. https://gitlab.1.2.3.4.nip.io"
}
variable "gitlab_project" {
  type        = string
  description = "URL-encoded path of the app project, e.g. user1%2Fquickcart"
}
variable "gitlab_pat" {
  type        = string
  sensitive   = true
  description = "Token the workflow uses to start the GitLab rollback pipeline"
}

# Quality-gate settings
variable "service" {
  type    = string
  default = "payment-service"
}
variable "staging_namespace" {
  type    = string
  default = "quickcart-staging"
}
variable "release_product" {
  type    = string
  default = "quickcart-demo"
}
variable "failure_rate_max_pct" {
  type    = number
  default = 2
}
variable "p90_max_ms" {
  type    = number
  default = 500
}
variable "soak_seconds" {
  type        = number
  default     = 270
  description = "Staging traffic before validating; must cover the guardian window"
}
variable "window" {
  type    = string
  default = "now()-4m"
}
