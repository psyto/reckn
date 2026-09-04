# Review 004 spec round 2

Payload: `/tmp/reckn-payload-004-spec-r2.md`
Codex raw: `/tmp/reckn-codex-004-spec-r2.md`

Codex 呼び出しは 1 回（`codex exec -C . -s read-only`、payload は起動前に全文表示済み）。
対象 `docs/specs/004-live-adversarial-input.md`（440 → **1233 行**）は `reckn-spec`（Claude Code）起草であり
Codex ではない。author independence 上 Codex は正当なレビュー主体であり、その旨を payload §0 に明記した。

Codex 5 件（BLOCKER 2 / MAJOR 3）+ 末尾所見 3 件 → 裁定後 **BLOCKER 2 / MAJOR 5 / MINOR 5**。
Codex 由来 5 件は**全件を現物に当てて再現し採用**（1 件は remedy を証拠付きで差し替え）、
Codex の末尾所見から 2 件を MINOR に格上げ、**私の独立検出 5 件**を追加した。

---

## 0. 先に書く — この round で**再 litigate 不要**なもの（実測で健全）

r1 の BLOCKER 1/2/3 の remedy として r2 が置いた pin 群は、**全て独立に再計算して一致した**。
仕様の数値は装飾ではない。以下は round 3 で触らない。

| pin | 検証方法 | 結果 |
|---|---|---|
| `CODE_HASH` (§3.3) | `keccak256(0x5f545f35015f5500)` | 一致 |
| `STATE_ROOT` = `0xe3879e4f…` (§3.3) | **独立実装の Python secure-MPT** で 3 アカウント + storage trie から再構築 | 一致 |
| §4.3 の fixture `state_root` = `0xf07b6a18…` | 同上（`testkit::anchored_sstore_witness` 相当を再構築） | 一致 |
| §4.3 `dealBinding` / `guestTraceHash` | §4.1 の式で再計算 → `zk-verdict/contracts/src/fixtures/reexec-groth16-fixture.json` の committed 値と比較 | **2 件とも一致** |
| AC-20 の 6 pin（3 amount × traceHash/dealBinding） | §3.3 の固定値から再計算 | **6 件とも一致**（Failed 側の outcome byte = 1 も `zk-verdict/lib/src/lib.rs:35-36` と整合） |
| §3.6 `recordTraceHash` 2 値 / `resultHash` | `packages/protocol-rs/src/lib.rs:63-101` の TLV を再実装 | 3 件とも一致。`ReplayRecordV1` が `pre`/`post`/`delta` を束ねないという §3.6 の主張も現物どおり |
| §3.6 `gasUsed` 8 点 | intrinsic gas（zero 4 / nonzero 16）+ cold SLOAD 2100 + SSTORE(RESET 2900 / no-op 100) から解析的に再導出 | **8 点すべて一致**。非単調（`1023999999`→26188 > `1024000000`→26164）は calldata のゼロバイト数から出る本物の EVM 由来量 |
| §7.5 corpus digest / 期待ベクタ | 32 件を仕様から機械抽出し `sha256(join("\n"))`、§7.4 の規則を実装して採点 | digest 一致、**21 APPROVE / 11 REJECT が 32/32 一致** |
| §7.6 judge-controls digest / 8 件ベクタ | 同上 | digest 一致、8/8 一致。R5 の先頭 64 bytes に `APPROVE` が生で現れることも確認 |
| `forge test` の母集合 | `zk-verdict/contracts/test/*.sol` の `function test` を計数 | **12 件**、AC-7(e) が名指しする 4 件は全て存在 |
| §1 の行番号 | `awk` | `dashboard/index.html:678` = `var SCEN = {`、`:705` = `};`。**r1 finding 15 の「706」の方が誤りで、r2 の訂正が正しい** |

r1 の BLOCKER 3（`spec_id` 未固定）、MAJOR 6/7/8/9/10/11、MINOR 12/13/14/15/16/17 は
**現物に照らして閉じている**。以下の findings はいずれもその再発ではない。

---

## Findings

### BLOCKER

**1. [BLOCKER] `docs/specs/004-live-adversarial-input.md:369-377`（§4.1）/ `:404-438`（§4.3）/
`:680-690`（AC-6）/ `:694-713`（AC-7(d)）/ `:908-923`（AC-20）/ `:1198-1210`（§11）
— 004 は 008 が削除する v1 guest に対して書かれている。008 は founder 裁定で 004 より前に走る。**

