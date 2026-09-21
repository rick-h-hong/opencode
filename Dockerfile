FROM ghcr.io/anomalyco/opencode:1.18.31

RUN apk add --no-cache git nodejs npm go bash openssh-client \
 && npm install -g @cortexkit/magic-context \
 && mkdir -p /workspace \
    /home/user/.config/opencode \
    /home/user/.local/share/opencode \
    /home/user/.local/state/opencode \
    /home/user/.cache/opencode \
    /home/user/.opencode \
    /home/user/.ssh \
 && chmod -R 777 /workspace /home/user

# container runs as the invoking host user (see oc: --user UID:GID), so the
# generic home dir must be writable by any uid
COPY opencode.json /home/user/.config/opencode/opencode.json

WORKDIR /workspace
