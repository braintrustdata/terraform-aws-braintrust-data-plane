#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#     "boto3",
#     "botocore[crt]",
# ]
# ///

import argparse
import json
import re
import sys
import time
from pathlib import Path

import boto3
import botocore.exceptions


COUNT_KEYS = [
    "brainstore_instance_count",
    "brainstore_writer_instance_count",
    "brainstore_fast_reader_instance_count",
]

RDS_RESOURCE = ("module.braintrust-data-plane.module.database", "aws_db_instance", "main")
ASG_RESOURCES = {
    "brainstore": (
        "module.braintrust-data-plane.module.brainstore[0]",
        "aws_autoscaling_group",
        "brainstore",
    ),
    "brainstore_writer": (
        "module.braintrust-data-plane.module.brainstore[0]",
        "aws_autoscaling_group",
        "brainstore_writer",
    ),
    "brainstore_fast_reader": (
        "module.braintrust-data-plane.module.brainstore[0]",
        "aws_autoscaling_group",
        "brainstore_fast_reader",
    ),
}

POLL_INTERVAL_SECONDS = 5
POLL_TIMEOUT_SECONDS = 60


def parse_args():
    parser = argparse.ArgumentParser(
        description="Park or unpark a Braintrust dataplane by stopping RDS and scaling Brainstore ASGs."
    )
    parser.add_argument("action", choices=["park", "unpark"])
    parser.add_argument(
        "--dir",
        default=".",
        help="Terraform wrapper directory containing terraform.tfstate and main.tf (default: current directory)",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Show planned actions without changing AWS resources"
    )
    parser.add_argument("--yes", action="store_true", help="Skip confirmation prompt")
    return parser.parse_args()


def fail(message: str):
    print(message, file=sys.stderr)
    raise SystemExit(1)


def load_state(target_dir: Path) -> dict:
    state_path = target_dir / "terraform.tfstate"
    if not state_path.exists():
        fail(f"Terraform state file not found: {state_path}")
    try:
        return json.loads(state_path.read_text())
    except json.JSONDecodeError as exc:
        fail(f"Failed to parse Terraform state JSON: {state_path}\n{exc}")


def infer_region_from_provider(target_dir: Path) -> tuple[str, str] | None:
    provider_tf = target_dir / "provider.tf"
    if not provider_tf.exists():
        return None

    text = provider_tf.read_text()
    match = re.search(r'(?ms)provider\s+"aws"\s*\{.*?^\s*region\s*=\s*"([^"]+)"', text)
    if match is None:
        return None
    return match.group(1), f"{provider_tf} where this dataplane VPC is configured"


def infer_region_from_state(state: dict) -> tuple[str, str] | None:
    for resource in state.get("resources", []):
        for instance in resource.get("instances", []):
            attrs = instance.get("attributes", {})
            arn = attrs.get("arn")
            if isinstance(arn, str):
                match = re.match(r"^arn:aws:[^:]+:([^:]+):\d{12}:", arn)
                if match is not None:
                    return match.group(1), "Terraform state resource ARNs"

    for resource in state.get("resources", []):
        if resource.get("type") != "aws_region":
            continue
        for instance in resource.get("instances", []):
            region = instance.get("attributes", {}).get("id")
            if isinstance(region, str) and region:
                return region, "the aws_region data source in terraform.tfstate"

    return None


def infer_target_region(target_dir: Path, state: dict) -> tuple[str, str]:
    provider_region = infer_region_from_provider(target_dir)
    if provider_region:
        return provider_region

    state_region = infer_region_from_state(state)
    if state_region:
        return state_region

    fail(
        "Could not infer AWS region from the Terraform wrapper. "
        "Expected a literal provider region in provider.tf or a region-bearing ARN in terraform.tfstate."
    )


def find_resource(state: dict, module_name: str, resource_type: str, resource_name: str):
    for resource in state.get("resources", []):
        if (
            resource.get("module") == module_name
            and resource.get("type") == resource_type
            and resource.get("name") == resource_name
            and resource.get("instances")
        ):
            return resource["instances"][0].get("attributes", {})
    return None


def discover_resources(target_dir: Path, state: dict, account_id: str, region: str):
    rds_attrs = find_resource(state, *RDS_RESOURCE)
    if not rds_attrs or not rds_attrs.get("identifier"):
        fail("Could not find RDS instance identifier in terraform state.")

    asg_names = []
    asg_roles = {}
    for role, address in ASG_RESOURCES.items():
        attrs = find_resource(state, *address)
        if attrs is None:
            continue
        asg_name = attrs.get("name") or attrs.get("id")
        if not asg_name:
            fail(f"Could not determine Auto Scaling Group name for {role} from terraform state.")
        asg_names.append(asg_name)
        asg_roles[asg_name] = role

    if not asg_names:
        fail("Could not find any Brainstore Auto Scaling Groups in terraform state.")

    return {
        "directory": str(target_dir),
        "account_id": account_id,
        "region": region,
        "rds_identifier": rds_attrs["identifier"],
        "asg_names": asg_names,
        "asg_roles": asg_roles,
    }