Codex 発見、全citation を現物で確認。004 は `verdict-lib` に依存せず 2 関数を再実装する設計
（r1 finding 14 の remedy）だが、その再実装が写しているのは **008 が置き換える版**である。

`docs/specs/008-verdict-domain-soundness.md:186-189`（決定 = (a) `U256` 化 + ABI 拡幅）、
`:228-234`（**全 preimage を fixed-width big-endian に、全ドメインタグを `v2` へ**）、
`:281-308`（新 preimage）を 004 の §4.1 と並べる:

| | 004 §4.1（`:369-377`） | 008 後（`008:289-300`） |
|---|---|---|
| `planHash` | `caller ‖ target ‖ calldata ‖ value`、タグ無し | `"reckn/zk/plan/evm/v2" ‖ caller ‖ target ‖ value:U256BE ‖ **gas_limit:u64BE** ‖ len(calldata):u64BE ‖ calldata` |
| `dealBinding` | `"…/v1" ‖ state_root ‖ address ‖ slot ‖ **le64(min)** ‖ **le64(max)** ‖ planHash`（平坦） | `"…/v2" ‖ state_root ‖ **env_hash** ‖ check_hash ‖ plan_hash`（入れ子） |
| `guestTraceHash` | `"reckn/zk/reexec/v1" ‖ … ‖ **le64(pre/post/min/max)**` | `"reckn/zk/reexec/v2" ‖ … ‖ **U256BE**` |

具体的な帰結は 4 つあり、いずれも「pin 値の再測定」では直らない:

1. **AC-7(d) が再び「誰も通せない AC」になる。** これは r1 BLOCKER 2 の defect が
   実行順によって復活する形である。004 は fixture の preimage を
   `testkit::anchored_sstore_witness(addr(0xca), addr(0x77))`（slot 7 = 42、post = 142）から
   組み直すと書く（`:404-428`）。だが `008:882-890` は同じファイル
   `reexec-groth16-fixture.json` を **`pre = 2^64` / `post = 2^64 + 100`** で再生成すると
   明記し、`:891-893` で「headline fixture の `pre = 2^64` は 008 前の guest では作れない」と
   書いている。**`anchored_sstore_witness` はその prestate を作らない。**
   AC-7(d) は pin がずれるのではなく、**組み直しのレシピが存在しなくなる**。
2. **AC-6 が出力を義務づけている 1 行（`:687`）が偽になる。**
   `u64 crossing is unreachable from this input surface only; the divergence itself is task
   008's, not closed here.` — 008 が閉じた後にこの文を gate が印字するのは、
   `AGENTS.md` §5 の「解消したかのように書かない」の逆向きの違反（**解消済みを未解消と書く**）。
   同じ AC が要求する `delta_outcome(u64_low(pre), u64_low(post), …)` の再実装は、
   `008:186-189` が削除する関数の再実装である。
3. **INV-2（`:1182-1184`）が偽になる。** 008 の `dealBinding` は `env_hash`（`spec_id` と
   block env を含む、`008:283-287`）を束ねるので、`dealBinding` は
   `(STATE_ROOT, TARGET, CHECK_SLOT, MIN_OUT, MAX_DELTA, planHash)` **のみ**の関数ではなくなる。
   AC-18（`:880-889`）が 12 の `spec_id` を振る以上、004 の面でこれは可視化する。
4. **§11 の D-1（`:1200-1205`、`planHash` が `gas_limit` を束ねない、"founder 裁定待ち"）は
   `008:292-294` が既に閉じている。** 004 は解決済みの穴を open として提示する。

**repro**: 008 を仕様どおり実装して fixture を再生成し、004 の `guest-fixture-check` を走らせる。
`§4.3` の preimage レシピは新 fixture の `pre` を再現できず、v1 の le64 pin は 6 件とも外れる。
`PinDrift` は発火するが、`PinDrift` の remedy（`:287-288`「同じ commit で再測定して更新する」）は
**値の更新しか指示していない**ので、004 は初手で停止し founder に返る。

