# Pre-submission checklist — ETHOnline 2026, Continuity Track

Six items. Each one is either **DONE** with the command that proves it, or **OPEN** with the
name of the person who has to do it. Nothing here is marked done on the strength of it
having been written down.

**Track: Continuity, not Classic From Scratch.** Reckn was built in July–August 2026 and
carries pre-existing work, so the Classic track would be a false declaration. The boundary
itself is the founder document [`DISCLOSURE.md`](DISCLOSURE.md), which this file points at
and does not restate — two accounts of one boundary is how they drift.

---

## 1. Continuity Track — the pre-existing-work disclosure ✅ DONE

[`DISCLOSURE.md`](DISCLOSURE.md) is the artefact, filed in the submission's Description field
in full because the rules require it there and there is nowhere else to put it.

What a judge can verify without reading it:

```sh
git log --format='%cd' --date=short | awk '$1<"2026-09-04"'  | wc -l   # 102 commits before
git log --format='%cd' --date=short | awk '$1>="2026-09-04"' | wc -l   # 129 during
```

The pre-existing body is **2026-07-26 → 2026-08-02** (about 140 tests: the re-execution
engine, the escrow, the zkVM guests, the keeper). The development harness added **2026-09-03**
is *also* declared pre-existing, one day before the window opens, rather than counted as
event work.

> **A judge asking git this question can get two different answers, so ask it the way the
> numbers above do.** `git log --since=2026-09-04` returns **117**, not 129, because it
> resolves the date in a different timezone and drops twelve commits made on the morning of
> 09-04 JST. The committer dates as displayed are what the counts here use.

## 2. New work during the event ✅ DONE

**2026-09-04 onward: 152 commits** as of 2026-09-08, every day of the window, no squash,
largest commit 22 files:

```sh
git log --format='%cd' --date=short | awk '$1>="2026-09-04"' | sort | uniq -c
#   34  2026-09-04
#   37  2026-09-05
#   18  2026-09-06
#   30  2026-09-07
#   33  2026-09-08   <- still moving; the window runs to the freeze
```

> **This figure decays, and it decayed once already.** It read *129, five days, 10 on 09-08*
> until 2026-09-08, which was true when it was typed and false a few hours later. Days
> 09-09 through the freeze are not in the table above yet and the sentence has no slot for
> them. **Regenerate it at freeze time — do not edit it by hand:**
> `bash scripts/submission-stats.sh`

The headline items, in the order a judge meets them:

| # | built during the event | evidence |
|---|---|---|
| 1 | **Arc settlement.** Keyless escrow settling Circle's USDC on Arc testnet with **no contract change** — a deal names its token at funding. Four settlements moved real testnet USDC. | `zk-verdict/contracts/arc.json`, and the live page reads them off-chain |
| 2 | **Cross-VM settlement.** One escrow settles an EVM proof and a Solana proof. **Two of the four Arc settlements were decided by proofs about work performed on Solana.** | `docs/specs/009`, `RecknCrossVmSettlement.t.sol` |
| 3 | **Verdict-domain soundness.** A decreasing balance had proved as a maximal credit. Found by writing the specification, before a test existed to fail. | `docs/specs/008` |
| 4 | **A keyless timeout.** `refundAfterDeadline`: permissionless, pays the caller nothing, names no privileged address. | `RecknTimeout.t.sol` |
| 5 | **Live adversarial input.** Anyone can type any claim into the live page and watch the binding and the verdict not move. | `docs/specs/004`, the live page |
| 6 | **The live page itself**, generated from the deployment record rather than typed. | `dashboard/live/generate.py` → `docs/index.html` |
| 7 | **Acceptance gates and mutation tests**, parsing their criteria out of the specifications. | `zk-verdict/scripts/ac00*.sh` |
| 8 | **The demo film**, two cuts from one recorder. | `dashboard/video/record.js` |

**Tempo — proven on testnet 2026-09-08, and deliberately NOT claimed here.** The escrow is
deployed to Tempo Moderato testnet, a deal funded in real PathUSD released on a Solana
`Reproduced` proof, and another refunded the buyer on a `Failed` one; both fees were paid in
the same TIP-20 the escrow held. Hashes: `docs/specs/011-tempo-tip20-slice.md` §10.

It is left out of this submission's event work **on purpose**, and that is a founder decision
rather than a fact: `DISCLOSURE.md` §3 enumerated what would be built during the event and
Tempo is not on that list. Adding it now would mean amending a disclosure **after
submission** — a category §0 does not have. The safe reading is that this submission stands
on Arc, which is what every other line of it claims, and Tempo belongs to CWF.

**The thirty-day timeout is not demonstrated on any chain and cannot be** — it exceeds the
judging window, and time does not move on a public chain. The refund shown anywhere is always
the proof-driven one.

## 3. AI transparency ✅ DONE

[`AI-USAGE.md`](AI-USAGE.md) — what AI was used for, which files it touched, what the human
decided and refused, and five places the AI was wrong and how each was caught.

The one-line version, because it is the version that must not be softened: **202 of 231
commits are AI co-authored; a human ruled on what the project was allowed to claim.**
`SUBMISSION-FORM.md` §9 holds the text pasted into the form's own AI field; this document is
the longer form it summarises.

