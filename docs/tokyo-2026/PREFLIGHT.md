# Preflight — the three things only the founder can do

**Start 2026-09-22. Not 09-25.** The faucets are rate-limited per day, so this is the one item on
the whole list that **cannot be compressed into the event**.

Everything here is infrastructure, not the submission. It is disclosed in
`docs/tokyo-2026/DISCLOSURE.md` as preparation and none of it is event work.

---

## 0. The deploy key — **it already exists, do not make a new one**

`~/.foundry/keystores/` already holds **`reckn-arc`**, the key that deployed `RecknZkEscrow` to
Arc testnet. Use it.

```
0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321
```

**That is the address the faucets fund.** Recovered 2026-09-21 with
`cast wallet address --account reckn-arc` (it prompts for the keystore password, so it needs a
real terminal — through a non-interactive shell it fails with `Device not configured`).

State when recorded:

| | |
|---|---|
| Sepolia | **0 ETH, nonce 0** — never used on this chain |
| Arc testnet | 16.83 native USDC — the key is live and is the one that deployed there |
| Sepolia MockUSDC | 0 |

> **This supersedes the first draft of this section**, which said to run `cast wallet new` and
> keep a plaintext private key in `~/.reckn/tokyo.env`. The keystore is **encrypted**, it is
> already the project's deployer identity — so Arc and Sepolia share it, visible from the chain —
> and `--account reckn-arc` means **the key never appears in a command, in shell history, or in a
> process list**. The env-file version was worse on every axis.

`reckn-arc-seller` and `reckn-tempo` are the Arc demo's counterparty and the Tempo slice. **Only
`reckn-arc` needs funding.**

Every command below uses `--account reckn-arc`. Keep `SEPOLIA_RPC` (from §3) in the shell:

```bash
export SEPOLIA_RPC=...
export DEPLOYER=0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321
```

> **Still true from the first draft:** no key material goes in the repository tree. On another
> project, `account-keys.json` was written to the repo root by a script and was **not** in
> `.gitignore` — one `git add -A` from a leak on a public repo.

---

## 1. Sepolia ETH — **start today, it is rate-limited per day**

**How much — measured, not guessed (2026-09-21).**

Sepolia gas price at the time of writing: **1.01 gwei** (six consecutive base fees 0.94–1.07).
Deployment cost from the **actual compiled bytecode** of what the event deploys:

| contract | deployed size | deploy gas |
|---|---|---|
| `PermissionedRegistry` | 23,457 B | ~4.79M |
| `SP1Verifier` | 11,974 B | ~2.46M |
| `RecknZkEscrow` | 5,569 B | ~1.16M |
| `RecordGatedHook` | 5,137 B | ~1.07M |
| `RecknVerdictVerifier` | 1,940 B | ~0.43M |

**~9.9M** for those, plus the resolver proxy, the record contract, pool initialisation, liquidity,
the name registration (commit + register) and the demo transactions — **~14M for one clean pass**,
**25–30M** allowing for redeploys. At 1 gwei that is **0.03 ETH**.

> **★ This supersedes "target ~0.5 ETH" in the first draft, which was an order of magnitude too
> conservative and would have cost three days of faucet-farming.** **0.05 ETH already covers a
> clean run.** Take **one** more claim for margin (~0.1 ETH) against a gas spike — Sepolia's base
> fee has historically reached tens of gwei — and then stop.

**Faucets that do not require a mainnet balance** (verify terms on the page; they change):

