# Migrating to v7

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

v7 lets the data plane run in a region that has only two availability zones. Three-zone regions keep a third private subnet.

## What changed

The main and quarantine VPCs omit private subnet 3 when the region has only two zones. In that case `existing_private_subnet_3_id`, `existing_quarantine_private_subnet_3_id`, and the Loop sandbox's third subnet ID are optional. A region with three or more zones still requires them. The Loop runtime sandbox creates two connector subnets when only two zones exist, instead of indexing a third zone.

`moved` blocks keep an existing private subnet 3, and its route table association, in place. A normal upgrade in a three-zone region does not replace those subnets.

## Upgrade steps

1. **Bump the module to v7** and run `terraform plan`.

   In a three-zone region the plan should move private subnet 3 and its route association in the main VPC, and the same pair in the quarantine VPC when that VPC is module-managed. It should not show those subnets as destroy and create.

2. **Apply** once the plan shows only the moves, plus any unrelated changes you expect.

## Downgrade

Do not downgrade to v6 after applying v7. v6 has no reverse `moved` block, so the next plan recreates private subnet 3 and its route association in each module-managed VPC. That replacement interrupts the load balancer, database, and cache attachments that use the subnet.
