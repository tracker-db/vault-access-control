# service-accounts.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SERVICE ACCOUNTS — Non-human identities
#
# Same RBAC model as users, but authenticated via AppRole
# instead of userpass. No passwords — uses role_id + secret_id.
#
# These cover: CI runners, Vault agents, monitoring, cron jobs,
# Ansible playbooks, anything automated that needs SSH access.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  service_accounts = {

    "github-actions-runner" = {
      roles       = ["deployer"]
      description = "GitHub Actions self-hosted runner on build server"
      token_ttl     = "30m"
      token_max_ttl = "1h"
    }

    # ── CI/CD Pipeline ───────────────────────
    "app-service" = {
      roles       = ["deployer"]
      description = "app service account formally EJ's shared account"
      # Short TTL — pipelines should be fast
      token_ttl     = "30m"
      token_max_ttl = "1h"
    }

    # ── Ansible Automation ───────────────────
    "ansible-automation" = {
      roles       = ["deployer"]
      description = "Ansible playbook execution from build server"
      token_ttl     = "1h"
      token_max_ttl = "2h"
    }

    # ── Monitoring Agent ─────────────────────
    "monitoring" = {
      roles       = ["read-only"]
      description = "Prometheus node_exporter checks, health probes"
      token_ttl     = "2h"
      token_max_ttl = "4h"
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

    # ── Backup Jobs ──────────────────────────
    # "backup-agent" = {
    #   roles       = ["read-only"]
    #   description = "Nightly backup job SSH into VMs for snapshots"
    #   token_ttl     = "1h"
    #   token_max_ttl = "2h"
    # }

  }
}
