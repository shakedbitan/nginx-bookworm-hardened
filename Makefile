IMAGE   := nginx-hardened
TAG     := 1.26.1-bookworm
BUILDER := nginx-deb-builder

.PHONY: all build-deb image test clean

all: image

# compile nginx from source, create .deb
build-deb:
	docker build -f build/Dockerfile -t $(BUILDER) build/
	docker volume create nginx-debs
	docker run --rm -v nginx-debs:/out $(BUILDER)
	docker run --rm \
		-v nginx-debs:/out \
		-v "$(CURDIR):/host" \
		debian:bookworm-slim \
		sh -c "mkdir -p /host/debs && cp /out/nginx_*.deb /host/debs/ && echo 'deb ready:' && ls /host/debs/nginx_*.deb"

# build final container image
image: build-deb
	docker build -f Containerfile -t $(IMAGE):$(TAG) -t $(IMAGE):latest .

# run our test
test: image
	pip install -q requests docker
	python3 test/test.py nginx:1.25-bookworm $(IMAGE):$(TAG)

# remove build artifacts
clean:
	docker rmi $(IMAGE):$(TAG) $(IMAGE):latest $(BUILDER) 2>/dev/null || true
	docker volume rm nginx-debs 2>/dev/null || true
	docker run --rm -v "$(CURDIR):/host" debian:bookworm-slim \
		sh -c "rm -rf /host/debs"