# botesito

REST front-end for a Telegram bot. You POST a message, it lands in your
Telegram chat. Turn on chatops and it reads the chat too, answering
questions about the cluster.

Same stack as `hobbytracker_bff`: design-first `erf` server over
`nhttp_erf`, `nhttpc` connection pools for outbound calls, `conf` for
optional YAML configuration, `relx` release packaged into a container.

## API

Three routes, described in `docs/openapi.yaml`.

    GET  /healthz    -> {"status": "ok", "telegram": "ok"}
    POST /messages   -> 201 {"message_id": .., "chat_id": .., "sent_at": .., "text": ..}
    POST /alerts     -> 201 same body, rendered from an Alertmanager webhook

`/messages` and `/alerts` need a bearer token; `/healthz` does not.

```bash
curl -X POST http://localhost:8080/messages \
  -H 'authorization: Bearer <api_token>' \
  -H 'content-type: application/json' \
  -d '{"text": "deploy terminado"}'
```

Body fields:

| field | type | notes |
|---|---|---|
| `text` | string, 1..4096 | required |
| `parse_mode` | `plain` \| `markdown` \| `html` | defaults to `plain`; `markdown` is Telegram's MarkdownV2 |
| `silent` | boolean | delivers without a notification sound |
| `preview_links` | boolean | link previews are disabled unless this is true |

Anything the schema rejects comes back as a 400 with a pointer to the
offending field. A bad or missing token is a 401. Telegram failures are a
502; a bot with no token or chat configured is a 503.

### Alerts

`/alerts` takes the payload Alertmanager posts to a webhook receiver and turns
it into one plain-text message, so Alertmanager never needs a bot token or a
chat id of its own:

```yaml
receivers:
  - name: botesito
    webhook_configs:
      - url: http://botesito.extra.svc.cluster.local:8080/alerts
        http_config:
          authorization:
            credentials_file: /etc/alertmanager/secrets/botesito/api_token
```

What arrives in the chat:

    FIRING 2 alerts

    [critical] KubePodCrashLooping
    Pod extra/stirling-pdf is restarting
    namespace=extra pod=stirling-pdf-0

    [warning] BlackboxProbeFailed
    Probe https://pdf.in.example.com/ failing
    instance=https://pdf.in.example.com/

The title is `[severity] alertname`, the second line is the `summary`
annotation (falling back to `description`), and the third lists whichever of
`namespace`, `pod`, `instance`, `node`, `service` and `job` the alert carries.
Messages are sent without a parse mode: alert text is full of characters that
Telegram's Markdown and HTML parsers reject, and a rejected message is a lost
alert.

Groups that would exceed Telegram's 4096 character limit are cut at whole
alerts and the rest is reported as `+N more`, together with anything
Alertmanager itself dropped in `truncatedAlerts`.

## Chatops

With `BOTESITO_CHATOPS=true` the bot also reads. It long-polls Telegram's
`getUpdates`, so nothing has to be exposed to the internet, and it answers
these commands in the configured chat:

| command | what it does |
|---|---|
| `/status` | node readiness, how many pods are not Running (with names), firing alerts |
| `/alerts` | firing alerts, `Watchdog` excluded |
| `/logs <app>` | last 15 log lines of the first pod whose name starts with `<app>` |
| `/restart <app>` | annotates the deployment's pod template, which rolls it, then reports how it went |
| `/silence <alert> <30m\|2h\|1d>` | Alertmanager silence for that alertname, with a notice when it expires |
| `/help` | the same list |

Messages from any other chat are ignored and logged, and updates that arrived
while the bot was down are discarded on startup: Telegram keeps them for 24
hours and replaying yesterday's `/restart` is nobody's intent.

### Follow-ups

Two commands answer twice. `/restart` says it rolled the deployment and then,
thirty seconds later, whether it actually came up; if it has not settled yet it
waits another thirty, up to six times, so a slow image pull is reported when it
lands instead of as a failure. `/silence` says it silenced the alert and speaks
again when the silence expires.

