#!/usr/bin/env bash
# Small, provider-neutral primitives for wrapper adapters.
#
# This file intentionally has no lock, payment, terminal-record, retry, or
# refusal policy. Those choices remain provider-owned until their behaviour is
# independently proven equivalent.

provider_wrapper_valid_name() {
  case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac
}

provider_wrapper_sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}
