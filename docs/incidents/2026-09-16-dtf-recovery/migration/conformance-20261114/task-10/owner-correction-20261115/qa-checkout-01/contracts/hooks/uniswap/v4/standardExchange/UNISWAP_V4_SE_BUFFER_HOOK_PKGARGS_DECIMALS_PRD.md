# Product Requirements Document

## Title

**Uni V4 SE buffer hook `PkgArgs` decimals** — deployer-supplied scales; no ERC-20 calls at hook create

## Status

**planned** — 2026-09-02. Locked for implementors. Execute plan: [`UNISWAP_V4_SE_BUFFER_HOOK_PKGARGS_DECIMALS_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_SE_BUFFER_HOOK_PKGARGS_DECIMALS_IMPLEMENTATION_AND_TEST_PLAN.md).

| Field | Value |
|-------|--------|
| **Home** | `contracts/hooks/uniswap/v4/standardExchange/` |
| **Depends on** | I/O routing §16.1 hook-first; token policy (non-18 pair tokens allowed; DETF ERC-20 is 18); no `try` in production hook init |
| **Unblocks** | Public DETF create without `vm.etch` / `anvil_setCode` |

---

## 0. Intent

Hook-first DETF create predicts the DETF CREATE2 address, deploys the reserve hook with that address as self-leg and owner, then deploys the DETF diamond onto the empty account. Hook `initAccount` today calls `IERC20Metadata.decimals()` (CP: hard call; weighted/orbital/quad: `try` default 18) and sometimes `symbol()`. The predicted DETF has no code, so CP reverts and tests/UI etch bytecode. Public networks cannot etch.

The hook must take scales from `PkgArgs`. The deployer (UI, script, TestBase) reads live pair/SE tokens off-chain or passes 18 for the DETF self-leg. Hook create must not call any ERC-20.

---

## 1. Decisions (`HDEC-*`) — LOCKED

| ID | Topic | Decision |
|----|-------|----------|
| **HDEC-1** | Deploy order | Unchanged. Predict DETF (`calcSalt` zeros `hook`) → hook `deployVault` with predicted DETF as self-leg and owner → `deployPair` / `finalizeInitialization` → `uniV4DetfPkg.deployVault` with live `args.hook`. Do not reverse order. Do not put `hook` into DETF salt. |
| **HDEC-2** | No token calls | `initAccount` and `processArgs` must not call `decimals()`, `symbol()`, `name()`, or any other ERC-20 / metadata function on pair tokens, DETF self-leg, or SE shares. |
| **HDEC-3** | No `try` | Do not add or keep `try IERC20Metadata` in these DFPkgs for create. Delete `_readDecimals` and `_safeSymbol` from in-scope packages. |
| **HDEC-4** | Decimals in `PkgArgs` | Named `uint8` fields, ABI order locked in the execute plan. Deployer-supplied. |
| **HDEC-5** | Salt | `calcSalt` **includes** the new decimal fields. Different claimed scales → different hook instance. |
| **HDEC-6** | Range | Every **used** decimal is in `[6, 18]`. Out of range → `InvalidDecimals()`. |
| **HDEC-7** | Self-leg | The DETF self-leg slot (`rawToken` on CP; `tokens[i]` / `tokenN` where the bound SE is `address(0)`) **must** be `18`. Do not call the account to prove it. |
| **HDEC-8** | Unused SE slots | Where `standardExchanges[i] == address(0)`, `seDecimals[i]` is ignored (not range-checked). |
| **HDEC-9** | LP metadata | Fixed package strings. Do not build LP name/symbol from token `symbol()`. |
| **HDEC-10** | Scope | In: CP, weighted, orbital, curve quad, balancer quad **SE buffer** hooks. Out: Dual SE CP; legacy single buffer; non-SE swap hooks (`hooks/uniswap/v4/orbital`, `weighted`, `stable/quad` without `standardExchange`). |
| **HDEC-11** | Etch | Forbidden in production UI. Remove `vm.etch` of the predicted DETF from in-scope TestBases and Foundry scripts after the hook change. Tests that need pair/SE decimals read them in **test** code and pass them in `PkgArgs`. |
| **HDEC-12** | DETF `PkgArgs.hook` | Unchanged. Still passed at DETF `deployVault` for `processArgs` / `initAccount`. Salt still zeros it. |

---

## 2. Why not DETF-first

CREATE2 prediction plus decimals in hook `PkgArgs` is enough for public create. Hook salt already includes the DETF address (`rawToken` / `tokens` / `owner`), so many DETFs may share the same pair tokens. Reversing deploy order is a separate PRD.

---

## 3. Requirements

### R1. CP SE buffer hook

`PkgArgs` gains `uint8 pairTokenDecimals` and `uint8 rawTokenDecimals` after `rawToken`, before `ownerOnlyLiquidity`. `processArgs` / `_validateArgs`: both in `[6,18]`; `rawTokenDecimals == 18`. `initAccount` stores those scales on the sorted currency pair (match `pairToken` / `rawToken` to `c0`/`c1`). LP name `SE Buffer CP Hook LP`, symbol `SSEBCP-LP`.

**Acceptance**

- [ ] Hook deploys with `rawToken` an empty EOA and `rawTokenDecimals = 18`.
- [ ] `rawTokenDecimals != 18` reverts `InvalidDecimals`.
- [ ] `pairTokenDecimals` 5 or 19 reverts `InvalidDecimals`.
- [ ] `calcSalt` differs if only `pairTokenDecimals` differs.
- [ ] DFPkg source has no `IERC20Metadata` use.

### R2. Weighted SE buffer hook

`PkgArgs` gains `uint8[] tokenDecimals` and `uint8[] seDecimals` after `rateProviders`, before `ownerOnlyLiquidity`. Length of each must equal `n` and `tokens.length`. Self-leg `tokenDecimals[i] == 18`. Bound SE `seDecimals[i]` in `[6,18]`. `initAccount` uses these instead of `_readDecimals`. LP name/symbol stay the current fixed strings.

**Acceptance**

- [ ] Same empty-self-leg deploy as R1.
- [ ] Length mismatch reverts (existing array-length error or `InvalidDecimals`; pick the existing length error if one exists).
- [ ] Salt includes both arrays.

### R3. Orbital SE buffer hook

`PkgArgs` gains `uint8 decimals0`, `decimals1`, `decimals2` after `token2` (before SEs). The index whose `seN == address(0)` must be 18. Other used token decimals in `[6,18]`. Orbital does **not** add `seDecimals` (init does not store SE share scales today). LP name `SE Orbital Buffer Hook LP`, symbol `SEORB-LP`.

**Acceptance**

- [ ] Empty self-leg deploy.
- [ ] No `_safeSymbol` / `_readDecimals` in the DFPkg.

### R4. Curve quad and balancer quad SE buffer hooks

`PkgArgs` gains `uint8[4] tokenDecimals` and `uint8[4] seDecimals` after `rateProviders`, before `baseAmp`. Same self-leg / unused-SE rules as R2. Fixed LP strings (keep current fixed names if already fixed; if a family still concatenates symbols, replace with `SE Quad Buffer Hook LP` / `SEQUAD-LP` for curve and `SE Balancer Quad Buffer Hook LP` / `SEBQ-LP` for balancer).

**Acceptance**

- [ ] Empty self-leg deploy for both packages.
- [ ] Salt includes both `[4]` arrays.

### R5. Callers

Every in-scope constructor of these `PkgArgs` (TestBases, `UniswapV4DetfHookPremineLib`, Foundry instance scripts, DTF create wizard encode) passes the new fields. Predicted DETF is not etched.

**Acceptance**

- [ ] `rg 'vm.etch\\(predicted' contracts/vaults/detf/protocols/dexes/uniswap/v4 test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4 scripts/foundry` is empty for DETF-create paths.
- [ ] Wizard `DetfDeployPanel` does not call `seedAccountCode`.
- [ ] Wizard reads pair/SE decimals via RPC `decimals()` and passes `18` for the DETF self-leg.

---

## 4. Non-goals

1. DETF-first / remove `hook` from DETF `PkgArgs` / staged DETF bind.
2. Custom I/O route UI.
3. Orbital create-wizard type.
4. Dual SE CP and non-SE swap hook `PkgArgs`.
5. On-chain verify that a live pair token’s `decimals()` matches `PkgArgs` (that would be a token call at create).
6. Changing DETF `calcSalt` (still zeros `hook`).
7. `via_ir`. SUT mocks.

---

## 5. Execute

Implementation plan: [`./UNISWAP_V4_SE_BUFFER_HOOK_PKGARGS_DECIMALS_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_SE_BUFFER_HOOK_PKGARGS_DECIMALS_IMPLEMENTATION_AND_TEST_PLAN.md)

Run: `/goal contracts/hooks/uniswap/v4/standardExchange/UNISWAP_V4_SE_BUFFER_HOOK_PKGARGS_DECIMALS_IMPLEMENTATION_AND_TEST_PLAN.md`
