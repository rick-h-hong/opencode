FROM ghcr.io/anomalyco/opencode:1.18.31

RUN apk add --no-cache git nodejs npm go bash openssh-client \
 && addgroup -g 1000 duka \
 && adduser -D -u 1000 -G duka -h /home/duka duka \
 && mkdir -p /workspace \
  && chown 1000:1000 /workspace \
  && chmod 775 /workspace

RUN npm install -g @cortexkit/magic-context

COPY --chown=duka:duka opencode.json /home/duka/.config/opencode/opencode.json

USER duka
WORKDIR /workspace
