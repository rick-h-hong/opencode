# Rebuild the opencode container image.
#   make build     build the image (as the user that will run it)
#   make run       quick smoke test: node/go/gradle/java versions inside
#
# Override the image name (default oc-local, matching oc's default):
#   make build IMAGE=my-image

IMAGE ?= oc-local

.PHONY: build run clean

build:
	docker build --build-arg USER_ID=$(shell id -u) --build-arg GROUP_ID=$(shell id -g) -t $(IMAGE) .

run:
	docker run --rm --entrypoint sh $(IMAGE) -c \
		'node -v && go version && java -version 2>&1 && gradle -v 2>&1 | grep Gradle'

clean:
	docker image rm $(IMAGE) 2>/dev/null || true