**round 3 で直すもの**: (i) §4.1 の 3 関数を**リテラルの式ではなく `zk-verdict` HEAD への参照**として
定義し、literal hex を「2026-09-04 時点・pre-008」と明示する。(ii) AC-7(d) を
「fixture の preimage を、そのとき `zk-verdict/script/src/bin/reexec.rs` の
`build_input` が使っている構成子から組み直す」と書く（関数名を固定しない）。
(iii) AC-6 を「guest の verdict 関数（008 後は `U256`）と 004 の off-chain 結果が
受理域 8 点で一致する」に一般化し、義務づけ文言を 008 の状態に応じた 2 分岐にするか削る。
(iv) §11 の D-1 を「**008 が閉じた**」に書き換える。
(v) §3.4 の `DELIVERED_MAX` を「008 前の暫定」から「004 の入力面の設計上の上限」に
書き直すか、008 後は撤廃すると明記する（008 後は `AmountWouldTruncate` に正当化が残らない）。

---

**2. [BLOCKER] `docs/specs/004-live-adversarial-input.md:573-585`（§6.1）/ `:543-571`（§6.0）/
`:1078-1112`（§8.2）/ `:1140-1150`（§9）
— 「再実行が走ったこと」を担保するとされた NC-19 は、受入条件のどこからも走らない。
そして §6.1 の「2 つ目のエンジンが要る」は偽。**

Codex は COUNT CONTRACT の偽造可能性として同じ穴を指した（BLOCKER 2）。**採用し、
より強い形に差し替える** — 敵対的な実装者を仮定しなくても穴は開いている。

- **(a) 負のコントロールが受入条件に無い。** §6.1（`:583-585`）は
  「**NC-19（§8.2）が白箱側の担保である**」と書く。だが §6.0 の 24 gate の表に
  `negative-controls` の行は無く、§9（`:1140-1147`）の `scripts/004-live.sh` の
  サブコマンドは `all / demo / scope-guard / forge-green / determinism / lint-claims /
  scope-check / check-counts` で、`scripts/004-negative-controls.sh` は**別の成果物として
  列挙されているだけ**。`grep -n "negative-controls" docs/specs/004-live-adversarial-input.md`
  → AC からの参照は **0 件**。つまり **NC-1〜NC-24 を 1 行も書かない実装が 24 gate 全部で緑になる。**
  r1 finding 1 の remedy の中核が、受入条件の外に置かれている。
- **(b) §6.1 の「2 つ目のエンジン」は偽。** `:576-582` は「AC-4 / AC-17 / AC-18 / AC-20 を
  同時に満たすには intrinsic gas と SSTORE メータリングと EIP-3855 と MPT 証明検証を実装する
  必要がある。それは退化した模型ではなく 2 つ目のエンジンである」と書く。
  **これらの AC の入力集合は有限で、しかも仕様が全部公開している**: AC-4 = 8 amount、
  AC-17 = 6 fixture、AC-18 = 12 spec_id。**合計 26 行のルックアップ表**（amount → gasUsed、
  fixture 名 → error 文字列、spec_id → (verdict, gas)）で 3 gate とも通る。
  ルックアップ表はエンジンではない。r1 の `fake_reexec` は死ぬが、それは
  「値を書き写さなかった模型」が死ぬというだけである。
  **正直さの告白（「それでも証明ではない」）が、その 2 文前の過大主張を覆う位置に置かれている** —
  founder の低信頼点 1 が疑ったとおり。
- **(c) COUNT CONTRACT は「走った」を測っていない。** `:43-49` と `:569-571` の
  `check-counts` は、**被検査プログラム自身が印字した文字列**を厳密一致で照合する。
  gate 本体を `println!(expected 行); Ok(())` に置換した実装は 24 gate 全部で緑になり、
  NC-24（`:1108`、「COUNT CONTRACT を**外す**」）はこの変異を覆わない。
  §6.0 の「**「緑だが 0 件走った」は COUNT CONTRACT で必ず落ちる**」（`:47-48`）は偽。

**repro**: (i) `scripts/004-negative-controls.sh` を作らずに `bash scripts/004-live.sh all` を
走らせる → 緑。(ii) `replay()` を呼ばず、上記 26 行の表と `println!` だけを持つ
`reckn-live` を書く → 24 gate 全部 + `check-counts` が緑。

**round 3 で直すもの**: (i) `negative-controls` を §6.0 の 25 番目の gate にし、
**NC ごとに「どの gate が落ちたか」を印字させ、期待と厳密一致**させる（NC-19 は 3 gate 名を要求）。
(ii) NC-25 を追加: 「gate 本体を、自分の成功行を印字するだけの実装に差し替える」→
`negative-controls` が落ちること。(iii) **少なくとも 1 つの gate の入力集合を実行時 seed で
生成する**（AC-3 が claim に対して既にやっている device を amount に適用する。
例: seed から K 個の amount を引き、`gasUsed` を intrinsic + SSTORE の解析式と突き合わせる）。
表に書けない入力集合が 1 つあれば、ルックアップ表は死ぬ。
(iv) §6.1 の「2 つ目のエンジンである」を削り、「**有限で公開された入力集合に対する黒箱 AC は
ルックアップ表で通る。replay が呼ばれたことを担保するのは白箱の負のコントロールだけであり、
それは gate に入っている**」に書き換える。

