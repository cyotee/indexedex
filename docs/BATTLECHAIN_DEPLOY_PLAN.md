# BattleChain Testnet Deploy Plan (Review)

**Status:** Ready for operator review (2026-07-22; commands updated for **Crane CWD**)  
**Audience:** Launch promo of Crane + vendored DeFi ports on BattleChain **testnet**  
**Wallet:** Foundry cast account **`deployer`** (Sepolia ETH available)  

### Working directory (canonical for Crane deploys)

All forge/cast commands below assume:

```bash
cd daosys/lib/indexedex/lib/crane
# or: cd <path-to-crane-checkout>
```

Do **not** use IndexedEx-root paths like `scripts/foundry/battlechain/...` when your shell is in Crane — those files live under IndexedEx only as a mirror.

| Role | Path **from Crane root** |
|------|---------------------------|
| Bridge script | `scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol` |
| Wave A promo deploy | `scripts/foundry/Script_Promo_BC_Launch.s.sol` |
| ERC20Permit pilot | `scripts/foundry/Script_Pilot_BC_ERC20Permit.s.sol` |
| BC bootstrap | `contracts/InitBcService.sol` |
| Foundry config / RPC aliases | `foundry.toml` |
| Promo manifest (after deploy) | `script/output/battlechain_promo_manifest.json` |

Optional mirror under IndexedEx (not used for Crane ops):  
`../scripts/foundry/battlechain/Script_Bridge_SepoliaToBattleChain.s.sol` (relative to Crane = IndexedEx `scripts/foundry/battlechain/...`).

Related (IndexedEx docs tree):

