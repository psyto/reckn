# CWF day one — the first hour, in order

**Kickoff: 2026-09-14 20:00 JST.** Written 2026-09-12 so that nothing on this list has to be
worked out while the clock is running. Each step says who does it and what proves it happened.
The rules behind it are in [`RULES.md`](RULES.md); the standing checklist is
[`PREFLIGHT.md`](PREFLIGHT.md).

---

## 0 · Before anything — the branch (agent or founder)

`master` is frozen from **09-14 01:00 JST** until ETHOnline's finale at **09-17 01:00 JST**.

```sh
git switch -c cwf-2026     # from master's tip, once
```

Everything from here lands on that branch. It is merged after the finale, keeping the dates.
**Nothing enforces this** — the branch is the whole mechanism.

## 1 · Record the boundary (agent, at 20:00 JST — not before)

```sh
bash scripts/cwf-baseline.sh --write     # refuses before kickoff; refuses a second time
```

Writes `docs/cwf-2026/baseline.json`: the HEAD the window opened on. At submission time,
`--diff` reads the window's work out of git rather than out of anyone's memory.

## 2 · Register the project (founder)

Registration opens at kickoff. Two fields matter more than the rest:

- **the description.** [`PITCH.md`](PITCH.md) — 150 words, already audited clause by clause.
  Do not improvise a shorter one at the keyboard; that is where the forbidden sentences appear.
- **the past-work disclosure.** Paste the table in [`PREFLIGHT.md`](PREFLIGHT.md) §3. The rule is
  *"teams must disclose all relevant past development work in the submission form"* — a file in
  this repository does not discharge it, and the Tempo slice belongs in it.
- **the repository link.** `psyto/reckn`, public since 2026-09-04.

## 3 · Read what was published at kickoff (founder)

Tracks, sponsors, judges, dev resources and the form's own fields are released **on 09-14**
(`RULES.md` §4 lists them as unknown). Fill them into `RULES.md` §4, replacing the `[unknown]`
lines with what the page says and the date it was read. **Do not plan around a track before it
exists**, and do not select a sponsor whose technology is not integrated — the ETHOnline
preflight's §6 reasoning applies here unchanged.

## 4 · Start the work (agent)

Spec 010's own gate first: `reckn-codex-impl` must not start until
`docs/reviews/010-spec-r1.md` ends with `VERDICT: APPROVE`, and that review has not been run.

> **This review can be run before kickoff without costing anything** — it reviews a *plan*, and
> the plan is already pre-existing work. Running it on 09-13 would mean day one starts at P1
> instead of at a review. **Founder's call**, because it spends a review round.

Then, in order (010 §9): **P1** pinned legacy SPL Token image replay → **P2** `TokenAmountDelta`
→ **P3** the mutation gate. `bash scripts/no-keys.sh` before every commit, paths named
explicitly, never `git add -A`.

Already closed, so day one does not spend on it: the toolchain is installed (`solana-cli 4.1.2`,
`cargo-build-sbf 4.1.0`, `anchor-cli 0.32.1`, `spl-token-cli 5.6.1`), and `reexec-svm` /
`escrow-svm` were green on 09-12 at 30 and 10 tests.

## 5 · The devnet steps — **founder only, and not on day one unless §6 is answered**

010 §10 puts these behind the founder: a keypair, funds, a deploy, a mint. The agent does not
generate, store or use a key — the Tempo deployment was done by the founder with an encrypted
Foundry keystore and that pattern holds here.

```sh
solana-keygen new --outfile ~/.config/solana/cwf-devnet.json   # NOT in this repository
solana config set --url devnet
solana airdrop 2
```

**Nothing in this repository reads that path**, no private key goes in an argument or an
environment variable, and no deploy happens without an explicit founder decision.

## 6 · The question to answer before any Solana demo (founder)

010 §13 **OQ-1**, and CWF makes it sharper rather than softer: the only thing Reckn can deploy to
Solana today is `escrow-svm`, which is a **resolver path with keys**. The central claim is that
no key decides. Showing a keyed Solana escrow at a Solana hackathon, without saying what it is,
would contradict the product on its own stage.

*The spec's recommendation, unchanged:* **show it only with "this is the resolver path" on the
same screen.** If that cannot be said in the demo, drop the demo instead of softening the
sentence. What is proof-driven today is the **settlement on Tempo and Arc of proofs about Solana
execution** — the Solana side of the ledger is the part the window is for.
