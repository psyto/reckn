# 010 — SVM token replay: the first slice

> **⚠ §0 Amendments（2026-09-12）を先に読む。** この枠の「Lane」と §11 の日程は、
> **CWF 参加の裁定より前に**書かれている。訂正は §0 にあり、旧文は消さずに引用してある。
> **実装は 2026-09-14 20:00 JST より前に着手しない**（理由は §0）。
>
> **Status: FROZEN 2026-09-12.** Round 1 of the independent spec review returned
> **`VERDICT: CHANGES`** ([`010-spec-r1.md`](../reviews/010-spec-r1.md)), its three findings are
> folded in at **§0.1**, and **spec review is one round — hard stop** (`AGENTS.md` §7). So the old
> gate below can never be satisfied and is replaced rather than waited on:
>
> ~~*"`reckn-codex-impl` must not start until `docs/reviews/010-spec-r1.md` ends with
> `VERDICT: APPROVE`."*~~ → **implementation is gated on the clock, not on a second review**:
> P1's first line is not written before **2026-09-14 20:00 JST**, and
> `bash scripts/cwf-baseline.sh --write` records the boundary commit first.
>
> **Lane:** this is **R&D**, not ETHOnline day-work. It is **not** part of the 9/9
> checkpoint (`AGENTS.md` §7), not part of the 9/12 freeze, and **nothing in it is
> claimed in the ETHOnline submission**. During the event the only artifact this lane
> produces is *this document*. Implementation is Phase B (9/16 以降), inside the ≤30%
> budget of §11.
>
> **Tier: local.** Everything specified here runs in LiteSVM in-process
> (`reexec-svm/vendor/litesvm`). **No devnet, no mainnet, no RPC, no cluster of any
> kind, no deployment.** A green 010 says nothing about devnet and nothing about
> mainnet (`AGENTS.md` §5). §10 names every point where that stops being true and
> founder approval is required.
>
> **Measurement provenance.** Every line number and code fact in §2 was read on
> **2026-09-06** from the working tree at `5009dd1`. No number is carried from an
> earlier document. Facts about SPL Token's own byte layout that this repository does
> not contain are marked **[要一次資料]** and must be confirmed against the named
> primary source before they are pinned in code — they are not assumed here.

---

## 0. Amendments（2026-09-12、founder 裁定）

**旧文を消さずに引用して訂正する。** この仕様は「提出物に現れない R&D レーン」として書かれたが、
その前提が founder の裁定で変わった。前提だけを差し替え、§1 の判断・§4〜§8 の受入条件は**一行も
変えていない**。

**裁定**: **Reckn は Crypto World's Fair（Colosseum、2026-09-14 → 10-12）に Tempo × Solana で
参加する。** 規約の一次資料は [`docs/cwf-2026/RULES.md`](../cwf-2026/RULES.md)、当日までの
チェックリストは [`docs/cwf-2026/PREFLIGHT.md`](../cwf-2026/PREFLIGHT.md)。

| 旧文（§11） | 訂正 |
|---|---|
| 「**一提出制約。** 本仕様は reckn を他の大会へ提出する判断を含まない。010 の成果物が reckn 以外の提出物に現れることは無い。」 | **偽になった。** 010 の実装は CWF の**当日作業そのもの**であり、提出物に現れる。 |
| 「9/12 の凍結後、9/15 まで: **このレーンは停止**」「9/16 以降: reckn は**従**であり、全体時間の **30% を上限**とする」 | 日程が変わった。CWF の窓は **9/14 20:00 JST → 10-12**。ETHOnline の判定窓（9/14 01:00 → 9/17 01:00 JST）は `master` 凍結・`cwf-2026` ブランチで作業する（`PREFLIGHT.md` §2）。30% の配分は founder が週次で決める、は不変。 |
| §11 の「**共有物ゼロ**」「**文書の一方向性**」 | **不変。** 参加する大会が決まったことは、他レーンの語彙・番号・日程をこの文書に持ち込む理由にならない。 |

**★ 実装開始時刻の制約（新規、拘束力あり）。** Colosseum の規約は
*"Teams may begin development before the hackathon, but products are judged only on the work
completed between the competition's start and end dates."*（`RULES.md` §1、2026-09-12 に読取）。
主催者は「今すぐ始めてよい」とも書いているが、**早く終わらせた分は当日作業でなく事前作業として
扱われる**。したがって:

> **P1 の1行目を 2026-09-14 20:00 JST より前に書かない。** 早く着手して得るものは無く、
> 失うのは「窓の内側で作った」という審査対象そのものである。窓が開いたら
> `bash scripts/cwf-baseline.sh --write` で境界の commit を記録してから着手する。

**§10 item 1 は測定で閉じた（2026-09-12）**: toolchain は導入済み —— `solana-cli 4.1.2` /
`cargo-build-sbf 4.1.0` / `anchor-cli 0.32.1` / `spl-token-cli 5.6.1`。ネットワーク取得は不要。
残る founder 専用項目は §10 の 2〜6（devnet の鍵・資金・deploy・mint・faucet・RPC）で不変。

**同日に測った現状（P1 の出発点）**: `cd reexec-svm && cargo test` → **30 passed**、
`cd escrow-svm && cargo test` → **10 passed**（`tests/e2e.rs`、LiteSVM）。

### 0.1 第二次裁定（2026-09-12）— レビュー r1 を畳み込み、ここで凍結する

[`docs/reviews/010-spec-r1.md`](../reviews/010-spec-r1.md) が **CHANGES**（BLOCKER 2 / MAJOR 1）。
**仕様レビューは1ラウンドで hard stop**（`AGENTS.md` §7）なので、3件をこの文書に畳み込んで**凍結**する。
再レビューはしない。

- **BLOCKER 1（pin した ELF が走らない）** → **設計判断**として founder に上げ、
  [`docs/decisions/010-A-which-elf-executes.md`](../decisions/010-A-which-elf-executes.md) で
  **案 B（世界を閉じる）を採択**。D-1 を §1 で書き換えた（旧文は引用して残した）。
  未知は **4時間の time-box**（seed した legacy-loader の program account が
  `add_program_preverified` 無しで実行されるか）。落ちたら**案 C を開示付きで一枚目に出す** ——
  これは第二ラウンドではなく、記録済みの fallback である。
- **BLOCKER 2（funded な述語フィールドが verdict を縛っていない）** → **INV-8** を新設し、
  §5.4 に3行、§7 に **AC-12**、§8.2 に **M-10 / M-11** を足した。
