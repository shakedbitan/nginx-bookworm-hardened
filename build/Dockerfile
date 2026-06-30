# produces the nginx .deb from upstream source.
# starts from a clean debian:bookworm-slim 

FROM debian:bookworm-slim

COPY build.sh   /build/build.sh
COPY patches/   /build/patches/

RUN chmod +x /build/build.sh

CMD ["/build/build.sh"]