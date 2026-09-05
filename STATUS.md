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
| 撤退可能点 | **9/9** — **`008` と `009` の両方が緑**でなければ founder 判断（`AGENTS.md` §7、2026-09-04 の応募提出に合わせて `003` → `009` に差し替え。`003` は撤退判定の対象外だが **9/12 の凍結までに着地させる対象**。旧文言「001/002 が緑」「008 と 003 が緑」は使わない） |

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
| 003 key gauntlet（001 を内包） | spec | **r3** | **CHANGES** | `docs/reviews/003-spec-r3.md` |
| 003 key gauntlet（001 を内包） | spec | **r4** | **CHANGES** | `docs/reviews/003-spec-r4.md` |
| 003 key gauntlet（001 を内包） | spec | **r5** | **CHANGES** | `docs/reviews/003-spec-r5.md` |
| 003 key gauntlet（001 を内包） | spec | **r6（hard stop）** | **CHANGES → founder** | `docs/reviews/003-spec-r6.md` |
| 004 live adversarial input | spec | r1 | **CHANGES** | `docs/reviews/004-spec-r1.md` |
| 004 live adversarial input | spec | **r2** | **CHANGES** | `docs/reviews/004-spec-r2.md` |
| **008 verdict domain soundness** | spec | r1 | **CHANGES** | `docs/reviews/008-spec-r1.md` |
| **008 verdict domain soundness** | spec | r2 | **CHANGES** | `docs/reviews/008-spec-r2.md` |
| **008 verdict domain soundness** | spec | **r3** | **CHANGES** | `docs/reviews/008-spec-r3.md` |
| **008 verdict domain soundness** | spec | **r4** | **CHANGES** | `docs/reviews/008-spec-r4.md` |
| **008 verdict domain soundness** | spec | **r5** | **CHANGES** | `docs/reviews/008-spec-r5.md` |
| **008 verdict domain soundness** | spec | **r6（hard stop / 時刻上限）** | **APPROVE** | `docs/reviews/008-spec-r6.md` |
| **009 cross-VM settlement** | spec | **r1** | **CHANGES** | `docs/reviews/009-spec-r1.md` |
| **009 cross-VM settlement** | spec | **r2** | **CHANGES** | `docs/reviews/009-spec-r2.md` |

## 009 spec review r2（2026-09-05）— **CHANGES**

記録: `docs/reviews/009-spec-r2.md`（payload `/tmp/reckn-payload-009-spec-r2.md` /
Codex raw `/tmp/reckn-codex-009-spec-r2.md`、**呼び出しは 1 回・`-s read-only`**。
1回目は自分の 10 分タイムアウトで**出力ファイルが1バイトも生まれないまま kill** されたので
detached で再投入した＝答えられた呼び出しは 1 回）。
対象 `docs/specs/009-cross-vm-settlement.md`（**2049 行**）は `reckn-spec`（Claude Code）起草＝
**Codex は自分の宿題を採点していない**（payload §0 に明記）。

**findings 10件（BLOCKER 3 / MAJOR 4 / MINOR 3）。r1 の 15件のうち BLOCKER 3件は実際に閉じた**
（7f の 9/8 再計数を自分で走らせて一致・命名 regex・§1.4 の新設）。**残った 3 BLOCKER は
閉じた 3 件と同じ形**——閉じた境界の外に穴が残る、gate が自分の文書を通れない、不変条件を
自分の AC が否定する。

1. **[BLOCKER] entry-point closure の**領域**が閉じていない**（`009:1260`/`:1377`/`:1410`）。
   7h・7i・check 2 clause 2a は全部「`contract RecknZkEscrow` 行から下」を読む。**継承した
   `fallback` はその行より上に置ける。** `/tmp/sbx009` で実際に**コンパイルして排水させた**:
   `[PASS] test_inherited_fallback_drains_a_funded_deal (gas: 1712521)` — 任意アドレスが
   32 byte の dealId を生 calldata で送るだけで funded deal を全額奪う。proof も binding も
   state guard も `msg.sender` gate も無い。**そのファイルに対し no-keys.sh 4検査と AC-7 の
   9 clause が全部緑**で、AC-7 が出す evidence 行は manifest の要求文字列と**バイト一致**:
   `function 2 (fund settleWithProof) other entry keywords 0 sum 2, 0 assembly 0 using`。
   排水は**インライン assembly を使う**のに 7i は `assembly 0` と印字する。r1 finding 4
   （「列挙は閉包でない」）が**一段上で再発**。INV-12 / INV-8 / §3.6.2 の「閉包が届かない範囲」
   も同時に偽。**塞ぎ方は小さい**: `contract RecknZkEscrow` と `{` の間の正規化テキストが空
   （継承指定なし）＋ファイル内 `contract` は1つ＋`using` はファイル全体で数える。
2. **[BLOCKER] §7.8 の抽出規則がこの文書自身で落ちる**（`009:1668`）。「§7 内の backtick で
   囲まれ `test_AC` で始まるトークン」を機械適用すると **20 件中 4 件が regex に不一致**
   （`test_AC` / `test_AC01_…` / r1 の却下名 ×2）で、`_AC03_` の件数も 2 でなく 4 になる。
   `ac009.sh --check` が常に落ち、**どの row も走れない**。r1 finding 2 を止めるために作った
   gate が、その中で同じ矛盾を再生産している。**塞ぎ方**: §7.1 が manifest を fenced block に
   しているのと同じく、16 名を fenced `ac009-testnames` block に置いて §7.8 はそこだけ読む。
3. **[BLOCKER] INV-2 が偽で、009 自身の AC-3 test 2 がその否定を「正しい挙動」として要求する**
   （`009:762` vs `:1172`、§4.4 B-1 `:666`）。INV-2 は *"there is no path to a payout that
   skips proof verification"* と書くが、buyer が `AlwaysReproduces` を `fund` で指名すれば
   garbage で seller に払われる。**設計は否定しない**（registry は鍵・vkey 引数は founder 案件・
   escrow 2本立ては deployer が VM を選ぶ＝同じ反論が一段上に出るだけ）。偽なのは**文言**で、
   しかも **§11(4) が実装者にその偽文を `CLAUDE.md`（中心主張が住むファイル）へ書けと指示している**。
   **009 が新たに作った危険は seller 側**: 009 前は escrow の verifier が全 deal 共通だったので、
   再現した seller は必ず払われた。009 後は buyer が常に `FAILED` を返す sham を指名でき、
   seller はタダ働きさせられる。INV-11/L-4/L-7 は checklist と sham を書くが、**「これは 009 が
   新設した能力だ」とは書いていない**。

**MAJOR 4件**: ④どちらの fixture も「その guest が作った」と紐づける criterion が 009 に無い
（`xvm.pinned` は path を1つも固定しない。看板の主張が**ファイル名に乗っている**）。
⑤AC-12 は §8.2 が言うほど強くない — founder が OQ-6 で認めた並行実装の木では
`0 sibling gate(s) discovered, 0/0 exit 0` の**空虚な緑**、`siblingGates` は検査対象自身が書き
何も検証しない、sibling の exit 0 は中身を保証しない、そして**未記載: `ac008.sh --all` は
`008:1439` で canary を in-tree に patch するので `ac009.sh --all` が作業ツリーを書く**
（§7.0 の "No file under the repository is written" は selftest の話で、checkpoint 命令の話ではない）。
実行時間も未測定（008 の gate は ELF 再ビルド込み）。
⑥**counted surface の棚卸しが3件足りない** — `008` AC-14 の docs-check（009 §11 が書き換える
まさに4文書＋`no-keys.sh` に 9 absent / 11 present を要求）、`008:1936` の転記済み digest literal、
`008` の forge selector 件数。OQ-8 の *"the only counted surface … cannot repair"* は偽。
r1 finding 3（完全と称した棚卸しが不完全）の**2度目**。ただし **AC-12 が commit 時に全部赤にする**
ので機構は効いており、直すのは §1.4/§10/OQ-8 の記述。
⑦INV-5 は ERC-20 モデル無しで価値保存を無条件に主張（`transferFrom` が false を返せば
**何も引かずに Funded** が立つ／出金側 `transfer` が false なら**誰にも払わず Settled**。
L-7 は入金側しか書いていない）。

**MINOR 3件**: ⑧INV-7「`msg.sender` はちょうど2回」は**3回**（今日の contract でも §3.3 でも。
`grep -c` 一発。r1 finding 1 と同種＝走らせず転記した数）。⑨`defence in depth` の grep は
009 自身の R-7 基準では denylist（"a secondary safeguard" で破れる）。⑩L-16 の residual が
また実際より小さい（R-11 で観測器に分岐すれば `if (block.chainid != 31337) transfer(...)` は
lexical にも behavioural にも捕まらない）。

**却下**: ①Codex の「predicate fixture `groth16-fixture.json` を差し替えれば AC-0b/1/2 が通る」
— 実測、**その fixture は `deal_binding` key を持たない**ので clause 2 の parse で落ちる
（一般論としての「path が固定されていない」は finding 4 として採用）。②「`008` AC-11/AC-13 の
witness（`*.t.sol` / `*.patch` の glob）が衝突する」— 両側が run time に再計算するので自己修復。
009 の CS-1 の分析が正しい。③Codex の finding 1 を「設計の BLOCKER」とする枠 — 文言の
BLOCKER（finding 3）へ再スコープ。④Codex の「§7.8 は r1 の矛盾を直した」— finding 2 で反証。

**founder への回答 — OQ-8: orchestrator の裁定では閉じない。** `008` は suite 総数を**2箇所**に
固定しており両方 009 が触れない文書の中にある: 本文 `008:2548`（*"must report **18** results"*）と
§6.1 manifest の evidence cell `008:1276`。`ac008.sh` は **stdout がその evidence 行を逐語で
含むこと**を要求する（`008:1213-1216`）ので、id 集合で assert する 008 実装は**自分の
dispatcher に一致しない行を印字する**。つまり「総数でなく id 集合で」は **`008` の承認済み
manifest を編集しない限り実装不能**で、それは `AGENTS.md` §2 の実装エージェントの役割ではない。
**必要な founder 指示は1行**: 009 が着地する commit で `008:2548` と `008:1276` の `18/18` を
base 実測トークン（`003` の `{P}` 形）に置き換える権限を `008` 側に与えること
（= 009 自身の推奨1、`009:2038`）。加えて裁定が届かない2件（`008` AC-14 の文書 marker と
`008:1936` の digest literal）は finding 6 として 009 が棚卸しに足す。

**OQ-1（拡大）: 009 の整理は正しい。**4行とも実在サイトであることを確認
（`003:1382` check 8 / `003:512`・`003:515` / `003:904`・`003:908` / `verifier()` は
`forge inspect` に今日も出る）。`003` は §7 で停止中・9/9 gate 外なのでコストは繰延。
**tightening 維持の推奨に同意。**再開時は finding 1 の remedy により check 8 を
constructor 本体でなく**領域の性質**へ張り替えるべき、を付記。

**9/7 に間に合わなかった場合の2分類**（founder 裁定でその仕様のまま実装に入る場合）:
**実装中に必ず閉じる** = finding 1（領域閉包。これだけは開示で済まない。`AGENTS.md` §0 の
ビルド条件が偽陽性を返す）、finding 2（`--check` が通らない＝全 row が走れない）、
finding 3（実装者が偽文を `CLAUDE.md` に書くよう指示されている）、finding 4 の安い半分
（fixture の2 path を literal で固定）。**開示で足りる** = finding 4 の深い半分（L-12 拡張）、
finding 5 の (a)〜(e)、finding 6 の棚卸し訂正、findings 7/8/9/10、繰延2件
（EIP-6780 の資金凍結、破棄された ERC-20 boolean）。**verdict によらず founder 指示が要るのは
OQ-8 の1行。**

10件中6件（1,3,4,5,6,10）が **009 に有利な方向**の誤り、KILL 方向は0件。r1 と同じ分布。
**round 2 は r1 から実質的に大きく前進している**（7f 再計数・E-13〜E-16 の再現・§5.3 の撤回・
§1.4 新設は本物の仕事で、r1 の 4 BLOCKER のうち 3 は閉じた）。残る3件はどれも
アーキテクチャではなく、1周で閉じられる。**r6 hard stop まで残り 4 周、時刻上限は 9/7。**

## 008 spec review r6（2026-09-05）— **APPROVE**（実装開始可）