- **MAJOR（M-5 が存在しない case に紐付く）** → §8.3 に **delegate の vector**（A-3）を足し、
  M-5 の帰属をそれに直した。
- **全案に共通する前提**（裁定で採択）: **feature set を profile に入れて hash する**（INV-5 / INV-6 を
  §5.3 で訂正）と、**M-9**（pin した ELF を挙動の違う ELF に差し替えたら verdict が動くことを要求）。
  **M-9 だけが BLOCKER 1 を単独で捕まえられる。** AC-2 では捕まらない（理由は §7 の AC-2 に書いた）。

---

## 1. 判断（一つだけ）

> **D-1（2026-09-12 改訂、案 B）.** Solana R&D の最初の一枚は、**legacy SPL Token の
> `TransferChecked` 1命令だけ**を `reexec-svm` の off-chain replay で決定的に再実行する枚である。
> そのために **replay の VM を閉じた世界として構成し** ——
> `LiteSVM::new()` をやめ、`LiteSVM::default()` に `with_builtins()` / `with_sysvars()` /
> **pin した `with_feature_set(...)`** / `with_sigverify(true)` を明示して
> **`with_default_programs()` を呼ばない** —— さらに `:501` の
> *「executable account を seed しない」*をやめて **snapshot の program account を seed** し、
> `:485` の all-or-nothing 拒否を **`(program_id, loader, sha256(elf))` の pin 集合が runtime profile
> に入り、derive された集合がそれと厳密に一致するときだけ通す**検査へ置き換える。
> **pin したバイトが、実行されるバイトである。**
> **zkVM guest（`zk-verdict/program-svm`）はこの一枚で一行も変えない。**

**旧 D-1 は偽だった。消さずに引用して残す**（2026-09-12、レビュー r1 finding 1）:

> ~~*「`:485` の all-or-nothing 拒否を、`(program_id, sha256(elf))` の pin 集合が runtime profile に
> 入り、derive された集合がそれと厳密に一致するときだけ通す検査へ置き換える。」*~~

**なぜ偽か。** `LiteSVM::new()` は `default().into_basic()` で、`into_basic()` が
`with_default_programs()` を呼び、`load_default_programs` が **8本**を `add_program_preverified` で
preload する。そして **`Tokenkeg…` に何が載るかは feature gate が決める** ——
`replace_spl_token_with_p_token` が有効なので、載るのは **`pinocchio_token_program.so`
（SPL Token の*別実装*）で、しかも `bpf_loader_upgradeable` の下**である。snapshot 側の
executable account は `:501` で飛ばされるので、**pin したバイトは一度も実行されない**。
拒否を緩めるだけの旧 D-1 では、pin は何も縛らない記述になる。

判断はこれ一つである。`TokenAmountDelta`（§5）も fail-closed 機構（§6）も、この一枚を
**閉じたまま**通すために必要な最小の随伴であって、別の判断ではない。

**なぜ guest を触らないのか（この一枚の設計上いちばん重要な選択）。** guest で Token program を
扱う道は2つしかない。(a) SBF interpreter を in-guest に入れる — これは
「System Program 限定 runtime を無制限の SBF 実行環境へ緩めない」に正面から違反する。
(b) Token program の意味論を guest 内に**手で書き直す** — これは
`AGENTS.md` §5 が precompile についてすでに開示している失敗様式
（*guest と off-chain engine は同じものの別実装を走らせており、等価性は未検証*）を、
**今度は資金移動そのものの上で**再生産する。どちらも「最初の一枚」で背負う負債ではない。
off-chain replay は **committed prestate から取り出した本物の ELF** を LiteSVM で走らせるので、
この divergence を**一枚目では作らない**。作る時期と、その時に必要になる differential 検査は
§9 の P4 / P5 に置く。

---

## 2. 今日そこに何があるか（実測。2026-09-06、`5009dd1`）

| 事実 | 場所 |
|---|---|
| off-chain replay の ambient program 既定は **System 1本だけ** | `reexec-svm/src/lib.rs:98` |
| `runtime_profile_hash` は System 以外の ambient を**エラーにする**（ambient allowlist は緩められない） | `:275`–`:281` |
| `derive_program_images` は **snapshot の executable account から**プログラム像を導く。seller 供給の `(program_id, elf)` 入力は V2 に無い。legacy loader なら `data` がそのまま ELF、upgradeable loader なら ProgramData account を辿る | `:331`–`:395` |
| **その像が1つでもあれば `replay()` は即 operational error** —— 今日 off-chain replay も実質 System 限定 | `:485` |
| LiteSVM の seeding は **executable account を飛ばす**（ambient cache を作らないため）。`AccountLoadPolicy::RejectUnseeded` | `:496`–`:503` |
| **【2026-09-12 追記、この行が無かったことが BLOCKER 1 の原因】** `LiteSVM::new()` は `default().into_basic()` で、`into_basic()` が **`with_default_programs()`** を呼ぶ。`load_default_programs` は **8本**を `add_program_preverified`（*preverified*）で preload する | `reexec-svm/src/lib.rs:491`／vendor `litesvm/src/lib.rs:535`／`programs/mod.rs:10`–`:66` |
| **`Tokenkeg…` に載る実装は feature gate が決める。** `replace_spl_token_with_p_token` が active mainnet set に入っているので、載るのは **`pinocchio_token_program.so`（別実装）／`bpf_loader_upgradeable`**。無効時のみ `spl_token-3.5.0.so`／`bpf_loader` | vendor `features.rs:230`／`programs/mod.rs:13`–`:28` |
| **`:485` の拒否は封じ込めであって手抜きではない。** コード自身がそう書いている: *「Treating those as a caller-selectable allowlist would merely move the old ambient-code trust bug into the profile. Until their account/loader state is reconstructed, the System builtin is the only permitted ambient executable.」* | `:269`–`:273` |
| profile が hash するのは litesvm の**バージョン文字列** `litesvm/0.13.1/reckn-closed-world/1`。**feature set 自体は hash していない** | `:27`, `:287` |
| message の全 account key は snapshot か ambient に**無ければ `ImplicitAccountLoad`** | `:639` |
| sysvar account と durable nonce は**入口で拒否** | `:658` |
| 述語は4つ。causal なのは `LamportsDelta` のみ（`post - pre` saturating が `[min,max]`） | `:114`–`:135` |
| zkVM guest は **System hard-coded**、`Transfer`（tag 2）だけを手で再現、**986,097 cycles** | `zk-verdict/program-svm/src/main.rs:28,:70`／`zk-verdict/cycles.json` |
| guest の check は `SvmCheck { account, min: u64, max: u64 }`。`delta_outcome` は U256 で取る（**u64 → U256 への拡大のみ。縮小は無い**） | `zk-verdict/svm-io/src/lib.rs`／`zk-verdict/lib/src/lib.rs:37` |
| **既存 SVM escrow（`escrow-svm`）は resolver 経路**である。`resolve` は直前の Ed25519 precompile 命令と `ResolverConfig` allowlist を要求する。**proof-only ではない** | `escrow-svm/README.md`／`src/lib.rs:1096` |
| その vault は **Token-2022 固定**、`TransferChecked`（ix 12）を CPI、amount は offset 64、decimals は mint offset 44 | `escrow-svm/src/lib.rs:29,45,1021,1048,1055,1071` |
| vault の検査は **`mint.len() >= 45`／`token_account.len() >= 165`／mint・owner フィールド一致**のみ。**frozen / delegate / close_authority / is_native は一切見ていない** | `:1048`–`:1074`（`108`・`delegate`・`close_authority` の grep は0件） |
| `escrow-svm` のテストは **LiteSVM のみ**。`cargo build-sbf` の `.so` が無ければ `assert!` で落ちる（skip しない） | `escrow-svm/tests/e2e.rs:294`–`:301` |
| **この repo に devnet に触れるコード・スクリプト・設定は1つも無い**（`grep -rn devnet` = 0 件、vendor/target 除く） | — |

