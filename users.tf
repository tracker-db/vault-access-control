# users.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HUMAN USERS — Who are the engineers?
#
# To onboard:  Add a user block, open PR, merge, set password.
# To offboard: Remove the user block, open PR, merge. Done.
# To change access: Move them to a different role.
#
# Users NEVER reference servers directly. They get roles.
# Roles define what servers they can access (see roles.tf).
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  users = {

    # ── Platform Team (full lab access) ──────
    "ej" = {
      roles = ["platform-admin"]
      email = "ejbest@gmail.com"
    }
    "fawaz" = {
      roles = ["platform-admin"]
      email = "fawazadewale120@gmail.com"
    }
    "desmond" = {
      roles = ["platform-admin"]
      email = "muyukhadesmond018@gmail.com"
    }

    # ── K8s Team (cluster access only) ───────
    "rich" = {
      roles = ["k8s-operator"]
      email = "rich@lab.internal"
    }
    "vishal" = {
      roles = ["k8s-operator"]
      email = "vishal@lab.internal"
    }

    # ── Multi-role example ───────────────────
    # A user can have multiple roles. Policies are merged.
    # "jane" = {
    #   roles = ["k8s-operator", "deployer"]
    #   email = "jane@lab.internal"
    # }

  }
}
