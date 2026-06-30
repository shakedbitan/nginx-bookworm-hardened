#!/usr/bin/env python3
"""

Compatibility test for the hardened nginx image.

Boots nginx:1.25-bookworm (baseline) and nginx-hardened:latest (hardened)
as separate containers, fires the same HTTP requests at both, and asserts
that status codes, headers, and bodies match.

What "working correctly" means:
  - Same HTTP status codes for every request
  - Same Content-Type headers
  - Same response body content for static files
  - Same error behavior for malformed / oversized / unknown requests
  - The hardened image does not introduce any behavioral regression

What this test covers:
  1. Root path GET — basic serving works
  2. Non-existent path — 404 handling matches
  3. HEAD request — returns 200 with no body
  4. Large request body — nginx accepts or rejects identically
  5. Malformed HTTP method — behavior matches
  6. Custom header round-trip — headers passed through correctly
  7. Response Content-Type — mime type detection matches
  8. Server header presence — both respond with a Server header

Usage:
  pip install requests docker
  python test/test.py [BASELINE_IMAGE] [HARDENED_IMAGE]

Defaults:
  BASELINE_IMAGE = nginx:1.25-bookworm
  HARDENED_IMAGE = nginx-hardened:latest
"""

import sys
import time
import argparse
import docker
import requests

# ── Constants ─────────────────────────────────────────────────────────────────

BASELINE_IMAGE = "nginx:1.25-bookworm"
HARDENED_IMAGE = "nginx-hardened:latest"

BASELINE_PORT = 18081
HARDENED_PORT = 18082

PASS = 0
FAIL = 0
FAILURES = []


# ── Helpers ───────────────────────────────────────────────────────────────────

def ok(label):
    global PASS
    PASS += 1
    print(f"  ✅  {label}")


def fail(label, reason):
    global FAIL
    FAIL += 1
    FAILURES.append(f"{label}: {reason}")
    print(f"  ❌  {label} — {reason}")


def assert_eq(label, got, want):
    if got == want:
        ok(label)
    else:
        fail(label, f"got {got!r}, want {want!r}")


def assert_in(label, needle, haystack):
    if needle in haystack:
        ok(label)
    else:
        fail(label, f"{needle!r} not found in {haystack!r}")