**この表から出る結論を2つ、先に書く。**

1. **「vault で token を動かせる」は既に成立している**（LiteSVM で、resolver 署名で）。
   **「その token transfer を再実行して裁定できる」は一行も存在しない。** 010 が着手するのは後者だけで、
   前者は §9 の P0 で*デモできる形にする*作業であって、実装作業ではない。
2. **`escrow-svm` の vault は Token-2022 を名指ししているのに、Token-2022 の extension を
   1つも検査していない。** これは 010 の replay 側の問題ではなく **vault 側の開いた穴**である。
   §7 の AC には入れず、§12 の L-3 として開示し、P0 の完了定義に「穴を穴として書く」を入れる。

---

## 3. 非目標（ついでに直したくなるもの）

- **N-1. guest を変えない。** `zk-verdict/program-svm`、`svm-io`、`svm-bankhash`、`lib` に0行。
  新しい proof を作らず、fixture を再生成せず、`cargo-prove` を走らせない。
- **N-2. `escrow-svm` を変えない。** resolver 経路は `AGENTS.md` §8 の「optimistic 経路の改善」に
  あたる。§2 で見つけた extension 未検査は**開示するだけ**で、010 では直さない。
- **N-3. 任意の SPL / Token-2022 対応をしない。** 対応する program・mint・instruction・extension を
  明示し、それ以外は拒否する。「一般化」は目標ですらない。
- **N-4. 実スナップショット取り込みをしない。** prestate は依然としてテストが構成する。
  RPC も snapshot archive も読まない（§9 P5、§10）。
- **N-5. Solana 上の proof-only settlement をしない。** それは §9 P5 の別マイルストーンであり、
  `escrow-svm` の resolver 経路と**同じ文の中に置かない**。
- **N-6. EVM 側に何もしない。** `RecknZkEscrow` / `RecknVerdictVerifier` / `no-keys.sh` は不変。
- **N-7. Token-2022 を一枚目に入れない。** 理由は §6.3（upgradeable loader・TLV・transfer hook）。

---

## 4. 対象取引（最初の一枚の全定義）

### 4.0 一次資料で pin した値（**2026-09-12 に読取**。[要一次資料] だったものを閉じる）

読んだのはこのマシン上の crate ソース本体であり、ブログでも検索結果でもない。出所は
`~/.cargo/registry/.../spl-token-interface-3.0.0`（`spl-token` 9.0.0 が `pub use` で再輸出している実体）。**版を書いてあるのは、版が上がれば読み直すという意味**である。

| 値 | pin | 一次資料の行 |
|---|---|---|
| legacy SPL Token の program id | `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA` | `src/lib.rs:17` の `solana_pubkey::declare_id!` |
| `TransferChecked` の tag | **12**、続けて `amount: u64 LE`（8）、`decimals: u8`（1）= **10 bytes** | `src/instruction.rs:713` の `pack`（`buf.push(12)`）と `:605` の `unpack`（`12 =>`） |
| `Mint::LEN` | **82** | `src/state.rs:38` |
| `Account::LEN` | **165** | `src/state.rs:132` |
| `Multisig::LEN` | **355** | `src/state.rs:218` |
| mint の `decimals` の offset | **44** | `Mint::unpack_from_slice` の `array_refs![src, 36, 8, 1, 1, 36]`（36+8 = 44） |
| token account の offset | `mint` 0..32 / `owner` 32..64 / **`amount` 64..72** / `delegate` 72..108 / **`state` 108** / **`is_native` 109..121（tag は 109..113）** / `delegated_amount` 121..129 / `close_authority` 129..165 | `Account::unpack_from_slice` の `array_refs![src, 32, 32, 8, 36, 1, 12, 8, 36]` |
| wrapped SOL の mint id | `So11111111111111111111111111111111111111112` | `src/native_mint.rs:7` |

**【2026-09-12】この表のレイアウトは crate が宣言している値である。** 案 B の下で実行されるのは
**snapshot が運ぶ ELF** なので、*その ELF のレイアウトがこの表と一致すること*は
**M-11 が観測で閉じる**（一致しなければ transfer は落ちるか、delta が動かない）。
案 C に落ちた場合は **`pinocchio_token_program.so` のレイアウト互換性が load-bearing になる**ので、
その時点で `[要一次資料]` を1つ増やす（決定メモ §3 案 C）。

**まだ [要一次資料] のままのものが1つある**: pin する **ELF のバイト列そのもの**。これは crate の
ソースからは出ない（program account の `data` を実チェーンから取るしかない）。§12 L-2 のとおり、
実装時に「その 32 bytes をどこから取ったか」を仕様の中に literal で書く。**§10 の 2〜6 に依存する
唯一の pin であり、P1 を LiteVM 内で閉じる分には自前で組んだ ELF で足りる。**

### 4.1 許す集合（これ以外は全部拒否）

- **program**: legacy SPL Token **1本のみ**。program id と `sha256(elf)` を pin する。
  program id は **`TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`**（§4.0 で pin 済み）。
  loader は legacy BPF loader なので **ELF は program account の `data` そのもの**であり、
  ProgramData account を必要としない（`:364`）。**これが legacy を一枚目に選ぶ理由の半分**である。
