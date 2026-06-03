# users.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HUMAN USERS — Who are the engineers?
#
# To onboard:   Add a user block, open PR, merge, set password.
# To disable:   Set status = "disabled", open PR, merge.
#               → Vault: all policies removed (no access)
#               → OS:    account locked   (cannot log in, home kept)
# To offboard:  Step 1 — Set status = "removed", open PR, merge.
#               → Vault: no change (already no policies)
#               → OS:    userdel -r (account + home dir deleted by Ansible)
#               Step 2 — Remove the user block entirely, open PR, merge.
#               → Vault: userpass account deleted
#
# Fields:
#   roles          required  list of role names from roles.tf
#   email          required  user's email address
#   status         required  "enabled" or "disabled" — controls Vault access
#   extra_policies optional  legacy custom policies not yet in a role
#
# Users NEVER reference servers directly. They get roles.
# Roles define what servers they can access (see roles.tf).
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  users = {

    "ej" = {
      roles  = ["platform-admin"]
      email  = "ej@lab.internal"
      status = "enabled"
    }
    "ejbest" = {
      roles  = ["platform-admin"]
      email  = "ej@lab.internal"
      status = "enabled"
    }
    "desmond" = {
      roles  = ["platform-admin"]
      email  = "desmond@lab.internal"
      status = "enabled"
    }
    "fawaz" = {
      roles  = ["platform-admin"]
      email  = "fawaz@lab.internal"
      status = "enabled"
    }

  }
}
