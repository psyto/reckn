# デプロイ順 — 09-25 21:00 ブロック（会場）

**これは `013` §4 の実装ではない。順番と引数の計画で、`PREFLIGHT` が `cast send` の行を事前に
持っているのと同じ範囲。** 契約のコードは 21:00 まで書かない。

すべての数値は **2026-09-25、21:00 より前にチェーンから読んだ実測**。

---

## ★ 0. 先に読む — 深夜に取り違える2つ

### 0.1 アドレスが他チェーンと衝突する

`reckn-agent` の **nonce 1 からの CREATE** は、どのチェーンでも同じアドレスになる。

| | |
|---|---|
| `arc.json` の `RecknVerdictVerifier`（Arc） | `0xc5f45b9dec0f0b00a1493c63c0204c8c920197b7` |
| **今日の Sepolia デプロイ予行の捨て契約** | **`0xc5f45b9deC0f0B00a1493C63C0204C8C920197B7`** |

**同じアドレス。中身は無関係。** Sepolia 側は `slot 0 = 1` を書くだけの捨て契約で、
**verifier ではない。**

> **03:00 に Sepolia の explorer で `0xc5f45b9d…` を見て「うちの verifier だ」と思わないこと。**
> 今夜の Sepolia デプロイは **nonce 2 以降**から始まる。**nonce を控えながら進める。**

### 0.2 `reckn-agent2` に `approve` / `setApprovalForAll` をしない

`ReputationRegistry` の門番は
`require(!isAuthorizedOrOwner(msg.sender, agentId), "Self-feedback not allowed")` で、
`isAuthorizedOrOwner` は **ERC-721 の標準チェック**（owner **または承認された相手**）。

**一度でも承認すると、カットB も revert して冒頭が成立しない。**

---

## 1. 今日測った数字

| | |
|---|---|
| ガス価格 | **0.94〜1.08 gwei**（09-21 の実測と同じ水準） |
| `reckn-agent` `0xfa2582ec…` | **0.044846 ETH** · nonce **2** |
| `reckn-agent2` `0xF81dFf68…` | **0.005 ETH** · nonce 0 · code `0x`（新品の EOA） |
| MockUSDC | **1000.000000** |
| デプロイ予行 | `0xc5f45b9d…`、gas **75,238**（計算値と差1）、`status 1` |

## 2. 既にチェーンに在るもの（デプロイ不要）

| | アドレス |
|---|---|
| ERC-8004 `IdentityRegistry` | `0x8004A818BFB912233c491871b3d84c89A494BD9e` |
| ERC-8004 `ReputationRegistry` | `0x8004B663056A597Dffe9eCcC1965A193B7388713` |
| ENS `ETHRegistrar` | `0xAbe76F6C8DFcEd81AA5A2bB8034202A7136b94ca` |
| ENS `UniversalResolverV2` | `0x5d25C1D6aCBb71B7a28AA7899618a3412a8303e3` |
| Permissioned Resolver **実装** | `0x14F09Fd05d4585759e54844DC9B00147131Cf243` |
| MockUSDC | `0x16f95D91DBa7dA3Aca778Ec053dF0FF6C6A8aA8e` |
| ENS `LabelStore` | **`0x375c082021e677a40ea2ae094d050602dba90992`** |
| ENS `ETHRegistry`（参考） | `0x657ea849311d3d5823348dded7c2aaafb3ede09e` |
| Uniswap v4 `PoolManager` | `0xE03A1074c86CFeDd5C142C4F04F1a1536e203543` |

**ENS の4つ**（`ETHRegistrar` · `UniversalResolverV2` · Resolver 実装 · `LabelStore`）**と
MockUSDC は、1つの系列に属する。** `ETHRegistrar` → `ETH_REGISTRY()` → `LABEL_STORE()` と
チェーンを辿って確認した（09-25）。**他系列のアドレスと混ぜてはいけない**（§3）。
ERC-8004 の2つと `PoolManager` はこの話と無関係。

両 ERC-8004 レジストリは `getVersion()` が **`"2.0.0"`**、`isAuthorizedOrOwner` が存在しない id で
`ERC721NonexistentToken`。**読んだソースと指紋が一致している。**