- **instruction**: `TransferChecked`（tag **12**、`amount: u64 LE` + `decimals: u8`、計 10 bytes）
  **discriminant は 12、§4.0 で pin 済み。**
  **命令数はちょうど 1**。ComputeBudget も Memo も付けない。
- **authority**: source token account の **owner フィールド（offset 32..64）と一致する
  message signer**。delegate 経路・multisig 経路は拒否（§6.2）。

### 4.2 拒否する集合（列挙ではなく性質で閉じる — R-7）

| 拒否するもの | 閉じ方（性質） |
|---|---|
| 他の program（Token-2022 含む） | derive された image 集合が pin 集合と**厳密に一致**しない → operational error |
| 他の instruction | 命令数 ≠ 1、または program id ≠ pin、または tag ≠ 12 → 拒否 |
| **あらゆる Token-2022 extension** | mint の `data.len()` が**ちょうど 82**、token account の `data.len()` が**ちょうど 165** でなければ拒否。**extension は必ず TLV を後ろに足すので長さが伸びる**。禁止 extension の名前を1つも書かずに閉じる **82 / 165 は §4.0 で pin 済み。Token-2022 の `account_type` が base の直後に来ることは、今日読んだ crate には無い事実なので [要一次資料] のまま** |
| multisig authority | authority pubkey が snapshot に存在し、かつその owner が pin した token program なら拒否（multisig account は token program 所有。長さ 355（§4.0 で pin 済み）に依存せず owner で閉じる） |
| wrapped SOL | token account の `is_native` COption tag（offset 109..113）が 0 でなければ拒否 |
| frozen | 両 token account の state（offset 108）が `Initialized` = 1 でなければ拒否 |
| sysvar / durable nonce | 既存の `reject_unsupported_environment_dependencies` がそのまま効く（`:658`） |
| snapshot に無い account | 既存の `ensure_closed_message_accounts` がそのまま効く（`:639`） |

### 4.3 必要な account 集合（committed prestate に**全部**入る）

1. legacy SPL Token **program account**（executable、legacy loader 所有、ELF 入り）
2. **mint** account
3. **source** token account
4. **destination** token account
5. **authority / fee payer**（System 所有、lamports 保有）

補助 account はこれ以上無い。ATA program も Rent sysvar も Clock sysvar も**入らない**（入ったら拒否）。
**この5つで閉じることを AC-1 が検定する。**

---

## 5. `TokenAmountDelta`

`PredicateV1` に5番目の variant として足す。`LamportsDelta` の token 版であり、
**同じ因果性**（no-op では `min > 0` を満たせない）を持つ。

### 5.1 入力

```
TokenAmountDelta {
    token_account: Pubkey,   // 測る先（通常は destination）
    mint: Pubkey,            // その account が保持していなければならない mint
    owner: Pubkey,           // その account の owner フィールド
    decimals: u8,            // committed prestate の mint から取った値と一致しなければならない
    min: u64,
    max: u64,
}
```

`decimals` を述語に入れるのは、**命令の `decimals` バイトではなく committed mint の値**を
真とするためである。命令側の値は seller が書く。

### 5.2 出力

`Verdict::Reproduced` または `Verdict::Failed(FailReason::TokenAmountDeltaOutOfBounds { .. })`。
**第三の値は無い。** 入力が構造的に不正なとき（§5.4）は verdict ではなく `OperationalError` を返す。
これは既存の規律（`escrow-svm/README.md`: *operational error は verdict ではない*）と同じ。

### 5.3 不変条件

- **INV-1（因果）**: `delta = post.saturating_sub(pre)`。`pre` は committed prestate の
  account から、`post` は **replay 後**の account から読む。committed 値をそのまま `post` に
  使う経路は無い。→ 何もしない transaction は `min ≥ 1` を満たせない。
- **INV-2（同一 account）**: `pre` と `post` は**同じ pubkey**の、**同じ mint・同じ owner・
  同じ data 長 165**の account から読む。post 側でこの4つのいずれかが変わっていたら
  `Failed`（close→再作成、mint 差し替えを閉じる）。
- **INV-3（測るのは着金額であって命令の額ではない）**: `amount` フィールドは述語に入らない。
  offset 64..72 の実残高差だけが verdict を決める。**transfer fee のような
  「送った額 ≠ 着いた額」を、述語は構造的に取り違えない。**
- **INV-4（domain）**: 内部は u64、`VerdictPublicValues` へ渡すときのみ `U256::from(u64)` で
  **拡大**する。**縮小・limb 取り出しはどこにも無い**（008 が閉じた偽解放の再来を作らない）。
- **INV-5（決定性、2026-09-12 訂正）**: 同じ `(anchor, snapshot, profile, plan, predicate)` は同じ
  verdict を返す。**profile は feature set を含む** —— どの token 実装が*存在するか*を選ぶのは
  feature set なので、それを固定しない profile は環境の記述ではない。
  旧文は *「LiteSVM の clock / slot / CU 設定を変えても変わらない」*だけを言っており、
  **決定性の主張として不足していた**（レビュー r1）。CU は依然 §13 OQ-2 で開いている。
- **INV-6（profile が replay 入力、2026-09-12 訂正）**: pin 集合**と feature set**は
  `runtime_profile_hash` に入り、したがって `snapshot_commitment` に入る。
  **旧 INV-6 は真だが空虚だった** —— 「pin を足すと hash が変わる」は `Sha256` の性質であって
  この設計の性質ではない。**言うべきことは「hash に入っていない環境入力が無い」**であり、
  2026-09-12 まで **feature set がまさにそれだった**（バージョン文字列が慣習で代理していただけで、
  vendored `features.rs` を編集しても hash は動かない）。
- **INV-7（ambient は増えない）**: `allowed_ambient_programs` は System のままである。
  token program は **ambient ではなく snapshot 由来**として入る。`:275` の拒否は緩めない。
  **案 B はこれを初めて本当に達成する** —— `with_default_programs()` を呼ばないので、
  ambient に非 builtin のコードが**物理的に存在しない**。
- **INV-8（funded なフィールドは verdict を縛る。2026-09-12 新設、レビュー r1 finding 2）**:
  `TokenAmountDelta` の `mint` / `owner` / `decimals` は**述語の一部として検定される**。
  `token_account` の実際の mint フィールドが `mint` と、owner フィールドが `owner` と、
  **committed prestate の mint account の `decimals`（offset 44）が `decimals` と**一致しない場合は
  `Failed`。**旧仕様は §5.1 の散文でしか言っておらず、不変条件も §5.4 の行も AC も mutant も
  無かった** —— つまり **別 mint への transfer が `Reproduced` になった**。
  6つある入力のうち3つが何も縛らない述語は、述語ではない。

