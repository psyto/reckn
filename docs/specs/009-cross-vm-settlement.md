# 009 — cross-VM settlement

> **Status:** spec, round 1. Not approved. `reckn-codex-impl` must not start until
> `docs/reviews/009-spec-rN.md` ends with `VERDICT: APPROVE`.
>
> **Tier: local.** Everything in this document runs in Foundry's in-memory EVM
> (`forge 1.7.1`, measured below) against **committed** Groth16 fixtures. No anvil, no
> testnet, no mainnet, no Solana node of any kind, no RPC. Nothing is deployed anywhere.
> A green 009 says nothing about testnet and nothing about mainnet (`AGENTS.md` §5).
>
> **All measurements in this document were taken on 2026-09-05 at `1db7cd1`**, with the
> command shown next to each. Where a number is carried from an earlier document it is
> labelled *history* and is not used by any criterion.

---

## 1. The claim, and what 009 is not

### 1.1 The claim (one sentence)

> **One `RecknZkEscrow` contract, with no deployment parameter of any kind, settles a deal
> funded on EVM using a proof produced by the Solana re-execution guest — because the deal
> names, at funding, the exact adjudicator program whose proof may settle it, and the
> escrow dispatches to that and to nothing a settler can choose.**

The application submitted on 2026-09-04 promises exactly this and nothing more
(`_applications/2026-09-04-ethonline-application.md`, Q2 item 2):

> *a payment escrowed on an EVM chain, disputed over work performed on Solana, settled by
> a proof — with no resolver on either side, no bridge, and no light client in the
> adjudication path.*

The last clause — **in the adjudication path** — is load-bearing and 009 keeps it. §9 says
what is still not true about *anchoring*, and §11 puts that sentence next to the claim in
every document that carries the claim.

### 1.2 Non-goals — including the ones it will be tempting to do anyway

- **N-1. `RecknVerdictVerifier.sol` is not modified. Not one byte.** In particular 009 does
  **not** add a vkey parameter to `verifyVerdict`, does **not** add an overload, does
  **not** delete `verdictProgramVKey`, and does **not** change the constructor. §4 is the
  full argument; the short form is that every one of those is a **loosening** of the check
  `008` installs over that file, and `AGENTS.md` §0's last line makes loosening that script
  a founder call, not an agent's. OQ-2 puts the alternative in front of the founder.
- **N-2. No Rust changes. No guest changes. No fixture regeneration. No proving.** 009 adds
  zero lines to `zk-verdict/lib`, `zk-verdict/program*`, `zk-verdict/*-io`,
  `zk-verdict/svm-bankhash`, `zk-verdict/script`, `reexec-evm`, `reexec-svm`, `binder`.
  009 consumes the two committed Groth16 fixtures as they are. It runs no `sp1-build`, no
  `cargo-prove`, no `--fixture`.
- **N-3. No timeout and no `refundAfterDeadline`.** That is `003`. A funded deal for which
  no proof ever arrives stays funded after 009 exactly as it does before it, and the root
  `README.md` `Known gaps (not closed)` entry saying so is **not** removed by 009.
- **N-4. The optimistic path (`contracts/RecknEscrow`) is untouched** (`AGENTS.md` §8).
- **N-5. The discarded `transferFrom` return value stays discarded.** `RecknZkEscrow.sol:86`
  today is `IERC20Min(token).transferFrom(msg.sender, address(this), amount);` with the
  boolean dropped. `003` r1 ruled that in scope for `003`. 009 moves that statement (the
  function around it grows two parameters) and changes **nothing else about it**: no
  `require`, no `bool ok`, no `SafeERC20`. Same for the `transfer` at `:117`.
- **N-6. No anchoring work.** No block-header binding, no Solana light client, no proof of
  where a `bank_hash` came from, no snapshot-subset proof. §9 states the residual; 009 does
  not narrow it by one word.
- **N-7. `settleWithProof`'s parameter list does not change.** It stays
  `settleWithProof(bytes32,bytes,bytes)` — measured today, `forge inspect RecknZkEscrow
  methodIdentifiers --json` → `"settleWithProof(bytes32,bytes,bytes)":"fdcef1bb"`. This is
  a non-goal *and* a pinned property (AC-3), because the whole safety argument of §3 is
  that a settler cannot name the adjudicator.
- **N-8. No new external / public function on `RecknZkEscrow`.** The `no-keys.sh` function
  enumeration (`fund` / `settleWithProof` / `refundAfterDeadline`) is unchanged.
  *(`fund` gains two parameters; `no-keys.sh:46` matches `function <name>` and does not see
  signatures. That is a real gap in the build condition and it is OQ-5, not a silence.)*
- **N-9. The predicate does not widen.** One CALL / one System transfer, one delta check,
  exactly as today.
- **N-10. 009 does not touch `docs/specs/003-*.md` or `docs/specs/008-*.md`.** They are in
  review with other agents. Every obligation 009 creates for them is written in §1.3 and in
  an OQ, never as an edit to their text, and **no literal of either document is copied into
  this one**.
- **N-11. No deployment script, no `anvil`, no `broadcast`.** 009 adds no `.s.sol`.
- **N-12. 009 does not claim to test the SVM predicate.** That a 0-lamport transfer fails a
  positive floor is the guest's property, exercised today by
  `cargo run --bin svm -- --execute --amount 500000`. 009 tests **settlement wiring**. §7.4
  says so and no AC below asserts otherwise.

### 1.3 Cross-spec obligations 009 creates (written here, not in their files)

| what 009 installs | who it constrains | protocol |
|---|---|---|
| `RecknZkEscrow.sol` changes (§3.3), so `008`'s `surfaces.pinned` digest of that file goes stale | `003` inherits the new file, not the old one | 009 re-pins `surfaces.pinned` **in the same commit that changes the contract, as a one-line visible diff** (`sha256 = <old>` → `sha256 = <new>`), copied from what `surfaces.sh` prints on failure. This is `008`'s own protocol for exactly this event, applied by the task that fires it first. If `008` has not landed, there is no pin file and this row is inert. |
| `scripts/no-keys.sh` **check 4** is replaced by a strictly stronger property: `RecknZkEscrow` declares **no `constructor` and no `immutable`** (§3.6) | **`003`**, if it still wants a constructor-set `refundDelay` | **OQ-1 — founder ruling required.** 009's recommendation: keep the tightening and let `003` make the delay a `constant` or a per-deal field. A deployer-chosen refund delay is a deployment-time parameter that decides *when* money can move, which is the shape §0 exists to exclude. 009 does **not** write `003`'s replacement. |
| `fund`'s signature widens from 5 to 7 parameters while `no-keys.sh` check 2 still matches only names | nobody, mechanically — which is the problem | **OQ-5.** Pinning signatures is a tightening and belongs in the same file `003` is already extending. 009 pins the two signatures in its own gate (AC-3, AC-7) and does not pre-empt `003`. |

**009 does not require `003` or `008` to be re-reviewed for any of this.**

---

## 2. Exactly where the wire ends today

Every line reference below was read on 2026-09-05 at `1db7cd1`.

### 2.1 What is connected

`zk-verdict/contracts/test/RecknZkEscrow.t.sol:38`, `test_real_proof_settles_to_seller`:
reads `src/fixtures/reexec-groth16-fixture.json`, deploys SP1's real `SP1Verifier`
(v6.1.0) at `:50`, wraps it in `RecknVerdictVerifier` at `:51`, deploys `RecknZkEscrow` at
`:52`, funds at `:55` with the fixture's `.deal_binding`, and calls
`escrow.settleWithProof(...)` at `:59`. The seller is paid at `:61`. **This is a real
Groth16 proof of an in-guest `revm` re-execution moving real ERC-20 balance, with no
signer anywhere in the path.**

Measured today, `cd zk-verdict/contracts && forge test`: **12 tests, 12 passed, 0 skipped**
across 5 suites. The fixture exists (`src/fixtures/reexec-groth16-fixture.json`,
`.outcome = 0`, `.vkey = 0x00248ef8…`), so the early-return gate at
`RecknZkEscrow.t.sol:39-42` does **not** fire.

### 2.2 What is not connected

`zk-verdict/contracts/test/RecknSvmVerdict.t.sol` is the whole SVM on-chain story and it
stops one call short:

- `:20` names `src/fixtures/svm-groth16-fixture.json`.
- `:35-36` deploys `SP1Verifier` and `RecknVerdictVerifier(address(sp1), vkey)` — **the
  same generic verifier contract**, constructed with the SVM guest's vkey.
- `:38` calls `v.verifyVerdict(publicValues, proof)` and asserts `outcome`, `traceHash`
  and a positive delta.
- **There is no `RecknZkEscrow` in this file.** `grep -n "RecknZkEscrow"
  zk-verdict/contracts/test/RecknSvmVerdict.t.sol` → no match. No deal is funded, no money
  moves, nothing is bound to anything.

So the state of the world is: **the SVM verdict is verified on-chain and then thrown away.**

### 2.3 The three facts that decide the design

**(a) The SVM guest already commits a `dealBinding`, and the fixture already carries it.**
`zk-verdict/program-svm/src/main.rs:129-141` computes a SHA-256 over a domain tag, the
authenticated `bank_hash`, the checked account, the predicate bounds and the transaction's
signature, and commits it as `dealBinding` at `:150`.
`zk-verdict/script/src/bin/svm.rs:235` writes it into the fixture as `.deal_binding`.
Measured today: `svm-groth16-fixture.json` has
`deal_binding = 0xe97ff443…`, `vkey = 0x0025224d…`, `outcome = 0`.
`reexec-groth16-fixture.json` has `deal_binding = 0x81899ffc…`, `vkey = 0x00248ef8…`,
`outcome = 0`. **Both bindings are non-zero and differ; both vkeys differ.**
→ **009 needs no guest work.** The binding half of the problem is already solved by the
guest and re-solved in v2 by `008`.

**(b) `RecknVerdictVerifier` holds exactly one vkey, and it is `immutable`.**
`zk-verdict/contracts/src/RecknVerdictVerifier.sol:40`:
```solidity
bytes32 public immutable verdictProgramVKey;
```
set once at `:44` and used at `:55`. One deployed `RecknVerdictVerifier` accepts proofs of
**one** program. `RecknZkEscrow.sol:28` holds **one** `RecknVerdictVerifier`, `immutable`,
set by the constructor at `:65-67`. **One deployed escrow can therefore only ever be
settled by one guest.** This is the obstacle. §4 is about nothing else.

