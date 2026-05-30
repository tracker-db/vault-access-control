# main.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WIRING — Connects roles.tf + users.tf + service-accounts.tf
#
# You should NOT need to edit this file for routine access changes.
# Edit users.tf to add/remove people.
# Edit roles.tf to change what roles can access.
# Edit service-accounts.tf to add/remove automation identities.
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
  default     = "ssh-client-signer"
}

# ──────────────────────────────────────────────
# Module: Create Vault SSH roles + policies from roles.tf
# ──────────────────────────────────────────────

module "vault_rbac" {
  source = "git::https://github.com/tracker-db/modules-terraform-vault-rbac.git?ref=v1.0.0"

  roles          = local.roles
  ssh_mount_path = var.ssh_mount_path
}

# ──────────────────────────────────────────────
# Auth Backend: Userpass (for humans)
# ──────────────────────────────────────────────

resource "vault_auth_backend" "userpass" {
  type = "userpass"

  lifecycle {
    prevent_destroy = true
  }
}

# ──────────────────────────────────────────────
# Auth Backend: AppRole (for service accounts)
# ──────────────────────────────────────────────

resource "vault_auth_backend" "approle" {
  type = "approle"

  lifecycle {
    prevent_destroy = true
  }
}

# ──────────────────────────────────────────────
# Human Users — resolve roles → policies, create userpass
# ──────────────────────────────────────────────

locals {
  # For each user, collect all policy names from their assigned roles
  # Example: tom has roles=["platform-admin"]
  #   → policies = ["ssh-role-platform-admin"]
  user_policies = {
    for username, user in local.users : username => distinct(flatten([
      for role_name in user.roles : module.vault_rbac.role_policy_names[role_name]
    ]))
  }
}

resource "vault_generic_endpoint" "users" {
  for_each = local.users

  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/${each.key}"
  ignore_absent_fields = true
  disable_read         = false
  disable_delete       = false

  data_json = jsonencode({
    token_policies = local.user_policies[each.key]
    token_ttl      = "8h"
    token_max_ttl  = "24h"
  })
}

# ──────────────────────────────────────────────
# Service Accounts — resolve roles → policies, create AppRole
# ──────────────────────────────────────────────

locals {
  sa_policies = {
    for sa_name, sa in local.service_accounts : sa_name => distinct(flatten([
      for role_name in sa.roles : module.vault_rbac.role_policy_names[role_name]
    ]))
  }
}

resource "vault_approle_auth_backend_role" "service_accounts" {
  for_each = local.service_accounts

  depends_on = [vault_auth_backend.approle]
  backend    = vault_auth_backend.approle.path
  role_name  = each.key

  token_policies = local.sa_policies[each.key]
  token_ttl      = try(each.value.token_ttl, "1h")
  token_max_ttl  = try(each.value.token_max_ttl, "2h")

  # Bind to specific CIDR if you want to lock SAs to specific hosts
  # secret_id_bound_cidrs = ["10.0.10.0/24"]

  # secret_id must be generated out-of-band:
  #   vault write -f auth/approle/role/<name>/secret-id
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
      policies = policies
    }
  }
}

output "service_account_matrix" {
  description = "Service accounts and their policies"
  value = {
    for sa_name, policies in local.sa_policies :
    sa_name => {
      roles    = local.service_accounts[sa_name].roles
      policies = policies
      description = local.service_accounts[sa_name].description
    }
  }
}

output "role_resource_map" {
  description = "What resources each role grants access to"
  value       = module.vault_rbac.role_resource_map
}
