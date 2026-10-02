# Security

- The plugin is read-only: it calls `get_workspace_overview`, `get_analytics_overview`,
  `get_deliverability_status` and `get_web_analytics` on the InstantCampaign MCP
  endpoint. None of these can send email or change workspace data.
- The API key lives in `~/.config/instantcampaign/api-key` (mode 600, directory 700)
  or the `INSTANTCAMPAIGN_API_KEY` environment variable. It reaches `curl` through a
  config file read from stdin, never as an argument.
- Network access goes only to the configured InstantCampaign URL (default
  `https://instantcampaign.ai`).
- Nothing is written outside `~/.config/instantcampaign/` and
  `~/.local/state/omarchy/instantcampaign/`.
- The QML runs no shell commands with user-controlled text other than the collector
  itself and `omarchy-launch-terminal` for setup.

Report a problem privately to the maintainers through GitHub's security advisory
form on this repository.
