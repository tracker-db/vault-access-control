# mounts.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECRETS ENGINE MOUNTS — all Vault mounts under management.
#
# secret/ (KV v2, managed) is declared in secrets.tf.
# ssh/ (SSH CA, managed) is used by the vault-rbac module.
# All other mounts are declared here.
#
# Mount-specific configuration (AWS creds, GCP SA keys,
# PKI CA certs, Transit key configs) is Phase 3 work.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── AWS Secrets Engine ───────────────────────────────────
resource "vault_mount" "aws" {
  path = "aws"
  type = "aws"
  lifecycle { prevent_destroy = true }
}

# ── GCP Secrets Engines ──────────────────────────────────
resource "vault_mount" "gcp_credentials_backend" {
  path        = "gcp-credentials-backend"
  type        = "gcp"
  description = "GCP secrets engine for issuing temporary credentials using credentials"
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "gcp_ejb" {
  path        = "gcp-ejb"
  type        = "gcp"
  description = "GCP secrets engine for issuing temporary credentials using credentials"
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "gcp_ejb2" {
  path        = "gcp-ejb2"
  type        = "gcp"
  description = "GCP secrets engine for issuing temporary credentials using credentials"
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "gcp_test_test" {
  path               = "gcp-test-test"
  type               = "gcp"
  listing_visibility = "hidden"
}

resource "vault_mount" "identify_token_ttl" {
  path        = "identify_token_ttl"
  type        = "gcp"
  description = "GCP secrets engine for issuing GCP OAuth token"
  lifecycle { prevent_destroy = true }
}

# ── PKI Engine ───────────────────────────────────────────
resource "vault_mount" "pki" {
  path = "pki"
  type = "pki"
  lifecycle { prevent_destroy = true }
}

# ── Transit Engine ───────────────────────────────────────
resource "vault_mount" "transit" {
  path = "transit"
  type = "transit"
  lifecycle { prevent_destroy = true }
}

# ── SSH Engines ──────────────────────────────────────────
# ssh/ is the SSH CA engine used by the vault-rbac module.
# The mount is declared here; the CA roles live in the module.
resource "vault_mount" "ssh_ca" {
  path = "ssh"
  type = "ssh"
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "tp_link" {
  path               = "tp-link"
  type               = "ssh"
  listing_visibility = "hidden"
  lifecycle { prevent_destroy = true }
}

# ── KV v2 Mounts ─────────────────────────────────────────
resource "vault_mount" "ansibe_backups_secrets" {
  path    = "ansibe-backups-secrets"
  type    = "kv"
  options = { version = "2" }
}

resource "vault_mount" "argo_cd" {
  path               = "argo-cd"
  type               = "kv"
  listing_visibility = "hidden"
  options            = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "cloudflare" {
  path    = "cloudflare"
  type    = "kv"
  options = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "ddd" {
  path               = "ddd"
  type               = "kv"
  listing_visibility = "hidden"
  options            = { version = "2" }
}

resource "vault_mount" "ej_prod" {
  path               = "ej-prod"
  type               = "kv"
  listing_visibility = "hidden"
  options            = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "englab_dev" {
  path    = "englab/dev"
  type    = "kv"
  options = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "espch" {
  path    = "espch"
  type    = "kv"
  options = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "jenkins_kv" {
  path    = "jenkins"
  type    = "kv"
  options = { version = "2" }
}

resource "vault_mount" "keycloak" {
  path               = "keycloak"
  type               = "kv"
  listing_visibility = "hidden"
  options            = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "kubeadm_cluster" {
  path    = "kubeadm-cluster"
  type    = "kv"
  options = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "kv_v2" {
  path    = "kv-v2"
  type    = "kv"
  options = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "libvirt" {
  path               = "libvirt"
  type               = "kv"
  listing_visibility = "hidden"
  options            = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "malcode" {
  path    = "malcode"
  type    = "kv"
  options = { version = "1" }
}

resource "vault_mount" "mytest" {
  path    = "mytest"
  type    = "kv"
  options = { version = "2" }
}

resource "vault_mount" "proxmox" {
  path    = "proxmox"
  type    = "kv"
  options = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "secrets_kv" {
  path    = "secrets"
  type    = "kv"
  options = { version = "1" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "servers" {
  path    = "servers"
  type    = "kv"
  options = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "ssh_keys" {
  path               = "ssh-keys"
  type               = "kv"
  listing_visibility = "hidden"
  options            = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "ssh_key" {
  path    = "ssh_key"
  type    = "kv"
  options = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "ssh_pass" {
  path    = "ssh_pass"
  type    = "kv"
  options = { version = "2" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "test_monitor" {
  path               = "test-monitor"
  type               = "kv"
  listing_visibility = "hidden"
  options            = { version = "2" }
}

resource "vault_mount" "tracker_db" {
  path               = "tracker-db"
  type               = "kv"
  listing_visibility = "hidden"
  options            = { version = "2" }
  lifecycle { prevent_destroy = true }
}

# ── KV v1 Mounts ─────────────────────────────────────────
resource "vault_mount" "ejbest" {
  path    = "ejbest"
  type    = "kv"
  options = { version = "1" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "kv_v1" {
  path    = "kv"
  type    = "kv"
  options = { version = "1" }
  lifecycle { prevent_destroy = true }
}

resource "vault_mount" "test_aws_iam" {
  path    = "test-aws/iam"
  type    = "kv"
  options = { version = "1" }
}
