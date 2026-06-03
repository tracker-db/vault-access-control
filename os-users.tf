# os-users.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OS User Sync — Terraform writes the manifest, Ansible enforces it
#
# Terraform is the source of truth (users.tf).
# Ansible reads the generated manifest and enforces OS state on each server.
#
# Two-step workflow:
#
#   Step 1 — Review all changes before touching anything:
#     terraform plan
#     ansible-playbook scripts/sync-os-users.yml -i scripts/inventory.yml --check --diff
#
#   Step 2 — Apply:
#     terraform apply                               ← updates Vault + writes manifest
#     ansible-playbook scripts/sync-os-users.yml -i scripts/inventory.yml
#
# What Ansible enforces per server:
#   status = "enabled"  → create account (if missing), ensure unlocked
#   status = "disabled" → lock account (if exists), skip if not present
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "local_file" "ansible_users" {
  filename        = "${path.root}/scripts/users.auto.yml"
  file_permission = "0644"

  content = yamlencode({
    vault_users = {
      for username, user in local.users :
      username => { status = try(user.status, "enabled") }
    }
  })
}
