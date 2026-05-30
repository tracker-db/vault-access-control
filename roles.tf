# roles.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ROLE DEFINITIONS — What does each role grant?
#
# Three types of grants:
#   ssh     → Vault SSH CA cert signing for target hosts
#   vault   → Vault admin/operator access (policies, secrets engines, auth)
#   secret  → Read access to KV secrets (passwords, tokens, keys)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  roles = {

    # ──────────────────────────────────────────
    # Platform Admin — the top engineers
    #
    # Gets: Vault admin, bastion SSH, AnyDesk creds,
    #        app-service creds (to hop into internal systems)
    # ──────────────────────────────────────────
    "platform-admin" = {
      description = "Full lab access — Vault admin, bastion SSH, AnyDesk, app-service"

      grants = {
        "bastion" = {
          type    = "ssh"
          targets = [
            "ssh.auto-deploy.net:1020",
            "ssh.auto-deploy.net:1022",
          ]
          access  = "admin"
          ttl     = "8h"
          max_ttl = "24h"
        }
      }

      # Vault admin — manage policies, secrets engines, auth methods
      vault_admin = true

      # KV secrets this role can READ
      secret_paths = [
        "secret/data/shared/anydesk/*",
        "secret/data/shared/app-service/*",
        "secret/data/apps/*",
      ]
    }

    # ──────────────────────────────────────────
    # K8s Operator — cluster node access only
    # ──────────────────────────────────────────
    "k8s-operator" = {
      description = "Read access to K8s cluster nodes via bastion"

      grants = {
        "bastion" = {
          type    = "ssh"
          targets = [
            "ssh.auto-deploy.net:1020",
            "ssh.auto-deploy.net:1022",
          ]
          access  = "read"
          ttl     = "4h"
          max_ttl = "8h"
        }
      }

      vault_admin = false

      secret_paths = [
        "secret/data/shared/app-service/*",
      ]
    }

    # ──────────────────────────────────────────
    # Deployer — CI/CD pipelines, automation
    # ──────────────────────────────────────────
    "deployer" = {
      description = "Deploy access for CI/CD automation"

      grants = {
        "bastion" = {
          type    = "ssh"
          targets = [
            "ssh.auto-deploy.net:1020",
            "ssh.auto-deploy.net:1022",
          ]
          access  = "read"
          ttl     = "2h"
          max_ttl = "4h"
        }
      }

      vault_admin = false

      secret_paths = [
        "secret/data/shared/app-service/*",
      ]
    }

    # ──────────────────────────────────────────
    # Read-Only — monitoring, auditing
    # ──────────────────────────────────────────
    "read-only" = {
      description = "Read-only for monitoring and audit"

      grants = {
        "bastion" = {
          type    = "ssh"
          targets = [
            "ssh.auto-deploy.net:1020",
            "ssh.auto-deploy.net:1022",
          ]
          access  = "read"
          ttl     = "2h"
          max_ttl = "4h"
        }
      }

      vault_admin = false

      secret_paths = []
    }

  }
}