記録: `docs/reviews/008-spec-r6.md`（payload `/tmp/reckn-payload-008-spec-r6.md` /
Codex raw `/tmp/reckn-codex-008-spec-r6.md`、**呼び出しは 1 回・`-s read-only`**）。
対象 `docs/specs/008-verdict-domain-soundness.md`（**4283 行**）は `reckn-spec`（Claude Code）起草＝
**Codex は自分の宿題を採点していない**（payload §0 に明記）。Codex は 3 findings（BLOCKER 1 /
MINOR 2）と 8 件の確認を返し、**BLOCKER は severity を再導出して採用、MINOR 1件は枠組みを証拠付きで
却下し鋭い半分だけ採用**、私の独立検出 4 件を追加。**残った 6 findings（MAJOR 1 / MINOR 5）**。

**`AGENTS.md` §7 の round 6 hard stop、かつ 9/5 founder 裁定の時刻上限下。round 7 は無い**ので、
verdict より重要なのは分類。判定基準は founder が与えた
*「実装者がこの文書だけを読んで作業した結果、中心主張が偽のまま緑になる経路が残っているか」*。

**答えは No。推論でなく実行して確かめた。** §6.4 5f の5段抽出規則を文面から実装し、現物に
§3.4 の `uint64`→`uint256` を当てて走らせた結果:

- **20片が転記どおりの順序で完全一致**、5b の**43 トークン**も一致。
- R-10 item 7 の2つの構成（`{ }` 挿入 / contract を早く閉じて `verifyVerdict` を自由関数化）が
  **どちらも20片と43トークンを完全再現**——起草側の自己申告どおり。
- **M-15 は発火する**: `reexec-groth16-fixture.json` の `trace_hash`(`0x4e7b1345…`) ≠
  `deal_binding`(`0x81899ffc…`) なので、member 入れ替えで `v.dealBinding` が ABI word 5 を
  decode し `RecknZkEscrow.sol:103` が `BindingMismatch` で revert する。
- **r5 の代案却下は正しい**: `RecknReexecVerdict.t.sol:27-30` / `RecknZkEscrow.t.sol:43-47` は
  JSON から fixture バイトを読む＝**Rust encoder の変更は forge に届かない**（AC-09 が赤になるだけ）。
- M-21 は 5f を分離している（`minDelta`/`maxDelta` は escrow もテストも読まない）。
- manifest 算術（18行 / cargo 91 / forge 6 / script 8）を手で再計算し全部閉じる。tier 違反なし。

**それでも MAJOR 1件。決定的なのは「限界の記述」がまた一箇所だけ偽だったこと。**

1. **[MAJOR / 実装中に必ず閉じる] `:3582` と `:4242` の残余の見積もりが偽。** 両方が
   *「permuted struct は通さない、M-21 が piece 5,6 を M-15 が 8,9 を動かすから」*と書くが、
   これは**位置比較**にしか成り立たない。**隣接関係**で書いた 5f——片数20と
   (`minDelta`,`maxDelta`) / (`traceHash`,`dealBinding`) の隣接だけを見る実装——は
   **M-15 も M-21 も落としながら、`uint8 outcome` を先頭へ動かす金の動く順列を通す**。
   実測（`full-5f` = 仕様どおり / `degenerate-5f` = 隣接版）:
   `outcome-to-head` は 5b **PASS** / full-5f **REJECT** / degenerate-5f **PASS**。
   → 正直な `Failed` の proof が seller に払い、`no-keys.sh` は 0 で抜ける
   （`AGENTS.md` §6 の commit 儀式は `forge` を走らせない）。
   **BLOCKER にしなかった理由**（Codex は BLOCKER と主張、severity のみ却下）: 仕様本文
   `:1683-1684` / `:1710` / stop rule `:1839-1846` は**曖昧さなく完全な順序付き等式**を命じており、
   `full-5f` 列は全順列で REJECT。**仕様どおりに書いた実装からは緑かつ偽の木に到達できない**。
   穴は「実装が仕様に従わなかった場合を gate が捕まえられない」側にあり、**§7.7 `:3624-3628` と
   §7.8(d′) はその degenerate をすでに名指しし、抽出コードの貼付を義務づけている**。
   偽なのは**残余の見積もり**であって機構ではない——そして founder はその文で **OQ-7** を裁定する。