**(c) The escrow reads three members of the verdict record and no numeric field.**
Measured by reading `RecknZkEscrow.sol`: `v.dealBinding` at `:103`; `v.outcome` at `:109`,
`:111` **and `:116`**; `v.traceHash` at `:116`. Five member accesses over three distinct
members. `v.pre`, `v.post`, `v.minDelta`, `v.maxDelta` are **never read**.
→ **009's correctness does not depend on the value width `008` changes.** This is INV-10
and it is what makes 009 safe to specify while `008` is still in review.

### 2.4 Measurements this document relies on

All run 2026-09-05, `forge Version: 1.7.1`, `Commit SHA
4072e48705af9d93e3c0f6e29e93b5e9a40caed8`, `solc 0.8.35`.

| # | command | observed |
|---|---|---|
| E-1 | `forge test --match-test "test_no_such_test_009"; echo $?` | `No tests found in project!` … `0` |
| E-2 | `forge test --list --json --match-test "test_no_such_test_009"` | `{}`, exit `0` |
| E-3 | `forge test --list --json \| jq '[.[][][]]\|length'` | `12` |
| E-4 | `forge inspect RecknZkEscrow methodIdentifiers --json` | `fund(bytes32,address,address,uint256,bytes32)`, `settleWithProof(bytes32,bytes,bytes)`, `deals(bytes32)`, `verifier()`, `FAILED()`, `REPRODUCED()` |
| E-5 | `forge inspect RecknZkEscrow storageLayout --json \| jq '.storage'` | exactly one entry: `label "deals"`, `slot "0"` — **the escrow already has exactly one storage variable**; 009 pins that rather than creating it |
| E-6 | `forge inspect RecknZkEscrow abi --json \| jq '[.[]\|{type,name}]'` | contains `{"type":"constructor"}` **today** |
| E-7 | `forge inspect RecknVerdictVerifier abi --json \| jq '[.[]\|select(.name=="verifyVerdict")\|.outputs[0].components[].name]'` | `["pre","post","minDelta","maxDelta","outcome","traceHash","dealBinding"]` — **the verdict record's member names are derivable from the compiled artifact**, so no criterion in this document has to hard-code them |
| E-8 | scratch probe: `address(contract).codehash` / nonexistent / funded EOA / `keccak256("")` | `0x5de6ebff…`, `0x00…00`, `0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470`, **the last two are equal** |
| E-9 | scratch probe: two instances of one contract with **different `immutable` values** | **different `codehash`** — immutables live in runtime code, so `extcodehash` commits them |
| E-10 | scratch probe: a state-writing target called through a **`view`-typed** reference | **reverts**, sink counter `0` (STATICCALL) |
| E-11 | same target called through a **non-`view`** interface | **succeeds**, sink counter `1` (CALL) |
| E-12 | sandbox: `cp -R src test foundry.toml remappings.txt` + `ln -s <repo>/lib lib`; `rm -rf out cache && forge test --force` | **60 KB**, whole suite green in **~0.73 s** wall |

E-8 and E-9 are the two facts §3 is built on. E-10 and E-11 are the pair AC-4 is built on —
E-11 is the negative control that makes E-10 mean something. E-12 is why every mutant in
§6.5 can run in a sandbox and **the repository's `RecknZkEscrow.sol` is never written by
the gate** (the founder's OQ-5 ruling of 2026-09-04, honoured by construction rather than
by a `trap`).

---

## 3. The design

### 3.1 The question, stated so it has one answer

*Who decides which program's proof may settle this deal, and when is that decided?*

Today the answer is "the deployer of the escrow, at deployment" — because the escrow's
verifier is `immutable` (§2.3b). That is a configuration choice by a party, made once, for
every deal the contract will ever hold. It cannot move a *funded* deal, so `no-keys.sh`
does not see it; but it decides *who is able to*, which is one level up from the thing
`AGENTS.md` §0 forbids, and it is the reason a Solana proof cannot reach `settleWithProof`
today.

**009's answer: the buyer, at `fund`, per deal, in public, in the calldata that funds it —
and nobody afterwards.** The adjudicator becomes a *term of the deal*, exactly like
`seller`, `token`, `amount` and `dealBinding` already are.

### 3.2 The deal terms after 009

A deal is funded against **three** commitments instead of one:

| term | what it fixes | who supplies it | when |
|---|---|---|---|
| `verifier` (address) | which contract adjudicates | buyer | `fund` |
| `verifierCodeHash` (bytes32) | **what code is at that address** — and therefore, by E-9, which SP1 verifier address and which program vkey are baked into it | buyer | `fund` |
| `dealBinding` (bytes32) | which committed prestate + predicate + plan/transaction the verdict must be about | buyer | `fund` |

`verifierCodeHash` is not decoration and it is not redundant with `verifier`. E-9 measured
that a contract's `extcodehash` changes when its `immutable`s change. So for the canonical
`RecknVerdictVerifier`, one 32-byte value commits **both** immutables — the SP1 verifier
address at `:38` and `verdictProgramVKey` at `:40`. The deal therefore names the *program*,
not merely an address, and a seller can check the whole adjudication stack against one hash
computed off-chain from the canonical artefact.

**R-11(iii) check on that sentence** — *does this pin what the dispatch target is set to, or
only that it is what was set?* It pins **what**: the code is fixed by value at funding, and
the address is fixed by value at funding. What it does **not** pin is the code at the
`ISP1Verifier` address *inside* that code — that address is committed, its code is not.
That residual is L-6 in §9, and closing it on-chain is `003`'s deployment check.

### 3.3 `RecknZkEscrow` after 009

The whole diff, written out. **This is the entire contract change 009 makes.**

```solidity
contract RecknZkEscrow {
    uint8 public constant REPRODUCED = 0;
    uint8 public constant FAILED = 1;
    // extcodehash of an account that exists with no code (measured, E-8).
    bytes32 public constant EMPTY_CODEHASH =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    enum State { None, Funded, Settled }

    struct Deal {
        address buyer;
        address seller;
        address token;
        uint256 amount;
        address verifier;          // NEW
        bytes32 verifierCodeHash;  // NEW
        bytes32 dealBinding;
        State state;
    }

    mapping(bytes32 => Deal) public deals;

    event Funded(
        bytes32 indexed dealId, address indexed buyer, address indexed seller,
        address token, uint256 amount,
        address verifier, bytes32 verifierCodeHash, bytes32 dealBinding
    );
    event SettledByProof(bytes32 indexed dealId, address indexed to, uint8 outcome, bytes32 traceHash);

    error DealExists();
    error BadState();
    error ZeroBinding();
    error BindingMismatch();
    error BadOutcome();
    error NoVerifierCode();     // NEW
    error VerifierMismatch();   // NEW

    // no constructor.

    function fund(
        bytes32 dealId, address seller, address token, uint256 amount,
        address verifier, bytes32 verifierCodeHash, bytes32 dealBinding
    ) external {
        if (deals[dealId].state != State.None) revert DealExists();
        if (dealBinding == bytes32(0)) revert ZeroBinding();
        if (verifierCodeHash == bytes32(0) || verifierCodeHash == EMPTY_CODEHASH) revert NoVerifierCode();
        if (verifier.codehash != verifierCodeHash) revert VerifierMismatch();
        deals[dealId] = Deal({
            buyer: msg.sender, seller: seller, token: token, amount: amount,
            verifier: verifier, verifierCodeHash: verifierCodeHash,
            dealBinding: dealBinding, state: State.Funded
        });
        emit Funded(dealId, msg.sender, seller, token, amount, verifier, verifierCodeHash, dealBinding);
        // State written first; the token pull is the only external interaction.
        IERC20Min(token).transferFrom(msg.sender, address(this), amount);
    }

    function settleWithProof(bytes32 dealId, bytes calldata publicValues, bytes calldata proofBytes)
        external
    {
        Deal storage d = deals[dealId];
        if (d.state != State.Funded) revert BadState();
        if (d.verifier.codehash != d.verifierCodeHash) revert VerifierMismatch();

        VerdictPublicValues memory v =
            RecknVerdictVerifier(d.verifier).verifyVerdict(publicValues, proofBytes);

        if (v.dealBinding != d.dealBinding) revert BindingMismatch();

        d.state = State.Settled;
        address to;
        if (v.outcome == REPRODUCED) {
            to = d.seller;
        } else if (v.outcome == FAILED) {
            to = d.buyer;
        } else {
            revert BadOutcome();
        }
        emit SettledByProof(dealId, to, v.outcome, v.traceHash);
        IERC20Min(d.token).transfer(to, d.amount);
    }
}
```

Four properties of that text, each of which an AC checks:

1. **`settleWithProof`'s signature is unchanged** (N-7, AC-3). There is no parameter a
   settler can use to name an adjudicator. This is the safety argument, and it is
   structural rather than lexical: the property is *"the parameter does not exist"*, which
   no operand-resolution question (R-8) can undo.
2. **The dispatch is `view`-typed**, so it compiles to `STATICCALL` (E-10/E-11). The escrow
   calls buyer-chosen code before it has checked the binding, and that is safe only because
   the callee cannot write. AC-4 tests this **with its negative control**.
3. **There is no constructor and no `immutable`.** Two deployments of this source are
   behaviourally identical. There is no deployer choice at all — which is a *strengthening*
   of the central claim, not a weakening (§3.6).
4. **The escrow still reads only `dealBinding`, `outcome`, `traceHash`** (INV-10, AC-7d).

### 3.4 Who ties Solana work to an EVM deal, and when — including the part that is awkward

**The buyer, at `fund`, by committing a `dealBinding` that is a function of the Solana
side.** The SVM guest's binding (`program-svm/src/main.rs:129-141`) commits, among other
things, the authenticated `bank_hash` and the **signature** of the adjudicated transaction.

A signature does not exist before the transaction is signed. Therefore:

> **The escrow after 009 is a dispute escrow, not a pre-payment escrow. Funding commits to
> an anchor and a transaction that already exist.**

This is not a defect 009 introduces and it is not specific to Solana. The EVM binding
commits `state_root`, and in any flow where the checked predicate is evaluated *after* the
seller's work, that root is a post-work anchor and is likewise unknown at the moment the
work is commissioned. Both paths have the same temporal shape and 009 states it once,
here, rather than implying otherwise anywhere.

