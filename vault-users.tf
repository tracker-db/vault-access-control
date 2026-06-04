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
#   roles           required  list of role names from roles.tf
#   email           required  user's email address
#   status          required  "enabled" or "disabled" — controls Vault access
#   extra_policies  optional  legacy custom policies not yet in a role
#   authorized_keys optional  list of SSH public keys deployed to ~/.ssh/authorized_keys
#                             on all servers — use for phones/devices that cannot run
#                             the Vault cert signing workflow. Revoke by removing the key.
#
# Users NEVER reference servers directly. They get roles.
# Roles define what servers they can access (see roles.tf).
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  users = {

    "ej" = {
      roles          = ["platform-admin"]
      email          = "ej@lab.internal"
      status         = "enabled"
      extra_policies = ["root-equivalent"]
      authorized_keys = [
        # Paste phone public key here — Ansible deploys it to ~/.ssh/authorized_keys
        # on all servers. Phone connects directly with its private key, no Vault needed.
        # To revoke: remove the line, apply, run Ansible.
        # "ssh-ed25519 AAAA... ej-phone",
      ]
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