### 5.4 失敗条件（全列挙）

| 条件 | 返すもの |
|---|---|
| 述語 account が snapshot に無い | `OperationalError::MissingPredicateAccount`（既存） |
| mint / token account の長さが 82 / 165 と**厳密に一致しない** | `OperationalError::UnsupportedTokenLayout`（新設） |
| pin されていない program image が derive された | `OperationalError::UnsupportedEnvironmentDependency`（既存 variant を再利用） |
| pin された image の `sha256(elf)` が一致しない | `OperationalError::ProgramImageMismatch`（新設） |
| 命令数 ≠ 1、tag ≠ 12、program ≠ pin | `OperationalError::UnsupportedInstructionProfile`（新設） |
| authority が multisig / delegate | `OperationalError::UnsupportedAuthority`（新設） |
| 署名検証が落ちる | `Verdict::Failed(InvalidAuthorization)`（既存） |
| transaction が実行時に落ちる | `Verdict::Failed(Execution)`（既存） |
| delta が `[min,max]` の外 | `Verdict::Failed(TokenAmountDeltaOutOfBounds)`（新設） |
| post 側で mint / owner / 長さが変わった | `Verdict::Failed(TokenAmountDeltaOutOfBounds)` |
| **述語の `mint` ≠ token account の実際の mint フィールド**（INV-8） | `Verdict::Failed(TokenAmountDeltaOutOfBounds)` |
| **述語の `owner` ≠ token account の実際の owner フィールド**（INV-8） | `Verdict::Failed(TokenAmountDeltaOutOfBounds)` |
| **述語の `decimals` ≠ committed mint の `decimals`（offset 44）**（INV-8） | `Verdict::Failed(TokenAmountDeltaOutOfBounds)` |
| **pin した ELF と、実行された program の image が違う**（案 B。`with_default_programs()` を呼ばない構成で ambient に非 builtin コードが存在しないこと） | `OperationalError::ProgramImageMismatch` |

`min = 0` は**仕様として拒否しない**が、`LamportsDelta` と同じく **floor 0 は「何もしない」で
満たされる**（`AGENTS.md` §5）。010 はこれを閉じない。§12 L-1 に置く。

---

## 6. System 限定から Token program を許すときに開く攻撃面

### 6.1 一枚目で閉じるもの

- **A-1 program 差し替え。** `snapshot_is_complete = false` の compact prestate では
  bank_hash が account 集合を縛らない。したがって **pin した address に別の ELF** を置いた
  snapshot を作れる。→ `sha256(elf)` の pin と、それが profile hash に入ること（INV-6）で閉じる。
  **address だけの pin では閉じない。** これが 010 で最も重要な一行である。
- **A-2 追加命令の相乗り。** 1つの transaction に Token 命令と System 命令を混ぜ、
  述語 account の残高を System 側で動かす。→ 命令数ちょうど 1 で閉じる。
- **A-3 delegate による第三者送金。** prestate の時点で approve 済みの delegate が送ると、
  seller でない誰かの行為で `Reproduced` になる。→ authority == owner フィールドで閉じる。
- **A-4 self-transfer。** source == destination の `TransferChecked` は成功して delta 0。
  → `min ≥ 1` の deal では自動的に `Failed`。AC-5 の否定コントロールで固定する。
- **A-5 frozen / wrapped SOL による測定面の変質。** → state と `is_native` の pin で閉じる。

### 6.2 一枚目で**閉じないが名指しする**もの

- **A-6 Token-2022 の transfer hook。** hook 付き mint の transfer は **任意の第三者 program** を
  CPI する。これは「pin した1本の program」を「pin した1本＋攻撃者が選ぶ任意の program」に変える。
  **Token-2022 を一枚目に入れない最大の理由がこれ**であり、P4 で Token-2022 を入れるときも
  **transfer hook は P5 以降**である。
- **A-7 permanent delegate。** mint 側の permanent delegate は、vault の中身を
  **settlement の前後を問わず**第三者が動かせるようにする。**「vault が排他的に保管している」を
  偽にする**唯一の extension であり、replay の問題ではなく **custody の問題**である。
- **A-8 confidential transfer。** 可視 amount（offset 64）は残高の全部でなくなる。
  `TokenAmountDelta` は**測る対象そのものを失う**。
- **A-9 freeze authority。** mint に freeze authority がある限り、発行者は vault または
  destination を凍結して payout を revert させられる。**Arc の blacklisted seller と同じ形**であり、
  001（timeout）が EVM 側で閉じたのと同じ穴が SVM 側に開いている（`escrow-svm` の
  `timeout_refund` が対応物だが、**凍結されているのは vault なので refund も revert する**）。
- **A-10 syscall 経由の ambient 依存。** message に sysvar account が無くても、program は
  `get_sysvar` で Clock / Rent を読める。`reject_unsupported_environment_dependencies` は
  **message しか見ない**。`TransferChecked` がそれを踏むかは
  **2026-09-12 に一次資料で測った**: `spl-token` 9.0.0 の `src/processor.rs` で `Rent::get()` /
  `Rent::from_account_info` が現れるのは `InitializeMint` / `InitializeAccount` /
  `InitializeMultisig` の3経路（`:37` `:98` `:180`）だけで、**`process_transfer`（`:227`）の本体には
  `Rent` も `Clock` も `get_sysvar` も1つも無い**。
  **それでも仮定にはしない** —— 走るのは pin した ELF であってこのソースではないので、
  AC-6（clock/slot を変えて同一 verdict）が**観測で**閉じる。この測定は AC-6 を置き換えず、
  **落ちたときに「実装が変わった」と「pin が別物だった」を切り分ける基準線**として置く。
- **A-11 CU 予算。** LiteSVM の既定 CU は profile hash に入っていない。transfer では効かないが、
  **profile が replay 入力であるという INV-6 の主張に穴が開いている**。§13 OQ-2。
  **【2026-09-12】この穴は CU だけではなかった。** より大きい穴は **feature set** で、
  それは *どの token 実装が存在するか*を選ぶ。INV-5 / INV-6 を訂正し、feature set は
  profile に入れて hash する（AC-11）。**CU は引き続き開いており、OQ-2 のまま。**

### 6.3 なぜ legacy が先で Token-2022 が後か（3つとも構造上の理由）

