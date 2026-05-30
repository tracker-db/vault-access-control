# roles.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ROLE DEFINITIONS — What does each role grant?
#
# Roles define ACCESS BOUNDARIES. Users and service accounts
# are assigned roles — they never reference resources directly.
#
# To add a new server to an existing role: update the grants here.
# To create a new access tier: add a new role here.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  roles = {

    # ──────────────────────────────────────────
    # Platform Admin — full root to everything
    # ──────────────────────────────────────────
    "platform-admin" = {
      description = "Full admin access to all lab infrastructure"
      grants = {
        "utility-servers" = {
          targets = [
            "vm-1.lab.internal",
            "vm-2.lab.internal",
            "vm-3.lab.internal",
          ]
          access  = "admin"
          ttl     = "8h"
          max_ttl = "24h"
        }
        "bastion" = {
          targets = ["bastion.lab.internal"]
          access  = "admin"
          ttl     = "4h"
          max_ttl = "8h"
        }
        "build-server" = {
          targets = ["build.lab.internal"]
          access  = "admin"
          ttl     = "8h"
          max_ttl = "24h"
        }
      }
    }

    # ──────────────────────────────────────────
    # K8s Operator — access to cluster nodes
    # ──────────────────────────────────────────
    "k8s-operator" = {
      description = "Read access to Kubernetes cluster nodes"
      grants = {
        "k8s-blue" = {
          targets = [
            "k8s-blue-node1.lab.internal",
            "k8s-blue-node2.lab.internal",
            "k8s-blue-node3.lab.internal",
          ]
          access  = "read"
          ttl     = "4h"
          max_ttl = "8h"
        }
        "k8s-green" = {
          targets = [
            "k8s-green-node1.lab.internal",
            "k8s-green-node2.lab.internal",
            "k8s-green-node3.lab.internal",
          ]
          access  = "read"
          ttl     = "4h"
          max_ttl = "8h"
        }
        "bastion" = {
          targets = ["bastion.lab.internal"]
          access  = "read"
          ttl     = "4h"
          max_ttl = "8h"
        }
      }
    }

    # ──────────────────────────────────────────
    # Deployer — CI/CD pipelines, build server
    # ──────────────────────────────────────────
    "deployer" = {
      description = "Deploy access for CI/CD and automation"
      grants = {
        "build-server" = {
          targets = ["build.lab.internal"]
          access  = "read"
          ttl     = "2h"
          max_ttl = "4h"
        }
        "utility-servers" = {
          targets = [
            "vm-1.lab.internal",
            "vm-2.lab.internal",
            "vm-3.lab.internal",
          ]
          access  = "read"
          ttl     = "1h"
          max_ttl = "2h"
        }
      }
    }

    # ──────────────────────────────────────────
    # Read-Only — monitoring, auditing
    # ──────────────────────────────────────────
    "read-only" = {
      description = "Read-only access for monitoring and audit"
      grants = {
        "utility-servers" = {
          targets = [
            "vm-1.lab.internal",
            "vm-2.lab.internal",
            "vm-3.lab.internal",
          ]
          access  = "read"
          ttl     = "2h"
          max_ttl = "4h"
        }
        "bastion" = {
          targets = ["bastion.lab.internal"]
          access  = "read"
          ttl     = "2h"
          max_ttl = "4h"
        }
      }
    }

  }
}
