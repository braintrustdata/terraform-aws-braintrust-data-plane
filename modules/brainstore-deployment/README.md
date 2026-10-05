# Brainstore deployment gate

Terraform's native ASG instance refresh returns before the rollout finishes, allowing API updates to start too early.
This module invokes a Lambda that rolls out the configured reader and fast-reader Brainstore launch templates and waits for healthy replacement instances and termination of old instances. Writer pools are not included in this gate.
API ECS services and API Lambdas wait for successful completion before updating.

Terraform invokes the controller twice in sequence, using the same deployment and a fresh 10-minute waiting budget for each attempt. The first attempt requests a `timed_out` response so Terraform can continue to the second attempt in the same apply. The final attempt throws on timeout, and only its `complete` response releases the API gate. When the first attempt completes, the final attempt rechecks readiness without starting another refresh. AWS refresh failures and other errors stop the apply immediately. Publish the helper with `return_on_timeout` support before releasing this module change.