---

### MAJOR

**3. [MAJOR] `docs/specs/004-live-adversarial-input.md:830-843`（AC-15）/ `:1131-1134`（§8.4）
— 禁止語 `settled` が、既存の・真である・別 tier の記述と衝突する。**

Codex 発見、現物で確認。AC-15 は `README.md` と `SUBMISSION.md` の**全文**を走査し、
`settled` を禁止語に含める（r1 finding 7 の remedy）。実測:

```
README.md:35        → settled on the proof alone**, on EVM or Solana (real fixture data).
SUBMISSION.md:187     proven → verified on-chain → settled on the proof alone**, on EVM or Solana (real
```

この 2 文は 004 の主張ではなく、**committed fixture と `forge test` が裏づける zk 経路の
真の記述**（`zk-verdict/contracts/test/RecknZkEscrow.t.sol` の 4 テスト、本日 12 件を確認）。
仕様どおり実装すると、004 は自分の local-only tier のために**別 tier の真の主張を削る**か、
gate が落ちて止まるかの二択になる。r1 finding 5 後半（「正しい実装でも充足不能」）と同型で、
今回は自分の禁止語リストが自分の README に発火している。

**repro**: `grep -n "settled" README.md SUBMISSION.md` → 2 件。004 の作業を 1 行も
始めていない状態で `lint-claims` が落ちる。

**修正**: 禁止語の走査単位をファイル全体から **004 が所有する区画**に落とす
（`<!-- 004:begin -->` / `<!-- 004:end -->` マーカー、または `dashboard/live.html` と
`docs/transcripts/004/NOTES.md` に限定）。`settled` を全域禁止語に置くなら、
禁止語を `004 settled` / `this demo settled` のような 004 の主張に固有の語形にする。

---

**4. [MAJOR] `docs/specs/004-live-adversarial-input.md:733-738`（AC-9）と `:743-746`（AC-10(a)）
— 2 つの AC が同時に満たせない。**

私の独立検出。AC-9 は同一 attempt を `stub` / `forced-unavailable` / `forced-kill` の 3 モードで
走らせ、`forced-kill` で **`judge.kind = "unavailable"`** になることを要求する（`:736`）。
AC-10(a) は **transcript の全行**が `judge.kind ∈ {stub, cli, http}` を持ち、さらに
`judge.model`（`:743-744`）と `judge.rawResponse`（**生の応答全文**、`:745`）を持ち、
「**1 つでも欠けたら非ゼロ終了**」と要求する。

- `"unavailable"` は許容集合に無い。
- 到達できなかった判事に `judge.model` も `rawResponse` も存在しない。
- `forced-unavailable` / `forced-kill` は §7.1 の mode 表（`:929-933`）に無く、
  §3.5 の `JudgeTimeout` / `JudgeResponseTooLarge`（`:303-305`）に対応する `judge.kind` も未定義。

AC-9 の 3 行が監査対象 transcript に載るなら AC-10(a) が落ち、載らないなら
AC-9 の「transcript の `reexec` サブオブジェクトが 3 件ともバイト同一」の対象が未定義になる。
`AGENTS.md` §7 の「仕様が本当に曖昧」に該当し、実装者は停止して founder に返す。
（BLOCKER にしないのは、中心主張が偽のままデモできる型の欠陥ではなく、
修正が `judge.kind` の許容集合の 1 行だからである。）

**repro**: AC-9 を実装して 3 行を `docs/transcripts/004/attempts.jsonl` に追記し、
`cargo run -p reckn-live -- audit --fields` を走らせる → 非ゼロ終了。

**修正**: `judge.kind ∈ {stub, cli, http, unavailable, timeout, oversize, unparseable}` に広げ、
**`NO_CONTEST` 系の行では `judge.model` / `rawResponse` が `null` であってよい**ことを明記する
（`judge.promptHash` は全行で必須にしてよい）。§7.1 の mode 表に forced 系のテスト専用モードを載せる。

---

