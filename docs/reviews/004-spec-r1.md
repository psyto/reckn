# Review 004 spec round 1

Payload: `/tmp/reckn-payload-004-spec-r1.md`
Codex raw: `/tmp/reckn-codex-004-spec-r1.md`

Codex 呼び出しは 1 回（`codex exec -C . -s read-only`、payload は起動前に全文表示済み）。
対象 `docs/specs/004-live-adversarial-input.md` は **Claude Code が起草**したものであり
Codex ではない（author independence 上、Codex は正当なレビュー主体）。その旨は payload §冒頭に明記した。

Codex は 8 件（BLOCKER 3 / MAJOR 4 / MINOR 1）を返した。以下は**私の裁定**であり、
採用したものは現物で裏を取り、落としたものは証拠を添えた。Codex が見落とした 6 件を追加した。

---

## Findings

### BLOCKER

**1. [BLOCKER] `docs/specs/004-live-adversarial-input.md` §6（AC-0〜AC-16 全体）
— どの AC も `reexec_evm::replay` が走ったことを要求していない。**

これは founder が最も疑っていた点そのもので、**疑いは正しい**。AC-3（散文不変性）と
AC-4（結果感応性）の対は「定数を返す実装」を落とすが、**「決定的な算術模型」を落とさない**。

再実行を 1 度も呼ばない退化実装（Codex が構成、私が AC ごとに検算した）:

```rust
fn fake_reexec(amount: U256) -> ReexecRecord {
    let pre  = U256::from(2_000_000_000u64);
    let post = pre + amount;                       // 実行ではなく算術
    let ok   = amount >= U256::from(MIN_OUT);
    ReexecRecord {
        verdict: if ok { "Reproduced" } else { "Failed" },
        pre, post, delta: amount,
        prestate_root: FIXED_ROOT,                 // 定数
        trace_hash: sha256(b"fake-trace-v1" ‖ amount.to_be_bytes()),
        gas_used: 43_217,                          // 誰も検査しない
        deal_binding: real_binding(amount),        // ここだけ本物
    }
}
```

AC ごとの通過理由: AC-0 契約に触れない / AC-1・AC-2 パーサは本物 / AC-3 金額固定なら
バイト同一 / AC-4 反転点は算術で正確 / AC-5 `delta = 0` を返し `--predicate-discriminates`
の対比出力はハードコード / AC-6 `U256` 算術と `delta_outcome` の呼び出しで一致 /
AC-7 binding だけ本物に計算 / AC-8〜AC-16 すべて形式要件。

**なぜ落ちないか**: 仕様は `reexec` サブオブジェクトの**形**（フィールドの存在・一致・不変性）
しか要求しておらず、**その値が本物の engine の出力であることを固定する値が 1 つも無い**。
`state_root` は「全 attempt で同一」としか言われず（AC-14 / INV-8）**具体値が committed でない**。
`gasUsed` はどこでも数値が固定されていない。`traceHash` は「3 回同一」だけで、
`reexec_trace_hash(state_root, pre, post, min, max, outcome)`（`zk-verdict/lib/src/lib.rs:53-` の
関数形）と一致することが要求されていない。

repro: 上記 `fake_reexec` を唯一の実装として `selftest --domain --prose-invariance --sweep
--noop --predicate-discriminates --u64-boundary --binding --judge-independence --scoreboard
--mutations --render` と `audit --docs --no-canned` を全部走らせて緑になること。

修正（最小）:
- §3.3 に **`STATE_ROOT` の 32 byte 具体値**を committed 定数として書き、AC で文字列一致を要求する。
- AC-4 の 5 点それぞれについて **`gasUsed` の期待値**（実測して committed）を要求する。
- **`traceHash` が `zk-verdict/lib::reexec_trace_hash` の出力と一致**することを AC にする
  （模型では `state_root` を知らないと作れない）。
- 負のコントロールに **NC-19「`replay()` 呼び出しを上記 `fake_reexec` に差し替える」→ 落ちるべき AC**
  を追加する。これが無い限り 8.2 の負のコントロール表は「中心主張の検定」を 1 件も持たない。
- witness を故意に壊した固定 fixture で `EngineError(InvalidWitness)` になることを AC にする
  （模型は `OperationalError` を作れない）。

---

**2. [BLOCKER] `docs/specs/004-live-adversarial-input.md` §6 AC-7(d)
— 指名されたフィクスチャに `dealBinding` が存在せず、どのフィクスチャにも preimage が無い。**