Those deferred messages are [`ntask`](https://github.com/nomasystems/ntask)
tasks, running with its ETS store:

```erlang
{ntask, [
    {store, ntask_store_ets},
    {poll_interval_ms, 1000},
    {bucket_granularity_ms, 1000},
    {backlog_threshold_ms, 2000},
    {retention_seconds, 120}
]}
```

One-shot due times round up to `bucket_granularity_ms`, which is why it is 1000
rather than the default 60000: a `/silence 30s` should not be reported a minute
late. `backlog_threshold_ms` has to stay at or above twice the poll interval or
every healthy claim looks like a backlog. The settings live in `sys.config`
because `ntask` validates them as it starts, which happens before `botesito`
does, so setting them from code would be too late.

The ETS store keeps nothing across a restart, so a pod that dies with a
follow-up pending never sends it. That is the trade for not running a database
next to the bot, and it only ever costs a message, never an action: the command
itself already happened.

The poll loop deliberately does not go through `ntask`. Telegram holds
`getUpdates` open until something arrives, so the loop reopens the connection
immediately and there is nothing to schedule; a supervisor restart is what
resumes it. Scheduling that through a library whose non-goals include
sub-second precision would add latency to every command and buy nothing, since
a poll offset is worthless after a restart.

### Cluster access

Reading the cluster needs a service account. `/status`, `/logs` and `/restart`
talk to the Kubernetes API with the token and CA mounted at
`/var/run/secrets/kubernetes.io/serviceaccount`, so the bot needs `get`/`list`
on nodes, pods and pod logs, plus `patch` on deployments for `/restart`.
Alerts come from Prometheus and silences go to Alertmanager over plain HTTP
inside the cluster.

| variable | notes |
|---|---|
| `BOTESITO_CHATOPS` | `true` enables the poller; off by default |
| `BOTESITO_K8S_HOST` | defaults to `kubernetes.default.svc` |
| `BOTESITO_PROMETHEUS_HOST` | `host:port`, defaults to the kube-prometheus-stack service |
| `BOTESITO_ALERTMANAGER_HOST` | `host:port`, defaults to the kube-prometheus-stack service |

Without a service account the read commands answer with the error instead of
crashing, so enabling chatops outside a cluster degrades to `/help` and
`/silence` working and the rest reporting why they cannot.

## Docker

The image is configured entirely through environment variables.

```bash
cp .env.example .env      # fill in the three values
docker compose up --build
curl http://localhost:8080/healthz
```

Or without compose:

```bash
make image
docker run --rm -p 8080:8080 \
  -e BOTESITO_API_TOKEN=... \
  -e TELEGRAM_BOT_TOKEN=... \
  -e TELEGRAM_CHAT_ID=... \
  botesito:0.2.0
```

| variable | notes |
|---|---|
| `BOTESITO_API_TOKEN` | required; the bearer token callers must present |
| `TELEGRAM_BOT_TOKEN` | from @BotFather |
| `TELEGRAM_CHAT_ID` | numeric chat id, or `@channelname` |
| `BOTESITO_PORT` | defaults to 8080 |
| `BOTESITO_SPEC_PATH` | defaults to `docs/openapi.json`, resolved against `/app/release` |
| `BOTESITO_CONFIG` | optional path to a YAML config, loaded before the variables above |
| `BOTESITO_CHATOPS` | `true` turns on the Telegram poller, see [Chatops](#chatops) |

The container refuses to start without `BOTESITO_API_TOKEN`: without it no
request could ever succeed, so it fails loudly instead of answering 401 to
everything. A missing Telegram token is softer, since you may add it
later: it boots, `/healthz` reports `"telegram": "unconfigured"`, and
`/messages` answers 503.

`make ship REGISTRY=<host>` tags and pushes to a registry.

The build pulls dependencies over git+SSH, so it runs with `--ssh default`
and needs an agent holding a key with access to the nomasystems repos.
`docker compose` is already configured for that.

### Getting the Telegram values

1. Talk to [@BotFather](https://t.me/BotFather), `/newbot`, keep the token.
2. Send any message to your new bot from your own account.
3. `curl "https://api.telegram.org/bot<token>/getUpdates"` and read
   `result[0].message.chat.id`. That number is `TELEGRAM_CHAT_ID`.

## Development

```bash
make shell        # config/dev/botesito.config.yml
make shell-local  # config/local/botesito.config.yml (gitignored, put real tokens here)
make check        # compile + fmt + xref + dialyzer + hank, under the plt profile
make test
```

`make check` runs `rebar3 as plt check` rather than `rebar3 check`. `ntask` keeps
`nmongo` as an optional application, so it is not fetched, but rebar3 still wants
it while it resolves `plt_apps, all_deps` and refuses to build the PLT without it.
The `plt` profile pulls it in for that and nothing else, so the Mongo driver never
reaches the release.

Outside the container the config comes from a YAML file loaded by `conf`;
the path lives in `config/*/sys.config`.

```yaml
botesito:
  port: 8080
  spec_path: "docs/openapi.json"
  api_token: "<openssl rand -hex 32>"

telegram:
  bot_token: "123456:ABC-DEF..."
  chat_id: 123456789
```

Empty strings are not valid values. Leave a key (or the whole section) out
instead; the validator rejects `""` and aborts the whole config load.

Environment variables always win over the YAML, so you can point
`BOTESITO_CONFIG` at a file and still override one value at run time.

`make spec` regenerates `docs/openapi.json` from the YAML; every other
target that needs it depends on it. The server reads the JSON, so edit the
YAML and never the JSON.
