#!/usr/bin/env bash
# AC-9 — the committed fixtures are the CURRENT guests'.
#
# Every on-chain test builds its verifier from the fixture's OWN vkey, so a guest
# that changed without its fixture being regenerated passes all of them. This is the
# only check that ties the committed proofs to the ELF in the tree.
#
# Per fixture: (1) the current ELF's vkey must equal the fixture's; (2) re-running
# the guest on the fixture's declared inputs must commit byte-identical public
# values; (3) the four numeric fields must be 32-byte 0x hex strings, not JSON
# numbers — `max_delta` as the integer 18446744073709551615 becomes
# 18446744073709552000 in any double-based reader, and a U256 cannot survive a JSON
# number at all.
#
# alt-binding.json is regenerated here too (AC-7b), but as a COMPARISON against a
# temporary copy rather than an overwrite: a check that rewrites the artefact it is
# checking cannot fail.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
fixtures="$root/zk-verdict/contracts/src/fixtures"
script_dir="$root/zk-verdict/script"

current=0
want=4
fail=0
note() { printf '  %s\n' "$*"; }
hex2dec() { python3 -c "import sys;print(int(sys.argv[1],16))" "$1"; }

# (3) shape first: a fixture whose numbers are JSON integers cannot be compared at all.
shape_ok() {
  local f=$1 name field val
  name=$(basename "$f")
  for field in pre post min_delta max_delta; do
    val=$(jq -r ".$field | tostring" "$f")
    if ! printf '%s' "$val" | grep -qE '^0x[0-9a-f]{64}$'; then
      note "SHAPE          $name: .$field is '$val', not a 32-byte 0x hex string"
      return 1
    fi
  done
  return 0
}

check_one() {
  local name=$1; shift
  local f="$fixtures/$name"
  [[ -f "$f" ]] || { note "MISSING        $name"; fail=1; return; }
  shape_ok "$f" || { fail=1; return; }

  local out
  if ! out=$( (cd "$script_dir" && cargo run --release --quiet "$@") 2>/dev/null ); then
    note "EXECUTE FAILED $name: the guest did not run"; fail=1; return
  fi
  local got_vkey got_values want_vkey want_values
  got_vkey=$(printf '%s\n' "$out" | sed -n 's/^vkey: //p' | tail -1)
  got_values=$(printf '%s\n' "$out" | sed -n 's/^public_values: //p' | tail -1)
  want_vkey=$(jq -r '.vkey' "$f")
  want_values=$(jq -r '.public_values' "$f")

  if [[ "$got_vkey" != "$want_vkey" ]]; then
    note "STALE VKEY     $name: guest is $got_vkey, fixture says $want_vkey"; fail=1; return
  fi
  if [[ "$got_values" != "$want_values" ]]; then
    note "STALE VALUES   $name: the committed public values are not this guest's"; fail=1; return
  fi
  current=$((current + 1))
}

# 1. the predicate guest
pre=$(hex2dec "$(jq -r .pre "$fixtures/groth16-fixture.json" 2>/dev/null || echo 0x0)")
post=$(hex2dec "$(jq -r .post "$fixtures/groth16-fixture.json" 2>/dev/null || echo 0x0)")
min=$(hex2dec "$(jq -r .min_delta "$fixtures/groth16-fixture.json" 2>/dev/null || echo 0x0)")
max=$(hex2dec "$(jq -r .max_delta "$fixtures/groth16-fixture.json" 2>/dev/null || echo 0x0)")
check_one groth16-fixture.json --bin evm -- --verify --pre "$pre" --post "$post" --min "$min" --max "$max"

# 2 + 3. the two re-execution fixtures (U256 inputs, passed as hex)
for name in reexec-groth16-fixture.json reexec-falserelease-fixture.json; do
  f="$fixtures/$name"
  check_one "$name" --bin reexec -- --verify \
    --pre "$(jq -r .pre "$f")" --post "$(jq -r .post "$f")" \
    --min "$(jq -r .min_delta "$f")" --max "$(jq -r .max_delta "$f")"
done

# 4. the SVM mirror: the bin takes the credited amount, which is post - pre.
svm="$fixtures/svm-groth16-fixture.json"
if [[ -f "$svm" ]] && shape_ok "$svm"; then
  amount=$(python3 -c "import sys;print(int(sys.argv[1],16)-int(sys.argv[2],16))" \
           "$(jq -r .post "$svm")" "$(jq -r .pre "$svm")")
  check_one svm-groth16-fixture.json --bin svm -- --verify --amount "$amount" --min "$(hex2dec "$(jq -r .min_delta "$svm")")"
else
  [[ -f "$svm" ]] || note "MISSING        svm-groth16-fixture.json"
  fail=1
fi

# alt-binding.json — the AC-7b artefact, compared rather than overwritten.
alt="$fixtures/alt-binding.json"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/altbind.XXXXXX")
if [[ -f "$alt" ]]; then
  headline="$fixtures/reexec-groth16-fixture.json"
  if (cd "$script_dir" && cargo run --release --quiet --bin reexec -- --alt-binding \
        --pre "$(jq -r .pre "$headline")" --post "$(jq -r .post "$headline")" \
        --min "$(jq -r .min_delta "$headline")" --max "$(jq -r .max_delta "$headline")" \
        --fixture-path "$tmp/alt-binding.json") > /dev/null 2>&1; then
    if [[ "$(jq -r .deal_binding "$tmp/alt-binding.json")" != "$(jq -r .deal_binding "$alt")" ]]; then
      note "STALE ALT      alt-binding.json is not this guest's binding"; fail=1
    fi
  else
    note "ALT FAILED     could not regenerate alt-binding.json"; fail=1
  fi
else
  note "MISSING        alt-binding.json"; fail=1
fi
rm -rf "$tmp"

# witness: the four freshly-computed vkeys, in fixture order, then the four files.
vkey_of() { (cd "$script_dir" && cargo run --release --quiet --bin "$1" -- --vkey) 2>/dev/null | sed -n 's/^vkey: //p' | tail -1; }
witness=$( { for v in "$(vkey_of evm)" "$(vkey_of reexec)" "$(vkey_of reexec)" "$(vkey_of svm)"; do
               printf '%s' "${v#0x}" | xxd -r -p
             done
             cat "$fixtures/groth16-fixture.json" "$fixtures/reexec-groth16-fixture.json" \
                 "$fixtures/reexec-falserelease-fixture.json" "$fixtures/svm-groth16-fixture.json"; } \
           | shasum -a 256 | cut -c1-16)

echo "fixtures: $current/$want current (vkey and public values byte-identical); witness=$witness"
[[ $fail -eq 0 ]] || exit 1
