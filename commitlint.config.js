module.exports = {
  extends: ['@commitlint/config-conventional'],
  ignores: [
    // Pre-existing commit in PR #567 that predates this config
    (commit) => commit.startsWith('upgrade gitea actions chart to v0.0.4'),
    // Temporary ignore for PR #764 commit; remove once this commit is out of active history
    (commit) => /^feat: adding in new user\n\nAdded configurations for authelia services including murtz and murtz-browse with OIDC provider settings\.$/.test(commit.replace(/\r\n/g, '\n').trim()),
  ],
};
