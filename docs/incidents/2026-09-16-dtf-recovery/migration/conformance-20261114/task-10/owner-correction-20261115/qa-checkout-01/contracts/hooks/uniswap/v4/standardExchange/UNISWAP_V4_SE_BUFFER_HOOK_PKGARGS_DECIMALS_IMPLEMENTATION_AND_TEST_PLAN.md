# Implementation plan: Uni V4 SE buffer hook `PkgArgs` decimals

- **PRD:** [`UNISWAP_V4_SE_BUFFER_HOOK_PKGARGS_DECIMALS_PRD.md`](./UNISWAP_V4_SE_BUFFER_HOOK_PKGARGS_DECIMALS_PRD.md)
- **Created:** 2026-09-02
- **Status:** ready for `/goal`

This file is the execute artifact. Implementors follow this plan and the PRD. Do not invent requirements. Do not reopen HDEC-1–HDEC-12.

**Goal:** Hook create takes token/SE decimals from `PkgArgs`, never calls ERC-20, so hook-first DETF create works on a public chain without etching the predicted DETF.

**Architecture:** Keep predict-DETF → deploy hook → doors → deploy DETF. Extend each in-scope hook `PkgArgs` with `uint8` scales. `processArgs` range-checks. `initAccount` writes those scales into existing Repo fields. `calcSalt` hashes the new fields. Callers (TestBase, scripts, DTF wizard) supply pair/SE decimals from off-chain reads and `18` for the DETF self-leg.

**Tech stack:** Solidity DFPkgs (no `via_ir`), Foundry hermetic default profile, DTF create encode in `frontend/apps/dtf/app/create/lib/`.

## Global constraints

- Crane first: `PkgInit` / `PkgArgs` on the **interface**. Never `new` facets/DFPkgs.
- Production-first tests. No mocks of hook, package, factory, registry, fee oracle, DETF.
- DETF role names only (`rateAsset`, `pairToken`, `detfToken`). No RICH/RICHIR.
- Token policy: FoT forbidden; rebasing underlyings forbidden; non-18 pair tokens allowed; DETF share ERC-20 is 18.
- Foundry: default `forge test`. `via_ir` forbidden. First compile in a worktree: seed `cache_forge/` + `out/`; wait hours, never kill `solc`.
- No `try` / `catch` around ERC-20 in in-scope DFPkgs.
- No `anvil_setCode` / `hardhat_setCode` / `vm.etch` of the predicted DETF.
- Do not deploy from this work (frontend ROADMAP no-deploy). Package CREATE3 on 4663 is a later launch-script task after bytecode exists.

---

## Decisions (locked)

Copy of PRD HDEC-*. Do not edit here without editing the PRD.

| ID | Decision |
|----|----------|
| HDEC-1 | Deploy order unchanged. DETF salt still zeros `hook`. |
| HDEC-2 | No ERC-20 calls in hook `initAccount` / `processArgs`. |
| HDEC-3 | No `try IERC20Metadata` in in-scope DFPkgs. |
| HDEC-4 | Decimals live on hook `PkgArgs`. |
| HDEC-5 | New decimal fields are in `calcSalt`. |
| HDEC-6 | Used decimals in `[6, 18]` else `InvalidDecimals()`. |
| HDEC-7 | Self-leg decimal must be `18`. |
| HDEC-8 | `seDecimals[i]` ignored when SE is `address(0)`. |
| HDEC-9 | Fixed LP name/symbol strings. |
| HDEC-10 | In: CP, weighted, orbital, curve quad, balancer quad SE buffer. Out: Dual, legacy single, non-SE swap hooks. |
| HDEC-11 | Remove predicted-DETF etch from DETF TestBases, instance scripts, wizard. |
| HDEC-12 | DETF `PkgArgs.hook` stays for init; salt still zeros it. |

### ABI field order (normative)

Insert new fields **exactly** as written. Frontend `components` arrays must match this order.

**CP** (`IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs`):

```solidity
address poolManager;
address feeOracle;
address standardExchange;
address pairToken;
address rawToken;
uint8 pairTokenDecimals;   // NEW
uint8 rawTokenDecimals;    // NEW, must be 18
bool ownerOnlyLiquidity;
address owner;
```

Add `error InvalidDecimals();` on this interface (weighted already has it).

**Weighted** (`IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs`):

