# build/Dockerfile
# Produces the nginx .deb from upstream source.
# Starts from a clean debian:bookworm-slim — no pre-baked binaries.
#
# Usage (called by Makefile):
#   docker build -f build/Dockerfile -t nginx-deb-builder build/
#   docker run --rm -v $(pwd)/debs:/out nginx-deb-builder

FROM debian:bookworm-slim

COPY build.sh   /build/build.sh
COPY patches/   /build/patches/

RUN chmod +x /build/build.sh

CMD ["/build/build.sh"]