## 4. Git history a judge can read ✅ DONE

Round 1 scores "proper use of git commit history" and this is the strongest of the three
criteria:

- **152 commits and counting, every day of the window** (2026-09-08), no squash, no `wip:` subjects (`git log --format='%s' | grep -ci 'squash\|wip'` → 0) — regenerate with `bash scripts/submission-stats.sh`
- **Every failed specification review is committed** — 16 verdicts, 15 of them `CHANGES`
- Commit messages carry the *reasoning and the defects found*, not just what changed
- The Continuity boundary rests on this same history, so it had to be true anyway

## 5. The final video — ⚠️ OPEN, and it is the only blocking item

**The rule: 2–4 minutes, at least 720p, audio required, and a human English voice. No AI
voice, no TTS.**

Current state, measured:

| requirement | `reckn-demo-v3.mp4` |
|---|---|
| 2–4 minutes | **3:15** ✅ |
| ≥ 720p | **1920 × 1080** ✅ |
| 16:9 | 1.7778 ✅ |
| opens at all (faststart) | ✅ |
| moves at all | ✅ |
| **audio** | ❌ **no track** |

**The narration is the open item and it belongs to the founder.** The script is
[`../../dashboard/video/VO.md`](../../dashboard/video/VO.md) — timecoded from the recorder's
own beats, every line inside its word budget *and* inside the shot it describes.

**The film is a verification checklist, not an explainer.** It states one claim — nobody can
move this money, including us — says that is easy to say, and then spends its whole running
time on four checks a judge can repeat: a real proof that cannot take the money; the deployed
bytecode compared against source in their own browser; four settlements in real USDC, two
decided by proofs about Solana work; and **what it does not prove** — which is the longest slide in the film, and names all three
limits: no Solana mainnet provenance, Arc **testnet** rather than production, and a thirty-day
timeout refund that a public chain cannot be fast-forwarded to demonstrate. It ends on the
URL, because the film's job is to get the page opened, not to be believed.
A narrator reciting text already on screen is the fastest way to make a good demo feel like a
bad one, so silence there is the script, not a gap in it.

The pitch deck itself — [`../../dashboard/media/reckn-deck.pdf`](../../dashboard/media/reckn-deck.pdf),
also served at `docs/deck.html` — is built from the same file the film's slides come from, so
the two cannot disagree.

### Verification procedure for the final file

Run these four, in order, on the file that will actually be uploaded:

```sh
# 1 · the mechanical rules
bash dashboard/video/check.sh dashboard/media/reckn-demo-v3.mp4

# 2 · an audio track exists, and is long enough to be narration rather than a beep
ffprobe -v error -select_streams a:0 \
  -show_entries stream=codec_name,channels,duration -of default=nk=0 <file>

# 3 · the voice is not silence pretending to be audio
ffmpeg -v error -i <file> -af volumedetect -f null - 2>&1 | grep mean_volume

# 4 · the spoken words match the script, and the timings still land
python3 dashboard/video/vo-table.py     # exits non-zero if any line runs past its shot
```

**Then listen to it.** `check.sh` says so in its own output, and it is not a formality:
whether the audio is a human voice, whether it is clear, and whether it carries music are
**not measured by anything here**. A mechanical green on an unmeasured property is worse than
no check at all. The one that matters most — *human voice, not TTS* — has no instrument, and
a human must sign it off.

## 6. Partner prizes — at most three, and the honest number is two ✅ DECIDED

Selecting a partner whose technology is not integrated is trivially checkable, and being
caught doing it costs more than any prize.

| candidate | integrated? | verdict |
|---|---|---|
| **Arc — Launch on Arc Testnet & Push to Mainnet** | **Yes.** Escrow, verifier and SP1 verifier deployed to Arc testnet; four settlements in Circle's USDC through the ERC-20 face of the native-gas balance | **SELECT (primary)** |
| **Arc — Best DeFi or Agentic Application** | Same deployment; the application *is* agent-to-agent payment | **SELECT** |
| Hedera | **No.** Nothing runs on Hedera | **Do not select** — the largest purse on offer at $15,000, and declining it is the point |
| World AgentKit | **No.** Never built; dropped by founder ruling 2026-09-06 | **Do not select** |
| Solana-badged prizes | Solana *work* is proven, but the settlement is on Arc and nothing is deployed to Solana | **Do not select** unless a specific prize's rules cover proving Solana execution elsewhere — read the rules, do not assume |
| Tempo-badged prizes, if any | **No.** Local implementation only, nothing proven on testnet | **Do not select** |

**Use two of the three slots.** An empty slot costs nothing; a false one costs the
submission's credibility, which is the only thing this project is actually selling.

> On Arc mainnet: the bounty's wording is "deployed OR deployment-ready", and the second
> branch is met. Circle had not published Arc mainnet contract addresses as of 2026-09-06, so
> mainnet is not deployed and the reason is not ours. The same script deploys there unchanged
> once that address list exists.

---

## The one thing that is not done

**Audio.** Everything else on this page is either measured green or a decision already taken.
Until a human voice is on the file, the submission does not meet a stated rule — and no
amount of the rest compensates for it, because it is a gate rather than a score.
