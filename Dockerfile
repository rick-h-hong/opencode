FROM ghcr.io/anomalyco/opencode:1.18.31

# The container runs as the invoking host user (see oc: --user UID:GID).
# The user building the image is the one running it, so hand /workspace and
# /home/user over to their uid:gid:
#   docker build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) ...
ARG USER_ID=1000
ARG GROUP_ID=1000

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0:/opt/gradle-9.8.1/bin"

RUN apk add --no-cache git nodejs npm go bash python3 openssh-client openjdk17 unzip curl make gcompat libgcc \
  && npm install -g @cortexkit/magic-context

RUN mkdir -p /workspace \
    /home/user/.config/opencode \
    /home/user/.local/share/opencode \
    /home/user/.local/state/opencode \
    /home/user/.local/share/cortexkit \
    /home/user/.android \
    /home/user/.cache/opencode \
    /home/user/.opencode \
    /home/user/.ssh

# Android SDK: cmdline-tools, then the android-34 packages, into /opt/android-sdk
RUN java -version \
  && mkdir -p "$ANDROID_HOME/cmdline-tools" \
  && curl -fsSL -o /tmp/cmdline-tools.zip \
      "https://dl.google.com/android/repository/commandlinetools-linux-12266719_latest.zip" \
  && unzip -q /tmp/cmdline-tools.zip -d "$ANDROID_HOME/cmdline-tools" \
  && mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest" \
  && rm /tmp/cmdline-tools.zip \
  && yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" --licenses \
  && "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" \
      "platforms;android-34" "build-tools;34.0.0" "platform-tools"

# Gradle 9.8.1 (Alpine ships no gradle package), runs on the image's openjdk17
RUN curl -fsSL -o /tmp/gradle-9.8.1-bin.zip \
       "https://services.gradle.org/distributions/gradle-9.8.1-bin.zip" \
  && echo "dce76f55f8e251a3a1f130eb120f30b3d271de2b76c9b0729d316b5a1b6dc01f  /tmp/gradle-9.8.1-bin.zip" | sha256sum -c - \
  && unzip -q /tmp/gradle-9.8.1-bin.zip -d /opt \
  && rm /tmp/gradle-9.8.1-bin.zip \
  && gradle --version

COPY opencode.json /home/user/.config/opencode/opencode.json

RUN chown -R "${USER_ID}:${GROUP_ID}" /workspace /home/user "$ANDROID_HOME" \
  && chmod 755 /home/user \
  && chmod 700 /home/user/.ssh

WORKDIR /workspace