**5. [MAJOR] `docs/specs/004-live-adversarial-input.md:747-751`（AC-10(b)）/ `:833-837`（AC-15）/
`:1102`（NC-17）— `attemptId` を引用しない誇張文は、どの検査にも捕まらない。**

Codex 発見、現物で確認。AC-10(b) が母集合にするのは
「`attemptId` を**引用している**文」だけである（`:747-748`）。したがって
`README.md` に `A language model was persuaded by the seller's claim.` と
**attemptId なしで**書けば、`audit --docs` の走査対象に入らず、manifest 件数とも一致し、
AC-15 の禁止語 10 件（`:833-837`）にも該当しない。NC-17（`:1102`、「stub の run を
README で『LLM was persuaded』と**引用する**」）は引用がある場合しか覆わない。

004 の AC-10 の見出しは「走らせていないものを passing と書かない」であり、
これはその見出しが名指しで防ごうとしている状態そのものである。

**repro**: `README.md` に上記 1 文を追記（attemptId 無し）、`doc-claims.json` は空のまま。
`cargo run -p reckn-live -- audit --docs && bash scripts/004-live.sh lint-claims` → 両方 exit 0。

**修正**: AC-10(b) の母集合を反転する — `LLM` / `language model` / `model` / `persuaded` /
`judge` の語彙を含む文を集め、**解決可能な `attemptId` を持たない文があれば失敗**にする。
（引用のある文の判定は現行のままでよい。）

---

**6. [MAJOR] `docs/specs/004-live-adversarial-input.md:301-305`（§3.5）/ `:733-738`（AC-9）/
`:892-902`（AC-19）— stress 経路が定義されているだけで、受入条件が 1 つも当たっていない。**

Codex 発見、現物で確認。r1 finding 17 の remedy として `JudgeTimeout`（20 秒）と
`JudgeResponseTooLarge`（16 KiB）が §3.5 に足されたが、**それを実行する AC が無い**。
AC-9 が使うのは `forced-unavailable` / `forced-kill` という 004 自身の合成モードで、
実際にハングするサブプロセスでも、16 KiB を超えるストリームでも、第 1 非空行が
`APPROVE`/`REJECT` でない実応答でもない。「合成モードだけを特別扱いする実装」が通る。

同様に AC-19(3)（`:895`）は「同じ `seq` を持つ行の追記が `SeqConflict` で拒否される」だけで、
r1 finding 9 の repro(a)（`POST /attempt` を**同時に 2 本**）を検定していない。
逐次の重複テストはロックが競合安全であることを 1 ビットも示さない。

**repro**: 判事コマンドを `sh -c 'sleep 60'` にして 1 attempt を流す → 仕様上 20 秒で
`JudgeTimeout` のはずだが、それを落とす AC が無いのでハングしたまま緑になりうる。
`seq` については 2 本の同時 POST で両方 `seq = N` を選ぶ実装が AC-19(3) を通る。

**修正**: `live-input/fixtures/judges/` に committed のスクリプト判事 3 本
（(a) 20 秒超スリープ、(b) 不正な第 1 行、(c) 16 KiB + 1 バイト）を置き、
`judge-independence` の expected を 3 → 6 に上げて、有界時間で終わること・
プロセスが kill されること・分類が `NO_CONTEST` であることを検定する。
AC-19 に (6) を足し、**同時 2 POST で 2 行が連続する別 `seq` を得て `prev` 連鎖が有効**であることを要求する。

---

**7. [MAJOR] `docs/specs/004-live-adversarial-input.md:284-288`（§3.4）/ `:687`（AC-6）
— `DELIVERED_MAX` が回避策であるという開示が、審査員が見る面に 1 つも無い。**

私の独立検出。§3.4 の囲み（`:284-288`）は「**デモ・README・提出文で同じ言い方をする**」と
明記している。だがそれを機械強制する AC は 1 つも無い:

- AC-6（`:686-687`）は開示文を **`selftest --u64-boundary` の stdout** に印字させるだけ。
- AC-15（`:830-843`）は `fixes the u64` / `closes the u64` を**禁止**するだけで、
  正の開示文を要求しない（要求されている必須文は「finite corpus」の 1 文のみ、`:831-832`）。
- 観客が `DELIVERED_MAX` を超える数を打つと `AmountWouldTruncate` が返るが（§3.5、`:299`。入力検証は `:280`）、
  **その理由を UI に出す要求がどこにも無い。**

