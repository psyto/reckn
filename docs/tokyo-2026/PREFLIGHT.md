# Preflight — the three things only the founder can do

**Start 2026-09-22. Not 09-25.** The faucets are rate-limited per day, so this is the one item on
the whole list that **cannot be compressed into the event**.

Everything here is infrastructure, not the submission. It is disclosed in
`docs/tokyo-2026/DISCLOSURE.md` as preparation and none of it is event work.

---

## 0. The deploy key — **it already exists, do not make a new one**

`~/.foundry/keystores/` already holds **`reckn-agent`**, the key that deployed `RecknZkEscrow` to
Arc testnet. Use it.

```
0xfa2582ecAD1186A171CB9626d1FcFDC0f7995321
```

**That is the address the faucets fund.** Recovered 2026-09-21 with
`cast wallet address --account reckn-agent` (it prompts for the keystore password, so it needs a
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
> and `--account reckn-agent` means **the key never appears in a command, in shell history, or in a
> process list**. The env-file version was worse on every axis.

`reckn-arc-seller` and `reckn-tempo` are the Arc demo's counterparty and the Tempo slice. **Only
`reckn-agent` needs funding.**

Every command below uses `--account reckn-agent`. Keep `SEPOLIA_RPC` (from §3) in the shell:

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
  --account reckn-agent --rpc-url $SEPOLIA_RPC

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

**★ 2026-09-26: fixed.** The output is captured first and the status is forge's own, so a
failing suite exits non-zero and the closing paragraph is not printed. Negative-controlled with a
test made to revert on purpose: forge exit 1 with the fix, and 0 with the first attempt at it,
because `|| true` runs on failure and replaces `PIPESTATUS`.

~~**Fix it during the event**, while writing `FEEDBACK.md` and the README pointers — not now.~~
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

## ★ 5.5 `gh` reverted to the other account once — and that is a loud failure, not a checklist item

**The measurement stands and is not deleted**: `gh auth status` showed `psyto` active on 09-21;
on 09-22 a push failed **403 — "Permission to psyto/reckn.git denied to r3saito"**. Not a 404,
which is what an older note in this repository predicted, and not a git problem. Push identity
here comes from `gh`'s *active account*, which changed without anyone changing it.

> **★ Founder decision 2026-09-25: the per-session `gh auth switch` is dropped from the preflight
> list.** Only `psyto` is used during the event, and **the cost of being wrong is a 403 on push** —
> it stops, loudly, and nothing is lost. A checklist earns its place by catching what fails
> *silently*; this one does not qualify. **If the 403 appears, this is the cause and this is the
> fix:**

```bash
gh auth switch -u psyto
git push origin master
```

**What would close it by property rather than by memory** — and is *not* done: make the push
identity independent of `gh`'s mutable state (an SSH remote, or a pinned credential). **That means
changing `origin`'s URL, which `AGENTS.md` §6 forbids outright.** So it stays a founder call for
after the event, not something to improvise at 03:00.

## ★ 5.7 The RPC key is not in the tree — but it is in the terminal, and the terminal is on camera

**Added 2026-09-25, when rotation was deferred to after the event.** `no-keys.sh`, `.gitignore`
and the rule against `git add -A` all guard **the repository**. None of them guards **a
screenshot**. The demo records terminal sessions against Sepolia, and `SEPOLIA_RPC` carries the
key inside the URL.

- **A key published in a video is published.** Deleting the video afterwards does not unpublish it.
- Before recording: `export SEPOLIA_RPC` stays out of the visible scrollback, and any `cast`
  invocation on screen uses the variable, **never the expanded URL**. Check the frame, not the
  intent — `--rpc-url $SEPOLIA_RPC` is fine, the same line after a shell that echoes it is not.
- The same applies to a live screen-share at judging on 09-27.
- **If it does get into a frame, rotate immediately and re-cut** — that is the one case where the
  deferral is cancelled.
- **The frame check now has a script around it**, because "check the frame" is an admonition too:

  ```bash
  bash docs/tokyo-2026/check-video.sh            # length, resolution, audio, speech, motion
  bash docs/tokyo-2026/check-video.sh <cut> --record   # after the tiles were looked at
  ```

  Rows 1-5 are measured. **Row 6 is not** — no OCR runs, so it records the hash of the cut a
  person actually looked at, and any re-export turns it red. `2026-09-26`: the submission cut
  `Reckn_ETHGlobal_Tokyo_HYBRID_DEMO_v13.mp4` passes 6/6; the only terminal on screen with a
  command line shows `--rpc-url "$SEPOLIA_RPC"` **unexpanded**.

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

## ★ 7. Day 1 — the eight hours before hacking starts

**Hacking begins at 21:00, not in the morning.** The published schedule (Toranomon Hills Forum):

| | |
|---|---|
| **13:00** | registration opens — **22:00 it closes.** Do it first |
| **15:00** | **ENSv2 — Identity for Apps, Agents & Beyond** (ENS, Kevin Krone) |
| 15:30 | Sui · 16:00 Curvegrid |
| **16:30** | **How to Navigate the Uniswap Stack** (Uniswap) |
| 17:00 | 1inch · 17:30 World (IDP vs IDKit) |
| 18:30 | dinner · 20:00 opening ceremony |
| **21:00** | **hacking begins.** Team formation runs in parallel — not needed, this is solo |

**These eight hours are the stated top priority of entering at all**, which was never the prize
money: it was meeting the people who build this. **The 15:00 and 16:30 talks are the two sponsors
this submission applies to**, and the ENS one is about identity for agents, which is the
submission's subject.

**Go with something to give, not something to ask.** `spikes/tokyo-2026/FINDINGS.md` has four
things the ENS team would want and that almost nobody else in the room will have measured:

- the **deployed Sepolia beta's ABI is not the main branch's** — `initialize` and `setText` differ
- `grantSetterRoles` takes **the setter's calldata**; a name reverts `UnsupportedResolverProfile`
  with the name's first four bytes read as a selector
- the resolver is **UUPS**, so an EIP-1167 clone dies in `onlyProxy` with 210 gas and no data
- a name is an **ERC-1155**, so a contract owner without a receiver hook cannot register one

Same for Uniswap: the **ERC-7751 `WrappedError`** wrapping, which makes a hook test that asserts
the outer selector prove nothing.

**None of this is a pitch.** It is the part of the work that helps the person you are talking to,
and it is already written down.

### ★ 7.1 The ENS talk — the second gift, and the one that can be said badly

**Added 2026-09-25.** The four findings above are for a protocol engineer. The 15:00 talk is
*Identity for Apps, Agents & Beyond*, so there is a second thing to bring, for whoever is thinking
about **agent identity** rather than about the beta's ABI. It came out of reading ERC-8004 this
morning (`013` §7-7 has the evidence and the file:line citations).

> **★ Read this before the observation: it is NOT a hole, and saying that it is will be the worst
> sentence of the conversation.** The standard says so itself, twice — `erc-8004.md:325`
> (*"results without filtering by clientAddresses are subject to Sybil/spam attacks"*) and
> Security Considerations (*"Sybil attacks are possible… We expect many players to build
> reputation systems"*). **ERC-8004 deliberately defers "who may write" to a layer above it.**
> What we bring is not a correction; it is **a report from the layer they deferred it to.**

**The first twenty seconds, as spoken:**

> *"The 8004 spec leaves **who may write a record** to a layer above it — it says so in Security
> Considerations. **ENSv2's EAC is the only on-chain answer I have found that doesn't work by
> asking who you are.** It's a capability on a resource, so a second address doesn't help. I'm
> using it as the mechanism, not as a lookup."*

**If they pull on it:**

> *"I read the reputation registry this morning because my demo depended on it. The spec says the
> submitter must not be the agent owner, and the deployed contract does enforce it —
> `Self-feedback not allowed`. But it is a **negative identity check**: a second address answers
> it. So in mine, the right to write one record is **a role a settlement grants and then
> revokes**."*

**The comparison, which is the whole content:**

| | the question it asks | defeated by a second address? |
|---|---|---|
| **ERC-8004** | *are you the subject?* — a negative identity check | **yes** |
| **ENSv2 EAC** | *were you granted this?* — a capability on a resource | **no** |

**Cheap identities defeat negative identity checks. They do not defeat capabilities.** That is an
observation about ENSv2's design with a measurement behind it, which is why it is not flattery.

**Four questions only they can answer, and each one is load-bearing for this submission:**

1. **Is per-record granularity an intended use?** `grantSetterRoles` takes the setter's calldata,
   so a grant for `job:1` does not authorise `other:key`. Is that a property to build on?
2. **Root roles on a `PermissionedRegistry`: is renouncing them intended, and will it stay?**
   **★ Corrected 2026-09-25 — the first draft of this line said the answer decides whether `013`
   §1.1 narrows and `R-6b` fails. It does not: `FINDINGS.md:234` already measured
   `root roles can be renounced ✓` on 09-21.** What is still worth asking is whether that is a
   property they intend to keep or something incidental to the beta — we hang a claim on it.
3. **Is the Sepolia beta's ABI converging with `main`?** `initialize` and `setText` differ. Which
   should something that must still work in a month be built against?
4. **Agents as namespaces — what does the ENS team want that to look like?** Open, and it is the
   question that makes them talk rather than listen.

**Three things not to say:**

- **"ERC-8004 has a hole."** They know, and they wrote it down. Saying it marks you as someone who
  did not read the spec.
- **Do not pitch Reckn, and do not mention the prize.** Lead with the observation; the product
  comes up only if they ask.
- **Do not volunteer that the ChaosChain reference implementation omits the check the official
  contracts enforce.** It is another team's repository and it sounds like telling tales. If asked
  which implementation we used, answer plainly: the official one, unmodified.

**On ordering, decided in the room:** leading with question 4 makes them talk and lets the
observation land inside their own answer. Leading with the observation makes them listen.
**Read which one they want. The observation keeps.**

### ★ 7.2 The Uniswap talk — 16:30

**Added 2026-09-25.** §7 carried one line for Uniswap. There is more, and the strongest piece is
something almost nobody else in the room can say: **we ran a real mainnet Uniswap swap inside a
zkVM and can tell them what made it hard.**

**Open with the provability finding, not with the hook.** Everyone at that booth is building a
hook.

> *"We re-execute Uniswap swaps inside a zk guest to settle an escrow — a real mainnet
> `SwapRouter02.exactInputSingle`, 13 million cycles, measured on the 8th. **The reason we are on
> v3 and not the Universal Router is one precompile: Permit2's signature step uses `ecrecover`,
> which is on our guest's divergent-precompile list and we have not verified equivalence.** So the
> router is the part of your stack we could not put on a proving path."*

**That is a report on the provability of the Uniswap stack from inside a zkVM.** It is a use they
almost certainly do not get feedback about, it costs them nothing to hear, and **it is not a
complaint** — the limitation is in our guest, and the sentence says so.

**Then the DX traps, which are the engineer's gift** (all from `spikes/tokyo-2026/FINDINGS.md`
S2/S3/S6, measured against the real Sepolia `PoolManager`
`0xE03A1074c86CFeDd5C142C4F04F1a1536e203543`):

| trap | what it actually does |
|---|---|
| **ERC-7751 `WrappedError(address,bytes4,bytes,bytes)`** | the PoolManager does **not** bubble a hook's error. **The `bytes4` is the hook function being called** (`beforeSwap` = `0x575e24b4`), **not the error selector** — the error is in `reason`. **A test that asserts the outer selector proves nothing**, and our first attempt at that test asserted the wrong field |
| **hook address mining** | `uint160(hook) & ALL_HOOK_MASK` must equal `BEFORE_SWAP_FLAG` **exactly**. Brute force found salt **8653** inside the test, sub-second, no miner library. **The salt is invalidated by any change to the hook's code or constructor args** — mine, then edit, and the address is silently wrong |
| **types moved** | `SwapParams` / `ModifyLiquidityParams` are in `src/types/PoolOperation.sol`, not on `IPoolManager`; `afterSwap` returns `int128`; liquidity hooks take `BalanceDelta`. Compile errors, not silent ones — cheap, but it costs an hour of a first-timer's day |
| **v4-core needs no submodules** | for interfaces + types + `Hooks`, a shallow clone is enough and `lib/` can stay empty |

**And the design choice, offered because it shows we thought about where a gate belongs:**
`beforeAddLiquidity` is deliberately **unflagged**. **The gate is on trading, not on providing
liquidity.** Say it before they ask.

**Four questions:**

1. **Is the flag encoding / `ALL_HOOK_MASK` stable?** A mined address is baked into every
   deployment and re-mined on every code change; we would like to know what we are committing to.
2. **ERC-7751's `bytes4`** — is "the hook function, not the error" the intended reading? If so, is
   there guidance anywhere, because **the natural test asserts the wrong field**.
3. **Permit2 and `ecrecover` on a proving path** — is a router path that avoids it of any interest,
   or is that firmly out of scope? *(the one whose answer could change what we build next)*
4. **Where do you think hooks should NOT be used?** Open, and we have a real answer of our own to
   trade — we left liquidity provision ungated on purpose.

**Three things not to say:**

- **Not one word against Uniswap's pricing, safety or quality.** It is the workload being verified
  and the venue being gated, not the subject of a critique (`DEMO.md` §4).
- **Do not say we proved a v4 swap.** The proven execution is **v3 `SwapRouter02`**. Earning is on
  v3, spending is on v4, and conflating them is the one factual error available here.
- ~~**Do not quote the fork numbers as deployed numbers.** `1.000000000000000000 → 0.987158034397061298`
  was measured on a **fork** of Sepolia on 09-21.~~ → **2026-09-26: they are deployed numbers now.**
  The same swap ran on Sepolia through the deployed hook and produced the same two figures
  (`0xa40bb316…`). Quote them freely; the caution is kept so the date it stopped applying is visible.

> **★ Talking to them at the booth is NOT the prize requirement.** `U-Q3` is a submission to the
> **Uniswap Developer Feedback Form**, a separate action from the ETHGlobal form and from any
> conversation (`013` §9). It is scheduled in the 16:00–19:00 block on the 26th. **A good
> conversation on Friday does not tick it.**

### ★ 7.3 The leave-behind is already public — do not build a new one

If either team wants it in writing, the honest artifact exists and is public:
**`spikes/tokyo-2026/FINDINGS.md`** on `github.com/psyto/reckn`. It is the measurements, with the
addresses, the salts, the revert selectors and the limits stated — including the ones that did not
work. **Send that, not a deck.** A page built to be handed over becomes a pitch, and §7.1 and §7.2
both exist to avoid handing anybody a pitch.

## 6. Done-check — updated 2026-09-22, three days out

| | |
|---|---|
| Sepolia ETH | ✅ **0.0499** — enough for the ~25–30M gas of a full run at 1 gwei. One more claim only if you want margin against a spike |
| MockUSDC | ✅ **1,000.000000** |
| archive RPC | ✅ Alchemy verified: `eth_getProof` at −100k on Sepolia and at **−15,000,000 on mainnet**, plus `eth_createAccessList`. **The key still needs rotating** |
| the 09-14 work public on `master` | ✅ fast-forwarded from `freeze-window` and pushed. `RETRACTED-2026-09-14.md` is now where the disclosure says it is |
| pre-event work committed with pre-event dates | ✅ 09-21 and 09-22, pushed. **This is what makes the disclosure true rather than merely written** |
| no key material in the tree; `--account reckn-agent` everywhere | ✅ |
| **the disclosure, in full, in the form's description** | ✅ **done 2026-09-22**, and no longer something to remember: `check-description.sh` compares the live field's recorded hash against the file, and a pre-commit hook refuses to commit a disclosure change that leaves `DESCRIPTION.txt` behind. **done 2026-09-22.** `DESCRIPTION.txt` pasted whole, so the narrative and the entire disclosure are in the one field the rules leave for it. **Re-run `build-description.py` and re-paste after any edit to either half** — what is in the form is a snapshot |
| the form's final paragraph | ✅ carried in by the same paste; the counted number is gone from it |
| Alchemy key rotated | **DEFERRED to after the event — founder decision 2026-09-25.** Swapping the RPC the demo depends on, hours before a 36-hour window, risks more than it protects. **No reason for the rotation was ever recorded and no key material is in the tree** (`:44` is a placeholder), so this was hygiene, not a leak response. **The one live consequence is §5.7: the key must not appear on camera.** Rotate on 09-28 |
| **event start time confirmed** | ✅ **hacking begins 09-25 at 21:00 JST.** The repository said 09:00 and was wrong by twelve hours. The window is **36 hours, 21:00 Fri → 09:00 Sun**, and it crosses two nights. See §7 |
| **slept** | 36 hours solo, and the last six are the submission |