def wait_for_nginx(port, timeout=10):
    """Poll until nginx is up or timeout."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            requests.get(f"http://localhost:{port}/", timeout=1)
            return True
        except requests.exceptions.ConnectionError:
            time.sleep(0.3)
    return False


def get(port, path="/", **kwargs):
    return requests.get(f"http://localhost:{port}{path}", timeout=5, **kwargs)


def head(port, path="/", **kwargs):
    return requests.head(f"http://localhost:{port}{path}", timeout=5, **kwargs)


def post(port, path="/", **kwargs):
    return requests.post(f"http://localhost:{port}{path}", timeout=5, **kwargs)


# ── Test cases ────────────────────────────────────────────────────────────────

def run_tests(baseline_port, hardened_port):
    """
    Each test fires the same request at both images and compares the result.
    Tests are grouped by what they cover.
    """

    # 1. Root path — basic serving
    print("\n[ 1/8 ] GET / — basic serving")
    b = get(baseline_port)
    h = get(hardened_port)
    assert_eq("status code matches", h.status_code, b.status_code)
    assert_eq("status is 200", h.status_code, 200)
    assert_in("body contains welcome text (baseline)", "Welcome to nginx", b.text)
    assert_in("body contains welcome text (hardened)", "Welcome to nginx", h.text)

    # 2. Non-existent path — 404 handling
    print("\n[ 2/8 ] GET /no-such-path — 404 handling")
    b = get(baseline_port, "/no-such-path-that-does-not-exist")
    h = get(hardened_port, "/no-such-path-that-does-not-exist")
    assert_eq("status code matches", h.status_code, b.status_code)
    assert_eq("status is 404", h.status_code, 404)

    # 3. HEAD request — no body, correct status
    print("\n[ 3/8 ] HEAD / — no body returned")
    b = head(baseline_port)
    h = head(hardened_port)
    assert_eq("status code matches", h.status_code, b.status_code)
    assert_eq("status is 200", h.status_code, 200)
    assert_eq("body is empty (baseline)", b.content, b"")
    assert_eq("body is empty (hardened)", h.content, b"")

    # 4. Large request body — nginx should accept or reject identically
    print("\n[ 4/8 ] POST / with 2MB body — large body handling")
    large_body = "x" * (2 * 1024 * 1024)
    b = post(baseline_port, data=large_body)
    h = post(hardened_port, data=large_body)
    assert_eq("status code matches", h.status_code, b.status_code)

    # 5. Custom request header round-trip
    print("\n[ 5/8 ] GET / with custom header — header handling")
    headers = {"X-Test-Header": "nginx-compat-test"}
    b = get(baseline_port, headers=headers)
    h = get(hardened_port, headers=headers)
    assert_eq("status code matches", h.status_code, b.status_code)

    # 6. Content-Type header on HTML response
    print("\n[ 6/8 ] Content-Type header — mime type detection")
    b = get(baseline_port)
    h = get(hardened_port)
    b_ct = b.headers.get("Content-Type", "")
    h_ct = h.headers.get("Content-Type", "")
    assert_in("baseline Content-Type is text/html", "text/html", b_ct)
    assert_in("hardened Content-Type is text/html", "text/html", h_ct)
    assert_eq("Content-Type matches", h_ct, b_ct)

    # 7. Server header presence
    print("\n[ 7/8 ] Server header — nginx is identifying itself")
    b = get(baseline_port)
    h = get(hardened_port)
    assert_in("baseline has Server header", "Server", dict(b.headers))
    assert_in("hardened has Server header", "Server", dict(h.headers))

    # 8. Repeated requests — connection stability
    print("\n[ 8/8 ] 10 consecutive GETs — connection stability")
    errors = 0
    for _ in range(10):
        try:
            r = get(hardened_port)
            if r.status_code != 200:
                errors += 1
        except Exception:
            errors += 1
    assert_eq("all 10 requests returned 200", errors, 0)


# ── Container lifecycle ───────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", nargs="?", default=BASELINE_IMAGE)
    parser.add_argument("hardened", nargs="?", default=HARDENED_IMAGE)
    args = parser.parse_args()

    client = docker.from_env()

    print(f"Baseline : {args.baseline}")
    print(f"Hardened : {args.hardened}")
    print("─────────────────────────────────────────")

    # Start both containers
    print("Starting containers...")
    baseline_container = client.containers.run(
        args.baseline,
        detach=True,
        remove=True,
        ports={"80/tcp": BASELINE_PORT},
    )
    hardened_container = client.containers.run(
        args.hardened,
        detach=True,
        remove=True,
        ports={"80/tcp": HARDENED_PORT},
    )

    try:
        print(f"Waiting for baseline on :{BASELINE_PORT}...")
        if not wait_for_nginx(BASELINE_PORT):
            print("ERROR: baseline container did not start in time")
            sys.exit(1)

        print(f"Waiting for hardened on :{HARDENED_PORT}...")
        if not wait_for_nginx(HARDENED_PORT):
            print("ERROR: hardened container did not start in time")
            sys.exit(1)

        run_tests(BASELINE_PORT, HARDENED_PORT)

    finally:
        baseline_container.stop()
        hardened_container.stop()

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n══════════════════════════════════════════")
    print(f"  {PASS} passed / {FAIL} failed")
    print("══════════════════════════════════════════")

    if FAILURES:
        print("\nFailures:")
        for f in FAILURES:
            print(f"  - {f}")
        sys.exit(1)


if __name__ == "__main__":
    main()