1. legacy は **legacy loader** なので ELF が program account に直に入る。Token-2022 は
   **upgradeable loader** なので Program + ProgramData の2 account が要り、
   `parse_upgradeable_program_account`（`:686`）の経路と、**upgrade authority が
   prestate 以後に ELF を差し替えられる**という時間依存が加わる。
2. legacy には **extension が存在しない**。「長さが厳密に 82 / 165」という一本の性質が、
   *対応していない extension を黙って通さない* を完全に達成する。
3. legacy の ELF は Token-2022 より小さい。P5 で guest に入れるときの cycle 予算が違う
   （**現在の SVM guest が 986,097 cycles**。ここに SBF 実行が乗る）。

---

## 7. 受入条件

書式は 004 §0.2 と同じ: **名前ではなく本体を検定する**。各 AC の下に
*「これを満たしつつ何も検定していない実装」* を名指しし、それを落とす手段を書く。

- **AC-1 — account 集合が閉じる。** §4.3 の5 account だけを持つ snapshot で
  `TransferChecked` が `Reproduced` に到達する。6番目の account（ATA program、Clock sysvar、
  無関係の token account のいずれか）を message に足した3 case が、それぞれ
  `ImplicitAccountLoad` か `UnsupportedEnvironmentDependency` になる。
  *空虚な実装*: 常に成功を返す replay。→ **同じ test 関数が正1・負3を持ち、負が verdict でなく
  operational error であることまで assert する。**
- **AC-2 — program pin が address でなく bytes を縛る（2026-09-12 訂正）。** pin した address に
  **1 byte だけ異なる ELF** を置いた snapshot が拒否される。
  **旧文は `ProgramImageMismatch` を要求していたが、その repro は到達不能だった** ——
  ELF を1バイト変えると `snapshot_commitment` が動くので `:419` の
  `PrestateCommitmentMismatch` が先に返り、それは既存テスト（`:1177`）が既に assert している。
  **正しい repro は「commitment を作り直した上で pin だけ古いまま」**にすること。
  *空虚な実装*: address だけ比較 → **M-1 が落とす。**
  **この AC は BLOCKER 1 を捕まえられない**（pin が実行されるかを見ていない）。それは **M-9** の仕事。
- **AC-3 — extension が長さで閉じる。** mint 83 bytes / token account 166 bytes の2 case が
  `UnsupportedTokenLayout` になる。**extension の名前は test にも実装にも1つも現れない**
  （`grep -c 'transfer_fee\|transfer_hook\|permanent_delegate\|confidential' reexec-svm/src` が **0**）。
  *空虚な実装*: 既知 extension の denylist。→ **grep が 0 を要求することで denylist を禁じる（R-7）。**
- **AC-4 — 因果。** destination を触らない（source→第三の account へ送る）transaction が、
  `min = 1` の `TokenAmountDelta` で `Failed` になる。`LamportsBounded` 相当の非因果述語では
  同じ入力が `Reproduced` になることを**同じ test 内で**示す。
  *空虚な実装*: prestate の残高をそのまま `post` に使う。→ **上の対比が落ちる。**
- **AC-5 — self-transfer。** source == destination の `TransferChecked` が成功し、かつ
  `min = 1` で `Failed` になる。**transaction が成功したことと verdict が `Failed` であることを
  両方 assert する**（片方だけなら実行していない実装で緑になる）。
- **AC-6 — 決定性。** 同じ入力を、LiteSVM の clock / slot を変えた2つの環境で replay し、
  `verdict` と `trace_hash` が**バイト一致**する。A-10 を観測で閉じる。
  *空虚な実装*: clock を実際には変えていない harness。→ **変更後の slot を読み出して
  assert_ne! で「環境が実際に違うこと」を先に示してから比較する。**
- **AC-7 — domain。** `pre = u64::MAX - 1`, `post = u64::MAX` の vector と、
  `pre = u64::MAX`, `post = 0` の vector が、それぞれ `delta = 1` / `delta = 0` として
  **U256 の上で**判定される。**limb 取り出しも縮小キャストも無いことを**、
  `grep -c 'as u64\|\.to::<u64>()\|limbs()' ` が新規コードで **0** であることで示す。
- **AC-8 — profile が入力である（2026-09-12 訂正）。** pin 集合を1つ足した profile が**異なる
  `runtime_profile_hash`** を出し、古い anchor に対する replay が拒否される。
  **旧文は `PrestateCommitmentMismatch` を名指ししていたが、`:411` は先に
  `RuntimeProfileMismatch` を返す。** エラー名を実際に返るものへ直す。
  **そして旧 AC-8 は `Sha256` の性質を検定していた** —— 「入力を足せば digest が変わる」は
  この設計の性質ではない。**AC-11 が代わりに設計の性質を検定する。**
- **AC-11 — 閉じた世界であること、および hash されていない環境入力が無いこと（新設、案 B）。**
  (a) replay の VM に **非 builtin の ambient program が0本**であることを、
  `Tokenkeg…` を呼ぶ transaction が **pin 無しでは実行に失敗する**ことで示す
  （`with_default_programs()` を呼んでいれば成功してしまうので、この test は構成を検定している）。
  (b) **feature set を1ビット変えると `runtime_profile_hash` が動く**。
  (c) **`replace_spl_token_with_p_token` を無効にした feature set は、有効な場合と
  *異なる* image を要求する** —— 同じ pin 集合が両方で通ったら、pin は実行を縛っていない。
  *空虚な実装*: `LiteSVM::new()` のまま feature set を hash に足すだけ。→ **(a) と (c) が落とす。**
- **AC-12 — funded なフィールドが verdict を縛る（新設、INV-8）。** 同一の transaction・同一の
  delta に対し、述語の **`mint` だけ**を別の pubkey にした case、**`owner` だけ**を変えた case、
  **`decimals` だけ**を committed mint と違う値にした case の3本が、いずれも `Failed` になる。
  **正の case と同じ test 関数の中に置く**（delta が範囲内であることまで同じ入力で示す）。
  *空虚な実装*: フィールドを読むだけで比較しない。→ **M-10 / M-11 が落とす。**
- **AC-9 — 変異検出。** §8.2 の mutant **11本**すべてが、**どの test に検出されたかを名指しで**
  記録される。**総数の等式ではなく、要求する mutant id の集合が実在し全部検出されたこと**を
  assert する（`AGENTS.md` の兄弟 gate の教訓）。
