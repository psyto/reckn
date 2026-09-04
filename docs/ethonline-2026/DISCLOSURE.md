# Pre-existing work disclosure — Reckn (ETHOnline 2026, Continuity: Ship a Feature)

*Send to the ETHGlobal team before/at the start of hacking, and reproduce in full in the
submission description. Required by <https://ethglobal.com/rules>.*

---

**Project:** Reckn — escrow for agent-to-agent payments where the dispute adjudicator is
deterministic re-execution, not a trusted judge.

**Repository:** `github.com/psyto/reckn`

**Track:** Continuity — *Ship a Feature*

**Team:** Hiroyuki Saito (solo)

## 1. This project has never been submitted to any hackathon

Reckn was built in July–August 2026 and was **never submitted anywhere** — not to an
ETHGlobal event, not elsewhere. A submission kit (`SUBMISSION.md`) was drafted but its
pre-flight items "Repo public" and "Submission form" were never completed. The
repository was **private until 2026-09-04**, when it was made public so that this
application could be reviewed against the actual source. It has received no prize, no
judging, and no public showcase.

## 2. What exists before the event (built 2026-07-26 → 2026-08-02)

93 commits on `master` plus ~20 feature branches, all authored before ETHOnline begins.
Full history is preserved in the repository and is available for inspection.

Pre-existing components:

- **`contracts/`** — `RecknEscrow` (optimistic settlement: bonded resolver, challenge
  window, resolver quorum, slashing, seller data-availability bond). 57 tests.
- **`reexec-evm/`**, **`reexec-svm/`** — deterministic re-execution engines with four
  predicate forms. 16 + 30 tests.
- **`zk-verdict/`** — the keyless path. Three SP1 zkVM guests (`program/`,
  `program-revm/`, `program-svm/`) committing identical public values to one on-chain
  verifier; `RecknZkEscrow`, which settles escrow on a verified Groth16 proof with no
  resolver. 12 tests, including a real Groth16 proof settling to the seller on-chain.
- **`keeper/`, `reckn-svm-keeper/`, `binder/`, `escrow-svm/`, `dashboard/`** — keepers,
  the LLM-judge-vs-replay money-shot dashboard, and a 35-second demo video.
- ERC-8004 reputation projection and x402 / EIP-3009 payment plumbing.

Total: ~140 tests. **All of the above is pre-existing and is not offered as work done
during ETHOnline.**

**Also pre-existing (added 2026-09-03, before the event begins):** an autonomous development
harness (`AGENTS.md`, `CLAUDE.md`, `.claude/agents/`, `scripts/no-keys.sh`) and the planning
documents in `docs/ethonline-2026/`. These are tooling and planning, not product features, and
none of the five items in section 3 is implemented by them. They are disclosed here so that the
repository history before 2026-09-04 is fully accounted for.

## 3. What will be built during the event (2026-09-04 → submission)

1. **Keyless timeout for `RecknZkEscrow`.** The keyless escrow currently has no deadline:
   if no proof is ever produced, funds lock permanently. A permissionless, deadline-based
   refund closes this without reintroducing any privileged key.
2. **Adversarial key gauntlet.** A test suite and UI that publish every participant's
   private key and demonstrate that no key can move a funded escrow.
3. **Live adversarial dispute input.** Open the seller's delivery claim to free-form input
   so any observer can attempt to persuade the LLM judge, and watch re-execution disagree.
4. **Real ERC-20 workload.** Extend the in-guest re-execution from the current single-slot
   SSTORE fixture to a real token-credit predicate, with measured cycle counts.
5. **Sponsor integrations (new):** an x402-gated service hosted on Hedera; USDC escrow
   deployed on Arc; World AgentKit gating who may open a dispute.

## 4. How the boundary is enforced

- All event work lands in commits dated within the event window, pushed continuously — no
  single squashed commit.
- Event work is confined to identifiable paths and is summarized in a `CHANGELOG` entry
  that names the pre-event baseline commit.
- All new parts remain open source, permanently.

## 5. Honest limits of the pre-existing engine

Carried verbatim from `zk-verdict/README.md` so nothing is overstated: the `c-kzg` and
`ecrecover` precompiles are disabled in-guest; verdict values map to `u64`; the guest
proves one CALL plus one delta check (a full block or arbitrary contract set is more
cycles, same architecture); and the `state_root`-to-block-header binding remains an
off-chain layer.
