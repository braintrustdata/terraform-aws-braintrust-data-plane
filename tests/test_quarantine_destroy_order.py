"""Verify the real Terraform dependency graph, without cloud access."""
import collections
import re
import runpy
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class QuarantineDestroyOrderTest(unittest.TestCase):
    def test_network_outlives_execution_role_permissions(self):
        graph = subprocess.check_output(["terraform", "graph", "-type=plan"], cwd=ROOT, text=True)
        edges = collections.defaultdict(set)
        for source, target in re.findall(r'"([^"\n]+)" -> "([^"\n]+)"', graph):
            edges[source].add(target)
        dependency_path = runpy.run_path(str(ROOT / "scripts/check-loop-network-dependencies"))["dependency_path"]
        group = "[root] module.services_common.aws_security_group.quarantine_lambda (expand)"
        attachment = "[root] module.services_common.aws_iam_role_policy_attachment.quarantine_function_role (expand)"
        role = "[root] module.services_common.aws_iam_role.quarantine_function_role (expand)"
        self.assertTrue(dependency_path(edges, group, attachment))
        self.assertTrue(dependency_path(edges, attachment, role))
        hook = "[root] module.services.aws_lambda_invocation.quarantine_cleanup (expand)"
        warmup = "[root] module.services.aws_lambda_function.quarantine_warmup (expand)"
        api = "[root] module.services.aws_lambda_function.api_handler (expand)"
        ecs = "[root] module.api_ecs.aws_ecs_service.braintrust_api (expand)"
        self.assertTrue(dependency_path(edges, api, hook))
        self.assertTrue(dependency_path(edges, ecs, hook))
        for name in ("braintrust_api_ingest", "braintrust_api_background"):
            self.assertTrue(dependency_path(edges, "[root] module.api_ecs.aws_ecs_service." + name + " (expand)", hook))
        pruner = "[root] module.services.aws_lambda_function.quarantine_pruner (expand)"
        self.assertTrue(dependency_path(edges, pruner, hook))
        self.assertTrue(dependency_path(edges, hook, warmup))
        self.assertTrue(dependency_path(edges, hook, group))
        self.assertNotIn("local-exec", (ROOT / "modules/services/lambda-quarantine-warmup.tf").read_text())

if __name__ == "__main__":
    unittest.main()
