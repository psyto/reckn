# CLAUDE.md — Reckn

## これは何か

エージェント間 (x402 型) 決済のエスクローで、**紛争の裁定者が決定的再実行**であるもの。
TEE の LLM 判事でも、自己申告フィードバックでも、監査不能な内部ループでもない。

> Every disputed agent payment is re-reckoned on-chain by replaying it. **Reproduce, or refund.**

**ハーネスと当日作業の規律は `AGENTS.md`。読んでから作業する。**

## いま走っている大会と、その規律（2026-09-12 更新。日付で失効する節なので、まず今日の日付と照らす）

| | |
|---|---|
| **ETHOnline 2026** | **提出済み**（Arc × Solana）。**判定窓 9/14 01:00 → 9/17 01:00 JST**（R1 非同期 9/14 04:00、R2 ライブ 9/15 01:00、Finale 9/17 01:00） |
| **Crypto World's Fair**（Colosseum） | 参加登録済み。**9/14 20:00 JST 開始 → 10/12 締切**。Tempo × Solana。規約 `docs/cwf-2026/RULES.md`、当日までの表 `docs/cwf-2026/PREFLIGHT.md` |

**① 9/14 01:00 JST から 9/17 01:00 JST は `master` 凍結**（founder 裁定 2026-09-12）。
CWF の作業は **`cwf-2026` ブランチ**に積み、Finale 後に日付を保ってマージする。
ETHOnline の審査員が見る `master` を、提出後に動かさないため。**9/13 までの commit は窓の内側**
なので `master` に入れてよい。**これを強制する検査は無い。枝が離れていることだけが機構である。**

**凍結中に `ac008.sh --all` / `ac009.sh --all` を始めない。** 21 個の mutation patch を
**追跡下のソースに当てては戻す**走行で、約75分かかる。途中で落ちれば**凍結しているはずのツリーが
変異したまま残る**——公開 repo が審査中に、当てたままの patch を晒す形になりうる。
同じ理由で、走行中は `zk-verdict/` 配下の検査結果を採用しない（下の節）。

**② CWF は「窓の内側で完成した作業だけ」を審査する**
（*"products are judged only on the work completed between the competition's start and end
dates"* — `docs/cwf-2026/RULES.md` §1）。主催者は「今すぐ始めてよい」と言っているが、
**早く終わらせた分は事前作業として扱われる**。したがって:

- **09-08 に着地した Tempo スライス（spec 011、実デプロイ、実決済2件）は CWF から見て事前作業**である。
  提出フォームの過去作業欄に書く。**当日作業として書かない**——規約が名指しで罰する不実表示になる。
- **spec 010（SVM token replay）の実装を 9/14 20:00 JST より前に始めない。** 仕様は 09-06 に
  書けている（＝事前作業の計画）。コードが窓の内側にあることが審査対象そのもの。
- 窓が開いたら最初に `bash scripts/cwf-baseline.sh --write`（境界の commit を記録。**開始前は
  書き込みを拒否する**）。提出時は `--diff` が窓の作業を git から出す。

**③ 2026-10-08 11:59:56 JST に、公開チェーン上で timeout 返金が初めて実演できる。**
Tempo の `mismatch` deal は 09-08 02:59:56 UTC から `Funded`（block 34352010、09-12 にチェーンから
読取）なので、`REFUND_AFTER = 30 days` が**CWF 締切の3日前**に満了する。誰でも呼べて、呼んだ人には
何も入らない。**011 §7.2 の「窓の内側では実演できない」は窓の内側で funded した deal の話**で、
この deal は窓が開く6日前に funded なので当てはまらない。**proof 由来の返金（T-2）と混ぜて書かない。**

## 中心主張（毎回確認する）

> **判定する鍵が存在しない。**

`zk-verdict/contracts/src/RecknZkEscrow.sol` は owner / resolver / admin / pause / upgrade を
持たず、`settleWithProof` は permissionless。決済権限は「proof が検証される」ことから来る。
`bash scripts/no-keys.sh` がこれをビルド条件として強制する。**commit 前に必ず走らせる。**

