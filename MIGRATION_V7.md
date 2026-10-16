# Migrating to v7

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

v7 lets the data plane run in a region that has only two availability zones. Three-zone regions keep a third private subnet.

## What changed

The main and quarantine VPCs omit private subnet 3 when the region has only two zones. In that case leave `existing_private_subnet_3_id`, `existing_quarantine_private_subnet_3_id`, and the Loop sandbox's third subnet ID unset. Setting one fails the plan. A region with three or more zones still requires them. The Loop runtime sandbox creates two connector subnets when only two zones exist, instead of indexing a third zone.

`moved` blocks keep an existing private subnet 3, and its route table association, in place. A normal upgrade in a three-zone region does not replace those subnets.

Quarantine in a two-zone region leaves `QUARANTINE_PRIVATE_SUBNET_3_ID` empty. This module pins the Lambda image to `v2.17.0` (`lambda_version_tag` in `modules/services/VERSIONS.json`) and the API image to `v2.17.0` (`api` in `modules/api-ecs/VERSIONS.json`). v2.17.0 still requires three quarantine subnet IDs, so a default apply in a two-zone region turns quarantine off. Do not tag v7 until both pins are a release that includes the two-subnet quarantine change. Three-zone regions still set all three IDs, so those pins do not change them.

If a bring-your-own VPC set `existing_private_subnet_3_id` to the same ID as subnet 1 or subnet 2, remove that duplicate before upgrading. v7 rejects repeated subnet IDs. In a two-zone region, leave the third ID unset. Setting it fails the plan. In a three-zone region, supply the real third subnet.

## Upgrade steps

1. **Bump the module to v7** and run `terraform plan`.

   In a three-zone region the plan moves private subnet 3 and its route association in the main VPC, and the same pair in the quarantine VPC when that VPC is module-managed. Every stack also creates `terraform_data.network_zone_requirements`. That resource holds the zone checks and does not create AWS infrastructure. The plan should not destroy and create private subnet 3.

2. **Apply** once the plan shows those moves, the new `terraform_data.network_zone_requirements` resource, and any unrelated changes you expect.

## Downgrade

Do not downgrade to v6 after applying v7. v6 has no reverse `moved` block, so the next plan destroys private subnet 3 at its counted address and creates it again without an index, in each module-managed VPC. RDS, ElastiCache, Lambda, and load balancers still use that subnet. AWS refuses to delete a subnet that has those attachments, so the apply fails partway through: the replacement subnet is not in place, and the original subnet is still there. Stay on v7.