2. **[MINOR ×5]** `:3338`/`:2807` の「M-19 は denylist を落とす唯一の mutant」は偽（**M-21 も落とす**
   ＝過小申告方向の誤り）／`:3821` §8 R-10 が「**Six** things」と書いて **7項目**を列挙
   （§9 が honest scope へ**逐語コピー**する対象）、同段落の「Two of the three regions」も
   「None」が正しい／`:3527` L-3 が step 0 のパッチ数を **18** と書く（`:2660` と `:3296` は **21**）／
   `:3684` §7.8(c) が `sandbox control clean` を **3行**と書く（§7.7 `:3596` は **6行**）／
   `:1325` の「sandbox は1つ」と、M-19 が名乗ってよい clause の §7.3 row 4（5b/5d）と
   phase 19g（5b/5d/**5f**）の食い違い。

**実装者への義務（仕様はもう直せないので、レビューが代替）**: ①5f は**添字付き20要素等式＋長さ表明**で
書く（隣接・部分集合・部分文字列検索は不可）②check 5 が `skeleton:` digest を印字し、selftest が
**自分で** `$S` から計算して照合（8g/18g/20g と同じ器具。ただし**印字だけでは不十分**——Codex の
指摘どおり、正しく抽出して印字しつつ部分集合で判定できる）③phase 21 に**生成した位置ごとの摂動**
（i と i+1 を入れ替えて 20 回、パッチファイル0本・ビルド0・数秒）を足す＝**OQ-7 の (b) が 65 mutants と
値付けした性質を、ほぼ無料で買う**④impl review は 5f の**実コードを引用**して pass/fail で書く
⑤実装報告に `:3582`/`:4242` が偽だったことと訂正文を書く。

**却下した findings**: Codex の BLOCKER severity と「OQ-7 の選択肢集合の不完全さ自体が blocker」
（証拠: `full-5f` は全順列で REJECT、仕様本文が完全等式を命じている）／Codex の
「denylist は round 6 後は 18 行を通らないので `:2814` が誤り」（証拠: `:2814` は M-19 導入の
反実仮想で、**同じ段落の次の文が M-19 で落ちると書いている**。真の誤りは `:3338` の唯一性主張）／
**私自身の payload 仮説**（「skeleton digest を印字させれば OQ-7 は安く閉じる」）——**Codex が正しく反証**
（印字は判定を縛らない）。記録に残す。／brace nesting が悪用可能という説（両モデルとも構成できず。
起草側の `:1833-1841` の両方向の書き方は**正しい**）／`remappings.txt` は R-10 item 3 で開示済み。

**founder が実装前に答える必要があるもの**: **OQ-7（ただし訂正後の残余で）**、OQ-1、OQ-2、OQ-3、
OQ-4（OQ-4 は round 5 で実装義務が付いたので**受諾が既定**、override だけが founder 判断）。

## 009 spec review r1（2026-09-05）— **CHANGES**

記録: `docs/reviews/009-spec-r1.md`（payload `/tmp/reckn-payload-009-spec-r1.md` /
Codex raw `/tmp/reckn-codex-009-spec-r1.md`、呼び出しは 1 回・`-s read-only`）。
対象 `docs/specs/009-cross-vm-settlement.md`（**1291 行**）は `reckn-spec`（Claude Code）起草＝
**Codex は自分の宿題を採点していない**（payload §0 に明記）。**15 findings（BLOCKER 4 / MAJOR 6 /
MINOR 5）**。Codex 7件のうち **5件を採用**（うち2件は severity を降格、1件は **repro を実測で却下して
差し替え**）、**私の独立検出 4件**を追加。

**★Codex の「破れなかった」リスト3件のうち2件が偽**——`§3.3` の代入数と AC のテスト名。どちらも
Codex を読む前に機械的に検出済み。**中継でなく裁定した価値はここに出た。**

**BLOCKER 4件（round 2 でこの順に閉じる）:**

1. **009 が着地すると `008` が赤になる**。009 は 12 個の mutant を `zk-verdict/scripts/mutants/` に置くが、
   `008` の `ac008-selftest.sh` step 0 は同ディレクトリの `*.patch` が**ちょうど 21 個**であることを
   assert する（`008:2620`）→ 33 個で AC-13 失敗。さらに `008` の AC-11 は suite 総数 **18/18** を
   evidence 行に literal で持つ（`008:2500-2508`）→ 009 が 16 テスト足して 34 で失敗。
   **9/9 のゲートは「008 と 009 が*同時に*緑」なので、ファイル名一つで到達不能になる。**
   009 の OQ-6 は「共有ファイルは `RecknZkEscrow.t.sol` だけ」と書くが、実際に衝突する3面
   （mutants ディレクトリ / suite 総数 / `scripts/no-keys.sh`）は**どれも名指しされていない**。
   **独立性を片方向でしか検定していない。**
2. **AC-7 の 7f の数値が §3.3 自身のコントラクトに対して誤り**。仕様の規則をそのまま適用すると
   **9 代入 / 8 ターゲット**（`Deal storage d = …` と `VerdictPublicValues memory v = …` が抜けている）。
   manifest の evidence は `7 assignments over 6 targets` で機械比較されるので **AC-7 は初日から赤**。
   実装者の最短経路は「7 になるまで観測者を鈍らせる」＝ **R-11(iii) の穴そのもの**。
3. **仕様が定めたテスト名が、仕様が定めた命名 gate に落ちる**。
   `test_AC03_settleWithProof_has_no_adjudicator_parameter` は `^test_AC[0-9]{2}[a-z]?_[a-z0-9_]+$` に
   非適合（大文字 `W`/`P`）。AC-3 は 2/2 に到達不能。
4. **AC-7「escrow の shape は閉じている」が閉じていない**。`fallback()` / `receive()` は
   `function` キーワードを持たないので `no-keys.sh:46` の列挙に**見えない**。
   `fallback() external { IERC20Min(deals[abi.decode(msg.data,(bytes32))].token).transfer(msg.sender, …); }`
   は **no-keys.sh 全4チェックと 009 の全12 AC を通過**して任意の funded deal を抜く（実測: コンパイル成功、
   check1 no match / check2 は列挙せず / check3 no match / check4 は 0,0 / **7f は代入ゼロで盲目**）。
   §7g が書く残余（「代入されない state 変数」）より実際の残余がはるかに大きい。

**MAJOR 6件:** §4.4 の barrier 表が製品主張を反転（**SP1 検証を "defence in depth" と書いている**）/
`L-7`「sham verifier を選んだ buyer は自分の金しか失わない」は**プール残高＋不正確な ERC-20 で偽**
（fee-on-transfer で他 deal の裏付けが削れる。コード修正は `003`、**偽の文は 009 のもの**）/
T-7「あらゆる対象 EVM で到達不能」は **tier を超えた主張**（EIP-6780 の同一 tx create→fund→destroy で到達可能、
ただし **Codex の Foundry repro は実測で再現せず**——codehash も codesize も変わらない——ので AC 化は不可）/
§3.6 の tightening 論法は**述語としては正しい**（集合は厳密に縮む、確認済み）が結論「全ての消費者は影響を受けない」が偽
（コメント除去器が文字列 `"//"` で破れる・check 2 は名前しか見ない）/ AC-10 の sandbox に
**`ac009.sh` が parse する仕様ファイル自体が入っていない**ので走らない / §1.3 の「003 の再レビューは不要」が偽。

**却下**（証拠付き）: Codex の overload BLOCKER の「AC-1…AC-6 は緑のまま」は**偽**——
`escrow.settleWithProof.selector` が `Error (6675): Member "settleWithProof" not unique after
argument-dependent lookup` でコンパイル不能（実測）。009 の gate は捕まえる、捕まえないのは
**commit 前の儀式だけ**。Codex の T-7 repro も実測で再現せず（`evm_version` `osaka`/`shanghai` 両方で
codehash 不変、`code.length == 129`）。

**破れなかったもの（本日再測定、過去 round の数字は引用しない）**: E-3 `12` / E-4 `fdcef1bb` /
E-5 storage 1 entry / E-8 `keccak256("")` / **E-9（immutable が違えば codehash が違い、同じなら同じ。
address も deal が固定するので adjudicator は一意に決まる）** / E-10・E-11（`view` 型経由は STATICCALL で
revert、非 `view` 経由は成功） / manifest 算術 12・16・6・5・12 / 7a・7c・7d / **`008` の literal はゼロ** /
**INV-10 は 008 の再型付けを生き延びる**（メンバ名は変わらない）。

**founder への論点**: **OQ-A（新規）** — finding 4 の修正は `no-keys.sh` check 2 にも入れるべきか
（`008` が同じスクリプトを今週触る）。**推奨: 入れる**——`fallback` は生きた資金経路で、
commit 前の儀式が今それを見られない。**OQ-1** は 009 の推奨（tightening を維持）で正しいが、
`003` が失うものは §1.3 の1行より大きい（check 7b/8・5部構成の deployment 検査・G-33/G-37・ROLE 表）。
**OQ-6 は「はい、ただし理由が違う」**——技術的独立性（INV-10）は**確認できた**が、
**finding 3 を直すまでハーネス上は独立でない**。

## 003 spec review r5（2026-09-04）— **CHANGES**

記録: `docs/reviews/003-spec-r5.md`（payload `/tmp/reckn-payload-003-spec-r5.md` /
Codex raw `/tmp/reckn-codex-003-spec-r5.md`、呼び出しは 1 回・`-s read-only`）。
対象 `docs/specs/003-key-gauntlet.md`（**4245 行**）は `reckn-spec`（Claude Code）起草＝
**Codex は自分の宿題を採点していない**（payload §0 に明記）。Codex 5件のうち **4件が検証を通過**
（うち2件は **repro を却下して私の repro に差し替え**、1件は severity 主張を却下）、**私の独立検出 1件**を追加。
残った **6 findings（BLOCKER 2 / MAJOR 2 / MINOR 2）**。**round 6 が hard stop**（`AGENTS.md` §7）。

**r5 は r4 の 11件に全部答えており、答えは散文でなく機構だった。**手で再測定して確認: check 14 は
r4 の「found sound」注記が増えただけ、**9c / 9b-range は 1バイトも動いていない**、§5.4a は r4 finding 5 が
要求した箇所（**contract 単位の probe** / `--match-test` + **parsed JSON** / `^SweepProbe_` を column read から除外）
だけが変わっている。**「本体機構は触っていない」という自己申告は本当**。文書内算術も全部閉じる
（matrix **39**行 = 21/7/10/1、`T` = **59** = 1+19+25+14、forge AC の `tests` 合計 **46**、
manifest の rows union は matrix の 39 id と集合一致、corpus **19**+control **4**、sweep columns **29**）。
**008 由来の literal は 1つも残っていない**（digest / suite 数 / binding 前像 / 幅、全て `{P}` `{S}` と
`docs/gauntlet.base.json` への参照に置換済み）。

**それでも CHANGES。決定的な2件は、どちらも「境界が閉じたのでなく動いただけ」。**

1. **[BLOCKER] check 15 は代入の*左辺*しか縛らず、`constructor` を明示的に除外している**
   （`docs/specs/003-key-gauntlet.md:1528-1552`）。`verifyVerdict` が呼ぶ `ISP1Verifier` の**アドレスは
   constructor で選ばれる**（`RecknVerdictVerifier.sol:38,42-45`）。15c は `verifyVerdict` の本体だけ、
   15e は「constructor と verifyVerdict の外」、15f の denylist に `if` / `?` / `block.` / アドレス即値は無い。
   → `constructor { if (block.chainid == 31337) { verifier = _verifier; } else { verifier = 0x…1337; } … }`
   は **15a〜15f を全部通り、しかもデモ chain では正直に振る舞うのでローカルのテスト行列も全部緑**。
   別 chain では鍵無しの偽 verifier が全 deal の verdict を決める。P5 の
   *「定数アドレスが住める分岐は存在しない」*（`:1478-1483`）は**偽**——分岐は constructor にある。
   §2.3(A) の4点デプロイ検査に `RecknVerdictVerifier.verifier()` が**入っていない**ので人の検査でも捕まらない。
   **これは r4 finding 1 の一段外での再発**（r4=決済権限が検査対象ファイルの外へ出た /
   r5=ファイルは入れたが**信頼する呼び先を選ぶ領域**が中に残った）。
   閉じ方は round 6 で足りる: 15c と同じ形を constructor に当てる＋デプロイ検査を**5点**にする
   （＋`gauntlet.json` と money-shot に SP1 verifier アドレスを印字）＋corpus/mutant 各1＋count 3つ再導出。
   ついでに **check 8 も同型**（エスクロー側 constructor も左辺しか見ていない）。

2. **[BLOCKER] 洗浄防止機構が「上書きを拒否」で、洗浄経路は `rm`。しかも AC-16 の `Falsify:` が
   逆の結果を主張している**（`:281-284`, `:2659-2662`, `:3884-3886`, `:4196`）。
   README を緩めて **commit → `rm docs/gauntlet.base.json` → `--measure`** で、
   working tree / `git show <base_commit>:…` / 記録値の**三者が全部新しい基準で一致**し、
   `base_commit` は当然 HEAD の祖先なので AC-16 は緑になる。`--measure` は存在しないファイルを
   上書きできない。**R-6 は全 `Falsify:` を実行して非ゼロを観測する義務**を課すので、
   結果が逆の `Falsify:` は誤記でなく**壊れた計器**。§9.1 P0 は「削除して測り直すな」と*指示*しているが、
   **R-10(i) が要求しているのは機構**。Codex の「これは founder 判断が要り 003 単独では閉じられない」は**却下**——
   `git log --diff-filter=D/A` で「base file は一度だけ追加され一度も削除されていない」を assert し、
   `--measure` に**クリーンツリー条件**を付ければ閉じる（後者は今の設計だと汚れたツリーで P0 を回せてしまい、
   赤くなるのが P8 まで遅れる問題も同時に消す）。

MAJOR 2件: ③**AC-17 は既存テストの「件数」と 4つの「名前」しか pin していない**ので、
`RecknReexecVerdict.t.sol:47` の改竄検知テストを消して同ファイルに通るテストを1本足せば `{S}` も status も
名前4つも無傷で緑（P0 は既に `--list --json` を回しているので**テスト id の集合**を記録するだけで閉じる）。
④**stripper の「バックスラッシュ escape を尊重する」節だけ corpus witness が無い**——
`string memory ref = "a \" // b"; IERC20Min(token).transfer(seller, amount);` は escape を見ない
one-pass scanner で `.transfer(` が消え、E-17 と同じ結果になる（**Codex の repro は exit を次行に置いており
`//` は行末までしか消さないので却下**、同一行の形に差し替えた）。

MINOR 2件: ⑤§8 の*「"impossible" は §5.0.1 とその再掲にしか現れない」*は Appendix C を書いた本 round で偽になった
（4122/4125/4181/4243）——**実質的な規律は健全**で、位置の主張が drift しただけ。
⑥`no-keys.sh` の check 15 と `gauntlet.sh --check` の check 15 が**別物なのに同じ名前**で相互参照されている。

**健全と確認して記録（round 6 で再審理しない）**: (a)/(b) の判断は正当
（適用した基準＝*製品上の理由で remedy を選んでよいのは開示集合が縮まない時だけ*。(b) の開示文は
§8 / §2.3(A) / §7.2 に**全部残っている**）。check 15 の 008 安定性の主張は正しい
（008 は struct の**数値幅4つだけ**を順序を変えずに変更し、15a は header 行、15e は contract 内部しか見ない）。
observer 4件の答え（witness / outside-in control / parsed JSON / 式による class count）は機構であって文章ではない。
§8 の*「003 は証拠を捏造する実装者に対する防御ではない」*は**正直さであって穴の正当化ではない**
（末端の artefact 1つを名指しし、R-10(iii) がそれを要求している）。**ただし finding 2 は別物**——
あちらは「機構が塞いでいる」と*主張*しており、それは許されない手。R-8/R-9/R-10 は互いに矛盾しない
（**finding 1 は R-8 の反例でなく実例**）。timeout 設計は不変（`refundAfterDeadline` は誰でも呼べる、
G-16/G-17 で settle と排他、G-11 が期限境界を fuzz）。tier 違反なし。

**OQ-8（008 が着地しなかったら）の整理は正しく、founder に渡す形として十分。**
§1.5 の測定機構により 003 はどちらのツリーでも正しい。ただし2点だけ足す:
(a) を選ぶ場合の*「truncation を画面に出す」*は**まだどこの義務でもない**（§7.2 に行が無く、
AC-16 は「変えていない」しか pin しない）ので round 6 で §7.2 に書く必要がある。
そして*「003 の主張は鍵についてであり 008 と独立」*は真だが、これは `AGENTS.md` §5 が警告する
「主張を後から狭める」型そのものなので、**壇上で言えるかを決めるのは founder であってエージェントではない**
（r5 はそれを決めなかった。正しい）。

**round 6 で閉じるのは上の6件だけ。** これ以外の新しい機構設計を開いたら §7 の hard stop で
論点を開いたまま founder に返す。

## 003 spec review r4（2026-09-04）— **CHANGES**

記録: `docs/reviews/003-spec-r4.md`（payload `/tmp/reckn-payload-003-spec-r4.md` /
Codex raw `/tmp/reckn-codex-003-spec-r4.md`、呼び出しは 1 回・`-s read-only`）。
対象 `docs/specs/003-key-gauntlet.md`（3171 行）は `reckn-spec`（Claude Code）起草＝
**Codex は自分の宿題を採点していない**（payload §0 に明記）。Codex 4件は**全件が検証を通過**し
採用（2件は訂正・拡張のうえ）、**私の独立検出 7件**を追加。
残った **11 findings（BLOCKER 2 / MAJOR 4 / MINOR 5）**。

**r4 は、エスクロー本体の縫い目が初めて再び開かなかった回。** r3 finding 1/2/3 への3つの閉鎖
（check 9c＝`function` キーワードの閉鎖 / check 14＝代入左辺の閉鎖 / §5.4a＝setUp probe）は、
`RecknZkEscrow.sol` の内側では**手検証で破れなかった**（`using for` / 継承 / library / `type(…)` /
`abi.encodeWithSelector` / modifier（`deals` と命名したものを含む）/ 関数型 struct フィールド /
2つ目の `Deal storage` を全て個別に当てた。**どの棄却も名前に依存していない**）。

**そして今回の決定的な2件は、その本体の話ではない。枠の縁で破れている。**

1. **[BLOCKER] 決済権限の経路が、検査対象のファイルの外に出る。**
   `scripts/no-keys.sh:19` の対象は `RecknZkEscrow.sol` **1本だけ**。しかし `settleWithProof` は
   `RecknVerdictVerifier.verifyVerdict`（`RecknVerdictVerifier.sol:50-57`、同じディレクトリ、
   **監査対象のデプロイの内側**）が返す struct に従う。そこに定数キーの分岐を1つ足せば、
   名指しされた1アドレスが**任意の funded deal を proof 無しで両方向どちらにも決済できる**＝
   resolver そのもの。14 checks 全通過・18 source mutants 全通過・16 corpus 全通過・
   fuzz は 2^-160（**R-5 自身の規則**）・kill table に当該ファイルの mutant は**ゼロ**。
   G-29 は「**自分で**別のエスクローをデプロイ」の行、G-37 は「別 bytecode のエスクロー」で、
   どちらも**この経路ではない**。§8 の「this file の外は frame の外」の一文だけが掠っており、
   ファイル名を書いておらず、money-shot には反映されていない。
   → 閉じ方は2択（(a) check 15 を追加＝`no-keys.sh` は自分の位置から target を導出しているので
   **引数追加ではなく N-9 に触れない** / (b) frame 外と裁定するなら §8・§2.3(A)・§7.2 に明記）。
   **どちらでもよいが、無言は不可。**

2. **[BLOCKER] 003 は「008 の後に走る」と自分で書きながら、008 以前のツリーに対して書かれている。**
   `AGENTS.md` §3 の実行順は `008` → `003`。008 の OQ-2 は
   *「これは実装開始前に答えが要る唯一の未決。003 がやることを変えるから」*と 003 に宛てて書いている。
   003 の §1.5 は**3つのうち1つ（`surfaces.pinned`）にしか答えておらず、しかもパスが違う**
   （008 は `zk-verdict/scripts/` に置く。003 は `ls scripts/` を見て「存在しない」と書いた）。
   実測で確認した食い違い: **既存テスト数 12 → 18**（008 が 6本追加。003 の 58 は **64** になる。
   `suite: 58/58 passed` と `control 58/58 pass` は `ac.sh` が**逐語比較**する manifest 文字列）、
   **Honest-scope digest**（008 が書き換えると明言。003 の AC-16 は旧値を literal で pin し
   「003 では変わらない」と書いている＝初日に赤、しかも通す唯一の道が「pin した digest を編集する」
   ＝AC-16 が禁じている当のこと）、**binding が v1 → v2** で式の形自体が変わる（003 の INV-9）、
   **`VerdictPublicValues` が `uint64` → `uint256`** で `u64_low` 切り捨てが消える
   （003 の INV-10 と §8 の「003 の後も全く同じに真」）。後半3つは**何にも検査されない散文**として出荷される。
   → 修正は「008 の数値を貼る」ではない（008 は審査中で、その literal はまだ事実でない）。
   **003 側を測定に変える**: §1.5 に再測定義務、AC-16 の digest は base commit で印字、
   AC-17/AC-21/§7.1 の総数は `46 + <測定値>`、INV-9/INV-10/§8 は参照で書く。

**MAJOR 4件**（いずれも「観測する側」の欠陥。R-9 が言う *criterion satisfied by breaking its own
observer* の形）: ③ `script` AC の evidence 規則にある *「何も走らせていないスクリプトはこれを
印字できない」*（`:1236-1237`）が**偽**——2行の echo で `mutation-kill.sh` と
`degeneracy-sweep.sh` を置換すると **AC-14 と AC-21 が緑**になる。この2つは §5.0.1 が
*「gap を狭める道具はこの2つだけ」*と名指ししている当のもの。r2 finding 2 で削除した文と
**同型の文が一段上に再発**（AC-1 は AC-14 の Falsify で守られている＝Codex の主張を1件訂正）。
④ **stripper の2つの区切り族が互いに当てられていない**——コーパス E-15/E-16/C-S は
文字列だけ・コメントだけで、実際のバグ族である**交差**（文字列の中の `//`、コメントの中の `"`）が
無い。`string memory ref = "https://reckn.dev"; IERC20Min(token).transfer(seller, amount);`
は、コメント先・文字列後の2パス実装（**今日の `no-keys.sh:30` がまさにその形**）で `.transfer(` が
消え、**14 checks 全通過のまま `fund` から資金が出る**。⑤ `SweepProbe_F is FTest` は
**継承したテストも全部走る**ので probe を exit status で読めず、pin された `control 58/58` も
到達不能。⑥ AC-14 の mutant クラス内訳（23/16/8）と**レビュア再現コマンドの注記 `# 48`** が
1ラウンド古い（実測 `T` = **52**、§5.4a は 24 と書いていて文書内で矛盾）。

**MINOR 5件**: AC-21 散文の 44/56 と D-4 の「expected 56」/ §4.5.1 の3操作の順序と check 9 の
range が collapsed テキスト上で未定義 / 列除外リストに上限が無い（`SWEEP_EXEMPT.txt` は 2 で上限）/
§8 の *「C-5 がその mutant を隠すから証拠は無い」*は事実より強い（`==`→`>=` ＋ outbound-fee token は
**隠れない**。§4.1 が既にそう書いている）/ AC-10 の handler 義務2つに instrument が無い。

**却下ゼロ。訂正2件**（Codex の「AC-1 も同型」は誤り＝AC-14 の Falsify が守る。
Codex は 008 依存の**最大の項目である既存テスト数**を落としていた）。

**残り 2 round。** 本体の機構が破れなかったのは初めてで、findings 1/2 はどちらも縁の編集で
範囲が限定されている。r5 で閉じられる形。ただし **MAJOR 3〜6 は全て「観測者」に関する主張**であり、
この文書の履歴では観測者こそ次の層が隠れている場所。

## 003 spec review r3（2026-09-04）— **CHANGES**

記録: `docs/reviews/003-spec-r3.md`（payload `/tmp/reckn-payload-003-spec-r3.md` /
Codex raw `/tmp/reckn-codex-003-spec-r3.md`、呼び出しは 1 回・`-s read-only`）。
対象 `docs/specs/003-key-gauntlet.md`（2555 行）は `reckn-spec`（Claude Code）起草＝
**Codex は自分の宿題を採点していない**（payload §0 に明記）。Codex 3件は**全件が検証を通過**し
採用（1件は根拠と被害経路を差し替えて強化）、**私の独立検出 5件**を追加。
残った **8 findings（BLOCKER 3 / MAJOR 3 / MINOR 2）**。

**BLOCKER 3件の性質**: r3 は禁止リストを捨てて property P（ファイル全体で呼び出し形トークンを
許可リストに閉じる）を書いた。**方向は正しい。破れ方が一段下がっただけで、まだ開いている。**

1. **`L_plain` が `transfer` を含まざるを得ず、それ自体が抜け穴**（`:795-796`, `:871`）。
   check 12 が `IERC20Min` に `function transfer(...)` の宣言を要求する以上、その宣言行が
   平文呼び出し `transfer(` を生むので 9b は `transfer` を拒否できない。関数型ローカルを
   **`transfer` という名前で**宣言して `IERC20Min(token).transfer` を代入すれば、9a は
   メンバ**参照**（`;` が続く）を見ず、9b は許可名を見る。13 チェック全通過で
   `no-keys.sh` は exit 0。被害は同一トークンの pool 全額（`fund` で入れて即出し→無担保 deal→
   期限後に他の deal の元本から払い戻し、原資は戻るので無料で反復可能）。
   仕様自身の corpus E-11 が「ポインタ名が `f` だから落ちる」と書いており、**改名で無効化する**。
2. **`fund` から他 deal の storage を書き換えられる**（`:646-649`, `:386`, `:605-610`、私の検出）。
   `deals[dealBinding].seller = seller;` は**呼び出し形トークンを一つも生まない**ので checks 9/11/12
   は原理的に見えない。`fund(freshId, attacker, token, 0, victimDealId)` で被害 deal の seller を
   奪い、正規の proof が attacker に払う。**INV-2 は §4.4 で唯一 `Mechanically:` も
   `Behaviourally:` も持たない不変条件**で、AC-11 は同一 dealId しか見ず、AC-10 の invariant には
   「funded deal の struct は不変」が無い。§3.1.3 は class C（`fund` 経由の状態汚染）を
   網羅したと書いているが、**別 key への書き込みは matrix に無い**。
3. **AC-21 が空アサーションを殺せない**（`:1802`, `:1813-1814`, `:1915`, `:1941-1942`）。
   28 列のうち **M-34（全関数 body が `revert()`）が `setUp` を壊す**ので、その列では
   44 テスト全部が Failure になり、「1列以上で Failure」という唯一の述語が中身に関係なく充足される。
   setUp-safe の保証は §5.4 の SW-1…SW-5 **5列にしか掛かっていない**。AC-21 自身の Falsify
   （6本を `assertTrue(true)` にすると非ゼロ）は**成立しない**。r2 finding 2 の穴が一段上で再開。

MAJOR 3件: ①M-23 は post-003 の contract では **C-5 に隠される**ので「AC-10 が C-5 と独立に殺す」は
偽（`:531-534`, `:1397`）。r2 finding 8 の符号違いの再発。②check 11 は `src`（文字列リテラル除去済み）
に対して**文字列を含む import 行**の完全一致を要求しており、実ファイルで通らない（`:732` vs `:822`）。
③コメント/文字列除去器が property P 全体を支えているのに未規定で、corpus には**過剰除去の対照が無い**。

**tier 違反なし**。OQ-6 の切り分けは正しい（`script/src/bin/evm.rs:25` は `verdict-program`＝
predicate guest、`reexec.rs:41` が `verdict-program-revm`。~34 秒は前者、後者は未測定）。
Honest scope の 2 digest は再計算して一致。文書内の算術（`T`=48 / Σ=44 / 56 / 37 行 / 20・7・10）
も全部閉じる。`AGENTS.md` §0 の surface 変更は D-10（`:2367`）に宣言済み。

**round 4 は短いはず**: BLOCKER 3件はいずれも1節＋corpus/mutant 1件の局所修正で、
matrix・manifest・算術・開示・honest-scope 凍結は検証に耐えた。**r6 hard stop まで残り 3 周。**

## 008 spec review r5（2026-09-05）— **CHANGES**

記録: `docs/reviews/008-spec-r5.md`（payload `/tmp/reckn-payload-008-spec-r5.md` /
Codex raw `/tmp/reckn-codex-008-spec-r5.md`、**呼び出しは 1 回・`-s read-only`**）。
対象 `docs/specs/008-verdict-domain-soundness.md`（**3619 行**）は `reckn-spec`（Claude Code）起草＝
Codex は書いていないので独立レビューとしてフル適用（payload §0 に明記）。**次が hard stop（r6）。**

**r4 の 9件は全部閉じている。** 仕様の実測値は全て今日再測定して一致した——43トークンの語彙、
引用符行1・`/*` 0・`*/` 0、代入5、`verifyVerdict` 本体の `;` 2、r4 splice の **+5** と
`verifyProof` 削除の **−1**、`surfaces.pinned` の2 digest、line 711 の一意性、AC-14 の
9 literal / marker 8–11 不在 / tilde 14（naive 正規表現は 12）/ `~34 s` ちょうど1。
**数値の誤りは1件も無い。findings は全て「その数値から何を結論したか」の側にある。**

**findings 6件（BLOCKER 2 / MAJOR 2 / MINOR 2）。**

1. **[BLOCKER] M-15 の因果が偽——検証者の定数を入れ替えても AC-10 は落ちない。**
   `RecknZkEscrow.sol:25-26` は**自前の** `REPRODUCED`/`FAILED` を宣言し `:109-112` はそれと比較する
   （`:4` の import は contract 型と struct だけ）。よって M-15 は誰に払うかを変えず、AC-10 の4本は
   緑のまま → AC-13 が miss を記録 → 仕様自身の規則で **stop**。**AC-10（money-shot を持つ行）が
   実質無 mutant。** 修正は M-15 の付け替え（~10分）。
2. **[BLOCKER] check 5 は3領域を「除外」でしか pin していない**——struct のメンバ列、定数2つの**値**
   （**10進 literal は5節のどれからも不可視**）、constructor の代入の**右辺**。実測で確認: struct を
   `outcome` 先頭に並べ替えた版が **5a–5e を全て通る**（語彙43は集合として一致、宣言数一致、本体2文一致、
   代入5・LHS一致）。`verifyProof` は本当に呼ばれ `dealBinding` は語6のままなので escrow の binding は通り、
   `pre == 0` の deal に対する**本物の `Failed` proof が seller に払う**。
   **003 r6 の生きている BLOCKER と同族**（`to` の右辺が無拘束 = R-11(iii)「左辺だけの pin は pin ではない」）
   で、これが3例目。**`ac008.sh --all` は落ちる**（AC-10 test 1/3 が捕まえる）——だから Codex の
   「check 5 だけで決まる」枠組みは却下したが、**`no-keys.sh` は commit 前とデモ時の器具**であり
   `AGENTS.md` §6 の commit 儀式に `forge test` は無いので、**exit 0 が「主張はまだ真」を表示する側が
   偽になる**。加えて文書は3箇所でこの穴の**逆**を書いている（R-10 item 4 の「同じものを計算する」、
   §8 R-10 の非成立4項目、5d の「早期離脱の第3の道は無い」）。OQ-5/OQ-6 が記録した
   **「自分に都合の良い方向の列挙」の4例目**。
3. **[MAJOR/must-fix] check 5 が「性質」実装か「禁止語 grep」実装かを分ける mutant が無い。**
   M-17 は `tx.origin` splice なので denylist でも検出でき、18行すべて緑のまま
   `AGENTS.md` §0 に出荷される「禁止語の列挙ではなく閉包性質」が**偽の木**が作れる。
   §7.8(d)(4) がレビュアに渡す2つの witness（`block.chainid` / `assembly{origin()}`）も
   denylist に捕まるので**判別しない**。判別する witness は文書内に既にある（AC-0 Falsify 3 =
   `verifyProof` 文の削除）。修正は sandbox mutant **M-19** 1本（zero-build、phase 17 の使い回し）。
4. **[MAJOR] 「R5 に mutant は作れない」は偽。** founder の OQ-5(b) 却下は**リポジトリの** pin を
   変える設計についてのもので、**sandbox 内のコピー**には移らない。clean control 済みの `$S` で
   `surfaces.pinned` のコピーだけを1文字変えれば、正しい実装は非ゼロ＋**変わっていない** target digest を
   印字し、heredoc 実装は **0 で抜ける**——「全実装が落ちる」ことはない（誤ったファイルを digest する実装は
   8d で harness failure になる）。phase 20 を1本足せば R5 は「読んで確認」から機械検査に移る。
5. **[MINOR]** §7.8 は「§7.8 が守られなかったことを誰が検出するか」を書いていない（終端は founder）。
   Codex の「§8 に移せ」は **却下**——§8 は honest scope に逐語で写る節で、r3 が §7.6/§8 の分離を健全と
   確認済み。
6. **[MINOR]** 「003 の literal は1つも持ち込んでいない」と書きながら 003 の R-7 を逐語引用している。

**Codex の裁定。** BLOCKER 1件（struct 並べ替え）は**本物だが severity の根拠は作り直した**——
Codex 自身の実例は AC-10 test 1 が捕まえる。そして **Codex の「確認済み」5件のうち1件が偽**:
*「M-15 の定数入れ替えは escrow の比較を誤らせる」*は**逆**で、それが上の BLOCKER 1。
**誤りの向きは案を通す方向。** §7.8 への remedy も却下。**独立レビューが決定的な finding を出しつつ、
同じ出力の中で仕様を通す方向に誤る**——両方向に裁定が要ることの実例として記録する。

**round 6 の見積り（9/9 に間に合わせる観点）**: BLOCKER 2件は「1節＋sandbox phase 1本」と
「mutant の付け替え」で、MAJOR 2件は**どちらも zero-build の sandbox phase 1本ずつ**。
mutant は 18 → 20（項目2が mutant 形を取れば 21）、**manifest は 18行のまま、cargo 91 / forge 6 は不動**。
AC-13 の 40分 budget は Groth16 の**再生成回数**で律速されており、**budget を上げて吸収しない**。
**founder に要る答え**: 項目2の形（5f で締めるか、R-11(iii) の最小＝3文の訂正＋R-10 に3項目追加＋OQ 化か）。
OQ-1 / OQ-2 は r4 から不変。OQ-4 は round 5 で初めて実装義務が付いたので**受諾が既定**。

## 008 spec review r4（2026-09-04）— **CHANGES**

記録: `docs/reviews/008-spec-r4.md`（payload `/tmp/reckn-payload-008-spec-r4.md` /
Codex raw `/tmp/reckn-codex-008-spec-r4.md`、`-s read-only`）。
対象 `docs/specs/008-verdict-domain-soundness.md`（**2744 行**）は `reckn-spec`（Claude Code）起草＝
Codex は書いていないので独立レビューとしてフル適用（payload §0 に明記）。

**Codex 呼び出しは実効 1 回。** 1回目は**私のハーネスの 10 分上限で kill され出力ファイルが
生成されなかった**（返答ゼロ）。同一 payload を編集せずバックグラウンドで再発行し 1 回返答。
気に入らない答えの再実行ではない。監査できるよう記録する。

**findings 9件（BLOCKER 1 / MAJOR 3 / MINOR 5）。r3 の 7件は全部閉じている**
（sandbox の control→mutation 順・4入力・Location rule、`:600` の byte-identical 訂正、
AC-11 の glob、testkit 配置、host-only 限定の3箇所、§7.5 の条件付き化、いずれも現物で確認）。
2 digest と line 711 は再計算して一致、cargo 91 と mutant 16 の内訳も再計算して閉じる。

1. **[BLOCKER] `RecknVerdictVerifier.sol` が決済権限の経路上にあり、008 がそれを編集するのに、
   008 のどの受入条件も守っていない。** `no-keys.sh:19` は `RecknZkEscrow.sol` しか読まず、
   AC-0b は2ファイルしか pin せず、§7.1 のファイル表にこのファイルが**無い**（§3.4 `:465-469` で
   `uint64`→`uint256` に変えるのに）。M-15 は定数を入れ替えるだけで分岐に届かない。
   `verifyVerdict` に `tx.origin` 分岐を差し込むと `verifyProof` に到達せず、
   `settleWithProof` は偽の `Reproduced` で seller に払う。**008 の全 AC が緑のまま。**
   `:1842` はこの事実（`no-keys.sh` がこのファイルを読まない）を書いた上で**逆の結論**を出している。
   003 r5 が同じ穴を自分の BLOCKER 1 として check 15（P4/P5）で塞いだが、**実行順は 008 → 009 → 003**
   なので 2タスク分あいたままになる。r5 の閉じ方は 003 の property 対を 008 に写し、
   zero-build の sandbox mutant を1本足すこと。`AGENTS.md` §0 の surface に2つ目のファイルを
   宣言するかは **founder 判断**。
2. **[MAJOR] AC-00b は digest を一切計算しない `surfaces.sh` で満たせる。** M-8 が証明するのは
   「**名指しされた1つのコメント**が変わると exit status が変わる」だけ。`grep -q '<そのコメント>'`
   で足りる（Location rule 準拠・8d 通過・8g 非ゼロ＝検出扱い）。`surfaces.pinned` を読まない実装が
   通るので **r2 finding 6 の修正（digest を仕様の literal にした意味）が再び開く**。加えて
   **AC-0b の第2節（`head -710`）にはどの mutant も当たらない**（M-16 は `:1954` で 711 行より下と
   明記）。この節が守るのは差分テストの**基準側**＝`reexec-evm::replay` で、緩めば「guest でなく
   oracle を直して通す」経路が空く。r5: 8g で `computed:` の digest 出力を要求＋sandbox 第2段で
   711 行上を変異＋`surfaces.pinned` を読むことを検定対象にする。
3. **[MAJOR] 「実装レビューが読んで走らせる」を唯一の信頼の根に据えながら、その義務がどこにも無い。**
   L-3（`:2393-2408`）はそう書くが、§7.7 が縛るのは**実装者の報告**だけ。2本の echo スクリプトで
   §7.7 の証拠行は全部貼れる。r5: stage=impl レビューの義務（自分で読む・自分で走らせる・
   自分の run の per-mutant 行を `docs/reviews/008-impl-rN.md` に記録・報告だけの受理は受理でない）を
   仕様に1節足す。**「人が読む」設計自体は受け入れる**（再帰は repo の内側で終わらない）。
   受け入れられないのは、その人が指名されていないこと。
4. **[MAJOR] INV-11 と §8 前文が偽で、しかも何も検出しない。** 「§8 の residual は全部 §9 の
   honest scope に逐語で出る」と書いてあるが、**R-7（`min == 0` は no-op を許す）はどこにも
   開示されていない**（`grep` で0件）。AC-14(ii) の marker 7本にも無い。OQ-4 の推奨は
   「`min == 0` は合法のまま **R-7 を開示**」なのに、その開示を実装する義務が §9 に無い。
   なお OQ-4 の「`zk-verdict/README.md:143` が不可能と宣伝している」は**過大**——143 行は
   `min ≥ 1` の fixture の話で普遍主張ではない（正直な方向の訂正）。
5–9. **[MINOR]** INV-14 の量化子が **AC-00b について今度は偽**（sandbox 化で M-8 は repo の
   1バイトも動かさず、8h がそれを assert する。守りは 8g の exit status 側にあり実在するが、
   INV-14 が挙げる機構は発火しない＝r3 finding 2 と同型の再発）／§6.3 の canary は in-tree で
   `trap` の下に patch を当てるので **SIGKILL 残渣**を同文書の論法どおり抱えるが §6.3 が書いていない
   （残渣は未使用関数で次の AC-06 が確実に落とすため Codex の「危険な worktree」評価は**却下**、
   1文の欠落として MINOR）／**OQ-2 は陳腐化**（003 r5 §1.5.2 が3結合すべてに回答済み。
   `003:341` と `004:171` の引用も両方ずれ。004 は `:370-375` に v1 前像を持ち、さらに
   `planHash` が `gas_limit` を含まない＝008 AC-7a との3つ目のずれ）／AC-14(i) の見出しが
   **"Seven"** なのに表は8行・evidence は `8/8`／`zk-verdict/README.md:97` の `~34 s` は
   §7.5 が同じ操作を **335.02 s** と実測した後も無修正で残る（003 の check 17 が「ちょうど1件」を
   要求するので**削除でなく限定**で直す）。

**round 5 は短いはず**: 1 は隣（003 r5）に設計が既にあり、2–9 は局所の編集。§3 / §4 / §5.1 /
AC-1…AC-12 / 試験計画は一切動かない。ただし 1 と 2 の帰結として **mutant 数 16 は動く**
（新しい被覆の結果であって算術の再litigate ではない）。**r6 hard stop まで残り 2 周。**
r5 で 1–4 が仕様どおり入れば r6 は APPROVE の形。入らなければ、9/9 のチェックポイントを
付けたまま founder に開いた論点を返す。

## 008 spec review r3（2026-09-04）— **CHANGES**

記録: `docs/reviews/008-spec-r3.md`（payload `/tmp/reckn-payload-008-spec-r3.md` /
Codex raw `/tmp/reckn-codex-008-spec-r3.md`、呼び出しは 1 回・`-s read-only`）。
対象 `docs/specs/008-verdict-domain-soundness.md`（**2334 行**）は `reckn-spec`（Claude Code）起草＝
Codex は書いていないので、独立レビューとしてフル適用（author independence 充足、payload に明記）。

**findings 7件（BLOCKER 1 / MAJOR 2 / MINOR 4）。r2 の 8件は全部閉じた**（digest 2件・
テスト数 12/7/16・AC-14 の 8 literal・tilde 14 vs 12 を全部再測定して一致）。

1. **[BLOCKER] M-8 が `RecknZkEscrow.sol` を in-place で編集する仕様のまま**＝ founder の
   sandbox 裁定と `AGENTS.md` §0 に反する。r4 で必要なのは文言でなく4条件:
   ①`surfaces.sh` が **`no-keys.sh:17-19` と同じく自分の位置から root を導出**（引数・環境変数・
   絶対パス fallback を許さない）②sandbox に **`reexec-evm/src/lib.rs` も入れる**（AC-0b は
   2節あり、第2節が `head -710`）③**変異前に clean copy で exit 0 を確認**（無いと
   「コピーされていないファイルを読んで落ちる退化実装」が "detected" と誤採点される）
   ④restore は `rm -rf "$S"`、N-1 は文字通りに戻る。
2. **[MAJOR] AC-13 の行自体が `echo` で満たせる。** witness set が「16個の `.patch` ファイル」で
   **どの mutant も patch ファイルを変更しない**ため witness は全 run で定数。`ac008-selftest.sh` を
   2行の echo にすると `18/18 rows passed` が出る。step 0 / step 6 は stub の内側。**INV-14 は
   AC-00 しか除外していないので偽**。閉じない（信頼の根は repo 内で終端しない）ので r4 は
   ①INV-14 の量化子修正 ②`:1059` の偽文削除 ③**L-3 を「AC-13 の行は echo で満たせる」と平明に
   書き直す** ④`ac008.sh --all` が **M-9 を canary として自分で適用**（zero-build）。
3. **[MAJOR] OQ-5 の3案は列挙が不完全**で、しかも自案有利の方向（§0 を破る/検査を弱める/検査を消す＝
   強いのは §0 破りだけ）。§0 に触れない案が2つ落ちていた（founder の sandbox、および M-8 を
   AC-0b の**第2節**＝`reexec-evm/src/lib.rs:711` 上の comment に向ける弱い代替）。
   **(b) の却下理由は founder の方が鋭い**（pin を変異させるとどのファイルを digest していても落ちる＝
   「digest が `RecknZkEscrow.sol` から計算されている」を検定しない）。(c) の価格付けは正しい。
   (a) の未計上リスク: `trap` は **SIGKILL を捕らえない**。`no-keys.sh` は設計上 comment-blind
   （`:28-30`）なので、hard kill で残った変異 comment を commit 時に検出できない。
4-7. **[MINOR]** honest scope の G-1 文（host 側の性質を無条件に書いている）／`:536` の
   「byte-identical code」過剰主張（正しくは同一 crate・出力同一。`revm-precompile-34.0.0/src/blake2.rs:135,201`
   に avx2+std の別実装）／AC-11 の witness set「5ファイル」は 008 が6本目を足す／AC-0b の
   prefix 1..710 は testkit の doc comment を含み、2つ目の `#[cfg]` ブロックを禁じる。