def load_brainstore_counts(target_dir: Path) -> dict[str, int]:
    main_tf = target_dir / "main.tf"
    if not main_tf.exists():
        fail(f"Terraform config file not found: {main_tf}")

    text = main_tf.read_text()
    counts = {}
    for key in COUNT_KEYS:
        match = re.search(rf"(?m)^\s*{re.escape(key)}\s*=\s*(\d+)\s*$", text)
        if match is None:
            fail(f"Could not infer literal value for {key} from {main_tf}")
        counts[key] = int(match.group(1))
    return counts


def build_session(region: str, region_source: str):
    try:
        ambient_session = boto3.Session()
        ambient_region = ambient_session.region_name
        if ambient_region != region:
            if ambient_region:
                print(
                    f"Switching AWS region from {ambient_region} to {region} based on {region_source}."
                )
            else:
                print(f"Using AWS region {region} based on {region_source}.")
        return boto3.Session(region_name=region)
    except botocore.exceptions.ProfileNotFound as exc:
        fail(
            "AWS authentication failed: "
            f"{exc}\nRun `aws sso login` or refresh your AWS credentials, then retry."
        )


def validate_aws_auth(session):
    sts = session.client("sts")
    try:
        return sts.get_caller_identity()
    except (
        botocore.exceptions.NoCredentialsError,
        botocore.exceptions.PartialCredentialsError,
        botocore.exceptions.TokenRetrievalError,
        botocore.exceptions.UnauthorizedSSOTokenError,
        botocore.exceptions.SSOTokenLoadError,
        botocore.exceptions.MissingDependencyException,
        botocore.exceptions.BotoCoreError,
    ) as exc:
        fail(
            "AWS authentication failed: "
            f"{exc}\nRun `aws sso login` or refresh your AWS credentials, then retry."
        )
    except botocore.exceptions.ClientError as exc:
        fail(
            "AWS authentication failed: "
            f"{exc}\nRun `aws sso login` or refresh your AWS credentials, then retry."
        )


def get_rds_status(rds_client, db_identifier: str) -> str:
    try:
        response = rds_client.describe_db_instances(DBInstanceIdentifier=db_identifier)
    except botocore.exceptions.ClientError as exc:
        fail(f"RDS instance not found or unreadable in AWS: {db_identifier}\n{exc}")
    return response["DBInstances"][0]["DBInstanceStatus"]


def get_asg_status(autoscaling_client, asg_name: str) -> dict:
    try:
        response = autoscaling_client.describe_auto_scaling_groups(
            AutoScalingGroupNames=[asg_name]
        )
    except botocore.exceptions.ClientError as exc:
        fail(f"Auto Scaling Group not found or unreadable in AWS: {asg_name}\n{exc}")
    groups = response.get("AutoScalingGroups", [])
    if not groups:
        fail(f"Auto Scaling Group not found in AWS: {asg_name}")
    group = groups[0]
    instances = group.get("Instances", [])
    return {
        "name": group["AutoScalingGroupName"],
        "min": group["MinSize"],
        "desired": group["DesiredCapacity"],
        "max": group["MaxSize"],
        "instances": len(instances),
        "in_service": sum(1 for instance in instances if instance["LifecycleState"] == "InService"),
    }


def print_submitted_actions(lines: list[str]):
    print("Submitted AWS changes:")
    for line in lines:
        print(f"- {line}")


def print_observed_state(rds_status: str, asg_statuses: list[dict]):
    print("Observed AWS state:")
    print(f"- RDS status: {rds_status}")
    for item in asg_statuses:
        print(
            "- ASG {name}: desired={desired} min={min} max={max} instances={instances} in_service={in_service}".format(
                **item
            )
        )


def asgs_match_targets(asg_statuses: list[dict], resources: dict, targets: dict[str, int]) -> bool:
    for item in asg_statuses:
        target = targets[resources["asg_roles"][item["name"]]]
        if (
            item["desired"] != target
            or item["min"] != target
            or item["max"] != target * 2
        ):
            return False
    return True


def classify_park_state(rds_status: str, asg_statuses: list[dict]) -> str:
    asgs_parked = all(
        item["desired"] == 0 and item["min"] == 0 and item["max"] == 0
        for item in asg_statuses
    )
    if rds_status == "stopped" and asgs_parked:
        return "parked"
    if rds_status == "stopping" and asgs_parked:
        return "parking"
    return "not_parked"


