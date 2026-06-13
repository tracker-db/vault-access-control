# policies-custom.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CUSTOM POLICIES — Pre-existing policies imported into management.
#
# Policy content is preserved exactly as found in Vault.
# Where a policy is superseded by a role-based policy, that is noted.
# Cleanup (retiring redundant policies) is a future task.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Broad admin policy — predates the role system.
# Equivalent to platform-admin + aws + transit + secrets/* + kv-v2/*.
# No new users should be assigned this; use platform-admin role instead.
resource "vault_policy" "admin" {
  name = "admin"

  policy = <<-EOT
    path "sys/health" {
      capabilities = ["read", "sudo"]
    }
    path "sys/policies/acl" {
      capabilities = ["list"]
    }
    path "sys/policies/acl/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "auth/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/auth/*" {
      capabilities = ["create", "update", "delete", "sudo"]
    }
    path "sys/auth" {
      capabilities = ["read"]
    }
    path "secret/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "secrets/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "jenkins/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "kv-v2/data/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "kv-v2/metadata/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/mounts/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/mounts" {
      capabilities = ["read"]
    }
    path "sys/storage/raft/snapshot" {
      capabilities = ["read"]
    }
    path "aws/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "transit/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

# Ansible automation — read access to the ansible backup secrets KV mount.
resource "vault_policy" "ansible" {
  name = "ansible"

  policy = <<-EOT
    path "ansibe-backups-secrets/data/*" {
      capabilities = ["read", "list"]
    }
    path "ansibe-backups-secrets/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

# Read a specific AWS credentials path from the secret/ KV store.
resource "vault_policy" "aws_credentials_policy" {
  name = "aws-credentials-policy"

  policy = <<-EOT
    path "secret/aws_credentials" {
      capabilities = ["read"]
    }
  EOT
}

# Template policy — documents a common access pattern.
resource "vault_policy" "basic_policy_template" {
  name = "basic-policy-template"

  policy = <<-EOT
    path "aws/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "secrets/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

# Cloudflare KV full management.
resource "vault_policy" "cloudflare_access" {
  name = "cloudflare-access"

  policy = <<-EOT
    path "secret/cloudflare/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
  EOT
}

# Cloudflare SSL certificates — read/update only.
resource "vault_policy" "cloudflare_ssl_certs" {
  name = "cloudflare-ssl-certs"

  policy = <<-EOT
    path "secret/cloudflare/*" {
      capabilities = ["read", "update"]
    }
  EOT
}

# ej personal policy — predates role system. Equivalent to admin + aws + transit.
# User ej is now on platform-admin role; this policy is retained for reference.
resource "vault_policy" "ej_policy" {
  name = "ej-policy"

  policy = <<-EOT
    path "sys/health" {
      capabilities = ["read", "sudo"]
    }
    path "sys/policies/acl" {
      capabilities = ["list"]
    }
    path "sys/policies/acl/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "auth/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/auth/*" {
      capabilities = ["create", "update", "delete", "sudo"]
    }
    path "sys/auth" {
      capabilities = ["read"]
    }
    path "secret/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "secrets/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "jenkins/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "kv-v2/data/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "kv-v2/metadata/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/mounts/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/mounts" {
      capabilities = ["read"]
    }
    path "aws/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "secrets/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "transit/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    path "sys/storage/raft/snapshot" {
      capabilities = ["read"]
    }
  EOT
}

# ESPCH service read access to the espch/ KV mount and its AppRole.
resource "vault_policy" "espch" {
  name = "espch"

  policy = <<-EOT
    path "espch/data/*" {
      capabilities = ["read", "list"]
    }
    path "espch/metadata/*" {
      capabilities = ["read", "list"]
    }
    path "auth/approle/role/espch-approle/role-id" {
      capabilities = ["read"]
    }
    path "auth/approle/role/espch-approle/secret-id" {
      capabilities = ["create", "update"]
    }
    path "auth/approle/login" {
      capabilities = ["create", "update"]
    }
  EOT
}

# ESPCH malcode analysis access.
resource "vault_policy" "espch_malcode_policy" {
  name = "espch-malcode-policy"

  policy = <<-EOT
    path "malcode/data/*" {
      capabilities = ["create", "update", "read", "list", "delete"]
    }
    path "malcode/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

# GCP role set read — used by accounts that need to inspect GCP rolesets.
resource "vault_policy" "gcp_role_set" {
  name = "gcp-role-set"

  policy = <<-EOT
    path "/gcp/roleset/+" {
      capabilities = ["read"]
    }
  EOT
}

# Keycloak environment secrets.
resource "vault_policy" "key_cloak_policy" {
  name = "key-cloak-policy.hcl"

  policy = <<-EOT
    path "key-cloak/env" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
  EOT
}


# Root-equivalent — path "*" full access. Retained from pre-role era.
# No users should be assigned this. Candidate for retirement.
resource "vault_policy" "root_equivalent" {
  name = "root-equivalent"

  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

# SSH OTP credential access for a specific role.
resource "vault_policy" "ssh_access_policy" {
  name = "ssh-access-policy"

  policy = <<-EOT
    path "ssh/creds/my-role" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
  EOT
}

# Read SSH key from kubeadm-cluster KV.
resource "vault_policy" "ssh_key_read" {
  name = "ssh-key-read"

  policy = <<-EOT
    path "kubeadm-cluster/data/ssh-key" {
      capabilities = ["read"]
    }
  EOT
}

# SSH key management in the kv/ store.
resource "vault_policy" "ssh_key_policy" {
  name = "ssh_key_policy"

  policy = <<-EOT
    path "auth/ssh/login" {
      capabilities = ["create"]
      allowed_parameters = {
        "username" = ["root"]
        "ip" = ["*"]
      }
    }
    path "kv/ssh_key/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
  EOT
}

# Pipeline CI — read-only access to pipeline secrets in tracker-db KV.
# Used by the self-hosted runner on util when running Terraform for the pipeline.
resource "vault_policy" "pipeline_reader" {
  name = "pipeline-reader"

  policy = <<-EOT
    path "tracker-db/data/module-baremetal-host" {
      capabilities = ["read"]
    }
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
  EOT
}

# Ticket / tracker-db full access.
resource "vault_policy" "ticket_policy" {
  name = "ticket-policy"

  policy = <<-EOT
    path "tracker-db/data/*" {
      capabilities = ["create", "update", "read", "list", "delete"]
    }
    path "tracker-db/metadata/*" {
      capabilities = ["read", "list"]
    }
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
  EOT
}

# CI read for the tracker API auth token.
resource "vault_policy" "tracker_ci" {
  name = "tracker-ci"

  policy = <<-EOT
    path "tracker-db/data/API_AUTH_TOKEN" {
      capabilities = ["read"]
    }
  EOT
}

# Legacy placeholder policies — referenced by old test paths.
resource "vault_policy" "users_list_policy" {
  name = "users-list-policy"

  policy = <<-EOT
    path "secret/users/xyz1" {
      capabilities = ["list"]
    }
  EOT
}

resource "vault_policy" "users_read_policy" {
  name = "users-read-policy"

  policy = <<-EOT
    path "secret/users/xyz1" {
      capabilities = ["list"]
    }
  EOT
}

# Full SSH CA management.
resource "vault_policy" "vault_ssh" {
  name = "vault-ssh"

  policy = <<-EOT
    path "ssh/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "ssh/verify" {
      capabilities = ["create", "update"]
    }
  EOT
}

# Cloudflare zone record read.
resource "vault_policy" "zone" {
  name = "zone"

  policy = <<-EOT
    path "secret/cloudflare/cloudflare_zones/nextresearch-www-record_record_id" {
      capabilities = ["read"]
    }
  EOT
}