**独立に検証して健全と判定した（r4 で再litigate しない）**: **P-12 は閉じている** — 4つの call
opcode が `revm-interpreter-35.0.1/src/instructions/contract.rs:158,203,248,293` →
`load_acc_and_calc_gas` → `db.basic`（`revm-context-16.0.1/src/journal/inner.rs:927`）の**一本道**
なので、実行時計算された callee でも `DELEGATECALL` でも witness に居る（P-12 panic）か
居ない（両側 fail）かの二択。**Δ の9要素は完全**（`bn`/`gmp` は default でないので `0x05`–`0x08` は
両側同一）。G-3・`head -710`・AC-7a・§7.5 の tier 扱いも健全（唯一の訂正＝「9/9 の blocker ではない」を
post-008 と SVM の未測定値に**条件付き**と明記）。

**round 4 は狭いはず**: 8項目とも局所で、§3 の修正内容・AC-1…AC-12 のベクタ・manifest 算術
（18行/91/6/16）・guest freeze 規則は検証に耐えた。**r6 hard stop まで残り 3 周。**

## 008 spec review r2（2026-09-04）— **CHANGES**

記録: `docs/reviews/008-spec-r2.md`（payload `/tmp/reckn-payload-008-spec-r2.md` /
Codex raw `/tmp/reckn-codex-008-spec-r2.md`、呼び出しは 1 回・`-s read-only`）。
対象 `docs/specs/008-verdict-domain-soundness.md`（**1731 行**）は `reckn-spec`（Claude Code）起草＝
**Codex は自分の宿題を採点していない**（payload の 1 行目に明記）。Codex 3件（BLOCKER 2 / MAJOR 1）
→ **3件とも採用**（うち2件は呼び出し前に私も独立に到達、1件＝AC-7a は私が見落としていた）。
**私の独立検出 5件**を追加。残った **8 findings（BLOCKER 2 / MAJOR 4 / MINOR 2）**。
**Codex 却下ゼロ** — r1 では BLOCKER 1件が偽の前提だったが、今回は反証できた主張が無い。

