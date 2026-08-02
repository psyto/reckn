#!/usr/bin/env bash
# Reckn ZK end-to-end — the trustless path, one command.
#
#   1. In-guest re-execution (live, if the SP1 toolchain is installed):
#      - EVM: MPT-verify the prestate vs state_root, run REAL revm in the zkVM,
#        derive post, apply the causal delta -> Reproduced (a no-op -> Failed).
#      - SVM: recompute bank_hash, signature-verify the real tx, re-execute the
#        System transfer -> Reproduced (a tampered prestate/sig -> rejected).
#   2. On-chain (always): a REAL Groth16 proof of that execution is verified by
#      SP1's real verifier through one generic RecknVerdictVerifier, and
#      RecknZkEscrow SETTLES the escrow to the seller on the proof alone -- no
#      resolver. Failed refunds the buyer; a wrong-binding/fake proof reverts.
#
# The step-2 proofs are committed fixtures, so this runs with just `forge`. Step 1
# needs the SP1 Rust toolchain (sp1up); it is skipped with a note if absent. Set
# ZK_FRESH=1 to regenerate a fresh Groth16 proof (needs SP1's ~6.2GB v6.1.0
# artifacts in ~/.sp1).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
zk=$(cd "$here/.." && pwd)
contracts="$zk/contracts"
script_dir="$zk/script"

say()  { printf '\n\342\226\266 %s\n' "$*"; }
note() { printf '  %s\n' "$*"; }

# --- deps: the SP1 verifier contracts (circuit v6.1.0) + forge-std --------------
ensure_contracts_deps() {
  local lib="$contracts/lib"
  mkdir -p "$lib"
  [[ -f "$lib/forge-std/src/Test.sol" ]] || \
    ( cd "$contracts" && forge install foundry-rs/forge-std --no-git >/dev/null 2>&1 )
  if [[ ! -f "$lib/sp1-contracts/contracts/src/v6.1.0/SP1VerifierGroth16.sol" ]]; then
    note "fetching sp1-contracts v6.1.0 (matches the proof circuit)…"
    rm -rf "$lib/sp1-contracts"
    git clone --depth 1 --branch v6.1.0 https://github.com/succinctlabs/sp1-contracts.git \
      "$lib/sp1-contracts" >/dev/null 2>&1
    # the SP1VerifierGateway needs OpenZeppelin (pinned v5.0.2)
    rm -rf "$lib/sp1-contracts/contracts/lib/openzeppelin-contracts"
    git clone --depth 1 --branch v5.0.2 https://github.com/openzeppelin/openzeppelin-contracts.git \
      "$lib/sp1-contracts/contracts/lib/openzeppelin-contracts" >/dev/null 2>&1
  fi
}

have_sp1() { command -v cargo-prove >/dev/null 2>&1 || command -v sp1up >/dev/null 2>&1; }

printf '\n=== Reckn ZK end-to-end — reproduce, or refund, with NO resolver ===\n'

# --- 1. live in-guest re-execution ---------------------------------------------
if have_sp1; then
  say "EVM: run real revm INSIDE the zkVM against an MPT-authenticated prestate"
  ( cd "$script_dir" && cargo run --quiet --release --bin reexec -- --execute ) \
    | grep -E 'MPT-proven|post \(EXECUTED|credited delta|verdict|cycles' || true

  say "EVM soundness: a tampered prestate value is REJECTED (bad MPT proof)"
  reason=$( cd "$script_dir" && cargo run --quiet --release --bin reexec -- --execute --tamper 2>&1 \
    | grep -ioE 'storage proof invalid[^"]*' | head -1 || true )
  note "REJECTED — ${reason:-guest panicked on the invalid prestate proof (no verdict)}"

  say "SVM: recompute bank_hash, verify the real signature, re-execute the transfer"
  ( cd "$script_dir" && cargo run --quiet --release --bin svm -- --execute ) \
    | grep -E 'bank_hash-bound|post \(EXECUTED|credited delta|verdict|cycles' || true

  say "SVM soundness: a tampered account is REJECTED (bank_hash mismatch)"
  reason=$( cd "$script_dir" && cargo run --quiet --release --bin svm -- --execute --tamper-prestate 2>&1 \
    | grep -ioE 'bank_hash authenticity' | head -1 || true )
  note "REJECTED — ${reason:-guest panicked on the bank_hash check (no verdict)}"

  if [[ "${ZK_FRESH:-0}" == "1" ]]; then
    say "Generating a FRESH Groth16 proof of the EVM re-execution (needs ~6.2GB artifacts)"
    ( cd "$script_dir" && SP1_PROVER=cpu cargo run --quiet --release --bin reexec -- --fixture ) \
      | grep -iE 'wrote fixture|vkey|outcome' || true
  fi
else
  say "SP1 toolchain not found — skipping live in-guest execution"
  note "install it with sp1up (https://docs.succinct.xyz) to watch revm/SVM run in the zkVM."
  note "The on-chain step below still runs on the committed REAL proofs."
fi

# --- 2. on-chain: verify the real proof AND settle -----------------------------
say "On-chain: the REAL Groth16 proofs verify via one generic verifier, and settle"
ensure_contracts_deps
( cd "$contracts" && forge test -vv 2>&1 ) | \
  grep -E 'RecknReexecVerdict|RecknSvmVerdict|RecknZkEscrow|real_.*verifies|reexecution_proof|settles_to_seller|refunds_buyer|Suite result|Ran .* test suites' || true

cat <<'EOF'

--- what just happened ---------------------------------------------------------
  • The disputed work was RE-EXECUTED inside a zkVM — real revm (EVM) / the real
    Solana transfer (SVM) — against a cryptographically authenticated prestate
    (MPT vs state_root / bank_hash lattice). `post` was computed under proof.
  • A real Groth16 proof of that execution was verified ON-CHAIN by SP1's real
    verifier, through ONE generic RecknVerdictVerifier — EVM and SVM alike.
  • RecknZkEscrow SETTLED the escrow on that proof alone: Reproduced -> seller,
    Failed -> buyer. No resolver, no signer allow-list, no trusted judge.
  Settlement authority = a proof that verifies. Reproduce, or refund.
EOF
