.PHONY: spec compile shell shell-local clean fmt check test release image run ship

-include Makefile.local

IMAGE    ?= botesito
TAG      ?= 0.1.0
REGISTRY ?=

spec:
	@if yq --version 2>&1 | grep -qi mikefarah; then \
		yq -o=json . docs/openapi.yaml > docs/openapi.json; \
	else \
		yq . docs/openapi.yaml > docs/openapi.json; \
	fi

compile: spec
	rebar3 compile

shell: spec
	rebar3 shell

shell-local: spec
	rebar3 as local shell

fmt:
	rebar3 fmt

check:
	rebar3 check

test:
	rebar3 test

release: spec
	rebar3 as prod release

image:
	DOCKER_BUILDKIT=1 docker build --ssh default \
		-t $(IMAGE):$(TAG) -t $(IMAGE):latest .

run: image
	docker run --rm -p 8080:8080 --env-file .env $(IMAGE):$(TAG)

# Push to a registry. Requires `docker login $(REGISTRY)` once and REGISTRY
# set, on the command line or in a gitignored Makefile.local.
ship: image
	@test -n "$(REGISTRY)" || { echo "set REGISTRY, e.g. make ship REGISTRY=ghcr.io/you"; exit 1; }
	docker tag $(IMAGE):$(TAG) $(REGISTRY)/$(IMAGE):$(TAG)
	docker tag $(IMAGE):latest $(REGISTRY)/$(IMAGE):latest
	docker push $(REGISTRY)/$(IMAGE):$(TAG)
	docker push $(REGISTRY)/$(IMAGE):latest

clean:
	rebar3 clean
	rm -rf _build
