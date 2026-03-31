#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#     "boto3",
# ]
# ///

"""Empty all S3 buckets for a Braintrust deployment so they can be deleted by terraform destroy.

The Braintrust module creates three buckets with the prefix <deployment_name>-:
  - <deployment_name>-brainstore-<random>
  - <deployment_name>-code-bundles-<random>
  - <deployment_name>-lambda-responses-<random>

The Braintrust platform may write objects to these buckets after deployment.
S3 buckets must be empty before they can be deleted, so terraform destroy will
fail if any objects exist. This script empties the buckets (including versioned
objects and delete markers) to unblock destroy.
"""

import boto3
import argparse
import sys


def find_deployment_buckets(s3_client, deployment_name):
    expected_prefixes = [
        f"{deployment_name}-brainstore-",
        f"{deployment_name}-code-bundles-",
        f"{deployment_name}-lambda-responses-",
    ]
    response = s3_client.list_buckets()
    matching = []
    for bucket in response["Buckets"]:
        name = bucket["Name"]
        if any(name.startswith(prefix) for prefix in expected_prefixes):
            matching.append(name)
    return sorted(matching)


def get_bucket_object_count(s3_client, bucket_name):
    """Return approximate count of objects (including versions and delete markers)."""
    count = 0
    paginator = s3_client.get_paginator("list_object_versions")
    for page in paginator.paginate(Bucket=bucket_name):
        count += len(page.get("Versions", []))
        count += len(page.get("DeleteMarkers", []))
    return count


def empty_bucket(s3_client, bucket_name):
    """Delete all object versions and delete markers from a bucket."""
    paginator = s3_client.get_paginator("list_object_versions")
    total_deleted = 0

    for page in paginator.paginate(Bucket=bucket_name):
        to_delete = []

        for version in page.get("Versions", []):
            to_delete.append({
                "Key": version["Key"],
                "VersionId": version["VersionId"],
            })

        for marker in page.get("DeleteMarkers", []):
            to_delete.append({
                "Key": marker["Key"],
                "VersionId": marker["VersionId"],
            })

        if not to_delete:
            continue

        # delete_objects accepts max 1000 keys per call
        for i in range(0, len(to_delete), 1000):
            batch = to_delete[i : i + 1000]
            response = s3_client.delete_objects(
                Bucket=bucket_name, Delete={"Objects": batch, "Quiet": True}
            )
            errors = response.get("Errors", [])
            if errors:
                for err in errors:
                    print(f"  Error deleting {err['Key']}: {err['Code']} - {err['Message']}")
            total_deleted += len(batch) - len(errors)

    return total_deleted


def main():
    parser = argparse.ArgumentParser(
        description="Empty S3 buckets for a Braintrust deployment to unblock terraform destroy.",
        usage="%(prog)s <deployment_name> [--delete]",
    )
    parser.add_argument("deployment_name", nargs="?", help="The deployment_name used in the Terraform module")
    parser.add_argument(
        "--delete",
        action="store_true",
        help="Actually delete all objects. Without this flag, only lists what would be deleted.",
    )

    args = parser.parse_args()

    if not args.deployment_name:
        parser.print_help()
        sys.exit(1)

    s3_client = boto3.client("s3")

    print(f"Looking for S3 buckets with prefix: {args.deployment_name}-")
    buckets = find_deployment_buckets(s3_client, args.deployment_name)

    if not buckets:
        print("No matching buckets found.")
        sys.exit(0)

    print(f"\nFound {len(buckets)} bucket(s):")
    for bucket in buckets:
        count = get_bucket_object_count(s3_client, bucket)
        print(f"  {bucket} ({count} objects/versions)")

    if not args.delete:
        print("\nUse --delete to empty these buckets.")
        sys.exit(0)

    print()
    for bucket in buckets:
        print(f"Emptying: {bucket}")
        deleted = empty_bucket(s3_client, bucket)
        print(f"  Deleted {deleted} objects/versions")

    print("\nDone. Buckets are now empty and can be deleted by terraform destroy.")


if __name__ == "__main__":
    main()