**009 後の決済（2026-09-06）**: エスクローは**2つの guest の proof を1つの契約で**決済する
（EVM と Solana、実 Groth16、`RecknCrossVmSettlement.t.sol`）。**constructor は無い**ので、
同じソースのデプロイは挙動として同一。**adjudicator は deal ごとに funder が指名**し、codehash で
固定される。

- **正しい文はこれ**: *funder が program を選び、その program が検査した proof が payout を選ぶ*。
- **書いてはいけない文**: 「proof 検証を飛ばす payout 経路は無い」。**偽である** ——
  buyer は `fund` で verifier を指名するので、sham を指名すればゴミで payout される
  （009 の AC-3 test 2 がその挙動を要求している）。
- **009 が新設した危険（seller 側）**: buyer が常に `FAILED` を返す verifier を指名でき、
  seller はタダ働きする。オンチェーンでは正直な `Failed` と区別が付かない。
- **「Solana の proof で決済」は anchoring の主張ではない**: guest は committed account set から
  `bank_hash` を再計算するだけで、それが実際の Solana クラスタのものだったことは 009 も示さない。
  *no bridge / no light client* は**裁定経路についての言明**。

**主張が住むファイルは1本ではない。** `settleWithProof` は
`zk-verdict/contracts/src/RecknVerdictVerifier.sol` の `verifyVerdict` が返す struct に従うので、
**その1本も同じ権限を持つ**。2026-09-05 の check 5 でそのファイルも検査領域に入った
（6つの性質で閉じる。禁止語リストではない）。

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
  `post` を導出する。**406,715 cycles**（2026-09-05 実測、`zk-verdict/cycles.json`）。
  → ルート `README.md` はこれを "a working proof-of-concept over a single instruction today" と
  書いていた（**SVM 側の話**で EVM には当てはまらない）。**09-03 に訂正済み。**
- `program-revm/src/main.rs` 冒頭のモジュールコメントは「MPT-authenticity は次に折り込める」と
  書いていたが、**その下の `verify_prestate_authenticity()` が既に実装している**。
  **09-03 にコメントを訂正済み。**
  → この2件は**コードでなくドキュメントが古かった**型。次に同じ疑いを持ったら、
  まず `git log -1 --format=%cd <file>` でなく**現物のコードを読む**。
- `RecknZkEscrow` は実 Groth16 proof で決済まで通っている（`Reproduced`→seller /
  `Failed`→buyer / binding 不一致 revert / 未検証 proof revert）。
- ~~**`RecknZkEscrow` に timeout が無い**~~ → **2026-09-06 に解消**。`refundAfterDeadline` が
  30日後に buyer へ返す（**誰でも呼べて、呼んだ人には何も入らない**）。待機期間はプロトコル固定で、
  deployer にも funder にも選ばせない。`AGENTS.md` §0 の列挙面に元から入っていた関数なので**主張は広がっていない**。
  以下は解消前の記録（本体 `RecknEscrow` は
  timeout escape hatch を持つ（`contracts/README.md:12`）のに鍵の無い方だけが持っていない。
  → タスク 001。**未解決**。09-03 に `README.md` の `Known gaps (not closed)` へ明記した
  （隠さず先に書く。`no-keys.sh` は `refundAfterDeadline` を唯一の入口として既に列挙済み）。