def classify_unpark_state(
    rds_status: str, asg_statuses: list[dict], resources: dict, targets: dict[str, int]
) -> str:
    asgs_unparked = asgs_match_targets(asg_statuses, resources, targets)
    if rds_status == "available" and asgs_unparked:
        return "unparked"
    if rds_status == "starting" and asgs_unparked:
        return "unparking"
    return "not_unparked"


def asgs_reflect_park_request(asg_statuses: list[dict]) -> bool:
    return all(
        item["desired"] == 0 and item["min"] == 0 and item["max"] == 0 for item in asg_statuses
    )


def wait_for_state(
    rds_client,
    autoscaling_client,
    resources: dict,
    rds_target_check,
    asg_target_check,
):
    deadline = time.time() + POLL_TIMEOUT_SECONDS
    last_rds_status = None
    last_asg_statuses = []

    while True:
        last_rds_status = get_rds_status(rds_client, resources["rds_identifier"])
        last_asg_statuses = [
            get_asg_status(autoscaling_client, name) for name in resources["asg_names"]
        ]

        if rds_target_check(last_rds_status) and all(
            asg_target_check(item) for item in last_asg_statuses
        ):
            return True, last_rds_status, last_asg_statuses

        if time.time() >= deadline:
            return False, last_rds_status, last_asg_statuses

        time.sleep(POLL_INTERVAL_SECONDS)


def confirm_or_exit(summary_lines: list[str], assume_yes: bool):
    print("\n".join(summary_lines))
    if assume_yes:
        return
    answer = input("Proceed? Type 'yes' to continue: ").strip().lower()
    if answer != "yes":
        raise SystemExit(1)


def update_asg_capacity(
    autoscaling_client,
    asg_name: str,
    min_size: int,
    desired_capacity: int,
    max_size: int,
    dry_run: bool,
):
    if dry_run:
        return
    autoscaling_client.update_auto_scaling_group(
        AutoScalingGroupName=asg_name,
        MinSize=min_size,
        DesiredCapacity=desired_capacity,
        MaxSize=max_size,
    )


def park(session, resources, dry_run: bool, assume_yes: bool):
    rds = session.client("rds")
    autoscaling = session.client("autoscaling")

    rds_status = get_rds_status(rds, resources["rds_identifier"])
    asg_statuses = [get_asg_status(autoscaling, name) for name in resources["asg_names"]]
    park_state = classify_park_state(rds_status, asg_statuses)

    if park_state == "parked":
        print(f"Dataplane is already parked in {resources['region']}.")
        print_observed_state(rds_status, asg_statuses)
        return
    if park_state == "parking":
        print(f"Dataplane is already transitioning to parked in {resources['region']}.")
        print_observed_state(rds_status, asg_statuses)
        return

    summary = [
        f"Directory: {resources['directory']}",
        f"AWS account: {resources['account_id']}",
        f"AWS region: {resources['region']}",
        f"Action: park",
        f"RDS: {resources['rds_identifier']} ({rds_status} -> stop if available)",
    ]
    summary.extend(
        f"ASG: {item['name']} (desired={item['desired']} min={item['min']} max={item['max']} -> desired=0 min=0 max=0)"
        for item in asg_statuses
    )
    confirm_or_exit(summary, assume_yes)

    submitted_actions = []
    if rds_status == "available" and not dry_run:
        rds.stop_db_instance(DBInstanceIdentifier=resources["rds_identifier"])
        submitted_actions.append(f"requested stop for RDS {resources['rds_identifier']}")
    elif rds_status in {"stopping", "stopped"}:
        submitted_actions.append(
            f"left RDS {resources['rds_identifier']} unchanged because it is already {rds_status}"
        )
    else:
        submitted_actions.append(
            f"did not request RDS stop because current status is {rds_status}"
        )

    for item in asg_statuses:
        update_asg_capacity(autoscaling, item["name"], 0, 0, 0, dry_run)
        if dry_run:
            submitted_actions.append(
                f"would set ASG {item['name']} to desired=0 min=0 max=0"
            )
        else:
            submitted_actions.append(f"set ASG {item['name']} to desired=0 min=0 max=0")

    print_submitted_actions(submitted_actions)
    if dry_run:
        print("Dry run complete. No AWS changes were made.")
        return

    print(
        f"Waiting up to {POLL_TIMEOUT_SECONDS}s for AWS to reflect the park transition..."
    )
    reached_target, final_rds_status, final_asg_statuses = wait_for_state(
        rds,
        autoscaling,
        resources,
        lambda status: status == "stopped",
        lambda item: item["desired"] == 0
        and item["min"] == 0
        and item["max"] == 0
        and item["instances"] == 0,
    )
    print_observed_state(final_rds_status, final_asg_statuses)

    if reached_target:
        print("Park complete.")
        return

    if final_rds_status in {"stopping", "stopped"} and asgs_reflect_park_request(final_asg_statuses):
        print("Park transition started successfully. Some resources are still draining.")
        return

    print(
        f"Park requests were submitted, but AWS did not reflect the target state within {POLL_TIMEOUT_SECONDS}s."
    )