The consequence that must be said out loud, because it is what a judge will ask:
**the deal's terms are agreed off-chain and asserted on-chain by the buyer.** The escrow
guarantees exactly one thing about them — that the proof which settles is a proof about
*those* terms and no others. It guarantees nothing about whether the terms were fair, and
nothing about whether the anchor was ever a real chain state (§9, L-1/L-2).

### 3.5 The no-op question, answered for this task

*Can a seller who does nothing be paid under 009?*

To settle a deal to the seller, a proof must (i) verify under the vkey baked into the code
whose hash the deal committed, and (ii) carry the deal's exact `dealBinding`. For the SVM
guest, (ii) forces the committed `bank_hash`, the checked account, the bounds, and the
transaction signature. A prover who changes any committed account changes `bank_hash`,
which changes the binding, which fails (i.e. `BindingMismatch`). A prover who supplies a
different transaction changes the signature, same result. And the guest's own predicate
gives `Failed` for a 0-lamport credit against a positive floor.

So the answer is no — **and the reason is that the binding is a term the buyer fixed, not
that the escrow inspects anything.** 009 adds no new predicate and claims none (N-12).

The 009-specific version of the same question is *"can a settler who does nothing choose a
favourable adjudicator?"* — and the answer is the whole of §3.1: there is no parameter to
choose it with (AC-3), and the deal's `verifier` is written once, in `fund`, and read
everywhere else (INV-1).

### 3.6 `scripts/no-keys.sh` check 4 — replaced by a strictly stronger property

Today (`scripts/no-keys.sh:64-70`) check 4 is *"the constructor may bind only the verifier"*
and it is implemented as *"the constructor body does not contain `= msg.sender`"*. After
009 there is no constructor, so that grep matches nothing and the check passes **vacuously**
— an observer that watches nothing (R-9/R-10 shape). 009 therefore replaces its body:

> **check 4 (009): `RecknZkEscrow`'s body declares no `constructor` and no `immutable`.**

Over the same stripped body the four existing checks already read (`no-keys.sh:29-30`):
zero occurrences of the token `constructor`, zero of the token `immutable`.

**This is a tightening, and the argument that it is one is required, not optional.** The set
of trees the build condition accepts strictly shrinks: every tree that passed old check 4
and has no constructor still passes; every tree with a constructor is now rejected, and
some of those passed before. No tree that was rejected is now accepted. The number of
checks does not change, the script's arguments do not change, and its declared final line
(`✓ the claim holds: no key can move a funded escrow.`) does not change — so every consumer
of that line, including the founder's pre-commit ritual and `003`'s harness, is unaffected.

**What it buys:** with no constructor, nothing in the contract can be set at deployment.
Combined with E-5 (one storage variable, the deal mapping) the statement the demo can make
becomes *"there is no key, and there is also nothing a deployer chose"* — which is a
stronger sentence than the one the project ships today, obtained by deleting code.

**What it costs:** `003` cannot have a constructor-set `refundDelay`. That is OQ-1 and it is
a founder ruling, because `003` is another agent's document (N-10).

### 3.7 Options considered and rejected

| option | why not |
|---|---|
| **Two escrow deployments** — leave every contract untouched and deploy one escrow per verifier. Zero Solidity diff, zero risk. | It answers the application's sentence literally and loses the point. The *deployer* would decide which VM an escrow adjudicates, which reintroduces a deployment-time party at the exact place the product claims there is none, and it dodges the question §4 exists to answer ("one escrow, two proof kinds — why is that safe?") rather than answering it. It is recorded here so the founder can take it if the schedule collapses (§10, OQ-6); its cost is this row. |
| **Give `verifyVerdict` a vkey parameter** (or add `verifyVerdictWith`). One verifier contract for all programs; the deal commits a vkey. | This is the technically cleanest shape and it is **not available to an agent**: it loosens the check `008` installs over `RecknVerdictVerifier.sol` (the token set grows, the function count grows, the constructor form changes), and `AGENTS.md` §0 plus `008`'s own N-7 make loosening that script a founder call. **OQ-2** puts it in front of the founder with this reasoning attached. |
| **Commit only the verifier address** (no `verifierCodeHash`) | An address is a weaker statement than the code at it. With the codehash, a seller checks one hash; without it, a seller must reason about what is deployed there and about whether it can change. The check is three tokens and one comparison. |
| **Commit `keccak256(verifier ‖ codeHash ‖ binding)` as one word**, keeping `fund`'s 5 parameters | Smaller ABI, opaque deal. A funded deal would no longer *say* what it committed to, so a seller could not read it off-chain from `deals(dealId)` and an event could not carry it. Legibility is worth two storage words at local tier. |
| **A registry / allow-list of accepted verifiers** | A key. Rejected without further discussion (`AGENTS.md` §0). |

---

## 4. The one-vkey problem, head on

### 4.1 The obstacle, stated precisely

`RecknVerdictVerifier` binds one vkey at construction (`:40`, `:44`) and checks against it
at `:55`. `RecknZkEscrow` binds one `RecknVerdictVerifier` at construction (`:28`, `:65-67`).
Composing those two immutables gives: **a deployed escrow can be settled by proofs of
exactly one guest program.** That is why `RecknSvmVerdict.t.sol` verifies a Solana proof and
then has nowhere to put it (§2.2).

### 4.2 What 009 does about it

**009 does not remove the verifier's immutable. It removes the *escrow's*.**

`RecknVerdictVerifier` stays a single-program adjudicator, deployed once per guest —
`RecknVerdictVerifier(sp1, evmVkey)` and `RecknVerdictVerifier(sp1, svmVkey)`. Deploying one
is permissionless and parameterless from the protocol's point of view: it is not a
registration, nobody approves it, and nothing enumerates the set of them.

The escrow stops choosing. Each deal names the adjudicator it accepts.

### 4.3 How `settleWithProof` tells an EVM proof from an SVM proof

**It does not, and that is the design, not an omission.**

The escrow never learns which virtual machine a verdict is about. There is no branch, no
tag byte, no `if (isSvm)`, no enum. What it learns is *which program* — because the deal
committed the code of the contract that holds that program's vkey — and the SP1 verifier
does the rest.

The claim is therefore not *"the escrow distinguishes two paths"* but the stronger and
simpler *"the escrow has one path, and the deal decides where it points."* Adding a new
guest — a third VM, a different predicate, a future runtime — requires **zero** contract
changes: deploy a `RecknVerdictVerifier` with the new vkey and fund a deal that names it.

### 4.4 Why one escrow accepting two kinds of proof is safe

Three independent barriers, in the order they fire. The AC that tests each is named, and
the one that carries the weight is named.

| # | barrier | what breaks if it is the only one | tested by |
|---|---|---|---|
| B-1 | **The deal's committed code.** `settleWithProof` dispatches to `d.verifier`, whose code must still hash to `d.verifierCodeHash`. A settler has no parameter to name a different one (N-7). | nothing — this is the load-bearing barrier | AC-3, AC-5 |
| B-2 | **SP1 verification.** The proof must verify under the vkey baked into that code. An SVM-guest proof does not verify under the EVM guest's vkey. | if only B-2 existed, an escrow that let the settler name the verifier would be trivially broken: name a sham verifier, settle anything | AC-2 (both directions) |
| B-3 | **The binding.** The verdict's `dealBinding` must equal the deal's. Domain tags separate the two guests' binding functions, and the two guests use different hash functions besides. | if only B-3 existed, any proof of *any* program that happened to commit the right 32 bytes would settle | AC-2 (the third test isolates B-3 from B-2) |

**B-1 is the load-bearing one. B-2 and B-3 are defence in depth**, and this document does not
rely on the cryptographic separation of the two domain tags for anything: the two guests
could share a tag and 009's safety argument would be unchanged, because the deal fixes the
program. That is stated here so no later round mistakes tag separation for the mechanism.

**The degenerate implementation this section exists to exclude:** an escrow that keeps a
single verifier and *"supports SVM"* by having the test deploy that one verifier with
whichever vkey the test needs. Every naive acceptance criterion about "an SVM proof settles
an escrow" is satisfied by it. AC-1 and AC-2 kill it by requiring **one escrow instance,
two verifier instances, two fixtures asserted distinct, and both settlements, inside a
single test function.**

---

## 5. State machine

### 5.1 States

`State { None, Funded, Settled }` — unchanged by 009. There is no fourth state and 009 adds
none.

Per-deal fields other than `state` are written **exactly once**, in `fund`, and read
everywhere else. There is no state in which `deals[id].verifier` differs from the value
`fund` wrote, because no code path writes it twice (INV-1, AC-7f).

### 5.2 Every transition, including the ones that revert

| # | from | call | condition | to | effect |
|---|---|---|---|---|---|
| T-1 | `None` | `fund` | all four guards pass | `Funded` | deal written; `amount` pulled from `msg.sender` |
| T-2 | `None` | `fund` | `dealBinding == 0` | `None` | revert `ZeroBinding` |
| T-3 | `None` | `fund` | `verifierCodeHash` is `0` or `EMPTY_CODEHASH` | `None` | revert `NoVerifierCode` |
| T-4 | `None` | `fund` | `verifier.codehash != verifierCodeHash` | `None` | revert `VerifierMismatch` |
| T-5 | `None` | `settleWithProof` | always | `None` | revert `BadState` |
| T-6 | `Funded` | `fund` | always | `Funded` | revert `DealExists` |
| T-7 | `Funded` | `settleWithProof` | `d.verifier.codehash != d.verifierCodeHash` | `Funded` | revert `VerifierMismatch` — **unreachable, see §5.3** |
| T-8 | `Funded` | `settleWithProof` | proof does not verify under the deal's program | `Funded` | revert (from `ISP1Verifier`) |
| T-9 | `Funded` | `settleWithProof` | verifies, `v.dealBinding != d.dealBinding` | `Funded` | revert `BindingMismatch` |
| T-10 | `Funded` | `settleWithProof` | verifies, binding matches, `outcome == REPRODUCED` | `Settled` | `amount` → `seller` |
| T-11 | `Funded` | `settleWithProof` | verifies, binding matches, `outcome == FAILED` | `Settled` | `amount` → `buyer` |
| T-12 | `Funded` | `settleWithProof` | verifies, binding matches, `outcome ∉ {0,1}` | `Funded` | revert `BadOutcome` |
| T-13 | `Settled` | `settleWithProof` | always | `Settled` | revert `BadState` |
| T-14 | `Settled` | `fund` | always | `Settled` | revert `DealExists` |

### 5.3 Transitions and states that do not exist

