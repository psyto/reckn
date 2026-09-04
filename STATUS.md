# STATUS — Reckn / ETHOnline 2026

**Phase 0 — Harness**（2026-09-03）

## 現在地

| | |
|---|---|
| イベント | ETHOnline 2026（9/4–16 async）、Continuity: **Ship a Feature** |
| 製品の事前作業の終端 | `a122b448887eb71b11f87c7d9cdf65afdc25fe69`（2026-08-02） |
| **`EVENT_START`** | **`121194ca3e25bab4ec92aaa4da1277f3a60b8421`**（2026-09-03 の最終 commit）。これ以降＝当日作業 |
| 当日作業の定義 | **日付が 2026-09-04 以降の commit のみ**（ハッシュでなく日付が一次） |
| 中心主張 | 判定する鍵が存在しない — `bash scripts/no-keys.sh` **PASS** |
| 凍結予定 | **9/12**（9/13–15 は R[3]sidency 締切 9/15 に明け渡す） |
| 撤退可能点 | **9/9** — **003（001 の受入条件を内包）が緑**でなければ founder 判断（`AGENTS.md` §7、2026-09-04 の実行順裁定に合わせる。旧文言「001/002 が緑」は使わない） |

## 完了

- Phase 0 — ハーネス: `AGENTS.md` / `CLAUDE.md` / `.claude/agents/` / `scripts/no-keys.sh`
- `scripts/no-keys.sh` は**負のコントロール3件**（`admin` フィールド追加 / 列挙外の関数追加 /
  `msg.sender` ゲート追加）で**いずれも正しく落ちること**を確認済み。
- 計画と事前開示文: `docs/ethonline-2026/{PLAN,DISCLOSURE}.md`
- **ドキュメント整合（9/3、事前作業／製品機能の変更なし）** — `README.md` に
  ①中心主張をビルド条件として明記 ②ETHOnline の境界（**当日作業=9/4以降の日付**、
  この README の内容は全て事前作業）③`Known gaps (not closed)`（**`RecknZkEscrow`
  に timeout が無く proof が来なければ資金がロックする**ことを含む）④欠けていた
  `zk-verdict/` とハーネスを Repository layout に追加 ⑤Collaboration model を
  「人間がリレーする」から現行ハーネスへ。あわせて `README:21` の
  「single instruction の PoC」を訂正（**EVM guest は実 revm を MPT 検証済み
  prestate 上で走らせている**。SVM 側だけが narrow slice）、`SUBMISSION.md` に
  未提出であることと ETHOnline が live entry であることを明記、
  `zk-verdict/program-revm/src/main.rs` の**コードに追いついていなかった**
  モジュールコメント（MPT 検証は「次に折り込める」→ 既に実装済み）を訂正。

## レビュー

| task | stage | round | verdict | 記録 |
|---|---|---|---|---|
| 003 key gauntlet（001 を内包） | spec | r1 | **CHANGES** | `docs/reviews/003-spec-r1.md` |
| 003 key gauntlet（001 を内包） | spec | **r2** | **CHANGES** | `docs/reviews/003-spec-r2.md` |
| 004 live adversarial input | spec | r1 | **CHANGES** | `docs/reviews/004-spec-r1.md` |

## 003 spec review r2（2026-09-04）— **CHANGES**

記録: `docs/reviews/003-spec-r2.md`（payload `/tmp/reckn-payload-003-spec-r2.md` /
Codex raw `/tmp/reckn-codex-003-spec-r2.md`、呼び出しは 1 回・`-s read-only`）。
対象 `docs/specs/003-key-gauntlet.md`（931 → **1642 行**）は `reckn-spec`（Claude Code）起草＝
Codex は自分の宿題を採点していない。Codex 4件 → 全件をディスクに当てて再現・採用（1件は severity を
証拠付きで BLOCKER→MAJOR に降格、1件は repro をより強い経路に差し替え）、**私の独立検出 10件**を追加。
残った **14 findings（BLOCKER 2 / MAJOR 7 / MINOR 5）**。

**founder 不確実点①（AC の5ゲートが「0件一致で緑」を構造的に不可能にしたか）は「半分」。**
5ゲートは*テストが0件*を不可能にしたが、*表明が0件*は通す——**ゲートはテスト名しか読まず、本体を
一度も開かない**。`test_AC02_G01_…() { assertTrue(true); }` を6本書けば AC-02 は緑で、**manifest も
総数も一切触らずに済む**（Σ=42 も AC-17=54 も保たれる）。仕様自身の AC-18 観測5（`:1157-1159`）が
「本体を `assertTrue(true)` にしても落ちる」と書いているが**それは偽**。実際に効いているのは AC-14
（mutation）だけで、文書はその逆を書いている。しかも **AC-8 だけが kill table に mutant を持たない**
（M-21 が `:782` と `:901` で別の変異を指し、`:1240` は AC-2 に割り当て）——C-4＝同一トークン drain の
修正を守る AC が、唯一 mutation の届かない AC になっている。**AC-18 は自己言及**でもある（`ac.sh` が
`ac-selftest.sh` を呼ぶので、退化した `ac.sh` は自分で自分を緑にできる。AC-0 のような直接実行行が無い）。