AC-7(d) は
`reckn-live binding --from-fixture zk-verdict/contracts/src/fixtures/groth16-fixture.json` が
「そのフィクスチャの `dealBinding` とバイト同一の値を再計算する」ことを要求する。現物:

- `zk-verdict/contracts/src/fixtures/groth16-fixture.json` のキーは
  `pre / post / min_delta / max_delta / outcome / trace_hash / vkey / public_values / proof`。
  **`deal_binding` フィールドは無い**（これは述語 guest `program` のフィクスチャで、
  `dealBinding` を持つのは `reexec-groth16-fixture.json` の方）。
- 正しい `reexec-groth16-fixture.json` にしても、そこにあるのは `deal_binding` の**値だけ**で、
  再計算に要る preimage（`state_root` / `caller` / `target` / `calldata` / `value` /
  `check.address` / `check.slot` / `min` / `max`）が**1 つも入っていない**。
  `public_values` も `VerdictPublicValues` の ABI 符号化＝`dealBinding` を含むが preimage は含まない。

すなわち AC-7(d) は**どんな実装でも通せない**。これは Codex の退化実装表が「AC-7 は本物の
binding を計算すれば通る」と書いて素通りした箇所であり、AC-7(d) は 004 の中で
**唯一「binding 計算が guest と同一関数である」ことを外部の固定物に対して検定する条項**なので、
これが空振りすると finding 1 の穴がさらに広がる。

repro: `python3 -c "import json;print(sorted(json.load(open('zk-verdict/contracts/src/fixtures/groth16-fixture.json'))))"`
→ `deal_binding` が無い。`reexec-groth16-fixture.json` でも同じコマンドで preimage 欠如を確認。

修正: `dealBinding` の preimage は `zk-verdict/script/src/bin/reexec.rs:78-141`（`build_input`、
`testkit::anchored_sstore_witness` で slot 7 = 42、`caller = addr(0xca)`）が決めている。
AC-7(d) は「`reexec-groth16-fixture.json` の `deal_binding` を、`build_input` と同じ入力を
004 側で組み直して再計算し一致させる」か、あるいは**004 が自分の fixture の preimage を
committed にして、そこから計算した `dealBinding` を committed 期待値と照合する**形に書き直す。
前者を採るなら「zk-verdict は独立 SP1 workspace」（`CLAUDE.md`）との依存関係を明記すること。

---

**3. [BLOCKER] `docs/specs/004-live-adversarial-input.md` §3.3
— FIXED の列挙が `replay()` の読む環境を網羅していない。**

§3.3 は「FIXED 群は仕様が固定。観客もエージェントも実行時に変更できない」と書き、
`CHAIN_ID / BLOCK_NUMBER / BASE_FEE / CALLER / TARGET / CHECK_SLOT / PRE_SLOT_VALUE /
PREDICATE / MIN_OUT / MAX_DELTA / PLAN.* / TEMPLATE / TARGET runtime` を挙げる。
だが `reexec-evm/src/lib.rs:489-512` は `anchor.spec_id` / `timestamp` / `block_gas_limit` /
`coinbase` / `prevrandao` を、`:459-462` は `block_header` を読む。**どれも §3.3 に無い。**

結果として:
- `TARGET runtime = 0x5f545f35015f5500` の先頭 `0x5f` は **PUSH0（EIP-3855, Shanghai）**。
  `spec_id` が未固定なので、Shanghai 未満を選ぶと**同じ §3.3 準拠のまま実行が失敗する**。
  「観客が選べる現実は数値ひとつ」という §3.1 の境界文が偽になる。
- `VerifiedWitnessDb` は EmptyDB フォールバックを持たない（`reexec-evm/src/lib.rs:398-443`）ので、
  **`CALLER` と `coinbase` のアカウントが witness に入っていないと `MissingAccountWitness`**
  になる。§3.3 は witness に何を入れるかを一言も決めていない。
- `state_root` の具体値も committed でない（finding 1 と同根）。

repro: 同一の `(claim, amount)` を `spec_id = SpecId::MERGE` と `SpecId::CANCUN` で走らせる。
前者は PUSH0 が invalid opcode で halt → `Failed(Execution)`、後者は `Reproduced`。
どちらも §3.3 に完全準拠している。

修正: §3.3 に anchor 全フィールド（`spec_id` / `timestamp` / `block_hash` / `block_gas_limit` /
`coinbase` / `prevrandao` / `block_header: None`）と、witness に含める account の集合
（`CALLER` / `TARGET` / `coinbase`、それぞれの nonce・balance・code・storage）と `STATE_ROOT`
の具体値を書く。AC-14 の「`state_root` は全 attempt を通じて同一」を
「**committed 定数 `0x…` と一致**」に強める。