結果として、「なぜこの入力面には上限があるのか」の答えは selftest の stdout にだけ存在する。
`AGENTS.md` §5 の「Honest scope を解消したかのように書かない」は、
**書かないこと**ではなく**見えるところに書くこと**でしか満たせない。

**修正**: AC-15 の必須文に 1 行足す
（`This demo's input surface stops short of the u64 boundary; the boundary itself is task 008's.`）、
`dashboard/live.html` を対象に含める。`AmountWouldTruncate` の UI メッセージに同じ理由を載せる。
（008 が閉じた後の扱いは finding 1 の (v) と同じ判断に従う。）

---

### MINOR

**8. [MINOR] `:284`（§3.4）— 「u64 の縁に**触れない**」は正確でない。**
Codex の末尾所見を採用。`deliveredBaseUnits = DELIVERED_MAX` は受理され、
`post = u64::MAX` **ちょうど**になる（`:282`、AC-1 / AC-4 / AC-6 / AC-20 が 4 箇所で
その点を検定している）。入力面は縁に**乗る**が**越えない**。
この文はデモ・README で復唱することが §3.4 で義務づけられているので、語形を直す:
「触れない」→「**越えない（縁ちょうどまでは受理する）**」。

**9. [MINOR] `:544` / `:552` / `:556`（§6.0）— expected 件数が列挙ケースと突き合わない gate が 3 つ。**
私の独立検出。COUNT CONTRACT は `N != M` で**何も実行せず exit 2** と定めるので、
`N` と「ケース」の定義がずれる gate は実装開始時に停止する。
- AC-0 `scope-guard` は `5`（`:544`）だが、AC-0 本文（`:594-611`）は
  `no-keys.sh` 1 件 + 5 パスの diff = **6 件**を列挙する。
- AC-7(e) `forge-green` は `4`（`:552`）だが、本文（`:705-709`）は
  名指し 4 テスト + failure 0 件 + 総数 ≥ 12 = **6〜7 件**を検定する。
- `docs-claims`（`:556`）だけ expected が数値でなく「manifest 長」＝**実装が数えて決める数**であり、
  §6.0 の「`N` は表が固定した数であり実装が数えて決める数ではない」（`:44-45`）に反する。
  `check-counts` の**厳密文字列一致**（`:47`）はこの gate を原理的に照合できない。
**修正**: 各 gate の「1 ケース」の単位を表に定義し、AC-0 = 6 / AC-7(e) = 7 に直す。
`docs-claims` は expected を `doc-claims.json` の要素数として**独立に読む**（`jq length` 相当）と書き、
`check-counts` はその値と gate 出力を突き合わせる。

あわせて内部相互参照が 1 件古い: **N-9（`:149`）が「T-6（cold clone / offline）」を指すが、
§8.1 の表で cold clone / offline は現在 **T-8**（`:1069`）であり、T-6（`:1067`）は
`INVERTED` セルの行になっている**（§12 OQ-3 の `:1226` は正しく T-8 を指している）。

**10. [MINOR] `:1180`（INV-3）— 同じ文書の AC-18 が INV-3 を反証している。**
私の独立検出。INV-3 は「`Reproduced` ⟺ `deliveredBaseUnits ∈ [MIN_OUT, MAX_DELTA]`。
**他のいかなる入力もこれを変えない**」。AC-18（`:880-889`）は `spec_id` を 8 通りに振って
`deliveredBaseUnits = 1024000000`（∈ 区間）で `Failed(Execution)` を得ることを**要求**する。
**修正**: INV-3 に「§3.3 の FIXED 環境の下で」を付す。

**11. [MINOR] `:1200-1205`（§11 D-1）— 解決済みの穴を open として提示している。**
私の独立検出。D-1（`planHash` が `gas_limit` を束ねない、「protocol の版上げが要る」「founder 裁定待ち」）は
`008:292-294` が `plan_hash` v2 に `gas_limit:u64BE` を入れて閉じる。
finding 1 の一部だが、round 3 で見落とされやすいので単独で記録する。

**12. [MINOR] `:1224-1228`（OQ-3）— 008 を読めば founder 裁定なしで閉じられる。**
Codex の末尾所見を**理由を差し替えて**採用。`008:343-349` は
「各ベクタについて (i) `reckn_reexec_evm::replay(...)` と (ii) **実 guest ELF** を SP1 `execute()` で
走らせて一致を主張する差分テスト」を 008 の AC として既に持っている。
004 の OQ-3 は「**もし 008 がこの差分テストを持つなら、004 は何も足さない**」と自分で書いており、
条件は既に真である。**founder 裁定は不要**で、004 は OQ-3 を「008 が持つので 004 は追加しない」と
閉じるだけでよい。
（Codex の remedy「004 should depend on that completed upstream gate」は**却下**。下記 Rejected 参照。）