**BLOCKER 2件は同じ種**:

1. **G-1/G-2/G-3 は prover のマシン上のチェック**（`to_guest_input` は host 関数）。
   仕様自身が `:308-311` で「**prover が敵対者であり、guest との間に sanitiser は無い**」と
   書いている。既存の `zk-verdict/script/src/bin/reexec.rs:123-140,164-166` が
   `GuestInput` を構造体リテラルで組んで `stdin.write` しており、**host 関数を呼ばない prover は
   何も失わない**。実害があるのは G-2 だけ（G-1/G-3 は迂回しても新しい能力を与えない）:
   seller は witness の中身を選べ、`dealBinding` は**どの account が witness に入るかを縛らない**。
   結果、**「Δ = `0x01`/`0x0a`/`0x0b`–`0x11` は到達不能」は偽**であり、その偽の文が
   `:1602-1607`（§9(1)）経由で **`zk-verdict/README.md` の honest scope に出荷される予定**だった。
   = 製品の定義上の失敗形（閉じていない健全性主張を閉じたものとして公開）。
   修正は guest 内 P-12（`GuestInput` に対する構文チェック、実行トレース不要）＋ W-09。
   **P-9（`:583`）が既に「off-chain analogue が無い panic」の正しい書き方の雛形になっている。**