---

**4. [BLOCKER] `docs/specs/004-live-adversarial-input.md` §9（「同じエンジンが in-guest で走り」）
— 現物では guest と off-chain の EVM は別のハードフォークで走っている。**

Codex が見落とした。§9 の「言わないこと」の直後に、004 が**言う**と宣言している文がこれ:

> 言うのは「同じエンジンが in-guest で走り、その verdict が `dealBinding` 一致で決済する。」

現物を突き合わせると:

- off-chain `reexec-evm/src/lib.rs:489-512`:
  `c.spec = anchor.spec_id` / `c.disable_base_fee = true` / `c.disable_nonce_check = true`、
  `b.number` `b.timestamp` `b.basefee` `b.gas_limit` `b.beneficiary` `b.prevrandao` を全部 anchor から設定。
- guest `zk-verdict/program-revm/src/main.rs:121-127`: **`c.chain_id = input.chain_id` だけ。**
  `spec` も block env も一切設定しない。

したがって guest は `CfgEnv::default()` の `SpecId::default()` で走る。
`~/.cargo/registry/src/…/revm-primitives-23.0.0/src/hardfork.rs:76-77` により
**`SpecId::default() == OSAKA`**。一方 off-chain の既存 fixture は
`reexec-evm/src/lib.rs:745` で **`SpecId::CANCUN`**。さらに guest は block env が全部既定値
（`number = 0` / `timestamp = 0` / `beneficiary = 0x0` / `prevrandao` 未設定）で、
`disable_nonce_check` も無いので **committed nonce ≠ 0 の caller では guest 側だけが tx を弾く**。

004 の固定 runtime（PUSH0/SLOAD/CALLDATALOAD/ADD/SSTORE/STOP）はこれらの opcode に触らないので
**verdict は今回一致する見込みだが、それは偶然であって仕様が保証したものではない**。
「同じエンジン」は現状 UNVERIFIED であり、審査員に向かって言ってよい文ではない。

repro（004 の scope 内で可能）: 004 の fixture 入力を `zk-verdict/script` の
`--execute` 経路にも通し、guest の `VerdictPublicValues`（`pre/post/outcome/traceHash/dealBinding`）が
off-chain `replay()` の結果と一致することを AC にする。一致しなければこの finding が実証される。

修正:
- §9 の台詞を「同じ**述語**と同じ `dealBinding` を使う」に落とすか、上記の一致テストを AC に入れて
  はじめて「同じエンジン」と言う。どちらかを選ぶ（両論併記にしない）。
- §11 に **guest が spec/block env を設定していない**ことを 3 件目の protocol 所見として記録する
  （004 では閉じない。finding 6 と同じ後続タスク束）。

---

**5. [BLOCKER] `docs/specs/004-live-adversarial-input.md` §6 AC-11(a)(b)
— 「1 文字列だけ効く実装キラー」が、賢い stub に回避される。**

founder の低信頼点そのもの。**回避できる。** 具体的に:

- **AC-11(a) の静的検査を抜ける**: canned 文字列をソースにリテラルで置かない。
  `const P_ENC: &str = "<base64>"` を実行時に復号して比較すれば、
  「`live-input/` のソース中にリテラルとして存在しない」は真のまま。
  長さ 8 未満の断片の連結でも同じ。**静的リテラル検査は 1 行の符号化で無効化される。**
- **AC-11(b) の 8/32 を抜ける**: 変奏を作るのも判事を書くのも**同じ実装者**である。
  判事側に「trim + 連続空白の畳み込み + case fold」の正規化を入れ、
  変奏生成器の 6 クラス（語置換 / 大小文字 / 空白挿入 / 末尾ノイズ / 日本語訳 / 順序入替）のうち
  **空白挿入と大小文字に偏重して 32 件を作れば**、正規化後は同一文字列なので 32/32 が `APPROVE` になる。
  実質は「1 文字列だけ効く実装」のまま閾値を超える。
- AC-12（judge-controls 8 件）はこれを止めない。canned 判定に落ちなかった入力を
  汎用キーワード採点にフォールバックさせれば `should-reject` 4/5・`honest` 2/3 は独立に満たせる。

