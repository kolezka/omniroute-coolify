# OmniRoute on Coolify

Deployment files for the [`diegosouzapw/omniroute`](https://hub.docker.com/r/diegosouzapw/omniroute)
image, a unified AI proxy that puts many LLM providers behind one endpoint
(source: [github.com/diegosouzapw/OmniRoute](https://github.com/diegosouzapw/OmniRoute)).

Image facts, read from the registry manifest for tag `3.8.50` on 2026-09-05:

| What | Value |
|---|---|
| Application port | **20128** (dashboard and API on the same port) |
| Data directory | `/app/data` (SQLite, logs, backups) |
| Container user | `node` (uid 1000); the entrypoint checks `/app/data` permissions |
| Healthcheck | `node healthcheck.mjs`, every 30s, 15s start period |
| Baked defaults | `PORT=20128`, `HOSTNAME=0.0.0.0`, `NODE_ENV=production`, `OMNIROUTE_MEMORY_MB=1024` |
| Architectures | amd64, arm64 |
| Health endpoints | `/healthz` (readiness), `/livez` (liveness), `/api/monitoring/health` (deep) |

## Deploy

Deploy **from this repository**. Coolify then injects the public URL itself,
which the pasted-compose path cannot do correctly (see the alternative below).
The repo is public, so Coolify needs no deploy key.

Requires **Coolify v4.0.0-beta.420.7 or newer**. Older releases run an
earlier parser that hands the app a hostname with no scheme, and OmniRoute
exits at startup rather than guessing.

1. Coolify → project → **New Resource → Public Repository**. Give it
   `https://github.com/kolezka/omniroute-coolify`, branch `main`, and pick
   **Docker Compose** as the build pack. Leave the Compose file field at its
   default `/docker-compose.yaml`; the file in this repo is named to match.
   Coolify reads that path literally and does not fall back to `.yml`.

2. **Domain.** Set the `omniroute` service's Domains field to
   `https://your-domain.com:20128`. The `:20128` is the *internal* port
   Coolify's proxy forwards to. Public traffic still arrives on HTTPS/443 and
   visitors use `https://your-domain.com` with no port.

   **Edit or replace the generated domain, do not add yours as a second
   entry.** Coolify takes the first domain in the list as canonical, so a
   generated one left in front keeps OAuth and dashboard links pointing at it.

   Leaving the field empty works only if the server has an **HTTPS** wildcard
   domain configured. Without one Coolify falls back to an `http://` sslip.io
   address; the app starts, but `AUTH_COOKIE_SECURE=true` then makes a Secure
   cookie the browser will not send over HTTP, and login bounces.

3. **Deploy.** Coolify generates every secret on the first deploy and reuses
   it afterwards, so redeploying will not rotate your keys. The container
   reports healthy after roughly 15 to 30 seconds.

4. **First login** at your domain. The password is the generated value of
   `SERVICE_PASSWORD_OMNIROUTE`, visible in Coolify under Environment
   Variables and injected as `INITIAL_PASSWORD`. Change it right after
   logging in: Dashboard → Settings → Security.

5. **Add providers** in Dashboard → Providers. Their credentials are stored
   with field-level encryption under `STORAGE_ENCRYPTION_KEY`, which is why
   they do not belong in environment variables.

Point your tools (Claude Code, Cursor, Cline) at `https://your-domain.com/v1`
with a key from Dashboard → API Keys. The compose sets `REQUIRE_API_KEY=true`,
so a key is mandatory.

### Why the repository path, and not pasted YAML

`NEXT_PUBLIC_BASE_URL` has to be a full public origin with a scheme, or OAuth
callbacks and every link the dashboard builds come out wrong. Coolify has two
different parsers, and they disagree about that value.

The **Docker Compose build pack** (this repo, an `Application` resource) reads
your Domains entry, keeps the scheme, strips the routing port, and refreshes
the value when you change the domain. `${SERVICE_URL_OMNIROUTE}` is therefore
exactly `https://your-domain.com`.

**Docker Compose Empty** (a pasted `Service` resource) goes through a different
code path that stores the value with the scheme stripped, and freezes it at
creation. There, `${SERVICE_URL_OMNIROUTE}` is a bare hostname.

So: if you paste the file instead, **edit the `NEXT_PUBLIC_BASE_URL` line in
the YAML** to a literal `https://your-domain.com` before creating the
resource. Setting `NEXT_PUBLIC_BASE_URL` in the Environment Variables UI does
not help: the compose mapping survives into the deployed file and keeps
resolving from `SERVICE_URL_OMNIROUTE`, so it wins. Everything else in the
file behaves the same on both paths.

### Back up the key, and the data

`STORAGE_ENCRYPTION_KEY` gives field-level AES-256-GCM encryption of stored
provider credentials and tokens. It does **not** encrypt the database as a
whole, so treat the volume and every backup of it as sensitive regardless.

Copy the generated value out of Coolify into your password manager before you
put anything real into the instance, and then leave it alone. Version 3.8.50
ships no re-encryption path: change the key and the stored credentials become
undecryptable, with only a logged mismatch to tell you.
`STORAGE_ENCRYPTION_KEY_VERSION` is initialized and persisted by the
bootstrap, but no encryption or decryption path reads it, so bumping it
rotates nothing.

Left to itself the image would generate the missing secrets on first boot and
persist them to `$DATA_DIR/server.env`, so nothing is silently stored in
plaintext. Letting Coolify supply them instead keeps the values out of the
data volume and visible where you can back them up.

Coolify generates each `SERVICE_*` value once, stores it, and reuses it. A
redeploy will not rotate your keys. Deleting the resource, or the variable
row, does lose them.

The automatic SQLite backups live in `db_backups` **inside the same
`/app/data` volume** as the live database, so they survive a redeploy but not
the loss of the host or the volume. Add an off-host copy of the
`omniroute-data` volume, test restoring it, and keep the matching encryption
key alongside it.

## Alternative: single Docker Image or Dockerfile resource

- **Docker Image**: use `diegosouzapw/omniroute:3.8.50`, port 20128, add a
  Volume for `/app/data`, and paste the variables from `.env.example`.
  Sections 1, 3 and 4 are the minimum, and section 2 is worth having;
  generate the secrets with the `openssl` commands in the comments. Section 4
  is not optional on a public instance: it carries `REQUIRE_API_KEY`.
- **Dockerfile**: use the bundled `Dockerfile`, a thin wrapper around the
  image, and configure the rest as above.

Neither path gives you Redis, which is why `.env.example` ships `REDIS_URL`
commented out. Leave it that way unless you actually run one: pointing ioredis
at a host that does not resolve costs connection retries and logs errors on
the request paths that use it, though an idle container stays quiet. Without
it the app falls back to an in-memory rate limiter, which upstream does not
recommend for production.

## Environment variables

Required before the first start:

| Variable | Role | Manual generation |
|---|---|---|
| `JWT_SECRET` | signs dashboard session cookies | `openssl rand -base64 48` |
| `API_KEY_SECRET` | HMAC behind the issued key format `sk-{machineId}-{keyId}-{crc8}`; encrypts nothing | `openssl rand -hex 32` |
| `OMNIROUTE_WS_BRIDGE_SECRET` | authenticates the internal WebSocket bridge. Upstream marks it required in production; leaving it out lets the standalone wrapper invent a fresh one on every restart | `openssl rand -base64 32` |
| `INITIAL_PASSWORD` | bootstrap password for the first login | `openssl rand -base64 16` |

Recommended:

| Variable | Role | Manual generation |
|---|---|---|
| `STORAGE_ENCRYPTION_KEY` | field-level encryption of stored provider credentials | `openssl rand -hex 32` |
| `MACHINE_ID_SALT` | machine fingerprint salt, unique per deployment | `openssl rand -hex 16` |

The secrets are passed through a KDF, so they need not be hex. Any strong
random value works; the commands above just produce sensible ones.

Behind a reverse proxy:

| Variable | Value | Why |
|---|---|---|
| `AUTH_COOKIE_SECURE` | `true` | forces the Secure flag behind HTTPS. OmniRoute also sets it when the proxy reports HTTPS, but do not lean on that. `false` only on plain HTTP |
| `NEXT_PUBLIC_BASE_URL` | your public `https://...` | OAuth callbacks and generated links |
| `BASE_URL` | `http://127.0.0.1:20128` | internal self-fetch for scheduled jobs; deliberately loopback |
| `REQUIRE_API_KEY` | `true` | a public instance should not proxy anonymously |
| `ALLOW_API_KEY_REVEAL` | `false` | keeps full key values out of the dashboard |
| `MAX_BODY_SIZE_BYTES` | `5242880` | upstream's hardening recommendation; the default is 10 MB |
| `OMNIROUTE_TRUST_PROXY` | leave unset | only for setups where direct container access is blocked and the proxy sanitises forwarded headers |

Full upstream list:
[.env.example in the OmniRoute repo](https://github.com/diegosouzapw/OmniRoute/blob/main/.env.example).

### A note on Coolify's magic variables

Coolify parses `SERVICE_*` names by **counting underscores**, not by regex.
An extra underscore in the identifier silently selects a different
generator, and an unrecognised one yields an empty value with no error.
`SERVICE_BASE64_MACHINE_SALT` would parse its command as `BASE64_MACHINE`
and produce nothing. Keep identifiers underscore-free.

Two names are also misleading: `SERVICE_BASE64_*` is *not* base64, it is a
plain random string (Coolify's own source says so). `SERVICE_REALBASE64_*`
is the real thing.

## Image variants and updates

- `3.8.50` is the current release; `3.8.50-web` adds Chromium and
  Playwright, needed only for web-cookie providers (`gemini-web`,
  `claude-web`, `claude-turnstile`). It is larger, but not by as much as
  often claimed: 1.67 GB of layers against 1.24 GB on amd64.
- The compose file pins a version on purpose. This project releases very
  often, and `latest` has shipped a broken build before (see below).
- To update: change the tag, then **Redeploy**. Migrations run on startup
  and an automatic SQLite backup is taken first
  (`DISABLE_SQLITE_AUTO_BACKUP=false`).
- Expect every session and in-flight request to drop during a restart.
  There is no rolling update on SQLite.

## Persistence and permissions

Data lives in the `omniroute-data` named volume mounted at `/app/data`. The
container runs as `node` (uid 1000); with a named volume Docker handles the
permissions. If you switch to a host bind-mount, set the owner with
`chown -R 1000:1000 <directory>`. If you do not, the entrypoint
(`check-permissions.sh`) prints a warning and starts the app anyway, and the
failure surfaces later on the first database write.

## Troubleshooting

### 502 Bad Gateway

Two different causes; the port in the error tells them apart.

**`dial tcp <ip>:80: connect: connection refused`** means the proxy is
forwarding to port 80 while OmniRoute listens on 20128. Set the `omniroute`
service's Domains field to `https://your-domain.com:20128` and redeploy.

**A 502 with the correct port** usually means the container is not up. A
restart, a redeploy, or a failed healthcheck empties the proxy's backend for
a few seconds and every request in that window gets a 502 that clients cannot
distinguish from a provider error. Check the container status first, and only
then the logs.

### Login page accepts the password but bounces back

`AUTH_COOKIE_SECURE=true` on a plain-HTTP domain. The browser refuses to
store a `Secure` cookie over HTTP, so the session never sticks. Either put
the instance behind HTTPS (correct) or set the variable to `false`
(development only).

### `Error: file data stream has unexpected number of bytes` on startup

Affects **3.8.45 and 3.8.46 only**. Fixed upstream in **3.8.47**; the pinned
`3.8.50` is not affected. Upgrade rather than working around it.

Historical note, because this repo previously documented it wrongly: the
crash was not corrupted Turbopack chunks. Upstream traced it to a race in
the legacy log-archive migration (issue #6401, PR #6898); the stack trace
merely pointed into a bundled chunk. The `OMNIROUTE_USE_TURBOPACK=0`
workaround that used to live in this file **never did anything** in the
published image. That variable is a build argument, consumed while the image
is built. At runtime the container starts `dev/run-standalone.mjs`, which
launches the prebuilt server and never reads it.

### Redis logs `WARNING Memory overcommit must be enabled!`

Harmless advisory from the `redis` sidecar, unrelated to OmniRoute. It
matters only under memory pressure, where a background save could fail. To
silence it, run `sudo sysctl vm.overcommit_memory=1` on the **Coolify host**
and add `vm.overcommit_memory = 1` to `/etc/sysctl.conf`. It is a host kernel
setting and cannot be set from a compose file.
