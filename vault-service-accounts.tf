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
      roles         = ["deployer"]
      description   = "Shared service account for internal lab systems (utility server, libvirt hosts, containers)"
      token_ttl     = 14400
      token_max_ttl = 28800
    }

    # ── CI/CD Pipeline ───────────────────────
    # Runs on util (192.168.2.97) as Docker containers via next-runner.
    # Authenticates via AppRole (VAULT_ROLE_ID + VAULT_SECRET_ID in .env).
    # Token TTL covers one job execution; container restarts refresh it.
    "github-actions-runner" = {
      roles          = ["deployer"]
      extra_policies = ["pipeline-reader"]
      description    = "GitHub Actions self-hosted runner on util (192.168.2.97) — serves tracker-db org"
      token_ttl      = 7200
      token_max_ttl  = 7200
    }

    # ── Vault Agent on K8s ───────────────────
    "vault-agent-blue" = {
      roles         = ["read-only"]
      description   = "Vault agent sidecar on Blue K8s cluster"
      token_ttl     = 14400
      token_max_ttl = 28800
    }

    "vault-agent-green" = {
      roles         = ["read-only"]
      description   = "Vault agent sidecar on Green K8s cluster"
      token_ttl     = 14400
      token_max_ttl = 28800
    }

    # ── Server Identities ────────────────────────
    "svc-anydesk-blue" = {
      roles         = ["read-only"]
      description   = "AnyDesk Blue server — reads credentials from Vault KV"
      token_ttl     = 14400
      token_max_ttl = 28800
    }

    "svc-anydesk-green" = {
      roles         = ["read-only"]
      description   = "AnyDesk Green server — reads credentials from Vault KV"
      token_ttl     = 14400
      token_max_ttl = 28800
    }

    "svc-bastion" = {
      roles         = ["deployer"]
      description   = "Bastion server — manages SSH CA operations and credential relay"
      token_ttl     = 14400
      token_max_ttl = 28800
    }

    # ── Imported — previously unmanaged AppRole accounts ──
    "ansible-approle" = {
      roles         = ["deployer"]
      description   = "Ansible automation — deploys to lab systems"
      token_ttl     = 3600
      token_max_ttl = 14400
    }

    "espch-approle" = {
      roles         = ["read-only"]
      description   = "ESPCH service account"
      token_ttl     = 3600
      token_max_ttl = 14400
    }

    # Previously had policy1/policy2 (placeholder policies) — vault-admin for Terraform automation
    "terraform" = {
      roles         = ["vault-admin"]
      description   = "Terraform service account for vault-access-control automation"
      token_ttl     = 3600
      token_max_ttl = 86400
    }

  }
}
