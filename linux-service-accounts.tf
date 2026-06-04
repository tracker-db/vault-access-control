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

  # util (192.168.2.97) only
  # mysql OS account is created by the MySQL package installer.
  # Declared here so it is tracked and reconcile shows ✓ instead of ROGUE.
  util_service_accounts = {

    "mysql" = {
      status = "enabled"
    }

  }

  # green (192.168.2.120) and blue (192.168.3.120) only
  # libvirt-qemu OS account is created by the libvirt package installer.
  # Declared here so it is tracked and reconcile shows ✓ instead of ROGUE.
  libvirt_service_accounts = {

    "libvirt-qemu" = {
      status = "enabled"
    }

  }
}
