FROM ghcr.io/anomalyco/opencode:1.18.31

# The container runs as the invoking host user (see oc: --user UID:GID).
# The user building the image is the one running it, so hand /workspace and
# /home/user over to their uid:gid:
#   docker build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) ...
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN apk add --no-cache git nodejs npm go bash openssh-client \
 && npm install -g @cortexkit/magic-context \
 && mkdir -p /workspace \
    /home/user/.config/opencode \
    /home/user/.local/share/opencode \
    /home/user/.local/state/opencode \
    /home/user/.local/share/cortexkit \
    /home/user/.cache/opencode \
    /home/user/.opencode \
    /home/user/.ssh

COPY opencode.json /home/user/.config/opencode/opencode.json

RUN chown -R "${USER_ID}:${GROUP_ID}" /workspace /home/user \
 && chmod 755 /home/user \
 && chmod 700 /home/user/.ssh

WORKDIR /workspace
