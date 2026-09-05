#!/usr/bin/env bash
# AC-0b — the two surfaces 008 promised not to touch, mechanically enforced.
#
#   N-1: `RecknZkEscrow.sol` is not modified. Not one byte, in any state.
#   N-3: `reexec-evm`'s production API — everything above the testkit `cfg`
#        line — is not modified either. It is the oracle INV-1 compares the
#        guest against, so a silent edit here would move the thing the
#        differential is measured with.
#
# Both are held against `surfaces.pinned`, a two-line text file whose values are
# literals of `docs/specs/008-verdict-domain-soundness.md` (AC-0b), measured at
# the 008 base commit. This script carries NEITHER digest in its own text (R5):
# the pin lives in one readable file so that a later task re-pinning it (003,
# §1.3) lands as a one-line diff a reviewer can read.
#
# Prefix rule, stated as a command because "above the line" is ambiguous:
#   lines 1..=710, i.e. `head -710 | shasum -a 256`; line 711 is EXCLUDED.
# Line 711 must still be the `#[cfg]` marker and must be its only occurrence —
# without that, inserting a line above 711 would shift the boundary and the
# digest would silently cover a different range.
#
# witness= is the first 8 bytes of sha256 over this row's witness set (§6.2):
#   sha256(RecknZkEscrow.sol) ‖ sha256(head -710 reexec-evm/src/lib.rs),
# the two digests as raw bytes, in that order.
#
# Run: bash zk-verdict/scripts/surfaces.sh   (exit 0 = neither surface moved)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)          # …/zk-verdict/scripts
root=$(cd "$here/../.." && pwd)              # repository root, derived, never given

pinfile="$root/zk-verdict/scripts/surfaces.pinned"
escrow="$root/zk-verdict/contracts/src/RecknZkEscrow.sol"
oracle="$root/reexec-evm/src/lib.rs"
marker='#[cfg(any(test, feature = "testkit"))]'

for f in "$pinfile" "$escrow" "$oracle"; do
  [[ -f "$f" ]] || { echo "missing $f"; exit 2; }
done

digest_of()  { shasum -a 256 "$1" | cut -d' ' -f1; }
pin_for()    { awk -v n="$1" '$1==n {print $2; found=1} END{exit !found}' "$pinfile"; }
# One failure line per clause, machine-checkable, full 64-hex digests (R6).
report() { printf '%s   pinned: %s   computed: %s\n' "$1" "$2" "$3"; }

fail=0

# Clause 1 — the escrow itself. `no-keys.sh` would catch an added key; this
# catches a changed `transferFrom`, a changed event, a changed require, a comment.
escrow_pinned=$(pin_for RecknZkEscrow.sol) || { echo "surfaces.pinned has no RecknZkEscrow.sol row"; exit 2; }
escrow_computed=$(digest_of "$escrow")
if [[ "$escrow_computed" != "$escrow_pinned" ]]; then
  report RecknZkEscrow.sol "$escrow_pinned" "$escrow_computed"
  fail=1
fi

# Clause 2 — the production prefix, and the boundary the prefix is measured from.
oracle_pinned=$(pin_for reexec-evm-prefix-710) || { echo "surfaces.pinned has no reexec-evm-prefix-710 row"; exit 2; }
oracle_computed=$(head -710 "$oracle" | shasum -a 256 | cut -d' ' -f1)

marker_count=$(grep -Fxc -- "$marker" "$oracle" || true)
line711=$(sed -n '711p' "$oracle")
if [[ "$line711" != "$marker" ]]; then
  echo "reexec-evm/src/lib.rs:711 is no longer the testkit cfg marker: $line711"
  report reexec-evm-prefix-710 "$oracle_pinned" "$oracle_computed"
  fail=1
elif [[ "$marker_count" != "1" ]]; then
  echo "reexec-evm/src/lib.rs has $marker_count occurrences of the testkit cfg marker; exactly 1 is required"
  report reexec-evm-prefix-710 "$oracle_pinned" "$oracle_computed"
  fail=1
elif [[ "$oracle_computed" != "$oracle_pinned" ]]; then
  report reexec-evm-prefix-710 "$oracle_pinned" "$oracle_computed"
  fail=1
fi

[[ $fail -eq 0 ]] || exit 1

witness=$(printf '%s%s' "$escrow_computed" "$oracle_computed" \
          | xxd -r -p | shasum -a 256 | cut -c1-16)
echo "surfaces: RecknZkEscrow.sol unchanged; reexec-evm production prefix unchanged; witness=$witness"