2. **AC-13 の 4 mutant は 16 AC のうち 4 しか守らない。**とくに **AC-3（13 tests）＝軸2
   （「guest は `chain_id` しか設定していない＝同じ EVM を走らせていない」）に mutant がゼロ**。
   軸1 には M-1/M-2 の 2つ。Codex が「**64 bit でなく 128 bit で切り詰める**」実装を構成し、
   V-11 だけがそれを捕まえる唯一の body である一方 M-1 は依然 V-03 を反転させるので
   `4/4 mutants detected` が出ることを示した（私が再検算して成立を確認）。
   加えて **`kind = script` 行 8本は `echo` 一行で通る**（`:779-781` の契約が
   「exit 0 かつ stdout に evidence 行」だけ）。委員会的に重いのは `fixtures-check.sh` —
   r1 が「committed fixture を現行 guest に繋ぐ唯一のもの」と記録した行がスタブで通る。
   → **M-5（env 適用の抹消→AC-03、guest 再ビルド1回）** と、
   **コンパイル不要の M-8/M-9/M-10/M-12**（`RecknZkEscrow.sol` のコメント1バイト→AC-00b /
   `u64_low` 再挿入→AC-06 / fixture の vkey 1バイト→AC-09 / `~410k` 挿入→AC-14）。
   **これは文書中で最も安いリゴア**であり、vector を削る前に買うべき。

**MAJOR 4件**: ③ G-3 は署名（`check: (Address,U256,U256,U256)` を取り `PredicateV1` を見ない）から
**実装不能**で、D の第1節は enum variant が**存在する**ことだけで "enforced" になっている
＝`AGENTS.md` §5 の「名前でなく本体」を仕様レベルで犯した ④ script 行の自己申告（上記）
⑤ AC-7a の `state_root` 成分は「1成分だけ変えて実 ELF を2回」では**原理的に実行できない**
（`main.rs:95-99` が binding より前に MPT 検証する）。加えて `plan.caller`/`plan.target`/
`coinbase`/`check.address`/`check.slot` の5成分は witness-closed DB のせいで P-5/P-8 に落ちる
（仕様は E-05 で同じ罠を自分で発見していたのに AC-7a に持ち込んでいない）
⑥ `surfaces.pinned` は**それに縛られる実装者自身が作る**（仕様に期待 digest が無い）＋
「testkit の `cfg` 行の**上**」が 711 行を含むか曖昧。→ 実測値を仕様に literal で書く:
`RecknZkEscrow.sol` = `07d649c2…33e45b`、`head -710 reexec-evm/src/lib.rs` = `b4fd62d5…b29d1`。

**MINOR 2件**: ⑦ AC-2 の V-10 の「guest today」が誤り（`2^128`→`2^128+1` は limb 0 が 0→1 で
`Reproduced`＝**今日の guest は一致する**）。`u64` で表現できない `min`/`max` の扱いも
V-13 と V-08/V-03/V-11 で不統一 ⑧ AC-11 が `zk-verdict/README.md:105-108`（「fixture の
有無で gate されるので `forge test` は緑」）を偽にするのに AC-14 の削除リストに無い。

**健全と確認したもの（round 3 で再審しない）**: r1 の 15件は**全部**答えられている。
`vm.exists` 7件＝早期 return 7件（実測、両カウントは今日一致）、README の 3 行域
（572-579 / 580-587 / 588-592）、AC-14(i) の 7 literal は**全部今日 grep で 1 件ヒット**、
tilde regex は 14 件（naive は 12 件）、manifest 算術は 86 = 11+59+16 で閉じる、
`binder` の testkit 依存（`Cargo.toml:26` / `tests/router_two_vms.rs:13`）、root `Cargo.toml` 不在。
**空 MPT proof の訂正は 008 が正しく r1 の私が間違っていた** — `alloy-trie-0.9.5/src/proof/verify.rs:29-43`
は空 proof でも `expected_value` が `Some` なら必ず `Err`、guest は account には常に
`Some(rlp(TrieAccount))` を渡す（`main.rs:58-60`）ので **account 側は既に一致、storage 側だけが乖離**。
Codex も独立に同じ結論。**tier 違反は発火せず**（AC-14(iv) は逆に cycle 数の持ち越しを禁止し
ELF の sha256 まで要求している）。

**9/9 に間に合うか（founder 判断の材料）**: 「縮んだのはカレンダーだけ」という主張は**概ね真**。
sandbox 10コピー（実測 `du -sh .` = **21G** / `zk-verdict/target` = **6.8G**）→ in-place patch、
12箇所の行番号 → 2 grep（実測で naive 版は 14 件中 2 件を取り逃す）、digest 2本 → literal 文。
**86 テストは律速ではない**（59 本は4つの vector 表の行、被験コードは `main.rs` 202 行 /
`lib.rs` 113 行 / `reexec-io` 72 行 / `.t.sol` 5本で 401 行）。Codex も独立に同じ判断。
**律速は値段のついていない Groth16 再生成**: AC-9 は 4本すべてが**最終**の guest ELF と
一致することを要求するので、guest に触る impl round のたびに 4本が無効化される。
repo 内の唯一のコスト実測は `zk-verdict/README.md:97` の「~15.9M constraints, ~34 s」＝
**predicate guest**（34 行）であって、410k cycles の再実行 guest（008 後はさらに増える）ではない。
仕様は §7.5 で**報告**は求めるが**予算も停止条件も無い**（AC-13 という小さい方には両方ある）
＝ r1 finding 3 と同型が場所を変えて再発。
**→ 推奨は削減でなく順序**: ①**今日**、現行 guest で `reexec-groth16-fixture.json` を1本
再生成して壁時計を測る。分単位なら日程は問題ない。時間単位なら**その数字が 9/9 を決める**。
②fixture 再生成は Rust が impl APPROVE に達した**後に1回だけ**（§7.2 に明記）。
③§7.5 に AC-13 と同じ形の予算＋停止条件。
**それでも入らない場合の削減順**: AC-3 の E-11/E-12（仕様自身が「fidelity でなく agreement」と
書いており AC-6 check 4 が無料で同じ面を見る）→ AC-8 を 6→2（5つの `FailReason` は同じ byte に
写るので4本は同一の assertion）→ AC-1 の test 2（20万件の乱択。15⁴=50,625 の網羅が本体）→
AC-12 test 2 → 最後に AC-16（ただし N-3 を明示的に取り下げる場合のみ）。
**AC-1 の pool / AC-2 / AC-3 の E-01…E-10 / AC-4 / AC-7a,b / AC-9 / AC-10 / AC-13 / AC-0,0b は削らない。
そして finding 2 の新 mutant を削減の財源にしない** — M-5 は上の11テストより価値が高い。

**round 3 の見通し**: BLOCKER 2件はいずれも局所修正（① guest に構文チェック1つ＋vector 1本＋
3つの文の書き換え ② patch ファイル 5〜7本、うち4本はコンパイル不要）。MAJOR も 1〜6 行ずつ。
**r6 hard stop まで残り 4 周。**

## 008 spec review r1（2026-09-04）— **CHANGES**

記録: `docs/reviews/008-spec-r1.md`（payload `/tmp/reckn-payload-008-spec-r1.md` /
Codex raw `/tmp/reckn-codex-008-spec-r1.md`、呼び出しは 1 回・`-s read-only`）。
対象 `docs/specs/008-verdict-domain-soundness.md`（1239 行）は `reckn-spec`（Claude Code）起草＝
**Codex は自分の宿題を採点していない**（payload に明記）。Codex 5件 → **1件を証拠付きで却下・
1件は前提が偽なので狭めて採用・1件は理由を差し替えて降格・2件を採用**、**私の独立検出 10件**を追加。
残った **15 findings（BLOCKER 2 / MAJOR 8 / MINOR 5）**。

**BLOCKER 2件はどちらも「仕様が名前しか読まない」型**:

1. **AC 群は全部テスト**名**しか見ない。79個の命名済み tautology で `ac008: 18/18 rows passed` が出る。**
   §6.0 の件数ゲートは「0件で緑」は確かに殺す（本日再実測: forge 1.7.1 / commit `4072e487…`、
   `--match-test` 無一致で **EXIT=0**、`--fail-on-no-tests` は存在しない）が、**0 assertion は殺さない**。
   唯一の自動防御 AC-13 は**テストを rename するだけ**（`:955`）で本体を一度も開かず、
   `assert!(true)` × 14 は AC-02 も AC-13 も通る。mutation 群 NC-1…NC-18 は `:1054` が
   「**残りは手で1回走らせて出力を報告に貼る**」＝ビルド条件でなく自己申告。
   → `u64_low` が残ったまま緑で出荷できる＝**製品の定義された失敗形そのもの**。
   **本 repo 3周連続の同型**（003 r1 finding 1 / 003 r2 の `assertTrue(true)`）。Codex も独立に到達。
2. **AC-11 が自己矛盾で実装不能。** `:921-922` は `grep -c 'vm.exists'` を **0** と要求し、
   `:923-924` は「gate を `require(vm.exists(FIXTURE), "…")` にする」と書く。後者は前者を不可能にする。
   `AGENTS.md` §7 の「仕様が本当に曖昧」に該当し、**実行順の先頭・9/9 チェックポイントの4日前**に停止を招く。

**MAJOR の中身（要点）**: ③AC-13 の sandbox 10コピーに**コスト見積が無い**
（本日実測 `zk-verdict/target` = **6.8G**、repo = **21G**、`zk-verdict/script` は `sp1-sdk` 依存）
④**INV-2 の iff が偽** — 空 MPT proof を guest は**受理**する（`alloy-trie-0.9.5/src/proof/verify.rs:29-43`
が空 proof + `EMPTY_ROOT_HASH` + 値なしで `Ok(())`）のに off-chain は `EmptyStorageProof` で `Err`
（`reexec-evm/src/lib.rs:352-356`）。P 表 P-1…P-9 は `EmptyAccountProof`/`EmptyStorageProof` を欠く
⑤`anchor.block_header = Some(_)` は `to_guest_input` の exclusion set で黙って落ちるが off-chain は
`HeaderMismatch` で `Err`（Codex の BLOCKER を**偽解放ではない**ので MAJOR へ降格。`state_root` は
buyer が funding 時に固定するため）⑥**N-3 の `binder` 保証を強制する AC がゼロ** —
`binder/Cargo.toml:26` が `features = ["testkit"]`、`binder/tests/router_two_vms.rs:13` が
`testkit::{addr, anchored_identity_witness}` を使うのに、AC-0b の digest は testkit 行より**上**しか見ない
⑦**AC-0b が `003` の破らねばならないビルド条件を設置**（`surfaces.pinned`）していて OQ-2 に記載が無い
⑧**3つ目の pinned digest が既に陳腐化**（本日再計算 `222eeeb8…f99b` / 44行 vs 仕様の `04f567a3…` / 38行）。
原因は 008 の spec commit `d4f59ba` の**後**に入った `9ac4545`（README precompile 訂正）。
結果、§9(3) の3義務のうち**1つは既に完了済み**で、引用行番号3つとも誤り（実際は 572-579 / 580-587 / 588-592）
⑨**domain D は記述であって強制でない** — AC-4 の「precompile 越境は両側で loudly に落ちる」は
**witness に無い場合だけ**成立する。