- `program-svm` は 986,097 cycles（ed25519 sigverify + lattice 再計算）。
- ~~**本プロジェクトは一度もハッカソンに提出されていない**（2026-09-07 現在も未提出）~~
  → **2026-09-12 更新: ETHOnline 2026 に提出済み**（Arc × Solana、Continuity: Ship a Feature）。
  **「未提出」と書かない。** 判定日程は下の「いま走っている大会」節。
  **リポジトリは 2026-09-04 に public 済み**——応募が現物のソースに対して審査されるようにするため、
  提出時でなく前倒しで公開した。**「今も private」は偽**なので、そう書かない。
  **提出フォームは 2026-09-06 に入力済み**（description は `DISCLOSURE.md` の全文再掲）。
  ~~**⚠ 開示文と現実にずれがある**（`DISCLOSURE.md` §3-5 が Arc を括弧書きに埋め、§3-3 が
  「LLM 判事を説得する」と約束している）~~ → **2026-09-07 に解消済み。この警告自身が古かった。**
  `DISCLOSURE.md` に **§0 Amendments** が新設され、§3-3 と §3-5 の両方が、**旧文面を引用した上で**
  修正されている（Arc が見出しになり、World AgentKit と Hedera は 09-06 の裁定で落としたと明記）。
  `PREFLIGHT.md:172` も "World AgentKit — **No.** Never built" と書いている。
  **教訓**: この警告は毎セッション読み込まれるので、古い警告は古いコードより高くつく。
  同じ疑いを持ったら、まず現物の `DISCLOSURE.md` を開く。
  **編集権限（2026-09-08 更新）**: founder 判断で **`docs/ethonline-2026/` は編集可**になった
  （`AGENTS.md` §8 の禁止を founder が解除）。ただし**送信済みの内容は別**——書き換えたら
  `AGENTS.md` §4 のとおり送付済みとの差分を記録する。**送信済みの「計画」を結果に合わせて
  後から書き換えるのは、規約が名指しで罰する不実表示**なので、やらない（実際に起きた変更は
  Amendments に追記する形で扱う）。

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
  **2026-09-07 に達成**（`8d5355a`）: `ac009.sh --all` → `13/13 rows passed`、AC-12 が
  `both-green: 2 sibling gate(s) discovered, 2/2 exit 0`。005 も同じ走行に入っている。
  **走行は実時間8時間かかった**（夜間スリープ込み）ので、凍結前の最終走行は一晩仕事として計画する。
- **★同じ形の欠陥で2回死んだ（2026-09-06〜07）: 正しい文の下に、名前を並べたコードが座っている。**
  `ac008.sh` の AC-13 witness は `*.patch`（36本）を見ていたが §7.2 は `[0-9][0-9]-*.patch`
  （21本）と正しく書いてあった。`ac009-selftest.sh` の M-13 サンドボックスは
  `rm -f ac008.sh ac008-selftest.sh` と名前で書いていたが §10 は「009 の scripts *だけ*」と
  正しく書いてあった。**どちらも兄弟 gate がちょうど1本の間は原理的に不可視**で、005 の gate を
  足した瞬間に両方が1回の走行で出た。**閉包が閉包であることを証明する行（M-13）自身が、
  名前を1つ足されて破れていた**（R-7）。→ **仕様が性質で書けていても、コードが名前で書いて
  いれば検査ではない。母集団が1のうちは両者を区別できない。**

## Arc（task 005、2026-09-06 に founder が唯一のスポンサー統合として固定）

- **Arc では USDC がネイティブガストークン**（18 decimals）で、Circle が同じ残高への
  **ERC-20 面を `0x3600000000000000000000000000000000000000` に predeploy**している（**その面は 6 decimals**）。
  ラップド USDC は存在せず、必要でもない。chain id **5042002**、RPC `https://rpc.testnet.arc.io`、
  explorer `https://testnet.arcscan.app`、faucet `https://faucet.circle.com`。
  **mainnet アドレスは 2026-09-06 時点で未公開**（"not yet available"）。出典は
  `zk-verdict/contracts/arc.json` に日付つきで転記。
- **`RecknZkEscrow` は無変更で USDC を決済できる。** deal ごとに支払いトークンを指名する設計だから。
  **payable 経路を足すのは関数面の追加＝中心主張の変更**（`AGENTS.md` §0）なので、やらない。
- **Hedera はスコープ外**（同じ裁定）。x402 有料サービス、Blocky402、消費 agent、Hedera デプロイは作らない。
- 実演は `bash scripts/arc-usdc-e2e.sh`（鍵も資金も不要、chain id 5042002 のローカル anvil）。
  **これは Arc testnet の結果ではない**——ローカルの再現であって、誰かがデプロイした証拠ではない。
