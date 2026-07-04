# IndexedEx / Pachira UI — Full Functionality Test Plan

**Status:** Ready to execute  
**Audience:** Agents + humans  
**Environment baseline:** Local Anvil via `scripts/shell/local_testing.sh` with **foundation + packages + assets + scenario1 + scenario2 + scenario3** deployed; UI pointed at chain id **11155111**, RPC **http://127.0.0.1:8545**.  
**Wallet under test:** Injected EIP-1193 (Playwright fixture), **not** MetaMask extension — same as production path for wagmi `injected`.

---

## 1. Goals

| # | Goal | Pass criterion |
|---|------|----------------|
| G1 | **All Standard Exchange route shapes** work on **Swap** | Each route in §4: preview OK + exact-in tx mines (or documented intentional skip) |
| G2 | **Same route shapes** work on **Batch Swap** where multi-step encoding applies | Each applicable route in §5: path builds, preview OK, batch tx mines |
| G3 | **Vault discovery** works (tokenlist + registry) | Earn preferred list non-empty; registry query by token returns ≥1 vault when registered |
| G4 | **Earn → deposit/withdraw** works for strategy vaults | Deposit panel uses correct router args; balances move |
| G5 | **DETF workspace** (scenario3) mint/bond paths reachable | UI loads DETF, mint/bond controls functional or clear preconditions |
| G6 | **Shell / brand / portfolio** | Connect, nav, redirects, portfolio reads non-error |

Non-goals for this plan:

- MetaMask popup UX  
- Public mainnet / funded live wallets  
- Exhaustive fork RPC stress  
- Visual pixel regression (unless added later)

---

## 2. Preconditions (do once per session)

### 2.1 Chain & deploy

```bash
# From indexedex repo root — if not already done
export DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
bash scripts/shell/local_testing.sh foundation --restart-anvil
bash scripts/shell/local_testing.sh packages
bash scripts/shell/local_testing.sh assets
bash scripts/shell/local_testing.sh scenario1
bash scripts/shell/local_testing.sh scenario2
bash scripts/shell/local_testing.sh scenario3
```

Confirm artifacts:

| Check | Path / command |
|-------|----------------|
| Stage JSON present | `ls deployments/local_testing/anvil_single/[0-9]*.json` — expect `01`…`06`, `10`–`12` as deployed |
| Platform for UI | `frontend/app/addresses/chain/11155111/platform.json` has `vaultRegistry`, `balancerV3StandardExchangeRouter`, `weth`/`weth9`, `permit2` |
| Tokenlists | `strategy-vaults`, `balancer-v3-pools`, `base-tokens`, `protocol-detfs` under `chain/11155111/` non-empty |

### 2.2 UI process

```bash
cd frontend
npm run dev
# or: npm run build && npm run start
```

| Check | Pass |
|-------|:----:|
| App loads `http://127.0.0.1:3000` no redbox | ☐ |
| Header **App Network** = Ethereum Sepolia (11155111) | ☐ |
| Anvil RPC reachable from app (local env maps sepolia → 8545) | ☐ |

### 2.3 Wallet (automation)

| Check | Pass |
|-------|:----:|
| `npm run test:e2e` green (baseline inject + connect) | ☐ |
| Optional: import Anvil #0 in browser for manual cross-check | ☐ |

