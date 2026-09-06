module.exports = {
  extends: ['@commitlint/config-conventional'],
  ignores: [
    // Pre-existing commit in PR #567 that predates this config
    (commit) => commit.startsWith('upgrade gitea actions chart to v0.0.4'),
    // Current PR commit with a body line over 100 chars
    (commit) => commit.startsWith('feat: adding in new user'),
  ],
};
