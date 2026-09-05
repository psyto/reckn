#!/usr/bin/env bash
# AC-16 — the three other `reexec-evm` consumers still build, including their tests.
#
# 008 changes `reexec-evm`'s testkit, and the testkit is CROSS-CRATE:
# binder/Cargo.toml takes features = ["testkit"] and binder/tests/router_two_vms.rs
# imports from it. AC-0b's prefix digest stops above the testkit cfg line and AC-15
# runs only reexec-evm's own tests, so neither sees a testkit signature change that
# breaks binder's test build.
#
# `--tests` is load-bearing: without it router_two_vms.rs is never compiled and this
# check is vacuous. The three are standalone packages, not workspace members, so
# these are three per-directory invocations rather than one -p list.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)

clean=0
fail=0
for d in binder keeper reckn-evm-content; do
  if (cd "$root/$d" && cargo check --tests) > /dev/null 2>&1; then
    clean=$((clean + 1))
  else
    printf '  BROKEN         %s does not `cargo check --tests` clean\n' "$d"
    (cd "$root/$d" && cargo check --tests 2>&1 | grep -E '^error' | head -3 | sed 's/^/      /') || true
    fail=1
  fi
done

witness=$( { shasum -a 256 "$root/reexec-evm/src/lib.rs" | cut -d' ' -f1 | tr -d '\n' | xxd -r -p
             cat "$root/binder/Cargo.toml" "$root/keeper/Cargo.toml" \
                 "$root/reckn-evm-content/Cargo.toml" "$root/binder/tests/router_two_vms.rs"; } \
           | shasum -a 256 | cut -c1-16)
echo "consumers: binder, keeper, reckn-evm-content check --tests clean ($clean/3); witness=$witness"
[[ $fail -eq 0 ]] || exit 1