Account under test (Anvil #0):

- Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`  
- Funded by Anvil; mint test tokens via `/mint` if scenarios use TTA/TTB/etc.

### 2.4 Session metadata (fill when running)

```text
Date:
Branch / commit:
Scenarios: foundation + packages + assets + s1 + s2 + s3
Anvil chainId: 11155111
UI URL:
Brand under test: Pachira / IndexedEx / both
```

---

## 3. Inventory: routes the UI must support

Canonical router matrix (from `MANUAL_UI_ROUTE_CHECKLIST.md` + `routeMatcher.ts`):

| Route name | Pool | tokenIn | tokenInVault | tokenOut | tokenOutVault |
|------------|------|---------|--------------|----------|---------------|
| **Direct Balancer Swap** | B3 pool | sell | 0 | buy | 0 |
| **Vault Pass-Through** | vault | sell | vault | buy | vault |
| **Strategy Vault Deposit** | vault | deposit asset | vault | vault shares | 0 |
| **Strategy Vault Withdrawal** | vault | vault shares | 0 | withdraw asset | vault |
| **Vault Deposit + Balancer Swap** | B3 pool | deposit asset | deposit vault | buy | 0 |
| **Balancer Swap + Vault Withdrawal** | B3 pool | sell | 0 | withdraw asset | withdraw vault |
| **Vault Deposit + Swap + Vault Withdrawal** | B3 pool | deposit asset | deposit vault | withdraw asset | withdraw vault |
| **WETH Wrap / Unwrap** | WETH sentinel | ETH↔WETH | 0 | … | 0 |

**Source of truth for classification:** `app/swap/lib/routeMatcher.ts` (unit-tested).  
**Source of truth for UI execution:** Swap page + Batch Swap page + Standard Exchange Router.

Also cover **app routes** (page loads + primary CTA):

| Path | Role |
|------|------|
| `/` | Landing / conversion |
| `/earn` | Preferred tokenlist + registry search |
| `/earn/[address]` | Detail + deposit panel |
| `/swap` | Single-hop / SE routes |
| `/batch-swap` | Multi-step paths |
| `/portfolio` | Balances + bond NFTs |
| `/token` | Token handoff |
| `/staking` | DETF workspace (scenario3) |
| `/mint` | Test token mint |
| `/vaults`, `/detf`, `/detfs` | Redirects → Earn |
| `/create`, `/insights`, `/token-info` | Power (smoke load only unless time) |

---

## 4. Swap (`/swap`) — full route matrix

### 4.1 Shared Swap setup (each case)

1. Connect injected/manual Anvil wallet.  
2. Ensure token balances: mint via `/mint` if needed; wrap ETH if needed.  
3. Explicit approval mode first (easier to debug); re-run one signed-mode case later.  
4. Record: pool label, tokenIn, tokenOut, route label shown in UI/debug, preview amount, tx hash.

### 4.2 Case table

| ID | Route | How to select in UI | Assert preview | Assert execute | Pass |
|----|-------|---------------------|----------------|----------------|:----:|
| S-BAL | Direct Balancer | Pool = Balancer V3 pool; tokenIn/out = pool underlyings | amountOut > 0 | tx success; balances move | ☐ |
| S-VPT | Vault Pass-Through | Pool = strategy vault; both sides underlying of that vault | amountOut > 0 | tx success | ☐ |
| S-DEP | Strategy Vault Deposit | Pool = vault; tokenIn = underlying; tokenOut = vault share | shares preview > 0 | shares balance ↑ | ☐ |
| S-WD | Strategy Vault Withdrawal | Pool = vault; tokenIn = vault share; tokenOut = underlying | amountOut > 0 | underlying ↑ | ☐ |
| S-VD-BAL | Vault Deposit → Balancer | Pool = B3; tokenIn vault-wrapped underlying; tokenOut direct pool token | preview OK | tx success | ☐ |
| S-BAL-VW | Balancer → Vault Withdraw | Pool = B3; tokenIn direct; tokenOut underlying of vault wrapping a pool token | preview OK | tx success | ☐ |
| S-VD-BAL-VW | Deposit → Swap → Withdraw | Pool = B3; both sides wrapped via vaults | preview OK | tx success | ☐ |
| S-WRAP | ETH → WETH | Pool = Wrap/Unwrap sentinel | 1:1-ish | WETH ↑ | ☐ |
| S-UNWRAP | WETH → ETH | same | 1:1-ish | ETH ↑ | ☐ |
| S-INV | Invalid combination | e.g. vault share → same vault share | UI shows invalid / no ready | no tx | ☐ |

### 4.3 Exact-out (subset)

| ID | Case | Pass |
|----|------|:----:|
| S-EO-BAL | Exact-out direct Balancer | ☐ |
| S-EO-DEP | Exact-out vault deposit if UI supports | ☐ |

### 4.4 Automation notes (Swap)

| Layer | What to automate first |
|-------|------------------------|
| Unit | Already: `routeMatcher.test.ts` — keep green |
| E2E inject | After connect: open `/swap`, assert pool/token options non-empty from tokenlists |
| E2E tx | Drive selectors via `data-testid` (add if missing), click preview + swap, wait receipt via RPC |

**Gap to close before full auto:** ensure Swap/Batch controls have stable `data-testid`s for pool, tokenIn, tokenOut, amount, preview, submit.

---

## 5. Batch Swap (`/batch-swap`) — route parity

Batch Swap encodes **paths of steps**. Goal: every SE route shape that can be expressed as one or more steps is executable.

### 5.1 Mapping: single-route → batch path

| ID | Intent | Path sketch | Pass |
|----|--------|-------------|:----:|
| B-BAL | Single-step Balancer | 1 step: pool=B3, tokenIn→tokenOut | ☐ |
| B-VPT | Vault pass-through | 1 step: pool=vault, underlying→underlying | ☐ |
| B-DEP | Vault deposit | 1 step: underlying→vault shares | ☐ |
| B-WD | Vault withdraw | 1 step: vault shares→underlying | ☐ |
| B-MULTI | Two-step: deposit then Balancer | step1 vault dep; step2 B3 swap | ☐ |
| B-MULTI2 | Balancer then withdraw | step1 B3; step2 vault wd | ☐ |
| B-WRAP | ETH boundary handling | path respects WETH sentinel stripping rules | ☐ |
| B-INV | Malformed path | preview/submit disabled or reverts cleanly in UI | ☐ |

### 5.2 Batch-specific asserts

| Check | Pass |
|-------|:----:|
| Path builder adds/removes steps without crash | ☐ |
| Preview uses batch router / documented preview path | ☐ |
| Submit mines; intermediate dust acceptable | ☐ |
| Error surface readable (not only console) | ☐ |

### 5.3 Parity rule

For each **S-*** case that is single-hop, there should be a matching **B-*** single-step path with the **same** pool/tokenIn/tokenOut semantics. Multi-hop S-VD-BAL / S-BAL-VW / S-VD-BAL-VW map to multi-step batch paths.

---

## 6. Vault query & Earn

### 6.1 Preferred list (tokenlist — no search)

| Check | Pass |
|-------|:----:|
| `/earn` shows ≥1 strategy vault after s1/s2 | ☐ |
| Protocol DETF appears after s3 (filter or type chip) | ☐ |
| Featured / filters by type work | ☐ |
| Row → `/earn/[address]` works | ☐ |

### 6.2 Registry query (user entry)

Use platform `vaultRegistry` (manager diamond).

| ID | Input | Expected registry call | Pass |
|----|-------|------------------------|:----:|
| R-TOK | Token address from `base-tokens` / vault underlying | `vaultsOfToken` → length ≥ 1 if vault registered with that token | ☐ |
| R-SYM | Known symbol (e.g. WETH / TTA) | Resolves to address then `vaultsOfToken` | ☐ |
| R-VAULT | Paste vault address | `isVault` true; row includes vault | ☐ |
| R-EMPTY | Clear search | Back to preferred tokenlist | ☐ |
| R-NONE | Random address | Empty registry results, no crash | ☐ |

Automation:

- Unit: `pickRegistryQuery.test.ts`, `loadEarnProducts` (already)  
- E2E: inject wallet → `/earn` → fill search → assert “Registry” badge / row count  
- Optional RPC assert: `cast call` `vaultsOfToken` matches UI count

### 6.3 Earn detail + deposit

| ID | Check | Pass |
|----|-------|:----:|
| E-COMP | Composition tab reads tokens/reserves (strategy) | ☐ |
| E-DEP | Deposit via panel (underlying → shares) | ☐ |
| E-WD | Withdraw via panel | ☐ |
| E-ARGS | Deposit uses `buildStrategyVaultDepositArgs` semantics (tokenInVault=vault) | ☐ (unit + one live) |
| E-PORT | After deposit, Portfolio or detail balance updates | ☐ |

### 6.4 DETF (scenario3)

| ID | Check | Pass |
|----|-------|:----:|
| D-LIST | DETF in Earn or staking selector | ☐ |
| D-WS | `/staking` workspace loads with CHIR/protocol DETF | ☐ |
| D-MINT | Mint CHIR path (or clear “minting not allowed”) | ☐ |
| D-BOND | Bond section present / smoke | ☐ |

---

## 7. Shell, redirects, brand

| ID | Check | Pass |
|----|-------|:----:|
| N-NAV | Earn · Swap · Portfolio · Token visible | ☐ |
| N-MORE | Batch Swap under More | ☐ |
| N-RED-V | `/vaults` → Earn strategy | ☐ |
| N-RED-D | `/detf` `/detfs` → Earn detf | ☐ |
| N-CONN | Connect shows Anvil address prefix | ☐ |
| N-BRAND | Toggle Pachira ↔ IndexedEx (if unlocked) changes name + theme | ☐ |
| N-HOME | Landing CTAs to Earn / Token | ☐ |

---

## 8. Execution layers (what to run when)

```text
L0  Preconditions (§2)                         human / shell
L1  Unit: vitest                               CI always
L2  E2E inject: connect + shell + earn load    CI / agent always
L3  E2E inject: registry search by fixture addr  after deploy
L4  E2E inject: swap route matrix (tx)         after deploy + testids
L5  E2E inject: batch parity                   after L4
L6  Manual checklist for residual edge cases   human
```

### 8.1 Commands

```bash
# L1
cd frontend && npm test

# L2 (needs build or running server)
npm run build && npm run test:e2e

# L3–L5 — add specs under e2e/ as implemented:
#   e2e/earn-registry.spec.ts
#   e2e/swap-routes.spec.ts
#   e2e/batch-swap-routes.spec.ts
E2E_SKIP_WEBSERVER=1 npm run test:e2e -- e2e/earn-registry.spec.ts
```

### 8.2 Implementation backlog (for agents)

Priority order to make L3–L5 reliable:

1. Add `data-testid` on Swap/Batch: `pool-select`, `token-in`, `token-out`, `amount-in`, `preview`, `submit-swap`, batch step controls.  
2. Helper `e2e/helpers/tokenlist.ts` — read addresses from `chain/11155111/*.tokenlist.json` (no hardcoding).  
3. Helper `e2e/helpers/rpc.ts` — `eth_getBalance`, wait for receipt.  
4. Specs that pick first strategy vault + first balancer pool from lists and run S-DEP / S-BAL / B-BAL.  
5. Expand matrix until §4–§5 checkboxes are automation-owned.

---

## 9. Pass / fail recording template

```markdown
### Session YYYY-MM-DD

| Suite | Result | Notes |
|-------|--------|-------|
| L1 vitest | PASS/FAIL | |
| L2 e2e baseline | PASS/FAIL | |
| Swap matrix S-* | x/y | failed: … |
| Batch matrix B-* | x/y | |
| Registry R-* | x/y | |
| Earn deposit E-* | x/y | |
| DETF D-* | x/y | |

Blockers:
-
```

---

## 10. Definition of done (full UI functionality for local scenarios)

All of the following:

1. **L1 + L2** green on CI/agent.  
2. **Every S-*** case §4.2** executed once (auto or manual) with PASS on local scenarios.  
3. **Every B-*** case §5.1** executed once with PASS (or explicitly N/A with reason).  
4. **R-TOK, R-EMPTY, E-DEP** PASS with real registry + one strategy vault.  
5. **N-*** shell checks PASS.  
6. Session notes committed or saved under agent scratch / this file’s session section.

---

## 11. Risk notes

| Risk | Mitigation |
|------|------------|
| Scenario deploy incomplete | Fail preconditions; don’t mark routes N/A as pass |
| Permit2 / approval stuck | Reset allowance; use explicit approval mode |
| Route labeled wrong in UI | Compare to `routeMatcher` + debug panel (lab flag) |
| Batch preview vs execute diverge | Prefer execute path; file bug if preview lies |
| Tokenlist stale after redeploy | Re-run aggregator / scenario shell hook |

---

## 12. Related files

| File | Use |
|------|-----|
| `MANUAL_UI_ROUTE_CHECKLIST.md` | Legacy detailed swap checklist (still valid for manual depth) |
| `e2e/README.md` | Injected wallet harness |
| `e2e/connected-wallet.spec.ts` | L2 baseline |
| `app/swap/lib/routeMatcher.ts` | Route classification |
| `app/lib/registry/*` | Earn registry query |
| `app/lib/earn/buildVaultSwapArgs.ts` | Earn deposit/withdraw args |
| `scripts/shell/local_testing.sh` | Deploy scenarios |

---

**Next step after approving this plan:** implement L3 registry E2E + Swap `data-testid`s, then automate S-BAL + S-DEP as the first live tx proofs against your three scenarios.

---

## Session log: 2026-07-11

### Environment notes

- Anvil **up** at `http://127.0.0.1:8545`, chainId **11155111**.
- Stage JSON present: foundation `01–06` + **scenario3** (`12`). **No `10`/`11` (scenario1/2)** in `deployments/local_testing/anvil_single/` — only scenario3 overlay artifact on disk.
- Live registry `vaults()` returned **4** addresses; `isVault` true; `vaultsOfToken(WETH)` returned strategy vault + BPT pool.
- **Stale tokenlists** initially pointed at addresses with **no code**. Fixed by rebuilding from fragments (run from **repo root**):
  ```bash
  node scripts/node/node_modules/tsx/dist/cli.mjs scripts/node/src/main.ts --config tokenlists.config.ts
  ```
  After rebuild: 1 strategy vault (`wethRichVlt`), 1 protocol DETF (`CHIR`), 6 base tokens, 2 balancer pools — addresses match live chain.

### Automated results

| Layer | Result |
|-------|--------|
| L1 vitest | **57 passed** |
| L2–L3 Playwright (`CI=1 npm run test:e2e`) | **17 passed** (connected wallet, Earn preferred + registry WETH search, DETF listed, earn detail, redirects, Swap/Batch surfaces) |
| Clean `npm run build` | **OK** (after excluding `e2e/` from `tsconfig` for Next typecheck) |

### Specs added this session

- `e2e/earn-registry.spec.ts`
- `e2e/swap-surface.spec.ts`
- `e2e/shell-routes.spec.ts`
- `e2e/helpers/chainArtifacts.ts`

### Session update (testids + live S-*/E-DEP)