def unpark(session, resources, counts: dict[str, int], dry_run: bool, assume_yes: bool):
    rds = session.client("rds")
    autoscaling = session.client("autoscaling")

    rds_status = get_rds_status(rds, resources["rds_identifier"])
    asg_statuses = [get_asg_status(autoscaling, name) for name in resources["asg_names"]]

    targets = {
        "brainstore": counts["brainstore_instance_count"],
        "brainstore_writer": counts["brainstore_writer_instance_count"],
        "brainstore_fast_reader": counts["brainstore_fast_reader_instance_count"],
    }
    unpark_state = classify_unpark_state(rds_status, asg_statuses, resources, targets)

    if unpark_state == "unparked":
        print(f"Dataplane is already unparked in {resources['region']}.")
        print_observed_state(rds_status, asg_statuses)
        return
    if unpark_state == "unparking":
        print(f"Dataplane is already transitioning to unparked in {resources['region']}.")
        print_observed_state(rds_status, asg_statuses)
        return

    summary = [
        f"Directory: {resources['directory']}",
        f"AWS account: {resources['account_id']}",
        f"AWS region: {resources['region']}",
        f"Action: unpark",
        f"RDS: {resources['rds_identifier']} ({rds_status} -> start if stopped)",
    ]
    for item in asg_statuses:
        role = resources["asg_roles"][item["name"]]
        target_count = targets[role]
        summary.append(
            f"ASG: {item['name']} (desired={item['desired']} min={item['min']} max={item['max']} -> desired={target_count} min={target_count} max={target_count * 2})"
        )
    confirm_or_exit(summary, assume_yes)

    submitted_actions = []
    if rds_status == "stopped" and not dry_run:
        rds.start_db_instance(DBInstanceIdentifier=resources["rds_identifier"])
        submitted_actions.append(f"requested start for RDS {resources['rds_identifier']}")
    elif rds_status in {"starting", "available"}:
        submitted_actions.append(
            f"left RDS {resources['rds_identifier']} unchanged because it is already {rds_status}"
        )
    else:
        submitted_actions.append(
            f"did not request RDS start because current status is {rds_status}"
        )

    for item in asg_statuses:
        role = resources["asg_roles"][item["name"]]
        target_count = targets[role]
        update_asg_capacity(
            autoscaling,
            item["name"],
            target_count,
            target_count,
            target_count * 2,
            dry_run,
        )
        if dry_run:
            submitted_actions.append(
                f"would set ASG {item['name']} to desired={target_count} min={target_count} max={target_count * 2}"
            )
        else:
            submitted_actions.append(
                f"set ASG {item['name']} to desired={target_count} min={target_count} max={target_count * 2}"
            )

    print_submitted_actions(submitted_actions)
    if dry_run:
        print("Dry run complete. No AWS changes were made.")
        return

    print(
        f"Waiting up to {POLL_TIMEOUT_SECONDS}s for AWS to reflect the unpark transition..."
    )
    reached_target, final_rds_status, final_asg_statuses = wait_for_state(
        rds,
        autoscaling,
        resources,
        lambda status: status == "available",
        lambda item: (
            item["desired"] == targets[resources["asg_roles"][item["name"]]]
            and item["min"] == targets[resources["asg_roles"][item["name"]]]
            and item["max"] == targets[resources["asg_roles"][item["name"]]] * 2
            and item["in_service"] >= targets[resources["asg_roles"][item["name"]]]
        ),
    )
    print_observed_state(final_rds_status, final_asg_statuses)

    if reached_target:
        print("Unpark complete.")
        return

    if final_rds_status in {"starting", "available"} and asgs_match_targets(
        final_asg_statuses, resources, targets
    ):
        print("Unpark transition started successfully. Some resources are still warming up.")
        return

    print(
        f"Unpark requests were submitted, but AWS did not reflect the target state within {POLL_TIMEOUT_SECONDS}s."
    )


def main():
    args = parse_args()
    target_dir = Path(args.dir).resolve()
    if not target_dir.exists() or not target_dir.is_dir():
        fail(f"Target directory does not exist: {target_dir}")

    state = load_state(target_dir)
    region, region_source = infer_target_region(target_dir, state)
    session = build_session(region, region_source)
    identity = validate_aws_auth(session)
    resources = discover_resources(target_dir, state, identity["Account"], region)

    if args.action == "park":
        park(session, resources, args.dry_run, args.yes)
    else:
        counts = load_brainstore_counts(target_dir)
        unpark(session, resources, counts, args.dry_run, args.yes)


if __name__ == "__main__":
    main()