加えて AC-11(a) は**逆方向にも壊れている**（正しい実装を落としうる）: AC-12 が要求する
`live-input/fixtures/judge-controls.json` の 8 件は committed な claim 文字列であり、
それらを走らせて同じ transcript に記録した瞬間、「transcript に現れた全 `claim` 文字列が
`live-input/` のソース中にリテラルとして存在しない」は**偽**になる。
fixtures がここでいう「ソース」に含まれるのか、control の run が監査対象 transcript に載るのか、
「長さ 8 以上の全部分文字列」の母集合が claim なのか transcript 全体なのかが**どれも未定義**。

repro: 上記の「符号化リテラル + 正規化判事 + 空白/大小文字偏重の変奏器」を実装し、
`audit --no-canned` と `selftest --mutations` を通す。両方緑になる。

修正:
- 変奏 corpus を**実装者が実行時に生成しない**。`live-input/fixtures/mutations-v1.json` に
  committed し、**6 クラスそれぞれ最低 4 件**を含め、`8/32` を
  「**4 クラス以上から 1 件以上を含む 8 件以上**」に置き換える。
- AC-11(a) は母集合（claim 文字列のみか transcript 全体か）と「ソース」の範囲
  （`fixtures/` を含むか）を確定し、AC-12 の control 文字列を明示的に除外する。
- 静的リテラル検査は補助に降格し、**「canned 判定を無効化しても 8/32 が保たれる」**
  という NC を追加する（NC-11 を「リテラル分岐」から「符号化された canned 分岐」に強める）。

---

### MAJOR

**6. [MAJOR] `docs/specs/004-live-adversarial-input.md` §3.4 / §11
— `u64` vs `U256` の乖離は「verdict が食い違う」ではなく「偽の release」であり、§11 に載っていない。**

Codex は MINOR としたが、**向きと到達可能性を見ると重い**。
`zk-verdict/program-revm/src/main.rs:31-33` の `u64_low(v) = v.as_limbs()[0]` は limb 0 だけを取る。

`pre = 2^64`（limbs `[0,1,0,0]` → `u64_low = 0`）、`post = 2^64 - 1`（`u64_low = u64::MAX`）のとき:

| | delta | verdict |
|---|---|---|
| off-chain `reexec-evm`（U256, `reexec-evm/src/lib.rs:641-658`） | `saturating_sub` → **0** | `Failed` |
| guest（u64, `zk-verdict/lib/src/lib.rs:40-47`） | **`u64::MAX`** | **`Reproduced`** |

つまり**残高が減ったのに最大額の credit が証明される**＝ proof が buyer の金を seller に出す。
これは「切り捨てで verdict が乖離しうる」より一段強い主張であり、§3.4 の書き方
（「verdict は乖離しうる」）はこの向きを隠している。

到達可能性: 18 decimals の ERC-20 では `2^64` base units ≈ **18.45 token**。すなわち
**残高が 18.45 token を超える口座は全部 limb 0 を跨ぐ**。`AGENTS.md` §3 のタスク **002
（実 ERC-20 ワークロード）は正面からこの領域に入る。**

004 自身は `DELIVERED_MAX` で入力面から到達不能にしており、**その回避策は 004 の scope としては正当**
（guest を変えるのは N-2 違反）。問題は**記録**の方: §11「既知の隣接する穴」に
`planHash` の `gas_limit` 欠落しか載っておらず、より重いこちらが載っていない。

repro: `pre = U256::from(1u128) << 64` / `post = pre - 1` を
`reexec_evm` の `PostStateDelta` と `verdict_lib::delta_outcome(u64_low(pre), u64_low(post), 1, u64::MAX)`
に同時に食わせ、`Failed` と `REPRODUCED`（= 0）が出ることを示す単体テスト。

修正: §11 に 2 件目として記録し、**002 の前に閉じるべき protocol 課題**として重み付けする
（founder 裁定が要る）。§3.4 の文言を「乖離しうる」から「**減少が最大 credit として証明されうる**」に直す。

---

**7. [MAJOR] `docs/specs/004-live-adversarial-input.md` §9（3 分台本）
— local only の分類を「エスクロー」「refund」「19/32 実測」と書いている。**

`tier: local only`（`:7`）でチェーンに一切触れず（INV-9）proof も作らない（N-3）のに、台本は
`0:00–0:20`「買い手は 1,024 USDC 以上の増加を条件に**エスクローした**」、
`1:00–1:30`「`Failed → refund`」と書く。`fund()` は呼ばれず、`dealId` は
`RecknZkEscrow.sol:71` の caller 供給 `dealId` とは無関係な 004 ローカルの導出である。
審査員は「on-chain で決済された」と読む。§9 の「言わないこと」は
「zk proof を作って on-chain で決済した」しか禁じておらず、**「エスクロー」「refund」は素通りする**。