```solidity
address poolManager;
address feeOracle;
uint8 n;
address[] tokens;
uint256[] weights;
address[] standardExchanges;
address[] rateProviders;
uint8[] tokenDecimals;     // NEW, length == n
uint8[] seDecimals;        // NEW, length == n
bool ownerOnlyLiquidity;
address owner;
```

Length mismatch → existing `ArrayLengthMismatch()`.

**Orbital** (`IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs`):

```solidity
address poolManager;
address feeOracle;
address token0;
address token1;
address token2;
uint8 decimals0;           // NEW
uint8 decimals1;           // NEW
uint8 decimals2;           // NEW
address se0;
address se1;
address se2;
address rp0;
address rp1;
address rp2;
int24 tickSpacing;
uint160 sqrtPriceX96;
bool ownerOnlyLiquidity;
address owner;
```

No `seDecimals` (orbital init does not store SE share scales). Add `error InvalidDecimals();` if missing.

**Curve quad** and **balancer quad** (same shape, two interfaces):

```solidity
address poolManager;
address feeOracle;
address[4] tokens;
address[4] standardExchanges;
address[4] rateProviders;
uint8[4] tokenDecimals;    // NEW
uint8[4] seDecimals;       // NEW
uint256 baseAmp;
bool ownerOnlyLiquidity;
address owner;
```

### How callers fill decimals

| Slot | Source |
|------|--------|
| Pair / listed ERC-20 | Off-chain / test `IERC20Metadata(token).decimals()` |
| SE vault share | Off-chain / test `IERC20Metadata(se).decimals()` (diamond is 18 today) |
| DETF self-leg (`rawToken`, or token whose SE is `address(0)`) | Constant `18`. Never call the predicted account. |
| Unused SE slot | `seDecimals[i] = 0` is fine (ignored). |

### `calcSalt` encode lists (append decimals, do not drop existing members)

- **CP:** current list plus `pairTokenDecimals`, `rawTokenDecimals`.
- **Weighted:** current list plus `tokenDecimals`, `seDecimals`.
- **Orbital:** current list plus `decimals0`, `decimals1`, `decimals2`.
- **Quads:** current list plus `tokenDecimals`, `seDecimals`.

### LP strings (HDEC-9)

| Package | `name` | `symbol` |
|---------|--------|----------|
| CP | `SE Buffer CP Hook LP` | `SSEBCP-LP` |
| Weighted | keep `SE Weighted Buffer Hook LP` | keep `SEWGT-LP` |
| Orbital | `SE Orbital Buffer Hook LP` | `SEORB-LP` |
| Curve quad | keep existing fixed strings if already fixed; else `SE Quad Buffer Hook LP` / `SEQUAD-LP` |
| Balancer quad | keep existing fixed strings if already fixed; else `SE Balancer Quad Buffer Hook LP` / `SEBQ-LP` |

### Self-leg check (no token call)

```text
CP:        rawTokenDecimals == 18
Weighted:  for i in [0,n): if standardExchanges[i]==0 then tokenDecimals[i]==18
Orbital:   if se0==0 then decimals0==18; same for 1,2. Exactly one self-leg already required.
Quad:      same as weighted over i in [0,4)
```

Used pair/token decimals and used `seDecimals` (SE != 0): `6 <= d && d <= 18`.

---

## Work order

Do stages in order. Each stage is independently testable. Do not start stage N+1 until that family’s compile + listed tests are green (or blocked only by the known cold compile).

FactoryService `deployHook` / `findMineNonce` take `PkgArgs memory`; they do not construct structs. No FactoryService signature change. Every **call site** that writes a `PkgArgs({...})` literal must add the new fields or Solidity will not compile.

### Step 1: CP SE buffer hook package

- **Files:**
  - Modify: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol`
  - Modify: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol`
  - Modify: every `PkgArgs({` in this family TestBase and specs under `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/`
  - Modify: `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookPremineLib.sol` (`premineCp` struct)
- **Do:**
  1. Add `InvalidDecimals` and the two `uint8` fields in the ABI order above.
  2. `_validateArgs`: keep address/same-token checks; add range + `rawTokenDecimals == 18`.
  3. `calcSalt`: encode the two uint8s.
  4. `initAccount`: delete `IERC20Metadata(c0).decimals()` / `c1.decimals()` and `_safeSymbol`. Map: if `c0 == a.pairToken` then `d0 = pairTokenDecimals` else `d0 = rawTokenDecimals` (same for `d1`). Pass `d0`,`d1` into `Repo._initializeBindings` as today.
  5. LP strings per table. Delete `_safeSymbol`.
  6. Remove `IERC20Metadata` import if unused.
