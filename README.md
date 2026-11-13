# opencode-container

Containerised [opencode](https://opencode.ai) that works against a local [llama.cpp](https://github.com/ggml-org/llama.cpp) server.

Includes the [`@cortexkit/magic-context`](https://www.npmjs.com/package/@cortexkit/magic-context) CLI (`magic-context`) for setup, doctor, and migration across OpenCode and Pi, plus the [`@cortexkit/opencode-magic-context`](https://www.npmjs.com/package/@cortexkit/opencode-magic-context) plugin, which is enabled in the baked-in `opencode.json` so sessions get unbounded context inside the container.

## Requirements

- Docker (with `host.docker.internal` available, e.g. Linux with `--host-gateway` or Docker Desktop)
- llama-server (llama.cpp) running on the host, listening on port 11434

## Build

```sh
# build as the user that will run the container (owner of /workspace + /home/user)
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  -t oc-local .
```

or simply `make build` (override the image name with `make build IMAGE=...`; `make run` is a quick smoke test, `make clean` removes the image).

Rebuild when switching the user that runs the image (or after `Dockerfile`/`opencode.json`/`cli.json`/`.cortexkit/magic-context.jsonc` changes).

The image is based on `ghcr.io/anomalyco/opencode:2.2.6` and adds:

- `git`, `nodejs`, `npm`, `go`, `bash`, `openssh-client`, `python3`, `openjdk17`, `unzip`, `curl`, `make`, `chromium`
- Android SDK 34 in `$ANDROID_HOME` (`/opt/android-sdk`): `platforms;android-34`, `build-tools;34.0.0`, `platform-tools`, with `sdkmanager`, `adb`, etc. on `PATH`
- Gradle 9.8.1 in `/opt/gradle-9.8.1`, on `PATH`, running on the image's `openjdk17`
- `chromium`, headless-capable (e.g. `chromium --headless=new --no-sandbox --dump-dom https://example.com`)
- Home dir `/home/user` (owned by the build user's uid/gid — the container runs as your host user)
- Global install of `@cortexkit/magic-context@0.49.50`
- `opencode.json` baked in at `/home/user/.config/opencode/opencode.json`, pointing at `http://host.docker.internal:11434/v1` with the magic-context plugin enabled
- `cli.json` baked in at `/home/user/.config/opencode/cli.json` (TUI/CLI settings, schema `https://opencode.ai/v2/cli.json`), disabling the Mini TUI splash banners (`mini.splash: "hide"`)
- magic-context historian config baked in at `/home/user/.config/cortexkit/magic-context.jsonc` (points the historian at `llama/Qwen3.5`, see [magic-context](#magic-context))

## Usage

The `oc` helper script runs opencode inside the container against your local llama-server.

To make it available system-wide, create a symlink:

```sh
ln -sf /workspace/oc /usr/local/bin/oc
```

Examples:

```sh
./oc ~/code/myproject                          # interactive TUI in a project
./oc run "fix the failing test"                # one-shot run in the current dir
./oc models                                    # list models
./oc -m llama/Qwen3.8-gsq-rco                  # override the model
./oc serve ~/code/myproject                    # start the remote server (see below)
./oc stop                                      # stop the remote server
```

Environment overrides:

| Variable            | Default                                        | Purpose                         |
| ------------------- | ---------------------------------------------- | ------------------------------- |
| `OC_IMAGE`          | `oc-local`                                     | image to use                    |
| `OC_LLM_URL`        | `http://host.docker.internal:11434`            | llama-server base URL           |
| `OC_CONTAINER_HOME` | `/home/user`                                   | home dir for state mounts       |
| `OC_GIT_NAME`       | host `git config user.name`                    | git commit name in the container |
| `OC_GIT_EMAIL`      | host `git config user.email`                   | git commit email in the container |
| `OC_SSH_COMMAND`    | built from your host's `~/.ssh` keys           | full `ssh` command for git      |
| `OC_NO_STATE`       | _(unset)_                                      | set to `1` to skip state mounts |
| `OC_SERVER_PASSWORD`| strong random (generated if unset)             | server password for `oc serve`  |
| `OC_SERVER_PASSWORD_FILE`| _(unset)_                                 | file (chmod 600) holding the password; kept out of env |
| `OC_SERVER_PORT`    | `4096`                                         | published port for `oc serve`   |
| `OC_LAN_IP`         | `0.0.0.0`                                      | host interface the server port binds to |

`OC_OLLAMA_URL` is still accepted as a fallback for `OC_LLM_URL`.

The script pre-checks that the image exists and llama-server is reachable before starting, and mounts opencode session state (`~/.local/share/opencode`), magic-context state (`~/.local/share/cortexkit`), and Android keystores (`~/.local/share/android` → `~/.android`) — all pre-created on first run so a bind mount isn't root-owned — plus `~/.ssh` (if present) and `/etc/passwd`, so sessions, memory, and private git repos keep working. `OC_NO_STATE=1` skips all of the optional mounts. Git identity (committing) comes from the host's `git config user.name`/`user.email`, passed in as `GIT_*` env vars. For git over SSH, the script assembles a `GIT_SSH_COMMAND` that points at the mounted keys with explicit `IdentityFile`/`UserKnownHostsFile` paths (ssh would otherwise look under the host home from `/etc/passwd`, which is not mounted). The host's `~/.config/opencode` is deliberately **not** mounted — the image's baked-in `opencode.json` targets `host.docker.internal` instead.

## Configuration

`opencode.json` configures the `llama` provider (named `llama.cpp`) via `@ai-sdk/openai-compatible` with the models `Qwen3.8-gsq-rco` (session model) and `Qwen3.5` (magic-context historian), both with 96k context, 8k output, tool calling and reasoning. OpenCode's native auto-compaction is disabled (`compaction: { auto: false }`) because the magic-context plugin manages compaction instead, and the plugin is enabled via the `plugins` field. It also allows all external-directory access without prompts (`permissions`: `external_directory` → `allow`) and enables the todo tool (`experimental.todo: true`).

To use different models, load them into llama-server first and edit the provider block in `opencode.json`, then rebuild.

`cli.json` holds the TUI/CLI settings (theme, keybinds, Mini transcript options, ...). Here it only sets `mini.splash: "hide"` so the entry/exit splash banners are not written to scrollback; all other TUI settings keep their defaults.

## Remote access (mobile app)

`oc serve [PATH]` starts a persistent, detached container (`oc-server`, restarts on boot) that runs `opencode serve` on the host-published port, so you can connect from the [OpenCode mobile app](https://getopencode.app/) or a browser:

```sh
./oc serve ~/code/myproject   # or: OC_SERVER_PASSWORD=... ./oc serve
./oc stop                     # stop and remove the server container
```

The server uses Basic auth: the username is always `opencode`, and the password is `OC_SERVER_PASSWORD`, or the first line of `OC_SERVER_PASSWORD_FILE` if that is set (the file is `chmod 600`-expected — `oc` warns if it is group/world-readable — and is mounted into the container as a file rather than an env var, so it never shows up in `docker inspect`). If neither is set, a 32-byte random password is generated and printed. In the app, add a connection manually:

- **Server**: `http://<host-ip>:4096` (the printed value)
- **Username**: `opencode`
- **Password**: the printed password

The same URL serves the full web UI in a browser. The `llama` provider points at the host's llama-server, so sessions started from the phone work exactly like local `oc` sessions, including session state, memory, and git.

Security notes:

- The password is the only gate — anyone who has it gets a full opencode agent in your workspace (it can run commands as your user). Keep it long and random, and re-run `oc serve` with a new `OC_SERVER_PASSWORD`/`OC_SERVER_PASSWORD_FILE` to rotate it. `oc` refuses to start with a password under 16 characters.
- By default the port is published on all host interfaces (`OC_LAN_IP=0.0.0.0`). On a trusted LAN that is fine; for anything else set `OC_LAN_IP` to a single interface (LAN address or Tailscale address), so the port only answers there — see *Over the internet (Tailscale)* below.
- Traffic on the published port is plain HTTP; encryption is provided by the path you choose (private LAN or Tailscale), not by the server.

### Over the internet (Tailscale)

For access from anywhere, put the host and the phone on the same tailnet (free personal tier) — no router ports, WireGuard-encrypted:

1. **Host**: install Tailscale (`curl -fsSL https://tailscale.com/install.sh | sh`), create an auth key at [login.tailscale.com/admin](https://login.tailscale.com/admin) → **Keys** (shown once), then:
   ```sh
   tailscale up --auth-key=tskey-... --hostname=oc-host
   tailscale status    # note the Tailscale IP (100.x.y.z) and the .ts.net name
   ```
2. **Phone**: install Tailscale and sign in with the **same account** — it joins the tailnet automatically. Only affects traffic to tailnet peers; normal internet stays on Wi-Fi/cellular.
3. **Start the server bound to the tailnet interface only**:
   ```sh
   OC_LAN_IP=<tailscale-ip> ./oc serve [PATH]
   ```
4. **App**: add the connection with server `http://oc-host.<tailnet>.ts.net:4096`, username `opencode`, and the password from your file.

Sanity check before connecting: `curl http://oc-host.<tailnet>.ts.net:4096` from the phone should return `401` (auth required), not "connection refused".

## magic-context

The CLI is available globally in the image:

```sh
docker run --rm --entrypoint sh oc-local -c "magic-context --help"
```

The matching OpenCode plugin (`@cortexkit/opencode-magic-context`) is already enabled in the baked-in `opencode.json`. Its state lives in `~/.local/share/cortexkit`, which `oc` mounts from the host (and pre-creates on first run), so compacted history and project memory persist across container runs.

The historian (the model that summarizes compacted history and maintains project memory) runs on the cheaper `Qwen3.5` model instead of the session model. It is configured in `.cortexkit/magic-context.jsonc`:

```jsonc
{ "historian": { "opencode": { "model": "llama/Qwen3.5" } } }
```

`oc` mounts the host's `/workspace` over the image's, so that file is picked up as the project-level config wherever the repo lives; a copy is also baked into the image at `/home/user/.config/cortexkit/magic-context.jsonc` (user level), so the setting applies in every project even when `/workspace` is not mounted — project-level config merges on top of it. The plugin reloads the config live, so no rebuild is needed to change the historian model in a running container.
