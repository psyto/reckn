# Reckn — Autonomous Harness (ETHOnline 2026)

このリポジトリは自律開発ハーネス付きで運用される。founder は **gate 判定と停止判断だけ**を担い、
仕様・実装・レビュー・デモはエージェントが進める。

計画は `docs/ethonline-2026/PLAN.md`、ETHGlobal への事前開示は同ディレクトリの `DISCLOSURE.md`。

---

## 0. これを壊したら全部無意味になるもの

> **判定する鍵が存在しない。**

Reckn の差別化はこの一点しかない。`RecknZkEscrow` に owner / admin / resolver / pause / upgrade を
**一行足した瞬間に、製品は競合と同じものになる**。だから約束でなく**ビルド条件**にしてある。

```sh
bash scripts/no-keys.sh     # exit 0 = 主張はまだ真
```

- **全 commit の前に走らせる。** 落ちたら commit しない、デモしない、提出しない。
- 列挙された関数面（`fund` / `settleWithProof` / `refundAfterDeadline`）を増やすなら、
  **主張が変わったということ**。同じ commit で本ファイルと `scripts/no-keys.sh` を更新し、
  デモの台本でも明示する。黙って通さない。
- このチェック自体を緩める変更は founder 判断。エージェントは緩めない。

**既定の optimistic 経路（`RecknEscrow`: bonded resolver + challenge window + quorum）は
コモディティであり、差別化しない。** デモと物語は zk 経路一本に寄せる。optimistic 経路は
既存資産として維持するだけで、ここでの改善対象ではない。

---

## 1. エージェント

frame の分割は**熟練度でなく枠の厚さ**による。

| agent | frame | 役割 | 定義 |
|---|---|---|---|
| `reckn-spec` | **thin** | 枠を閉じる。受入条件・不変条件・非目標・境界を `docs/specs/NNN-*.md` に固める。何を主張するかを決める。 | `.claude/agents/reckn-spec.md` |
| `reckn-codex-impl` | **thick** | 固まった仕様の内側を Codex CLI に網羅的に埋めさせる。diff を統合し git を所有。 | `.claude/agents/reckn-codex-impl.md` |
| `reckn-codex-review` | — | Codex を独立した第二のモデルとして敵対的レビューに使い、findings を**自分で裁定**する。 | `.claude/agents/reckn-codex-review.md` |
| `reckn-demo` | thin | 審査員が最初に見るもの（gauntlet・money-shot・README・3分台本）を所有。 | `.claude/agents/reckn-demo.md` |

**author independence**: `reckn-codex-impl` が書いたコードを Codex にレビューさせない。
その場合は自分で仕様の不変条件に照らして行単位で裁定する。Codex は「最も自信の無い2点」への
セカンドオピニオンとしてのみ呼び、**Codex が対象を書いた事実を payload に明記する**。
自分の宿題に自分で丸を付けたレビューは、綺麗な verdict と直っていないバグを生む。

---

## 2. サイクル

```
task → reckn-spec → reckn-codex-review(stage=spec) → [APPROVE] →
       reckn-codex-impl → reckn-codex-review(stage=impl) → [APPROVE] → commit → push
```

- `CHANGES` が5周続くのは正常。周回が長いことを理由に verdict を甘くしない。
- **round 6 で hard stop。** 開いている論点を持って founder に返す。
- レビュー記録は `docs/reviews/NNN-<stage>-r<M>.md`、末尾は `VERDICT: APPROVE` か `VERDICT: CHANGES` の一行。

---

## 3. タスク（ETHOnline の当日作業）

依存順。各タスクは**緑のテストで終わる**単位に割る。

| # | タスク | 主眼 |
|---|---|---|
| 001 | **keyless timeout** | `RecknZkEscrow` に期限後の permissionless 返金。proof が来なくても資金がロックしない。**鍵を足さずに**塞ぐ |
| 002 | **実 ERC-20 ワークロード** | in-guest 再実行を単一 SSTORE fixture から実トークン入金述語へ。cycles を実測して記録 |
| 003 | **key gauntlet** | 全当事者の秘密鍵を公開し、あらゆる窃取経路が revert することをテスト行列と UI で実証 |
| 004 | **live adversarial input** | seller の納品主張を自由入力に。観客が LLM 判事を説得でき、再実行は説得されない |
| 005 | **Arc / USDC** | Arc testnet に USDC エスクローをデプロイ。9/30 までに mainnet 可能な形 |
| 006 | **Hedera / x402** | x402 有料サービスを Hedera 上でホストし、実課金リクエストを通す |
| 007 | **World AgentKit** | 「**誰が紛争を開けるか**」のゲート。**「誰が判定するか」には触れない**（触れたら 0. 違反） |

### 実行順（founder 裁定 2026-09-04）

**`003` → `004` → `002` の順で進める。`001` は独立タスクとして起こさず、`003` の
テスト行列の一項目として同時に落とす。**

