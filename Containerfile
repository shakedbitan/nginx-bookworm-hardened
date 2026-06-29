# Containerfile
# Builds the final hardened nginx image from the .deb produced by build/.
#
# Matches nginx:1.25-bookworm exactly:
#   - nginx user uid=101
#   - same paths (/etc/nginx, /var/cache/nginx, /var/log/nginx)
#   - same EXPOSE, STOPSIGNAL, WORKDIR, ENTRYPOINT, CMD

FROM debian:bookworm-slim

ENV NGINX_VERSION=1.26.1 \
    PKG_RELEASE=1~bookworm

# Same user and uid as the official nginx image
RUN groupadd --system --gid 101 nginx && \
    useradd --system --gid nginx --no-create-home \
            --home /nonexistent --comment "nginx user" \
            --shell /bin/false --uid 101 nginx

# Copy the .deb produced by build/
COPY debs/nginx_*.deb /tmp/nginx.deb

# Upgrade system packages — eliminates CVEs in libssl3, libcurl4, libfreetype6,
# libexpat1, libkrb5, libnghttp2, libxml2, libsystemd0 that already have
# Debian security updates available.
# Then install our custom-built nginx .deb.
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

# Symlink logs to stdout/stderr — identical to official nginx image
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Match official image exactly
EXPOSE 80
STOPSIGNAL SIGQUIT
WORKDIR /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]