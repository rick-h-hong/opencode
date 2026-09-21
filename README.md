# opencode-container

Containerised [opencode](https://opencode.ai) that works against a local [Ollama](https://ollama.com) server.

Includes the [`@cortexkit/magic-context`](https://www.npmjs.com/package/@cortexkit/magic-context) CLI (`magic-context`) for setup, doctor, and migration across OpenCode and Pi.

## Requirements

- Docker (with `host.docker.internal` available, e.g. Linux with `--host-gateway` or Docker Desktop)
- Ollama running on the host, listening on port 11434

## Build

```sh
# build as the user that will run the container (owner of /workspace + /home/user)
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  -t oc-local .
```

Rebuild when switching the user that runs the image (or after `Dockerfile`/`opencode.json` changes).

The image is based on `ghcr.io/anomalyco/opencode:1.18.31` and adds:

- `git`, `nodejs`, `npm`, `go`, `bash`, `openssh-client`
- Home dir `/home/user` (owned by the build user's uid/gid — the container runs as your host user)
- Global install of `@cortexkit/magic-context`
- `opencode.json` baked in at `/home/user/.config/opencode/opencode.json`, pointing at `http://host.docker.internal:11434/v1`

## Usage

The `oc` helper script runs opencode inside the container against your local Ollama:

```sh
./oc [PATH] [OPENCODE ARGS...]
```

Examples:

```sh
./oc ~/code/myproject                          # interactive TUI in a project
./oc run "fix the failing test"                # one-shot run in the current dir
./oc models                                   # list models
./oc -m ollama/qwen3.8-64k                     # override the model
```

Environment overrides:

| Variable            | Default                                        | Purpose                         |
| ------------------- | ---------------------------------------------- | ------------------------------- |
| `OC_IMAGE`          | `oc-local`                                     | image to use                    |
| `OC_OLLAMA_URL`     | `http://host.docker.internal:11434`            | Ollama base URL                 |
| `OC_CONTAINER_HOME` | `/home/user`                                   | home dir for state mounts       |
| `OC_GIT_NAME`       | host `git config user.name`                    | git commit name in the container |
| `OC_GIT_EMAIL`      | host `git config user.email`                   | git commit email in the container |
| `OC_SSH_COMMAND`    | built from your host's `~/.ssh` keys           | full `ssh` command for git      |
| `OC_NO_STATE`       | _(unset)_                                      | set to `1` to skip state mounts |

The script pre-checks that the image exists and Ollama is reachable before starting, and mounts your host opencode state (`~/.local/share/opencode`, etc.) plus `~/.ssh` and `/etc/passwd` so sessions and private git repos keep working. Git identity (committing) comes from the host's `git config user.name`/`user.email`, passed in as `GIT_*` env vars. For git over SSH, the script assembles a `GIT_SSH_COMMAND` that points at the mounted keys with explicit `IdentityFile`/`UserKnownHostsFile` paths (ssh would otherwise look under the host home from `/etc/passwd`, which is not mounted). The host's `~/.config/opencode` is deliberately **not** mounted — the image's baked-in `opencode.json` targets `host.docker.internal` instead.

## Configuration

`opencode.json` configures the Ollama provider via `@ai-sdk/openai-compatible` with models `qwen3.8-64k`, `qwen3.8-48k`, and `qwen3.8-32k`. It also sets auto-compaction (8000-token buffer) and denies access to external directories.

To use different models, pull them into Ollama first (`ollama pull ...`) and edit the provider block in `opencode.json`, then rebuild.

## magic-context

```sh
docker run --rm --entrypoint sh oc-local -c "magic-context --help"
```
