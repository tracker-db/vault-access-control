# service-accounts.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SERVICE ACCOUNTS — Non-human identities
#
# All use AppRole auth (role_id + secret_id, no passwords).
#
# app-service is the SHARED account for internal systems.
# Engineers hop through bastion → use app-service creds
# (retrieved from Vault KV) to reach internal hosts.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  service_accounts = {

    # ── Shared Internal Access ───────────────
    # Used by platform-admins after bastion hop
    # to reach: utility server, libvirt hosts, containers
    "app-service" = {
      roles       = ["deployer"]
      description = "Shared service account for internal lab systems (utility server, libvirt hosts, containers)"
      token_ttl     = "4h"
      token_max_ttl = "8h"
    }

    # ── CI/CD Pipeline ───────────────────────
    "github-actions-runner" = {
      roles       = ["deployer"]
      description = "GitHub Actions self-hosted runner on build server"
      token_ttl     = "30m"
      token_max_ttl = "1h"
    }

    # ── Vault Agent on K8s ───────────────────
    "vault-agent-blue" = {
      roles       = ["read-only"]
      description = "Vault agent sidecar on Blue K8s cluster"
      token_ttl     = "4h"
      token_max_ttl = "8h"
    }

    "vault-agent-green" = {
      roles       = ["read-only"]
      description = "Vault agent sidecar on Green K8s cluster"
      token_ttl     = "4h"
      token_max_ttl = "8h"
    }

  }
}
