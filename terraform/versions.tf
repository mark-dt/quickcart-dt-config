terraform {
  required_version = ">= 1.5.0"
  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.96"
    }
  }
  # GitLab-managed Terraform state, configured by the pipeline (-backend-config)
  backend "http" {}
}

provider "dynatrace" {
  dt_env_url   = var.dt_env_url
  dt_api_token = var.dt_api_token

  # Platform resources (guardian, workflow): OAuth client
  client_id                = var.dt_client_id
  client_secret            = var.dt_client_secret
  account_id               = var.dt_account_id
  automation_client_id     = var.dt_client_id
  automation_client_secret = var.dt_client_secret
  automation_env_url       = var.dt_apps_url
  automation_token_url     = var.dt_sso_url
}
