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
    "tom" = {
      roles = ["platform-admin"]
      email = "tom@lab.internal"
    }
    "harry" = {
      roles = ["platform-admin"]
      email = "harry@lab.internal"
    }
    "sally" = {
      roles = ["platform-admin"]
      email = "sally@lab.internal"
    }
    "fawaz" = {
      roles = ["platform-admin"]
      email = "fawaz@lab.internal"
    }
    "desmond" = {
      roles = ["platform-admin"]
      email = "desmond@lab.internal"
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

    # ── Imported — previously unmanaged accounts ──
    # Previously had: admin policy
    "arti" = {
      roles = ["platform-admin"]
      email = "arti@lab.internal"
    }
    "niam" = {
      roles = ["platform-admin"]
      email = "niam@lab.internal"
    }
    "richard" = {
      roles = ["platform-admin"]
      email = "richard@lab.internal"
    }

    # Previously had: root-equivalent policy
    "ej" = {
      roles = ["platform-admin"]
      email = "ej@lab.internal"
    }

    # Previously had: nandhapo (custom policy) — read-only pending role review
    "nandha" = {
      roles = ["read-only"]
      email = "nandha@lab.internal"
    }

    # Previously had: jenkins policy (decommissioned) — reset to read-only
    "joe" = {
      roles = ["read-only"]
      email = "joe@lab.internal"
    }

    # Previously had: no policies — read-only baseline
    "air" = {
      roles = ["read-only"]
      email = "air@lab.internal"
    }
    "bob" = {
      roles = ["read-only"]
      email = "bob@lab.internal"
    }
    "jade" = {
      roles = ["read-only"]
      email = "jade@lab.internal"
    }
    "mac" = {
      roles = ["read-only"]
      email = "mac@lab.internal"
    }
    "nice" = {
      roles = ["read-only"]
      email = "nice@lab.internal"
    }
    "nick" = {
      roles = ["read-only"]
      email = "nick@lab.internal"
    }
    "sebastin" = {
      roles = ["read-only"]
      email = "sebastin@lab.internal"
    }

  }
}
