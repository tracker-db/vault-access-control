# secrets.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VAULT KV SECRETS — Everything stored in Vault
#
# This file manages:
#   - KV v2 secrets engine mount
#   - Shared credentials (AnyDesk, app-service)
#   - App-specific secrets
#
# SECRET VALUES: Do NOT put actual passwords in this file.
# Use terraform.tfvars (git-ignored) or pass via env vars.
# Terraform manages the KEY STRUCTURE. Values come from
# variables marked sensitive.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ──────────────────────────────────────────────
# KV v2 Secrets Engine
# ──────────────────────────────────────────────

resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv-v2"
  description = "KV v2 — all lab secrets"

  lifecycle {
    prevent_destroy = true
  }
}

# ──────────────────────────────────────────────
# AnyDesk Credentials
#
# Two AnyDesk servers are entry points to the lab.
# Shared password stored here; platform-admins read it.
# ──────────────────────────────────────────────

variable "anydesk_server_1" {
  description = "AnyDesk server 1 connection details"
  type = object({
    anydesk_id = string
    password   = string
    hostname   = string
  })
  sensitive = true
}

variable "anydesk_server_2" {
  description = "AnyDesk server 2 connection details"
  type = object({
    anydesk_id = string
    password   = string
    hostname   = string
  })
  sensitive = true
}

resource "vault_kv_secret_v2" "anydesk_server_1" {
  mount = vault_mount.kv.path
  name  = "shared/anydesk/server-1"

  data_json = jsonencode({
    anydesk_id = var.anydesk_server_1.anydesk_id
    password   = var.anydesk_server_1.password
    hostname   = var.anydesk_server_1.hostname
    notes      = "Lab entry point — AnyDesk server 1"
  })
}

resource "vault_kv_secret_v2" "anydesk_server_2" {
  mount = vault_mount.kv.path
  name  = "shared/anydesk/server-2"

  data_json = jsonencode({
    anydesk_id = var.anydesk_server_2.anydesk_id
    password   = var.anydesk_server_2.password
    hostname   = var.anydesk_server_2.hostname
    notes      = "Lab entry point — AnyDesk server 2"
  })
}

# ──────────────────────────────────────────────
# app-service — Shared Service Account
#
# Used to access: utility server, 2 libvirt hosts,
# all containers. Engineers hop through bastion,
# then use these creds for internal systems.
# ──────────────────────────────────────────────

variable "app_service_ssh_private_key" {
  description = "SSH private key for app-service account"
  type        = string
  sensitive   = true
  default     = ""
}

variable "app_service_password" {
  description = "Password for app-service account on internal systems"
  type        = string
  sensitive   = true
  default     = ""
}

resource "vault_kv_secret_v2" "app_service" {
  mount = vault_mount.kv.path
  name  = "shared/app-service/credentials"

  data_json = jsonencode({
    username        = "app-service"
    password        = var.app_service_password
    ssh_private_key = var.app_service_ssh_private_key
    notes           = "Shared service account for utility server, libvirt hosts, containers"
    targets         = [
      "utility server",
      "libvirt-host-1",
      "libvirt-host-2",
      "all containers",
    ]
  })
}

# ──────────────────────────────────────────────
# Future: App-specific secrets
#
# Add blocks like this as apps are onboarded:
#
# variable "myapp_db_password" {
#   type      = string
#   sensitive = true
# }
#
# resource "vault_kv_secret_v2" "myapp" {
#   mount = vault_mount.kv.path
#   name  = "apps/myapp/credentials"
#   data_json = jsonencode({
#     db_password = var.myapp_db_password
#     db_host     = "db.lab.internal"
#   })
# }
# ──────────────────────────────────────────────
