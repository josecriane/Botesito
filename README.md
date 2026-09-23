# botesito

REST front-end for a Telegram bot. You POST a message, it lands in your
Telegram chat.

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
  botesito:0.1.0
```

| variable | notes |
|---|---|
| `BOTESITO_API_TOKEN` | required; the bearer token callers must present |
| `TELEGRAM_BOT_TOKEN` | from @BotFather |
| `TELEGRAM_CHAT_ID` | numeric chat id, or `@channelname` |
| `BOTESITO_PORT` | defaults to 8080 |
| `BOTESITO_SPEC_PATH` | defaults to `docs/openapi.json`, resolved against `/app/release` |
| `BOTESITO_CONFIG` | optional path to a YAML config, loaded before the variables above |

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
make check        # compile + fmt + xref + dialyzer + hank
make test
```

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