- **AC-10 — 兄弟を赤くしない。** `cargo test -p reexec-svm` と `cargo test -p reckn-escrow-svm`
  と `bash scripts/no-keys.sh` が、010 の後も 010 の前と同じ結果を出す。
  **010 は EVM 側のファイルに0行**（`git diff --stat` に `contracts/` と `zk-verdict/contracts/` が
  現れないこと）。

**AC を1つも通さずに緑になる経路が1つ残っている**: `cargo test <filter>` は
**一致0でも exit 0**（`CLAUDE.md` の実測）。したがって **AC-9 の runner は、
期待する test 名の集合が実在することを先に検査してから走らせる**（`ac008.sh` / `ac009.sh` と同じ構造）。

---

## 8. テスト計画

### 8.1 正の経路（4本）

1. `TransferChecked` が `Reproduced`（`min ≤ delta ≤ max`）。
2. 同じ transaction が `max` を下回る deal で `Failed`。
3. 同じ transaction が `min` を上回る deal で `Failed`。
4. pin された ELF が正しいときだけ image 検査を通る（AC-2 の正側）。

### 8.2 否定コントロール（**壊したら落ちることの確認**。mutant 8本）

| id | 変異 | 落とす AC |
|---|---|---|
| M-1 | `sha256(elf)` 比較を address 比較に弱める | AC-2 |
| M-2 | 長さ比較を `==` から `>=` に弱める | AC-3 |
| M-3 | `post` を committed prestate から読む | AC-4 |
| M-4 | `saturating_sub` を `wrapping_sub` にする | AC-4 / AC-7 |
| M-5 | authority == owner 検査を削る | **§8.3 の delegate case**（2026-09-12 訂正。旧文は「AC-1 の負側（delegate case）」と書いていたが、**AC-1 の負例は ATA / Clock / 無関係 token account の3本で delegate は無く**、§8.3 の6本も multisig であって素の delegate ではない。**帰属先が存在しなかった**ので §8.3 に vector を足した） |
| M-6 | 命令数 1 の検査を「1本目だけ見る」に弱める | AC-1 |
| M-7 | pin 集合を `runtime_profile_hash` から外す | AC-8 |
| M-8 | `is_native` / state の検査を削る | §8.3 の layout case |
| **M-9** | **pin した ELF を、挙動の違う ELF に差し替える**（`amount - 1` を送る／常に失敗する） | **AC-11(a)**。**これだけが「pin したバイトが実行されている」を単独で検定する。** 差し替えても verdict が動かなければ、走っているのは pin した image ではない |
| **M-10** | INV-8 の `mint` / `owner` 比較を削る | **AC-12** |
| **M-11** | INV-8 の `decimals` 比較を削る（または committed mint でなく命令の byte を読む） | **AC-12**。§4.0 のレイアウト前提も同時に観測する |

**mutant は 11 本ある**（2026-09-12 に M-9 / M-10 / M-11 を追加）。
**mutant は repository のファイルを書き換えずに適用する**（009 part 4 と同じ規律: sandbox に
複製して適用する）。**「手で走らせて報告書に貼る」自己申告にしない** —— runner が
mutant id → 検出した test 名の表を stdout に出し、AC-9 はその表を読む。

### 8.3 layout の負 case（6本）

frozen source / frozen destination / wrapped SOL destination / multisig authority /
mint 83 bytes / token account 166 bytes。**すべて `OperationalError`**（verdict ではない）
であることまで assert する。

**7本目（2026-09-12 追加、レビュー r1 MAJOR）: delegate 経路。** prestate で approve 済みの
**delegate が signer である** `TransferChecked`。§6.2 の **A-3** が名指しする攻撃で、
**旧仕様はこの vector をどこにも持っていなかった**（M-5 の帰属先が存在しなかった理由）。
`OperationalError::UnsupportedAuthority` であることまで assert する ——
**authority は source token account の owner フィールドと一致する signer でなければならない**（§4.1）。

### 8.4 書かないテスト

- devnet に対する test（§10）。
- guest に対する test（N-1）。
- `escrow-svm` の extension 穴に対する test（N-2。**開示するだけ**）。
- Token-2022 の test（P4）。

---

## 9. マイルストーンと完了定義

**P0 と P1–P3 の間に依存は無い。** P0 は既存物の実演、P1–P3 が 010 の実装である。

| | 内容 | 完了定義（**tier を跨がない**） |
|---|---|---|
| **P0** | 既存 Token-2022 vault の devnet 実演 | **前提が満たされて初めて着手可能**（§10）。完了 = 「devnet 上の deploy 済み program id」「Token-2022 mint」「fund → resolve(Reproduced) → seller 着金」の3つの **explorer で追える tx signature**。**この時点でも resolver 経路である**ことを、デモの台本と README に**同じ画面で**書く。§2 の extension 未検査（L-3）と A-9 を**穴として併記する**。**「proof で決済した」と書かない。** |
| **P1** | pin された legacy SPL Token image の replay（**案 B: 閉じた世界**） | **先に4時間の spike**: seed した legacy-loader の program account が `add_program_preverified` 無しで compile・実行されるか。落ちたら**案 C を開示付きで採る**（決定メモ §5）。完了 = `cargo test -p reexec-svm` が §8.1 の4本と §8.3 の**7本**で緑、かつ **AC-11 と M-9 が緑**（＝pin したバイトが実行されている証拠）。**LiteSVM tier**。 |
| **P2** | `TokenAmountDelta` | AC-1〜AC-8 が緑。 |
| **P3** | mutant gate | AC-9 / AC-10 が緑。**ここまでが 010 の範囲。** |
| **P4** | extension 無し Token-2022 mint | 別仕様（011）。upgradeable loader 経路と `account_type` byte を閉じる。**transfer hook は入らない。** |
| **P5** | 実 snapshot 取り込み / Solana 上の proof-only settlement | **別仕様（012 / 013）。010 は一言も主張しない。** §12 L-4 が理由。 |

**tier の言い換えを禁じる一文**（デモ・README・提出文に転記する）:
> LiteSVM で緑であることは devnet について何も言わない。devnet で動いたことは mainnet について
> 何も言わない。resolver が署名した settlement は proof-only settlement ではない。

---

## 10. 外部依存と founder 承認が要る地点

**agent が越えられない線を、越える順に書く。**