**founder 不確実点②（checks 9/10 が主張を弱めずに穴を塞いだか）は否。** 検査は**2つのメソッド名を
数えているだけ**で、資金は今も2経路で出る。①`fund` 内の
`if (amount == 0) { IERC20Min(token).approve(seller, type(uint256).max); }` — `msg.sender` も新関数も
継承も無く、**10検査すべてを通す**（本日サンドボックスで実測: `.transfer(`=2 / `transferFrom(`=1 /
fund 内 `.transfer(`=0 / fund 内 `msg.sender`=3、すべて適合、`no-keys.sh` exit 0）。攻撃者は
`fund(freshId, attacker, USDC, 0, binding)` で無限 allowance を得て、トークンを直接叩いて
**そのトークンの全 deal を proof も deadline も無しに抜く**。②`scripts/no-keys.sh:29` の走査は
`^contract RecknZkEscrow` から始まるので、**宣言より上に置いた library / file-level function の
`.transfer(` は本文カウントに映らない**（file 3 / body 2 を実測）。仕様は C-4 でこの死角を
**意図的に利用**（interface を上に置く）しながら §3.1:245 で「出口は増やせない」と書いている。
= **r1 finding 3 のメソッド名を1つ替えただけの再発**。なお**6検査の追加自体は既定挙動を緩めていない**
（interface / default target / exit semantics / 検査1-4の文面は不変、check 3 は check 7 と併存、
追加行は最終行の前）。N-9（target 引数を足さない）は正しい判断。

**その他の主要 finding**: ③§1.3 の exact-transfer 定義が**エスクロー側しか見ていない**ので、
受取側手数料トークンは定義を満たしたまま `amount − fee` しか払わず `Settled` になる（Codex 検出）。
④§2.3 は「deployer が選ぶ3つ」に**エスクロー bytecode を挙げておきながら**、直後の3点チェックから
落としている＝正規 verifier/vkey を晒した偽エスクローが seller の点検を通る。加えて `d.token` は
buyer が deal ごとに選び seller の受取可否を決めるのに点検に無く、**seller にとっては
「pre-funding」ではあり得ない**（terms は `Funded` イベントでしか届かない、OQ-4 が自認）。
⑤**OQ-6 の事実主張が偽** — 「この repo に実測 Groth16 proving wall-clock は無い」と書くが
`zk-verdict/README.md:97` に **~34 s**（同日の 004 r1 レビューが既に実測として引用済み）。
向きは珍しく**否定方向の過剰主張**だが §5 違反であることは同じ。
⑥C-5 の exact 一致を正当化する「M-23 を止めるのは upper bound」は、**§5.3:1245 が M-23 を AC-10 に
割り当てている**ことと矛盾（多 deal invariant が契約側の上限と無関係に殺す）。**exact を維持する結論は
支持するが、G-34/G-35 という 003 が作った恒久ロックを、文書自身が反証する論拠で正当化している。**
⑦N-5 の「seller-acceptance も trigger を持つ＝鍵だ」は広すぎる。**入る同意は結果を決める権限ではない**
（accept しない seller の帰結＝今日の「何もしない seller」と同一）。G-33 を disclosed に留める**結論は
003 の scope 内で正しい**が、OQ-4 が偽の前提（「中心主張の形が変わる」）に乗っており、founder が
将来これを見直せなくなる。

**tier 違反は発火せず**: 全 AC が Foundry/シェル、AC-16 は Honest scope 2ブロックを digest で凍結、
003 は1つも解消していない。⑤は実測値を**落としている**のであって tier を上げてはいない。

**算術は AC-14 以外すべて再計算一致**（35行 / 20-7-8 / manifest 21件 / Σforge tests=42 / 既存 suite=12 で
AC-17 の 54 が閉じる / `RecknZkEscrow.t.sol` は4テスト）。**forge 1.7.1 の挙動は本日再実測**
（`--list --json` は3階層・`invariant_*` を列挙・`--match-test` が一致・no-match で `{}`、run の key は
`name(sig)`）＝§5.0 のゲートは設計通り動く。落ちないのは AC-14 の数字だけ（41 / 42 / 46 の三重不一致）。

