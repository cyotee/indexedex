# MiniMax M3 — L3 SY-Conversion Cross-Review (Bounded Round)

> Cross-review of three peer originals. Read together; no peer cross-review consulted. My `minimax-original.md` is the baseline. Routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. What each peer actually read vs what they inferred

**Astra** read: (a) `sourcify.dev/server/v2/contract/4663/0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5?fields=proxyResolution,compilation` (proxy→impl mapping); (b) `sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=metadata` (compilation settings); (c) `sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=compilation,sources` returned a ~109KB single-line JSON; `read` truncated at 2000 chars and grep omitted the long line. They confirmed constructor + constants recovered (the prefix), inheritance (`SYBaseUpgV2`, `TokenWithSupplyCapUpg`), and that `_deposit` token exists — **but the body was NOT read**. IPFS gateways (ipfs.io 429, dweb.link 429, Pinata timeout, Lighthouse 402, Filebase 504), Blockscout 403, legacy repo 404 — all failed.

**Grok** read: ABI fields=`abi`; `?fields=sources` returned ~108KB JSON, single-line, `read` truncated at 2000 chars. Recovered: constructor signature `(_sNet, _decimalsWrapperFactory)`, recovered constants `INDEX_BASE=1e9`, `DECIMALS_OFFSET=1e9`, `INITIAL_FRAGMENTS=5_000_000_000e9`, `TOTAL_GONS`, `MAX_SNET_SUPPLY`. **No body read.** Distinguishes the 4 layers and lists misses but explicitly says "do not invent them."

**Kimi** read: `?fields=sources` returned ~230KB JSON, single-line; the opening section of the first source entry was verbatim-readable — **~60 lines shown including the full skeleton up to `/* DEPOSIT/REDEEM USING BAS… */`**. This is a **substantially larger source excerpt** than I or the other peers recorded. It includes: `pragma solidity ^0.8.17;`, imports, all four constants, full constructor body (`:38–:45`), full `initialize` body (`:47–:52`), and confirmed no `sNetToWs/wsToSNet/wsNet/WrappedStakedNET/taxEnabled/isTaxExempt/isTaxedPair` matches via full-bundle probe. **Body of `_deposit`/`_redeem`/`_previewDeposit`/`_previewRedeem`/`exchangeRate`/etc. was NOT extracted** (line-length cap and grep truncation).

**Me (MiniMax)**: same fields=`sources` retrieval; truncated at 2000 chars; reported "we have ABI + constructor signals; we do NOT have the raw source file." **Partially wrong** — Kimi demonstrated the opening ~60 lines ARE extractable.

---

## 2. Critical correction to my original

**My original §1 said:**
> "Implementation (Sourcify): `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E` on chain 4663, verified `2026-09-04T08:05:04Z`, compiler `0.8.30+commit.73712a01`, optimizer **800**, **Osaka**, **`viaIR=false`**."

**Wrong.** Verified values (per Astra and Kimi, both direct reads): optimizer **1,000,000**, **Cancun**, **`viaIR=true`**. Compiler version `0.8.30+commit.73712a01` is correct.

**My original §1 said:** "Source URL on Sourcify's repo: `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`."

**Wrong term.** It is a **fully-qualified name (FQN)** from the compilation metadata, not a URL. The repo path is `lib/pendle-sy/...` (i.e., `pendle-sy` repository, remapped as `@pendle/sy/`). It is NOT in the public `pendle-finance/Pendle-SY-Public` repo at this path — that repo has no `implementations/NET/` directory.

**My original §1 said:** "We have ABI + constructor signals + API attestation (scaled18 wrappers, NET/sNET direction); what we do NOT have: the raw source file."

**Partially wrong.** Kimi shows the opening ~60 lines ARE extractable from the saved JSON: `pragma solidity ^0.8.17;`, all 4 imports, all 5 constants, constructor body (`:38–:45`), initialize body (`:47–:52`). **What we do NOT have**: the body of `_deposit`, `_redeem`, `_previewDeposit`, `_previewRedeem`, `exchangeRate`, `_updateRewardIndexes`, `_transferRewardsOut`, etc. (these continue past the ~60-line readable prefix).

---

## 3. Do NOT derive SY mint 1:1 from scaled yieldToken

The user is right that **specialized rebase constants/index suggest source-dependent share relation**. The constructor sets `yieldToken = decimalsWrapperFactory.getOrCreate(_sNet, 18)` (scaled18 wrapper of sNET). This **does NOT prove** that deposit(underlying) returns `amount · 10^9` SY shares. It only proves the wrapper exists and is used as the yieldToken reference.

