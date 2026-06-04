# linux-service-accounts.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OS-ONLY SERVICE ACCOUNTS — Linux accounts on bastion servers.
#
# These accounts are NOT in Vault userpass and must NEVER be
# given Vault access. They exist solely for OS-level automation.
#
# Servers: bastion0 and bastion2 only — NOT on anydesk servers.
#
# To add:    Add a block here, apply, run Ansible.
# To remove: Set status = "removed", apply, run Ansible,
#            then delete the block.
#
# Accounts:
#   ansible-job-user          Ansible job runner automation
#   ansible-work              Ansible worker process account
#   ansible-work-service-account  Ansible service account for pipelines
#   auto-deploy               Automated deployment runner
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
}
