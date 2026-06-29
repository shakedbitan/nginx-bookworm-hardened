#!/bin/bash
# build/build.sh
#
# Fetches nginx 1.26.1 source, applies patches, compiles, and packages a .deb.
#
# Outputs: /out/nginx_1.26.1-1~bookworm_amd64.deb
#
# CVE remediation:
#   VERSION BUMP  1.25.5 → 1.26.1
#     Fixes CVE-2024-32760, CVE-2024-35200, CVE-2024-34161, CVE-2024-31079
#   BACKPORT PATCH  patches/CVE-2025-23419.patch
#     TLS session resumption bypass, fixed in 1.26.3, backported onto 1.26.1

set -euo pipefail

NGINX_VER="1.26.1"
OUTDIR="/out"
STAGEDIR="/tmp/nginx-stage"
SRCDIR="/tmp/nginx-${NGINX_VER}"

echo "==> Installing build dependencies"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    wget ca-certificates \
    build-essential \
    libpcre2-dev libssl-dev zlib1g-dev \
    libgd-dev libgeoip-dev libxslt1-dev \
    patch
rm -rf /var/lib/apt/lists/*

# ── 1. Fetch source ───────────────────────────────────────────────────────────
echo "==> Fetching nginx ${NGINX_VER} source"
cd /tmp
wget -q "https://nginx.org/download/nginx-${NGINX_VER}.tar.gz"
tar xzf "nginx-${NGINX_VER}.tar.gz"
cd "${SRCDIR}"

# ── 2. Apply patches ──────────────────────────────────────────────────────────
echo "==> Applying patches"
for p in /build/patches/*.patch; do
    echo "    patch: $(basename "$p")"
    patch -p1 < "$p"
done

# ── 3. Configure ──────────────────────────────────────────────────────────────
echo "==> Configuring"
./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib64/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -fPIC' \
    --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie'

# ── 4. Compile ────────────────────────────────────────────────────────────────
echo "==> Compiling"
make -j"$(nproc)"

# ── 5. Install into staging directory ────────────────────────────────────────
echo "==> Installing into staging dir"
make install DESTDIR="${STAGEDIR}"

# Create dirs nginx expects at runtime
install -d "${STAGEDIR}/var/cache/nginx"
install -d "${STAGEDIR}/var/log/nginx"
install -d "${STAGEDIR}/var/run"
install -d "${STAGEDIR}/etc/nginx/conf.d"
install -d "${STAGEDIR}/docker-entrypoint.d"

# ── 6. Build the .deb manually ───────────────────────────────────────────────
echo "==> Building .deb"

DEB_NAME="nginx"
DEB_VER="${NGINX_VER}-1~bookworm"
DEB_ARCH="amd64"
DEB_FILE="${OUTDIR}/${DEB_NAME}_${DEB_VER}_${DEB_ARCH}.deb"
CONTROL_DIR="${STAGEDIR}/DEBIAN"

mkdir -p "${CONTROL_DIR}" "${OUTDIR}"

# Calculate installed size in KB
INSTALLED_SIZE=$(du -sk "${STAGEDIR}" | cut -f1)

# Write the DEBIAN/control file — this is what dpkg reads to know what package it is
cat > "${CONTROL_DIR}/control" <<EOF
Package: ${DEB_NAME}
Version: ${DEB_VER}
Architecture: ${DEB_ARCH}
Maintainer: Hardened Build <build@local>
Installed-Size: ${INSTALLED_SIZE}
Depends: libpcre2-8-0, zlib1g, libssl3, libgd3, libgeoip1, libxslt1.1
Section: httpd
Priority: optional
Description: nginx web server (hardened build)
 nginx ${NGINX_VER} compiled from upstream source.
 Version bump from 1.25.5 fixes CVE-2024-32760, CVE-2024-35200,
 CVE-2024-34161, CVE-2024-31079.
 Backport patch applied for CVE-2025-23419.
EOF

# Write postinst — creates the nginx user/group on install
cat > "${CONTROL_DIR}/postinst" <<'EOF'
#!/bin/sh
set -e
if ! getent group nginx > /dev/null 2>&1; then
    groupadd --system --gid 101 nginx
fi
if ! getent passwd nginx > /dev/null 2>&1; then
    useradd --system --gid nginx --no-create-home \
            --home /nonexistent --comment "nginx user" \
            --shell /bin/false --uid 101 nginx
fi
EOF
chmod 755 "${CONTROL_DIR}/postinst"

# Package it
dpkg-deb --build --root-owner-group "${STAGEDIR}" "${DEB_FILE}"

echo ""
echo "==> Done:"
ls -lh "${DEB_FILE}"