**003 spec r1（2026-09-04）— CHANGES。** Codex を独立レビュアとして1回呼び、5 findings を受領。
自分で行単位に裁定し、**12 findings（BLOCKER 3 / MAJOR 6 / MINOR 3）**を残した。Codex 由来は
5 件中 4 件を採用（1 サブ主張を証拠付きで却下）、残り 8 件は裁定側の発見。

BLOCKER の中身:

1. **18 AC のうち 11 個が「テストを一行も書かない」実装で緑になる。** `forge test --match-test`
   はパターンが何にも一致しないとき **exit 0**（forge 1.7.1 で実測）。§5 冒頭の
   「Every AC is a command whose exit status decides it」は 11 個について偽。
2. **AC-6 と AC-8 のコマンドは、テストが存在しても永久に0件一致。** `--match-test` は正規表現
   1本であり `"test_AC06 testFuzz_AC06"` は空白を含むリテラル。AC-6 は binding（INV-9＝製品の
   健全性そのもの）の受入条件で、書かれたままでは必ず空振り。
3. **`transfer` の呼び出し箇所を数える検査がどこにも無い**（Codex 発見、検証済み）。§3.1 の
   「出口は2箇所、AC-1 がビルド条件にする」は成立しない。`fund` 内に
   `if (address(uint160(0x1337)) == msg.sender) { transfer(msg.sender, balanceOf(this)); }` を
   置き `amount == 0` で呼ぶと全額を抜けて、`no-keys.sh`・AC 群・mutant 群を**全部素通り**する。
   = **中心主張が偽のままデモできる状態**。付随して、spec が「本プロジェクトが3回開けた穴」と
   呼ぶ M-1 も、それを殺すはずの AC-2（caller fuzz）では殺せない。

**scope（founder 不確実点②）は spec 側を支持**: `transferFrom` 戻り値未検査の修正は 003 の枠内。
今日の `RecknZkEscrow.sol:86` は false を捨てるので、revert しない偽トークンが**裏付けの無い
Funded deal** を作り、支払いが**同一トークンの他 deal の元本**から出る。全鍵を公開しながら
同一トークンの drain 経路を積んだ gauntlet は gauntlet ではない。**正しい切り口**（004 が守る線）＝
「003 が `RecknZkEscrow.sol` を変えてよいのは、変えなければ matrix の行が真の期待値を持てない箇所だけ」。

**再litigate 不要（検証済みで健全）**: 001 の4条件は G-11/G-13/G-14/G-16/G-17 に**弱まらず全て存在**、
AC-16 の SHA-256 は2本とも再計算一致、行列32行と 20/7/5 の内訳は機械再計数一致、mutant id は37個で一致、
INV-9 の binding 式は `program-revm/src/main.rs:178-190` と一致。

**founder 判断が要るもの**: ①短窓デプロイ開示の形（finding 7）②OQ-1 の署名付き anvil を作るか
（finding 8）③`no-keys.sh` に target 引数を入れること自体（finding 12、`AGENTS.md` §0 は
このチェックの緩和を founder 判断としている）。

## 004 spec review r1（2026-09-04）— **CHANGES**

記録: `docs/reviews/004-spec-r1.md`（payload `/tmp/reckn-payload-004-spec-r1.md` /
Codex raw `/tmp/reckn-codex-004-spec-r1.md`、呼び出しは 1 回・`-s read-only`）。
対象 `docs/specs/004-live-adversarial-input.md` は `reckn-spec`（Claude Code）起草。
Codex 8件 → 裁定後 **BLOCKER 5 / MAJOR 6 / MINOR 6**（Codex 由来 7件採用・1件を理由差し替えで採用・
1件を部分却下・1件を MINOR→MAJOR に引き上げ、**私の独立検出 6件**を追加）。

**founder 不確実点①（AC-3/AC-4 の対で退化実装を落とせるか）は否**: 再実行を 1 度も呼ばない
決定的な算術模型が **AC-0〜AC-16 を全部通る**。仕様は `reexec` の**形**しか固定しておらず、
`STATE_ROOT` の具体値も `gasUsed` の期待値も `traceHash` の関数形も committed でない。
AC-11(a) の静的リテラル検査は base64 化 1 行で抜けられ、AC-11(b) の 8/32 は
変奏器と判事を同じ実装者が書くので空白/大小文字偏重の変奏＋正規化判事で自作自演できる。

**founder 不確実点②（OQ-2）**: 実モデル不可なら、判事側は実装者自作の採点器なので
**判事だけを見れば strawman**。ただし **004 の核（散文は再実行を動かさない）は判事ゼロでも成立する**。
現状は §1 の見出し主張が「LLM 判事」と書かれており、**未決の OQ に主張が依存している**。
推奨＝見出しを判事非依存に書き直し、LLM 版を OQ-2 条件付きに落とす（founder 裁定）。

