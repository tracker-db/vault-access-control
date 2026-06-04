# principals.tf
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-GENERATED PRINCIPALS FILES
#
# This eliminates the drift problem: principals.d/ files
# are generated from roles.tf, not maintained manually.
#
# After `terraform apply`, run:
#   ./scripts/sync-principals.sh
# to push these to target VMs.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

locals {
  # Build a map: target_host → { user_type → [list of resource principals] }
  #
  # Example output:
  # {
  #   "vm-1.lab.internal" = {
  #     "root"   = ["utility-servers"]
  #     "deploy" = ["utility-servers"]
  #   }
  #   "bastion.lab.internal" = {
  #     "root"   = ["bastion"]
  #     "deploy" = ["bastion"]
  #   }
  # }

  # Step 1: Flatten all grants into target → resource → access mappings
  target_grants = flatten([
    for role_name, role in local.roles : [
      for resource_name, grant in role.grants : [
        for target in grant.targets : {
          target        = target
          resource_name = resource_name
          access        = grant.access
        }
      ]
    ]
  ])

  # Step 2: Group by target host
  targets_grouped = {
    for tg in local.target_grants : tg.target => tg...
  }

  # Step 3: For each target, determine which principals each OS user gets
  principals_files = {
    for target, grants in local.targets_grouped : target => {
      # root principals: only from admin-level grants
      root = distinct([
        for g in grants : g.resource_name if g.access == "admin"
      ])
      # deploy principals: from ALL grants (admin includes deploy)
      deploy = distinct([
        for g in grants : g.resource_name
      ])
    }
  }
}

# Generate principals.d directory structure as local files
# These are committed to the repo and synced to VMs via script

resource "local_file" "principals_root" {
  for_each = {
    for target, principals in local.principals_files : target => principals
    if length(principals.root) > 0
  }

  filename = "${path.root}/principals.d/${each.key}/root"
  content  = join("\n", each.value.root)
}

resource "local_file" "principals_deploy" {
  for_each = local.principals_files

  filename = "${path.root}/principals.d/${each.key}/deploy"
  content  = join("\n", each.value.deploy)
}

output "principals_summary" {
  description = "Generated principals per target host"
  value       = local.principals_files
}
