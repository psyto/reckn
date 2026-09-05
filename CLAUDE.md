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
  → ルート `README.md` はこれを "a working proof-of-concept over a single instruction today" と
  書いていた（**SVM 側の話**で EVM には当てはまらない）。**09-03 に訂正済み。**
- `program-revm/src/main.rs` 冒頭のモジュールコメントは「MPT-authenticity は次に折り込める」と
  書いていたが、**その下の `verify_prestate_authenticity()` が既に実装している**。
  **09-03 にコメントを訂正済み。**
  → この2件は**コードでなくドキュメントが古かった**型。次に同じ疑いを持ったら、
  まず `git log -1 --format=%cd <file>` でなく**現物のコードを読む**。
- `RecknZkEscrow` は実 Groth16 proof で決済まで通っている（`Reproduced`→seller /
  `Failed`→buyer / binding 不一致 revert / 未検証 proof revert）。
- **`RecknZkEscrow` に timeout が無い**（proof が来なければ資金は永久ロック）。本体 `RecknEscrow` は
  timeout escape hatch を持つ（`contracts/README.md:12`）のに鍵の無い方だけが持っていない。
  → タスク 001。**未解決**。09-03 に `README.md` の `Known gaps (not closed)` へ明記した
  （隠さず先に書く。`no-keys.sh` は `refundAfterDeadline` を唯一の入口として既に列挙済み）。
- `program-svm` は ~980k cycles（ed25519 sigverify + lattice 再計算）。
- **本プロジェクトは一度もハッカソンに提出されていない。** `SUBMISSION.md` のプリフライトで
  "Repo public" と "Submission form" が未チェック、リポジトリは今も private。

## 検証済みの事実（2026-09-04 / 09-05 に追加、いずれも実測）

- **`no-keys.sh` が読むのは `RecknZkEscrow.sol` 1本だけ**。だが `settleWithProof` は
  `RecknVerdictVerifier.verifyVerdict` が返す struct に従う（`RecknZkEscrow.sol:99`）。
  **同じデプロイの内側にある別ファイルが決済権限を持っている。** → task 008 が閉じる。
- **`fallback()` / `receive()` は列挙に映らない**（`function` キーワードを持たないため）。
  **任意の funded deal を抜く fallback が4検査を全部通ることを実測。** → task 009 が閉じる。
- **`forge test --match-test` も `cargo test <filter>` も、一致ゼロで exit 0**（forge 1.7.1 実測）。
  **終了ステータスだけで判定する受入条件は、テストを1本も書かない実装で緑になる。**
- **`zk-verdict/scripts/zk-e2e.sh:83` は `forge test | grep … || true`** で終了ステータスを捨てる。
  README がワンコマンドのデモとして宣伝しているものが、**テストが落ちても緑に見える**。
- **Groth16 fixture 1本の end-to-end 再生成 = 335.02 s**（2026-09-04 実測、warm build、
  制約 15,972,262、うち証明生成 31.71 s）。`zk-verdict/README.md:97` の「~34秒」は
  **gnark wrap の部分だけ**で、しかも **predicate guest** のもの。re-execution guest は別物。
- **`RecknVerdictVerifier` の `verdictProgramVKey` は immutable で1つだけ**（`:40`）。
  1つの verifier は1つの guest しか裁定できない。009 はこれを**エスクロー側の immutable を消す**ことで回避する。

- **`Deal memory d` はコンパイルが通り、二重支払いになる**（009 r2 の発見）。`storage` でなく
  `memory` で受けると `d.state = State.Settled` は**コピーへの書き込み**になり、実際の state が
  変わらない。**左辺を「宣言子込みの逐語」で取る検査でないと捕まらない。**
- **`AGENTS.md` の各 gate は兄弟タスクの数を数えている。** 片方が patch やテストを足すと
  もう片方が赤くなる。**「総数がちょうど N」でなく「要求する id の集合が実在し全部 Success」で
  assert しろ**（orchestrator 裁定 2026-09-05）。総数の等式は、テストが1本消えて1本足された
  ケースを緑のまま通す——**集合の方が厳しい。**
- **9/9 のチェックポイントは「008 と 009 が*同時に*緑」。** 片方ずつ確認しても満たせない。
  009 の `both-green.sh` が兄弟 gate を閉包で発見して一括で走らせる形になっている。

## この repo で成立した規則（仕様レビューが生んだもの。AC を書く前に読め）

- **R-7**: 禁止リストを書くな。**性質で閉じろ。** 名前を1つ足せば破れる検査は検査でない。
- **R-8**: **呼び出し箇所の字句検査は被演算子を縛らない。**
- **R-9**: **自分の観測器を壊すことで満たされる基準は、基準ではない。**
- **R-10**: 検査の連鎖は repo の内側では終わらない。**どこで人に乗るのかを名指しで書け。**
- **R-11**: **攻撃者は観測器の存在を条件に分岐できる**（テストがローカルチェーンで走るなら、
  ローカルでない時だけ悪さをする実装は全テストを緑にする）。**除外で範囲を述べた検査は穴が空いている。
  左辺だけの pin は pin ではない。**

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
