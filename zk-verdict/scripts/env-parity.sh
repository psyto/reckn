#!/usr/bin/env bash
# AC-6 — no truncation survives, and the two engines' constants are pinned by text.
#
# The defect 008 exists to close was a narrowing conversion: the guest judged on
# limb 0 of a U256 while the off-chain engine judged on the whole word, so a
# decrease could be proven as the largest possible credit. Tests prove the
# behaviour; this proves the CONSTRUCT is absent from the source, which is the
# thing a later edit would reintroduce by accident.
#
# Four checks, all greps. No build, so it is cheap enough to be the canary's target.
#
# Location rule, as in surfaces.sh: root from this file's own path, nothing else.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)

guest="$root/zk-verdict/program-revm/src/main.rs"
libsrc="$root/zk-verdict/lib/src/lib.rs"
script_lib="$root/zk-verdict/script/src/lib.rs"
oracle="$root/reexec-evm/src/lib.rs"
for f in "$guest" "$libsrc" "$script_lib" "$oracle"; do
  [[ -f "$f" ]] || { echo "missing $f"; exit 2; }
done

# `sed file | grep -q` looks right and is not: grep -q exits on the first match,
# sed takes SIGPIPE on a large file, and `set -o pipefail` then reports the pipeline
# as failed. So every stripped file is read into a variable first, and nothing here
# greps through a pipe. (Measured: this produced a false "CFG MISSING" on
# reexec-evm/src/lib.rs — 1100 lines — while passing on the shorter guest.)
strip() { sed -e 's://.*::' -e 's:/\*.*\*/::' "$1"; }
fail=0
note() { printf '  %s\n' "$*"; }

# 1. No narrowing conversion anywhere on the EVM guest path.
patterns=('as_limbs' 'u64_low' ' as u64' '.to::<u64>()' 'try_into')
absent=0
for pat in "${patterns[@]}"; do
  hit=0
  for f in "$guest" "$libsrc" "$script_lib"; do
    body=$(strip "$f")
    if printf '%s\n' "$body" | grep -cF -- "$pat" | grep -qv '^0$'; then
      note "TRUNCATION     '$pat' in ${f#$root/}"; hit=1
    fi
  done
  [[ $hit -eq 1 ]] && fail=1 || absent=$((absent + 1))
done

# 2. The two cfg flags are set on BOTH sides. A guest that disables one and an
#    engine that does not are two different EVMs.
flags=0
for flag in 'disable_base_fee = true' 'disable_nonce_check = true'; do
  for f in "$guest" "$oracle"; do
    body=$(strip "$f")
    n=$(printf '%s\n' "$body" | grep -cF -- "$flag" || true)
    if [[ "$n" != "0" ]]; then
      flags=$((flags + 1))
    else
      note "CFG MISSING    '$flag' absent from ${f#$root/}"; fail=1
    fi
  done
done

# 3. `to_guest_input` destructures exhaustively. A rest pattern makes adding a field
#    to EvmAnchorV1 silent instead of a compile error.
rest=$(awk '/fn to_guest_input/{f=1} f{print} f&&/^}/{exit}' "$script_lib" \
       | sed -e 's://.*::' | grep -cF '..' || true)
if [[ "$rest" != "0" ]]; then
  note "REST PATTERN   $rest '..' in to_guest_input — the destructure is no longer exhaustive"
  fail=1
fi

# 4. The two TxEnv literals set the same fields.
txenv_fields() {
  awk '/TxEnv \{/{f=1} f{print} f&&/\}/{if (++n) exit}' "$1" \
    | grep -oE '^[[:space:]]*[a-z_][a-z0-9_]*:' | tr -d ' :' | LC_ALL=C sort -u
}
want_fields=$(printf '%s\n' caller chain_id data gas_limit gas_price kind value | LC_ALL=C sort -u)
n_fields=0
for f in "$oracle" "$guest"; do
  got=$(txenv_fields "$f")
  if [[ "$got" != "$want_fields" ]]; then
    note "TXENV FIELDS   ${f#$root/} sets [$(echo $got)], not the pinned 7"
    fail=1
  else
    n_fields=7
  fi
  lit=$(awk '/TxEnv \{/{f=1} f{print} f&&/\}/{if (++n) exit}' "$f")
  if [[ "$(printf '%s\n' "$lit" | grep -cF '..Default::default()' || true)" == "0" ]]; then
    note "TXENV DEFAULT  ${f#$root/}'s TxEnv literal does not end with ..Default::default()"
    fail=1
  fi
done

witness=$(cat "$guest" "$libsrc" "$script_lib" "$oracle" | shasum -a 256 | cut -c1-16)
echo "env-parity: $absent/5 truncation patterns absent; $flags/4 cfg flags pinned on both sides; $rest rest patterns in to_guest_input; TxEnv fields identical ($n_fields); witness=$witness"
[[ $fail -eq 0 ]] || exit 1
