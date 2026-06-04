# auth-backends.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTH BACKENDS — all Vault auth methods under management.
#
# userpass and approle are declared in main.tf (they are
# tightly coupled to the user/SA aggregation logic there).
# All other backends are declared here.
#
# Backend-specific configuration (OIDC client IDs, Okta org,
# GCP service accounts, cert PEM content) is Phase 3 work.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "vault_auth_backend" "cert" {
  type = "cert"
  path = "cert"
  lifecycle { prevent_destroy = true }
}

resource "vault_auth_backend" "certs" {
  type = "cert"
  path = "certs"
  lifecycle { prevent_destroy = true }
}

resource "vault_auth_backend" "gcp" {
  type = "gcp"
  lifecycle { prevent_destroy = true }
}

resource "vault_auth_backend" "jwt" {
  type = "jwt"
  lifecycle { prevent_destroy = true }
}

resource "vault_auth_backend" "oidc" {
  type = "oidc"
  lifecycle { prevent_destroy = true }
}

resource "vault_auth_backend" "okta" {
  type = "okta"
  lifecycle { prevent_destroy = true }
}