- **【2026-09-06 更新】Arc testnet に実デプロイ済み。** escrow `0x580f2c32…`、**実決済4件**
  （EVM proof→seller / EVM decrease→buyer / **SVM proof→seller** / **SVM below-floor→buyer**）。
  さらに1件が Circle の USDC blacklist で seller 側が凍結され 1.00 USDC のまま残っている
  （`refundAfterDeadline` でのみ戻る。**隠さず `arc.json` に記録**）。
  上の「鍵も資金も持たない」は**当時の停止条件であって現状ではない**ので、そう書かない。
- **★実 tx hash は手で転記するな。** 4本のうち2本を記憶から書いて間違えた（長さも prefix も
  正しく、リンク先だけ存在しない）。`zk-verdict/scripts/arc-receipts.sh` が両方向で閉じている
  （repo 内の arcscan リンクは全部 `arc.json` が記録した hash か / 記録した決済は全部
  どこかにリンクされているか）。**検査されない領収書は、領収書が無いより悪い——証拠に見えるから。**

## この repo で成立した規則（仕様レビューが生んだもの。AC を書く前に読め）

- **R-7**: 禁止リストを書くな。**性質で閉じろ。** 名前を1つ足せば破れる検査は検査でない。
- **R-8**: **呼び出し箇所の字句検査は被演算子を縛らない。**
- **R-9**: **自分の観測器を壊すことで満たされる基準は、基準ではない。**
- **R-10**: 検査の連鎖は repo の内側では終わらない。**どこで人に乗るのかを名指しで書け。**
- **R-11**: **攻撃者は観測器の存在を条件に分岐できる**（テストがローカルチェーンで走るなら、
  ローカルでない時だけ悪さをする実装は全テストを緑にする）。**除外で範囲を述べた検査は穴が空いている。
  左辺だけの pin は pin ではない。**

## 変異走行中は、zk-verdict の検査を信じない（2026-09-08 に実害が出た）

`ac008.sh --all` と `ac009.sh --all`（後者は `both-green` 経由で前者を呼ぶ）は、**21個の
mutation patch を作業ツリーのソースに当てては戻す**。対象は
`zk-verdict/program-revm/src/main.rs` / `lib/src/lib.rs` / `script/src/lib.rs` /
`reexec-evm/src/lib.rs` / `contracts/src/*` など。**約75分かかる。**

**その間、そこを読むあらゆる検査が「もっともらしい嘘」を返す。** 2026-09-08、担当外の窓が
走行中に `docs-check.sh` を実行し、**`cycles.json matches 2/3 guests`（従来 3/3）と2分の
タイムアウト**を得た。`cycles.json` は正しく、guest ELF が変異ソースからビルドされていた
だけ。**症状が「エラー」でなく「本物の回帰に見える数字」だったので、調査に時間が溶けた。**

- **走行を始めるときは、他の窓に告げる。** 書き込みが衝突しなくても、**読み取りが汚染される**。
  走行前に「編集しているファイル」だけを照合して安全と判断したのが、この失敗の直接の原因。
- **走行中は `zk-verdict/` 配下の検査結果を採用しない**（`docs-check.sh` / `surfaces.sh` /
  `fixtures-check.sh` / `ac0*.sh`）。`dashboard/` と `docs/` は影響を受けない。
- 静止しているかは副作用なしで判る:
  `git diff --quiet -- zk-verdict/program-revm/src/main.rs zk-verdict/lib/src/lib.rs zk-verdict/script/src/lib.rs reexec-evm/src/lib.rs`
- **`ac009` は自分でツリーの移動を検出し、"a red row here may be drift, not a defect.
  Re-run on a still tree before believing any failure." と言う。その行を信じる。**
  実際 2026-09-08 の走行はこれで AC-12 を赤にしたが、静止ツリーで個別に再実行すると
  `ac011` 8/8・`ac004` 4/4・`ac005` 4/4 で全部通った。
- **ゲートは自分が裁くツリーを汚してはいけない。** `ac011` は `tempo-verify.sh` と
  `tempo-tip20-probe.sh` を呼ぶが、両者は毎回レコードを書き換えていた（タイムスタンプと
  発見したホルダー）。**それ自体が親のドリフト検出を壊す。** いまは `RECKN_NO_WRITE=1` で
  読み取り専用に走らせる。ツールとしての書き込み経路はそのまま残っている。

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
