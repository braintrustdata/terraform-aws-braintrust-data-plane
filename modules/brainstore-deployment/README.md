# Brainstore deployment gate

Terraform's native ASG instance refresh returns before the rollout finishes, allowing API updates to start too early.
This module invokes a Lambda that rolls out the configured reader and fast-reader Brainstore launch templates and waits for healthy replacement instances and termination of old instances. Writer pools are not included in this gate.
API ECS services and API Lambdas wait for successful completion before updating.