| # | 必要なもの | 誰が |
|---|---|---|
| 1 | Solana CLI + `cargo build-sbf`（`platform-tools`）の導入 | agent が実行可（ネットワーク取得を伴うので founder に事前通知） |
| 2 | **devnet keypair と SOL** | **founder のみ。** agent は鍵も資金も持たない・取得しない |
| 3 | **devnet への program deploy** | **founder 承認必須。** 外部に向いた不可逆行為。`AGENTS.md` §8 が禁じるのは mainnet だが、devnet も agent の独断では行わない |
| 4 | devnet 上の Token-2022 mint 作成 / ATA 作成 / mint_to | **founder のみ**（2 に依存） |
| 5 | faucet（`https://faucet.solana.com` 等）の利用 | **founder のみ**。外部サービス |
| 6 | RPC provider（実 account 取り込み、P5） | **founder 承認必須**。外部サービス契約に触れうる |
| 7 | snapshot archive の取得（P5、bank_hash 検証に**全 account 集合**が要る） | **founder 判断。** RPC では原理的に得られない（`docs/svm-snapshot-authenticity.md`: lattice hash は全 state を一度にコミットし、単一 account の inclusion path が無い）。**これが P5 を別マイルストーンにする技術的理由であり、意思の問題ではない** |

**P0 は 2 と 3 が来るまで着手できない。** それまで P1–P3 は**独立に進む**（LiteSVM だけで閉じる）。

---

## 11. 他レーンを阻害しないための境界

**この節は、reckn 以外のレーンを名指しせずに書く。** この repository は 2026-09-04 から public であり
（`CLAUDE.md`）、ここに書いた期日・タスク番号・技術選択は**そのまま公開される**。
別レーンの内部日程やスタックは、それ自体が公開してよい情報ではない。境界は
**reckn 側で守れる規則としてだけ**書き、向こう側の語彙・番号・日付を持ち込まない。

**時間**

- ETHOnline 期間（〜9/12 凍結）: このレーンの成果物は**本仕様のみ**。実装0行。
- 9/12 の凍結後、9/15 まで: **このレーンは停止**（別の締切に明け渡す）。
- 9/16 以降: reckn は**従**である。**全体時間の 30% を上限**とし、P0 → P1 → P2 → P3 の順に進める。
  **主レーンの締切と衝突した週は reckn を 0% にする。** 30% は上限であって配分ではない。
  どの週がそれに当たるかは **founder が週次で決める**（本仕様は判定しない）。

**依存**

- **共有物ゼロ。** コード・crate・program id・keypair・fixture・CI・agent 定義・`docs/` の
  いずれも他レーンと共有しない。他 repository から import せず、他 repository へ export しない。
- **同じ技術に触れることを、混同の理由にしない。** 別レーンが Solana に触れる場合でも、
  **同じ program を使わず、同じ鍵を使わず、同じ devnet deploy を両方のデモに映さず、
  一方の成果をもう一方の証拠として引用しない。**
- **一提出制約。** 本仕様は **reckn を他の大会へ提出する判断を含まない**。
  010 の成果物が reckn 以外の提出物に現れることは無い。
- **文書の一方向性。** reckn の文書は他レーンを参照しない。**この節自体がその規則に従っている** ——
  ここには他レーンの名前・タスク番号・期日・スタックが1つも無い。

---

## 12. 正直な限界（010 が閉じないもの）

- **L-1**: `min = 0` の deal は「何もしない」で満たされる。`LamportsDelta` と同じ既知の穴。
- **L-2**: pin した ELF が**本物の SPL Token である**ことは、010 の内側では確認できない。
  pin する値の出所（どのバイト列を正とするか）は **[要一次資料]** であり、
  実装時に「その 32 bytes をどこから取ったか」を仕様の中に literal で書く。**R-10**。
- **L-3**: `escrow-svm` の vault は Token-2022 を名指しながら extension を1つも検査していない
  （§2）。**010 はこれを直さない。** P0 のデモは、直っていないことを画面に併記する。
- **L-4**: 010 の prestate はテストが構成したものであり、**Solana クラスタのものではない**。
  `bank_hash` 再計算（guest 側にはある）も、それが実在のクラスタのものだったことは示さない
  —— `CLAUDE.md` が 009 について書いているのと**同じ限界**が、そのままここにも残る。
- **L-5**: A-10（syscall 経由の sysvar）は AC-6 の**観測**で閉じるのであって、
  静的に閉じてはいない。`TransferChecked` の実装が将来変わればすり抜けうる。
- **L-6**: `escrow-svm` は **proof を1本も見ない**。010 の後も、SVM 側の settlement は
  resolver 署名である。**proof-only settlement は P5 であり、010 の成果ではない。**

---

## 13. OPEN QUESTION（founder）

- **OQ-1**: P0（devnet 実演）は、resolver 経路のままで審査・対外文脈に出す価値があるか。
  中心主張は「判定する鍵が存在しない」であり、**P0 が見せるのは鍵のある経路**である。
  *推奨*: **出すが、同じ画面に「これは resolver 経路である」と書く。** 書けないなら P0 を落とす。
- **OQ-2**: CU 予算を `runtime_profile_hash` に入れるか（A-11）。
  *推奨*: **010 では入れず、OQ として開示する。** 入れると profile の版が上がり、
  既存の anchor が全部無効になる。
- **OQ-3**: `min = 0` を仕様レベルで拒否するか（L-1）。
  *推奨*: **拒否しない。** 述語の意味論の問題ではなく deal 設計の問題であり、
  ここで閉じると `LamportsDelta` と非対称になる。
- **OQ-4**: §11 の境界を**機構**にするか（現状は規則として書いてあるだけで、観測器が無い）。
  **この仕様の起草中に、§11 が実際に破られた** —— 初稿の §11 は別レーンの内部日程と技術選択を
  列挙しており、しかも同じ節の末尾が「持ち込んでいない」と書いていた。**R-9 の形**である
  （自分の観測器を壊すことで満たされる基準）。commit 前に発見・除去したので流出は無い。
  *閉じ方の問題*: 禁止語 grep は **R-7 違反**であり、しかもそのリスト自体が
  **public な repo に置かれた秘密の列挙**になるので、対策が事故になる。
  *推奨*: `no-keys.sh` の check 5b と同じ **語彙閉包**で閉じる ——
  *「`docs/specs/` に現れる固有名詞は、この repository のファイル・`AGENTS.md`・`PLAN.md` に
  既出のものだけ。未知の固有名詞が現れたら赤」*。**許可側を閉じるので、禁じたい語を一語も書かずに済む。**
  初稿の §11 はこの検査で捕まる。**010 のスコープには入れない**（別タスク）。

---

**次の手順**: `reckn-codex-review`（stage=spec、1回）→ APPROVE なら凍結して
`reckn-codex-impl` へ **P1 から**引き渡す。P0 は §10 の 2 / 3 が満たされるまで着手しない。
