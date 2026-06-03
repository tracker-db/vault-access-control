# os-users.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OS User Sync — Terraform writes the manifest, Ansible enforces it
#
# Terraform is the source of truth (users.tf).
# Ansible reads the generated manifest and enforces OS state on each server.
#
# Two-step workflow:
#
#   Step 1 — Workstation: review and apply Vault changes
#     terraform plan
#     terraform apply                               ← updates Vault + writes manifest
#
#   Step 2 — Copy manifest to bastion2 (primary), run Ansible from there
#     scp -P 1022 scripts/users.auto.yml \
#       root@ssh.auto-deploy.net:/tmp/users.auto.yml
#
#     ssh -i ~/.ssh/id_rsa -p 1022 root@ssh.auto-deploy.net
#
#     ansible-playbook sync-os-users.yml -i inventory.yml \
#       --extra-vars "anydesk_ssh_password=<password>" --check --diff
#
#     ansible-playbook sync-os-users.yml -i inventory.yml \
#       --extra-vars "anydesk_ssh_password=<password>"
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