- **`None` → `Settled` does not exist.** No path writes `State.Settled` other than the one
  in `settleWithProof`, which is guarded by `d.state != State.Funded`.
- **`Settled` → `Funded` does not exist.** `fund` requires `State.None`.
- **No transition rewrites `verifier`, `verifierCodeHash`, `dealBinding`, `buyer`,
  `seller`, `token` or `amount`.** The only assignment to a member of a stored `Deal`
  outside the single `deals[dealId] = Deal({…})` literal is `d.state = State.Settled`
  (AC-7f pins the assignment set).
- **T-7 is unreachable on any chain where deployed runtime code is immutable**, which is
  every EVM this project targets. It is kept as a fail-closed guard and is honestly labelled
  in §9 (L-8) as evidence of nothing. **No AC asserts that T-7 fires**, because an AC that
  needs an impossible precondition is an AC that will be satisfied by breaking something.
- **There is no state in which the escrow dispatches to an address the caller supplied.**
  The parameter does not exist (N-7, AC-3).
- **There is no re-entrant state.** The only external call made before `d.state` is written
  is the `view`-typed dispatch, which is a `STATICCALL` (E-10, AC-4). The two token calls
  happen after the state write.

---

## 6. Invariants

Identifiers are referenced by the ACs in §7.

- **INV-1 (adjudicator fixation).** For every `dealId`, `deals[dealId].verifier` and
  `.verifierCodeHash` are written by exactly one statement, in `fund`, and by no other. The
  program whose proof can settle a deal is therefore decided by the funder and by nobody
  after funding — in particular not by the settler, who has no parameter for it.
- **INV-2 (program identity).** A `settleWithProof` call that does not revert implies that
  `ISP1Verifier.verifyProof` was reached with the vkey held by the code whose keccak equals
  `d.verifierCodeHash`, and returned without reverting. Equivalently: **there is no path to
  a payout that skips proof verification.**
- **INV-3 (binding).** A payout implies the verified record's `dealBinding` equals the
  value committed at `fund`. A proof of some other execution — other prestate, other
  predicate bounds, other plan or other signed transaction — cannot settle this deal.
- **INV-4 (no path confusion).** For any two deals funded against verifiers `A` and `B`
  whose vkeys differ, no proof that settles the `A` deal can settle the `B` deal. 009 does
  **not** assume the vkeys differ: AC-2 asserts the inequality at run time from the two
  fixtures, so a tree in which the two fixtures became the same artefact fails rather than
  passes.
- **INV-5 (value conservation).** Across `fund` + at most one `settleWithProof` for a deal:
  `balanceOf(buyer) + balanceOf(seller) + balanceOf(escrow)` is constant, `totalSupply` is
  constant, and the escrow's balance attributable to that deal goes from `amount` to `0`
  exactly once. No path pays two recipients and no path pays twice.
- **INV-6 (no double settlement).** `Funded → Settled` is one-way and guarded by the state
  read at the top of `settleWithProof`, before any external call.
- **INV-7 (keylessness).** `msg.sender` appears exactly twice in the contract body, both in
  `fund`, both recording or debiting the funder. `settleWithProof` never reads it. This is
  `no-keys.sh` check 3 and 009 does not weaken it.
- **INV-8 (no configuration).** `RecknZkEscrow` has no constructor and no `immutable`, so
  two deployments of the same source are behaviourally identical and there is no
  deployment-time parameter to disclose, trust, or check.
- **INV-9 (static adjudication).** The dispatch into `d.verifier` cannot write state. It is
  typed through a `view` function and therefore compiles to `STATICCALL` (E-10). This is
  what makes it safe for the escrow to call buyer-supplied code before the binding check.
- **INV-10 (width independence).** The escrow reads exactly three members of the verdict
  record — `dealBinding`, `outcome`, `traceHash` — and no numeric member. Therefore no
  change to the width of `pre` / `post` / `minDelta` / `maxDelta` can change any behaviour
  009 specifies, and 009 is correct against the tree with or without `008`. The member list
  is **derived from the compiled `RecknVerdictVerifier` artefact** (E-7), never written out
  in a script (AC-7d).
- **INV-11 (the seller's checklist grew by one).** Before 009 a seller had to check one
  value on a funded deal (`dealBinding`). After 009 they must check three
  (`verifier`, `verifierCodeHash`, `dealBinding`). This is a real cost of the design and is
  stated as an invariant so that no document may describe the funded deal as
  self-authenticating. §9 L-4.

---

## 7. Acceptance criteria

### 7.0 How an AC is decided

Three gates, in `008`'s construction, because the same two failures keep happening in this
repository.

**Gate 1 — exit status is not enough.** Re-measured today (E-1, E-2): `forge test
--match-test` with a pattern that matches nothing prints `No tests found in project!` and
**exits 0**; `--list --json` with the same pattern prints `{}` and exits 0. There is no
`--fail-on-no-tests` in forge 1.7.1. **Every AC therefore asserts an exact count before it
asserts success.** `zk-verdict/scripts/ac009.sh` implements:

```
kind = forge   (columns: selector, tests)
  cd zk-verdict/contracts
  forge test --list --json --match-test "<selector>"      # must be valid JSON
     found := [.[][][]] ;  FAIL unless |found| == <tests>   # ac009.sh refuses <tests> < 1
     every name in found must match ^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+$
  forge test --json --match-test "<selector>"              # must be valid JSON
     ran := every entry of every suite's test_results, "(…)" stripped
     FAIL unless set(ran) == set(found) and |ran| == <tests> and every status == "Success"
  # --match-test takes ONE regex. A space is a literal space and matches nothing.
  # No selector in this document contains a space.
  # Manifest ids are AC-N; test names use the ZERO-PADDED two-digit form AC0N, and the
  # selector column carries the padded form literally. ac009.sh does not derive one from
  # the other -- both are read from the manifest row, so they cannot drift apart silently.

kind = script  (columns: command, evidence)
  run <command>; exit status must be 0; stdout must contain <evidence> verbatim as a
  substring of one line, after replacing every {witness} with a 16-lowercase-hex value
  ac009.sh RECOMPUTES ITSELF from §7.2. ac009.sh's recomputation must not invoke <command>.
  A row whose evidence contains no {witness} is exempt only where §7.2 says so in writing.
```

**Gate 2 — a count is not an assertion.** Sixteen tests named `test_AC01_…` with bodies of
`assertTrue(true);` pass gate 1 completely. Every AC below therefore names, on a
`Falsify:` line, **a concrete degenerate implementation that makes that AC exit non-zero**.
An AC without one is not an acceptance criterion.

**Gate 3 — the gate must detect a wrong implementation.** AC-10 applies **twelve** committed
mutation patches to a **sandbox copy** of the layout and requires each named row to exit
non-zero. A body that asserts nothing survives the mutant, so its row stays green, so
AC-10 fails.

**The sandbox, and why 009 needs no founder exception for it.** E-12: a copy of
`zk-verdict/contracts/{src,test,foundry.toml,remappings.txt}` with `lib` **symlinked** is
60 KB and runs the whole suite in ~0.73 s including a `--force` rebuild. 009's selftest
reconstructs, under `mktemp -d`:

```
$S/scripts/no-keys.sh
$S/zk-verdict/scripts/*                       (every 009 script, plus ac009.sh)
$S/zk-verdict/contracts/{src,test,foundry.toml,remappings.txt}   (copies)
$S/zk-verdict/contracts/lib -> <repo>/zk-verdict/contracts/lib   (symlink, read-only use)
$S/{README.md, AGENTS.md, CLAUDE.md}          (copies, for AC-11's mutant)
$S/zk-verdict/README.md                        (copy)
```

mutates the **copy**, runs the **copied** scripts, and finishes with `rm -rf "$S"`. **No
file under the repository is written at any point**, which is the founder's 2026-09-04
ruling on `008` OQ-5 honoured by construction rather than by a `trap`. This requires one
property of every script 009 adds, and it is a requirement, not an observation:

> **Location rule.** Every script under `zk-verdict/scripts/` that 009 adds derives its
> targets from its own location (`here=$(cd "$(dirname "$0")" && pwd)` and `root` relative
> to it) **and from nothing else**: no target argument, no environment override, no
> absolute path, no `git rev-parse`. This is already how `scripts/no-keys.sh:17-19`
> behaves and 009 must not regress it.

The sandbox must **fail loudly** if `lib/forge-std/src/Test.sol` is absent. It must never
run `forge install`, never `git clone`, and never write through the `lib` symlink.

### 7.1 The manifest (parsed by `zk-verdict/scripts/ac009.sh` from this file)

**Six columns, always six, `-` where a column does not apply to that kind:**
`AC` | `kind` ∈ {`forge`,`script`} | `selector` (forge only) | `command` (script only) |
`tests` (forge only, exact) | `evidence` (script only). Fields are separated by **two or more
spaces**, so a command or an evidence string may contain single spaces; `#` starts a comment.

**Two placeholders and no others**: `{witness}` (§7.2) and `{B}` (§7.3). `ac009.sh`
substitutes both before comparing; everything else in an evidence line is matched literally.
`ac009.sh --check` fails if any row has a column count other than six, if a `forge` row's
`tests` is `< 1`, or if a `script` row's `evidence` is `-`.

```ac009-manifest
# AC     kind    selector  command                                    tests  evidence
AC-0     script  -         bash scripts/no-keys.sh                    -      the claim holds: no key can move a funded escrow.
AC-0b    script  -         bash zk-verdict/scripts/xvm-pins.sh        -      xvm-pins: 2/2 fixtures match the pin, vkeys distinct, bindings distinct, both Reproduced; witness={witness}
AC-1     forge   _AC01_    -                                          2      -
AC-2     forge   _AC02_    -                                          4      -
AC-3     forge   _AC03_    -                                          2      -
AC-4     forge   _AC04_    -                                          2      -
AC-5     forge   _AC05_    -                                          3      -
AC-6     forge   _AC06_    -                                          3      -
AC-7     script  -         bash zk-verdict/scripts/escrow-shape.sh    -      escrow-shape: 0 constructor, 0 immutable, 1 mapping, verdict members 3/3 read (5 accesses) and 4/4 unread, 7 assignments over 6 targets; witness={witness}
AC-9     script  -         bash zk-verdict/scripts/xvm-no-skip.sh     -      no-skip: 0 fixture gates in the cross-VM file, 2/2 fixtures readable, {B}+16 tests listed and ran, 0 skipped; witness={witness}
AC-10    script  -         bash zk-verdict/scripts/ac009-selftest.sh  -      ac009-selftest: 12/12 mutants detected, 12/12 sandbox controls clean; witness={witness}
AC-11    script  -         bash zk-verdict/scripts/xvm-docs.sh        -      docs: 4/4 replacements present, 3/3 stale claims absent, 1/1 anchoring sentence adjacent; witness={witness}
```

**Arithmetic `ac009.sh --check` recomputes, and a reviewer can recompute by hand:**

- **12** manifest rows, **12** acceptance criteria. **There is no AC-8** — its clauses are
  folded into AC-7 (§7.6) — and **the number is not reused**.
- **6** `forge` rows; their `tests` column sums to **16**.
- **6** `script` rows; **5** carry `{witness}` (AC-0 is the written exemption, §7.2).
- The whole `zk-verdict/contracts` suite after 009 is **`{B} + 16`**, where `{B}` is defined
  in §7.3. AC-9 asserts that number; **no total is spelled out anywhere in this document.**
- AC-10's mutants = **12** (`M-1`, `M-2`, `M-3`, `M-4a`, `M-4b`, `M-4c`, `M-5`, `M-6`, `M-7`,
  `M-8`, `M-9`, `M-10` — the three `M-4` variants are three separate patches), covering
  **11** of the 12 rows; the one row without a mutant
  (**AC-10**) carries a written exemption in §7.2 and a residual in §9 (L-10).