---

## Rejected findings

- **Codex #12 の remedy「004 は 008 の差分 gate に依存すべき」** — 却下。004 の N-9（`:148-151`）と
  T-8（`:1069-1077`）は「SP1 toolchain を 004 の緑の条件にすると offline 再現が偽になる」と書いており、
  この判断は正しい（`CLAUDE.md`「`~/.sp1` に v6.1.0 の ~6.2GB artifacts が要る」）。
  上流の gate に緑を賭けるのは 004 が正しく避けている依存の逆流そのもの。
  **finding 12 は「OQ を閉じてよい」の部分だけを採用**した。

- **「AC-7(d) は Failed 側の outcome byte を外部アンカーしていない」（私の候補）** — 証拠で却下。
  fixture は `outcome = 0` の 1 点しか持たないが、`zk-verdict/lib/src/lib.rs:35-36` が
  `REPRODUCED = 0` / `FAILED = 1` を定め、AC-20 の pin（`:914`、amount `0` → outcome 1）は
  **その値でしか再現しない**ことを本日再計算で確認した（一致）。
  outcome の符号化は AC-20 の pin で十分に固定されている。
  （残る唯一の drift channel は可変長 calldata の扱いだが、004 の calldata は常に 32 bytes なので
  観測不能であり、004 の面では被害が無い。）

- **「pin 群は起草時の自己申告であって検証されていない」（founder の疑いの一般形）** — 却下。
  §0 の表のとおり **11 種類の pin を独立に再計算して全件一致**した。
  特に `STATE_ROOT` 2 本は仕様の記述だけから独立実装の MPT で再構築して一致しており、
  「実測した」という主張は真である。

- **「T-8 の cold clone と offline が矛盾する」（私の候補）** — 却下。
  `:1071-1077` は cold clone（git）と cold cargo registry を区別し、
  「依存が既に取得済みのマシンに限る」「clone してすぐ offline で動くとは書かない」と明記している。
  r1 finding 16 は正しく閉じている。

- **「AC-11(b) は self-refereed のままだ」（founder の疑い）** — 却下、ただし語形は要修正（下記）。
  §7.4 の判事規則も §7.5 の corpus も**本仕様が固定**しており、実装者はどちらも書けない。
  本日、規則を独立実装して 32 件を採点し、仕様の期待ベクタと **32/32 一致**した。
  したがって AC-11(b) は「実装者の自作自演」を許さない。
  **ただし AC-11(b) が測っているのは仕様定義関数への適合であって「一般化」ではない**
  （`:772` の見出し「(b) 一般化」は誤称）。仕様が判事側を書いた以上、これは正しい設計であり、
  004 の主張が判事に依存しなくなった（founder 裁定）ことでその限界は無害になっている。
  round 3 では**見出しを「(b) 適合（conformance）」に直すだけ**でよい。

- **「AC-11(a) は無意味な AC を残しただけ」（founder の疑い）** — 却下。
  `:764-771` は母集合（`mutations-v1.json` の 32 文字列）と走査対象（`live-input/src/**` と
  `dashboard/live.html`、`fixtures/**` と `prompts/**` は除外）を確定し、POSITIVE CONTROL を持ち、
  「base64 1 行で破れる」ことを明記して tripwire に降格している。
  **測っている性質は狭いが空ではなく**（リテラル canned 分岐は実際に落ちる）、
  NC-11（`:1096`）が「符号化された分岐は `no-canned` を**抜ける**」と明示的に記録している。
  これは正直であって、無意味ではない。

---

## Deferred

新規の deferred は無い。r1 の D-1 は **008 が閉じるので繰延ではなく解決**（finding 11）、
D-2 / D-3 は 008 が引き取り済み、D-4（OQ-1）は §12 に残る founder 裁定、
D-5（OQ-2）は founder 裁定で決着済み。

---

## founder の低信頼点への回答