---

## ★ 3. 解決済み — `LabelStore` は在る。ただし **系列を混ぜるな**

**2026-09-25 に解決。ブースに聞く必要はなかった。** `PermissionedRegistry` の constructor は

```
PermissionedRegistry(ILabelStore labelStore, address rootAccount, uint256 roleBitmap)
```

で、spike は `MockLabelStore2` を使っていた（`S7_RealNameResolution.t.sol:68`）。
**正式なものはチェーン上に在り、自分でデプロイする必要はない:**

```
ETHRegistrar  0xAbe76F6C8DFcEd81AA5A2bB8034202A7136b94ca
  └ ETH_REGISTRY()  0x657ea849311d3d5823348dded7c2aaafb3ede09e
      └ LABEL_STORE()  0x375c082021e677a40ea2ae094d050602dba90992   ←  これを渡す
```

### ★ そのかわり出てきた、もっと大きい話

**Sepolia に ENSv2 のデプロイ群が少なくとも3つあり、どれも生きている。**

| 出どころ | `ETHRegistrar` | `LabelStore` |
|---|---|---|
| **spike が使った（今夜これを使う）** | `0xAbe76F6C…` | `0x375c0820…` |
| vendored `deployments/sepolia` | `0xa4449a0d…` | `0xb0352428…` |
| vendored `sepolia-official-v1-20260525-r2` | `0x8c2e866b…` | `0x23ea712d…` |

`reckn` は**どの系列でも空いている**ので、**間違った系列に登録しても成功してしまう。**
失敗は静かで、**気づくのは「誰も解決できない名前ができた」後**になる。

**spike の系列を使う理由（3つとも実測）:**

1. **`UniversalResolverV2` 経由の解決まで通したのはこの系列だけ**（S7）。E-Q3 が要求しているのは
   まさにそれ
2. **MockUSDC `0x16f95D91…` に 1000 持っているのもこの系列。** 他系列は別の MockUSDC
   （`0xd3322b29…` / `0xba11ebdb…`）で、**残高はゼロ**
3. `PermissionedResolverImpl` `0x14F09Fd0…` も spike が検証済み

**なぜ食い違うか**: vendored の `ens-v2` は **commit `48b3e2d`（2026-07-03, "Post Audit Changes"）**
に固定されていて、`deployments/sepolia` は**7月時点の記録**。spike が9月に取ったアドレスは
**vendored ツリーのどこにも現れない**ので、それ以降に置き換わった現行だと考えられる。
**ENS ブースで裏を取る**（デッキの質問1）。**答えが来る前でも、上の3つの理由で進めてよい。**

> **各ステップで、使っているアドレスが上の表の1行目であることを確認する。**
> 2行目・3行目のアドレスが混ざったら、その時点で止めて戻す。

## 4. 順番

依存で決まる。**ENS の待ちは 60 秒しかないので、順番の制約にはならない。**

### ① ビート1 — ERC-8004（依存なし・最初にやる）

デモの冒頭であり、**5分で終わり、ラッシュ①の素材になる。**

```bash
# 登録（reckn-agent = エージェント本人。EOA であること）
cast send 0x8004A818BFB912233c491871b3d84c89A494BD9e "register()" \
  --account reckn-agent --rpc-url $SEPOLIA_RPC
# → agentId は 2 番以降。約 108,899 gas。料金なし
```

```bash
# カットA：本人から → Self-feedback not allowed で revert する「べき」
cast send 0x8004B663056A597Dffe9eCcC1965A193B7388713 \
  "giveFeedback(uint256,int128,uint8,string,string,string,string,bytes32)" \
  <agentId> 100 0 "" "" "" "" 0x0000000000000000000000000000000000000000000000000000000000000000 \
  --account reckn-agent --rpc-url $SEPOLIA_RPC
```

```bash
# カットB：reckn-agent2 から → 通る
#   （同じ呼び出しを --account reckn-agent2 で）
```

**revert 文言が `Self-feedback not allowed` であることを目で確認する。**
これが `DEMO.md` §1 に残した「プロキシの実装がソースと同一か未確認」の最後の1つを閉じる。