同じ台本に `1:30–2:05`「左は `19/32 APPROVE`（実測比をそのまま出す）」がある。
**この run は存在しない。** AC-11(c) 側は「例 `19/32`」と書いているが、台本側には「例」が無い。
`AGENTS.md` §5「走らせていないものを passing と書かない」に正面から触れる。

repro: 台本のまま録画すると、`docs/transcripts/004/attempts.jsonl` に
`19/32` を裏づける行も、`state = Funded` の deal も存在しない。

修正:
- 台本の `refund` / `release` を **`would refund` / `would release`（分類であって決済ではない）**に直し、
  UI にも常時ラベルを出す。AC-15 の `lint-claims` の禁止語に `settled` / `on-chain refund` を足す。
- `19/32` を `<M_APPROVE>/32` のプレースホルダにし、AC-15 の「`N` のままなら失敗」と同じ機械検査に載せる。

---

**8. [MAJOR] `docs/specs/004-live-adversarial-input.md` §5.4 / §7.1
— egress 境界が `cli` モードを覆っていない。観客のバイト列が第三者に出る。**

§5 は「観客入力が到達できる範囲を全列挙する」と宣言したうえで、§5.4 で
「既定 (`stub`) は egress ゼロ。`http` モードは既定で loopback 限定。非 loopback は
`RECKN_JUDGE_ALLOW_EGRESS=1` が無ければハードエラー」と書く。だが §7.1 の表は
`cli` モードの egress を「**CLI 側**」＝無制限としている。`cli` は実モデル経路の第一候補
（§7.1 末尾、OQ-2）なので、**実際にデモで使う経路だけが境界の外にある**。

そこを通るのは**観客がその場でタイプした最大 2000 bytes の任意テキスト**である。

repro: `RECKN_JUDGE=cli RECKN_JUDGE_CMD="/opt/homebrew/bin/claude -p"` で attempt を 1 件流す。
`EgressBlocked` は発火せず、claim は外部 API に送られる。

修正: §5.4 を「`stub` = egress ゼロ / `http` = loopback 限定 / **`cli` = 第三者へ egress する。
観客のバイト列が repo 外に出る唯一の経路であり、明示 opt-in かつ UI に常時表示**」と
モードごとに書き分ける。`AGENTS.md` §8「外部サービス契約」の解釈は OQ-2 に残す（それは founder 裁定）。

---

**9. [MAJOR] `docs/specs/004-live-adversarial-input.md` §4.3 / INV-5 / AC-13
— transcript の append-only は宣言だけで、競合も改竄も検出できない。**

`INV-5` は `attemptId = sha256("reckn/004/attempt/v1" ‖ dealId ‖ claimHash ‖ seq)` を定義するが、
`seq` の一意性を保証する機構（排他 append / ロック / 連鎖ハッシュ / transcript root）が無い。
AC-13 は「スコアボードが transcript の純関数であること」しか要求しないので、
**手で足した偽の行を忠実に集計する**。AC-10(b) の `audit --docs` も
`judge.kind` が `"cli"` と書いてある行を信じるだけなので、
「stub の run を LLM と偽る」ことは**行を書き換えれば通る**。

repro:
(a) `POST /attempt` を同時に 2 本投げる（最終 seq = 7）。仕様上どちらも 8 を選べる。
(b) `docs/transcripts/004/attempts.jsonl` の 1 行を JSON として妥当な `WIN` /
`judge.kind:"cli"` に手で書き換え、`reckn-live score` と `audit --docs` を走らせる。両方通る。

修正: 各行に `prev = sha256(前行の生バイト)` を持たせ、`audit` が連鎖を検証する。
`serve` は追記を排他化し、`seq` の重複を `SeqConflict` で拒否する。
committed transcript の末尾ハッシュを `docs/transcripts/004/HEAD` に置き、commit に含める。

---

**10. [MAJOR] `docs/specs/004-live-adversarial-input.md` §1（主張文）と §12 OQ-2 — 主張が未決の OQ に依存している。**

冒頭の 1 文は「観客が自分で書いた散文で **LLM 判事**を `APPROVE` に動かせても…」である。
一方 OQ-2 は「実モデル経路を走らせてよいか」を**未決のまま**にし、
不可なら「004 の主張は『報告だけを読む決定的な模型判事を説得できる』に弱まる」と自認する。
すなわち**仕様の見出し主張が、仕様の中で未決とされた問いの答えに依存している。**