- **Tests (new, this family TestBase, no DETF etch):**
  - `test_initAccount_emptyRawToken_usesPkgArgsDecimals` — `rawToken` is `address(uint160(uint256(keccak256("empty-detf"))))` with `code.length == 0`; `rawTokenDecimals = 18`; pair is a live mintable; `deployHook` succeeds; stored currency decimals match args.
  - `test_processArgs_rawTokenDecimalsNot18_reverts` — `expectRevert InvalidDecimals`.
  - `test_processArgs_pairTokenDecimalsOutOfRange_reverts` — `0` and `19`.
  - `test_calcSalt_differsWhenPairDecimalsDiffer` — identical args except `pairTokenDecimals` 6 vs 18.
- **Also:** fix every existing `PkgArgs({` in CP hook tests: `pairTokenDecimals: uint8(IERC20Metadata(pair).decimals())`, `rawTokenDecimals: 18` (when raw is predicted/empty) or live token decimals when both tokens exist (standalone hook tests).
- **Done when:** `forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/*.t.sol'` (default profile) green. DFPkg has no `IERC20Metadata` / `_safeSymbol` / `_readDecimals`.

### Step 2: Weighted SE buffer hook package

- **Files:**
  - Modify: `.../weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol`
  - Modify: `.../weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol`
  - Modify: `PkgArgs({` sites under `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/` and DETF weighted TestBases (struct literals).
- **Do:**
  1. Add `tokenDecimals` and `seDecimals` arrays in ABI order.
  2. `_validateArgs`: `tokenDecimals.length == n`, `seDecimals.length == n` else `ArrayLengthMismatch`. Loop: token decimals in `[6,18]`; if `standardExchanges[i]==0` then `tokenDecimals[i]==18`; else `seDecimals[i]` in `[6,18]`. Keep existing SE/token/weight checks (those may still `view` `vaultTokens()` on **live** SEs; that is not ERC-20 `decimals()`; leave it).
  3. `calcSalt`: encode both arrays.
  4. `_initProductBindings`: `pd = a.tokenDecimals[i]`; if SE==0, `invDecimals = pd`; else `sd = a.seDecimals[i]`. Delete `_readDecimals` and unused `_safeSymbol` if still present.
- **Tests:** empty self-leg deploy; length mismatch; self-leg not 18; salt changes when `tokenDecimals` change.
- **Done when:** weighted hook spec path green. No `_readDecimals` in this DFPkg.

### Step 3: Orbital SE buffer hook package

- **Files:**
  - Modify: `.../orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol`
  - Modify: `.../orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol`
  - Modify: orbital hook TestBases + DETF orbital TestBase `PkgArgs({` literals.
- **Do:** Add `decimals0/1/2`. Validate range + self-leg 18 via `seN == 0`. `calcSalt` includes them. `_initProductBindings` assigns `b.decimalsN = a.decimalsN`. Delete `_readDecimals` and `_safeSymbol`. Fixed LP strings.
- **Tests:** empty self-leg; `decimals` of the self-leg index not 18 reverts; salt differs.
- **Done when:** orbital SE buffer hook specs green.

### Step 4: Curve quad SE buffer hook package

- **Files:**
  - Modify: `.../stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol`
  - Modify: `.../stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol`
  - Modify: curve-quad hook TestBases + DETF quad TestBase literals (`ProtocolDetfInstanceLib._quadHArgs` included in Step 7 if not reached here).
- **Do:** `uint8[4] tokenDecimals` and `seDecimals`. Same validation as weighted over 4 slots. Replace `_readDecimals` uses. Salt includes both arrays. Fixed LP strings if symbols are still concatenated.
- **Tests:** empty self-leg; invalid decimals; salt.
- **Done when:** curve quad SE buffer hook specs green.

### Step 5: Balancer quad SE buffer hook package

- **Files:** same pattern under `.../stable/quad/balancer/`.
- **Do:** Identical field layout and rules as Step 4 on the balancer interface/DFPkg.
- **Tests:** same shape.
- **Done when:** balancer quad SE buffer hook specs green. Dual and non-SE hooks untouched.

### Step 6: DETF TestBases drop predicted-DETF etch

