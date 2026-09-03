# CLAUDE.md — Reckn

## これは何か

エージェント間 (x402 型) 決済のエスクローで、**紛争の裁定者が決定的再実行**であるもの。
TEE の LLM 判事でも、自己申告フィードバックでも、監査不能な内部ループでもない。

> Every disputed agent payment is re-reckoned on-chain by replaying it. **Reproduce, or refund.**

**ハーネスと当日作業の規律は `AGENTS.md`。読んでから作業する。**

## 中心主張（毎回確認する）

> **判定する鍵が存在しない。**

`zk-verdict/contracts/src/RecknZkEscrow.sol` は owner / resolver / admin / pause / upgrade を
持たず、`settleWithProof` は permissionless。決済権限は「proof が検証される」ことから来る。
`bash scripts/no-keys.sh` がこれをビルド条件として強制する。**commit 前に必ず走らせる。**

競合が模倣できないのは、全員が「鍵を持つ誰か」を抱えているから（TEE 系=オペレータ /
optimistic 系=bonded resolver / feedback 系=投票者）。**アーキテクチャを捨てないと同じことが言えない。**

## 二つの経路を混同しない

| 経路 | 実体 | 差別化 |
|---|---|---|
| **zk 経路**（`zk-verdict/`） | proof が直接エスクローを解く。resolver 不在 | **これだけ** |
| optimistic 経路（`contracts/RecknEscrow`） | bonded resolver + challenge window + quorum + slashing | **コモディティ**。改善対象でない |

デモ・README・提出文は zk 経路に寄せる。optimistic 経路は既存資産として維持するだけ。

## 検証済みの事実（2026-09-03、再調査で確定）

- `zk-verdict/program-revm/src/main.rs` は **prestate を `state_root` に対し MPT 検証**し
  （アカウント証明＋ストレージ証明）、**本物の `revm` を in-guest で任意 CALL に対し実行**して
  `post` を導出する。**~410k cycles**（うち MPT 検証 ~180k）。
  → ルート `README.md:21` の "a working proof-of-concept over a single instruction today" は
  **SVM 側の話**であり、EVM には当てはまらない。**この行に騙されない。**
- `program-revm/src/main.rs` 冒頭のモジュールコメントは「MPT-authenticity は次に折り込める」と
  書いているが、**その下の `verify_prestate_authenticity()` が既に実装している**。
  **コメントがコードに追いついていない。**
- `RecknZkEscrow` は実 Groth16 proof で決済まで通っている（`Reproduced`→seller /
  `Failed`→buyer / binding 不一致 revert / 未検証 proof revert）。
- **`RecknZkEscrow` に timeout が無い**（proof が来なければ資金は永久ロック）。本体 `RecknEscrow` は
  timeout escape hatch を持つ（`contracts/README.md:12`）のに鍵の無い方だけが持っていない。
  → タスク 001。
- `program-svm` は ~980k cycles（ed25519 sigverify + lattice 再計算）。
- **本プロジェクトは一度もハッカソンに提出されていない。** `SUBMISSION.md` のプリフライトで
  "Repo public" と "Submission form" が未チェック、リポジトリは今も private。

## 環境

- **`codex` は PATH に無い。** 実体は `/Applications/ChatGPT.app/Contents/Resources/codex`
  （codex-cli 0.152.1、確認済み）。**`command -v codex` の失敗を「未インストール」と読まない。**
  これを読み違えて独立レビューを失いかけた事例が過去にある。
- SP1 toolchain は導入済み（`~/.sp1/bin/cargo-prove`、circuits あり）。
  `ZK_FRESH=1` で新規 Groth16 proof を再生成できる（`~/.sp1` に v6.1.0 の ~6.2GB artifacts が要る）。
- `zk-verdict/` は**独立した SP1 workspace**。メインの reckn crates とビルドを共有しない。
- `bash zk-verdict/scripts/zk-e2e.sh` — 鍵の無い経路のワンコマンド e2e。
  step 2 は committed fixtures なので `forge` だけで走る。step 1 は SP1 toolchain が要る。
- `bash scripts/anvil-e2e.sh` — optimistic 経路のワンコマンド e2e（ローカルチェーン）。

## 作業規律

- タスクごとに小さな commit。commit 前に `bash scripts/no-keys.sh` と `git diff` とテスト結果を確認。
- **`git add -A` を使わない。** パスを名指しで stage する。
- 既存の無関係な lint / test 失敗は直さない。
- 迷ったら scope を広げず `docs/specs/` の OPEN QUESTION に書いて進む。
- **走らせていないものを passing と書かない。**