**① 「再実行しか作れない量」への結び直しは効いているか — 半分。そして正直さは主張の弱さを覆っている。**
pin は本物である（§0 の 11 件、全て再計算一致）。r1 の `fake_reexec`（`gas_used: 43_217` の
算術模型）は AC-4 で確実に死ぬ。**しかし AC-4 / AC-17 / AC-18 の入力集合は有限で、
仕様が 26 行すべてを公開している。** amount → gasUsed の 8 行、fixture 名 → error 文字列の 6 行、
spec_id → (verdict, gas) の 12 行を持つルックアップ表は、`replay()` を 1 度も呼ばずに 3 gate を通る。
§6.1 の「それは 2 つ目のエンジンである」（`:581-582`）は**偽**であり、その 1 文あとの
「それでも証明ではない」という告白が、**直前の過大主張を読み手の目から隠す位置に置かれている**。
効いているのは値上げであって、値上げ幅は「26 行を書き写す」である。
決定的なのは白箱の NC-19 だが、**それは受入条件の外にある**（finding 2）。
round 3 で必要なのは pin を増やすことではなく、(a) 負のコントロールを gate にすること、
(b) 少なくとも 1 gate の入力集合を実行時 seed にすること（表に書けなくすること）である。

**② AC-7(d) は guest との一致を強制しているか — 008 前の guest に対しては YES、008 後は NO。**
本日、fixture の committed `deal_binding` / `trace_hash` を §4.1 の式から再計算して**両方一致**した。
判別軸を全部数えた: `min = 100`（le/be 判別可）・`pre = 42` / `post = 142`（同）・`slot = be32(7)`（同）・
ドメインタグ・フィールド順・`gas_limit` の不在・`outcome` の符号化（AC-20 の pin が固定）。
**「再実装が guest とずれたまま両方一致する経路」は、004 の入力面では見つからなかった。**
唯一残る channel（可変長 calldata の区切り）は 004 の calldata が常に 32 bytes なので観測されない。
**しかし `PinDrift` では不十分である。** 008 は値を変えるのではなく、
preimage の**構造**（平坦 → `env_hash`/`check_hash`/`plan_hash` の入れ子）と**ドメインタグ**（v1 → v2）と
**fixture の prestate 自体**（`pre = 42` → `pre = 2^64`、`008:882-890`）を変える。
`§4.3` の組み直しレシピ（`testkit::anchored_sstore_witness`）は新 fixture を再現できない。
`PinDrift` は「同じ commit で pin 値を再測定して更新する」としか書いておらず、
**式そのものが変わる場合の指示が無い**。004 は実装初手で停止して founder に返る（finding 1）。

---

## round 3 で直すもの（CHANGES の具体リスト）

1. §4.1 / §4.3 / AC-6 / AC-7(d) / AC-20 / INV-2 / §11 D-1 / §3.4 を **008 後の guest に対して**書き直す
   （関数を参照で定義し、literal hex を「pre-008」と明示し、AC-7(d) の組み直しを構成子名で固定しない）。— finding 1
2. `negative-controls` を §6.0 の gate にする。NC-25（gate 本体を成功行の印字だけに置換）を追加する。
   §6.1 の「2 つ目のエンジンである」を削り、ルックアップ表で通ることを明記する。— finding 2
3. 少なくとも 1 gate の入力集合を実行時 seed にする（amount 側の fuzz）。— finding 2
4. AC-15 の走査単位をファイル全体から 004 所有区画へ落とす（`settled` が README/SUBMISSION の
   真の記述に発火する）。— finding 3
5. `judge.kind` の許容集合を広げ、`NO_CONTEST` 系で `judge.model` / `rawResponse` が
   `null` でよいことを書く。§7.1 の mode 表に forced 系を載せる。— finding 4
6. AC-10(b) の母集合を「語彙を含む文」に反転し、attemptId 無しの誇張文を落とす。— finding 5
7. committed のスクリプト判事 3 本で `JudgeTimeout` / `JudgeResponseTooLarge` / 不正応答を実行する。
   AC-19 に同時 POST の項を足す。— finding 6
8. `DELIVERED_MAX` の理由を `dashboard/live.html` と `AmountWouldTruncate` のメッセージに出す
   （AC-15 の必須文に足す）。— finding 7
9. §3.4 の「縁に触れない」→「縁を越えない」。§6.0 の expected を AC-0 = 6 / AC-7(e) = 7 に直し、
   `docs-claims` の expected を manifest から独立に読む。N-9 の「T-6」を「T-8」に直す。
   INV-3 に環境の限定を付す。
   §11 D-1 を「008 が閉じた」に直す。OQ-3 を `008:343-349` を引いて閉じる。
   AC-11(b) の見出しを「一般化」→「適合」に直す。— findings 8–12

---

VERDICT: CHANGES