`register()` は**過負荷が3つ**あるので、`cast` では署名を完全に指定する。

### ② `RecknZkEscrow`（依存なし）

**constructor が無い。** 引数不要。

### ③ SP1 verifier → `RecknVerdictVerifier`

```
RecknVerdictVerifier(address _verifier, bytes32 _verdictProgramVKey)
```

`_verdictProgramVKey` は**再実行 guest のもの**:
`0x00c2ee9999a00a5987a5b5c5261bee355bbb6e86c145429775d9fe89f496e16d`
（`reexec-groth16-fixture.json`。**SVM guest は別の vkey**
`0x004ad9fc…` なので混ぜない）

`RecknVerdictVerifier` は **vkey が immutable で1つだけ**。1つの verifier は1つの guest しか裁定しない。

### ④ `PermissionedRegistry`

```
PermissionedRegistry(
  labelStore  = 0x375c082021e677a40ea2ae094d050602dba90992,
  rootAccount = reckn-agent (0xfa2582ec…),
  roleBitmap  = ALL_ROLES
)
```

**`labelStore` は §3 の1行目の系列のもの。** `0xb0352428…` や `0x23ea712d…` を渡すと、
`ETHRegistrar` と噛み合わない。

### ⑤ Resolver のインスタンス

**実装 `0x14F09Fd0…` に向けた本物のプロキシ**を立てて `initialize` する。
**EIP-1167 clone は使えない** — 実装は UUPS なので `onlyProxy` の中で 210 gas で死に、
revert データも出ない（S1 の実測）。

### ⑥ 名前を実 `ETHRegistrar` に登録

**ラベルは `reckn` が空いている**（今日確認。`reckn-agent` / `recknlabs` / `reckn2026` も空き）。

| | |
|---|---|
| `MIN_COMMITMENT_AGE` | **60 秒** |
| `MIN_REGISTER_DURATION` | **2,419,200 秒 = 28 日** |
| 価格 | **base 0.613701 + premium 0.000000 MockUSDC** |

```
approve(MockUSDC → ETHRegistrar)
makeCommitment(label, owner, secret, subregistry = 我々の PermissionedRegistry,
               resolver = ⑤ のインスタンス, duration, referrer = 0x0)
commit(commitment)
--- 60 秒待つ ---
register(label, owner, secret, subregistry, resolver, duration,
         paymentToken = MockUSDC, referrer = 0x0)
```

**`secret` は控えておく。** `commit` と `register` で同じ値でなければ通らない。

### ⑦ エージェントの subname

**`ROLE_SET_RESOLVER` を付けない。** S7 は `ROLE_RENEW` だけを渡している。
**名前を持っていても、自分の記録面を差し替えられない**というのが主張の一部（S4）。

### ⑧ 通しの確認

`UniversalResolverV2` `0x5d25C1D6…` 経由で解決できること。
**自分の resolver を直接叩くのでは足りない** — ENS の解決経路を通ることが E-Q3 の要件。

---

## 5. ガスの見積もり

`PREFLIGHT` §1 の実測バイトコードから。

| | |
|---|---|
| `PermissionedRegistry` | ~4.79M |
| `SP1Verifier` | ~2.46M |
| `RecknZkEscrow` | ~1.16M |
| `RecknVerdictVerifier` | ~0.43M |
| resolver proxy · 名前登録 · subname · ERC-8004 | ~1.5M |
| **合計** | **~10.4M** |

1 gwei で **約 0.0104 ETH**。残高 0.044846 ETH に対して、**やり直し3回分の余裕**がある。
ガスが跳ねたら faucet を1回引く。

---

## 6. 各段階でやること

- **nonce を控える。** `0.1` のアドレス衝突はこれで防げる
- **デプロイしたアドレスをその場で記録する。** 記憶から転記しない
  （`CLAUDE.md`：**検査されない領収書は、領収書が無いより悪い**）
- **commit は 30〜60分ごと。** 単一の大 commit は既定で失格扱い
- commit 前に毎回 `bash scripts/no-keys.sh`
- **`git add -A` を使わない**