**新しい protocol 所見（004 の scope 外・deferred）**: spec §11 が挙げる `planHash` の
`gas_limit` 欠落は**正しい**。それより重い2件を追加検出 —
①`u64_low`（limb 0 のみ）と off-chain U256 の乖離は「verdict が乖離しうる」ではなく
**減少が最大 credit として証明される**（偽 release）向きを持ち、18 decimals の ERC-20 では
**残高 18.45 token 超で日常的に到達する**（＝ タスク 002 が正面から入る領域）。
②guest（`program-revm/src/main.rs:121-127`）は `chain_id` しか設定せず
`SpecId::default() == OSAKA` で走るのに対し、off-chain（`reexec-evm/src/lib.rs:489-512`）は
`anchor.spec_id`（現 fixture は `CANCUN`）と block env 全体を pin する。
**「同じエンジンが in-guest で走る」は現状 UNVERIFIED** であり、審査員に言ってよい文ではない。

**tier 違反は発火せず**: `~34 s` / `~6.2 GB` は `zk-verdict/README.md:97` `:105` の実測の引用で、
004 は「だから live loop に乗らない」という否定方向にのみ使っている。Honest scope は 1 つも解消していない。

## 次

1. **founder**: ETHOnline に応募（<https://ethglobal.com/events/ethonline2026>）
2. **founder**: 9/4 に `DISCLOSURE.md` を ETHGlobal へ送付
3. **`reckn-spec`**: `docs/reviews/003-spec-r2.md` の「What must change before round 3」10項目を
   `docs/specs/003-key-gauntlet.md` に反映 → `reckn-codex-review`(stage=spec, **r3**)。
   **blocking は2つだけ**: ①allowance 出口と走査域外出口を塞ぐ（or 出口が列挙されているという主張を
   取り下げる）②AC-18 観測5の偽文を削り、「format はテスト0件を防ぐが表明0件は防がない」と明記し、
   AC-18 に `ac.sh` 外の直接実行行を与え、全 forge AC に mutant を1つ以上持たせる
4. **`reckn-spec`**: `docs/reviews/004-spec-r1.md` の「004 に戻すときに直すもの」12項目を
   `docs/specs/004-live-adversarial-input.md` に反映 → `reckn-codex-review`(stage=spec, r2)
5. **founder 裁定（003 r2 追加）**: G-33 を disclosed に留めるのは**コストの判断であって
   中心主張の形の判断ではない**（finding 9）。OQ-6 は「実測が無い」ではなく「**~34 s は predicate guest の
   実測、`program-revm` は未測**」を前提に問い直す。OQ-1/OQ-2/OQ-3/OQ-5 は r2 で不変。
6. **founder 裁定**: OQ-2（`cli` 実モデル経路の可否。**004 の見出し主張がこれに依存**）／
   `u64`/`U256` 偽 release を**タスク 002 の前に閉じるか**（deferred D-2）
7. spec が APPROVE になってから `reckn-codex-impl`。**実装・コントラクトは未着手**（r2 の時点でも
   `RecknZkEscrow.sol` に変更なし）

## Day 1（2026-09-04）— 起点の記録

`EVENT_START = 121194c`。**これ以降の commit が当日作業**であり、以前は全て事前作業。

**9/3 の founder 裁定（`_applications/HANDOFF-2026-09-03-reckn-spec-timing.md`、22:15 作成）は
実行されていない。** 裁定は「仕様の事前執筆は開示すれば合法。9/3 に 001/002 の仕様を書き、
9/4 朝から実装に入る」だったが、Reckn の窓はその 25 分前（21:50）に最後の commit を打って
終わっていた。結果:

- `docs/specs/` `docs/reviews/` は**空のままイベントに入った**。仕様執筆は当日作業に食い込む。
- **ただし規約上の損失は無い。** 事前に仕様を書かなかったので、`DISCLOSURE.md` に
  追記すべき事前仕様も存在しない（裁定 §2(a)3 の追記は**不要**）。今日書く仕様は
  当日作業であり、開示の対象外。
- 失ったのは**正当性ではなく時間**。9/12 凍結までの実働8日のうち、初日が仕様に乗る。

裁定 §2(a) の規律更新（「境界をコードに引く」旨の `AGENTS.md` 追記）は、**この
イベントに対しては空振り**になった。次回イベントのために線を動かすかは founder 判断で、
今は当日作業を優先する。

## 未送付 / 未実行

- 事前開示の送付（founder の手）
- `psyto/reckn` の public 化（**提出時**、founder の合図で）