| faucet | notes |
|---|---|
| [QuickNode](https://faucet.quicknode.com/ethereum/sepolia) | base drip needs **no account, no social post, no mainnet balance** — the one to try first |
| [Google Cloud Web3](https://cloud.google.com/application/web3/faucet/ethereum/sepolia) | Google login instead of a mainnet balance |
| [Alchemy](https://www.alchemy.com/faucets/ethereum-sepolia) | free account; **reports differ on whether a small mainnet balance is now required** — check before relying on it |
| GetBlock / Mode / GHOST | account or email sign-up, no mainnet requirement |

**One or two claims is enough — do not farm for three days.** Check the balance:

```bash
cast balance $DEPLOYER --rpc-url $SEPOLIA_RPC --ether
```

---

## 2. MockUSDC — ✅ **DONE 2026-09-21**. Mintable by anyone, and minted.

ENSv2's Sepolia registration fees are paid in **MockUSDC**, and the deployed contract's
`mint(address,uint256)` has **no owner guard** — verified 2026-09-21 by reading the bytecode's
selectors (no `owner()`, no `Ownable` error) and by simulating a mint from an unrelated address,
which did not revert.

```
address   0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e
decimals  6
symbol    USDC
```

**Mint yourself some** (1,000 USDC; a name costs ~0.61):

```bash
cast send 0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e \
  "mint(address,uint256)" $DEPLOYER 1000000000 \
  --account reckn-arc --rpc-url $SEPOLIA_RPC

cast call 0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e \
  "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $SEPOLIA_RPC
```

**Done**: tx `0xdf7e341f6a3e4aab9ec62c357bce7d6b74b4f40bda599016b7f7639326285444`,
block 11,749,554 — balance **1,000.000000 USDC**. Cost **51,369 gas at 1.02 gwei = 0.0000526 ETH**,
which is the empirical check on §1's budget.

**Do not register the real name before the event.** Minting a test token is infrastructure;
registering the submission's namespace is part of building it. Mint now, register on 09-25.

---

## 3. An archive RPC — the demo-day dependency

`012` §7-1, measured: **the public endpoint serves no archive state and rate-limits.** A demo that
depends on a public RPC over conference wifi is a demo that fails in the room.

**Get a free-tier key** from Alchemy or QuickNode (an account either way) and export it as
`SEPOLIA_RPC` (§0). An RPC URL with a key in it is a secret too — keep it out of the tree.

### Verify it actually does what we need — do not assume

```bash
# 1. it answers at all
cast block-number --rpc-url $SEPOLIA_RPC

# 2. eth_getProof on a block ~100k back — the archive question
OLD=$(( $(cast block-number --rpc-url $SEPOLIA_RPC) - 100000 ))
cast rpc eth_getProof 0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e '[]' \
  $(cast to-hex $OLD) --rpc-url $SEPOLIA_RPC | head -c 200

# 3. eth_createAccessList
cast rpc eth_createAccessList \
  '{"to":"0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e","data":"0x313ce567"}' latest \
  --rpc-url $SEPOLIA_RPC
```

**If step 2 returns an error about missing trie nodes or pruned state, the endpoint is not
archive** and the mainnet re-execution path will fail at the venue. Find another before 09-25.

> A QuickNode account may already exist for other reasons. **Check before creating a new one.**

---

## 3b. ✅ DONE 2026-09-21 — `master` was four commits behind, and a judge clones `master`

**Found by cloning the public repository the way a judge would**, which is the only reason it was
found at all.

> **The first diagnosis here was wrong and is kept rather than deleted.** It said "four commits are
> unpushed". They were pushed — to **`freeze-window`**, the branch `CLAUDE.md` created for work
> done during the ETHOnline freeze, with the standing instruction *"merge it back preserving the
> dates once the finale is over"*. **The finale was 2026-09-17 and the merge had not happened.**
> So the symptom was real and the cause was not: the default branch on GitHub is `master`, a clone
> lands there, and `master` did not have the 09-14 work.

What `master` was missing — including the file the disclosure names as its evidence:

| commit | |
|---|---|
| `c0b7ea8` cwf: retracted | **`docs/cwf-2026/RETRACTED-2026-09-14.md`** — the disclosure cites it for Reckn withdrawing from Crypto World's Fair |
| `6c8f38d` ethonline: round 1 ended it | the ETHOnline history §2 relies on |
| `e1d15ae` / `501cbde` | `STATUS.md`, `CLAUDE.md`, `AGENTS.md` — the Tokyo lane decision |

`master` was an ancestor of `freeze-window`, so this was a **fast-forward: no conflicts, no
rewriting, dates preserved** — exactly the operation `CLAUDE.md` had prescribed.

```
origin/master  9c9a98d (09-12, 306 commits)  →  501cbde (09-14, 310 commits)
```

**The disclosure's "310 commits, most recent `501cbde`" is now checkable by anyone.** Before this
it was not: a judge would have counted 306 and found no retraction file.

**Work on `master` from here.** `freeze-window` has served its purpose.

## 4. Also before 09-25, and not on this page

- **★ CORRECTED 2026-09-21 — there is no "send it to ETHGlobal" procedure, and the first draft of
  this page invented one.** The obligation is real and the rules page says it verbatim:
  *"In all cases, you must disclose any pre-existing work in writing to the ETHGlobal team"* —
  **but the rules define no channel.** This repository already settled the question at ETHOnline
  (`docs/ethonline-2026/SUBMISSION-FORM.md:66`): *"the rules and `DISCLOSURE.md` itself require the
  disclosure **reproduced in full in this field**. There is no other place to file it."*
  **So the disclosure is delivered by pasting it, in full, into the submission form's description
  field** — which can be filled in before the event. Discord and the help desk are a courtesy, not
  the procedure.
- Fill the ETHGlobal form's stable fields (`docs/tokyo-2026/SUBMISSION-FORM.md`).
- Decide where the **live demo** is hosted. A single static page on GitHub Pages — no wallet, no
  install, touchable in thirty seconds — is the pattern that has worked here before.

## ★ 5. Traps measured on 2026-09-21 that will bite during the event

These came out of actually running the two checks rather than reasoning about them. **None is a
reason to change anything before the event; all three are reasons not to be surprised by it.**

### 5.1 `zk-e2e.sh` cannot fail — the one-command demo prints success regardless

`zk-verdict/scripts/zk-e2e.sh:85`:

```bash
( cd "$contracts" && forge test -vv 2>&1 ) | grep -E '…' || true
```

`set -euo pipefail` is set at the top, and `|| true` neutralises it. **Demonstrated twice:**

- a throwaway clone with one test deliberately reverting → **exit 0**, and the closing
  *"what just happened … Settlement authority = a proof that verifies"* block still printed;
- **on this repository**, during §5.2's run, with a genuinely failing test → same.

The failure text does survive the `grep` filter, so it is visible **if you read the scrollback**.
The exit code is not, and the closing paragraph asserts the opposite.

**Fix it during the event**, while writing `FEEDBACK.md` and the README pointers — not now.
Touching it beforehand improves the submission before the window opens; knowing about it now is
enough to avoid being fooled by it. Added to `013` §4.

### 5.2 `ZK_FRESH=1` destroys a hand-made fixture — do not run it casually

Regenerating the proof overwrote the **tracked** file
`zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json` and turned the suite red:

| | committed | regenerated |
|---|---|---|
| `pre` | `0x…0001_0000000000000000` = **2⁶⁴** | `0x2a` = **42** |
| `post` | 2⁶⁴ + 100 | 142 |
| `vkey` | identical | identical |

**The committed fixture was built with `pre` exactly at 2⁶⁴ so that
`test_AC10_verifier_returns_untruncated_pre` means something** — it proves the verifier does not
truncate at the 64-bit limb boundary. `ZK_FRESH=1` is **not "regenerate the same thing"**; it
generates a different execution, `pre` becomes 42, and the property that AC10 exists to check
**stops being exercised**.

The dangerous version of this is not the red test. It is someone at 03:00 seeing `42 != 2⁶⁴`,
"fixing" the expectation, and **silently deleting an acceptance criterion**.

```bash
# if it was run by accident:
git checkout -- zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json
```

Verified restored on 2026-09-21: **55 passed, 0 failed.**

### 5.3 `pages/builds/latest` says "errored" for builds that were merely cancelled

Two Pages builds reported `status: errored`, `duration: 0` and the message *"Page build failed."*,
and the live site stayed stale. **Nothing had failed.** Pushing twice within two minutes makes
GitHub cancel the superseded build, and the Pages API reports that cancellation as an error with
no way to tell the difference. The API kept saying `errored` for the commit **after** the build
that deployed it had succeeded.

**The truth is in the workflow, not the Pages API:**

```bash
gh run list --limit 5     # "pages build and deployment" — success / cancelled / failure
```

This cost a wrong diagnosis and a commit whose message blames Jekyll for something Jekyll did not
do (`docs/.nojekyll`, kept because a four-page hand-written site has no use for the pipeline
either way). **On the day: push once, then check `gh run list` — not the Pages API — before
concluding the site is broken.**

### 5.4 The good news — a fresh clone works

`git clone` of the **public** repo, then `bash zk-verdict/scripts/zk-e2e.sh`: dependencies are
fetched by the script (there is no `.gitmodules`), **55 tests pass, exit 0**. A judge can run the
keyless settlement path in one command. **Re-run this check at the end of the event**, from a
clone rather than the working tree.

---

## ★ 5.5 `gh` reverts to the other account between sessions

`gh auth status` showed `psyto` active on 09-21; on 09-22 a push failed
**403 — "Permission to psyto/reckn.git denied to r3saito"**. Not a 404, which is what an older
note in this repository predicted, and not a git problem.

```bash
gh auth switch -u psyto       # first, every session
git push origin master
```

## ★ 5.6 The description cannot go stale silently

**A note saying "remember to re-paste" is an admonition.** This repository's own rule is that
what works is a structure that forces the choice, which is why `no-keys.sh` fails the build
rather than asking nicely. Same shape here:

```bash
bash docs/tokyo-2026/check-description.sh            # is the live field current?
bash docs/tokyo-2026/check-description.sh --record   # after pasting, say so
```

- **Row 1** regenerates `DESCRIPTION.txt` and diffs it — catches an edit to the disclosure or the
  narrative that was never rendered.
- **Row 2** compares the hash recorded in `PASTED` against the file — **catches the half the
  repository cannot see**, which is whether the text in the live form is this text.
- **`scripts/hooks/pre-commit`** (installed with `git config core.hooksPath scripts/hooks`)
  **refuses the commit** if the sources moved and `DESCRIPTION.txt` did not, and warns — without
  blocking, because it would be circular — that the form is now behind.

**Both were run against a negative control**: one word changed in the disclosure turns both rows
red and the commit is refused; restoring it turns them green. A check never seen to fail is not
a check — which is exactly what §5.1 says about `zk-e2e.sh`.

## 6. Done-check — updated 2026-09-22, three days out

| | |
|---|---|
| Sepolia ETH | ✅ **0.0499** — enough for the ~25–30M gas of a full run at 1 gwei. One more claim only if you want margin against a spike |
| MockUSDC | ✅ **1,000.000000** |
| archive RPC | ✅ Alchemy verified: `eth_getProof` at −100k on Sepolia and at **−15,000,000 on mainnet**, plus `eth_createAccessList`. **The key still needs rotating** |
| the 09-14 work public on `master` | ✅ fast-forwarded from `freeze-window` and pushed. `RETRACTED-2026-09-14.md` is now where the disclosure says it is |
| pre-event work committed with pre-event dates | ✅ 09-21 and 09-22, pushed. **This is what makes the disclosure true rather than merely written** |
| no key material in the tree; `--account reckn-arc` everywhere | ✅ |
| **the disclosure, in full, in the form's description** | ✅ **done 2026-09-22**, and no longer something to remember: `check-description.sh` compares the live field's recorded hash against the file, and a pre-commit hook refuses to commit a disclosure change that leaves `DESCRIPTION.txt` behind. **done 2026-09-22.** `DESCRIPTION.txt` pasted whole, so the narrative and the entire disclosure are in the one field the rules leave for it. **Re-run `build-description.py` and re-paste after any edit to either half** — what is in the form is a snapshot |
| the form's final paragraph | ✅ carried in by the same paste; the counted number is gone from it |
| Alchemy key rotated | **OPEN** |
| **event start time confirmed** | **OPEN** — the repository says 09-25 09:00, the founder recalls an afternoon start. 36 hours and 48 hours are different plans |
| **slept** | 36 hours solo, and the last six are the submission |