- [`BATTLECHAIN_LAUNCH_PROMO.md`](./BATTLECHAIN_LAUNCH_PROMO.md) — marketing scope + announcement copy  
- [`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md) §1.4b  
- [`battlechain/promo_addresses.md`](./battlechain/promo_addresses.md) — fill after deploy  

---

## 1. Goals

| Goal | Success |
|------|---------|
| Fund **`deployer`** with ETH on BattleChain testnet (627) | Balance &gt; 0 after bridge |
| Deploy **Crane core** via BC-tracked Create3Factory | `InitBcService` + Safe Harbor root |
| Deploy **Wave A** | Crane-only gaps: Uni V2, Uni V4, Permit2, ERC20Permit; **use BC-provided WETH + Uni V3** |
| Open **attack mode** | Agreement adopted + request (testnet self-approve if needed) |
| Publish addresses for launch promo | Manifest + `promo_addresses.md` |

**Not goals:** Base CCA / mainnet RICH; Wave B (Aave, Balancer full stack, Aerodrome, IndexedEx product diamonds).

---

## 2. Network facts

| Item | Value |
|------|--------|
| BattleChain testnet chain id | **627** |
| Settlement L1 | **Ethereum Sepolia** (11155111) |
| L2 RPC alias (Foundry) | **`battlechain-sepolia`** → `https://testnet.battlechain.com` |
| L1 Bridgehub (Sepolia) | `0xcEa5C0ade89389Dd5FC461F69CCbD812cFb7fbd8` |
| BC Deployer (L2) | `0x0f75289c6b883b885A1fDF9BCCABE1bbFB094077` |
| Agreement factory (L2) | `0xf52CEA27b9E20D03Ec48CDe4fafF8F27565646f2` |
| Attack registry (L2) | `0x22134e878c409a0Eab7259d873b38e26Ca966d3C` |
| Mock registry moderator (testnet) | `0x3DdA228A38b4d7438bBF5D5137c8D1090DcaF6bF` |
| Portal bridge UI | https://portal.battlechain.com/bridge |
| Deployments JSON | https://docs.battlechain.com/deployments.json |

### Foundry RPC aliases (Crane `foundry.toml`)

```toml
"battlechain-sepolia" = "https://testnet.battlechain.com"
battlechain_testnet = "https://testnet.battlechain.com"   # legacy alias
sepolia_public = "https://ethereum-sepolia-rpc.publicnode.com"
```

(Same keys also exist in IndexedEx `foundry.toml` for product work; **Crane deploys use Crane’s config**.)

```bash
--rpc-url battlechain-sepolia   # L2 deploys
--rpc-url sepolia_public        # L1 bridge (or sepolia_alchemy / sepolia_infura)
```

---

## 3. Funding: Sepolia → BattleChain (Foundry, fully on-chain)

### Research conclusion

BattleChain testnet is a **ZK Stack** rollup that settles to Sepolia. L1→L2 ETH deposits are **entirely on-chain** via the Sepolia **Bridgehub**:

1. Quote L2 execution cost: `l2TransactionBaseCost(chainId=627, gasPrice, l2GasLimit, l2GasPerPubdata)`.  
2. Call `requestL2TransactionDirect{value: mintValue}(L2TransactionRequestDirect{...})` where:
   - `mintValue = baseCost(+pad) + l2Value`  
   - `l2Contract = recipient` (EOA)  
   - `l2Value = ETH to credit on L2`  
   - `l2Calldata = ""` (pure deposit)  
   - `refundRecipient = broadcaster` (unspent L2 gas budget)  

No portal is required for the deposit itself (UI remains an optional alternative). After the L1 tx is mined, the sequencer includes a **priority transaction** on chain 627 (often within ~1 minute).

**Verified on Sepolia:** Bridgehub has bytecode; `l2TransactionBaseCost(627, …)` returns non-zero.

### Implemented script (Crane)

| Path from Crane root | Role |
|----------------------|------|
| `scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol` | **Canonical** L1→L2 ETH deposit |

**Env knobs:**

| Env | Default | Meaning |
|-----|---------|---------|
| `L2_DEPOSIT_WEI` | `0.1 ether` | ETH credited on BattleChain |
| `L2_RECIPIENT` | broadcaster | L2 credit address |
| `L2_GAS_LIMIT` | `1_000_000` | L2 gas for priority tx |
| `L2_GAS_PER_PUBDATA` | `800` | Pubdata gas param |
| `BASE_COST_BPS_PAD` | `2000` (+20%) | Headroom if L1 gas price moves |
| `QUOTE_ONLY` | unset / `false` | If `true`, only quotes `mintValue` (no wallet / no broadcast) |

**Operator commands (from Crane root):**

```bash
cd daosys/lib/indexedex/lib/crane   # if not already there
export DEPLOYER=$(cast wallet address --account deployer)

# Quote-only dry run (no wallet needed)
QUOTE_ONLY=true L2_DEPOSIT_WEI=500000000000000000 forge script \
  scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol:Script_Bridge_SepoliaToBattleChain \
  --rpc-url sepolia_public -vv

# Broadcast deposit (pay Sepolia gas + mintValue)
# CRITICAL: always pass --sender $DEPLOYER and L2_RECIPIENT=$DEPLOYER.
# Without --sender, forge uses msg.sender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
# (Foundry default caller) as L2 credit address — funds on L2 are then unrecoverable.
L2_RECIPIENT=$DEPLOYER L2_DEPOSIT_WEI=500000000000000000 forge script \
  scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol:Script_Bridge_SepoliaToBattleChain \
  --rpc-url sepolia_public \
  --broadcast \
  --account deployer \
  --sender $DEPLOYER \
  -vv

# Wait, then confirm L2 gas
cast balance $DEPLOYER --rpc-url battlechain-sepolia
```

**Total Sepolia ETH spent ≈** `L2_DEPOSIT_WEI + padded baseCost + L1 gas`.  
Recommend depositing **≥ 0.5 ETH** to L2 for Wave A multi-contract deploy + agreement.

---

## 4. Deploy Wave A (Crane + ports)

### What gets deployed

```text
BattleChainDeployer.deployCreate2
        │
        ▼
  Create3Factory          ◄── Safe Harbor root (ChildContractScope.All)
        │
        ├── DiamondPackageCallBackFactory
        ├── ERC20 / ERC5267 / ERC2612 facets
        ├── ERC20PermitDFPkg + sample token (CBCP)  [not mainnet RICH]
        ├── Uni V2 Factory + Router02  (wired to BC WETH)
        ├── Uni V4 PoolManager
        └── BetterPermit2
        │
        └── createAndAdoptAgreement → requestAttackMode

  Policy: use BC-provided, do not replace
  WETH              = 0x4CAc28Fc96bb8fa0e6F94ef0E579384902142f42
  Uni V3 Factory    = 0xd5DCFCab1B60C70F45D61597b351674b4b3C8CDc
  Uni V3 SwapRouter = 0x4FC93149e329C15BfF627E967aaA487079D89d2F
  Uni V3 NPM        = 0x43d314e63223041C61460c9A2F5e597Ff7D1cd30
```

Script (from Crane root): `scripts/foundry/Script_Promo_BC_Launch.s.sol`

### Pre-flight checklist

1. [ ] Crane build/tests green (assumed fixed).  
2. [ ] Security contact in `scripts/foundry/Script_Promo_BC_Launch.s.sol` `_contacts()` is **not** `REPLACE_BEFORE_BROADCAST@example.com`.  
3. [ ] `deployer` has **BattleChain** ETH (§3).  
4. [ ] Optional: `forge test --match-contract Pilot_BC_Promo_Launch_LocalMock_Test -vv`

### Broadcast (from Crane root)

```bash
cd daosys/lib/indexedex/lib/crane   # if not already there
export DEPLOYER=$(cast wallet address --account deployer)

forge script scripts/foundry/Script_Promo_BC_Launch.s.sol:Script_Promo_BC_Launch \
  --rpc-url battlechain-sepolia \
  --broadcast \
  --skip-simulation \
  --account deployer \
  --sender $DEPLOYER \
  -vv
```

**Required:** `--skip-simulation` on BattleChain forge broadcasts.

**Outputs (written by the script under Crane root):**

| Path | Role |
|------|------|
| Console dump | Human log during broadcast |
| `docs/deployment/addresses/battlechain-sepolia.json` | **Source of truth** for docs / agents |
| `docs/deployment/addresses/battlechain-sepolia.table.md` | mdBook include for [Deployed Addresses](../../lib/crane/docs/deployment/deployed-addresses.md) |
| `script/output/battlechain-sepolia/wave-a.latest.json` | Runtime copy of the same JSON |

**After you broadcast successfully:** tell the agent “Wave A BattleChain deploy complete.” They will read the JSON and confirm the Crane docs site Deployed Addresses section.

Optional: copy addresses into IndexedEx `docs/battlechain/promo_addresses.md` for product marketing.

### Attack mode (testnet)

Script calls `requestAttackMode` when `chainid == 627`. If approval is still pending, self-approve via MockRegistryModerator (see BattleChain docs / `battlechain-dev-workflow` skill):

```bash
# From Crane root; after agreement address is known from broadcast logs
cast send 0x3DdA228A38b4d7438bBF5D5137c8D1090DcaF6bF \
  "approveAttack(address)" $AGREEMENT \
  --rpc-url battlechain-sepolia \
  --account deployer \
  --sender $DEPLOYER
```

(Confirm exact selector against current docs if the skill’s `approveAttack` differs from registry `approveAttack`.)

---

## 5. Operator sequence (end-to-end)

All steps **from Crane root** unless noted.

```text
A. cd Crane; set security contact in scripts/foundry/Script_Promo_BC_Launch.s.sol
B. Bridge Sepolia ETH → BattleChain:
     scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol
     --rpc-url sepolia_public --account deployer
C. cast balance $DEPLOYER --rpc-url battlechain-sepolia
D. Broadcast Script_Promo_BC_Launch
     --rpc-url battlechain-sepolia --skip-simulation --account deployer
E. Fill IndexedEx docs/battlechain/promo_addresses.md from Crane script/output/...
F. Approve attack mode if needed
G. Announce (copy in BATTLECHAIN_LAUNCH_PROMO.md)
```

Parallel track (does not block BC promo): RICH ETH deploy → Superchain bridge → Base CCA (IndexedEx product path).

---

## 6. Wave B (later — not announcement-blocking)

| Item | Notes |
|------|--------|
| Aerodrome / Slipstream | Larger constructor graph |
| Balancer V3 Vault diamond | Own bootstrap |
| Aave V3/V4 / Euler | Multi-tx config |
| IndexedEx DualLiquidity (removed) | Product surface |
| Explorer verification batch | Post-stable addresses |

---

## 7. Messaging rules (unchanged)

- BattleChain = **security + open Crane/DeFi infra**, not the capital raise.  
- Sample BC permit token ≠ **RICH**.  
- RICH raise = **Base CCA** after ETH deploy + Superchain bridge.  
- Fee-make / `donation` = **roadmap VP** for RICH until live on product chain.

---

## 8. Risks

| Risk | Mitigation |
|------|------------|
| Wrong script path (IndexedEx vs Crane) | Always `cd` Crane; use `scripts/foundry/Script_*.s.sol` only |
| L2 credit to Foundry default sender `0x1804…1f38` | Always `--sender $DEPLOYER` and `L2_RECIPIENT=$DEPLOYER`; script now reverts if default sender is used |
| Bridge delay / under-quoted baseCost | +20% pad; increase `BASE_COST_BPS_PAD` or `L2_GAS_LIMIT` if tx reverts |
| L2 underfunded for full Wave A | Deposit ≥ 0.5 ETH; re-run bridge script |
| Wrong chain for bridge script | Script reverts unless `chainid == 11155111` |
| Wrong chain for promo deploy | Use `--rpc-url battlechain-sepolia` (627) |
| Security contact placeholder | Must replace before public attack-mode marketing |
| Dual WETH / dual Uni V3 | **Use BC-provided only**; never create3 a second WETH or Uni V3 |

---

## 9. Definition of done

- [x] RPC alias **`battlechain-sepolia`** in Crane (+ IndexedEx) `foundry.toml`  
- [x] On-chain Foundry **bridge script** at Crane `scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol`  
- [x] Wave A **promo deploy script** at Crane `scripts/foundry/Script_Promo_BC_Launch.s.sol`  
- [x] Plan commands use **Crane CWD** paths  
- [ ] Live bridge executed with `deployer`  
- [ ] Live Wave A broadcast + manifest  
- [ ] Attack mode live  
- [ ] Address book + announcement published  

---

## 10. File index

### Crane (operator CWD)

| Path from Crane root | Role |
|----------------------|------|
| `foundry.toml` | `battlechain-sepolia`, `sepolia_public` |
| `scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol` | L1→L2 ETH deposit |
| `scripts/foundry/Script_Promo_BC_Launch.s.sol` | Wave A deploy |
| `scripts/foundry/Script_Pilot_BC_ERC20Permit.s.sol` | Minimal pilot |
| `contracts/InitBcService.sol` | BC-aware Crane bootstrap |
| `script/output/battlechain_promo_manifest.json` | Written on successful promo broadcast |
| `docs/deployment/battlechain.md` | Crane gate narrative |

### IndexedEx docs (review / marketing)

| Path from IndexedEx root | Role |
|--------------------------|------|
| `docs/BATTLECHAIN_DEPLOY_PLAN.md` | **This plan** |
| `docs/BATTLECHAIN_LAUNCH_PROMO.md` | Marketing + Wave A/B scope |
| `docs/battlechain/promo_addresses.md` | Address book template |
| `scripts/foundry/battlechain/Script_Bridge_*.s.sol` | Optional mirror only — **not** used when operating from Crane |

---

*Execute §5 A→G from Crane. Prefer bridge amount ≥ 0.5 ETH for a comfortable Wave A deploy.*