- **Files (modify all `vm.etch(predicted_` DETF-create helpers):**
  - `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol` (`_deployHookThenDetf`)
  - Sibling TestBases in that directory that copy the etch (`*_Weighted.sol`, `*_Orbital.sol`, `*_Quad.sol`, `*_Policy.sol`, `*_Decimals.sol`, `*_Adversarial.sol`, `*_ProdSe.sol`, pons/mix variants)
  - `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTablesGoldBase.sol`
  - `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_IoTablesGoldBase_Decimals.sol`
  - `contracts/test/bases/TestBase_UniswapV4Detf_PonsV2Se.sol`
- **Do:**
  1. Delete `vm.etch(predicted_, ...)` and the matching `vm.etch(predicted_, "")`.
  2. Fill new hook `PkgArgs` fields: pair/token decimals from **live** pair ERC-20s; self-leg `18`; `seDecimals` from live SE `decimals()` in the **test**.
  3. Keep `deployPair` + `finalizeInitialization` **before** DETF `deployVault` (HDEC-1). Empty DETF account during `deployPair` is required to be legal (PoolManager + `beforeInitialize` do not need ERC-20 code).
- **Do not:** etch Permit2 or other unrelated `vm.etch` (leave those).
- **Tests:** existing DETF deploy specs (`UniswapV4Detf_Deploy.t.sol` and family deploy tests) must pass without etch.
- **Done when:** `rg 'vm.etch\(predicted' contracts/vaults/detf/protocols/dexes/uniswap/v4 test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4 contracts/test/bases` reports none.

### Step 7: Foundry instance scripts

- **Files:**
  - `scripts/foundry/anvil_robinhood_testnet/ProtocolDetfInstanceLib.sol`
  - `scripts/foundry/anvil_robinhood_fee_detf/Script_09_DeployChirInstance.s.sol`
  - Any other `PkgArgs({` / `rawToken: predicted` under `scripts/foundry/`
- **Do:** Add decimal fields. Remove predicted-DETF `vm.etch`. Self-leg 18. Pair/SE from `IERC20Metadata` in the **script** (the pair exists; the DETF does not).
- **Done when:** those files compile; no predicted-DETF etch. Do **not** broadcast.

### Step 8: DTF create wizard encode (no seed)

- **Files:**
  - `frontend/apps/dtf/app/create/lib/detfAbi.ts` — `CP_HOOK_ARGS_COMPONENTS`, `WEIGHTED_HOOK_ARGS_COMPONENTS`, `QUAD_HOOK_ARGS_COMPONENTS`
  - `frontend/apps/dtf/app/create/lib/detfDeploy.ts` — types `CpHookPkgArgs`, `WeightedHookPkgArgs`, `QuadHookPkgArgs`; `buildCpHookArgs` / `buildWeightedHookArgs` / `buildQuadHookArgs`
  - `frontend/apps/dtf/app/create/lib/detfDeploy.test.ts`
  - `frontend/apps/dtf/app/create/DetfDeployPanel.tsx` — remove `seedPredicted` / `clearPredicted` / `seedAccountCode`
- **Do:**
  1. ABI components match Solidity field order exactly (`uint8` / `uint8[]` / `uint8[4]`).
  2. `buildCpHookArgs` takes `pairTokenDecimals: number` and sets `rawTokenDecimals: 18`.
  3. Weighted: `tokenDecimals` aligned to sorted hook tokens (18 at DETF index; pair decimals for pair indices); `seDecimals` 0 on DETF index, SE share decimals on pair indices.
  4. Quad: same mapping over 4 sorted tokens.
  5. `DetfDeployPanel` / `premineHook` path: before encode, `publicClient.readContract` `decimals()` on each **live** pair token and each SE vault. Never on the predicted DETF.
  6. Delete the seed/clear try/finally. If hook deploy fails, do not write code at the predicted address.
- **Tests:** vitest `detfDeploy.test.ts` asserts encoded tuples include the new fields; `rawTokenDecimals === 18`.
- **Done when:** `cd frontend/apps/dtf && npx vitest run app/create/lib/detfDeploy.test.ts`. No `seedAccountCode` import from `DetfDeployPanel`.

### Step 9: Docs touch-up (this change only)

- **Files:**
  - This plan: tick stages as done in the PR if you use checkboxes below.
  - Optional one-line in `contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md` §16.1: hook init does not read ERC-20; decimals from hook `PkgArgs`. Do not change hook-first order.
  - `scripts/foundry/anvil_robinhood_main/DEPLOY_UNIFIED_DETF_PACKAGES.md`: delete or fix the stale line that the wizard still looks up `cpDetfPkg` / `weightedDetfPkg` / `curveQuadDetfPkg` if you touch that file. Wizard already uses `uniV4DetfPkg`.
