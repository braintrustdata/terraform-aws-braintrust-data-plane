#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Assert fixed-name ECS replacements destroy before creating."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
EXPECTED_ORDER = ["delete", "create"]

TEST_CASES = {
    "tests/api_ecs_root_replacement_order.tftest.hcl": {
        "run": "force_root_api_ecs_replacements",
        "resources": {
            "module.api_ecs[0].aws_ecs_service.braintrust_api",
            "module.api_ecs[0].aws_ecs_service.braintrust_api_ingest",
            "module.api_ecs[0].aws_ecs_service.braintrust_api_background",
        },
    },
    "tests/api_ecs_warm_root_replacement_order.tftest.hcl": {
        "run": "force_warm_root_api_ecs_replacements",
        "resources": {
            "module.api_ecs[0].aws_ecs_service.braintrust_api",
            "module.api_ecs[0].aws_ecs_service.braintrust_api_ingest",
            "module.api_ecs[0].aws_ecs_service.braintrust_api_background",
        },
    },
    "tests/api_ecs_replacement_order.tftest.hcl": {
        "run": "force_fixed_name_api_ecs_replacements",
        "resources": {
            "aws_ecs_service.braintrust_api",
            "aws_ecs_service.braintrust_api_ingest",
            "aws_ecs_service.braintrust_api_background",
        },
    },
    "tests/gateway_ecs_replacement_order.tftest.hcl": {
        "run": "force_fixed_name_gateway_replacement",
        "resources": {"aws_ecs_service.gateway"},
    },
    "tests/loop_runtime_ecs_replacement_order.tftest.hcl": {
        "run": "force_fixed_name_loop_runtime_replacement",
        "resources": {"aws_ecs_service.loop_runtime"},
    },
}

LIFECYCLE_INVARIANTS = {
    ("modules/api-ecs/braintrust-api.tf", "aws_ecs_service", "braintrust_api"): False,
    (
        "modules/api-ecs/braintrust-api-ingest.tf",
        "aws_ecs_service",
        "braintrust_api_ingest",
    ): False,
    (
        "modules/api-ecs/braintrust-api-background.tf",
        "aws_ecs_service",
        "braintrust_api_background",
    ): False,
    ("modules/gateway-ecs/main.tf", "aws_ecs_service", "gateway"): False,
    ("modules/loop-runtime-ecs/main.tf", "aws_ecs_service", "loop_runtime"): False,
    (
        "modules/api-gateway/main.tf",
        "aws_api_gateway_deployment",
        "api",
    ): True,
}


def extract_block(source: str, block_type: str, name: str) -> str:
    marker = re.compile(
        rf'\bresource\s+"{re.escape(block_type)}"\s+"{re.escape(name)}"\s*\{{'
    )
    match = marker.search(source)
    if match is None:
        raise ValueError(f'resource "{block_type}" "{name}" not found')

    start = source.find("{", match.start())
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(source)):
        char = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : index]
    raise ValueError(f'resource "{block_type}" "{name}" has no closing brace')


def check_lifecycle_invariants() -> list[str]:
    failures: list[str] = []
    for (relative_path, block_type, name), expected in LIFECYCLE_INVARIANTS.items():
        source = (REPO_ROOT / relative_path).read_text()
        try:
            block = extract_block(source, block_type, name)
        except ValueError as error:
            failures.append(f"{relative_path}: {error}")
            continue
        lifecycle = re.search(r"\blifecycle\s*\{(?P<body>.*?)\}", block, re.DOTALL)
        if lifecycle is None:
            failures.append(f"{relative_path}: {block_type}.{name} has no lifecycle block")
            continue
        configured = re.search(
            r"\bcreate_before_destroy\s*=\s*(true|false)\b",
            lifecycle.group("body"),
        )
        if configured is None:
            failures.append(
                f"{relative_path}: {block_type}.{name} must explicitly set "
                f"create_before_destroy = {str(expected).lower()}"
            )
        elif (configured.group(1) == "true") != expected:
            failures.append(
                f"{relative_path}: {block_type}.{name} has "
                f"create_before_destroy = {configured.group(1)}, expected "
                f"{str(expected).lower()}"
            )
    return failures


def read_replacement_plan(test_file: str, run_name: str) -> tuple[dict[str, list[str]], list[str]]:
    command = [
        "terraform",
        "test",
        f"-filter={test_file}",
        "-json",
        "-verbose",
        "-no-color",
    ]
    process = subprocess.Popen(
        command,
        cwd=REPO_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    assert process.stdout is not None

    actions: dict[str, list[str]] = {}
    errors: list[str] = []
    for line in process.stdout:
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            if line.strip():
                errors.append(line.strip())
            continue

        if event.get("@level") == "error":
            diagnostic = event.get("diagnostic", {})
            errors.append(
                f"{diagnostic.get('summary', event.get('@message', 'Terraform error'))}: "
                f"{diagnostic.get('detail', '')}".rstrip()
            )

        if event.get("type") != "test_plan" or event.get("@testrun") != run_name:
            continue
        for resource_change in event["test_plan"].get("resource_changes", []):
            address = resource_change.get("address")
            if address:
                actions[address] = resource_change.get("change", {}).get("actions", [])

    return_code = process.wait()
    if return_code != 0 and not errors:
        errors.append(f"terraform test exited with status {return_code}")
    return actions, errors


def main() -> int:
    failures = check_lifecycle_invariants()

    for test_file, test_case in TEST_CASES.items():
        actions, errors = read_replacement_plan(test_file, test_case["run"])
        failures.extend(f"{test_file}: {error}" for error in errors)

        for address in sorted(test_case["resources"]):
            actual = actions.get(address)
            if actual != EXPECTED_ORDER:
                failures.append(
                    f"{test_file}: {address} replacement actions were {actual!r}; "
                    f"expected {EXPECTED_ORDER!r}"
                )
            else:
                print(f"PASS {address}: {actual}")

    if failures:
        print("\nECS replacement-order regression failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("All fixed-name ECS services destroy before replacement creation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
