# nginx-bookworm-hardened
patched version of nginx:1.25-bookworm

# Build instructions:
make sure you work on windows OS.
1. make sure you have git, Docker desktop and make installed on your computer.
2. git clone this repository
3. run: 
```
make all 
```
this command will create the hardened docker image!

# Image size:
run
```
docker images nginx:1.25-bookworm --format "{{.Repository}}: {{.Size}}"  
docker images nginx-hardened:latest --format "{{.Repository}}: {{.Size}}"
```
before: 188 MB
after: 183 MB

*the original image installs nginx from Debian's apt package, which pulls the full module set plus packaging overhead, hence it is bigger.


# CVE table
 
| CVE | severity | binary/library | fix method | evidence |
|---|---|---|---|---|
| CVE-2024-32760 | Medium | nginx binary (`ngx_http_v3`) | **Version bump** 1.25.5 to 1.26.1 | [nginx CHANGES-1.26](https://nginx.org/en/CHANGES-1.26) |
| CVE-2024-35200 | Medium | nginx binary (`ngx_http_v3`) | **Version bump** 1.25.5 to 1.26.1 | [nginx CHANGES-1.26](https://nginx.org/en/CHANGES-1.26) |
| CVE-2024-34161 | Medium | nginx binary (`ngx_http_v3`) | **Version bump** 1.25.5 to 1.26.1 | [nginx CHANGES-1.26](https://nginx.org/en/CHANGES-1.26) |
| CVE-2024-31079 | Medium | nginx binary (`ngx_http_v3`) | **Version bump** 1.25.5 to 1.26.1 | [nginx CHANGES-1.26](https://nginx.org/en/CHANGES-1.26) |
| CVE-2025-23419 | Medium | nginx binary (SSL SNI callback) | **Backport patch** from 1.26.3 | [GitHub compare 1.26.1→1.26.3](https://github.com/nginx/nginx/compare/release-1.26.1...release-1.26.3) |
 
# why these CVEs
 
**version bump (CVE-2024-32760 and friends):** all four are HTTP/3 parser bugs
in the same subsystem introduced together and fixed together in 1.26.1. 
 
**backport (CVE-2025-23419):** The patch is small and applied cleanly, and 
the bug is meaningful: a client can resume aTLS 1.3 session from a server block 
that doesn't require client certificates
and reuse it on a server block that does, bypassing `ssl_verify_client`.
 
## Residual risk
 
| CVE | Severity | Why not fixed | What I'd do next |
|---|---|---|---|
| CVE-2023-44487 | High (KEV, EPSS 100%) | No Debian deb fix for nginx 1.25/1.26. Patch landed in nginx.org 1.25.3 but was never packaged by Debian for this branch. | Add `http2_max_concurrent_streams 1` to nginx.conf as mitigation, or upgrade to nginx:1.27+ base image |
| CVE-2026-42055 | Critical | Fixed in 1.30.x only — too large a gap to backport safely | Schedule upgrade to nginx:1.30-bookworm |
| CVE-2011-3389 (BEAST) | Negligible | TLS 1.0 attack; nginx disables TLS 1.0 by default in modern builds | Accept |
| CVE-2023-2953 | High | `libldap` won't-fix upstream; nginx doesn't use LDAP on the request path | Accept (transitive dep, no real exposure) |
| CVE-2023-52355/52356 | High | `libtiff6` won't-fix upstream; not on nginx request path | Accept (transitive dep) |
 
I was not able to make this image 100% secure at this point. in order to do so:
I will have to patch and bump versions of all the risks we can see in the baseline files.

with more time, I would dig dipper into the CVEs and find the root cause of them. my goal is to make this image as secure as possible.
This mission was fascinating for me, as a DevOps engineer I learned a LOT about images, CVEs, and especially understood how important it is to secure images.
I was introduced to new technologies, and I can not wait to continue working with them.
Thank you for the opportunity!