`bash zk-verdict/scripts/ac009.sh --all` runs every row, asserts it ran **12**, then
applies the canary of §7.4 and requires **AC-7** to exit non-zero, and only then prints

```
ac009: 12/12 rows passed; canary M-4c detected by AC-7
```

`ac009.sh <AC>` runs one row. **AC-10 calls only the single-row form**, so `--all` does not
recurse; the canary likewise calls only the single-row form.

### 7.2 Witness recipes, and why a `script` row is not satisfied by `echo`

Every `script` evidence line ends with `witness=<16 lowercase hex>`, the first 8 bytes of a
`sha256` over that row's **witness set** — the exact repository bytes the row's claim is
about. `ac009.sh` **recomputes the witness itself** and requires equality; its recomputation
must not invoke the row's command. A stub can no longer print a constant: it must print a
**hardcoded digest**, which is stale the moment any witnessed byte moves — and AC-10's
mutants move witnessed bytes **at run time**, when no stub author can re-hardcode.

| row | witness set — `sha256` over the concatenation, in this order |
|---|---|
| AC-0 | **exempt from `witness=`, in writing.** Its evidence line is `AGENTS.md` §0's declared output and every consumer of that script reads it; 009 changes check 4's body and must not restyle the output. What replaces the witness is **M-4a**: a sandbox mutant that restores a constructor + immutable into the copied `RecknZkEscrow.sol` and requires the **copied** `no-keys.sh` to exit non-zero. A stubbed `no-keys.sh` is the script the sandbox runs, so it exits 0 on the mutated copy, M-4a is a miss, and AC-10 fails. |
| AC-0b | the two fixture files whole, `LC_ALL=C` sorted by path, ‖ `zk-verdict/scripts/xvm.pinned` |
| AC-7 | `zk-verdict/contracts/src/RecknZkEscrow.sol` whole ‖ `zk-verdict/contracts/src/RecknVerdictVerifier.sol` whole |
| AC-9 | **every** `*.t.sol` under `zk-verdict/contracts/test/`, whole, `LC_ALL=C` sort order — **the glob, not a name list**, so the file 009 adds is inside the witness set on the commit that adds it |
| AC-10 | the **twelve** `zk-verdict/scripts/mutants/M-*.patch` files, whole, `LC_ALL=C` sort order |
| AC-11 | the four documents of AC-11 whole, in the order written there |

### 7.3 Substitution tokens

| token | definition |
|---|---|
| `{B}` | the **cardinality of the recorded test-id set** of `zk-verdict/contracts` at 009's **base commit** — recorded by the implementer in `zk-verdict/scripts/xvm.base.json` as a **sorted list of `<contract>:<test>` strings**, produced by `forge test --list --json` flattened and sorted. `ac009.sh` refuses to run if the file is missing, and AC-9 asserts every recorded id is still present on the current tree. **The set is the artefact; `{B}` is its size.** *(History: on this tree, 2026-09-05, that set has 12 members — E-3. `008` adds tests, so `{B}` will not be 12 at 009's base if `008` lands first. That is exactly why no total appears in this document.)* |
| `{witness}` | §7.2 |

`{B}` and `{witness}` are the **only** two substitution tokens. Anything else in an evidence
line is matched literally.

### 7.4 The canary

