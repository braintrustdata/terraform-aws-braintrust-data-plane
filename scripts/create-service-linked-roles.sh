#!/bin/bash
set -euo pipefail

SERVICE_NAME="autoscaling.amazonaws.com"

# Try to create the service-linked role
if CREATE_ROLE_OUTPUT=$(aws iam create-service-linked-role --aws-service-name "$SERVICE_NAME" 2>&1); then
    echo "Service-linked role for '$SERVICE_NAME' created successfully."
else

    # Check if the error indicates the role already exists
    if echo "$CREATE_ROLE_OUTPUT" | grep -q "has been taken in this account"; then
        echo "Service-linked role for '$SERVICE_NAME' already exists."
    else
        echo "Failed to create service-linked role: $CREATE_ROLE_OUTPUT" >&2
        exit 1
    fi
fi
echo "AWS account is ready to use for the Braintrust data plane."