技術的に何が言えなくなるか（founder の低信頼点 2 への回答。Codex の答えと私の裁定は一致）:

- **消える**: §1 の「LLM 判事」／§9 の「判事の生の応答（model id 付き）」と `19/32`／
  AC-10 と AC-11(c) と AC-12 の実モデル側（いずれも「記録するだけ」の条項で、
  実行が無ければ**記録すべきものが存在しない**）。
- **残る**: 「**有限の corpus について、決定的再実行の verdict は claim のバイト列に不変であり、
  金額にだけ感応した**」。これは判事が 1 人も居なくても成立する。004 の**製品的な核はこちら**である。
- **strawman になるか**: `stub` は**実装者が自分で書いた採点器**なので、
  「説得された」は独立情報を 1 ビットも運ばない。AC-12 が `should-reject` 4/5 を要求しても、
  その判別力を定義したのも同じ実装者である。**判事側だけを見れば strawman**。
  ただし 004 の主張を「再実行は散文に動かない」に置き直せば、判事は**対照**であって
  主張の担い手ではなくなり、strawman 批判は当たらなくなる。

推奨（founder 裁定が要る）: §1 の主張文を判事非依存の形に書き直し、
LLM 版は「OQ-2 が可のときに**追加で**言えること」として条件付きで置く。
現状のように見出しだけ強い形は、OQ-2 が不可に倒れた瞬間に**提出文が仕様と食い違う**。

---

**11. [MAJOR] `docs/specs/004-live-adversarial-input.md` §3.2 / §3.5 / AC-2 — NUL は valid UTF-8 である。**

§3.2 は `claim` の定義域を「任意の valid UTF-8、1–2000 bytes」とする。
§3.5 と AC-2 は「NUL を含む → `ClaimNotUtf8`」を要求する。**U+0000 は valid UTF-8**
（`std::str::from_utf8(&[0u8])` は `Ok`）。正しい UTF-8 検証器はこの入力を通すので、
AC-2 は正しい実装で落ち、AC-2 を通せば §3.2 の「任意の valid UTF-8」が偽になる。

repro: `printf '\0' | reckn-live attempt --claim-stdin --amount 0` — 仕様の 2 条が同時に満たせない。

修正: 「valid UTF-8 かつ制御文字 `U+0000` を含まない」と定義し、専用のエラー名
（`ClaimHasNul`）を §3.5 に足す。`ClaimNotUtf8` は本来の不正バイト列（`0xff 0xfe`）専用にする。

---

### MINOR

**12. [MINOR] `docs/specs/004-live-adversarial-input.md` §6 AC-0 — 「落とすコマンド」が反転している。**

```
… | grep . && exit 1
```
`grep .` は一致ゼロで exit 1 を返すため、**差分が無い（＝ AC が満たされている）ときにパイプライン全体が
非ゼロで終わる**。CI に貼るとちょうど逆に落ちる。実測: `bash -c 'echo "" | grep . && exit 1'; echo $?` → `1`。
加えて `$EVENT_START` はどのスクリプトでも定義されていない（値は `STATUS.md` にある文字列）。

修正: `if git diff --name-only "$EVENT_START" -- … | grep -q .; then exit 1; fi` にし、
`EVENT_START` を `scripts/004-live.sh` 内で `STATUS.md` から読むか定数で持つ。

**13. [MINOR] `docs/specs/004-live-adversarial-input.md` §6 AC-4 — `FailReason` のフィールド列挙が不正確。**

AC-4 は `PostStateDeltaOutOfBounds { pre, post, delta, min, max }` を要求するが、
現物（`reexec-evm/src/lib.rs:174-182`）は `{ address, slot, pre, post, delta, min, max }` の **7 フィールド**。
機械判定を謳う AC が実型と食い違っている。`address`/`slot` を含めて書き、
`address == TARGET` / `slot == 0` も検査対象にする（finding 1 の補強にもなる）。

**14. [MINOR] `docs/specs/004-live-adversarial-input.md` §6 AC-16 — 依存の閉包が AC-6 / AC-7(d) と整合しない。**