**却下（証拠付き）**: Codex の BLOCKER「precompile は warm 扱いで DB を叩かないから witness-closed DB は
効かない」は**前提が偽**。`revm-context-16.0.1/src/journal/inner.rs:920-927` で `Entry::Vacant` は
`warm_addresses` から `is_cold` を得た**後に `db.basic(address)?` を無条件に呼ぶ**（warm は EIP-2929 の
gas だけ）。top-level は `revm-handler-18.1.0/src/execution.rs:20-22`、nested は
`revm-interpreter-35.0.1/src/instructions/contract.rs:157-158` → `call_helpers.rs:73` で必ず到達し、
`frame.rs:203` の `precompiles.run` は**その後**。狭めた版を finding 9 として残した。
ほかに Codex の「(b) のコスト記述が逆」（`:202-204` が実際には predicate/SVM fixture を既に credit している）と
INV-8/INV-10 の「存在するだけ」判定、tier 指摘を証拠付きで却下。

**tier 違反は発火せず。** 008 は自分の header（`:3-6`）で local 限定を宣言し、cycles は
**再測定を義務づける方向**（AC-14(ii)、`~180k` の未計測 sub-figure 2件を削除）に動いている。
Honest scope の残余は §9(1) が R-1…R-6 を逐語で保持。

**再litigate 不要（検証済みで健全）**: 欠陥の再現は正確（`main.rs:31-33`/`:163-166` vs
`reexec-evm/src/lib.rs:647`）／revm 引用は**全件行単位で一致**（`hardfork.rs:76-77`、
`block.rs:116-122`、`cfg.rs:120-121`/`:50`/`:329`）／testkit 引用も全件一致（`:737`〜`:745`）／
**precompile 訂正は正しく、逆方向にも踏み込んでいない**（`bn`/`p256-aws-lc-rs` は両側とも非有効なので
modexp/bn254/sha256/ripemd/blake2f/secp256r1 は両側同一コード＝除外集合 `0x01`/`0x0a`/`0x0b`–`0x11` は完全）／
§6.1 の算術は全項再計算一致（18行・cargo 8行79件・forge 2行6件・script 8行・11+52+16=79・12+6=18・AC-13=10）／
基礎件数も実測一致（reexec-evm 10+6=16、forge 12、`vm.exists` 7件/4ファイル）／
AC-14 の 12 cycle sites は**全部実在し漏れも無い**／digest 3件中2件は一致。
**scope 拡大は正当**（しかも仕様自身の理由より強い）: witness-closed DB が無いと seller は account を
**省略**して `dealBinding` を変えずに verdict を変えられる＝**INV-5 が偽**になる。`plan.gas_limit` も同様。
003 の scope 線と整合。

**founder 不確実点① — (a) は正しい。(b) へ切り替えるな。切るのは harness であって fix ではない。**
(b) は完了状態ですらない: `RecknZkEscrow` に timeout が無い（宣言は `fund`/`settleWithProof` のみ）ので
窃取が**恒久ロック**に変わり、002 は 18 decimals で構造的に不可能（RAY は常に定義域外）。
ただし**仕様は fix より大きく、私の 15 findings のうち 8 件はその余剰部分に居る**。
**保持**: AC-1 / AC-2 / AC-3 / AC-4(+空 proof 2 vector) / AC-7a / AC-7b / AC-9 / AC-10.3 / AC-0・AC-0b。
**縮小**: AC-13 は sandbox 10コピー → **in-place semantic mutation（NC-1/5/9/10）+ 保証付き revert・3行**（より厳しく、かつ安い）／
AC-14 は 12箇所 exact 整数 → `cycles.json` + `~NNNk` 不在の grep ／AC-6 は網羅 destructure の
**コンパイルエラー**が強い半分なので bash の Rust struct parser は落とす／AC-5 は AC-6 に畳む。
**追加（安価）**: `binder`/`keeper`/`reckn-evm-content` を建てる manifest 1行、空 proof の W-04/W-05、
`to_guest_input` が `Some(block_header)` を拒否。これで 9/12 内どころか 9/9 前に閉じられると判断する。
**現状のままでは判断しない。** Codex も独立に同じ結論（(a) 維持、AC-13 と cycle gate を切る）。

**founder 不確実点② — 4層は閉じていない。全層を通過して食い違う経路が4本ある。**
①`TxEnv`（どの層にも無い。今日は両側一致なので慣行であって data ではない）
②`anchor.block_header = Some(_)`（層1の exclusion set、層2/3 は `GuestEnv` のみ、層4 は vector が無い）
③空 MPT proof（層1-3 は環境フィールドしか見ず、W-01…W-03 に無い）
④precompile backend（層1-3 は dispatch を模さず、E-01…E-10 は一度も入らず、D は強制されない）。
**「層4 が都合のよいビルドを見ていないか」は否**: `script/build.rs:4-8` が毎ビルドで3つの guest ELF を
生成し `include_elf!` が拾うので AC-9 の vkey 照合は循環しない。ただし **`sp1-build 6.3.1` の source が
ローカル registry に無く skip-build 環境変数の有無を検証できなかった**——これは finding ではなく
**suspicion として記録**（保険: `ac008.sh` が `SP1_*` を unset し、ELF の sha256 を `cycles.json` に残す）。

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

## 004 spec review r2（2026-09-04）— **CHANGES**

記録: `docs/reviews/004-spec-r2.md`（payload `/tmp/reckn-payload-004-spec-r2.md` /
Codex raw `/tmp/reckn-codex-004-spec-r2.md`、呼び出しは 1 回・`-s read-only`、payload は起動前に全文表示）。
対象 `docs/specs/004-live-adversarial-input.md`（440 → **1233 行**）は `reckn-spec`（Claude Code）起草＝
Codex は自分の宿題を採点していない。Codex 5件 → **全件を現物で再現して採用**（1件は remedy を証拠付きで
差し替え）、末尾所見から2件を MINOR に格上げ、**私の独立検出5件**を追加。
残った **12 findings（BLOCKER 2 / MAJOR 5 / MINOR 5）**。

**r2 の pin は本物だった（再 litigate 不要）。** r1 BLOCKER 1/2/3 の remedy として置かれた数値を
**11 種類すべて独立に再計算して一致**: `CODE_HASH` / **`STATE_ROOT` 2本を独立実装の Python secure-MPT で
再構築** / §4.3 の fixture `deal_binding`・`trace_hash`（committed fixture と一致）/ AC-20 の 6 pin /
`recordTraceHash` 2値・`resultHash`（`protocol-rs` の TLV を再実装）/ **§3.6 の `gasUsed` 8点を
intrinsic gas + SSTORE メータリングから解析的に再導出**（非単調 26188 > 26164 は本物の EVM 由来量）/
§7.5 corpus digest と 21-APPROVE/11-REJECT ベクタ（§7.4 の規則を実装して 32/32 一致）/ §7.6 の digest と 8/8 /
`forge test` 12件・名指し4件の実在。`dashboard/index.html:705` の訂正は **r2 が正しく r1 の「706」が誤り**。

**BLOCKER 2件:**

1. **004 は 008 が削除する v1 guest に対して書かれている**（Codex 発見）。008 は founder 裁定で 004 より前に走り、
   `008:228-234` が**全 preimage を fixed-width big-endian に、全ドメインタグを v2 に**する。決定的なのは
   `008:882-890` が `reexec-groth16-fixture.json` を **`pre = 2^64` / `post = 2^64+100`** で再生成すると
   明記していること — 004 §4.3 の組み直しレシピ `testkit::anchored_sstore_witness`（slot 7 = 42）は
   その prestate を作れず、**AC-7(d) が再び「誰も通せない AC」になる**（r1 BLOCKER 2 の実行順による復活）。
   併せて AC-6 が印字を義務づける「the divergence itself is task 008's, not closed here」は**解消済みを
   未解消と書く**逆向きの §5 違反になり、INV-2 は `env_hash` の導入で偽になり、§11 D-1（`planHash` に
   `gas_limit` が無い、"founder 裁定待ち"）は `008:292-294` が既に閉じている。
   **`PinDrift` は不十分** — 変わるのは値でなく式・タグ・fixture の prestate。
2. **「再実行が走ったこと」の担保とされた NC-19 は、受入条件のどこからも走らない。**
   §6.1 は「NC-19 が白箱側の担保」と書くが、§6.0 の 24 gate に `negative-controls` の行が無く、
   `scripts/004-live.sh` のサブコマンドにも無い（AC からの参照 **0件**）＝**NC-1〜NC-24 を1行も
   書かない実装が 24 gate 全部で緑**。加えて §6.1 の「**2つ目のエンジンが要る**」は**偽**:
   AC-4/17/18 の入力集合は有限で仕様が全部公開しており（8 amount + 6 fixture + 12 spec_id）、
   **合計 26 行のルックアップ表**で 3 gate とも通る。正直な告白（「それでも証明ではない」）が
   その2文前の過大主張を覆う位置に置かれている。COUNT CONTRACT も**被検査プログラム自身の出力**を
   照合するだけなので、gate 本体を成功行の印字に置換した実装を落とせない（NC-24 はこの変異を覆わない）。

**MAJOR 5件**: ③AC-15 の禁止語 `settled` が**既存の真の記述**に発火（`README.md:35` / `SUBMISSION.md:187`、
zk 経路の記述で、004 の作業を1行も始める前に `lint-claims` が落ちる）④**AC-9 と AC-10(a) が同時に
満たせない**（`judge.kind = "unavailable"` vs 許容集合 `{stub,cli,http}` + 必須 `judge.model`/`rawResponse`）
⑤AC-10(b) は `attemptId` を**引用している文しか見ない**ので、引用の無い "A language model was persuaded"
が全検査を素通り（Codex）⑥`JudgeTimeout`/`JudgeResponseTooLarge` を実行する AC が無く、AC-19 は
逐次 `seq` 衝突しか見ない（同時 POST 未検定、Codex）⑦`DELIVERED_MAX` が回避策である開示が
**selftest の stdout にしか無い**（§3.4 は「デモ・README・提出文で同じ言い方をする」と書くが強制する AC が無い）。

**MINOR 5件**: 「u64 の縁に触れない」→ 実際は縁**ちょうど**まで受理（Codex）/ §6.0 の expected が
列挙ケースと不一致（AC-0 = 5 vs 6、AC-7(e) = 4 vs 7、`docs-claims` は expected が実装依存で
`check-counts` の厳密一致が原理的に効かない）/ **INV-3 を同じ文書の AC-18 が反証**している /
§11 D-1 が解決済み / OQ-3 は `008:343-349`（実 ELF 差分テスト）で **founder 裁定なしに閉じられる**。

**却下**: ①Codex の「004 は 008 の差分 gate に依存すべき」— N-9/T-8 が正しく避けている依存の逆流。
②「AC-7(d) は Failed 側の outcome を外部アンカーしていない」— AC-20 の pin が outcome=1 でしか
再現しないことを再計算で確認、却下。③「AC-11(b) は self-refereed のまま」— §7.4 の規則も §7.5 の
corpus も**仕様が固定**しており、独立実装で 32/32 再現。ただし見出し「(b) 一般化」は誤称で「適合」が正しい。
④「AC-11(a) は無意味」— 母集合と走査域を確定し POSITIVE CONTROL を持ち限界を明記した tripwire で、
狭いが空ではない。⑤「T-8 の cold clone と offline が矛盾」— cold clone と cold cargo registry を
正しく区別しており r1 finding 16 は閉じている。

**tier 違反は発火せず**: 004 は `local only` を守り、`~34 s`/`~6.2 GB` は否定方向の引用のみ、
Honest scope は1つも解消していない。ただし **kill 方向の tier 誤りが2件**（§11 D-1 と AC-6 の
義務づけ文言が、008 が閉じたものを未解決として提示する）— finding 1 に含めた。

