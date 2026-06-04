# linux-service-accounts.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OS-ONLY SERVICE ACCOUNTS
#
# These accounts are NOT in Vault userpass and must NEVER
# be given Vault access. OS automation only.
#
# To add:    Add a block, apply, run Ansible.
# To remove: Set status = "removed", apply, run Ansible,
#            then delete the block.
#
# linux_service_accounts  — bastions only
#   ansible-job-user, ansible-work, ansible-work-service-account,
#   auto-deploy
#
# core_server_service_accounts  — core-servers only (util, green, blue)
#   app-service  — shared service account replacing ej on core-servers
#                  Password managed in Vault KV:
#                  secret/shared/app-service/credentials
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  linux_service_accounts = {

    "ansible-job-user" = {
      status = "enabled"
    }
    "ansible-work" = {
      status = "enabled"
    }
    "ansible-work-service-account" = {
      status = "enabled"
    }
    "auto-deploy" = {
      status = "enabled"
    }

  }

  core_server_service_accounts = {

    "app-service" = {
      status = "enabled"
    }

  }
}
