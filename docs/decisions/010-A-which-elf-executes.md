# 010-A — which ELF actually executes, and therefore what a pin can mean

**Founder decision required.** Raised by [`docs/reviews/010-spec-r1.md`](../reviews/010-spec-r1.md)
finding 1 (BLOCKER), re-verified against the tree on **2026-09-12**. It changes the wording of
D-1 in [`docs/specs/010-svm-token-replay.md`](../specs/010-svm-token-replay.md) §1, which is why it
is a decision and not a fix.

---

## 1. What is actually true today (measured, not inferred)

| fact | where |
|---|---|
| replay builds the VM with **`LiteSVM::new()`** | `reexec-svm/src/lib.rs:491` |
| `LiteSVM::new()` = `default().into_basic()`, and `into_basic()` applies `with_mainnet_features()` · `with_builtins()` · **`with_default_programs()`** · `with_sysvars()` · `with_feature_accounts()` | `vendor/litesvm/crates/litesvm/src/lib.rs:535`, `into_basic` |
| `load_default_programs` preloads **eight** programs, each with an explicit loader, via `add_program_preverified` — note *preverified* | `vendor/litesvm/.../programs/mod.rs:10`–`:66` |
| **which token program answers at `Tokenkeg…` is decided by a feature gate.** `replace_spl_token_with_p_token` is **in the active mainnet set**, so the loaded ELF is **`pinocchio_token_program.so` under `bpf_loader_upgradeable`** — *not* `spl_token-3.5.0.so` under `bpf_loader` | `features.rs:230`; `programs/mod.rs:13`–`:28` |
| snapshot seeding **skips executable accounts** | `reexec-svm/src/lib.rs:501` |
| the profile hashes the litesvm **version string** `litesvm/0.13.1/reckn-closed-world/1` — **the feature set itself is not hashed** | `:27`, `:287` |
| the existing refusal of derived images is **the containment, not an oversight** — the code says so: *"Treating those as a caller-selectable allowlist would merely move the old ambient-code trust bug into the profile. Until their account/loader state is reconstructed, the System builtin is the only permitted ambient executable."* | `:269`–`:273` |

**So D-1 as written is false in a specific way.** It relaxes the refusal at `:485` and pins
`(program_id, sha256(elf))`, but the pinned bytes never execute: an ambient, preverified,
*different implementation* of SPL Token is already sitting at that address, and the snapshot's copy
is skipped. The pin would describe something and constrain nothing.

**One correction to make in passing, because the spec leans on it:** §6.3's reason for choosing
legacy SPL Token — *"legacy loader, so the ELF is the program account's `data`"* — does not describe
what runs. What runs is under the **upgradeable** loader, which is the case §6.3 deferred.

---

## 2. A prerequisite that is in every branch

**The feature set must become an explicit, hashed input**, whichever option is chosen. It selects
*which token implementation exists*, so a profile that does not fix it is not a description of the
environment. `LiteSVM::with_feature_set(FeatureSet)` exists (`lib.rs:671`), so this is a choice, not
a limitation.

This is also the honest resolution of the review's point about **INV-5 / INV-6**: the version string
in the profile pins the feature set only *by convention* — editing the vendored `features.rs`
without touching that string moves the environment and not the hash.

**And in every branch, one acceptance criterion that §8 does not currently contain:**

> **Replace the pinned ELF with a byte-different program whose behaviour is distinguishable (one
> that transfers `amount - 1`, or always fails) and require the verdict to change.** If the verdict
> does not move, the pinned ELF is not the one executing.

That mutant — call it **M-9** — is the only thing in this document that would have caught the
blocker by itself. AC-2 as written cannot: a one-byte ELF change moves `snapshot_commitment` and
trips `PrestateCommitmentMismatch` first (`:419`), which an existing test already asserts.

---

## 3. The three options

### Option A — *declare the ambient*: hash what LiteSVM preloads

Keep `LiteSVM::new()`. Enumerate the eight preloaded `(program_id, loader, sha256(elf))` triples
into `RuntimeProfileV1`, hash them with the feature set, and let the pin describe the ambient set.

- **+** smallest change to the replay path; no ELF-loading work; the profile becomes *true*, and a
  true profile would have caught this bug.
- **−** it is **precisely what `:269` forbids**, in the words it forbids it in. The trust question —
  *is that ELF the thing it claims to be?* — is not answered, only recorded.
- **−** **D-1's derivation disappears.** There is nothing to derive from the snapshot and nothing to
  match; the "pin set" is a transcription of the vendor's bytes. The sentence *"the derived set must
  match the pins exactly"* cannot survive.
- **−** the code that decides a payment is chosen by **our build**, not by the deal. That is a
  smaller version of the shape Reckn exists to remove.

### Option B — *close the world*: don't preload, and actually run the snapshot's ELF

