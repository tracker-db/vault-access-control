# roles.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ROLE DEFINITIONS — What does each role grant?
#
# Three types of grants:
#   ssh     → Vault SSH CA cert signing for target hosts
#   vault   → Vault admin/operator access (policies, secrets engines, auth)
#   secret  → Read access to KV secrets (passwords, tokens, keys)
#
# TTLs are in seconds to avoid Vault API normalization drift.
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
      description = "Full lab access — Vault admin, bastion SSH, AnyDesk, app-service, AWS"

      grants = {
        "bastion" = {
          type = "ssh"
          targets = [
            "ssh.auto-deploy.net:1020",
            "ssh.auto-deploy.net:1022",
          ]
          access  = "admin"
          ttl     = 28800 # 8h
          max_ttl = 86400 # 24h
        }
      }

      vault_admin = true
      aws_access  = true

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
          type = "ssh"
          targets = [
            "ssh.auto-deploy.net:1020",
            "ssh.auto-deploy.net:1022",
          ]
          access  = "read"
          ttl     = 14400 # 4h
          max_ttl = 28800 # 8h
        }
      }

      vault_admin = false
      aws_access  = false

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
          type = "ssh"
          targets = [
            "ssh.auto-deploy.net:1020",
            "ssh.auto-deploy.net:1022",
          ]
          access  = "read"
          ttl     = 7200  # 2h
          max_ttl = 14400 # 4h
        }
      }

      vault_admin = false
      aws_access  = false

      secret_paths = [
        "secret/data/shared/app-service/*",
      ]
    }

    # ──────────────────────────────────────────
    # AWS Operator — dynamic AWS credentials
    #
    # Gets: aws/* access (generate AWS creds via
    # Vault's AWS secrets engine). No SSH CA grants.
    # Assign to individuals or service accounts that
    # need AWS credentials but not full platform-admin.
    # ──────────────────────────────────────────
    "aws-operator" = {
      description = "AWS dynamic credentials via Vault AWS secrets engine"

      grants = {}

      vault_admin = false
      aws_access  = true

      secret_paths = []
    }

    # ──────────────────────────────────────────
    # Vault Admin — Vault operations only
    #
    # Gets: full Vault admin policy (policies, auth,
    #       secrets engines). No SSH CA grants.
    # ──────────────────────────────────────────
    "vault-admin" = {
      description = "Vault administration — manage policies, auth methods, secrets engines"

      grants = {}

      vault_admin = true
      aws_access  = false

      secret_paths = []
    }

    # ──────────────────────────────────────────
    # Read-Only — monitoring, auditing
    # ──────────────────────────────────────────
    "read-only" = {
      description = "Read-only for monitoring and audit"

      grants = {
        "bastion" = {
          type = "ssh"
          targets = [
            "ssh.auto-deploy.net:1020",
            "ssh.auto-deploy.net:1022",
          ]
          access  = "read"
          ttl     = 7200  # 2h
          max_ttl = 14400 # 4h
        }
      }

      vault_admin = false
      aws_access  = false

      secret_paths = []
    }

  }
}