**The mirror of StakedNET's gons constants** (`INITIAL_FRAGMENTS`, `TOTAL_GONS`, `INDEX_GONS`, `MAX_SNET_SUPPLY`) suggests the SY mirrors the sNet rebasing model. But:
- The `_deposit` body is **not read** — we cannot confirm whether deposit(sNet) returns `10^9 · amount` SY shares (1:1 with scaled units), or uses an `index`-adjusted formula.
- The `exchangeRate()` body is **not read** — we cannot confirm the rate formula.
- The `INITIAL_FRAGMENTS / 10^9 ≈ 5e9` sNet fragments matches `StakedNET`'s genesis supply, but that is **deduction from local source** not deployed SY verification.

My original §2.3 said "Source supports an integer-exact inverse ONLY for the linear path (underlying-NET, no rebase): previewDeposit and previewRedeem from SYBase return the configured SYBase calcTotalValueAndReallocate output."

This is **a deduction about linear paths**, not a verified reading. The user correctly notes: scaled yieldToken's mere existence does not prove the share relation. **Withdraw any inference that mint = 10^9 · amount for rebasing sNet paths.**

---

## 4. Reject unknown current cap / whitelist / initialization / live tax claims

- **Supply cap**: ABI shows `getAbsoluteSupplyCap() / updateSupplyCap(uint256)` — current value **NOT read** (NN-01 evidence). Initialization sets cap to `type(uint256).max` (per Kimi's skeleton, line 49: `_updateSupplyCap(type(uint256).max);`). **Do NOT assert current cap ≠ `type(uint256).max` or that it has been changed.**
- **Whitelist (FEES.HTM exemption)**: per Kimi's probe, no `taxEnabled/isTaxExempt/isTaxedPair` strings exist in the SY source. **This does NOT prove the deployment is whitelisted on chain 4663.** It only proves the SY itself does not model the tax. The whitelisting lives in `NET.sol`'s `taxCollector.exemptAddresses(...)` mapping, which is **not read**.
- **Initialization on chain 4663**: the constructor runs once. `initialize(...)` is **upgradeable**, gated by `__SYBaseUpgV2_init`. Whether the deployed proxy has been called by NetNet's deployer is **not read**. The skeleton source only proves the *constructor* path; whether `initialize` was called live is **not asserted**.
- **Live tax state**: PRD §8 requires NET FoT-aware SE. **The custom V2 SE** (not the SY) is the tax modeler. The SY's `net()` getter returns the NET address; the SE checks `NET.isTaxedPair(token)` and `NET.isTaxExempt(token)` directly. **No live NET tax state was read** (NN-01 evidence).
- **Owner-gated `updateSupplyCap`**: ABI shows `Ownable`-style (transferOwnership / claimOwnership / pendingOwner). **The live owner address is not asserted.**

---

## 5. Fresh compilation settings vs local NET compile

Kimi + Astra both confirmed (direct reads):
- **solc 0.8.30+commit.73712a01**
- **optimizer 1,000,000**
- **viaIR true**
- **evm cancun**
- **remappings `@pendle/sy/=lib/pendle-sy/`**

These are the deployed contract's compilation facts. **The plan's local IndexedEx compile is `solc 0.8.35, optimizer runs 1, viaIR false` (per plan v0.6 §1.2 line 56).** Different compiler, different optimizer, different IR mode, different EVM version. **Do NOT assume local compile is equivalent.** Local verification (forge build, test) requires re-compiling any borrowed source under local settings.

---

## 6. Isolate NET-DETF staking (gons) from external SY conversion

The user's explicit ask. Confirmed:
- `DETFFundedStakingRepo.sol` (gons-based, IndexRebase math, `gonsPerUnit`, funded `accountedBacking`, `totalGons`, standing fee/creator weights, `_rebase` via `Math.mulDiv` ceilings) is **NET-DETF-specific** — funded-gons model, not the SY's gons model.
- `PendleStakedNetSY` constructor mirrors `INITIAL_FRAGMENTS` / `TOTAL_GONS` / `INDEX_GONS` — likely mirrors **NetNet StakedNET** (rebasing gons), not the DETF's funded-gons.
- These are **two distinct gons systems**: (1) NET-DETF staking child (funded, with `accountedBacking` and `stakingDust`), and (2) the SY itself (rebasing over a scaled18 wrapper).

**Do not mix the two.** Conversion between them is bounded by `previewDeposit/previewRedeem` (SY→scaled18) and the staking 1:1 mint/burn (NET↔sNet). The rebate rate changes via the sNet index, NOT via the DETF staking's `gonsPerUnit`. **These are distinct supply rates; conversion math must account for each.**

---

## 7. Correct misnamed calls / paths / selectors

- "Source URL" → should be "Source FQN" (fully-qualified name from compilation metadata).
- "Source is not in public Pendle SY repo" — confirmed: `pendle-finance/Pendle-SY-Public` has no `implementations/NET/` directory (Kimi verified by full tree fetch).
- "Mirror of NetNet constants" → clarify: **mirror of NetNet's StakedNET gons constants** (`StakedNET.sol:25–28`), not mirror of DETF funded-gons. The `Math.INDEX_BASE/INITIAL_FRAGMENTS` constants are local-source fact; the SY constants with identical names ARE local source fact copied into the SY contract.
- "Address-of wrappers" `0xba46fc...9727` and `0x5317c...33db` — these are **Astra's** (per repo view at chain 4663, immutable table). I did not read them directly; **I should not cite them as my own data**.

---

## 8. Plan update: truthful readable-code blocker

The plan should record:
- **What is verified**: ABI (`?fields=abi`); proxy/impl mapping (`?fields=proxyResolution,compilation`); compilation settings (`?fields=metadata`); opening ~60 lines of source (`?fields=sources`, opening section). matchId 47105638, verifiedAt 2026-09-04T08:05:04Z, compiler 0.8.30+commit.73712a01, optimizer 1e6, viaIR true, cancun, FQN `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`.
- **What is NOT read (smallest missing evidence)**: function bodies of `_deposit`, `_redeem`, `_previewDeposit`, `_previewRedeem`, `exchangeRate`, `_updateRewardIndexes`, `_transferRewardsOut`, `getTokensIn/Out`, `isValidTokenIn/Out`, `assetInfo`, `pricingInfo`, `updateSupplyCap` (live value).
- **What is NN-01 evidence (not L3 plan)**: live `getTokensIn/Out`, `assetInfo`, `pricingInfo`, current supply cap, current owner, current reward tokens, live NET tax state, current whitelist, whether `initialize` was called.

The plan should **not** claim L3 is closed until the smallest missing evidence is acquired. L3 is a **readable-code blocker**: without the function bodies, the plan cannot specify the exact integer NET↔SY flows or mint relation.

---

## 9. Recommended smallest extraction handoff (no new endpoint campaign)

The smallest missing evidence is the function bodies of `_deposit`, `_redeem`, `_previewDeposit`, `_previewRedeem`, `exchangeRate`. These are inside the saved JSON (`?fields=sources` returned ~230KB single-line). **A JSON-aware reader** (parser, or a tool that joins continuation lines) would extract them. **No new endpoint, no retries of failed URLs, no shell, no execution.**

If a JSON-aware reader is available, the extraction can be done in one step. **Without a JSON-aware reader, the next-best is a direct Blockscout PRO endpoint** (which requires a key — not sent externally) **or a pull from Pendle's official source repo if/when published** (the public `pendle-sy-public` repo currently has no `implementations/NET/` directory).

---

## 10. Source mapping (what the plan can specify NOW)

Even without body extraction, the plan can specify the following (verified):

- **Imports** (`PendleStakedNetSY.sol:5–8`): `SYBaseUpgV2`, `IPDecimalsWrapperFactory`, `TokenWithSupplyCapUpg`, `IStakedNet`, `IStakedNetStaking`.
- **Constructor body** (`:38–:45`): `_sNet`, `decimalsWrapperFactory.getOrCreate(_sNet, 18)`, `staking = IStakedNet(_sNet).staking()`, `net = IStakedNetStaking(staking).net()`, `scaledNet = IPDecimalsWrapperFactory(_decimalsWrapperFactory).getOrCreate(net, 18)`.
- **Initialize body** (`:47–:52`): `__SYBaseUpgV2_init(name_, symbol_, _owner); _updateSupplyCap(type(uint256).max); _safeApproveInf(net, staking); _safeApproveInf(sNet, staking);`
- **Token set hypothesis** (probe-derived, NOT getTokensIn/Out read): `net`, `sNet`, `scaledNet`, `yieldToken = scaled18(sNet)`. **Must be confirmed from bytecode/source.**
- **No wsNET anywhere** (probe).
- **No NET tax predicates in SY** (probe).
- **Upgradability**: `SYBaseUpgV2` shell + `TokenWithSupplyCapUpg`. `updateSupplyCap` exists for owner changes.

---

## 11. Confidence and evidence limits

- **High** proxy/impl mapping, compilation metadata, opening source prefix verified directly.
- **High** compiler settings corrected: 0.8.30, 1,000,000 optimizer, viaIR true, cancun.
- **High** NetNet StakedNET gons constants mirrored (per source prefix).
- **Medium** that the unread body matches SYBaseUpgV2 standard behavior (typical pattern).
- **Low** on live values (NN-01 deferred).
- **Not claiming** the source body matches a public file (it doesn't — no `implementations/NET/` in `Pendle-SY-Public`).
- **Not reopening** weights, Universal NET synthetic, fees, holder proxies, excess same-NFT, pre-maturity rebond, intermediate reset / E+1, NN-03.

**Saved:** `docs/research/netnet-sy-conversion-2026-09-27/minimax-cross-review.md`. Originals untouched.