Construct with `LiteSVM::default()` plus the pieces we want — `with_builtins()`, `with_sysvars()`,
`with_feature_set(<pinned>)`, `with_sigverify(true)` — and **not** `with_default_programs()`. Stop
skipping executable accounts at `:501`, seed the snapshot's program account, and let the pinned
`(program_id, sha256(elf))` set be the only non-builtin code in the VM.

- **+** **D-1 becomes true as written.** The pinned bytes are the executing bytes, and §1's reason
  for not touching the guest holds again: off-chain replay runs the ELF the prestate committed to,
  so the guest/engine divergence is not created in slice one.
- **+** the feature set stops being ambient and becomes a declared input — INV-5's real hole closes
  in the same change.
- **+** **no fork.** The vendored API already supports this; `new()` is a convenience we chose.
- **−** the most work, and the only option with an **unknown**: whether litesvm's program cache will
  load a program from a *seeded account* rather than from `add_program_preverified`. Legacy loader
  makes the bytes trivially available (`data` is the ELF), but "available" is not "loaded".
  **This needs a time-boxed spike before the option can be called costed.**
- **−** does **not** fix provenance. It makes *pinned* and *executing* the same bytes; whether those
  bytes are Solana's SPL Token remains §12 L-2, unchanged.

### Option C — *re-aim the slice*: pin the preloaded implementation as the subject

Accept that slice one adjudicates the token program LiteSVM preloads. Pin
`(program_id, loader, sha256(pinocchio_token_program.so))` and the feature set; the snapshot
supplies **data accounts only**, and the claim that the code comes from the committed prestate is
**dropped rather than weakened**.

- **+** smallest total change, fully deterministic today, and testable this week.
- **+** honest if stated plainly — and it keeps the prestate's role narrow and true.
- **−** the adjudicator's code identity comes from **our build**. The disclosure has to say so in
  the same breath as any "the deal names the program" sentence, or it is misleading.
- **−** **pushes the cost into P5.** An in-guest version would have to reimplement *p-token's*
  semantics, which is the divergence §1 declined to create — so C buys two days now and owes the
  hardest part later.
- **−** §4.0's layout pins were read from `spl-token-interface 3.0.0`. p-token is a
  reimplementation *intended* to be byte-compatible. **Until that is read from a primary source it
  is an assumption, and it becomes load-bearing under C.** `[要一次資料]`

---

## 4. Comparison

| | **A** declare the ambient | **B** close the world | **C** re-aim the slice |
|---|---|---|---|
| pinned bytes are the executing bytes | **no** | **yes** | yes (of the vendor's ELF) |
| who chooses the adjudicating code | our build | **the deal** | our build |
| D-1's sentence survives | no | **yes** | no, and it is replaced |
| contradicts `:269`'s own doctrine | **yes** | no | partly — it names one ambient program instead of a set |
| feature set hashed | required anyway | required anyway | required anyway |
| new unknown | none | **program-cache loading from a seeded account** | p-token layout compatibility |
| cost to P5 (in-guest) | unchanged | **unchanged** | **higher** — guest must match p-token |
| effort | small | **large** | small |

---

## 5. Recommendation

> **Take B. Time-box the unknown to four hours, and if it does not land, ship C for slice one with
> the disclosure and keep B as the P4 path.**

Why B rather than the cheaper two: **the product's sentence is that the proof runs the code the deal
committed to.** A and C both move code identity from the deal to our build. They are not as bad as a
resolver — nobody can *choose an outcome* — but they are the same direction: someone outside the
deal decides which code decides. The spec already refused that trade once, in §1, when it declined
to hand-write token semantics into the guest; refusing it again here is consistency, not purity.

**Why the fallback is C and not A:** C drops the false claim, A keeps the claim and hollows it out.
A profile that enumerates eight vendor ELFs reads like rigour and is the thing `:269` predicted
would happen. If we cannot make the pin bind, the honest move is to stop calling it a pin.

**What to do with the four hours** — the whole unknown is one question: *does a seeded, legacy-loader
program account get compiled and executed by LiteSVM without `add_program_preverified`?*
Build the smallest possible probe: `LiteSVM::default()` with builtins and a pinned feature set, one
seeded executable account owned by `bpf_loader` whose `data` is any tiny SBF program, and one
transaction that calls it. **It either runs or it does not, and the answer decides the branch.**
Do this **after** kickoff — it is implementation, and `AGENTS.md` / §0 gate it to 2026-09-14 20:00 JST.

**What does not change under any option:** provenance stays unproven (§12 L-2), `min = 0` stays a
known hole (L-1), and `escrow-svm` stays a resolver path (L-6). This decision is about *identity
between pinned and executing code*, and it is worth being precise that it buys nothing else.

---

## 6. What this decision does **not** cover

Review finding 2 (the three funded predicate fields that constrain nothing) and finding 3 (mutant
M-5 attributed to a case that does not exist) are **independent** and must be folded into the spec
regardless of which option is chosen. Neither is a design question: the first needs an invariant, a
row in §5.4, an AC and a mutant; the second needs the vector §8 is missing.
