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

    # ── Platform Team (full lab access) ──────
    "tom" = {
      roles  = ["platform-admin"]
      email  = "tom@lab.internal"
      status = "disabled"
    }
    "harry" = {
      roles  = ["platform-admin"]
      email  = "harry@lab.internal"
      status = "disabled"
    }
    "sally" = {
      roles  = ["platform-admin"]
      email  = "sally@lab.internal"
      status = "disabled"
    }
    "fawaz" = {
      roles  = ["platform-admin"]
      email  = "fawaz@lab.internal"
      status = "enabled"
    }
    "desmond" = {
      roles  = ["platform-admin"]
      email  = "desmond@lab.internal"
      status = "enabled"
    }

    # ── K8s Team (cluster access only) ───────
    "rich" = {
      roles  = ["k8s-operator"]
      email  = "rich@lab.internal"
      status = "disabled"
    }
    "vishal" = {
      roles  = ["k8s-operator"]
      email  = "vishal@lab.internal"
      status = "disabled"
    }

    # ── Multi-role example ───────────────────
    # A user can have multiple roles. Policies are merged.
    # "jane" = {
    #   roles  = ["k8s-operator", "deployer"]
    #   email  = "jane@lab.internal"
    #   status = "enabled"
    # }

    # ubuntu exists on bastion 1020 only — default cloud image account.
    "ubuntu" = {
      roles  = ["operator"]
      email  = "ubuntu@lab.internal"
      status = "disabled"
    }

    # ── Imported — previously unmanaged accounts ──
    # Previously had: admin policy
    "arti" = {
      roles  = ["platform-admin"]
      email  = "arti@lab.internal"
      status = "disabled"
    }
    "niam" = {
      roles  = ["platform-admin"]
      email  = "niam@lab.internal"
      status = "disabled"
    }
    "richard" = {
      roles  = ["platform-admin"]
      email  = "richard@lab.internal"
      status = "disabled"
    }

    # Previously had: root-equivalent policy
    "ej" = {
      roles  = ["platform-admin"]
      email  = "ej@lab.internal"
      status = "enabled"
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
      status         = "removed"
      extra_policies = ["nandhapo"]
    }

    # Previously had: jenkins policy (decommissioned) — reset to read-only
    "joe" = {
      roles  = ["read-only"]
      email  = "joe@lab.internal"
      status = "disabled"
    }

    # ── Bastion OS users — added from /etc/passwd audit ─────
    # behnam authored the original Vault policies — platform-admin
    "behnam" = {
      roles  = ["platform-admin"]
      email  = "behnam@lab.internal"
      status = "disabled"
    }
    # ejbest is ej's alternate OS account — platform-admin
    "ejbest" = {
      roles  = ["platform-admin"]
      email  = "ej@lab.internal"
      status = "enabled"
    }

    # All remaining bastion OS users — operator (bastion deploy access).
    # Role unclear or not confirmed as sudoer. Upgrade individually as needed.
    "aman" = {
      roles  = ["operator"]
      email  = "aman@lab.internal"
      status = "disabled"
    }
    "aqib" = {
      roles  = ["operator"]
      email  = "aqib@lab.internal"
      status = "disabled"
    }
    "artif" = {
      roles  = ["operator"]
      email  = "artif@lab.internal"
      status = "disabled"
    }
    "bhavesh" = {
      roles  = ["operator"]
      email  = "bhavesh@lab.internal"
      status = "disabled"
    }
    "boby" = {
      roles  = ["operator"]
      email  = "boby@lab.internal"
      status = "disabled"
    }
    "es" = {
      roles  = ["operator"]
      email  = "es@lab.internal"
      status = "disabled"
    }
    "farukh" = {
      roles  = ["operator"]
      email  = "farukh@lab.internal"
      status = "disabled"
    }
    "fawaz-test" = {
      roles  = ["operator"]
      email  = "fawaz-test@lab.internal"
      status = "enabled"
    }
    "golla" = {
      roles  = ["operator"]
      email  = "golla@lab.internal"
      status = "disabled"
    }
    "hamza" = {
      roles  = ["operator"]
      email  = "hamza@lab.internal"
      status = "disabled"
    }
    "jerry" = {
      roles  = ["operator"]
      email  = "jerry@lab.internal"
      status = "disabled"
    }
    "jorge" = {
      roles  = ["operator"]
      email  = "jorge@lab.internal"
      status = "disabled"
    }
    "kishor" = {
      roles  = ["operator"]
      email  = "kishor@lab.internal"
      status = "disabled"
    }
    "lucky" = {
      roles  = ["operator"]
      email  = "lucky@lab.internal"
      status = "disabled"
    }
    "mangash" = {
      roles  = ["operator"]
      email  = "mangash@lab.internal"
      status = "disabled"
    }
    "manish" = {
      roles  = ["operator"]
      email  = "manish@lab.internal"
      status = "disabled"
    }
    "miguel" = {
      roles  = ["operator"]
      email  = "miguel@lab.internal"
      status = "disabled"
    }
    "neel" = {
      roles  = ["operator"]
      email  = "neel@lab.internal"
      status = "disabled"
    }
    "nirav" = {
      roles  = ["operator"]
      email  = "nirav@lab.internal"
      status = "disabled"
    }
    "omen" = {
      roles  = ["operator"]
      email  = "omen@lab.internal"
      status = "disabled"
    }
    "pavan" = {
      roles  = ["operator"]
      email  = "pavan@lab.internal"
      status = "disabled"
    }
    "peterlight" = {
      roles  = ["operator"]
      email  = "peterlight@lab.internal"
      status = "disabled"
    }
    "ramu" = {
      roles  = ["operator"]
      email  = "ramu@lab.internal"
      status = "disabled"
    }
    "ravi" = {
      roles  = ["operator"]
      email  = "ravi@lab.internal"
      status = "disabled"
    }
    "roy" = {
      roles  = ["operator"]
      email  = "roy@lab.internal"
      status = "disabled"
    }
    "saif" = {
      roles  = ["operator"]
      email  = "saif@lab.internal"
      status = "disabled"
    }
    "santosh" = {
      roles  = ["operator"]
      email  = "santosh@lab.internal"
      status = "disabled"
    }
    "sergej" = {
      roles  = ["operator"]
      email  = "sergej@lab.internal"
      status = "disabled"
    }
    "solomon" = {
      roles  = ["operator"]
      email  = "solomon@lab.internal"
      status = "disabled"
    }
    "taimour" = {
      roles  = ["operator"]
      email  = "taimour@lab.internal"
      status = "disabled"
    }
    "test" = {
      roles  = ["operator"]
      email  = "test@lab.internal"
      status = "disabled"
    }
    "testuser" = {
      roles  = ["operator"]
      email  = "testuser@lab.internal"
      status = "disabled"
    }
    "tim" = {
      roles  = ["operator"]
      email  = "tim@lab.internal"
      status = "disabled"
    }
    "vikhil" = {
      roles  = ["operator"]
      email  = "vikhil@lab.internal"
      status = "disabled"
    }

    # Previously had: no policies — read-only baseline
    "air" = {
      roles  = ["read-only"]
      email  = "air@lab.internal"
      status = "disabled"
    }
    "bob" = {
      roles  = ["read-only"]
      email  = "bob@lab.internal"
      status = "disabled"
    }
    "jade" = {
      roles  = ["read-only"]
      email  = "jade@lab.internal"
      status = "disabled"
    }
    "mac" = {
      roles  = ["read-only"]
      email  = "mac@lab.internal"
      status = "disabled"
    }
    "nice" = {
      roles  = ["read-only"]
      email  = "nice@lab.internal"
      status = "disabled"
    }
    "nick" = {
      roles  = ["read-only"]
      email  = "nick@lab.internal"
      status = "disabled"
    }
    "sebastin" = {
      roles  = ["read-only"]
      email  = "sebastin@lab.internal"
      status = "disabled"
    }

  }
}
