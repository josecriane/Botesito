# botesito

REST front-end for a Telegram bot. You POST a message, it lands in your
Telegram chat.

Same stack as `hobbytracker_bff`: design-first `erf` server over
`nhttp_erf`, `nhttpc` connection pools for outbound calls, `conf` for
optional YAML configuration, `relx` release packaged into a container.

## API

Two routes, described in `docs/openapi.yaml`.

    GET  /healthz    -> {"status": "ok", "telegram": "ok"}
    POST /messages   -> 201 {"message_id": .., "chat_id": .., "sent_at": .., "text": ..}

`/messages` needs a bearer token; `/healthz` does not.

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
