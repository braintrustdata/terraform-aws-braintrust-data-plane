# Brainstore deployment gate

Terraform's native ASG instance refresh returns before the rollout finishes, allowing API updates to start too early.
This module invokes a Lambda that rolls out the desired Brainstore launch templates and waits for healthy replacement instances and termination of old instances.
API ECS services and API Lambdas wait for successful completion before updating.
