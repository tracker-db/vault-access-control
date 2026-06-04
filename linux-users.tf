# linux-users.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OS User Sync — Terraform writes the manifest, Ansible enforces it.
#
# Two sources feed the manifest:
#   vault_users          — from vault-users.tf (Vault + all 3 servers)
#   service_accounts     — from linux-service-accounts.tf (bastions only)
#
# Workflow:
#   Step 1 — Workstation:
#     terraform plan
#     terraform apply    ← updates Vault + writes manifest + copies to bastion2
#
#   Step 2 — SSH into bastion2, run Ansible:
#     ansible-playbook sync-os-users.yml -i inventory.yml \
#       --extra-vars "anydesk_ssh_password=<password>" --check --diff
#     ansible-playbook sync-os-users.yml -i inventory.yml \
#       --extra-vars "anydesk_ssh_password=<password>"
#
# Ansible enforces per server:
#   vault_users:
#     enabled  → create + unlock on all servers
#     disabled → lock if exists
#     removed  → userdel -r if exists
#   service_accounts:
#     enabled  → create + unlock on bastions only
#     removed  → userdel -r on bastions only
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "local_file" "ansible_users" {
  filename        = "${path.root}/scripts/users.auto.yml"
  file_permission = "0644"

  content = yamlencode({
    vault_users = {
      for username, user in local.users :
      username => { status = try(user.status, "enabled") }
    }
    service_accounts = {
      for username, sa in local.linux_service_accounts :
      username => { status = sa.status }
    }
  })
}

# Auto-copy manifest to bastion2 whenever it changes.
resource "null_resource" "copy_manifest_to_bastion2" {
  triggers = {
    manifest_hash = local_file.ansible_users.id
  }

  provisioner "local-exec" {
    command = "scp -o BatchMode=yes ${path.root}/scripts/users.auto.yml ssh.auto-deploy.net:/tmp/users.auto.yml"
  }
}
