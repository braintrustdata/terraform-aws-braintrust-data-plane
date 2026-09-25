# Brainstore deployment gate

This internal module deploys the `BrainstoreDeployment` Lambda built in the Braintrust repository's `api-ts` project. Terraform updates the existing ASGs' numbered launch-template versions, then invokes the helper synchronously. Three sequential invocations carry continuation state across Lambda's execution limit. The final invocation must report completion; Lambda exceptions or a pending final result stop the apply before API services update.

The helper owns instance refreshes. Do not add a native `instance_refresh` block to the ASGs or restore launch-template-triggered ASG replacement. Terraform waits for healthy capacity when creating an ASG, but healthy old capacity does not prove that an update has rolled out. The helper checks the actual instance versions, target health, refresh status, and termination of old instances. Existing ASG identities and Terraform resource addresses stay unchanged during routine updates.

Only the API ECS service resources and API-related Lambda functions depend on `completion_id`. Keep bootstrap resources and the API ALB outside that dependency. Brainstore retains the existing SSM proxy URL lookup; the ECS URL's parameter-version reference targets the specific module instance to avoid depending on the entire API module.

## Release coordination

1. Merge/build the helper implementation in the Braintrust repository. Its Bazel target is `//api-ts:lambda_brainstore_deployment_zip`, and the normal regional publisher stages it as `BrainstoreDeployment`.
2. Publish the chosen build tag to all supported regional asset buckets, and set `VERSIONS.json` here to that published tag. The checked-in pin identifies the implementation commit prepared with this change; it must be published before releasing this module.
3. Validate a real non-production deployment using the generated IAM role: initial creation, a simultaneous Brainstore/API version update, failed refresh, and interruption/retry. Confirm API updates begin only after old Brainstore instances terminate.
4. Release the Terraform module after the artifact exists in every supported region. Application Lambda overrides deliberately do not change the helper pin.

Mock tests cover wiring and failure propagation. They cannot validate AWS authorization, eventual consistency, or actual instance boot timing. The helper has read permissions plus `StartInstanceRefresh` restricted by both ASG name and deployment tag; it uses the configuration Terraform has already installed and does not require `iam:PassRole` or ASG update permissions.

The function depends on its IAM policy, but a successful policy attachment does not guarantee immediate propagation to every AWS service. The helper retries authorization errors during the first two minutes of each invocation, within its existing time budget. Persistent permission errors still stop the apply with the original AWS error.

A failed final invocation is not recorded as a completed deployment. Rerunning apply resumes through live AWS inspection; it does not require state surgery. Terraform's usual deployment state lock must remain enabled. The invocation resources use the default `CREATE_ONLY` lifecycle, so deleting the module does not invoke the helper.