After all 12 rows pass, `ac009.sh --all` itself applies one mutant — **M-4c**, appending an
unused `immutable` declaration to a sandbox copy of `RecknZkEscrow.sol` — and requires the
**single-row** invocation of AC-7 against the sandbox to exit non-zero. This moves one
detection off `ac009-selftest.sh` and onto the runner every other row already depends on.
It does not close L-10; it raises the bar (`008`'s construction, same reasoning).

---

### AC-0 — the central claim still holds

```sh
bash scripts/no-keys.sh                    # exit 0
bash zk-verdict/scripts/ac009.sh AC-0      # same command, via the manifest
```

009 changes what check 4 *asserts* (§3.6) and asserts a **strictly smaller** set of accepted
trees. It adds **no** external or public function to `RecknZkEscrow`: the enumerated surface
in `AGENTS.md` §0 and at `no-keys.sh:45` (`fund settleWithProof refundAfterDeadline`) is
byte-identical after 009. Because check 4's meaning moves, `AGENTS.md` §0 and `CLAUDE.md`
record what changed **in the same commit** (§11), and the demo script says it out loud.

**Falsify:** restore a `constructor(RecknVerdictVerifier _v) { verifier = _v; }` and an
`immutable` to `RecknZkEscrow` — check 4 exits non-zero. (This is mutant **M-4a**, run in
the sandbox.)

---

### AC-1 — one escrow, two virtual machines, both settled

`kind: forge`, `selector: _AC01_`, `tests: 2`. File:
`zk-verdict/contracts/test/RecknCrossVmSettlement.t.sol`.

1. `test_AC01_one_escrow_settles_an_evm_proof_and_an_svm_proof`
   - reads **both** fixtures with `vm.readFile` — a missing fixture fails the test rather
     than skipping it (AC-9);
   - asserts `evmVkey != svmVkey`, `evmBinding != svmBinding`,
     `keccak256(evmPublicValues) != keccak256(svmPublicValues)`,
     `keccak256(evmProof) != keccak256(svmProof)`, and both `.outcome == 0`;
   - deploys **one** `SP1Verifier`, **two** `RecknVerdictVerifier`s (`vE` with `evmVkey`,
     `vS` with `svmVkey`), and **exactly one** `RecknZkEscrow`;
   - funds deal `E` (`vE`, `address(vE).codehash`, `evmBinding`) and deal `S`
     (`vS`, `address(vS).codehash`, `svmBinding`) from the same buyer, same token;
   - settles **both** through that one escrow;
   - asserts `token.balanceOf(seller) == 2 * AMOUNT`, `token.balanceOf(address(escrow)) == 0`,
     and both deals' state is `Settled`.
2. `test_AC01_settling_the_svm_deal_leaves_every_other_deal_untouched`
   - one escrow, three funded deals (`E` against `vE`, `S` and `U` against `vS` with
     different `dealId`s and different bindings — `U`'s binding is
     `keccak256("unrelated")`, non-zero and matching no fixture);
   - settles **only** `S`;
   - asserts `E` and `U` are still `Funded`, the escrow still holds `2 * AMOUNT`, the seller
     holds exactly `AMOUNT`, and `U`'s stored `verifier` / `verifierCodeHash` /
     `dealBinding` are unchanged.

**Falsify:** an implementation that keeps a single `immutable` verifier in the escrow —
test 1 cannot construct the escrow with two verifiers, and if it constructs two escrows the
assertion that both settlements happened *through one address* fails. An implementation that
ignores `d.verifier` and dispatches to the first-funded deal's verifier fails test 1's second
settlement. (Mutants **M-4b**, **M-7**.)

---

### AC-2 — the two paths are really two paths

`kind: forge`, `selector: _AC02_`, `tests: 4`.

1. `test_AC02_an_evm_proof_cannot_settle_the_svm_deal` — deal funded against `vS` with
   `svmBinding`; submit the EVM fixture's `publicValues` + `proof`; `vm.expectRevert()`;
   then assert the deal is still `Funded` and the escrow balance is unchanged.
2. `test_AC02_an_svm_proof_cannot_settle_the_evm_deal` — mirror image.
3. `test_AC02_a_verifying_proof_with_the_wrong_binding_reverts_on_the_binding` — deal funded
   against `vS` (so the SVM proof **does** verify) but with `evmBinding` committed; submit
   the SVM fixture; `vm.expectRevert(RecknZkEscrow.BindingMismatch.selector)`. This is the
   test that separates barrier B-3 from barrier B-2 (§4.4): it proves both exist
   independently rather than one masking the other.
4. `test_AC02_the_two_fixtures_are_not_the_same_artifact` — asserts, from the two files:
   `vkey` differ and neither is `bytes32(0)`; `deal_binding` differ and neither is
   `bytes32(0)`; `keccak256(public_values)` differ; `keccak256(proof)` differ; both
   `outcome == 0`.

**Falsify — and this is the one this task will actually hit:** point the test's SVM fixture
constant at `reexec-groth16-fixture.json`. Tests 1–3 would then pass by accident (same
vkey, same binding, everything agrees); **test 4 fails on the first assertion.** (Mutant
**M-5**, which mutates the *test file* for exactly this reason.) Second falsifier: delete
the binding check in `settleWithProof` — test 3 stops reverting (mutant **M-1**).

---

### AC-3 — the settler cannot name the adjudicator; the deal already did

`kind: forge`, `selector: _AC03_`, `tests: 2`.

1. `test_AC03_settleWithProof_has_no_adjudicator_parameter`
   - `assertEq(escrow.settleWithProof.selector, bytes4(keccak256("settleWithProof(bytes32,bytes,bytes)")))`
   - `assertEq(escrow.fund.selector, bytes4(keccak256("fund(bytes32,address,address,uint256,address,bytes32,bytes32)")))`
   - This is a compile-time-plus-runtime pin of both signatures: if a parameter is added or
     reordered, `.selector` changes and the assertion fails.
2. `test_AC03_the_escrow_dispatches_to_the_deal_s_verifier_and_to_nothing_else`
   - deploys the real `vE` **and** a sham `AlwaysReproduces` contract whose `verifyVerdict`
     is `view`, ignores its arguments, and returns a record with `outcome = REPRODUCED`,
     `traceHash = 0`, and `dealBinding = <a fixed value the test chooses>`;
   - **deal A** is funded against `vE` with that *same* fixed binding; submitting garbage
     `publicValues` and `proof` **reverts** (the real verifier is reached);
   - **deal B** is funded against the sham with the same binding; submitting the same
     garbage **settles to the seller**;
   - both assertions live in one test, so it proves the dispatch **follows `d.verifier` in
     both directions** — it is not merely that some call happened.

**R-8 note.** Neither test is a lexical check on a call site, so neither is exposed to
"can the name resolve to something else": test 2 observes the *effect* of dispatching to
two different addresses from two different deals in one escrow.

**Falsify:** make `fund` store `msg.sender` instead of the `verifier` parameter — test 2's
deal B stops settling (mutant **M-7**). Restore a single `immutable` verifier — deal B
reverts (mutant **M-4b**).

---

### AC-4 — the adjudication call cannot write state, and the control proves the test means it

`kind: forge`, `selector: _AC04_`, `tests: 2`.

1. `test_AC04_the_adjudication_call_cannot_write_state`
   - `Sink` (a counter) and `WritingVerifier` (a **non-`view`** `verifyVerdict` with the same
     selector, which bumps the sink and then returns a record matching the deal's binding
     with `outcome = REPRODUCED`);
   - fund a deal against `WritingVerifier` with its real `codehash` (so `fund` succeeds and
     the settle path is actually reached);
   - `vm.expectRevert()` on `settleWithProof`; then assert `sink.n() == 0`, the deal is
     still `Funded`, and the escrow still holds `AMOUNT`.
2. `test_AC04_the_same_verifier_writes_when_it_is_not_called_through_a_view_type`
   - a `NonViewCaller` helper in the test file calls the **same** `WritingVerifier` through a
     non-`view` interface; assert it **succeeds** and `sink.n() == 1`.

**Test 2 is the negative control and is not optional.** Without it, test 1 is satisfied by
any implementation that reverts for any reason at all, including a broken one. Measured
today as E-10/E-11 in a scratch project, so this is a reproduction of an observed pair, not
a prediction.

**Falsify:** type the dispatch through a non-`view` interface — test 1 stops reverting and
`sink.n()` becomes `1` (mutant **M-3**).

---

### AC-5 — funding pins the adjudicator's code by value

`kind: forge`, `selector: _AC05_`, `tests: 3`.

1. `test_AC05_fund_rejects_an_address_with_no_code` — two `expectRevert(NoVerifierCode.selector)`
   calls: a never-touched address (`codehash == 0`, E-8) and a `vm.deal`-funded EOA
   (`codehash == keccak256("")`, E-8). The second case is the one a naive `!= 0` check misses.
2. `test_AC05_fund_rejects_a_codehash_that_is_not_the_named_verifier_s` — pass `vE`'s address
   with `vS`'s codehash; `expectRevert(VerifierMismatch.selector)`; assert nothing was
   pulled from the buyer.
3. `test_AC05_fund_still_rejects_a_zero_binding` — regression pin on today's `ZeroBinding`
   guard, which is also what keeps the predicate guest (whose committed binding is zero) out
   of the settlement path.

**Falsify:** delete the `verifier.codehash != verifierCodeHash` comparison — test 2 stops
reverting (mutant **M-2**). Weaken `NoVerifierCode` to `== bytes32(0)` only — test 1's second
case stops reverting.

---

### AC-6 — money is conserved and settlement happens once

`kind: forge`, `selector: _AC06_`, `tests: 3`.

1. `test_AC06_the_svm_deal_cannot_be_settled_twice` — settle deal `S` with the SVM fixture,
   then submit the **same** `publicValues` + `proof` again;
   `expectRevert(RecknZkEscrow.BadState.selector)`; assert the seller's balance is exactly
   `AMOUNT` and the escrow holds `0`.
2. `test_AC06_a_failed_verdict_on_an_svm_shaped_deal_refunds_the_buyer` — uses a
   `MockVerdictVerifier` (a real contract, so `fund` accepts its codehash) that returns the
   deal's binding with `outcome = FAILED`; assert the **buyer** is made whole and the seller
   holds `0`. *(This test uses a mock and therefore says nothing about Solana; it says that
   the `Failed` branch of the widened contract still refunds. §7.7 repeats this boundary.)*
3. `test_AC06_no_token_is_created_or_destroyed_across_both_settlements` — records
   `totalSupply()` and the three balances before, funds `E` and `S`, settles both, and
   asserts `totalSupply()` unchanged and
   `balanceOf(buyer) + balanceOf(seller) + balanceOf(escrow)` unchanged at every step.

**Falsify:** pay `d.seller` unconditionally, dropping the `v.outcome` branch — test 2 fails
(mutant **M-8**). Remove the `d.state != State.Funded` guard — test 1 fails.

---

### AC-7 — the escrow's shape is closed

`kind: script`, `command: bash zk-verdict/scripts/escrow-shape.sh`.

Region: `zk-verdict/contracts/src/RecknZkEscrow.sol`, from the `contract RecknZkEscrow` line
onward, comments stripped with the idiom `no-keys.sh:29-30` already uses. This script obeys
the Location rule (§7.0), reads no environment variable, takes no argument, **and does not
invoke `forge`** — so `ac009-selftest.sh` can run it against a sandbox copy with no build.

Seven clauses. Every count below is a **literal of this specification, measured against §3.3
and transcribed here**, not a value the implementer generates from the file.

- **7a — the region is literal.** The raw file contains **zero** `/*` and **zero** `*/`, so
  the line-based stripper cannot be spanned; and after stripping, **zero** lines contain a
  `"` or `'`. *(Measured on today's file: 0, 0, 0. §3.3 introduces no string literal.)*
- **7b — no deployment-time configuration.** In the stripped region: **0** occurrences of
  the token `constructor` and **0** of the token `immutable`. This is check 4 of
  `no-keys.sh` restated so that AC-7 and AC-0 fail together and for the same reason.
- **7c — one storage variable.** Exactly **1** occurrence of the token `mapping`, on a line
  that whitespace-normalises to exactly `mapping(bytes32 => Deal) public deals;`.
- **7d — the verdict record's read set is exact, in both directions.** The member names of
  `VerdictPublicValues` are **read at run time** from
  `zk-verdict/contracts/src/RecknVerdictVerifier.sol` (the `struct` block), never written in
  the script. Partition them: for the three names `dealBinding`, `outcome`, `traceHash` the
  region must contain the accesses `v.dealBinding` ×1, `v.outcome` ×3, `v.traceHash` ×1 —
  **five accesses in total**, at `:103`, `:109`, `:111` and twice at `:116` on the file of
  §3.3 — **exactly, as a multiset**; for **every other** member name `m` the region must contain
  **0** occurrences of `v.m`. Evidence prints `3/3 read (5 accesses) and K/K unread` with `K` computed
  from the parsed struct, so a member `008` adds is covered on the commit that adds it.
  *(This clause is INV-10's mechanization, and it is why 009 is correct with or without `008`.)*
- **7e — the dispatch site is singular.** Exactly **1** occurrence of the token
  `RecknVerdictVerifier` in the region, on a line that also contains `d.verifier`.
  **R-8 applies and is written here rather than implied:** this clause does not constrain
  what `d.verifier` resolves to at run time; **AC-3 test 2 does**, behaviourally, and the
  two clauses are a pair.
- **7f — assignment targets and sources are closed.** Over the stripped region, every `=`
  that is not part of `==`, `!=`, `<=`, `>=` or `=>` has a left-hand side drawn from exactly
  `{REPRODUCED, FAILED, EMPTY_CODEHASH, deals[dealId], d.state, to}`, and the total number of
  such assignments is exactly **7**. **R-11(iii):** the LHS enumeration alone is not a pin,
  so the two payout assignments are pinned on the **right** as well — the RHS of the two
  `to = …` statements are exactly `d.seller` and `d.buyer`, in that order.
  *What this closes:* a new state variable written from anywhere, a rewrite of any deal field
  after `fund`, a payout to a third address, and a swap of the two payout branches.
- **7g — the residual, stated rather than implied.** 7f cannot see a state variable that is
  **declared and never assigned**; such a variable is unreachable in every transition of §5.2
  and is left uncovered on purpose. 7c would catch a second *mapping*; a never-written
  scalar would survive. Recorded in §9 as L-11.

**Falsify:** append `RecknVerdictVerifier public immutable fallbackVerifier;` and a
constructor that sets it — 7b fails (mutants **M-4b**, **M-4c**). Pay `d.seller`
unconditionally — 7f's count goes from 7 to 6 (mutant **M-8**). Read `v.post` anywhere —
7d's unread count fails.

---

### AC-9 — no test in this suite can pass by not running

`kind: script`, `command: bash zk-verdict/scripts/xvm-no-skip.sh`.

- **0** occurrences of the token `vm.exists` and **0** *bare* `return;` statements in
  `zk-verdict/contracts/test/RecknCrossVmSettlement.t.sol`. Both fixtures are read with
  `vm.readFile`, whose failure is a **test failure**, not a skip. There is no gate to fire.
  *(A `return expr;` inside a helper contract is not a bare `return;` and is not matched.)*
- both fixture files exist and parse as JSON with non-empty `.vkey`, `.deal_binding`,
  `.public_values`, `.proof`, and an integer `.outcome`;
- `forge test --list --json` over the whole `zk-verdict/contracts` project lists exactly
  **`{B} + 16`** tests, `forge test --json` runs exactly that many, **0** skipped, all
  `Success`;
- every id recorded in `zk-verdict/scripts/xvm.base.json` is still present in the listing.
  *(A base id that vanished means 009 deleted or renamed a pre-existing test, which is not
  in scope and must fail here rather than be absorbed into a total.)*

**Note on scope overlap:** `008`'s own no-skip criterion, if it lands first, asserts a
different number over a different base. The two do not conflict — `{B}` is measured at 009's
base, whatever that is.

**Falsify:** re-insert `if (!vm.exists(FIXTURE)) return;` at the top of the first cross-VM
test — the first clause fails and the listed/ran counts diverge (mutant **M-9**).

---

### AC-10 — the gate detects a wrong implementation

`kind: script`, `command: bash zk-verdict/scripts/ac009-selftest.sh`.

For each of the twelve mutants: reconstruct the sandbox (§7.0), assert the **clean** copy passes
the target rows (the control), apply the patch to the **copy**, assert every target row exits
**non-zero**, then `rm -rf "$S"`. Print one line per mutant with elapsed time, then the
evidence line. Order is: control, then mutation, then restore-by-deletion — never the reverse.

| id | mutation, applied to the sandbox copy | target rows |
|---|---|---|
| M-1 | delete the `BindingMismatch` guard in `settleWithProof` | AC-2 |
| M-2 | delete the `verifier.codehash != verifierCodeHash` guard in `fund` | AC-5 |
| M-3 | declare a non-`view` interface in the escrow file and dispatch through it | AC-4 |
| M-4a | restore a `constructor` + `immutable verifier` (dispatch unchanged) | **AC-0** |
| M-4b | M-4a **and** dispatch to the immutable instead of `d.verifier` | AC-1, AC-3, AC-7 |
| M-4c | append one unused `immutable` declaration, nothing else (**the §7.4 canary**) | AC-7 |
| M-5 | point the cross-VM test's SVM fixture constant at the EVM fixture path | AC-2 |
| M-6 | flip one hex nibble in the copied `svm-groth16-fixture.json`'s `deal_binding` | AC-0b |
| M-7 | `fund` stores `msg.sender` as the deal's verifier instead of the parameter | AC-1, AC-3 |
| M-8 | pay `d.seller` unconditionally (drop the `v.outcome` branch) | AC-6, AC-7 |
| M-9 | re-insert an early-return fixture gate in the cross-VM test | AC-9 |
| M-10 | restore one stale sentence in the copied `zk-verdict/README.md` settlement section | AC-11 |

*(Twelve patch files; `M-4a` / `M-4b` / `M-4c` are three separate patches and are counted as
three of the twelve. Rows covered: AC-0, AC-0b, AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-11 =
**11 of 12**.)*

**AC-10's own row has no mutant.** A mutant on the selftest would be evaluated by the
selftest. §7.4's canary moves one detection onto `ac009.sh --all`, a different script every
other row depends on; the rest is the implementation review opening the script and running
it, which is a person and not a mechanism. **L-10** in §9 says so.

**Falsify:** replace `ac009-selftest.sh`'s loop so it applies only the first two patches —
the count goes to `2/12` and the evidence line does not match. (What this does **not**
falsify is a wholesale stub of the same script; that is L-10.)

---

### AC-11 — the documents moved in the same commit

`kind: script`, `command: bash zk-verdict/scripts/xvm-docs.sh`. Documents: `README.md`,
`zk-verdict/README.md`, `AGENTS.md`, `CLAUDE.md`.

- **4/4 replacements present** — §11(1)…§11(4).
- **3/3 stale claims absent** — the three sentences §11 retires, matched as text.
- **1/1 anchoring sentence adjacent** — in `zk-verdict/README.md`, the paragraph that
  states cross-VM settlement and the paragraph that states the anchoring limit must be
  **within 25 lines of each other**, and the anchoring paragraph must not be the only place
  the limit appears. *(This is the mechanization of OQ-4's recommendation: the caveat travels
  with the claim rather than living in a footnote.)*

**Falsify:** ship the cross-VM paragraph without the anchoring paragraph — the third clause
fails (mutant **M-10** exercises the mirror case).

---

### 7.5 What 009 does **not** put in an AC, and why

- **That a Solana transaction really happened.** No AC asserts it, because nothing in this
  repository can (§9, L-1).
- **That the SVM predicate rejects a no-op.** That is the guest's property and it is
  exercised by `cargo run --bin svm -- --execute --amount 500000` today. 009 runs no Rust
  (N-2) and claims nothing about it (N-12).
- **That the committed fixtures are the current guests'.** That is `008`'s criterion over
  `008`'s ELF builds. 009 asserts only that the fixtures **it consumes** are the ones it
  was pinned against (AC-0b) — a weaker and different claim, and §9 L-12 says so.
- **That T-7 (§5.2) ever fires.** Its precondition cannot be produced on the target chains.

### 7.6 What round 1 folded, so the size change is visible in one place

`AC-8` was going to be a second script running `forge inspect` (`storageLayout`, `abi`,
`methodIdentifiers`). It is folded: `methodIdentifiers` is pinned behaviourally and more
strongly by AC-3 test 1 (`.selector` equality), the absence of a `constructor` ABI entry is
7b restated, and `storageLayout` having one entry is already true today (E-5) and is pinned
lexically by 7c. Keeping it would have added a script that **needs a built project** and
therefore cannot run in the zero-build sandbox, forcing either a mutant exemption or an
in-place mutation of `RecknZkEscrow.sol` — the thing the founder ruled against on
2026-09-04. **The number 8 is not reused.**

### 7.7 Boundary the implementation report must restate

Two of 009's sixteen tests use a mock verifier (AC-6 test 2) or a sham verifier (AC-3 test 2,
AC-4). **Those tests are about the escrow's own logic and say nothing about Solana.** The
Solana claim rests on AC-1 test 1, AC-2 tests 1–4, AC-6 tests 1 and 3, all of which consume
the real `svm-groth16-fixture.json` through SP1's real `SP1Verifier`. The report must say
which tests carry the cross-VM claim and which do not.

---

## 8. Test plan

### 8.1 Files

| path | status | contents |
|---|---|---|
| `zk-verdict/contracts/src/RecknZkEscrow.sol` | **modified** | §3.3 |
| `zk-verdict/contracts/src/RecknVerdictVerifier.sol` | **untouched** | N-1 |
| `zk-verdict/contracts/test/RecknCrossVmSettlement.t.sol` | **new** | the 16 tests of AC-1…AC-6, plus `AlwaysReproduces`, `WritingVerifier`, `Sink`, `NonViewCaller`, `MockVerdictVerifier` as helper contracts in the same file |
| `zk-verdict/contracts/test/RecknZkEscrow.t.sol` | **modified** | its four existing tests call `fund` with two more arguments; **no test is added, renamed or deleted** (AC-9's base-id clause) |
| `scripts/no-keys.sh` | **modified** | check 4's body only (§3.6) |
| `zk-verdict/scripts/ac009.sh` | new | dispatcher; manifest parsed from §7.1 of this file |
| `zk-verdict/scripts/xvm-pins.sh` | new | AC-0b |
| `zk-verdict/scripts/xvm.pinned` | new | the two fixture digests + vkeys + bindings, one per line |
| `zk-verdict/scripts/xvm.base.json` | new | §7.3 |
| `zk-verdict/scripts/escrow-shape.sh` | new | AC-7 |
| `zk-verdict/scripts/xvm-no-skip.sh` | new | AC-9 |
| `zk-verdict/scripts/ac009-selftest.sh` | new | AC-10 |
| `zk-verdict/scripts/xvm-docs.sh` | new | AC-11 |
| `zk-verdict/scripts/mutants/M-*.patch` | new | **twelve** patches |
| `README.md`, `zk-verdict/README.md`, `AGENTS.md`, `CLAUDE.md`, `STATUS.md` | modified | §11 |

**No Rust file appears in this table. No fixture is regenerated. No `.s.sol` is added.**

### 8.2 Positive path

`bash zk-verdict/scripts/ac009.sh --all` → `ac009: 12/12 rows passed; canary M-4c detected by
AC-7`, and `cd zk-verdict/contracts && forge test` → `{B} + 16` passed, 0 skipped.

### 8.3 Negative controls — every one of these must be observed failing, not argued

| # | break this | must go red |
|---|---|---|
| NC-1 | delete `RecknCrossVmSettlement.t.sol` | AC-1…AC-6 (count gate, `0 ≠ N`), AC-9 |
| NC-2 | replace every body in that file with `assertTrue(true);` | AC-10 (every mutant becomes a miss) |
| NC-3 | point the SVM fixture constant at the EVM fixture | AC-2 test 4 — **the fixture-swap control** |
| NC-4 | restore a constructor + immutable to the escrow | AC-0 (check 4), AC-7 (7b) |
| NC-5 | type the dispatch through a non-`view` interface | AC-4 test 1 — and AC-4 test 2 must **still pass**, which is what proves test 1 was measuring the type and not an accident |
| NC-6 | delete the binding check | AC-2 test 3 |
| NC-7 | delete the codehash check in `fund` | AC-5 test 2 |
| NC-8 | store `msg.sender` as the deal's verifier | AC-1, AC-3 test 2 |
| NC-9 | flip a nibble in a fixture | AC-0b |
| NC-10 | stub `escrow-shape.sh` with `echo "<the evidence line with today's witness>"`, then apply M-4c | AC-7 (the recomputed witness has moved; the printed one has not) |
| NC-11 | stub `xvm-pins.sh` the same way, then apply M-6 | AC-0b, same mechanism |
| NC-12 | replace `ac009.sh`'s count gate with `true` | AC-1…AC-6 stop being decidable — **this is not detected by anything in 009** and is L-10 |

**NC-5 and NC-12 are the two that matter most.** NC-5 is the pair that makes AC-4 mean
something. NC-12 is written into the table with "not detected" rather than being left out of
it (R-10(iii)).

### 8.4 Tests that will not be written

- A test that asserts `settleWithProof` "works" without asserting **who** was paid and **how
  much**. Every settlement assertion names a recipient and an exact balance.
- A test whose only assertion is that a revert happened. Every `expectRevert` in AC-2, AC-4,
  AC-5 and AC-6 is followed by an assertion about **state that did not change**.
- A fuzz over the settler address. `settleWithProof` is permissionless and `msg.sender` does
  not appear in it (INV-7); a fuzz that draws 256 callers and finds nothing is evidence of
  nothing. The structural fact is `no-keys.sh` check 3. *(This is `003`'s R-5 applied here.)*
- A test that "checks the SVM binding formula". 009 has no second implementation of it to
  compare against (§9 L-5, OQ-3), and a test that recomputes it from the same constants the
  guest used would be a test of nothing.

---

## 9. Honest limitations

Written here, not in a footnote, and reproduced next to the claim in `zk-verdict/README.md`
(AC-11's third clause).

- **L-1 (Solana anchoring — the big one).** Nothing in 009 establishes that the committed
  `bank_hash` was ever a real Solana cluster's bank hash. The SVM guest recomputes it from
  the committed account set, and `zk-verdict/README.md:215-218` already records that this is
  conclusive only over a **complete** account set and that the demo treats its committed set
  as the world. 009 does not narrow this by one word. **"Settled by a Solana proof" means
  "settled by a proof about a Solana-shaped state the deal named", not "about Solana".**
- **L-2 (EVM anchoring).** Symmetrically, the `state_root` ↔ block-header binding remains in
  the off-chain `reexec-evm::header` layer.
- **L-3.** Therefore *no bridge, no light client* is a statement about the **adjudication
  path** and not about anchoring — the exact form the 2026-09-04 application used, preserved.
- **L-4 (the seller's checklist grew).** INV-11. A seller must now read three values off the
  funded deal before working, not one. 009 adds no mechanism that checks them for the seller.
- **L-5 (one implementation of each binding).** The repository contains exactly one
  implementation of the SVM binding formula — the guest. So *"either party can independently
  compute the deal's terms"* is **not demonstrated** by 009, and the demo funds a deal by
  copying `.deal_binding` out of a fixture the prover produced. OQ-3.
- **L-6 (the SP1 verifier's code).** `verifierCodeHash` commits the `RecknVerdictVerifier`'s
  runtime code and therefore the *address* of the `ISP1Verifier` it uses (E-9). The **code**
  at that address is committed by nothing 009 adds. On-chain deployment checking is `003`'s.
- **L-7 (a buyer can name a sham).** The escrow guarantees the adjudicator is the one the
  buyer committed, not that it is honest. A buyer who commits a sham verifier loses their own
  money and nobody else's; a seller who works without reading the deal can be paid nothing.
  This is a property of a permissionless escrow, not a bug, and it is the reason L-4 exists.
- **L-8 (T-7 is evidence of nothing).** The codehash re-check in `settleWithProof` guards a
  transition that cannot occur where deployed runtime code is immutable. It is fail-closed
  hygiene, not a demonstrated protection, and no AC claims otherwise.
- **L-9 (`extcodehash` corner).** `fund` rejects both `0` (no account) and `keccak256("")`
  (account with no code) — E-8. It does **not** and cannot distinguish a contract that is
  mid-construction; a contract calling `fund` from its own constructor would have
  `codehash == 0` and be rejected, which is the fail-closed direction.
- **L-10 (the gate's own regress).** Nothing in 009 detects a stubbed `ac009.sh` or a stubbed
  `ac009-selftest.sh`. §7.4's canary moves one detection onto `ac009.sh --all`; beyond that
  what stands is the implementation review opening those two scripts and running them, which
  is a person. NC-12 records this in the table rather than omitting it.
- **L-11 (7g).** AC-7's assignment closure cannot see a state variable that is declared and
  never written. Such a variable changes no transition in §5.2.
- **L-12 (fixture freshness).** AC-0b asserts the fixtures are the ones 009 was pinned
  against. It does **not** assert they are the current guests' — that is `008`'s criterion
  over `008`'s ELF builds, and 009 builds no ELF (N-2).
- **L-13 (tier).** Local, in-memory, one process. No chain of any kind was contacted. A green
  009 says nothing about testnet or mainnet.

---

## 10. Dependency on `008`, expressed as a derivation

**`008` is not APPROVE'd. No literal of it — no tag string, no field order, no type, no
number — appears anywhere in this document.** 009 consumes four things from the tree and
derives each of them rather than restating it, so that if the version underneath 009 changes
silently, a gate goes red instead of a claim going quietly false.

| # | consumed | derivation | what fires if it moves |
|---|---|---|---|
| D-1 | the `VerdictPublicValues` struct | 009 **imports** it and never re-declares it. AC-7d parses the member names out of `RecknVerdictVerifier.sol` **at run time**. | a renamed/reordered member 009 reads → `forge build` fails → every `forge` row fails. A member added or re-typed that 009 does **not** read → AC-7d's `K/K unread` count changes → AC-7 fails until the evidence line is updated deliberately. |
| D-2 | the two guests' binding formulas and domain tags | 009 **never writes them**. `zk-verdict/scripts/xvm.pinned` records `sha256` of each fixture file plus its `.vkey` and `.deal_binding`, and `xvm-pins.sh` prints **both** the pinned and the computed value on failure. | any fixture regeneration — by `008`, by `ZK_FRESH=1`, by anyone — makes AC-0b fail. The fix is a **one-line visible diff** copied from the printed value, in the commit that regenerated it. **This is the entire mechanism for "the version changed and nobody said so."** |
| D-3 | the pre-existing test population | `{B}` (§7.3), recorded as a **sorted id set** at 009's base commit. No total appears in this document. | `008` landing between 009's base and 009's commit changes `{B}` → `ac009.sh` refuses to run until `xvm.base.json` is re-measured at the true base, and AC-9's base-id clause fails if a pre-existing test disappeared. |
| D-4 | `no-keys.sh`'s check count and output | 009 changes check 4's **body** and neither its number, its arguments, nor the script's declared final line. AC-0's evidence is that final line, which is `AGENTS.md` §0's declared output. | if `008` adds check 5 first, 009 is unaffected: 009 asserts a line, not a count. |

**009 is correct with or without `008`.** INV-10 is the reason: the escrow reads no numeric
member of the verdict record, so the widening `008` performs cannot change any behaviour 009
specifies. If `008` fails to land, 009's only visible difference is that `{B}` is smaller and
the pinned fixture digests are the pre-`008` ones. **009 must not be blocked on `008`'s
approval**; see OQ-6.

---

## 11. Documents that move in the same commit

1. **`zk-verdict/README.md`, "Settlement — the proof moves money"** — `fund`'s signature
   changes (5 → 7 parameters) and the paragraph that describes the binding gains the
   adjudicator terms. **Retire** the sentence that presents the escrow as bound to one
   verifier at construction. **Add** a short "Honest scope of cross-VM settlement" block
   carrying L-1, L-3, L-4, L-5, L-13 — placed **within 25 lines of** the cross-VM claim
   (AC-11).
   **The existing "Honest scope" blocks for the EVM guest and the SVM guest are not
   overwritten and not edited** (`AGENTS.md` §5).
2. **`README.md`, "Known gaps (not closed)"** — add the cross-VM anchoring gap (L-1/L-2/L-3)
   and the local-tier statement (L-13). **Do not remove** the `RecknZkEscrow has no timeout`
   entry; 009 does not close it (N-3).
3. **`AGENTS.md` §0** — record that check 4 now asserts *no constructor and no `immutable`*,
   that this is a **tightening** with the argument of §3.6, and that the enumerated function
   surface is unchanged. `AGENTS.md` §3's 009 row can then say the wire is closed.
4. **`CLAUDE.md`** — the "verified facts" block says the escrow is settled by real Groth16
   proofs; after 009 it must say **from two guests, through one escrow with no constructor**,
   and must carry L-1 in the same breath.
5. **`STATUS.md`** — the review row, the 9/9 checkpoint state, and the `surfaces.pinned`
   re-pin if `008` landed first. *(`STATUS.md` is not in AC-11's document set: it is a log,
   and pinning log text is how the last three specs shipped stale numbers.)*
6. **`docs/ethonline-2026/PLAN.md` and `DISCLOSURE.md` are founder documents and are not
   edited** (`AGENTS.md` §8).

---

## 12. OPEN QUESTIONS — founder

- **OQ-1 — `no-keys.sh` check 4's tightening constrains `003`.** 009 replaces check 4 with
  *no constructor and no `immutable`* (§3.6). `003`'s current draft expects a
  constructor-set `refundDelay`. **Recommendation: keep the tightening**; a deployer-chosen
  refund delay decides *when* a funded deal can be drained, which is the shape §0 exists to
  exclude, and a `constant` or a per-deal deadline says the same thing without a deployment
  parameter. **009 will not write `003`'s replacement.** If the founder rules the other way,
  009 leaves check 4 alone and AC-7's 7b becomes the only place the property is asserted —
  which is weaker, because it is not the founder's pre-commit command.
- **OQ-2 — the alternative vkey design.** The cleanest shape is one verifier contract that
  takes the vkey as a call argument, with the deal committing the vkey. 009 **rejects it as
  an agent decision** because it loosens the check `008` installs over
  `RecknVerdictVerifier.sol` and `AGENTS.md` §0's last line makes that a founder call. If the
  founder wants it, it is a small change to that file plus an extension of `008`'s check 5,
  and it removes the need for `verifierCodeHash`. **009's design does not depend on the
  answer**; this is an invitation, not a blocker.
- **OQ-3 — should either party be able to compute a deal's terms without the prover?**
  Today they cannot (L-5). Closing it means a host-side binding printer plus a differential
  criterion against the fixture — Rust work, which 009 excludes (N-2). **Recommendation: not
  in 009**, but it is the honest next step and it is the first thing a judge will ask after
  "who computed that hash?".
- **OQ-4 — how loudly must L-1 travel?** 009's answer is AC-11's third clause: the anchoring
  paragraph must sit within 25 lines of the cross-VM claim in `zk-verdict/README.md`.
  **Does the same rule apply to the 3-minute demo script and the submission text?** Those are
  `reckn-demo`'s and the founder's surfaces and 009 does not legislate them.
- **OQ-5 — `no-keys.sh` check 2 matches function names, not signatures.** `fund` goes from
  5 to 7 parameters and the build condition does not see it. Pinning signatures is a
  tightening and belongs in the file `003` is already extending. **Should 009 do it anyway,
  given that 009 is the task that makes the gap material?** 009's recommendation is no —
  two tasks editing the same check in the same week is how the last conflict started — but
  the gap is real and this is the round it became real.
- **OQ-6 — ordering, given the 9/9 checkpoint.** The execution order is `008 → 009`, and the
  checkpoint requires **both** green. §10 shows 009 is technically independent of `008`
  (INV-10). If `008`'s review is still in `CHANGES` on **2026-09-07**, may 009's
  implementation start in parallel against the current tree, accepting a `{B}` re-measure and
  a fixture re-pin when `008` lands? **009's recommendation: yes** — 009 is the item the
  application named as the headline, and it touches no file `008` touches except
  `zk-verdict/contracts/test/RecknZkEscrow.t.sol` (whose four tests both tasks edit for
  different reasons). If the answer is no, the fallback of §3.7 row 1 — two escrow
  deployments, zero Solidity diff — is what fits in the remaining time, and its cost is
  written in that row.