AC-16 は依存名集合 ⊆（EVENT_START 時点の repo 内 `Cargo.toml` の依存名）∪ `{reckn-reexec-evm}` とする。
だが AC-6 は `zk-verdict/lib::delta_outcome`（crate `verdict-lib`）を要求し、
AC-7(d) は `zk-verdict/contracts/src/fixtures/` を要求する。
`verdict-lib` は `zk-verdict/program-revm/Cargo.toml:12` に依存名として現れるので
**規則の字面は満たすが**、AC-16 の但し書きが `reckn-reexec-evm` だけを名指ししているため、
実装者が「zk-verdict に触ってよいのか」を判断できない。
`{reckn-reexec-evm, verdict-lib}` と明記し、`zk-verdict/` は**読み取り専用参照のみ**と書く
（`CLAUDE.md` の「zk-verdict は独立した SP1 workspace」との関係も一言添える）。

**15. [MINOR] `docs/specs/004-live-adversarial-input.md` §1 — 引用行がわずかにずれている。**

`dashboard/index.html:677-705` とあるが、`var SCEN = {` は **678** 行目、閉じ `};` は **706** 行目。
同節の `:681` / `:694`（`claim` リテラル）と `:981` / `:986`（ハードコードされた verdict 行）、
`dashboard/moneyshot.json:13-36`、`dashboard/README.md:48-55` は**すべて正確**だった。
`:677-705` だけ 1 行ずれ。他が正確なので誤読の危険は低いが、
`AGENTS.md` の file:line 規律に従って直す。

**16. [MINOR] `docs/specs/004-live-adversarial-input.md` §8.1 T-6 — 「cold clone・ネットワーク遮断」の前提が書かれていない。**

T-6 は「cold clone・ネットワーク遮断・鍵なしで `scripts/004-live.sh demo` が完走」を要求するが、
`live-input/` は crates.io の依存（`serde` / `revm` / `alloy-*`）を解決する必要があり、
レジストリが温まっていない cold clone では**ネットワーク遮断下でビルドできない**。
`Cargo.lock` の commit と、`cargo --offline` の前提（レジストリ or vendor が事前に存在すること）を
T-6 の前提条件として明記する。さもないと「審査員が再現できる」が実際には偽になる。

**17. [MINOR] `docs/specs/004-live-adversarial-input.md` §3.5 / §4.3 — 判事が「応答しない」場合が未定義。**

`JudgeUnavailable` は「endpoint に到達できない」を覆うが、**接続はできて応答が返らない**場合
（ハング / 無限ストリーム）の timeout が定義されていない。`serve` が 1 attempt で固まる。
`judge.rawResponse` のサイズ上限も無い（敵対的 endpoint / 敵対的 CLI が巨大応答を返せる）。
`JudgeTimeout`（→ `NO_CONTEST`）と応答バイト上限を §3.5 に足す。

---

## Rejected findings

- **Codex #5 の一部「`RECKN_JUDGE_CMD` は任意コード実行であり §5.1 に反する」** — 却下。
  §5 は冒頭で「**観客入力が到達できる範囲**を全列挙する」と scope を宣言している
  （`docs/specs/004-live-adversarial-input.md:250`）。`RECKN_JUDGE_CMD` を設定できるのは
  デモを走らせる operator であって観客ではなく、operator は元から任意のプログラムを実行できる。
  同じ finding の **egress の半分は採用**した（finding 8）。観客のバイト列が第三者に出るのは
  まさに「観客入力が到達できる範囲」の話であり、そこは §5.4 の記述が偽になっている。

- **Codex 末尾「cold clone / offline が再現不能なのは EVM 依存の vendor tree が無いから
  （`reexec-svm/vendor` は無関係）」** — 理由を却下。vendor tree は再現の必要条件ではなく、
  温まった cargo レジストリ or `Cargo.lock` + `--offline` で足りる。
  ただし**前提が仕様に書かれていない**という結論部分だけは正しいので、finding 16 として
  理由を差し替えて採用した。

- **Codex #8 の severity（MINOR）** — 却下。`u64`/`U256` 乖離は「verdict が乖離しうる」ではなく
  **減少が最大 credit として証明される**（＝ buyer の資金が seller に出る）向きを持ち、
  18 decimals の ERC-20 では残高 18.45 token 超で日常的に到達する。
  タスク 002 が正面からその領域に入る。MAJOR に引き上げて finding 6 とした
  （004 の scope 内の作業は「§11 に記録する」だけであり、修正自体は deferred）。

- **Codex 退化実装表の AC-7 行「本物の `planHash`/`dealBinding` を計算すればフィクスチャ再計算も通る」**
  — 却下。フィクスチャに `deal_binding` も preimage も無いので、
  **本物の実装でも退化実装でも AC-7(d) は通らない**（finding 2）。
  Codex はこの AC を「通る」側に数えたが、実際には「誰も通せない」。
  結論（AC 群が退化実装を落とせない）は変わらないので、finding 1 は維持したうえで finding 2 を追加した。