理由: Continuity で審査されるのは**当日の差分**であり、`001`（数十行の期限後返金）は
物語上必要だが差分としては弱い。審査員に効くのは `003` key gauntlet と
`004` live adversarial input。`001` は `003` が実証する「あらゆる窃取経路が revert する」
行列の中で、**「proof が来ないまま期限を過ぎた場合」の行**として自然に入る。

これは依存順の変更であって、`001` の中身の放棄ではない。`003` の受入条件は
`001` の受入条件（任意アドレスが期限後に呼べる / 期限前は誰も呼べない /
`settleWithProof` 後は返金経路が死んでいる / 逆順でも二重に出ない）を**含まなければならない**。

---

## 4. Continuity 規律（違反すると失格・賞剥奪・BAN）

- **境界は日付で定義する。当日作業とは、日付が 2026-09-04 以降の commit のみ。**
  ハッシュで「終端」を書くと、それを書いた commit 自身が終端の後に来て必ずずれる
  （実際に一度ずれた）。ハッシュは事前に書けるものではなく、開始時に確定する。
- **イベント開始時（9/4 最初の作業の前）に `git rev-parse HEAD` を記録し、
  `STATUS.md` の `EVENT_START` に書く。** それ以前は全て事前作業。
- 参考: 製品の事前作業は `a122b448887eb71b11f87c7d9cdf65afdc25fe69`（2026-08-02）で一旦終わり、
  以降 9/3 までの commit はハーネスと計画（tooling / planning、製品機能ではない）。
  いずれも `DISCLOSURE.md` に事前作業として記載済み。
- 当日の作業は**イベント期間内の日付で連続的に commit** する。単一の大 commit は既定で失格扱い。
  **事前に書いて当日1発 push は不可。**
- 各 commit は当日作業のパスに限定し、基準コミットからの差分として説明できる状態を保つ。
- 新規部分は**恒久的に** open source。提出時に `psyto/reckn` 全体を public にする（2026-09-03 決定）。
- `DISCLOSURE.md` を書き換えたら、送付済みの内容との差分を `STATUS.md` に記録する。

---

## 5. 主張の規律

`zk-verdict/README.md` の "Honest scope" を**上書きしない**。以下は当日の作業で解消しない限り真であり、
デモ・README・提出文で**解消したかのように書かない**:

- `c-kzg` / `ecrecover` precompile は in-guest で無効。これを要する plan は非対応
- verdict 値は `u64` にマップ（`u64_low` は limb 0 のみ。2^64 超の残高は切り捨て）
- 1 CALL + 1 delta check。フルブロック / 任意コントラクト集合は more cycles, same architecture
- `state_root` ↔ ブロックヘッダの束縛は off-chain の `reexec-evm::header` 層に残る

さらに:

- **走らせていないものを passing と書かない。** 実出力か、さもなくば起きていない。
- **主張は tier を超えない。** local anvil の成功は testnet を意味せず、testnet は mainnet を意味しない。
- **数字が製品に都合よく転んだときこそ疑う。** 過去のラボで誤りは常に「案を通す方向」に出た。
- 前の round の数字を引用しない。ハーネスが変わったなら再実行し、変わっていないならそう明記する。

---

## 6. git 規律

- **`reckn-codex-impl` だけが git を所有する。** 他のエージェントは commit も push もしない。
  Codex は `workspace-write` でも `.git` に書けない。この分担は固定。
- **`git add -A` を使わない。** パスを名指しで stage する（作業ツリーを他のエージェントと共有するため）。
- commit 前に毎回: `bash scripts/no-keys.sh`、`git status`、`git diff --check`、staged 一覧、
  そして `.env` / keypair / 秘密鍵 / `target/` / `node_modules` / 生成物が含まれないことを確認。
- `origin` を新規作成・削除・置換・URL 変更しない。remote URL をログや報告にそのまま書かない。
- **提出前に repo を public にしない。** public 化は提出時、founder の合図で行う。

---

## 7. 停止条件

以下に該当したら回避策を実装せず停止して founder に返す。

- `scripts/no-keys.sh` が落ちた
- 仕様が本当に曖昧（2つの読みとその推奨を書いて止まる。**Codex に推測させない**）
- レビューが round 6 に到達
- 当日作業と事前作業の境界が曖昧になった
- 0. の中心主張を弱める必要が出た
- **9/9 のチェックポイント**: **`003`（`001` の受入条件を含む）が緑**でなければ、撤退可否を
  founder に返す（9/13–15 は R[3]sidency に明け渡すため、ここで撤退できる形を保つ）。
  2026-09-04 の実行順変更に合わせて書き換え。**旧文言「001 と 002 が緑」は使わない**
  — 001 は独立タスクとして存在しなくなり、そのままでは判定不能になる。

## 8. 禁止

- mainnet デプロイ、実資金の投入、外部ユーザーへの連絡、外部サービス契約
- `docs/ethonline-2026/PLAN.md` と `DISCLOSURE.md` の**エージェントによる書き換え**（founder の文書）
- 既存の optimistic 経路の"改善"（差別化に寄与せず、当日作業の境界を濁す）
- scope の拡大。迷ったら広げず `docs/specs/` の OPEN QUESTION に書いて進む
