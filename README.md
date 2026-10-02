# InstantCampaign Spark for Omarchy

Your [InstantCampaign](https://instantcampaign.ai) workspace in the Omarchy bar:
one envelope that lights up when a sending domain needs attention, and a panel
with the last week's email and website numbers.

![preview](preview.png)

## What it shows

- **Email** — sent, delivered, open and click rates for the period, each with
  its change against the period before, plus meters for opened, clicked and
  bounced.
- **Recent campaigns** — the five newest, with their status.
- **Sending domains** — verification, DNS drift, warm-up progress against
  today's cap, blocklist listings and the reputation verdict. A domain that
  needs a hand turns the bar icon to the alert colour and says why.
- **Website** — visitors, sessions, pageviews and bounce rate from the
  cookieless tracking snippet, the live visitor count, and the top pages.

Keys while the panel is open: `r` refresh, `o` open analytics, `c` campaigns,
`d` deliverability, `Esc` close. Right-click the bar icon to open the app,
middle-click to refresh.

## Install

```sh
omarchy plugin add https://github.com/Cloud-First-Consulting/omarchy-instantcampaign-spark --enable
```

Then connect it to your workspace. Open the panel and click **Sign in with
InstantCampaign** (or press `s`). A browser tab opens on instantcampaign.ai;
log in, pick the workspace, approve, and the bar fills in by itself. Nothing to
copy. Press `x` in the panel to sign out again, which also revokes the
authorisation in the workspace's *Connected apps*.

Prefer an API key? In InstantCampaign go to **Settings → API keys**, create a
key with the **mcp** scope, and run:

```sh
~/.config/omarchy/plugins/instantcampaign.spark/bin/omarchy-instantcampaign-spark setup
```

The panel's "Set up with an API key" button does the same. Setup asks for the
key once, stores it in `~/.config/instantcampaign/api-key` with mode 600, and
tests it. An API key, when present, takes precedence over a sign-in.

The widget refreshes every five minutes; change the interval, the period (7,
30 or 90 days) or the URL of a self-hosted InstantCampaign in the widget's
settings in the Omarchy shell.

## Links

- Website and sign-in: https://instantcampaign.ai
- Create an API key: https://instantcampaign.ai/settings/api-keys (scope: **mcp**)
- Analytics the widget reads: https://instantcampaign.ai/analytics and https://instantcampaign.ai/deliverability
- Help centre: https://docs.instantcampaign.ai

## Remove

```sh
~/.config/omarchy/plugins/instantcampaign.spark/bin/omarchy-instantcampaign-spark logout
omarchy plugin remove instantcampaign.spark
rm -rf ~/.config/instantcampaign ~/.local/state/omarchy/instantcampaign
```

The first line revokes a sign-in server-side; the last deletes any stored API
key or tokens and the cached numbers. Revoke an API key in InstantCampaign as
well if you no longer need it.

## How it works, and what it can see

A small bash collector (`bin/omarchy-instantcampaign-spark`) calls four tools
on the InstantCampaign MCP endpoint — workspace overview, email analytics,
deliverability status and web analytics — and writes one JSON file under
`~/.local/state/omarchy/instantcampaign/`. The QML panel only reads that
file. Credentials are passed to `curl` through its config on stdin, so they
never appear on a command line.

Sign-in is standard OAuth 2.1 for a native app: the plugin registers itself
once as a public client (RFC 7591), uses PKCE S256, and receives the redirect
on a loopback port (`127.0.0.1:48217`, or the next free of four). The access
token lasts an hour and is refreshed silently; the refresh token rotates on
every use and lasts 90 days from the last one. Tokens live in
`~/.config/instantcampaign/oauth.json` with mode 600. Because the client is
self-registered, the consent page shows an "Unverified app" notice; that is
the server being honest about a client it did not pre-approve, not a warning
about this plugin.

Everything the widget receives is aggregate: counts, rates, campaign names and
domain names. The InstantCampaign API never returns contact data to an API
client, and the tools used here are read-only; nothing in this plugin can send
mail or change your workspace.

Dependencies: `curl`, `jq` and `python3` (all ship with Omarchy; Python only
runs the sign-in) and `gum` for the API-key prompt (optional; a plain prompt
is used without it).

## License

MIT — see [LICENSE](LICENSE). By [Cloud First Consulting](https://github.com/Cloud-First-Consulting),
the company behind InstantCampaign.
