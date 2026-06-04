# vault-secrets.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Terraform manages the KV mount and service account credential paths.
#
# No secrets are stored in files — passwords are passed via
# environment variable and land only in Vault:
#
#   TF_VAR_service_account_password=88888888 terraform apply
#
# To read a service account credential:
#   vault kv get secret/service-accounts/<name>/credentials
#
# To rotate all passwords:
#   TF_VAR_service_account_password=<new> terraform apply
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "vault_mount" "kv" {
  path               = "secret"
  type               = "kv"
  description        = "KV v2 — all lab secrets"
  listing_visibility = "hidden"

  options = {
    version = "2"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ──────────────────────────────────────────────
# Service Account Credentials
#
# All OS service accounts — bastions and core-servers.
# Password passed via TF_VAR env var, never stored in any file.
# ──────────────────────────────────────────────

variable "service_account_password" {
  description = "Password for all OS service accounts. Pass via: TF_VAR_service_account_password=<value>"
  type        = string
  sensitive   = true
}

locals {
  service_accounts_with_creds = [
    # bastions
    "ansible-job-user",
    "ansible-work",
    "ansible-work-service-account",
    "auto-deploy",
    # core-servers (util)
    "mysql",
    # core-servers (green, blue)
    "libvirt-qemu",
  ]
}

resource "vault_kv_secret_v2" "service_accounts" {
  for_each = toset(local.service_accounts_with_creds)

  mount = vault_mount.kv.path
  name  = "service-accounts/${each.key}/credentials"

  data_json = jsonencode({
    username = each.key
    password = var.service_account_password
  })
}
