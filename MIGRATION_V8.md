# Migrating to v8

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://docs.braintrust.dev/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

**Note** - This guide is still growing. These sections cover the starting version and the tooling requirement. Later v8 changes add their own sections.

## Start from v7.3.0 or later

Upgrade to v7.3.0 or a later v7 release, and apply it, before you move to v8. v7.3.0 is the oldest release we support upgrading from. Coming from an older v7 release puts the v7.3.0 changes into the same apply as v8, and we don't support that combination.

## Terraform 1.17 or newer

The root module and the examples require Terraform `>= 1.17.0`, and the module is validated on Terraform 1.17.2. We didn't look for a lower minimum. Child modules under `modules/` keep `>= 1.10.0`.

v7 allows Terraform `>= 1.10.0`, so you can move every pipeline that applies this module to Terraform 1.17 while you're still on v7. Do that first. Then the v8 apply is the only change in that pipeline.

If you run Atlantis or a similar tool, check two settings before you upgrade: the Terraform version the tool runs (for example `terraform_version` in `atlantis.yaml`) and the `required_version` in your own configuration. Either one can still be pinned below 1.17, and either one stops the plan.

### OpenTofu

OpenTofu is still supported. The root module and each example have a `versions.tofu` that requires OpenTofu `>= 1.13`, and OpenTofu reads that file instead of `versions.tf`. We validate the module and the examples with `tofu validate` on OpenTofu 1.13, and that is all. The upgrade test needs Terraform's `state_key`, which OpenTofu doesn't have, so nobody has run an OpenTofu upgrade against mocked or real state. Plan an OpenTofu upgrade on a copy of your state first.