- **`~34 s` / `~6.2 GB`（§2 N-3）が tier を超えているという疑い** — 発火せず。
  `zk-verdict/README.md:97`（`~34 s`、gnark CPU prover、~15.9M constraints）と `:105`（`~6.2 GB`）に
  実測として存在し、004 は「だから live loop に乗らない」という**否定方向**にのみ使っている。
  `~410k` / `~980k` cycles も同様に既存の実測の引用であり、004 の run として提示されていない。
  ただし前 round の数字ではなく**別タスクの実測の引用**なので、由来を 1 行添えることを推奨する（AC ではない）。

---

## Deferred

以下は本物だが 004 の scope 外（`AGENTS.md` §8「scope の拡大」に従い 004 では閉じない）。
**別ファイルは作らず、founder 裁定待ちとしてここに記録する**（004 の §11 に載せることは
finding 4 / 6 として 004 の scope 内の作業）。

- **D-1 `planHash` が `gas_limit` を束ねない**（`zk-verdict/program-revm/src/main.rs:176-181`）。
  spec §11 の記述は**正しい**。`gas_limit` だけが違う 2 つの plan が同じ `dealBinding` を持つ。
  `gas_limit` は実行の成否を変えうる（OOG）ので settlement-affecting。protocol 版上げが要る。
- **D-2 guest は `u64`、off-chain は `U256`**（finding 6）。**D-1 より重い**（偽 release の向きを持ち、
  18 decimals の ERC-20 で日常的に到達する）。**タスク 002 の前に founder 裁定が要る。**
- **D-3 guest が `spec`/block env/nonce check を設定しない**（finding 4、
  `zk-verdict/program-revm/src/main.rs:121-127` vs `reexec-evm/src/lib.rs:489-512`）。
  guest は `SpecId::default() == OSAKA`、off-chain は `anchor.spec_id`（現 fixture は `CANCUN`）。
  004 の固定 runtime では表面化しないが、002 の実 ERC-20 では表面化しうる。
- **D-4 OQ-1（観客の attempt をセッション後に実 Groth16 → `settleWithProof`）** — 仕様の推奨（別タスク化）に同意。
  004 の緑を proof 生成に依存させない点は正しい。
- **D-5 OQ-2（`cli` 実モデル経路の可否）** — finding 10 の通り、**004 の見出し主張がこの裁定に依存している**。
  裁定より先に見出しを判事非依存の形に直すことを推奨する。

---

## 004 に戻すときに直すもの（CHANGES の具体リスト）

1. 再実行が本物であることを固定する AC を足す（`STATE_ROOT` 具体値 / `gasUsed` 期待値 /
   `traceHash` = `reexec_trace_hash(...)` / 壊した witness で `EngineError` / NC-19）。— finding 1
2. AC-7(d) をフィクスチャの実体に合わせて書き直す。— finding 2
3. §3.3 に anchor 全フィールドと witness account 集合と `STATE_ROOT` を書く。— finding 3
4. §9 の「同じエンジンが in-guest で走る」を、一致テストを AC にするか主張を落とすかで決着させる。— finding 4
5. AC-11 の変奏 corpus を committed fixture にし、クラス被覆で閾値を定義し直す。
   AC-11(a) の母集合と「ソース」の範囲を確定し、AC-12 の control を除外する。— finding 5
6. §11 に `u64`/`U256` と guest env の 2 件を追記し、§3.4 の文言を「偽 release」の向きで書き直す。— finding 6, 4
7. §9 台本の `refund`/`release`/`エスクロー` を分類語に直し、`19/32` をプレースホルダにし、
   AC-15 の lint に載せる。— finding 7
8. §5.4 を mode 別に書き分ける（`cli` は egress する）。— finding 8
9. transcript を連鎖ハッシュ化し、`serve` の追記を排他化する。— finding 9
10. §1 の主張文を判事非依存の形に書き直す（LLM 版は OQ-2 条件付き）。— finding 10
11. NUL を UTF-8 の問題から分離する。— finding 11
12. AC-0 のコマンドの反転を直す / AC-4 の `FailReason` を 7 フィールドに / AC-16 に `verdict-lib` /
    `:677-705` → `:678-706` / T-6 の offline 前提 / `JudgeTimeout` と応答サイズ上限。— finding 12–17

---

VERDICT: CHANGES
