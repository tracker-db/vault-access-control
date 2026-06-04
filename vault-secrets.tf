# vault-secrets.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Terraform manages the KV mount structure only.
#
# Secret VALUES are set directly in Vault — never in this repo.
# No variables, no tfvars, no secrets on disk.
#
# To read or update a secret:
#   vault kv get  secret/shared/app-service/credentials
#   vault kv put  secret/shared/anydesk/server-1 password=xxx
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
