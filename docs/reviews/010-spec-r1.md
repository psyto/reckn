# Review 010 spec round 1

Payload: `/tmp/reckn-payload-010-spec-r1.md`
Codex raw: `/tmp/reckn-codex-010-spec-r1.md`

Target: `docs/specs/010-svm-token-replay.md` (524 lines, round 0, never reviewed).
Codex invocations this round: **1** (`-s read-only`). The document under review was written by a
Claude agent, so author independence holds: Codex is an independent reviewer here, not the author.

Tree state: clean and still at review time (`git status --porcelain` empty, no mutation run in
progress), so the `reexec-svm/` reads below are trustworthy. `ac008.sh --all` / `ac009.sh --all`
were **not** run (they patch tracked sources and take ~75 min); nothing in this review depends on
them.

## Findings

1. **[BLOCKER] `docs/specs/010-svm-token-replay.md:232` (INV-2), with `:209`–`:212` (the
   `TokenAmountDelta` fields) and `:247`–`:260` (§5.4, which calls itself 「全列挙」)** — **three
   of the six funded predicate fields never constrain the verdict.** INV-2 is written entirely as
   a *prestate-vs-poststate* comparison — *"`pre` と `post` は同じ pubkey の、同じ mint・同じ
   owner・同じ data 長 165 の account から読む"* — so it fixes that the measured account did not
   change identity during replay. **Nothing requires the account's actual `mint`, actual `owner`,
   or the committed mint's `decimals` to equal the `mint` / `owner` / `decimals` the buyer wrote
   into the predicate at funding.** §5.1's comments state the intent in prose
   (*"その account が保持していなければならない mint"*, *"committed prestate の mint から取った値と
   一致しなければならない"*) but no invariant, no row of the §5.4 complete enumeration (`:249`–`:260`), no AC in
   §7 and no mutant in §8.2 turns that prose into a check. This is the exact defect class the
   payload asked about: the fields *exist*, and say nothing.

   Consequence: a buyer funds *"≥ 1 unit of mint M2 into account X"*, the seller delivers a
   transfer of a worthless mint M1 that account X happens to hold at prestate, and the replay
   returns `Reproduced`. The predicate's own terms were not adjudicated.

   *repro (the conforming implementation that is wrong):* implement `TokenAmountDelta` reading
   only `token_account`, assert `pre`/`post` mint+owner+len agree with **each other**, and compute
   the delta at offset `64..72`. Every one of AC-1..AC-8 passes, because every AC's fixture builds
   the predicate from the same account it measures. *Test that catches it:* three vectors that keep
   the transaction and snapshot fixed and perturb only the predicate —
   `predicate.mint != account.mint[0..32]`, `predicate.owner != account.owner[32..64]`,
   `predicate.decimals != mint.data[44]` — each required to return an `OperationalError`
   (not a verdict), plus a mutant `M-9` that deletes the predicate/account agreement check and is
   attributed to those vectors in the AC-9 table.

2. **[BLOCKER] `docs/specs/010-svm-token-replay.md:242`–`:245` (INV-6 / INV-7), `:335`–`:337`
   (AC-2) and `:357`–`:359` (AC-8)** — **the pinned ELF is not the ELF that executes, so the whole pin is
   ceremony.** The spec's own §2 row at `:99` records that seeding skips executable accounts
   (`reexec-svm/src/lib.rs:496`–`:503`, *"Avoid populating an ambient cache from unused executable
   accounts"*), and D-1 changes **only** the refusal at `reexec-svm/src/lib.rs:485`. Under that
   change, `derive_program_images` (`:331`) extracts the ELF from the snapshot and compares its
   `sha256` to the pin, the seeding loop then **skips that same account**, and the VM resolves
   `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA` from LiteSVM's own bundled image:
   `LiteSVM::new()` (`reexec-svm/src/lib.rs:491`) → `into_basic()`
   (`reexec-svm/vendor/litesvm/crates/litesvm/src/lib.rs:517`, which calls
   `with_mainnet_features()` **and** `with_default_programs()`) →
   `load_default_programs` (`reexec-svm/vendor/litesvm/crates/litesvm/src/programs/mod.rs:10`).
   The fact was already written down in the file D-1 edits: `reexec-svm/src/lib.rs:271` reads
   *"`LiteSVM::new()` also preloads several SPL programs"*. The spec quotes the neighbouring
   ambient-allowlist rule (`:275`, INV-7) and does not carry that comment's consequence into
   §5.3 or §7.
   `MAINNET_ACTIVE_FEATURES` contains `replace_spl_token_with_p_token::ID`
   (`.../src/features.rs:230`), so the branch taken is the **first** one (`mod.rs:17`–`:22`):
   Tokenkeg is preloaded from **`elf/pinocchio_token_program.so` under
   `bpf_loader_upgradeable`** — not `spl_token-3.5.0.so`, and not the legacy loader.

   So the design as written produces the precise failure §1 says it avoids. §1's justification for
   not touching the guest is *"off-chain replay は committed prestate から取り出した本物の ELF を
   LiteSVM で走らせるので、この divergence を一枚目では作らない"* — **false as specified**: what
   runs is a *different implementation* of SPL Token (p-token), which is the same
   "two implementations, equivalence unverified" hazard `AGENTS.md` §5 already discloses for
   precompiles, relocated onto the fund movement itself. It also falsifies §6.3 reason 1 (legacy
   loader ⇒ ELF is the program account's `data`) as a statement about what LiteSVM executes, and
   it makes §4.1's *"ELF は program account の `data` そのもの"* true of the pin and false of the run.

   AC-2 and AC-8 do not catch it, and are themselves mis-specified in ways that would be
   "fixed" by loosening the assertion:
   - **AC-2's repro is unreachable as written.** Placing a 1-byte-different ELF in the snapshot
     changes `snapshot_commitment` (`reexec-svm/src/lib.rs:298`, which hashes `account.data` for
     **every** account including executables), so `replay` returns
     `PrestateCommitmentMismatch` at `:419` **before** reaching the image check at `:481`. The
     existing test `tampered_program_image_is_bound_by_snapshot_commitment`
     (`reexec-svm/src/lib.rs:1177`) asserts exactly that today. AC-2 can only reach
     `ProgramImageMismatch` if the anchor is **rebuilt from** the tampered snapshot — i.e. the
     pin's real job is to stop a *buyer-chosen* anchor from adjudicating against a fake Token
     program, not to stop snapshot tampering. §6.1 A-1's premise (*"compact prestate では
     bank_hash が account 集合を縛らない、したがって別の ELF を置ける"*) is wrong about which
     mechanism binds, even though its conclusion (address-only pin is insufficient) is right.
   - **AC-8 names the wrong error.** With a new profile and an old anchor,
     `replay` checks `runtime_profile_hash` first (`:411`) and returns
     **`RuntimeProfileMismatch`**, never `PrestateCommitmentMismatch` (`:419`).
   - Neither AC establishes that the pinned bytes **control the VM**, which is the only thing
     INV-6's *"pin を1つ足すことは anchor を変えること"* is worth saying.

   On the author's own INV-6 doubt (payload §4.1): **as written INV-6 is true but vacuous, and
   INV-5 at `:240`–`:241` is false.** The pin set does enter `runtime_profile_hash` and therefore
   `snapshot_commitment` (`:302`, `:318`) — that part holds. But INV-5 claims the verdict is
   invariant under LiteSVM's clock/slot/**CU** settings, and §6.2 A-11 admits CU is not hashed;
   worse, the **feature set** is not hashed either, and it selects *which of two different token
   program implementations answers at Tokenkeg*. AC-8 tests only that adding a pin changes a hash,
   which is a property of `Sha256`, not of the replay. §12 L-2 records where the pinned 32 bytes
   came from; it does not say those bytes ran, which is the gap (payload §4.2: L-2 sits next to
   the gap, it does not cover it).

   *repro:* implement D-1 exactly as specified (replace `:485`, keep the executable skip at `:501`, pin the
   legacy SPL Token ELF) and run a `TransferChecked`. It reproduces — executed by
   `pinocchio_token_program.so`. Now pin a `sha256` of **any** byte string and place that byte
   string in the snapshot's Tokenkeg account with a consistently rebuilt anchor: it still
   reproduces, because the snapshot bytes are never loaded. *Test that catches it:* after seeding
   and before `send_transaction`, read the program account back out of the VM and assert its
   `data`/loader `owner` equal the derived image and its loader byte-for-byte; and a vector that
   pins a deliberately non-functional ELF and requires the transaction to **fail**. Then either
   bind the LiteSVM feature set (and CU) into `runtime_profile_hash`, or delete the CU clause from
   INV-5 and downgrade INV-6 to what it actually gives.

3. **[MAJOR] `docs/specs/010-svm-token-replay.md:391` (mutant M-5)** — **M-5 is attributed to a
   test case that does not exist.** The row reads *"authority == owner 検査を削る | AC-1 の負側
   （delegate case）"*, but AC-1's negatives (`:330`–`:332`) are exactly three — ATA program,
   Clock sysvar, unrelated token account — and none is a delegate. §8.3's six layout negatives
   (`:402`–`:404`) include **multisig** authority, not a plain delegate. So the attack the spec
   itself names as A-3 (`:277`, *"delegate による第三者送金 … seller でない誰かの行為で
   `Reproduced` になる"*) and the rule it writes in §4.1 (`authority` == owner field 32..64) have
   **no vector anywhere in §8**. AC-9 (`:360`–`:363`) requires each mutant id to be attributed to
   a detecting test by name; M-5 has no such test, so the gate goes red for a reason the table
   mislabels, or the implementer attributes M-5 to an unrelated failure. This is the failure
   pattern `CLAUDE.md` records as having killed twice: a correct sentence with a list of names
   sitting under it.

   *repro / missing test:* a 5-account `TransferChecked` (§4.3, so the account set is unchanged)
   where the source account's `owner` (32..64) is `A`, its `delegate` COption (72..108) is set to
   signer `D`, `delegated_amount` (121..129) `>= amount`, and `D` is the sole signer and fee payer.
   SPL Token accepts it, the destination delta lands in `[min,max]`, and with the owner-equality
   check removed the verdict is `Reproduced`. Required: `OperationalError::UnsupportedAuthority`
   (`:256`), asserted as an operational error and not a verdict, listed in §8.3 (making it 7
   layout negatives), and named in the M-5 row.

## Rejected findings

None. All three findings Codex returned were confirmed against the files and kept; two were
sharpened with evidence Codex did not have (see below).

Sharpenings added during adjudication, each verified:

- Finding 2, which Codex stated as "LiteSVM preloads Tokenkeg from `elf/spl_token-3.5.0.so`
  (`programs/mod.rs:24-29`)": **the branch actually taken is the other one.** `LiteSVM::new()`
  activates `MAINNET_ACTIVE_FEATURES`, which includes `replace_spl_token_with_p_token::ID`
  (`reexec-svm/vendor/litesvm/crates/litesvm/src/features.rs:230`), so
  `programs/mod.rs:17`–`:22` loads **`pinocchio_token_program.so` under
  `bpf_loader_upgradeable`**. Both ELFs are present on disk
  (`reexec-svm/vendor/litesvm/crates/litesvm/src/programs/elf/`). This makes the finding worse,
  not better: the executing program is a reimplementation, and the loader is not the legacy one
  §6.3 reasons about.
- Finding 2: AC-2's repro is unreachable because `snapshot_commitment` already binds executable
  `data` (`reexec-svm/src/lib.rs:298`–`:326`) and the existing test at `:1177` proves the error is
  `PrestateCommitmentMismatch`; and AC-8 asserts `PrestateCommitmentMismatch` where the control
  flow at `:411` produces `RuntimeProfileMismatch`. Folded into finding 2 rather than numbered
  separately, to hold the 3-finding cap.

Checked and **not** raised as findings:

- **§0's kickoff constraint is sound, and correctly derived.** `docs/cwf-2026/RULES.md` §1 quotes
  *"products are judged only on the work completed between the competition's start and end
  dates"*, and RULES.md §1.1 already states the organiser also says *"There's no need to wait"*.
  §0's instruction (do not write P1's first line before 2026-09-14 20:00 JST) is therefore a
  founder-chosen constraint that follows from the *judging* rule, not a prohibition the rule
  imposes — §0 says exactly that (*"主催者は「今すぐ始めてよい」とも書いている"*). No
  misstatement. Codex reached the same reading.
- **The tier discipline is load-bearing, not decorative.** §9 P0's completion definition names the
  resolver path on the same screen and forbids *"proof で決済した"*; §9's closing sentence, §12 L-6
  and §13 OQ-1 each block the P0-devnet-evidence-for-P1 substitution independently. Nothing in
  the document claims a LiteSVM result at devnet tier or a resolver settlement as proof-only.
  §4.0's measured values are attributed to a named crate version on a named date, and §0's
  toolchain versions and `30 passed` / `10 passed` test counts are stated as measurements of the
  starting point, not as results of 010.
- **"No code exists yet"** — excluded by the payload as a finding, and Codex did not raise it.

## Deferred

None. All three findings are inside 010's own scope: two are corrections to the spec's
invariants/ACs, one adds a test vector the spec's own §6.1 A-3 already demands. Finding 2's
"bind the feature set into `runtime_profile_hash`" option overlaps §13 OQ-2 (CU), which remains a
founder question — but the finding can also be closed by **weakening INV-5/INV-6 to what the
design gives**, so it does not require OQ-2 to be answered first and is not deferred.

## Note for the implementer

Spec review for 010 is **one round, hard stop**. These three findings are fixed by `reckn-spec`
(Claude) in the spec, the spec is then frozen, and 010 is **not** re-reviewed at stage=spec. Only
a new, reproducible BLOCKER against the central claim reopens it, with founder approval.
Implementation remains gated: **P1's first line is not written before 2026-09-14 20:00 JST**
(§0), and `bash scripts/cwf-baseline.sh --write` records the boundary commit first.

VERDICT: CHANGES
