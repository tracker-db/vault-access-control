# main.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THIS REPO IS THE SINGLE SOURCE OF TRUTH FOR VAULT.
# If it's not in Terraform, it doesn't exist in Vault.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }

  backend "local" {
    path = "/opt/terraform/state/user-access.tfstate"
  }
}

provider "vault" {
  address = var.vault_addr
}

variable "vault_addr" {
  description = "Vault primary/anchor address"
  type        = string
  default     = "https://vault.lab.internal:8200"
}

variable "ssh_mount_path" {
  description = "Vault SSH secrets engine mount path"
  type        = string
  default     = "ssh"
}


# ──────────────────────────────────────────────
# Module: SSH CA roles + per-role policies
# ──────────────────────────────────────────────

module "vault_rbac" {
  source = "git::https://github.com/tracker-db/modules-terraform-vault-rbac.git//modules/vault-rbac?ref=ca4f089f3578f31c57571a8878a2b541d45e04d4"

  roles          = local.roles
  ssh_mount_path = var.ssh_mount_path
}

# ──────────────────────────────────────────────
# Vault Admin Policy — for platform-admin role
# ──────────────────────────────────────────────

resource "vault_policy" "vault_admin" {
  name = "vault-admin"

  policy = <<-EOT
    # Full Vault administration
    # Manage policies
    path "sys/policies/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "sys/policy/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Manage auth methods
    path "sys/auth/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "auth/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Manage secrets engines
    path "sys/mounts/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "sys/mounts" {
      capabilities = ["read", "list"]
    }

    # Manage audit backends
    path "sys/audit/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/audit" {
      capabilities = ["read", "list"]
    }

    # Vault health and status
    path "sys/health" {
      capabilities = ["read"]
    }
    path "sys/seal-status" {
      capabilities = ["read"]
    }
    path "sys/leader" {
      capabilities = ["read"]
    }
    path "sys/storage/raft/autopilot/state" {
      capabilities = ["read"]
    }

    # Read Vault configuration
    path "sys/config/*" {
      capabilities = ["read", "list"]
    }

    # Token management
    path "auth/token/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # SSH CA management
    path "${var.ssh_mount_path}/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
  EOT
}

# ──────────────────────────────────────────────
# KV Secret Read Policies — per role
# ──────────────────────────────────────────────

resource "vault_policy" "kv_read" {
  for_each = {
    for role_name, role in local.roles :
    role_name => role.secret_paths
    if length(role.secret_paths) > 0
  }

  name = "kv-read-${each.key}"

  policy = join("\n\n", [
    for path in each.value :
    <<-EOT
    path "${path}" {
      capabilities = ["read", "list"]
    }
    EOT
  ])
}

# Platform-admins also get KV write (they manage secrets)
resource "vault_policy" "kv_admin" {
  name = "kv-admin"

  policy = <<-EOT
    # Full KV v2 management
    path "secret/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "secret/metadata/*" {
      capabilities = ["read", "list", "delete"]
    }
    path "secret/data/*" {
      capabilities = ["create", "read", "update", "delete"]
    }
  EOT
}

# ──────────────────────────────────────────────
# Auth Backends
# ──────────────────────────────────────────────

resource "vault_auth_backend" "userpass" {
  type = "userpass"
  lifecycle { prevent_destroy = true }
}

resource "vault_auth_backend" "approle" {
  type = "approle"
  lifecycle { prevent_destroy = true }
}

# ──────────────────────────────────────────────
# User Policy Aggregation
#
# For each user, collect ALL policies from their roles:
#   - SSH CA policies (from module)
#   - vault-admin policy (if role.vault_admin = true)
#   - KV read policy (if role.secret_paths not empty)
#   - KV admin policy (if role.vault_admin = true)
# ──────────────────────────────────────────────

locals {
  user_policies = {
    for username, user in local.users : username => distinct(flatten(concat(
      # SSH CA policies from the RBAC module
      [for role_name in user.roles : module.vault_rbac.role_policy_names[role_name]],

      # vault-admin policy
      [for role_name in user.roles :
        local.roles[role_name].vault_admin ? "vault-admin" : ""
      ],

      # KV admin policy (platform-admins can write secrets)
      [for role_name in user.roles :
        local.roles[role_name].vault_admin ? "kv-admin" : ""
      ],

      # KV read policies
      [for role_name in user.roles :
        length(local.roles[role_name].secret_paths) > 0 ? "kv-read-${role_name}" : ""
      ],
    )))
  }

  sa_policies = {
    for sa_name, sa in local.service_accounts : sa_name => distinct(flatten(concat(
      [for role_name in sa.roles : module.vault_rbac.role_policy_names[role_name]],
      [for role_name in sa.roles :
        length(local.roles[role_name].secret_paths) > 0 ? "kv-read-${role_name}" : ""
      ],
    )))
  }
}

# ──────────────────────────────────────────────
# Human Users — userpass accounts
# ──────────────────────────────────────────────

resource "vault_generic_endpoint" "users" {
  for_each = local.users

  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/${each.key}"
  ignore_absent_fields = true
  disable_read         = false
  disable_delete       = false

  data_json = jsonencode({
    token_policies = [for p in local.user_policies[each.key] : p if p != ""]
    token_ttl      = 28800
    token_max_ttl  = 86400
  })
}

# ──────────────────────────────────────────────
# Service Accounts — AppRole
# ──────────────────────────────────────────────

resource "vault_approle_auth_backend_role" "service_accounts" {
  for_each = local.service_accounts

  depends_on = [vault_auth_backend.approle]
  backend    = vault_auth_backend.approle.path
  role_name  = each.key

  token_policies = [for p in local.sa_policies[each.key] : p if p != ""]
  token_ttl      = try(each.value.token_ttl, 3600)
  token_max_ttl  = try(each.value.token_max_ttl, 7200)
}

# ──────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────

output "user_access_matrix" {
  description = "Who has what policies"
  value = {
    for username, policies in local.user_policies :
    username => {
      roles    = local.users[username].roles
      policies = [for p in policies : p if p != ""]
    }
  }
}

output "service_account_matrix" {
  description = "Service accounts and their policies"
  value = {
    for sa_name, policies in local.sa_policies :
    sa_name => {
      roles       = local.service_accounts[sa_name].roles
      policies    = [for p in policies : p if p != ""]
      description = local.service_accounts[sa_name].description
    }
  }
}
