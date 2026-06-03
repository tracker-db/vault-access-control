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

    # nandha holds nandhapo in addition to platform-admin.
    # nandhapo grants:
    #   - aws/*      full CRUD+sudo on the AWS secrets engine
    #   - secrets/*  full CRUD on the secrets/ KV mount
    # No other managed user currently has AWS engine access — see Phase 2
    # backlog to decide whether aws/* belongs on platform-admin for everyone
    # or becomes a separate role. Until then extra_policies preserves access.
    "nandha" = {
      roles          = ["platform-admin"]
      email          = "nandha@lab.internal"
      extra_policies = ["nandhapo"]
    }

    # Previously had: jenkins policy (decommissioned) — reset to read-only
    "joe" = {
      roles = ["read-only"]
      email = "joe@lab.internal"
    }

    # ── Bastion OS users — added from /etc/passwd audit ─────
    # behnam authored the original Vault policies — platform-admin
    "behnam" = {
      roles = ["platform-admin"]
      email = "behnam@lab.internal"
    }
    # ejbest is ej's alternate OS account — platform-admin
    "ejbest" = {
      roles = ["platform-admin"]
      email = "ej@lab.internal"
    }

    # All remaining bastion OS users — operator (bastion deploy access).
    # Role unclear or not confirmed as sudoer. Upgrade individually as needed.
    "aman" = {
      roles = ["operator"]
      email = "aman@lab.internal"
    }
    "aqib" = {
      roles = ["operator"]
      email = "aqib@lab.internal"
    }
    "artif" = {
      roles = ["operator"]
      email = "artif@lab.internal"
    }
    "bhavesh" = {
      roles = ["operator"]
      email = "bhavesh@lab.internal"
    }
    "boby" = {
      roles = ["operator"]
      email = "boby@lab.internal"
    }
    "es" = {
      roles = ["operator"]
      email = "es@lab.internal"
    }
    "farukh" = {
      roles = ["operator"]
      email = "farukh@lab.internal"
    }
    "fawaz-test" = {
      roles = ["operator"]
      email = "fawaz-test@lab.internal"
    }
    "golla" = {
      roles = ["operator"]
      email = "golla@lab.internal"
    }
    "hamza" = {
      roles = ["operator"]
      email = "hamza@lab.internal"
    }
    "jerry" = {
      roles = ["operator"]
      email = "jerry@lab.internal"
    }
    "jorge" = {
      roles = ["operator"]
      email = "jorge@lab.internal"
    }
    "kishor" = {
      roles = ["operator"]
      email = "kishor@lab.internal"
    }
    "lucky" = {
      roles = ["operator"]
      email = "lucky@lab.internal"
    }
    "mangash" = {
      roles = ["operator"]
      email = "mangash@lab.internal"
    }
    "manish" = {
      roles = ["operator"]
      email = "manish@lab.internal"
    }
    "miguel" = {
      roles = ["operator"]
      email = "miguel@lab.internal"
    }
    "neel" = {
      roles = ["operator"]
      email = "neel@lab.internal"
    }
    "nirav" = {
      roles = ["operator"]
      email = "nirav@lab.internal"
    }
    "omen" = {
      roles = ["operator"]
      email = "omen@lab.internal"
    }
    "pavan" = {
      roles = ["operator"]
      email = "pavan@lab.internal"
    }
    "peterlight" = {
      roles = ["operator"]
      email = "peterlight@lab.internal"
    }
    "ramu" = {
      roles = ["operator"]
      email = "ramu@lab.internal"
    }
    "ravi" = {
      roles = ["operator"]
      email = "ravi@lab.internal"
    }
    "roy" = {
      roles = ["operator"]
      email = "roy@lab.internal"
    }
    "saif" = {
      roles = ["operator"]
      email = "saif@lab.internal"
    }
    "santosh" = {
      roles = ["operator"]
      email = "santosh@lab.internal"
    }
    "sergej" = {
      roles = ["operator"]
      email = "sergej@lab.internal"
    }
    "solomon" = {
      roles = ["operator"]
      email = "solomon@lab.internal"
    }
    "taimour" = {
      roles = ["operator"]
      email = "taimour@lab.internal"
    }
    "test" = {
      roles = ["operator"]
      email = "test@lab.internal"
    }
    "testuser" = {
      roles = ["operator"]
      email = "testuser@lab.internal"
    }
    "tim" = {
      roles = ["operator"]
      email = "tim@lab.internal"
    }
    "vikhil" = {
      roles = ["operator"]
      email = "vikhil@lab.internal"
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
