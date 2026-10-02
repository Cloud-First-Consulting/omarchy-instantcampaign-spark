# Security

- The plugin is read-only: it calls `get_workspace_overview`, `get_analytics_overview`,
  `get_deliverability_status` and `get_web_analytics` on the InstantCampaign MCP
  endpoint. None of these can send email or change workspace data.
- Credentials are an API key in `~/.config/instantcampaign/api-key` or the
  `INSTANTCAMPAIGN_API_KEY` variable, or OAuth tokens in
  `~/.config/instantcampaign/oauth.json` (both mode 600, directory 700). Each
  reaches `curl` through a config file read from stdin, never as an argument.
- Sign-in (`bin/omarchy-instantcampaign-spark-login`, Python standard library only)
  is OAuth 2.1 with a public client (the one InstantCampaign registered for this
  plugin, or a dynamically registered one on a self-hosted server), PKCE S256, a `state`
  check, and a loopback redirect bound to 127.0.0.1 that serves one static page
  and accepts a single callback. The refresh token rotates on every use; a reused
  or revoked one ends the session and deletes the token file. Logout revokes the
  grant server-side (RFC 7009).
- Network access goes only to the configured InstantCampaign URL (default
  `https://instantcampaign.ai`).
- Nothing is written outside `~/.config/instantcampaign/` and
  `~/.local/state/omarchy/instantcampaign/`.
- The QML runs no shell commands with user-controlled text other than the collector
  itself, `omarchy-launch-terminal` for the API-key setup, and the browser launcher
  for sign-in and links.

Report a problem privately to the maintainers through GitHub's security advisory
form on this repository.