**founder の低信頼点への回答**: ①「再実行しか作れない量」への結び直しは**半分効いている**。
pin は本物で r1 の `fake_reexec` は確実に死ぬが、26行のルックアップ表は通る。必要なのは pin を
増やすことではなく、負のコントロールを gate にすることと、**少なくとも1 gate の入力集合を
実行時 seed にする**こと（表に書けなくする）。②AC-7(d) は **008 前の guest に対しては
一致を強制できている**（判別軸 — min=100/pre=42/post=142/slot=be32(7)/タグ/順序/`gas_limit` 不在/
outcome 符号化 — を全部数えて、ずれたまま両方一致する経路は見つからなかった）。**008 後は NO**。

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
2. ~~**founder**: 9/4 に `DISCLOSURE.md` を ETHGlobal へ送付~~ → **この指示は実行不能だった**。
   受理前の時点で送付先が存在しない（Discord 接続は受理後、提出フォームは提出時）。
   **実質的な開示は 9/4 の応募 Q1 で既に済んでいる**（一度も提出していないこと、製品作業が
   `a122b44`/08-02 で停止していること、以降が tooling/planning/docs であること）。
   `DISCLOSURE.md` 自身の指定は「ETHGlobal チームへハック開始前／開始時に送り、**提出時の
   description に全文を再掲する**」なので、残る実行項目は次の2つ:
   - **受理後**: Discord 接続時に全文を主催者へ渡す
   - **提出時（9/16 まで）**: submission description に全文を再掲
   - ✅ **`DISCLOSURE.md` の該当箇所は 2026-09-04 に修正済み**。「the repository is still
     private」は public 化で偽になっていた → 「private until 2026-09-04, when it was made
     public so that this application could be reviewed against the actual source」に差し替え。
     **`AGENTS.md` §8 は founder 文書のエージェントによる書き換えを禁じているが、この編集は
     founder の明示的な委任により行った**（黙って例外を作らないためここに記録する）。
     §8 の規則自体は変更していない。次に同種の編集が要るときも、founder の委任を待つ。
3. **`reckn-spec`（最優先・実行順の先頭）**: `docs/reviews/008-spec-r1.md` の
   「What must change before round 2」15項目を `docs/specs/008-verdict-domain-soundness.md` に反映 →
   `reckn-codex-review`(stage=spec, **r2**)。**blocking は2つ**: ①AC-13 を rename から
   **semantic mutation（NC-1/5/9/10）+ in-place & 保証付き revert・3行**へ置換し、
   §7.3 の「残りは手で走らせて貼る」をビルド条件に格上げする ②AC-11 の自己矛盾
   （`vm.exists` 0件要求 vs `require(vm.exists(...))`）を early-return パターンの検査に書き直す。
   **併せて「Founder uncertainty 1」の cut list を適用**（AC-13 縮小 / AC-14 の12箇所 exact 整数を撤回 /
   AC-6 の bash struct parser 撤回 / AC-5 を AC-6 に畳む）。適用しない場合は**規模の判断を founder に上げる**
   ——9/9 チェックポイントの対象タスク。
4. **`003` は round 6 で hard stop に到達（2026-09-04、`docs/reviews/003-spec-r6.md`）。
   `VERDICT: CHANGES` → round 7 は無く、founder 裁定待ち。`reckn-spec` は指示があるまで動かない。**
   **残った BLOCKER は1つ**: check 14 は代入の**左辺しか pin しない**ので、
   `settleWithProof` 内の `if (d.token == <定数>) { to = <定数>; }` を**どの検査も拒否しない**
   （`003:1138-1148`, `:1670-1677`）。この木では §1.1（「funded deal は funding 時に固定した
   2つ以外の宛先へ動かせない」）が**偽でありながら 15/15 検査・46 テスト・38 EVM 行・全 fuzz が緑**で、
   money-shot は `40/40 rows as specified` と `Addresses that helped: 0` を印字する。
   仕様はこれを **OQ-10** として正直に開示済み（§8 / INV-2 / §4.5.6a / §10）だが、
   **判事が見る §7 には一行も出ない**（`grep OQ-10` が §7 で0件）。
   **G-39 / G-40 と同一クラス**であり、その2つは r5 で BLOCKER 判定→r6 で 15g により構造的に閉じた。
   閉じるコスト（founder が 9/12 凍結までの日程で判断するための見積り）:
   - **14d（`to` の右辺を `d.seller`/`d.buyer` に各1回で pin）＝仕様編集のみ、実装パート増加 0**
     （P3 に吸収）。仕様の「P1 前には安全に書けない」という理由は、**同じ round が
     check 8 の右辺句・15g-iii・14c と3つの右辺 pin を先に書いている**ので成立しない
   - **§7.2 に1行＋§7.3 に1項目＝0 パート。14d が入っても必要**（14d は宛先側しか閉じない）
   - `fund` の `deals[dealId] = Deal({…})` リテラルまで pin する広い形は **P1 後に1パート**
   その他: `"top-level `;`"` の未定義（MINOR）、`GC-1 … GC-18` → `GC-19` の誤記（MINOR）
5. **`reckn-spec`**: `docs/reviews/004-spec-r2.md` の「round 3 で直すもの」9項目を
   `docs/specs/004-live-adversarial-input.md` に反映 → `reckn-codex-review`(stage=spec, **r3**)。
   **blocking は2つだけ**: ①§4.1/§4.3/AC-6/AC-7(d)/AC-20/INV-2/§11/§3.4 を **008 後の guest**に対して
   書き直す（式を参照で定義し、literal hex を "pre-008" と明示し、AC-7(d) の組み直しを構成子名で固定しない）
   ②`negative-controls` を 25 番目の gate にし、NC-25（gate 本体を成功行の印字に置換）を足し、
   §6.1 の「2つ目のエンジン」を削り、**1 gate の入力集合を実行時 seed にする**
6. **founder 裁定（003 r2 追加）**: G-33 を disclosed に留めるのは**コストの判断であって
   中心主張の形の判断ではない**（finding 9）。OQ-6 は「実測が無い」ではなく「**~34 s は predicate guest の
   実測、`program-revm` は未測**」を前提に問い直す。OQ-1/OQ-2/OQ-3/OQ-5 は r2 で不変。
7. **founder 裁定（004 r2 更新）**: OQ-2 は**決着済み**（見出しは判事非依存に書き換え済み）。
   `u64`/`U256` 偽 release は **008 が引き取り済み**。004 で残る裁定は **OQ-1**（観客 attempt を
   セッション後に実 Groth16 → `settleWithProof` する別タスクを起こすか）と **OQ-4**（凍結後に届いた
   attempt を commit するかの Continuity 解釈）の2つだけ。**OQ-3 は裁定不要** — `008:343-349` が
   実 ELF 差分テストを既に持つので 004 は何も足さない（004 自身がその条件を書いている）
8. spec が APPROVE になってから `reckn-codex-impl`。**実装・コントラクトは未着手**
   （`RecknZkEscrow.sol` は 2026-09-04 時点で無変更）。**`003` は round 6 の CHANGES により
   実装に入っていない** — 上記4の founder 裁定が先。

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

## 応募（2026-09-04）

**ETHOnline 2026 に応募提出済み。** トラックは **Hack on Existing Project**。
文面一式は `_applications/2026-09-04-ethonline-application.md`（実測値・誇張しないための線・
未回答の Q3 を含む）。受理確認まで完了、**審査結果待ち**。

**この提出が生んだ約束**: Q2 に4本書いた以上、出す義務がある。とくに項目2＝**task 009
（Solana の proof で EVM の escrow を決済）は応募時点で `AGENTS.md` に存在しなかった**ため、
同日に登録し実行順を `008 → 009 → 003 → 004` に変更、**9/9 の撤退チェックポイントを
`008` と `009` に差し替えた**（応募文が目玉として提示したのが 009 だから）。

**受理された（2026-09-04、Kartik / ETHGlobal co-founder より）。** Hack on Existing Project で参加確定。

**founder の手（期限あり）**:
- ✅ **RSVP — 完了**（2026-09-05 報告）
- ✅ **0.005 ETH のステーク — 完了**（2026-09-05 報告。参加完了後に返還）
- ✅ **Discord 接続 — 完了**（`psyto7835`、2026-09-05 報告）
- ✅ **track 選択 — Continuity Track で確定**（2026-09-05 報告。切り替え不可）。
  → これで賞金一覧が開く。**`005` Arc/USDC と `006` Hedera/x402 の対象スポンサーが
  実在するかを、一覧が出た時点で確認すること**（受理メールの名指しは 1inch / World /
  Uniswap / Chainlink / 0G。World のみ確認済み）。
- **`DISCLOSURE.md` の送付先が判明**: ダッシュボードの **Create project**（提出は未開放だが
  記入は可能）。`DISCLOSURE.md` 自身が「提出時の description に全文を再掲する」と指定して
  いるので、**project を作って description に全文を貼れば義務を果たせる**。
- Discord 参加、Event Info Center 確認、Code of Conduct 確認
- ステーク後に `DISCLOSURE.md` 全文を主催者へ（`§1` の修正は 2026-09-04 に適用済み）

**⚠ スポンサー構成の確認事項（`AGENTS.md` §3 のタスクに影響）**: 受理メールが名指ししたのは
**1inch / World / Uniswap / Chainlink / 0G**（「and more」付き、**完全な賞金一覧は未公開**）。
- **`007` World AgentKit** → World は**確認済み**
- **`005` Arc / USDC** と **`006` Hedera / x402** → **どちらも現時点の名指しに無い**。
  賞金一覧が公開されたら**対象スポンサーの実在を確認してから着手する**こと。
  存在しないスポンサー向けに作ると当日作業を丸ごと捨てることになる。
  なお 005/006 は実行順（`008 → 009 → 003 → 004`）に入っておらず、凍結 9/12 までに到達しない見込み。

## 裁定 — OQ-5（008 の M-8 が `RecknZkEscrow.sol` を触る件、2026-09-04）

**(a) 実ファイルを一時変異 / (b) `surfaces.pinned` を変異 のどちらでもなく、第4案＝
sandbox レイアウトを採る。**

- **(b) は守りたい性質を検定しない**: `surfaces.pinned` を変異させれば、**どのファイルの
  digest を計算している実装でも**不一致になって落ちる → 「別ファイルを digest している
  退化実装」を素通しする。AC-00b の目的（digest が**そのファイル**から計算されていること）を
  達成できない。
- **(a) は目的を達成するが `AGENTS.md` §0 / N-1 の例外を要する。**
- **sandbox レイアウトは両方を満たす。** `no-keys.sh` は自分の位置から対象を導出する
  （`scripts/no-keys.sh:17-19`）ので、レイアウトごと temp dir に再構成すればコピーを
  同じコードパスで判定できる。**003 が §4.5.9 で採用し 2026-09-04 に実測検証済み**
  （clean copy は exit 0、mutated copy は落ちる。引数・環境変数・既定値の変更なし）。

→ **N-1「1バイトも触らない」は文字通り成立し、§0 の例外は不要になる。**
条件: `surfaces.sh` も `no-keys.sh` と同様に**自分の位置から対象を導出する**設計であること。
絶対パスを焼き込むなら sandbox が効かないので、そこは仕様で要求する。

## 裁定 — OQ-8（承認済み仕様 008 の2セル、2026-09-05 founder 承認）

**`008:2548`（"must report **18** results"）と §6.1 manifest の `008:1276` の `18/18` を、
base 測定のトークンに置き換えることを承認。009 の着地 commit で同時に行う。**

- **なぜ 009 側では直せないか**: 両セルは 008 の仕様ファイルの中にあり、`ac008.sh` は
  stdout がその evidence 行を**逐語で**含むことを要求する（`008:1213-1216`）。
- **なぜ実装エージェントの判断でできないか**: 承認済み仕様の manifest 編集は実装者の役割でない。
- **orchestrator の先の裁定（「id 集合で assert しろ」）は撤回済み**——実装不能だった
  （id 集合版は自分のディスパッチャが照合できない行を印字する）。実装は仕様どおり `18/18`。
- **これが無いと 9/9 の「008 と 009 が同時に緑」が構造的に達成できない。**

## 実装の順序（orchestrator、2026-09-05）

**009 の実装は 008 の実装が着地してから始める。** 理由は依存でなく**作業ツリーの共有**:
`AGENTS.md` §6 のとおりエージェントは同じツリーを共有しており、009 は 008 が今まさに触っている
`scripts/no-keys.sh` と escrow を変更する。並行させると互いの diff を潰す。
（仕様の並行執筆は問題なかったが、実装は別。）

## 未送付 / 未実行

- 事前開示の送付（founder の手）
- ~~`psyto/reckn` の public 化~~ → **2026-09-04 実施済み**（founder の合図により、提出時でなく
  応募審査のために前倒し。ETHOnline の Hack on Existing Project は「提供された情報のみ」で
  審査されるため、source link が機能しないと審査が成立しない）。公開前に走査済み:
  `.env` / 秘密鍵 / keypair / mnemonic / PEM いずれも追跡下に無し、`.DS_Store` 未追跡、
  LICENSE は Apache-2.0。