- **Done when:** §16.1 still says hook DFPkg first; decimals note present.

### Step 10: Verification (mandatory before claiming done)

Commands (default Foundry profile, no `via_ir`). Cold compile may take 20–40+ minutes. Wait for exit.

```bash
# Hook packages (after each of steps 1–5, and again at the end)
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/*.t.sol'
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/*.t.sol'
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/*.t.sol'
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/*.t.sol'
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/*.t.sol'

# Unified DETF create without etch
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol'
forge test --match-contract UniswapV4Detf_Deploy

# Source guards
rg -n 'IERC20Metadata' contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol
rg -n '_readDecimals|_safeSymbol' contracts/hooks/uniswap/v4/standardExchange --glob '*DFPkg.sol'
rg -n 'vm.etch\(predicted' contracts/vaults/detf/protocols/dexes/uniswap/v4 test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4
rg -n 'seedAccountCode' frontend/apps/dtf/app/create

cd frontend/apps/dtf && npx vitest run app/create/lib/detfDeploy.test.ts
```

Expected: listed `forge test` exit 0; `rg IERC20Metadata` on CP DFPkg empty; `_readDecimals` / `_safeSymbol` gone from in-scope SE buffer DFPkgs (Dual may still have them; do not “fix” Dual); predicted-DETF etch empty; `DetfDeployPanel` does not seed.

---

## Acceptance criteria

- [ ] CP `PkgArgs` has `pairTokenDecimals` and `rawTokenDecimals` in the locked ABI order; `rawTokenDecimals` must be 18.
- [ ] Weighted `PkgArgs` has `tokenDecimals` and `seDecimals` arrays length `n`.
- [ ] Orbital `PkgArgs` has `decimals0/1/2`; no `seDecimals`.
- [ ] Curve quad and balancer quad have `tokenDecimals` and `seDecimals` as `uint8[4]`.
- [ ] Every in-scope `calcSalt` hashes the new fields.
- [ ] In-scope DFPkg `initAccount` / `processArgs` do not call ERC-20 metadata. No `try`.
- [ ] Self-leg decimal ≠ 18 reverts `InvalidDecimals`.
- [ ] Used decimals outside `[6,18]` revert `InvalidDecimals`.
- [ ] Hook deploys when the DETF self-leg account has empty code.
- [ ] DETF TestBases and instance scripts no longer `vm.etch` the predicted DETF.
- [ ] Wizard encodes the new fields, passes 18 for the DETF leg, reads pair/SE decimals via RPC, and does not `anvil_setCode`.
- [ ] Deploy order still hook-then-DETF. DETF `calcSalt` still zeros `hook`.
- [ ] Dual SE CP and non-SE swap hooks are unchanged.
- [ ] No `via_ir`. No SUT mocks.

---

## Do not

- Do not reverse DETF/hook order or remove `hook` from DETF `PkgArgs`.
- Do not put hook address into DETF salt.
- Do not call `decimals()` on-chain to “verify” `PkgArgs` at create.
- Do not use `try`/`catch` as a substitute for `PkgArgs` decimals.
- Do not etch the predicted DETF “so tests look like before.”
- Do not change Dual / legacy single / non-SE swap hooks in this plan.
- Do not `forge script --broadcast` or start Anvil for UI.
- Do not bump hook DFPkg CREATE3 salts in this PR unless a TestBase deploy salt is already parameterized; hermetic tests deploy packages in `setUp`. Live 4663 package replace is a later launch-script PRD (ABI break: old instances keep old packages).

---

## Call-site inventory (must compile)

Grep after each family step:

```bash
rg -n 'PkgArgs\(\{' contracts/hooks/uniswap/v4/standardExchange \
  contracts/vaults/detf/protocols/dexes/uniswap/v4 \
  test/foundry/spec/hooks/uniswap/v4/standardExchange \
  test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4 \
  scripts/foundry
```

Every hit for in-scope types must include the new fields. `UniswapV4DetfHookPremineLib.premineCp` is easy to miss.

---

## Package redeploy note (not this PR)

`PkgArgs` ABI and instance `calcSalt` change. Hermetic TestBases deploy the new DFPkg in `setUp`. Public 4663/46630 hook **package** addresses stay the old bytecode until a launch Stage FORCE-deploys a new CREATE3 salt. Do not mix a new wizard ABI with an old hook package on a live RPC. Document that in the launch PRD when those Stages run; do not broadcast from this plan.
