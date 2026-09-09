# Repository layout

*Moved out of `README.md` on 2026-09-08. It is reference, not argument.*

```text
AGENTS.md                   # harness rules, day-work discipline, stop conditions
CLAUDE.md                   # orientation: the central claim, verified facts, environment
STATUS.md                   # where the event stands (EVENT_START, gates, freeze)
SUBMISSION.md               # pitch surface: submission copy, demo-video script, checklist
scripts/
  no-keys.sh                # BUILD CONDITION: no key can judge (exit 0 = claim holds)
  anvil-e2e.sh              # one-command live dispute on a throwaway local chain
  arc-usdc-e2e.sh           # one-command conditional USDC payment, Arc-shaped chain
docs/
  ethonline-2026/           # PLAN.md + DISCLOSURE.md (founder documents)
  specs/ reviews/ tasks/    # per-task spec → review → impl records (event work)
  protocol-architecture.md  # converged EVM-first protocol (the source of truth)
  roadmap-crossvm.md        # EVM → Solana → cross-VM extension roadmap
  x402-payments.md          # how a buyer agent's x402/EIP-3009 payment funds the escrow
  architecture-brief.md     # original frame-thick task brief (historical)
contracts/                  # EVM V1 settlement half (Foundry) — implemented
  src/RecknEscrow.sol       #   four-state escrow + timeout escape hatches
  src/ResolverRegistry.sol  #   resolver keys + exact backend/version allow-list
  src/libraries/VerdictHash.sol
  src/interfaces/IUSDC3009.sol
  test/                     #   forge tests
reexec-evm/                 # EVM re-execution backend (revm 38) — implemented
  src/lib.rs                #   deterministic CALL replay + predicate verdict
                            #   (testkit feature: valid MPT witness fixtures, cfg-gated)
  examples/moneyshot.rs     #   emits real engine output for the dashboard
reckn-evm-content/          # shared canonical EVM content codec — implemented
  src/lib.rs                #   the keeper's & binder adapter's ONE decoder (no drift)
reexec-svm/                 # Solana re-execution backend (LiteSVM) — implemented
  src/lib.rs                #   deterministic tx replay → the SAME ReplayRecordV1
escrow-svm/                 # Solana settlement half (Pinocchio) — implemented
  src/lib.rs                #   4-state escrow; Ed25519-attested resolve; timeout
  tests/e2e.rs             #   LiteSVM tx-level e2e
reckn-svm-keeper/           # Solana keeper: replay -> Ed25519-sign -> resolve
  src/lib.rs                #   + keyless verify
  tests/full_loop.rs        #   fund->challenge->keeper->resolve->verify (LiteSVM)
binder/                     # cross-VM binder — one router, both VMs (reckn-binder)
  src/lib.rs                #   route a dispute by committed backendId -> verdict
  src/adapters.rs           #   EvmBackend + SvmBackend (content-addressed replay)
  tests/router_two_vms.rs   #   one router re-executes EVM + SVM, fails closed
packages/protocol/          # canonical cross-VM codecs (specs + golden vectors)
  REPLAY_RECORD_V1.md       #   ReplayRecordV1 TLV spec (trace_hash source)
  golden/                   #   cross-language conformance vectors
packages/protocol-rs/       # reckn-record: the shared Rust record codec both
                            #   backends emit, so EVM and SVM trace hashes match
zk-verdict/                 # the keyless path — independent SP1 workspace
  program-revm/             #   guest: MPT-verify prestate, run real revm under proof
  program-svm/              #   guest: recompute bank_hash, sigverify, re-execute transfer
  contracts/src/RecknZkEscrow.sol      # settles on the proof alone — no resolver
  contracts/src/RecknVerdictVerifier.sol # one generic verifier, EVM + SVM proofs
  script/tests/             #   the 008 vectors: value domain, engine identity, binding
  contracts/test/RecknCrossVmSettlement.t.sol # one escrow, an EVM proof and an SVM proof
  cycles.json               #   measured cycle counts + ELF digests (no rounded figures)
  scripts/zk-e2e.sh         #   one command: re-execute → prove → verify → settle
  scripts/ac005.sh          #   the 005 acceptance gate: 4 rows, USDC units and semantics
  scripts/ac008.sh          #   the 008 acceptance gate: one runner, 18 manifest rows
  scripts/ac009.sh          #   the 009 acceptance gate: 13 rows, cross-VM settlement
  scripts/ac011.sh          #   the 011 acceptance gate: 8 rows, the Tempo slice — half
                            #   of them read the live chain, so a network failure is a
                            #   FAILURE and not a skip
  scripts/both-green.sh     #   runs every SIBLING gate it discovers by pattern — the
                            #   only row that tests "green at the same time"
  scripts/arc-receipts.sh   #   every arcscan link names a settlement arc.json records,
                            #   and every settlement it records is linked somewhere
  scripts/arc-constants.sh  #   chain id, Arc URLs and the USDC predeploy match the record
  scripts/tempo-verify.sh   #   reads the Tempo deployment back off the chain and
                            #   re-derives every outcome from receipts — deal ids out of
                            #   the Funded events, never from a terminal
  scripts/tempo-arc-parity.sh #  the same escrow bytecode on Arc AND on Tempo, fetched
                            #   from both chains; fails if the escrow ever gains a
                            #   constructor, which is what makes the equality mean
                            #   "same source" rather than "same configuration"
  scripts/tempo-receipts.sh #   every recorded hash exists on chain with the status the
                            #   record claims — including the one that FAILED
  scripts/tempo-constants.sh #  Tempo's constants match the record, and the endpoint that
                            #   answers 4217 — Tempo MAINNET — appears nowhere as an endpoint
  scripts/tempo-page-check.sh #  runs docs/tempo.html's own JavaScript against Tempo and
                            #   fails if what it renders is not true
  contracts/script/DeployTempo.s.sol # the same keyless path to Tempo, escrow unchanged
  contracts/test/RecknTempoTip20.t.sol # TIP-20 settlement, pause and policy failure paths
  contracts/tempo.json      #   Tempo's constants and receipts, each with how it was read
  scripts/escrow-shape.sh   #   the escrow's shape, closed by ten properties
  scripts/both-green.sh     #   sibling gates, discovered by closure and actually run
  scripts/mutants/          #   36 mutation patches: 21 for 008, 15 for 009
  contracts/script/DeployArc.s.sol # deploy the keyless path to Arc (no admin to hold)
  contracts/test/RecknArcUsdcSettlement.t.sol # USDC settlement, real Groth16 proofs
  contracts/arc.json        #   Arc's constants, transcribed with source and date
  scripts/surfaces.sh       #   BUILD CONDITION: the two files 008 promised not to touch
  scripts/surfaces.pinned   #   their pinned digests, re-pinned only as a readable diff
dashboard/                  # LLM-judge vs replay money-shot — implemented
  arc.html                  #   Arc: a USDC payment released by a proof (measured run)
  index.html                #   cinematic money-shot: money moves, live keeper
                            #   console + ledger, on-chain resolve receipt
  variants/                 #   design exploration (v1–v5); v5 is promoted above
  media/reckn-moneyshot.gif #   README hero animation
  media/reckn-demo-full.mp4 #   full demo: money-shot + live anvil-e2e terminal run
  media/reckn-demo.mp4      #   dashboard-only clip; media/reckn-e2e.mp4 = terminal clip
keeper/                     # resolver keeper — replay, EIP-712 signature, live chain shell
  src/lib.rs                #   verified core: build + EIP-712-sign VerdictCommitment
  src/main.rs               #   live shell: once/watch (resolve) + verify (keyless recheck)
```

Planned (not yet in the tree): `mcp-server` and the rest of
`packages/protocol`'s production spec/delivery/anchor codecs. See the module map in
[`docs/protocol-architecture.md`](protocol-architecture.md).