**Root cause of earlier S-* e2e failures:** live `/swap` is implemented in `app/swap/page.tsx` (not the extracted `SwapForm.tsx`). Testids were only on `SwapForm` and never appeared in the real DOM. Testids are now on the live page.

| Route | Status |
|-------|--------|
| **S-DEP** (WETH → vault shares via Swap) | **PASS** live tx (`e2e/swap-routes-live.spec.ts`) |
| **S-VPT** (WETH → RICH pass-through) | **PASS** live tx |
| **E-DEP** (Earn deposit panel) | **PASS** live tx |
| **S-BAL** (WETH → CHIR Direct Balancer) | **Soft-pass** UI + route + quote error. Pool is registered but **not initialized** (`PoolNotInitialized` / `0x4bdace13`); CHIR `totalSupply` is 0. Full tx needs a seed stage (`balancerV3Router.initialize` after minting CHIR). |
| **B-BAL** | **PASS** surface (pool + CHIR selectable via testids); execute not asserted |
| Testids on Swap / Batch / Earn deposit | **Done** |
| Protocol DETFs in `token-select` menu | **Done** (CHIR selectable for Balancer legs) |

### Still open (manual / next automation — full S-*/B-* tx matrix)

| Area | Status |
|------|--------|
| S-BAL full live tx | Needs scenario liquidity seed (init WETH/CHIR pool + mint CHIR) |
| S-WD / combo SE routes | Not automated yet |
| Batch route **execute** txs (B-*) | Surface only; execute needs approvals + pool liquidity |
| DETF mint/bond D-MINT/D-BOND | Workspace loads; CHIR listed; mint flow not automated |

### Blockers / follow-ups

1. After each local redeploy, **rebuild tokenlists from repo root** or Earn/Swap show dead addresses.  
2. Deploy **scenario1/2** stage JSON if you need UniV2 AB vaults in the preferred list (currently only scenario3 vault fragment).  
3. **Scenario3 gap:** Balancer pools (`wethDetfBP`, `reserveBP`) are created but never `initialize()`d — add a local seed stage (mirror `Script_10` / `Script_13`) so S-BAL live swaps can complete.
