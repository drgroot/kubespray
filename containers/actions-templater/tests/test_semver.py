import tempfile
import unittest
from pathlib import Path

import yaml

from src.com.repo import RepoContext
from src.get_workflows import get_workflows
from src.lib.actions.common.semver import changelog
from src.writeyaml import write_workflow_file


class ChangelogWorkflowTests(unittest.TestCase):
    def test_changelog_auto_controls_schedule(self):
        for artifact in (None, "tenant"):
            for config in ({}, {"changelog_auto": True}, {"changelog_auto": False}):
                with (
                    self.subTest(artifact=artifact, config=config),
                    tempfile.TemporaryDirectory() as folder,
                ):
                    repo = RepoContext(
                        source="github",
                        repo_full_name="example/service",
                        repo_name="service",
                        repo_owner="example",
                        clone_url="https://example.com/service.git",
                        local_folder=folder,
                        **({"artifact": artifact} if artifact else {}),
                        **config,
                    )
                    workflows, _ = get_workflows(repo)
                    selected = next(
                        item
                        for item in workflows
                        if item["filename"] == ".github/workflows/changelog.yml"
                    )
                    write_workflow_file(repo, selected, folder)
                    workflow = yaml.safe_load(
                        (Path(folder) / selected["filename"]).read_text()
                    )

                    self.assertIn("workflow_dispatch", workflow["on"])
                    self.assertIn("changelog", workflow["jobs"])
                    if config.get("changelog_auto") is False:
                        self.assertNotIn("schedule", workflow["on"])
                    else:
                        self.assertEqual(
                            [{"cron": "0 0 * * *"}], workflow["on"]["schedule"]
                        )

    def test_servc_changelog_uses_vault_gitea_token(self):
        repo = RepoContext(
            source="github",
            repo_full_name="serv-c/service",
            repo_name="service",
            repo_owner="serv-c",
            clone_url="https://example.com/service.git",
        )

        workflow = changelog["function"](repo, {})
        steps = workflow["jobs"]["changelog"]["steps"]

        self.assertEqual("gitea_secrets", steps[0]["id"])
        self.assertEqual("hashicorp/vault-action@v2", steps[0]["uses"])
        self.assertEqual(
            "servc/data/iac/gitea token | PAT_TOKEN ;",
            steps[0]["with"]["secrets"],
        )
        self.assertEqual(
            "${{ steps.gitea_secrets.outputs.PAT_TOKEN }}",
            steps[1]["with"]["token"],
        )

        changelog_step = next(step for step in steps if step.get("id") == "changelog")
        self.assertEqual(
            "${{ steps.gitea_secrets.outputs.PAT_TOKEN }}",
            changelog_step["with"]["github-token"],
        )

    def test_non_servc_changelog_uses_github_token(self):
        repo = RepoContext(
            source="github",
            repo_full_name="example/service",
            repo_name="service",
            repo_owner="example",
            clone_url="https://example.com/service.git",
        )

        workflow = changelog["function"](repo, {})
        steps = workflow["jobs"]["changelog"]["steps"]

        self.assertNotEqual("gitea_secrets", steps[0].get("id"))
        self.assertNotIn("token", steps[0]["with"])

        changelog_step = next(step for step in steps if step.get("id") == "changelog")
        self.assertEqual("${{ github.token }}", changelog_step["with"]["github-token"])
