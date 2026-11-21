import os
import tempfile
import unittest

from src.com.repo import RepoContext
from src.get_workflows import get_workflows
from src.writeyaml import remove_obsolete_workflows
from src.lib.actions.common.agent import embed_issues, embed_markdown, issue_agent_workflow


class AgentWorkflowSelectionTests(unittest.TestCase):
    def test_agent_workflows_are_never_shipped(self):
        for owner in ("serv-c", "Serv-C", "example-org"):
            for agent in (True, False):
                with self.subTest(owner=owner, agent=agent):
                    repo = RepoContext(
                        source="github", repo_full_name=f"{owner}/example",
                        repo_name="example", repo_owner=owner,
                        clone_url="https://example.com/example.git", agent=agent,
                    )
                    workflows, _ = get_workflows(repo)
                    filenames = {workflow["filename"] for workflow in workflows}
                    for name in ("issue-agent.yml", "agent-issue.yml", "agent-markdown.yml"):
                        self.assertNotIn(f".github/workflows/{name}", filenames)

    def test_existing_agent_workflows_are_removed_once(self):
        repo = RepoContext(
            source="github", repo_full_name="example/repo", repo_name="repo",
            clone_url="https://example.com/repo.git",
        )
        with tempfile.TemporaryDirectory() as directory:
            folder = os.path.join(directory, ".github", "workflows")
            os.makedirs(folder)
            retired = ("issue-agent.yml", "agent-issue.yml", "agent-markdown.yml")
            for name in (*retired, "unit.yml", "deploy.yml"):
                with open(os.path.join(folder, name), "w") as file:
                    file.write("jobs: {}\n")
            self.assertEqual(3, remove_obsolete_workflows(repo, directory))
            self.assertEqual({"unit.yml", "deploy.yml"}, set(os.listdir(folder)))
            self.assertEqual(0, remove_obsolete_workflows(repo, directory))


class AgentTokenWorkflowTests(unittest.TestCase):
    def test_servc_issue_agent_uses_vault_agent_and_github_tokens(self):
        repo = RepoContext(
            source="github",
            repo_full_name="serv-c/example",
            repo_name="example",
            repo_owner="serv-c",
            clone_url="https://example.com/example.git",
        )

        workflow = issue_agent_workflow(repo, {})
        steps = workflow["jobs"]["dispatch"]["steps"]

        self.assertEqual("agent_secrets", steps[0]["id"])
        self.assertEqual("hashicorp/vault-action@v2", steps[0]["uses"])
        self.assertEqual(
            "servc/data/iac/servc agent-auth-token | AGENT_TOKEN ;",
            steps[0]["with"]["secrets"],
        )
        self.assertEqual("gitea_secrets", steps[1]["id"])
        self.assertEqual("hashicorp/vault-action@v2", steps[1]["uses"])
        self.assertEqual(
            "servc/data/iac/gitea token | PAT_TOKEN ;",
            steps[1]["with"]["secrets"],
        )
        self.assertEqual(
            "${{ steps.agent_secrets.outputs.AGENT_TOKEN }}",
            steps[2]["with"]["api_token"],
        )
        self.assertEqual(
            "${{ steps.gitea_secrets.outputs.PAT_TOKEN }}",
            steps[2]["env"]["GITHUB_TOKEN"],
        )

    def test_servc_embed_issue_uses_vault_agent_token(self):
        repo = RepoContext(
            source="github",
            repo_full_name="serv-c/example",
            repo_name="example",
            repo_owner="serv-c",
            clone_url="https://example.com/example.git",
        )

        workflow = embed_issues(repo, {})
        steps = workflow["jobs"]["agent-embed-issue"]["steps"]

        self.assertEqual("agent_secrets", steps[0]["id"])
        self.assertEqual(
            "servc/data/iac/servc agent-auth-token | AGENT_TOKEN ;",
            steps[0]["with"]["secrets"],
        )
        self.assertEqual(
            "${{ steps.agent_secrets.outputs.AGENT_TOKEN }}",
            steps[1]["with"]["api_token"],
        )

    def test_servc_embed_markdown_uses_vault_agent_token(self):
        repo = RepoContext(
            source="github",
            repo_full_name="serv-c/example",
            repo_name="example",
            repo_owner="serv-c",
            clone_url="https://example.com/example.git",
        )

        workflow = embed_markdown(repo, {})
        steps = workflow["jobs"]["agent-embed-markdown"]["steps"]

        self.assertEqual("agent_secrets", steps[0]["id"])
        self.assertEqual(
            "servc/data/iac/servc agent-auth-token | AGENT_TOKEN ;",
            steps[0]["with"]["secrets"],
        )
        self.assertEqual(
            "${{ steps.agent_secrets.outputs.AGENT_TOKEN }}",
            steps[2]["with"]["api_token"],
        )

    def test_non_servc_agent_workflows_use_secret_agent_token(self):
        repo = RepoContext(
            source="github",
            repo_full_name="example-org/example",
            repo_name="example",
            repo_owner="example-org",
            clone_url="https://example.com/example.git",
        )

        issue_workflow = issue_agent_workflow(repo, {})
        issue_steps = issue_workflow["jobs"]["dispatch"]["steps"]
        self.assertNotEqual("agent_secrets", issue_steps[0].get("id"))
        self.assertNotEqual("gitea_secrets", issue_steps[0].get("id"))
        self.assertEqual("${{ secrets.AGENT_TOKEN }}", issue_steps[0]["with"]["api_token"])
        self.assertEqual("${{ secrets.GITHUB_TOKEN }}", issue_steps[0]["env"]["GITHUB_TOKEN"])

        embed_workflow = embed_issues(repo, {})
        embed_steps = embed_workflow["jobs"]["agent-embed-issue"]["steps"]
        self.assertNotEqual("agent_secrets", embed_steps[0].get("id"))
        self.assertEqual("${{ secrets.AGENT_TOKEN }}", embed_steps[0]["with"]["api_token"])
