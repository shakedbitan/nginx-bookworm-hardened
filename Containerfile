# builds the final hardened nginx image 

FROM debian:bookworm-slim

ENV NGINX_VERSION=1.26.1 \
    PKG_RELEASE=1~bookworm

# same user and uid as official nginx image
RUN groupadd --system --gid 101 nginx && \
    useradd --system --gid nginx --no-create-home \
            --home /nonexistent --comment "nginx user" \
            --shell /bin/false --uid 101 nginx

# copy the .deb 
COPY debs/nginx_*.deb /tmp/nginx.deb

# upgrade system packages- eliminating CVEs in libssl3, libcurl4, libfreetype6,
# libexpat1, libkrb5, libnghttp2, libxml2, libsystemd0 
# than install our custom-built nginx .deb.
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libpcre2-8-0 \
        libssl3 \
        zlib1g \
        libgd3 \
        libgeoip1 \
        libxslt1.1 \
        gettext-base && \
    dpkg -i /tmp/nginx.deb && \
    rm /tmp/nginx.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# symlink logs to stdout/stderr- identical to official nginx image
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# match official image exactly
EXPOSE 80
STOPSIGNAL SIGQUIT
WORKDIR /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]