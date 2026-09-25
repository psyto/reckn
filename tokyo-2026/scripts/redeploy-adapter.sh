#!/usr/bin/env bash
# redeploy-adapter — put the FIXED SettlementRecord on Sepolia and move root to it.
#
# Why a script. Three things went wrong by hand on 09-25 and all three are mechanical:
#   1. `forge create --constructor-args` swallows every flag that follows it, so the deploy
#      silently went to localhost:8545. Options come FIRST here, constructor args LAST.
#   2. A predicted address went stale when two funding transactions moved the nonce, and root
#      was granted to a ghost. Nothing here is predicted -- the address is READ back from the
#      deploy, and every later step uses that value.
#   3. The old adapter keeps its root grant unless somebody remembers to take it away. That is
#      a second admin on the surface whose whole claim is that nobody is in charge, so the
#      revoke is a step in the same run as the grant, not a note in a document.
#
# Three password prompts: deploy, grant, revoke (reckn-agent each time).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$here"
: "${SEPOLIA_RPC:?set SEPOLIA_RPC first}"
READ_RPC=${READ_RPC:-https://ethereum-sepolia-rpc.publicnode.com}

ESCROW=0x6d6a9deb67d785BC131a5d732617EABE751098C5
RESOLVER=0x740e02cE9FB52629feF861CA02DF7091f416BBF8
OLD=0x6691283d8B77E1e22D08836c55E3f952c304Ccc1
DNS=0x056167656e74057265636b6e0365746800     # agent.reckn.eth, DNS wire form
ALL=0x1111111111111111111111111111111111111111111111111111111111111111
WANT_NAME="agent.reckn.eth"

say() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
die() { printf '\n\033[31mredeploy: %s\033[0m\n' "$*" >&2; exit 1; }

# Refuse to deploy the code we are replacing. The two fixes are a guard on `close` and a name
# fixed at construction; if neither is in the source, this is the wrong tree.
grep -q 'WRITE_WINDOW' src/SettlementRecord.sol || die "src has no WRITE_WINDOW -- this is the old adapter"
grep -q 'bytes memory _dnsName' src/SettlementRecord.sol || die "src constructor takes no name -- this is the old adapter"

say "0. what is on chain right now"
printf '   old adapter %s  root=%s\n' "$OLD" \
  "$(cast call "$RESOLVER" "hasRootRoles(uint256,address)(bool)" "$ALL" "$OLD" --rpc-url "$READ_RPC")"

say "1. deploy  [reckn-agent]   -- options first, --constructor-args LAST"
OUT=$(forge create src/SettlementRecord.sol:SettlementRecord \
  --rpc-url "$SEPOLIA_RPC" --account reckn-agent --broadcast \
  --constructor-args "$ESCROW" "$RESOLVER" "$DNS")
printf '%s\n' "$OUT"

# READ the address. Never compute it.
NEW=$(printf '%s' "$OUT" | sed -n 's/^Deployed to: *//p' | tr -d '[:space:]')
[[ "$NEW" =~ ^0x[0-9a-fA-F]{40}$ ]] || die "could not read a deployed address out of forge's output"
# lowercase via tr, not ${x,,}: /bin/bash on macOS is 3.2 and does not have it
[[ "$(printf '%s' "$NEW" | tr 'A-Z' 'a-z')" != "$(printf '%s' "$OLD" | tr 'A-Z' 'a-z')" ]] \
  || die "the deploy returned the OLD address"

say "2. prove the constructor took, before handing it any power"
GOT=$(cast call "$NEW" "nameDotted()(string)" --rpc-url "$READ_RPC" | tr -d '"')
[[ "$GOT" == "$WANT_NAME" ]] || die "the adapter's name is '$GOT', expected '$WANT_NAME'"
WIN=$(cast call "$NEW" "WRITE_WINDOW()(uint64)" --rpc-url "$READ_RPC" | awk '{print $1}')
printf '   address     %s\n   nameDotted  %s\n   WRITE_WINDOW %s s\n' "$NEW" "$GOT" "$WIN"

say "3. grant root to the new adapter  [reckn-agent]"
cast send "$RESOLVER" "grantRootRoles(uint256,address)" "$ALL" "$NEW" \
  --rpc-url "$SEPOLIA_RPC" --account reckn-agent | grep -E '^(status|transactionHash)'
[[ "$(cast call "$RESOLVER" "hasRootRoles(uint256,address)(bool)" "$ALL" "$NEW" --rpc-url "$READ_RPC")" == "true" ]] \
  || die "the grant did not take"

say "4. take root away from the OLD adapter  [reckn-agent]  -- the step that gets forgotten"
cast send "$RESOLVER" "revokeRootRoles(uint256,address)" "$ALL" "$OLD" \
  --rpc-url "$SEPOLIA_RPC" --account reckn-agent | grep -E '^(status|transactionHash)'
[[ "$(cast call "$RESOLVER" "hasRootRoles(uint256,address)(bool)" "$ALL" "$OLD" --rpc-url "$READ_RPC")" == "false" ]] \
  || die "the old adapter STILL holds root"

say "5. point the join at it -- not by hand"
# The tests do not need touching: they deploy their own adapter and only pin the escrow and the
# resolver, neither of which moved. The join script is the one place the address is written
# down, and this repo's rule about receipts applies to addresses too: do not retype them.
python3 - "$NEW" <<'PYEOF'
import re, sys
new = sys.argv[1]
p = 'scripts/join-sepolia.sh'
s = open(p).read()
s2, n = re.subn(r'(?m)^ADAPTER=0x[0-9a-fA-F]{40}$', 'ADAPTER=' + new, s)
assert n == 1, f'expected exactly one ADAPTER= line, found {n}'
open(p, 'w').write(s2)
print('   scripts/join-sepolia.sh  ADAPTER=' + new)
PYEOF

say "done"
printf '   new adapter  %s\n   old adapter  %s  (root revoked)\n\n' "$NEW" "$OLD"
printf '   next, in order:\n'
printf '     1. DEAL_ID=$(cast keccak "reckn-tokyo-join-2") bash scripts/join-sepolia.sh\n'
printf '     2. shoot beat 3 from THAT run -- same run, so the frames and the ledger agree\n'
printf '     3. record the new address in ../zk-verdict/contracts/sepolia.json, then\n'
printf '        bash ../zk-verdict/scripts/sepolia-receipts.sh\n'
