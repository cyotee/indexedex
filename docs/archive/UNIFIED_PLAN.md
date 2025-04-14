# Unified Development Plan

This document tracks all planned features across the IndexedEx ecosystem.
Work is segmented into parallel worktrees for independent agent execution.

**Last Updated:** 2026-01-10 (All 5 worktrees verified and ready for agents)

## Ecosystem Layers

| Layer | Repo | Purpose |
|-------|------|---------|
| **Crane** | `lib/daosys/lib/crane` | Reusable Solidity framework |
| **daosys** | `lib/daosys` | Aggregator package (Crane + wagmi-declare + daosys_frontend) |
| **IndexedEx** | `.` (root) | Product-specific vault strategies and business logic |

---

## Worktree Status

Worktrees are created on-demand when launching an agent via `/backlog:launch <task-number>`.

| Task | Worktree | Status |
|------|----------|--------|
| 5 | `feature/protocol-detf` | 🔧 Ready for agent (compiles, needs tests) |
| 7 | `feature/slipstream-vault` | 🔧 Ready for agent (stack-too-deep needs struct refactoring) |
| 15 | `review/idx-test-harness-and-quality` | 🔧 Ready for agent |
| 16 | `review/idx-seigniorage-vaults-review` | 🔧 Ready for agent |
| 17 | `review/idx-slipstream-vault-review` | 🔧 Ready for agent (depends on Crane Task C-4) |
| 18 | `review/idx-uniswap-v2-vault-review` | 🔧 Ready for agent (depends on Crane Task C-4) |
| 19 | `review/idx-uniswap-v3-vault-review` | 🔧 Ready for agent (depends on Crane Task C-4) |
| 20 | `review/idx-uniswap-v4-vault-review` | 🔧 Ready for agent (depends on Crane Task C-4) |
| 21 | `review/idx-aerodrome-vault-review` | 🔧 Ready for agent (depends on Crane Task C-4) |
| 22 | `review/idx-camelot-v2-vault-review` | 🔧 Ready for agent (depends on Crane Task C-4) |
| 23 | `review/idx-deployments-and-create3-usage` | 🔧 Ready for agent (depends on Crane Tasks C-1, C-2) |
| 24 | `review/idx-spec-coverage-gap-audit` | 🔧 Ready for agent |
| 25 | `review/idx-protocol-detf-review` | 🔧 Ready for agent (depends on Task 5, Crane Tasks C-2, C-5, C-6) |
| 11 | — | ✅ Complete (merged to `main`: aaf6e73, worktree deleted) |
| 12 | — | ✅ Complete (merged to `main`: c1453c6, worktree deleted) |
| 13 | — | ✅ Complete (merged to `main`: ccb9f05, worktree deleted) |

**Status values:**
- 🚀 In Progress - Worktree active, agent working
- ✅ Complete (merged to `<branch>`) - Task done, worktree deleted
- ⏸️ Paused - Worktree exists but agent not running
- ❌ Blocked: `<reason>` - Agent encountered blocker

### Recovery Notes (2026-01-10)

All agents crashed. Investigation found uncommitted work in most worktrees:

#### Task 11: Aerodrome V1 deployVault ✅ COMPLETE
- **Commit:** `aaf6e73 feat(aerodrome): add deployVault with pool creation and initial deposit`
- **Status:** Complete, merged to main
- **Merged:** 2026-01-10

#### Task 12: Camelot V2 deployVault ✅ COMPLETE
- **Commit:** `c1453c6 feat(camelot-v2): add deployVault with pool creation and initial deposit`
- **Status:** Complete, rebased onto main, all 11 tests pass
- **Changes:** 8 files, 1197 insertions, 562 deletions
- **Verify:** `cd indexedex-wt/feature/camelot-deploy-with-pool && forge test --match-contract CamelotV2StandardExchange_DeployWithPool`

#### Task 13: Uniswap V2 deployVault 🔧 READY FOR AGENT
- **Commits:** None (work not committed)
- **Build:** ✅ Compiles 451 files successfully
- **Uncommitted:** +235 lines across 2 files
- **Files:** `UniswapV2StandardExchangeDFPkg.sol` (+234 lines), `TestBase_UniswapV2StandardExchange.sol`
- **New:** `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_DeployWithPool.t.sol`
- **Agent task:** Run tests, verify, commit
- **Launch:** `cd indexedex-wt/feature/uniswap-v2-deploy-with-pool && claude --dangerously-skip-permissions`

#### Task 5: Protocol DETF 🔧 READY FOR AGENT
- **Commits:** None (work not committed)
- **Build:** ✅ Compiles 741 files successfully
- **New files (15):** ProtocolDETFRepo.sol, ProtocolDETFCommon.sol, ProtocolDETFExchangeInTarget.sol, ProtocolDETFExchangeInFacet.sol, ProtocolDETFExchangeOutTarget.sol, ProtocolDETFExchangeOutFacet.sol, ProtocolDETFBondingTarget.sol, ProtocolDETFBondingFacet.sol, ProtocolNFTVaultRepo.sol, ProtocolNFTVaultCommon.sol, ProtocolNFTVaultTarget.sol, ProtocolNFTVaultFacet.sol, RICHIRRepo.sol, RICHIRTarget.sol, RICHIRFacet.sol
- **Interfaces:** IProtocolDETF.sol, IProtocolDETFErrors.sol, IProtocolNFTVault.sol, IRICHIR.sol + proxy interfaces
- **Missing:** Tests, DFPkg files, FactoryService
- **Agent task:** Write tests, create DFPkg, complete implementation per PROMPT.md
- **Launch:** `cd indexedex-wt/feature/protocol-detf && claude --dangerously-skip-permissions`

#### Task 7: Slipstream Vault 🔧 READY FOR AGENT
- **Commits:** None (work not committed)
- **Code lines:** ~4,233 lines (12 contracts + 4 test files)
- **Contracts:** SlipstreamStandardExchangeRepo.sol, SlipstreamStandardExchangeCommon.sol, SlipstreamStandardExchangeInTarget.sol, SlipstreamStandardExchangeInFacet.sol, SlipstreamStandardExchangeOutTarget.sol, SlipstreamStandardExchangeOutFacet.sol, SlipstreamStandardExchangeDFPkg.sol, Slipstream_Component_FactoryService.sol, SlipstreamRangeCalculator.sol, SlipstreamPoolAwareRepo.sol, SlipstreamNFTAwareRepo.sol, TestBase_SlipstreamStandardExchange.sol
- **Tests:** SlipstreamStandardExchange_SingleSided.t.sol, SlipstreamStandardExchange_StateTransition.t.sol, SlipstreamStandardExchange_Consolidation.t.sol, SlipstreamStandardExchange_Compound.t.sol
- **Submodule:** ✅ Fixed (crane copied from main repo)
- **Build:** Compiles 749 files, then hits **stack-too-deep error** at `SlipstreamStandardExchangeInTarget.sol:194`
- **Agent task:** Refactor using structs (NOT viaIR) to fix stack-too-deep, then complete implementation
- **Backup:** `/tmp/claude/slipstream-backup/` contains contracts and PROMPT.md
- **Launch:** `cd indexedex-wt/feature/slipstream-vault && claude --dangerously-skip-permissions`

### Recovery Priority Order

All worktrees verified and ready:

1. **Task 11** - ✅ Already committed, just merge
2. **Task 12** - ✅ Ready for agent (compiles, run tests + commit)
3. **Task 13** - ✅ Ready for agent (compiles, run tests + commit)
4. **Task 7** - ✅ Ready for agent (stack-too-deep needs struct refactoring)
5. **Task 5** - ✅ Ready for agent (compiles, needs tests and DFPkg)

### Running Agents

**Standardized command (works in any worktree):**
```bash
cd <worktree-path>
claude --dangerously-skip-permissions
# Then in Claude Code:
/ralph-loop:ralph-loop "Read PROMPT.md and execute the task described in it." --completion-promise "TASK_COMPLETE" --max-iterations 10
```

All PROMPT.md files use standardized promises:
- `<promise>TASK_COMPLETE</promise>` - success
- `<promise>TASK_BLOCKED: [reason]</promise>` - blocked

### Permission Configuration

To prevent agents from pausing to ask for permissions, use one of these approaches:

**Option 1: Skip all permissions (recommended for trusted worktrees)**
```bash
claude --dangerously-skip-permissions
```

**Option 2: Pre-approve specific tools**
```bash
claude --allowedTools "Bash(forge:*),Bash(git:*),Read,Edit"
```

**Option 3: Use permission mode flag**
```bash
claude --permission-mode bypassPermissions
```

**Option 4: Persistent configuration via `.claude/settings.json`**
```json
{
  "permissions": {
    "defaultMode": "dontAsk",
    "allow": [
      "Bash(forge build:*)",
      "Bash(forge test:*)",
      "Bash(git:*)",
      "Read",
      "Edit"
    ]
  }
}
```

**Permission modes:**
| Mode | Behavior |
|------|----------|
| `default` | Standard prompting |
| `acceptEdits` | Auto-accept file edits |
| `dontAsk` | Auto-deny unless in `allow` list |
| `bypassPermissions` | Skip all permission prompts |

**Note:** "Always allow in this session" responses don't persist across sessions. Use CLI flags or settings.json for persistent configuration.

---

## Agent Execution Notes

Each agent receives a `PROMPT.md` in its worktree with:
1. Clear scope boundaries
2. Inventory check requirements
3. Standardized completion promise (`TASK_COMPLETE`)
4. Files NOT to modify (owned by other agents)

Agents output `<promise>TASK_COMPLETE</promise>` when done, or `<promise>TASK_BLOCKED: reason</promise>` if stuck.

---

## Task 5: Protocol DETF (CHIR) and Fee Distribution System

**Layer:** IndexedEx
**Worktree:** `feature/protocol-detf`
**Status:** Ready for Agent

### Description
Implement the Protocol DETF system (CHIR token) with integrated fee distribution. This is similar to the existing Seigniorage DETF but with key differences in token economics and fee capture mechanisms.

### Token Architecture

| Token | Type | Purpose |
|-------|------|---------|
| **CHIR** | Mintable/Burnable ERC20 | Protocol DETF token |
| **RICH** | Static Supply ERC20 | Reward token sold by protocol |
| **RICHIR** | Rebasing ERC20 | Holds protocol-owned NFT, redeemable for WETH |
| **WETH** | Standard ERC20 | Chain's wrapped gas token |

### RICHIR Rebasing Mechanism

RICHIR is a **true rebasing token** where `balanceOf()` returns different values over time based on the current spot redemption value of the user's underlying shares.

**How it works:**

```
User's RICHIR balance = userShares * currentRedemptionRate

where:
  currentRedemptionRate = spotRedemptionQuote(1 share) in WETH terms
```

**Rebasing triggers:**
- Balance changes on **any liquidity event** in either underlying pool:
  - CHIR/WETH Aerodrome pool swaps, deposits, withdrawals
  - RICH/CHIR Aerodrome pool swaps, deposits, withdrawals
- This means `balanceOf()` can return different values between any two calls

**Storage model:**

| Storage | Mutability | Description |
|---------|------------|-------------|
| `sharesOf[user]` | Only on mint/burn | User's underlying share balance (constant between transfers) |
| `totalShares` | Only on mint/burn | Total shares outstanding |
| `balanceOf(user)` | Computed live | `sharesOf[user] * redemptionRate()` |
| `totalSupply()` | Computed live | `totalShares * redemptionRate()` |

**Redemption rate calculation:**
1. Query protocol NFT's reserve LP position value
2. Calculate proportional claim on reserve pool
3. Simulate full unwinding: reserve LP → vault tokens → Aerodrome LP → WETH
4. Return WETH value per share

**Intentional incompatibilities:**
- AMM liquidity pools (balance changes break invariants)
- Lending protocols (collateral value unstable)
- Yield aggregators (share accounting assumptions violated)
- Most DeFi integrations expecting stable `balanceOf()`

**This is desired behavior.** RICHIR is designed as a redemption claim, not a composable DeFi primitive.

### Reserve Pool Structure

```
Reserve Pool (80/20 Balancer V3 Weighted Pool)
├── CHIR/WETH Standard Exchange Vault (80%)
│   ├── Rate Provider: targets WETH
│   └── Underlying: Aerodrome V1 CHIR/WETH volatile LP
└── RICH/CHIR Standard Exchange Vault (20%)
    ├── Rate Provider: targets RICH
    └── Underlying: Aerodrome V1 RICH/CHIR volatile LP
```

### Price Peg Mechanism

This system uses a **fully diluted, backing-derived synthetic spot price** (RICH per 1 WETH) to gate asymmetric operations in a manipulation-resistant way.

- **Target peg:** `synthetic_price ≈ 1.0` (RICH and WETH treated as equal-value at peg)
- **Mint gate (WETH → CHIR):** allowed only when `synthetic_price > mintThreshold`
- **Burn gate (CHIR/RICHIR redemption path):** allowed only when `synthetic_price < burnThreshold`
- **Hysteresis (recommended):** `mintThreshold = 1.005`, `burnThreshold = 0.995`

#### Fully Diluted Peg Oracle (RICH per 1 WETH)

**Token mapping (this task):**
- DETF token = `CHIR`
- Static token = `RICH`
- Gas token = `WETH`

**Required on-chain inputs (queried live):**
- From Aerodrome V1 CHIR/WETH volatile LP:
  - `CHIR_gas` = CHIR reserve in CHIR/WETH pool
  - `G` = WETH reserve in CHIR/WETH pool
- From Aerodrome V1 RICH/CHIR volatile LP:
  - `CHIR_static` = CHIR reserve in RICH/CHIR pool
  - `St` = RICH reserve in RICH/CHIR pool
- `D_total` = total supply of CHIR (fully diluted)

**Computation:**
1. Current distribution of CHIR across the two LPs:
  - `total_CHIR_in_LPs = CHIR_static + CHIR_gas`
  - `proportion_static = CHIR_static / total_CHIR_in_LPs`
  - `proportion_gas = CHIR_gas / total_CHIR_in_LPs`
2. Hypothetically allocate the full CHIR supply using those proportions:
  - `hyp_CHIR_static = proportion_static * D_total`
  - `hyp_CHIR_gas = proportion_gas * D_total`
3. Implied backing prices:
  - `P_static = St / hyp_CHIR_static` (RICH per CHIR)
  - `P_gas = G / hyp_CHIR_gas` (WETH per CHIR)
4. Synthetic spot price:
  - `synthetic_price = P_static / P_gas` (RICH per 1 WETH)

**Simplified equivalent (implementation-friendly):**
`synthetic_price = (St / G) * (CHIR_gas / CHIR_static)`

**Interpretation:**
- `synthetic_price > 1`: RICH backing relatively strong vs WETH backing → allow WETH deposits to mint CHIR (and enable seigniorage capture).
- `synthetic_price < 1`: WETH backing relatively strong → allow CHIR/RICHIR redemption paths (burn flows) to redeem WETH.

### Key Differences from Seigniorage DETF

| Aspect | Seigniorage DETF (RBT) | Protocol DETF (CHIR) |
|--------|------------------------|----------------------|
| Seigniorage token | sRBT minted to NFT vault | CHIR minted, zapped into RICH/CHIR vault |
| Minting input | Reserve vault token | WETH only |
| Bonding inputs | N/A | WETH or RICH |
| NFT sale | N/A | Sells to protocol for RICHIR |
| Protocol NFT | N/A | No unlock, held by RICHIR |
| Redemption token | N/A | RICHIR redeemable for WETH |

### Operations

#### 1. Minting CHIR (User deposits WETH)
```
User deposits WETH
  → Require `synthetic_price > mintThreshold`
  → Mint proportional CHIR (priced using the peg oracle gating above)
  → Deposit WETH + CHIR → CHIR/WETH Aerodrome pool
  → Deposit Aerodrome LP → CHIR/WETH Standard Exchange Vault
  → Add vault tokens to reserve pool (unbalanced deposit)
  → Reserve LP NOT credited to any account (benefits NFT holders)
  → Mint CHIR to user based on exchange rate
```

#### 2. Bonding (User deposits WETH or RICH for NFT)
```
User deposits WETH or RICH
  → Mint proportional CHIR
  → If WETH: pair with CHIR → CHIR/WETH Aerodrome → LP → vault → reserve
    If RICH: pair with CHIR → RICH/CHIR Aerodrome → LP → vault → reserve
  → Credit NFT with shares based on reserve LP tokens added
  → NFT receives RICH rewards (external supply)
```

#### 3. Seigniorage Capture (Above Peg)
```
When `synthetic_price > mintThreshold`:
  → Calculate profit margin (gross seigniorage - discount margin)
  → Mint CHIR
  → Zap-in CHIR through RICH/CHIR Standard Exchange Vault
  → Add resulting vault tokens to reserve pool (unbalanced)
  → NOT credited to any account (benefits NFT holders)
```

#### 4. NFT Sale to Protocol
```
User sells NFT
  → Transfer NFT's LP shares to protocol-owned NFT
  → User receives RICHIR tokens
  → Protocol NFT: no unlock time, never fully redeemed
```

#### 5. RICHIR Redemption (Burn RICHIR → WETH)
```
User burns RICHIR
  → Calculate reserve pool tokens from rebasing balance (ERC4626 math)
  → Proportional withdrawal from reserve pool
  → Withdraw RICH/CHIR vault tokens → Aerodrome LP → burn → RICH + CHIR
  → Deposit RICH back into RICH/CHIR vault → unbalanced to reserve pool
  → Swap CHIR → WETH through WETH/CHIR Standard Exchange Vault
  → Withdraw WETH/CHIR vault tokens → Aerodrome LP → burn → WETH + CHIR
  → Burn the CHIR
  → Send WETH to user
```

### Fee Distribution Integration

FeeCollector converts and pushes fees to Protocol DETF via `donate()` function.
Protocol DETF does not need to know about FeeCollector internals.

### Existing Patterns to Follow
- `contracts/vaults/seigniorage/SeigniorageDETF*.sol` - Base DETF pattern
- `contracts/vaults/seigniorage/SeigniorageNFTVault*.sol` - NFT bonding
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchange*.sol` - Aerodrome V1 integration
- `contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol` - Pool math

### Package Reuse Requirements

**Token Packages (from Crane):**

| Token | Package | Location |
|-------|---------|----------|
| RICH | `ERC20PermitDFPkg` | `lib/daosys/lib/crane/contracts/tokens/ERC20/` |
| CHIR | `ERC20PermitMintBurnLockedOwnableDFPkg` | `lib/daosys/lib/crane/contracts/tokens/ERC20/` |
| RICHIR | Custom (extend ERC4626) | New implementation required - no Crane rebasing pattern exists |

**Standard Exchange Vault Packages (per chain):**

| Chain | DEX | Package | Location |
|-------|-----|---------|----------|
| Base | Aerodrome V1 | `AerodromeStandardExchangeDFPkg` | `contracts/protocols/dexes/aerodrome/v1/` |
| Ethereum | Uniswap V2 | `UniswapV2StandardExchangeDFPkg` | `contracts/protocols/dexes/uniswap/v2/` |

**Other Packages:**

| Component | Package/Factory | Notes |
|-----------|-----------------|-------|
| Reserve Pool | Balancer V3 `WeightedPool8020Factory` | Direct factory call (not a DFPkg) - same pattern as SeigniorageDETF |
| NFT Vault | Follow `SeigniorageNFTVaultDFPkg` pattern | Custom implementation in `contracts/vaults/protocol/` |
| Rate Provider | `StandardExchangeRateProviderDFPkg` | Use existing if available, or implement inline |

**Multi-Chain Deployment:**
- **Primary target:** Base (Aerodrome V1 pools for CHIR/WETH and RICH/CHIR)
- **Secondary target:** Ethereum (Uniswap V2 pools, if CHIR/WETH and RICH/CHIR pairs exist)

### Files to Create

**Core DETF:**
- `contracts/vaults/protocol/ProtocolDETFRepo.sol` - Storage
- `contracts/vaults/protocol/ProtocolDETFCommon.sol` - Shared logic
- `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol` - Mint/bond logic
- `contracts/vaults/protocol/ProtocolDETFExchangeInFacet.sol` - Facet
- `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol` - Redeem logic
- `contracts/vaults/protocol/ProtocolDETFExchangeOutFacet.sol` - Facet
- `contracts/vaults/protocol/ProtocolDETFUnderwritingTarget.sol` - Bond creation
- `contracts/vaults/protocol/ProtocolDETFUnderwritingFacet.sol` - Facet
- `contracts/vaults/protocol/ProtocolDETFDFPkg.sol` - Diamond package
- `contracts/vaults/protocol/ProtocolDETF_FactoryService.sol` - CREATE3 deployment

**NFT Vault:**
- `contracts/vaults/protocol/ProtocolNFTVaultRepo.sol` - Storage
- `contracts/vaults/protocol/ProtocolNFTVaultCommon.sol` - Shared logic
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol` - Bond/unlock/sell logic
- `contracts/vaults/protocol/ProtocolNFTVaultFacet.sol` - Facet
- `contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol` - Diamond package

**RICHIR Rebasing Vault:**
- `contracts/vaults/protocol/RICHIRRepo.sol` - Storage
- `contracts/vaults/protocol/RICHIRRebasingTarget.sol` - Rebasing logic
- `contracts/vaults/protocol/RICHIRExchangeInTarget.sol` - Redemption (burn → WETH)
- `contracts/vaults/protocol/RICHIRFacet.sol` - Facet
- `contracts/vaults/protocol/RICHIRDFPkg.sol` - Diamond package

**Interfaces:**
- `contracts/interfaces/IProtocolDETF.sol`
- `contracts/interfaces/IProtocolNFTVault.sol`
- `contracts/interfaces/IRICHIR.sol`
- `contracts/interfaces/proxies/IProtocolDETFProxy.sol`
- `contracts/interfaces/proxies/IProtocolNFTVaultProxy.sol`
- `contracts/interfaces/proxies/IRICHIRProxy.sol`

**Tests:**
- `test/foundry/spec/protocol/vaults/protocol/ProtocolDETFMinting.t.sol`
- `test/foundry/spec/protocol/vaults/protocol/ProtocolDETFBonding.t.sol`
- `test/foundry/spec/protocol/vaults/protocol/ProtocolDETFSeigniorage.t.sol`
- `test/foundry/spec/protocol/vaults/protocol/ProtocolNFTVault.t.sol`
- `test/foundry/spec/protocol/vaults/protocol/RICHIRRedemption.t.sol`
- `contracts/vaults/protocol/TestBase_ProtocolDETF.sol`

### Inventory Check (Agent must verify)
- [ ] Aerodrome V1 volatile pool integration exists and works
- [ ] Balancer V3 80/20 weighted pool math available
- [ ] Standard Exchange Vault with rate provider pattern exists
- [ ] ERC4626 rebasing patterns available in Crane
- [ ] NFT vault bonding pattern from Seigniorage DETF works

### User Stories

**US-5.1: Mint CHIR with WETH**
As a user, I want to deposit WETH to receive CHIR tokens so that I can participate in the protocol.

Acceptance Criteria:
- `exchangeIn(WETH, amount, CHIR)` mints CHIR only when `synthetic_price > mintThreshold` (else revert)
- WETH is paired with minted CHIR, LPed, vaulted, and added to reserve
- Reserve LP benefits existing NFT bond holders
- User receives CHIR tokens

**US-5.2: Bond with WETH**
As a user, I want to bond WETH for an NFT position so that I can earn RICH rewards.

Acceptance Criteria:
- `bond(WETH, amount, lockDuration)` creates NFT position
- WETH paired with minted CHIR, LPed into CHIR/WETH pool
- Aerodrome LP deposited to vault, vault tokens to reserve
- NFT credited with shares based on reserve LP added
- Longer lock = higher bonus multiplier = more reward share

**US-5.3: Bond with RICH**
As a user, I want to bond RICH for an NFT position so that I can earn RICH rewards.

Acceptance Criteria:
- `bond(RICH, amount, lockDuration)` creates NFT position
- RICH paired with minted CHIR, LPed into RICH/CHIR pool
- Aerodrome LP deposited to vault, vault tokens to reserve
- NFT credited with shares based on reserve LP added

**US-5.4: Seigniorage Capture**
As the protocol, I want to capture seigniorage when CHIR trades above peg so that NFT bond holders benefit.

Acceptance Criteria:
- When `synthetic_price > mintThreshold`, calculate profit margin
- Mint CHIR and zap-in to RICH/CHIR Standard Exchange Vault
- Add resulting vault tokens to reserve pool (unbalanced)
- Not credited to any account - benefits all NFT holders

**US-5.5: Sell NFT to Protocol**
As a user, I want to sell my NFT to the protocol so that I can exit my position for RICHIR.

Acceptance Criteria:
- `sellNFT(tokenId)` or during underwriting `bond(..., sellImmediately=true)`
- NFT's LP shares transferred to protocol-owned NFT
- User receives RICHIR tokens proportional to position value
- Protocol NFT accumulates LP without new bond periods

**US-5.6: RICHIR Redemption**
As a RICHIR holder, I want to burn RICHIR for WETH so that I can exit.

Acceptance Criteria:
- `exchangeIn(RICHIR, amount, WETH)` processes redemption only when `synthetic_price < burnThreshold` (else revert)
- Calculate reserve tokens from rebasing balance
- Complex unwinding: withdraw from reserve, burn LPs, redeposit RICH portion
- User receives WETH, CHIR is burned

**US-5.7: Protocol NFT Privileges**
As the protocol, I want a special NFT that can accumulate LP without lock restrictions.

Acceptance Criteria:
- Protocol NFT has no unlock time (always unlocked)
- Protocol NFT is never fully redeemed
- Can add LP from sold user NFTs without restarting bond period
- Receives RICH rewards like regular NFTs
- Held by RICHIR contract

**US-5.8: Fee Donation**
As the FeeCollector, I want to donate converted fees to the Protocol DETF.

Acceptance Criteria:
- `donate(token, amount)` accepts WETH or CHIR only
- **WETH donation flow:**
  1. Single-sided deposit to CHIR/WETH StandardExchangeVault via `exchangeIn(WETH, amount, vaultToken, pretransferred=true, recipient=BalancerV3Vault)`
  2. Call Prepay interface on StandardExchangeRouter for unbalanced deposit to reserve pool
  3. No CHIR minting occurs (neither for CHIR/WETH pool nor RICH/CHIR pool)
- **CHIR donation flow:** Simply burn the CHIR
- No coupling to FeeCollector internals

### Implementation Clarifications

| Topic | Clarification |
|-------|---------------|
| **Lock Duration Curve** | Use exact exponential formula from existing SeigniorageDETF; min/max duration from VaultFeeOracle |
| **RICH Token Supply** | Pre-minted at deployment (static supply, no minting capability) |
| **Discount Margin** | Retrieved from VaultFeeOracle seigniorage terms |
| **NFT Sale Value** | Current reserve LP share value + accrued RICH rewards; immediate maturation allowed with no penalty |
| **RICHIR Redemption** | Partial redemption allowed (any amount) |
| **Protocol NFT Rewards** | Left uncollected by default; `feeTo` address from VaultFeeOracle can call restricted function to reallocate as bond purchase incentives |
| **Lock Duration Bounds** | Both minimum and maximum lock duration retrieved from VaultFeeOracle |

### Completion Criteria
- All Protocol DETF operations functional (mint, bond, redeem)
- NFT vault with bonding, rewards, and sell-to-protocol
- RICHIR rebasing vault with WETH redemption
- Seigniorage capture benefits NFT holders
- Fork tests against Base mainnet pass
- Full test coverage for all user stories

---

## Task 6: Spec Coverage for Package-Deployed Protocol Instances (DFPkgs)

**Layer:** IndexedEx
**Worktree:** TBD
**Status:** Pending Agent

### Description
Add/repair Foundry spec tests to ensure protocol instances deployed via Diamond Factory Packages (DFPkgs) are actually covered by runnable `test*` functions and assert real behavioral guarantees (not just compilation/deployment).

### Requirements
- Ensure Uniswap V2, Camelot V2, and Balancer V3 constant-product-vault package deployments have spec-level tests.
- Add direct coverage for `StandardExchangeRateProviderDFPkg` behavior (beyond integration-only coverage).
- Keep test deployments aligned with repo conventions (avoid `new` for deploys when deterministic deployment helpers exist).

### Completion Criteria
- `forge test --match-path test/foundry/spec/protocol/dexes/uniswap/v2/**/*.sol` runs at least one suite with passing tests.
- Camelot V2 and Balancer constant-product-vault package deployments are exercised in Foundry specs.
- Coverage includes both success paths and revert paths (slippage, deadline, caller restrictions).
- Any harness tests currently using `new` for deploys are refactored to deterministic factory-based deployments (or documented exceptions).

### User Stories

**US-6.1: Runnable Uniswap V2 StandardExchange Specs**
As a user, I want Uniswap V2 StandardExchange behavior covered by runnable specs so that swaps and previews are correct for package-deployed instances.

Acceptance Criteria:
- Tests deploy `UniswapV2StandardExchangeDFPkg` and assert `previewExchangeIn`/`exchangeIn` consistency within tolerance.
- Revert coverage: slippage (`minAmountOut`), deadline, and invalid token routing.
- Includes coverage for `pretransferred = true/false` behavior.

**US-6.2: Camelot V2 StandardExchange Specs**
As a user, I want Camelot V2 StandardExchange behavior covered by specs so that Camelot deployments remain safe and correct as packages evolve.

Acceptance Criteria:
- Tests deploy `CamelotV2StandardExchangeDFPkg` and perform at least one successful `exchangeIn` and `exchangeOut` round-trip.
- Revert coverage: slippage and deadline.
- Asserts spender/approval expectations (no unexpected token retention).

**US-6.3: Balancer V3 Constant-Product Pool Standard Vault Package Specs**
As a user, I want the constant-product pool standard vault package covered by specs so that vault accounting and pool interactions remain correct.

Acceptance Criteria:
- Tests deploy `BalancerV3ConstantProductPoolStandardVaultPkg` and validate deposit/withdraw correctness.
- Includes at least one swap/price-impact path relevant to the vault’s accounting.
- Revert coverage for invalid inputs and safety checks.

**US-6.4: StandardExchangeRateProviderDFPkg Direct Specs**
As a user, I want rate-provider package behavior covered directly so that integrations relying on rates are correct and stable.

Acceptance Criteria:
- Tests deploy `StandardExchangeRateProviderDFPkg` and assert `getRate` behavior against a controlled scenario.
- Covers edge cases like zero supply / initial state and validates expected revert/return semantics.

**US-6.5: Deterministic Deploys in Specs (No `new` Harness Deployments)**
As a maintainer, I want spec tests to follow the repo's deterministic deployment conventions so that tests match production deployment patterns.

Acceptance Criteria:
- Any spec suite deploying harness facets/packages via `new` is refactored to factory/CREATE3 helpers (or has a clearly documented exception).
- Balancer "locked caller" harness specs continue to validate the caller-restriction behavior after refactor.

### Implementation Clarifications

| Topic | Clarification |
|-------|---------------|
| **Preview/Actual Tolerance** | Exact match required (0 tolerance) - `previewExchangeIn` must return exactly what `exchangeIn` produces |
| **Balancer Caller Restriction** | Agent should investigate existing test code to determine what "locked caller harness specs" refers to; may relate to router-only calls or vault settlement patterns |

---

## Task 7: Slipstream Standard Exchange Vault

**Layer:** IndexedEx
**Worktree:** `feature/slipstream-vault`
**Status:** Ready for Agent
**Fulfills:** Task 4 (partially)

### Description
Implement a Standard Exchange vault for Aerodrome Slipstream (concentrated liquidity) on Base. This is the reference implementation for concentrated liquidity vaults that will inform Tasks 8 and 9.

### Dependencies
- Task 2 (Slipstream Utils) must complete first

### Concentrated Liquidity Position States

| State | Price Condition | Holds | Accepts |
|-------|-----------------|-------|---------|
| **Below price** | current price < lower tick | 100% token1 | token1 only |
| **In range** | lower tick ≤ price ≤ upper tick | Both tokens | Both (in ratio) |
| **Above price** | current price > upper tick | 100% token0 | token0 only |

### Position Management Strategy

- **Max 3 active NFT positions**: one per state (above/in/below price)
- **Track by intended tick range**, reassign state based on current price
- **On-demand creation**: new positions created only when deposit requires it
- **State transitions**: positions automatically transition as price moves

### Deposit Flow

```
User deposits tokenX via exchangeIn()
  │
  ├── If tokenX == token0:
  │     ├── Check for "above-price" NFT → deposit there (single-sided)
  │     └── If none: create new NFT with range above current price
  │
  ├── If tokenX == token1:
  │     ├── Check for "below-price" NFT → deposit there (single-sided)
  │     └── If none: create new NFT with range below current price
  │
  └── State transition handling:
        └── If intended "above-price" NFT is now in-range:
              → Reassign it as in-range NFT
              → Create new above-price NFT for deposit
```

### Range Calculation

- **Width**: Based on historical TWAP volatility from pool oracle
- **Formula**: Wider range in high volatility, narrower in low volatility
- **New positions**: Created just above/below current price with volatility-adjusted width

### Consolidation

- **Triggers**:
  - Manual/keeper call
  - Large deposits (threshold from VaultFeeOracle)
- **Strategy**: Merge only if ranges are adjacent
- **Out-of-range positions**: Kept separate unless adjacent to merge target

### Fee Handling

- **Auto-compound**: Collected fees reinvested into positions
- **Fee collection**: Uses `VaultFeeOracle` for protocol fee calculation

### User Stories

**US-7.1: Single-Sided Token0 Deposit**
As a user, I want to deposit token0 into a Slipstream vault so that I can earn trading fees without needing both tokens.

Acceptance Criteria:
- `exchangeIn(token0, amount, vaultToken)` accepts single-sided deposit
- If "above-price" NFT exists and is still above price: deposit into it
- If no suitable NFT: create new NFT with range above current price
- Range width calculated from historical TWAP volatility
- User receives vault shares proportional to liquidity added
- Protocol fee deducted per VaultFeeOracle

**US-7.2: Single-Sided Token1 Deposit**
As a user, I want to deposit token1 into a Slipstream vault so that I can earn trading fees without needing both tokens.

Acceptance Criteria:
- `exchangeIn(token1, amount, vaultToken)` accepts single-sided deposit
- If "below-price" NFT exists and is still below price: deposit into it
- If no suitable NFT: create new NFT with range below current price
- Range width calculated from historical TWAP volatility
- User receives vault shares proportional to liquidity added

**US-7.3: Position State Transition**
As the vault, I want to correctly handle position state transitions when price moves so that deposits always go to the right NFT.

Acceptance Criteria:
- When intended "above-price" NFT becomes in-range:
  - Reassign as in-range NFT
  - Create new above-price NFT for new token0 deposits
- When intended "below-price" NFT becomes in-range:
  - Reassign as in-range NFT
  - Create new below-price NFT for new token1 deposits
- When in-range NFT goes out of range:
  - Reassign based on which direction price moved
  - Allow single-sided deposits to that NFT

**US-7.4: TWAP-Based Range Calculation**
As the vault, I want to calculate optimal tick ranges based on volatility so that positions capture fees efficiently.

Acceptance Criteria:
- Query pool oracle for historical TWAP data
- Calculate volatility from price movement over lookback period
- Higher volatility → wider range (capture more price movement)
- Lower volatility → narrower range (concentrate liquidity)
- Range parameters configurable via VaultFeeOracle

**US-7.5: Position Consolidation**
As a keeper, I want to consolidate fragmented positions so that the vault operates efficiently.

Acceptance Criteria:
- `consolidate()` function callable by keeper or triggered by large deposits
- Large deposit threshold from VaultFeeOracle
- Only merge positions with adjacent tick ranges
- Out-of-range positions kept separate unless adjacent
- Gas-efficient: skip consolidation if cost exceeds benefit

**US-7.6: Fee Auto-Compound**
As a user, I want collected trading fees automatically reinvested so that my position compounds.

Acceptance Criteria:
- Fees collected from Slipstream positions
- Fees added back to appropriate NFT positions
- Protocol fee deducted before reinvestment
- Compound happens on deposits, withdrawals, or explicit collect call

**US-7.7: Withdrawal**
As a user, I want to withdraw my liquidity from the vault so that I can exit my position.

Acceptance Criteria:
- `exchangeIn(vaultToken, shares, tokenOut)` burns shares, returns tokens
- Withdrawal removes liquidity proportionally from all positions
- User can specify single token output (zap-out)
- If zap-out: vault swaps to desired token
- Minimum output enforced via slippage parameter

**US-7.8: Preview Functions**
As a user, I want to preview deposits and withdrawals so that I know what to expect.

Acceptance Criteria:
- `previewExchangeIn(token0, amount, vaultToken)` returns expected shares
- `previewExchangeIn(token1, amount, vaultToken)` returns expected shares
- `previewExchangeIn(vaultToken, shares, token0)` returns expected token0
- `previewExchangeIn(vaultToken, shares, token1)` returns expected token1
- Previews account for current price, position states, and fees

### Files to Create

**Core Vault:**
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeRepo.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTarget.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInFacet.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutFacet.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeDFPkg.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/Slipstream_Component_FactoryService.sol`

**Position Management:**
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPositionManager.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamRangeCalculator.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamConsolidator.sol`

**Tests:**
- `test/foundry/fork/base_main/slipstream/SlipstreamStandardExchange_SingleSided.t.sol`
- `test/foundry/fork/base_main/slipstream/SlipstreamStandardExchange_StateTransition.t.sol`
- `test/foundry/fork/base_main/slipstream/SlipstreamStandardExchange_Consolidation.t.sol`
- `test/foundry/fork/base_main/slipstream/SlipstreamStandardExchange_Compound.t.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/TestBase_SlipstreamStandardExchange.sol`

### Inventory Check (Agent must verify)
- [ ] Slipstream NFT position manager interface available
- [ ] Slipstream pool oracle (TWAP) accessible
- [ ] SlipstreamUtils and SlipstreamZapQuoter from Task 2 ready
- [ ] VaultFeeOracle integration patterns from existing vaults
- [ ] Multi-NFT tracking patterns (ERC721 enumerable or custom)

### Implementation Clarifications

| Topic | Clarification |
|-------|---------------|
| **TWAP Lookback Period** | Configurable per-vault via VaultFeeOracle |
| **Tick Offset from Current Price** | Volatility-dependent: higher volatility = larger offset from current price |
| **Position Slot Full Scenario** | When all 3 slots occupied and none accept deposit token: rebalance the smallest overlapping-range position into above/below positions, apply volatility offset to new position |
| **Rebalance Fee** | Charge Usage Fee from VaultFeeOracle based on accrued fees as diluting vault shares |
| **Consolidation Threshold** | Tick density relative to pool average (total liquidity / active tick count) |
| **No TWAP Fallback** | If pool oracle lacks sufficient history, use spot price volatility calculation |
| **Minimum Deposit** | No minimum; handle dust gracefully via opportunistic consolidation |
| **Uncollected Fees** | Include in both preview and actual deposit/withdrawal calculations |

### Completion Criteria
- All user stories implemented and tested
- Fork tests against Base mainnet pass
- Single-sided deposits work for both tokens
- Position state transitions handled correctly
- Consolidation merges adjacent ranges
- Auto-compound reinvests fees

---

## Task 8: Uniswap V3 Standard Exchange Vault

**Layer:** IndexedEx
**Worktree:** `feature/uniswap-v3-vault`
**Status:** Ready for Agent
**Fulfills:** Task 4 (partially)

### Description
Implement a Standard Exchange vault for Uniswap V3 (concentrated liquidity) on Ethereum mainnet and L2s. This mirrors the Slipstream vault pattern (Task 7) but simplified for V3's architecture (no gauge/staking/rewards).

### Dependencies
- Task 1 (V3 Mainnet Fork Tests) should complete first for test infrastructure
- Crane's existing `UniswapV3Utils`, `UniswapV3Quoter`, `UniswapV3ZapQuoter` libraries

### Technical Differences from Slipstream

| Aspect | Uniswap V3 | Slipstream | Vault Impact |
|--------|-----------|------------|--------------|
| Gauge/Staking | None | Full integration | V3 vault is simpler |
| Rewards | None | `rewardGrowthGlobalX128` | Skip reward tracking |
| Fee Protocol | `feeProtocol` in slot0 | Removed | Optional protocol fee handling |
| Tick Spacings | Flexible per deployment | Hardcoded (1,50,100,200,2000) | Dynamic config needed |
| Callbacks | `uniswapV3*Callback` | Identical | Same handlers work |

### Concentrated Liquidity Position States

| State | Price Condition | Holds | Accepts |
|-------|-----------------|-------|---------|
| **Below price** | current price < lower tick | 100% token1 | token1 only |
| **In range** | lower tick ≤ price ≤ upper tick | Both tokens | Both (in ratio) |
| **Above price** | current price > upper tick | 100% token0 | token0 only |

### Position Management Strategy

- **Max 3 active NFT positions**: one per state (above/in/below price)
- **Track by intended tick range**, reassign state based on current price
- **On-demand creation**: new positions created only when deposit requires it
- **State transitions**: positions automatically transition as price moves
- **Use NonfungiblePositionManager (NPM)**: standard Uniswap V3 periphery contract

### Multi-Chain Deployment

Each chain requires a separate Diamond Factory Package with chain-specific addresses:
- Ethereum Mainnet
- Arbitrum One
- Optimism
- Polygon
- Base

Chain-specific configuration passed during vault instance initialization:
- NonfungiblePositionManager address
- V3 Factory address
- WETH/wrapped native token address

### Deposit Flow

```
User deposits tokenX via exchangeIn()
  │
  ├── If tokenX == token0:
  │     ├── Check for "above-price" NFT → deposit there (single-sided)
  │     └── If none: create new NFT with range above current price
  │
  ├── If tokenX == token1:
  │     ├── Check for "below-price" NFT → deposit there (single-sided)
  │     └── If none: create new NFT with range below current price
  │
  └── State transition handling:
        └── If intended "above-price" NFT is now in-range:
              → Reassign it as in-range NFT
              → Create new above-price NFT for deposit
```

### Range Calculation

- **Width**: Based on historical TWAP volatility from V3 pool oracle
- **Formula**: Wider range in high volatility, narrower in low volatility
- **New positions**: Created just above/below current price with volatility-adjusted width
- **Tick spacing**: Must align to pool's tick spacing (varies by fee tier)

### Fee Tiers

Each vault instance targets a single fee tier pool:
- 0.01% (1 bps) - tickSpacing 1
- 0.05% (5 bps) - tickSpacing 10
- 0.30% (30 bps) - tickSpacing 60
- 1.00% (100 bps) - tickSpacing 200

### Consolidation

- **Triggers**:
  - Manual/keeper call
  - Large deposits (threshold from VaultFeeOracle)
- **Strategy**: Merge only if ranges are adjacent
- **Out-of-range positions**: Kept separate unless adjacent to merge target

### Fee Handling

- **Auto-compound**: Collected swap fees reinvested into positions
- **Fee collection**: Uses `VaultFeeOracle` for protocol fee calculation
- **Protocol fees**: Handle `feeProtocol` from slot0 if governance enables (currently 0 on most chains)
- **No rewards**: Unlike Slipstream, V3 has no native reward system

### User Stories

**US-8.1: Single-Sided Token0 Deposit**
As a user, I want to deposit token0 into a Uniswap V3 vault so that I can earn trading fees without needing both tokens.

Acceptance Criteria:
- `exchangeIn(token0, amount, vaultToken)` accepts single-sided deposit
- If "above-price" NFT exists and is still above price: deposit into it
- If no suitable NFT: create new NFT with range above current price
- Range width calculated from historical TWAP volatility
- User receives vault shares proportional to liquidity added
- Protocol fee deducted per VaultFeeOracle

**US-8.2: Single-Sided Token1 Deposit**
As a user, I want to deposit token1 into a Uniswap V3 vault so that I can earn trading fees without needing both tokens.

Acceptance Criteria:
- `exchangeIn(token1, amount, vaultToken)` accepts single-sided deposit
- If "below-price" NFT exists and is still below price: deposit into it
- If no suitable NFT: create new NFT with range below current price
- Range width calculated from historical TWAP volatility
- User receives vault shares proportional to liquidity added

**US-8.3: Position State Transition**
As the vault, I want to correctly handle position state transitions when price moves so that deposits always go to the right NFT.

Acceptance Criteria:
- When intended "above-price" NFT becomes in-range:
  - Reassign as in-range NFT
  - Create new above-price NFT for new token0 deposits
- When intended "below-price" NFT becomes in-range:
  - Reassign as in-range NFT
  - Create new below-price NFT for new token1 deposits
- When in-range NFT goes out of range:
  - Reassign based on which direction price moved
  - Allow single-sided deposits to that NFT

**US-8.4: TWAP-Based Range Calculation**
As the vault, I want to calculate optimal tick ranges based on volatility so that positions capture fees efficiently.

Acceptance Criteria:
- Query V3 pool oracle via `observe()` for historical TWAP data
- Calculate volatility from price movement over lookback period
- Higher volatility → wider range (capture more price movement)
- Lower volatility → narrower range (concentrate liquidity)
- Range parameters configurable via VaultFeeOracle
- Tick ranges align to pool's tick spacing

**US-8.5: Position Consolidation**
As a keeper, I want to consolidate fragmented positions so that the vault operates efficiently.

Acceptance Criteria:
- `consolidate()` function callable by keeper or triggered by large deposits
- Large deposit threshold from VaultFeeOracle
- Only merge positions with adjacent tick ranges
- Out-of-range positions kept separate unless adjacent
- Gas-efficient: skip consolidation if cost exceeds benefit

**US-8.6: Fee Auto-Compound**
As a user, I want collected trading fees automatically reinvested so that my position compounds.

Acceptance Criteria:
- Swap fees collected from V3 positions via NPM's `collect()`
- Fees added back to appropriate NFT positions
- Protocol fee deducted before reinvestment
- Compound happens on deposits, withdrawals, or explicit collect call
- Handle `feeProtocol` if governance enables (currently 0)

**US-8.7: Withdrawal**
As a user, I want to withdraw my liquidity from the vault so that I can exit my position.

Acceptance Criteria:
- `exchangeIn(vaultToken, shares, tokenOut)` burns shares, returns tokens
- Withdrawal removes liquidity proportionally from all positions
- User can specify single token output (zap-out)
- If zap-out: vault swaps to desired token via V3 pool
- Minimum output enforced via slippage parameter

**US-8.8: Preview Functions**
As a user, I want to preview deposits and withdrawals so that I know what to expect.

Acceptance Criteria:
- `previewExchangeIn(token0, amount, vaultToken)` returns expected shares
- `previewExchangeIn(token1, amount, vaultToken)` returns expected shares
- `previewExchangeIn(vaultToken, shares, token0)` returns expected token0
- `previewExchangeIn(vaultToken, shares, token1)` returns expected token1
- Previews account for current price, position states, and fees
- Uses `UniswapV3Quoter` and `UniswapV3ZapQuoter` from Crane

### Files to Create

**Core Vault:**
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3StandardExchangeRepo.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3StandardExchangeCommon.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3StandardExchangeInTarget.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3StandardExchangeInFacet.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3StandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3StandardExchangeOutFacet.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3StandardExchangeDFPkg.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3Vault_Component_FactoryService.sol`

**Position Management:**
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3PositionManager.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3RangeCalculator.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/UniswapV3Consolidator.sol`

**Aware Repos (for NPM and Factory injection):**
- `contracts/protocols/dexes/uniswap/v3/UniswapV3NPMAwareRepo.sol`
- `contracts/protocols/dexes/uniswap/v3/UniswapV3FactoryAwareRepo.sol`

**Interfaces:**
- `contracts/interfaces/IUniswapV3StandardExchange.sol`
- `contracts/interfaces/proxies/IUniswapV3StandardExchangeProxy.sol`

**Tests:**
- `test/foundry/fork/ethereum_main/uniswapV3/UniswapV3StandardExchange_SingleSided.t.sol`
- `test/foundry/fork/ethereum_main/uniswapV3/UniswapV3StandardExchange_StateTransition.t.sol`
- `test/foundry/fork/ethereum_main/uniswapV3/UniswapV3StandardExchange_Consolidation.t.sol`
- `test/foundry/fork/ethereum_main/uniswapV3/UniswapV3StandardExchange_Compound.t.sol`
- `contracts/protocols/dexes/uniswap/v3/vault/TestBase_UniswapV3StandardExchange.sol`

### Inventory Check (Agent must verify)
- [ ] Crane's UniswapV3Utils library available and working
- [ ] Crane's UniswapV3Quoter library available and working
- [ ] Crane's UniswapV3ZapQuoter library available and working
- [ ] V3 NonfungiblePositionManager interface available
- [ ] V3 pool oracle (observe()) accessible
- [ ] VaultFeeOracle integration patterns from existing vaults
- [ ] Multi-NFT tracking patterns (ERC721 enumerable or custom)
- [ ] Fork test infrastructure for Ethereum mainnet (from Task 1)

### Implementation Clarifications

| Topic | Clarification |
|-------|---------------|
| **TWAP Lookback Period** | Configurable per-vault via VaultFeeOracle |
| **Tick Offset from Current Price** | Volatility-dependent: higher volatility = larger offset from current price |
| **Position Slot Full Scenario** | When all 3 slots occupied and none accept deposit token: rebalance the smallest overlapping-range position into above/below positions, apply volatility offset to new position |
| **Rebalance Fee** | Charge Usage Fee from VaultFeeOracle based on accrued fees as diluting vault shares |
| **Consolidation Threshold** | Tick density relative to pool average (total liquidity / active tick count) |
| **No TWAP Fallback** | If pool oracle lacks sufficient history, use spot price volatility calculation |
| **Minimum Deposit** | No minimum; handle dust gracefully via opportunistic consolidation |
| **Uncollected Fees** | Include in both preview and actual deposit/withdrawal calculations |

### Completion Criteria
- All user stories implemented and tested
- Fork tests against Ethereum mainnet pass
- Single-sided deposits work for both tokens
- Position state transitions handled correctly
- Consolidation merges adjacent ranges
- Auto-compound reinvests swap fees
- Multi-chain deployment packages ready (Ethereum, Arbitrum, Optimism, Polygon, Base)

---

## Task 9: Uniswap V4 Standard Exchange Vault

**Layer:** IndexedEx
**Worktree:** `feature/uniswap-v4-vault`
**Status:** Ready for Agent
**Fulfills:** Task 4 (partially)

### Description
Implement a Standard Exchange vault for Uniswap V4 (concentrated liquidity with PoolManager singleton) on Ethereum mainnet and L2s. This follows the same position management strategy as Tasks 7/8 but adapts to V4's unique architecture: centralized PoolManager, native ERC-6909 balances, and hook system.

### Dependencies
- Task 3 (Uniswap V4 Utils Library) must complete first
- Crane's `UniswapV4Utils`, `UniswapV4Quoter`, `UniswapV4ZapQuoter` libraries required

### Key V4 Architecture Differences from V3

| Aspect | Uniswap V3 | Uniswap V4 | Vault Impact |
|--------|-----------|------------|--------------|
| Pool Architecture | Individual pools deployed separately | Centralized PoolManager singleton | Interact with PoolManager, not pools |
| Position Storage | Pool stores positions, accessed via NonfungiblePositionManager | PoolManager stores positions via PoolKey | Track positions by PoolKey + tick range |
| Token Balances | Standard ERC20 transfers | ERC-6909 multi-token balance system | Native ERC-6909 integration |
| Fee Tiers | Fixed set (0.01%, 0.05%, 0.3%, 1%) | Dynamic, can be customized per pool | Match pool's fee tier |
| Hooks | Not available | Full hook system for custom logic | No hooks initially (simpler) |
| Callbacks | SwapCallback, MintCallback, FlashCallback | UnlockCallback pattern | Implement V4 callback pattern |
| Pool Identification | Address of deployed pool | PoolKey struct (currency0, currency1, fee, tickSpacing, hooks) | Use PoolKey for identification |

### Concentrated Liquidity Position States

| State | Price Condition | Holds | Accepts |
|-------|-----------------|-------|---------|
| **Below price** | current price < lower tick | 100% token1 | token1 only |
| **In range** | lower tick ≤ price ≤ upper tick | Both tokens | Both (in ratio) |
| **Above price** | current price > upper tick | 100% token0 | token0 only |

### Position Management Strategy

- **Max 3 active positions**: one per state (above/in/below price)
- **Track by PoolKey + tick range**: positions identified via V4's native system
- **On-demand creation**: new positions created only when deposit requires it
- **State transitions**: positions automatically transition as price moves
- **No hooks initially**: deploy to pools without custom hooks for simpler implementation

### V4 PoolManager Interaction Pattern

```
User deposits via exchangeIn()
  │
  ├── 1. Acquire lock via PoolManager.unlock()
  │       └── Callback: unlockCallback() is called
  │
  ├── 2. Inside callback:
  │       ├── Claim ERC-6909 balances from user (or transfer ERC20 → settle)
  │       ├── Modify position in PoolManager
  │       │     └── PoolManager.modifyLiquidity(poolKey, params, hookData)
  │       └── Handle any delta balances
  │
  └── 3. Mint vault shares to user
```

### ERC-6909 Integration

V4 uses ERC-6909 (multi-token standard) for internal balances:
- Token ID is derived from Currency (address for ERC20, 0 for native)
- Users can hold balances in PoolManager without withdrawing
- Vault accepts ERC-6909 balances directly OR standard ERC20 transfers
- Vault can settle balances (convert ERC-6909 → ERC20) or keep as ERC-6909

### Deposit Flow

```
User deposits tokenX via exchangeIn()
  │
  ├── If tokenX == token0:
  │     ├── Check for "above-price" position → add liquidity there
  │     └── If none: create new position with range above current price
  │
  ├── If tokenX == token1:
  │     ├── Check for "below-price" position → add liquidity there
  │     └── If none: create new position with range below current price
  │
  └── State transition handling:
        └── If intended "above-price" position is now in-range:
              → Reassign as in-range position
              → Create new above-price position for deposit
```

### Range Calculation

- **Width**: Based on historical TWAP volatility from V4 pool oracle
- **Formula**: Wider range in high volatility, narrower in low volatility
- **New positions**: Created just above/below current price with volatility-adjusted width
- **Tick spacing**: Must align to pool's tick spacing (defined in PoolKey)

### Multi-Chain Deployment

Each chain requires a separate Diamond Factory Package with chain-specific addresses:
- Ethereum Mainnet
- Arbitrum One
- Optimism
- Base
- Polygon (if V4 deployed)

Chain-specific configuration passed during vault instance initialization:
- PoolManager address
- Pool's PoolKey (currency0, currency1, fee, tickSpacing, hooks)
- WETH/wrapped native token address

### Consolidation

- **Triggers**:
  - Manual/keeper call
  - Large deposits (threshold from VaultFeeOracle)
- **Strategy**: Merge only if ranges are adjacent
- **Out-of-range positions**: Kept separate unless adjacent to merge target

### Fee Handling

- **Auto-compound**: Collected swap fees reinvested into positions
- **Fee collection**: Uses `VaultFeeOracle` for protocol fee calculation
- **Dynamic fees**: V4 pools may have dynamic fees; vault works with pool's configured fee
- **No hooks fee integration**: Skip hook-based fee modifications initially

### User Stories

**US-9.1: Single-Sided Token0 Deposit**
As a user, I want to deposit token0 into a Uniswap V4 vault so that I can earn trading fees without needing both tokens.

Acceptance Criteria:
- `exchangeIn(token0, amount, vaultToken)` accepts single-sided deposit
- If "above-price" position exists and is still above price: add liquidity there
- If no suitable position: create new position with range above current price
- Range width calculated from historical TWAP volatility
- User receives vault shares proportional to liquidity added
- Protocol fee deducted per VaultFeeOracle
- Works with both ERC20 transfers and ERC-6909 balances

**US-9.2: Single-Sided Token1 Deposit**
As a user, I want to deposit token1 into a Uniswap V4 vault so that I can earn trading fees without needing both tokens.

Acceptance Criteria:
- `exchangeIn(token1, amount, vaultToken)` accepts single-sided deposit
- If "below-price" position exists and is still below price: add liquidity there
- If no suitable position: create new position with range below current price
- Range width calculated from historical TWAP volatility
- User receives vault shares proportional to liquidity added
- Works with both ERC20 transfers and ERC-6909 balances

**US-9.3: Position State Transition**
As the vault, I want to correctly handle position state transitions when price moves so that deposits always go to the right position.

Acceptance Criteria:
- When intended "above-price" position becomes in-range:
  - Reassign as in-range position
  - Create new above-price position for new token0 deposits
- When intended "below-price" position becomes in-range:
  - Reassign as in-range position
  - Create new below-price position for new token1 deposits
- When in-range position goes out of range:
  - Reassign based on which direction price moved
  - Allow single-sided deposits to that position

**US-9.4: TWAP-Based Range Calculation**
As the vault, I want to calculate optimal tick ranges based on volatility so that positions capture fees efficiently.

Acceptance Criteria:
- Query V4 pool oracle for historical TWAP data
- Calculate volatility from price movement over lookback period
- Higher volatility → wider range (capture more price movement)
- Lower volatility → narrower range (concentrate liquidity)
- Range parameters configurable via VaultFeeOracle
- Tick ranges align to pool's tick spacing (from PoolKey)

**US-9.5: Position Consolidation**
As a keeper, I want to consolidate fragmented positions so that the vault operates efficiently.

Acceptance Criteria:
- `consolidate()` function callable by keeper or triggered by large deposits
- Large deposit threshold from VaultFeeOracle
- Only merge positions with adjacent tick ranges
- Out-of-range positions kept separate unless adjacent
- Gas-efficient: skip consolidation if cost exceeds benefit

**US-9.6: Fee Auto-Compound**
As a user, I want collected trading fees automatically reinvested so that my position compounds.

Acceptance Criteria:
- Swap fees collected from V4 positions via PoolManager
- Fees added back to appropriate positions
- Protocol fee deducted before reinvestment
- Compound happens on deposits, withdrawals, or explicit collect call
- Handle dynamic pool fees correctly

**US-9.7: Withdrawal**
As a user, I want to withdraw my liquidity from the vault so that I can exit my position.

Acceptance Criteria:
- `exchangeIn(vaultToken, shares, tokenOut)` burns shares, returns tokens
- Withdrawal removes liquidity proportionally from all positions
- User can specify single token output (zap-out)
- If zap-out: vault swaps to desired token via V4 pool
- Minimum output enforced via slippage parameter
- Returns as ERC20 (not ERC-6909 balances)

**US-9.8: Preview Functions**
As a user, I want to preview deposits and withdrawals so that I know what to expect.

Acceptance Criteria:
- `previewExchangeIn(token0, amount, vaultToken)` returns expected shares
- `previewExchangeIn(token1, amount, vaultToken)` returns expected shares
- `previewExchangeIn(vaultToken, shares, token0)` returns expected token0
- `previewExchangeIn(vaultToken, shares, token1)` returns expected token1
- Previews account for current price, position states, and fees
- Uses `UniswapV4Quoter` and `UniswapV4ZapQuoter` from Crane (Task 3)

**US-9.9: ERC-6909 Balance Support**
As a user with ERC-6909 balances in PoolManager, I want to deposit directly without settling to ERC20.

Acceptance Criteria:
- Vault accepts ERC-6909 claim transfers as deposit input
- Gas savings vs. ERC20 round-trip (no settle/take)
- `exchangeIn()` detects if user is transferring ERC-6909 or ERC20
- Preview functions work for both input types
- Vault's internal accounting handles both balance types

### Files to Create

**Core Vault:**
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4StandardExchangeRepo.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4StandardExchangeCommon.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4StandardExchangeInTarget.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4StandardExchangeInFacet.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4StandardExchangeOutTarget.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4StandardExchangeOutFacet.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4StandardExchangeDFPkg.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4Vault_Component_FactoryService.sol`

**Position Management:**
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4PositionManager.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4RangeCalculator.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4Consolidator.sol`

**V4 Integration:**
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4UnlockCallback.sol` - Implements IUnlockCallback
- `contracts/protocols/dexes/uniswap/v4/vault/UniswapV4BalanceManager.sol` - ERC-6909 balance handling

**Aware Repos (for PoolManager and PoolKey injection):**
- `contracts/protocols/dexes/uniswap/v4/UniswapV4PoolManagerAwareRepo.sol`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4PoolKeyAwareRepo.sol`

**Interfaces:**
- `contracts/interfaces/IUniswapV4StandardExchange.sol`
- `contracts/interfaces/proxies/IUniswapV4StandardExchangeProxy.sol`

**Tests:**
- `test/foundry/fork/ethereum_main/uniswapV4/UniswapV4StandardExchange_SingleSided.t.sol`
- `test/foundry/fork/ethereum_main/uniswapV4/UniswapV4StandardExchange_StateTransition.t.sol`
- `test/foundry/fork/ethereum_main/uniswapV4/UniswapV4StandardExchange_Consolidation.t.sol`
- `test/foundry/fork/ethereum_main/uniswapV4/UniswapV4StandardExchange_Compound.t.sol`
- `test/foundry/fork/ethereum_main/uniswapV4/UniswapV4StandardExchange_ERC6909.t.sol`
- `contracts/protocols/dexes/uniswap/v4/vault/TestBase_UniswapV4StandardExchange.sol`

### Inventory Check (Agent must verify)
- [ ] Task 3 complete: UniswapV4Utils library available and working
- [ ] Task 3 complete: UniswapV4Quoter library available and working
- [ ] Task 3 complete: UniswapV4ZapQuoter library available and working
- [ ] V4 PoolManager interface imported from v4-core
- [ ] V4 IUnlockCallback interface available
- [ ] ERC-6909 interface and implementation patterns understood
- [ ] V4 pool oracle (observe equivalent) accessible
- [ ] VaultFeeOracle integration patterns from existing vaults
- [ ] Position tracking patterns (by PoolKey + tick range)
- [ ] Fork test infrastructure for Ethereum mainnet

### Implementation Clarifications

| Topic | Clarification |
|-------|---------------|
| **TWAP Lookback Period** | Configurable per-vault via VaultFeeOracle |
| **Tick Offset from Current Price** | Volatility-dependent: higher volatility = larger offset from current price |
| **Position Slot Full Scenario** | When all 3 slots occupied and none accept deposit token: rebalance the smallest overlapping-range position into above/below positions, apply volatility offset to new position |
| **Rebalance Fee** | Charge Usage Fee from VaultFeeOracle based on accrued fees as diluting vault shares |
| **Consolidation Threshold** | Tick density relative to pool average (total liquidity / active tick count) |
| **No TWAP Fallback** | If pool oracle lacks sufficient history, use spot price volatility calculation |
| **Minimum Deposit** | No minimum; handle dust gracefully via opportunistic consolidation |
| **Uncollected Fees** | Include in both preview and actual deposit/withdrawal calculations |
| **ERC-6909 Detection** | Store relevant ERC-6909 address in vault config during initialization; check if `tokenIn` or `tokenOut` matches the stored address to determine input type |

### Completion Criteria
- All user stories implemented and tested
- Fork tests against Ethereum mainnet pass
- Single-sided deposits work for both tokens
- Position state transitions handled correctly
- Consolidation merges adjacent ranges
- Auto-compound reinvests swap fees
- ERC-6909 balance input/output supported
- Multi-chain deployment packages ready (Ethereum, Arbitrum, Optimism, Base)
- No hook integration (pools without hooks only)

---

## Task 11: Aerodrome V1 Package deployVault with Pool Creation and Initial Deposit

**Layer:** IndexedEx
**Worktree:** `feature/aerodrome-deploy-with-pool`
**Status:** Ready for Agent

### Description
Add a new `deployVault(tokenA, tokenAAmount, tokenB, tokenBAmount, recipient)` function to the Aerodrome V1 Standard Exchange Package. This function creates a new volatile pool via the Aerodrome factory (if one doesn't exist), optionally performs an initial deposit, deploys the vault, and deposits LP tokens to the vault on behalf of the recipient.

### New Function Signature

```solidity
function deployVault(
    IERC20 tokenA,
    uint256 tokenAAmount,
    IERC20 tokenB,
    uint256 tokenBAmount,
    address recipient
) external returns (address vault);
```

### Workflow

```
User calls deployVault(tokenA, tokenAAmount, tokenB, tokenBAmount, recipient)
  │
  ├── 1. Check if volatile pool exists via factory.getPool(tokenA, tokenB, false)
  │     ├── If no pool: factory.createPool(tokenA, tokenB, false)
  │     └── If pool exists: use existing pool
  │
  ├── 2. Get pool reserves and determine if initial deposit requested
  │     └── If tokenAAmount > 0 AND tokenBAmount > 0 AND recipient != address(0):
  │           │
  │           ├── Calculate proportional amounts based on pool reserves
  │           │   └── If newly created pool (reserves = 0): use provided amounts as-is
  │           │   └── If existing pool: calculate max proportional from provided amounts
  │           │
  │           ├── transferFrom(msg.sender, pool, proportionalAmountA)
  │           ├── transferFrom(msg.sender, pool, proportionalAmountB)
  │           └── pool.mint(address(this)) → LP tokens minted to Package
  │
  ├── 3. Deploy vault via existing deployVault(pool)
  │     └── vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(...)
  │
  ├── 4. If LP tokens were minted in step 2:
  │     ├── Approve vault for LP tokens
  │     ├── Call vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, true, deadline)
  │     └── Recipient receives vault shares
  │
  └── 5. Return vault address
```

### Package Changes

**Add to PkgInit struct:**
```solidity
IPoolFactory aerodromePoolFactory;  // Add factory reference
```

**Add immutable storage:**
```solidity
IPoolFactory public immutable AERODROME_POOL_FACTORY;
```

### User Stories

**US-11.1: Create New Pool and Deploy Vault**
As a user, I want to deploy a vault for a token pair that doesn't have an existing pool so that I can be the first liquidity provider.

Acceptance Criteria:
- `deployVault(tokenA, 0, tokenB, 0, address(0))` creates pool and vault without initial deposit
- Pool created as volatile (stable = false)
- Vault deployed and registered with VaultRegistry
- Returns vault address

**US-11.2: Create Pool with Initial Deposit**
As a user, I want to create a new pool with initial liquidity and receive vault shares so that I can start earning fees immediately.

Acceptance Criteria:
- `deployVault(tokenA, amountA, tokenB, amountB, recipient)` creates pool with liquidity
- Both tokens transferred from caller (via transferFrom)
- LP tokens minted and deposited to vault
- Recipient receives vault shares proportional to liquidity
- Vault registered with VaultRegistry

**US-11.3: Deploy Vault for Existing Pool with Proportional Deposit**
As a user, I want to deploy a vault for an existing pool and make an initial proportional deposit.

Acceptance Criteria:
- If pool exists, use existing pool
- Calculate proportional amounts based on current reserves
- Transfer only proportional amounts (excess stays with caller)
- Deposit LP to vault, recipient receives shares
- Works regardless of whether pool was newly created or existed

**US-11.4: Deploy Vault for Existing Pool Without Deposit**
As a user, I want to deploy a vault for an existing pool without providing initial liquidity.

Acceptance Criteria:
- `deployVault(tokenA, 0, tokenB, 0, address(0))` with existing pool
- No token transfers occur
- Vault deployed and registered
- Returns vault address

**US-11.5: Preview Proportional Calculation**
As a user, I want to know how much of each token will be used before calling deployVault.

Acceptance Criteria:
- Add `previewDeployVault(tokenA, amountA, tokenB, amountB)` view function
- Returns: (poolExists, proportionalA, proportionalB, expectedLP)
- Uses pool reserves to calculate proportional amounts
- If pool doesn't exist, returns provided amounts as proportional

### Files to Modify

**Modified Files:**
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol` - Add new deployVault function and PkgInit changes
- `contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol` - Update buildArgs and deploy functions for factory param
- `contracts/interfaces/IAerodromeStandardExchangeDFPkg.sol` - Add new interface function

**Tests:**
- `test/foundry/spec/protocol/dexes/aerodrome/v1/AerodromeStandardExchange_DeployWithPool.t.sol` - New test file
- Modify `contracts/protocols/dexes/aerodrome/v1/test/bases/TestBase_AerodromeStandardExchange.sol` - Update PkgInit with factory

### Inventory Check (Agent must verify)
- [ ] Current AerodromeStandardExchangeDFPkg.deployVault(pool) works correctly
- [ ] IPoolFactory.createPool(tokenA, tokenB, stable) interface available
- [ ] IPoolFactory.getPool(tokenA, tokenB, stable) returns address(0) if not exists
- [ ] Pool.mint() callable after direct token transfer
- [ ] Vault.exchangeIn() with pretransferred=true works for LP deposits
- [ ] FactoryService pattern understood for adding new constructor args

### Completion Criteria
- New deployVault function compiles and works
- Can create new pool and vault in single transaction
- Can deploy vault for existing pool
- Proportional deposit calculated correctly
- Excess tokens stay with caller (not transferred)
- Fork tests against Base mainnet pass
- Existing deployVault(pool) function still works

---

## Task 12: Camelot V2 Package deployVault with Pool Creation and Initial Deposit

**Layer:** IndexedEx
**Worktree:** `feature/camelot-deploy-with-pool`
**Status:** Ready for Agent

### Description
Add a new `deployVault(tokenA, tokenAAmount, tokenB, tokenBAmount, recipient)` function to the Camelot V2 Standard Exchange Package. This function creates a new pair via the Camelot factory (if one doesn't exist), optionally performs an initial deposit, deploys the vault, and deposits LP tokens to the vault on behalf of the recipient.

### New Function Signature

```solidity
function deployVault(
    IERC20 tokenA,
    uint256 tokenAAmount,
    IERC20 tokenB,
    uint256 tokenBAmount,
    address recipient
) external returns (address vault);
```

### Workflow

```
User calls deployVault(tokenA, tokenAAmount, tokenB, tokenBAmount, recipient)
  │
  ├── 1. Check if pair exists via factory.getPair(tokenA, tokenB)
  │     ├── If no pair: factory.createPair(tokenA, tokenB)
  │     └── If pair exists: use existing pair
  │
  ├── 2. Get pair reserves and determine if initial deposit requested
  │     └── If tokenAAmount > 0 AND tokenBAmount > 0 AND recipient != address(0):
  │           │
  │           ├── Calculate proportional amounts based on pair reserves
  │           │   └── If newly created pair (reserves = 0): use provided amounts as-is
  │           │   └── If existing pair: calculate max proportional from provided amounts
  │           │
  │           ├── transferFrom(msg.sender, pair, proportionalAmountA)
  │           ├── transferFrom(msg.sender, pair, proportionalAmountB)
  │           └── pair.mint(address(this)) → LP tokens minted to Package
  │
  ├── 3. Deploy vault via existing deployVault(pair)
  │     └── vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(...)
  │
  ├── 4. If LP tokens were minted in step 2:
  │     ├── Approve vault for LP tokens
  │     ├── Call vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, true, deadline)
  │     └── Recipient receives vault shares
  │
  └── 5. Return vault address
```

### Package Changes

**Add to PkgInit struct:**
```solidity
ICamelotFactory camelotFactory;  // Add factory reference
```

**Add immutable storage:**
```solidity
ICamelotFactory public immutable CAMELOT_FACTORY;
```

### User Stories

**US-12.1: Create New Pair and Deploy Vault**
As a user, I want to deploy a vault for a token pair that doesn't have an existing Camelot pair so that I can be the first liquidity provider.

Acceptance Criteria:
- `deployVault(tokenA, 0, tokenB, 0, address(0))` creates pair and vault without initial deposit
- Pair created via Camelot factory
- Vault deployed and registered with VaultRegistry
- Returns vault address

**US-12.2: Create Pair with Initial Deposit**
As a user, I want to create a new pair with initial liquidity and receive vault shares so that I can start earning fees immediately.

Acceptance Criteria:
- `deployVault(tokenA, amountA, tokenB, amountB, recipient)` creates pair with liquidity
- Both tokens transferred from caller (via transferFrom)
- LP tokens minted and deposited to vault
- Recipient receives vault shares proportional to liquidity
- Vault registered with VaultRegistry

**US-12.3: Deploy Vault for Existing Pair with Proportional Deposit**
As a user, I want to deploy a vault for an existing Camelot pair and make an initial proportional deposit.

Acceptance Criteria:
- If pair exists, use existing pair
- Calculate proportional amounts based on current reserves
- Transfer only proportional amounts (excess stays with caller)
- Deposit LP to vault, recipient receives shares
- Works regardless of whether pair was newly created or existed

**US-12.4: Deploy Vault for Existing Pair Without Deposit**
As a user, I want to deploy a vault for an existing Camelot pair without providing initial liquidity.

Acceptance Criteria:
- `deployVault(tokenA, 0, tokenB, 0, address(0))` with existing pair
- No token transfers occur
- Vault deployed and registered
- Returns vault address

**US-12.5: Preview Proportional Calculation**
As a user, I want to know how much of each token will be used before calling deployVault.

Acceptance Criteria:
- Add `previewDeployVault(tokenA, amountA, tokenB, amountB)` view function
- Returns: (pairExists, proportionalA, proportionalB, expectedLP)
- Uses pair reserves to calculate proportional amounts
- If pair doesn't exist, returns provided amounts as proportional

### Files to Modify

**Modified Files:**
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol` - Add new deployVault function and PkgInit changes
- `contracts/protocols/dexes/camelot/v2/CamelotV2_Component_FactoryService.sol` - Update buildArgs and deploy functions for factory param
- `contracts/interfaces/ICamelotV2StandardExchangeDFPkg.sol` - Add new interface function

**Tests:**
- `test/foundry/spec/protocol/dexes/camelot/v2/CamelotV2StandardExchange_DeployWithPool.t.sol` - New test file
- Modify `contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange.sol` - Update PkgInit with factory

### Inventory Check (Agent must verify)
- [ ] Current CamelotV2StandardExchangeDFPkg.deployVault(pair) works correctly
- [ ] ICamelotFactory.createPair(tokenA, tokenB) interface available
- [ ] ICamelotFactory.getPair(tokenA, tokenB) returns address(0) if not exists
- [ ] CamelotPair.mint() callable after direct token transfer
- [ ] Vault.exchangeIn() with pretransferred=true works for LP deposits
- [ ] FactoryService pattern understood for adding new constructor args

### Completion Criteria
- New deployVault function compiles and works
- Can create new pair and vault in single transaction
- Can deploy vault for existing pair
- Proportional deposit calculated correctly
- Excess tokens stay with caller (not transferred)
- All tests pass
- Existing deployVault(pair) function still works

---

## Task 13: Uniswap V2 Package deployVault with Pool Creation and Initial Deposit

**Layer:** IndexedEx
**Worktree:** `feature/uniswap-v2-deploy-with-pool`
**Status:** Ready for Agent

### Description
Add a new `deployVault(tokenA, tokenAAmount, tokenB, tokenBAmount, recipient)` function to the Uniswap V2 Standard Exchange Package. This function creates a new pair via the Uniswap V2 factory (if one doesn't exist), optionally performs an initial deposit, deploys the vault, and deposits LP tokens to the vault on behalf of the recipient.

### New Function Signature

```solidity
function deployVault(
    IERC20 tokenA,
    uint256 tokenAAmount,
    IERC20 tokenB,
    uint256 tokenBAmount,
    address recipient
) external returns (address vault);
```

### Workflow

```
User calls deployVault(tokenA, tokenAAmount, tokenB, tokenBAmount, recipient)
  │
  ├── 1. Check if pair exists via factory.getPair(tokenA, tokenB)
  │     ├── If no pair: factory.createPair(tokenA, tokenB)
  │     └── If pair exists: use existing pair
  │
  ├── 2. Get pair reserves and determine if initial deposit requested
  │     └── If tokenAAmount > 0 AND tokenBAmount > 0 AND recipient != address(0):
  │           │
  │           ├── Calculate proportional amounts based on pair reserves
  │           │   └── If newly created pair (reserves = 0): use provided amounts as-is
  │           │   └── If existing pair: calculate max proportional from provided amounts
  │           │
  │           ├── transferFrom(msg.sender, pair, proportionalAmountA)
  │           ├── transferFrom(msg.sender, pair, proportionalAmountB)
  │           └── pair.mint(address(this)) → LP tokens minted to Package
  │
  ├── 3. Deploy vault via existing deployVault(pair)
  │     └── vault = VAULT_REGISTRY_DEPLOYMENT.deployVault(...)
  │
  ├── 4. If LP tokens were minted in step 2:
  │     ├── Approve vault for LP tokens
  │     ├── Call vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, true, deadline)
  │     └── Recipient receives vault shares
  │
  └── 5. Return vault address
```

**Note:** This is the Uniswap V2 version. See Task 11 for Aerodrome V1, Task 12 for Camelot V2.

### Package Changes

**Note:** Uniswap V2 already has `UNISWAP_V2_FACTORY` in PkgInit, so only minimal changes needed.

**Verify existing PkgInit includes:**
```solidity
IUniswapV2Factory uniswapV2Factory;  // Already present
```

### User Stories

**US-13.1: Create New Pair and Deploy Vault**
As a user, I want to deploy a vault for a token pair that doesn't have an existing Uniswap V2 pair so that I can be the first liquidity provider.

Acceptance Criteria:
- `deployVault(tokenA, 0, tokenB, 0, address(0))` creates pair and vault without initial deposit
- Pair created via Uniswap V2 factory
- Vault deployed and registered with VaultRegistry
- Returns vault address

**US-13.2: Create Pair with Initial Deposit**
As a user, I want to create a new pair with initial liquidity and receive vault shares so that I can start earning fees immediately.

Acceptance Criteria:
- `deployVault(tokenA, amountA, tokenB, amountB, recipient)` creates pair with liquidity
- Both tokens transferred from caller (via transferFrom)
- LP tokens minted and deposited to vault
- Recipient receives vault shares proportional to liquidity
- Vault registered with VaultRegistry

**US-13.3: Deploy Vault for Existing Pair with Proportional Deposit**
As a user, I want to deploy a vault for an existing Uniswap V2 pair and make an initial proportional deposit.

Acceptance Criteria:
- If pair exists, use existing pair
- Calculate proportional amounts based on current reserves
- Transfer only proportional amounts (excess stays with caller)
- Deposit LP to vault, recipient receives shares
- Works regardless of whether pair was newly created or existed

**US-13.4: Deploy Vault for Existing Pair Without Deposit**
As a user, I want to deploy a vault for an existing Uniswap V2 pair without providing initial liquidity.

Acceptance Criteria:
- `deployVault(tokenA, 0, tokenB, 0, address(0))` with existing pair
- No token transfers occur
- Vault deployed and registered
- Returns vault address

**US-13.5: Preview Proportional Calculation**
As a user, I want to know how much of each token will be used before calling deployVault.

Acceptance Criteria:
- Add `previewDeployVault(tokenA, amountA, tokenB, amountB)` view function
- Returns: (pairExists, proportionalA, proportionalB, expectedLP)
- Uses pair reserves to calculate proportional amounts
- If pair doesn't exist, returns provided amounts as proportional

### Files to Modify

**Modified Files:**
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol` - Add new deployVault function
- `contracts/interfaces/IUniswapV2StandardExchangeDFPkg.sol` - Add new interface function

**Note:** FactoryService may not need changes if factory is already in PkgInit

**Tests:**
- `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_DeployWithPool.t.sol` - New test file
- Modify `contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange.sol` if needed

### Inventory Check (Agent must verify)
- [ ] UNISWAP_V2_FACTORY already in PkgInit (confirm or add)
- [ ] Current UniswapV2StandardExchangeDFPkg.deployVault(pair) works correctly
- [ ] IUniswapV2Factory.createPair(tokenA, tokenB) interface available
- [ ] IUniswapV2Factory.getPair(tokenA, tokenB) returns address(0) if not exists
- [ ] UniswapV2Pair.mint() callable after direct token transfer
- [ ] Vault.exchangeIn() with pretransferred=true works for LP deposits

### Completion Criteria
- New deployVault function compiles and works
- Can create new pair and vault in single transaction
- Can deploy vault for existing pair
- Proportional deposit calculated correctly
- Excess tokens stay with caller (not transferred)
- All tests pass
- Existing deployVault(pair) function still works

---

## Task 14: Deployment Scripts for Crane Factories, IndexedEx Core, and Vault Packages

**Layer:** IndexedEx
**Worktree:** `feature/deployment-scripts`
**Status:** Ready for Agent

### Description
Create a comprehensive suite of Foundry deployment scripts for deploying the full IndexedEx stack across Base and Ethereum mainnets. Scripts are staged (factories → core → vault packages → vault instances) and persist deployment addresses to JSON files. Each network has its own configuration, and vault instance scripts are segmented by chain and DEX.

### Target Networks

| Network | Chain ID | DEXes Available |
|---------|----------|-----------------|
| Base Mainnet | 8453 | Aerodrome V1, Uniswap V2, Balancer V3 |
| Ethereum Mainnet | 1 | Uniswap V2, Balancer V3 |

### Directory Structure

```
scripts/foundry/
├── deployments/                         # Persisted deployment state
│   ├── 1.json                           # Ethereum mainnet deployments
│   └── 8453.json                        # Base mainnet deployments
│
├── config/                              # Network-specific configuration
│   ├── NetworkConfig.sol                # Base contract with network detection
│   ├── EthereumMainConfig.sol           # Ethereum addresses and settings
│   └── BaseMainConfig.sol               # Base addresses and settings
│
├── lib/                                 # Shared deployment utilities
│   ├── DeploymentState.sol              # JSON read/write for deployment state
│   ├── DeploymentUtils.sol              # Common deployment helpers
│   └── IndexedexDeployLib.sol           # Indexedex-specific deployment logic
│
├── stages/                              # Staged deployment scripts
│   ├── 01_CraneFactories.s.sol          # Deploy Create3Factory + DiamondPackageFactory
│   ├── 02_CoreFacets.s.sol              # Deploy shared facets (ERC20, ERC165, etc.)
│   ├── 03_FeeCollector.s.sol            # Deploy FeeCollector package + instance
│   ├── 04_IndexedexManager.s.sol        # Deploy IndexedexManager package + instance
│   └── 05_VaultComponents.s.sol         # Deploy shared vault facets
│
├── packages/                            # Vault package deployment
│   ├── base/                            # Base mainnet packages
│   │   ├── AerodromeV1Pkg.s.sol         # Aerodrome Standard Exchange Package
│   │   ├── UniswapV2Pkg.s.sol           # Uniswap V2 Package (Base)
│   │   └── BalancerV3RouterPkg.s.sol    # Balancer V3 Router Package
│   └── ethereum/                        # Ethereum mainnet packages
│       ├── UniswapV2Pkg.s.sol           # Uniswap V2 Package (Ethereum)
│       └── BalancerV3RouterPkg.s.sol    # Balancer V3 Router Package
│
├── vaults/                              # Vault instance deployment
│   ├── base/                            # Base vault instances
│   │   ├── aerodrome/                   # Aerodrome vaults
│   │   │   └── DeployVault.s.sol        # Deploy vault for specific pool
│   │   ├── uniswap-v2/                  # Uniswap V2 vaults on Base
│   │   │   └── DeployVault.s.sol
│   │   └── balancer-v3/                 # Balancer V3 vaults on Base
│   │       └── DeployVault.s.sol
│   └── ethereum/                        # Ethereum vault instances
│       ├── uniswap-v2/
│       │   └── DeployVault.s.sol
│       └── balancer-v3/
│           └── DeployVault.s.sol
│
└── full/                                # Complete deployment scripts
    ├── DeployAll_Base.s.sol             # Full Base deployment (all stages)
    └── DeployAll_Ethereum.s.sol         # Full Ethereum deployment (all stages)
```

### Deployment State JSON Format

```json
{
  "chainId": 8453,
  "network": "base",
  "deployedAt": "2026-01-10T12:00:00Z",
  "deployer": "0x...",
  "owner": "0x...",

  "factories": {
    "create3Factory": "0x...",
    "diamondPackageFactory": "0x..."
  },

  "core": {
    "feeCollectorDFPkg": "0x...",
    "feeCollector": "0x...",
    "indexedexManagerDFPkg": "0x...",
    "indexedexManager": "0x..."
  },

  "facets": {
    "multiStepOwnableFacet": "0x...",
    "diamondCutFacet": "0x...",
    "erc20Facet": "0x...",
    "erc2612Facet": "0x...",
    "erc4626Facet": "0x..."
  },

  "packages": {
    "aerodromeV1StandardExchange": "0x...",
    "uniswapV2StandardExchange": "0x...",
    "balancerV3Router": "0x..."
  },

  "vaults": {
    "aerodrome": {
      "WETH-USDC": "0x..."
    }
  }
}
```

### User Stories

**US-14.1: Deploy Crane Factories**
As a deployer, I want to deploy the Crane factory infrastructure so that I can deploy IndexedEx components with deterministic addresses.

Acceptance Criteria:
- Script deploys Create3Factory with deployer as owner
- Script deploys DiamondPackageCallBackFactory with required facets
- Create3Factory is linked to DiamondPackageFactory
- Addresses persisted to `deployments/{chainId}.json`
- Script is idempotent (skips if already deployed)

**US-14.2: Deploy Core Facets**
As a deployer, I want to deploy all shared facets in a single transaction batch so that packages can reference them.

Acceptance Criteria:
- Deploys all facets from `AccessFacetFactoryService`
- Deploys all facets from `IntrospectionFacetFactoryService`
- Deploys all facets from `VaultComponentFactoryService`
- Each facet uses deterministic salt from type name
- Facets registered in Create3Factory registry

**US-14.3: Deploy FeeCollector**
As a deployer, I want to deploy the FeeCollector system so that vaults can route fees to it.

Acceptance Criteria:
- Deploys FeeCollector facets
- Deploys FeeCollectorDFPkg with facet references
- Deploys FeeCollector proxy instance via DiamondPackageFactory
- Owner set correctly on FeeCollector

**US-14.4: Deploy IndexedexManager**
As a deployer, I want to deploy the IndexedexManager so that vaults can be registered and discovered.

Acceptance Criteria:
- Deploys all VaultRegistry and VaultFeeOracle facets
- Deploys IndexedexManagerDFPkg
- Deploys IndexedexManager proxy with FeeCollector reference
- IndexedexManager granted operator rights on Create3Factory

**US-14.5: Deploy Vault Packages (Per Network)**
As a deployer, I want to deploy vault packages for each DEX available on the target network.

Acceptance Criteria:
- Base: Aerodrome V1, Uniswap V2, Balancer V3 Router packages
- Ethereum: Uniswap V2, Balancer V3 Router packages
- Packages registered with IndexedexManager
- Protocol addresses sourced from network constants (BASE_MAIN, ETH_MAIN)

**US-14.6: Deploy Vault Instances**
As a deployer, I want to deploy vault instances for specific pools/pairs on each network.

Acceptance Criteria:
- Vault deployment scripts accept pool/pair address as input
- Script calls package.deployVault(pool) via IndexedexManager
- Vault registered in VaultRegistry
- Separate scripts per chain/DEX combination

**US-14.7: Full Deployment Script**
As a deployer, I want a single script that runs all stages for a complete network deployment.

Acceptance Criteria:
- `DeployAll_Base.s.sol` runs stages 01-05 + all Base packages
- `DeployAll_Ethereum.s.sol` runs stages 01-05 + all Ethereum packages
- Each stage checks deployment state and skips if already complete
- Final output summarizes all deployed addresses

### Files to Create

**Configuration:**
- `scripts/foundry/config/NetworkConfig.sol` - Base contract with chainId detection
- `scripts/foundry/config/EthereumMainConfig.sol` - ETH_MAIN protocol addresses
- `scripts/foundry/config/BaseMainConfig.sol` - BASE_MAIN protocol addresses

**Utilities:**
- `scripts/foundry/lib/DeploymentState.sol` - JSON read/write for deployment state
- `scripts/foundry/lib/DeploymentUtils.sol` - Common deployment helpers
- `scripts/foundry/lib/IndexedexDeployLib.sol` - Indexedex deployment logic

**Staged Scripts:**
- `scripts/foundry/stages/01_CraneFactories.s.sol`
- `scripts/foundry/stages/02_CoreFacets.s.sol`
- `scripts/foundry/stages/03_FeeCollector.s.sol`
- `scripts/foundry/stages/04_IndexedexManager.s.sol`
- `scripts/foundry/stages/05_VaultComponents.s.sol`

**Package Scripts:**
- `scripts/foundry/packages/base/AerodromeV1Pkg.s.sol`
- `scripts/foundry/packages/base/UniswapV2Pkg.s.sol`
- `scripts/foundry/packages/base/BalancerV3RouterPkg.s.sol`
- `scripts/foundry/packages/ethereum/UniswapV2Pkg.s.sol`
- `scripts/foundry/packages/ethereum/BalancerV3RouterPkg.s.sol`

**Vault Instance Scripts:**
- `scripts/foundry/vaults/base/aerodrome/DeployVault.s.sol`
- `scripts/foundry/vaults/base/uniswap-v2/DeployVault.s.sol`
- `scripts/foundry/vaults/base/balancer-v3/DeployVault.s.sol`
- `scripts/foundry/vaults/ethereum/uniswap-v2/DeployVault.s.sol`
- `scripts/foundry/vaults/ethereum/balancer-v3/DeployVault.s.sol`

**Full Deployment:**
- `scripts/foundry/full/DeployAll_Base.s.sol`
- `scripts/foundry/full/DeployAll_Ethereum.s.sol`

### Files to Modify

- `foundry.toml` - Add fs_permissions for JSON read/write if needed

### Inventory Check (Agent must verify)
- [ ] Existing `Script_BaseMain_DeployIndexedex.s.sol` patterns are understood
- [ ] All FactoryService libraries exist and compile
- [ ] Network constants (BASE_MAIN, ETH_MAIN) have required protocol addresses
- [ ] `forge script` supports JSON file operations via `vm.readFile`/`vm.writeFile`
- [ ] Camelot V2 is NOT on Base or Ethereum (only Arbitrum) - excluded from this task

### Completion Criteria
- All staged scripts compile and can be run individually
- `DeployAll_Base.s.sol` successfully deploys full stack on Base fork
- `DeployAll_Ethereum.s.sol` successfully deploys full stack on Ethereum fork
- Deployment state JSON files are created and readable
- Idempotent: re-running scripts skips already-deployed contracts
- Vault instance scripts work for specific pools
- All console output includes deployed addresses

---

## Task 15: Review — IndexedEx Test Harness and Test Quality

**Layer:** IndexedEx
**Worktree:** `review/idx-test-harness-and-quality`
**Status:** Ready for Agent

### Description
Review the IndexedEx Foundry test harness and test patterns for correctness, determinism, and trustworthiness. The goal is to ensure tests catch real regressions and are not overly reliant on fork state, implicit assumptions, or weak assertions.

### Dependencies
- None

### User Stories

**US-15.1: Produce a test harness trust memo**
As a maintainer, I want a clear analysis of how tests are structured and what they actually guarantee so that I can trust failures and green builds.

Acceptance Criteria:
- Memo written with top failure modes (false positives/negatives, flakiness, missing negative tests)
- Memo identifies the most important shared fixtures/helpers and how they are used

**US-15.2: Strengthen at least one weak test**
As a maintainer, I want at least one concrete improvement to an existing test so that the suite becomes more meaningful immediately.

Acceptance Criteria:
- Add at least one targeted assertion or negative test (revert/edge case) to an existing spec test
- `forge test` passes

### Files to Create/Modify

**New Files:**
- `docs/review/test-harness.md` - Review memo and prioritized improvements

**Potentially Modified Files:**
- `test/foundry/**` - Tighten assertions, add negative test(s), reduce flaky assumptions

### Inventory Check (Agent must verify)
- [ ] How forks are configured under `test/foundry/fork/`
- [ ] How spec tests are organized under `test/foundry/spec/`
- [ ] What the primary shared test bases are (search `TestBase_`)

### Completion Criteria
- Memo exists and includes a prioritized “Top 5 improvements” list
- At least one concrete test improvement merged in this task
- `forge build` and `forge test` pass

---

## Task 16: Review — Seigniorage Vaults Correctness and Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-seigniorage-vaults-review`
**Status:** Ready for Agent

### Description
Review the seigniorage vault implementation for correctness and coverage. Identify invariants and potential edge cases, then ensure test coverage validates the intended behavior.

### Dependencies
- None

### User Stories

**US-16.1: Document invariants and risks**
As a maintainer, I want a written set of invariants/threat-model assumptions so that the vault logic is reviewable and testable.

Acceptance Criteria:
- Memo lists key invariants (accounting, access control, state transitions)
- Memo lists external dependencies and assumptions

**US-16.2: Add at least one missing spec test**
As a maintainer, I want at least one new spec test covering a high-risk behavior so that regressions are caught.

Acceptance Criteria:
- Add at least one new spec test or expand an existing one
- `forge test` passes

### Files to Create/Modify

**New Files:**
- `docs/review/seigniorage-vaults.md` - Review memo + test gap list

**Potentially Modified Files:**
- `test/foundry/spec/**` - Add/extend spec tests

### Inventory Check (Agent must verify)
- [ ] Review `contracts/vaults/seigniorage/**` and map the main state transitions
- [ ] Locate existing tests (search `Seigniorage` under `test/foundry/`)

### Completion Criteria
- Memo exists with prioritized test gaps
- At least one spec test improvement included
- `forge build` and `forge test` pass

---

## Task 17: Review — Slipstream Vault Correctness and Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-slipstream-vault-review`
**Status:** Ready for Agent

### Description
Review the Slipstream-related IndexedEx vault code for correctness and test coverage, focusing on quoting correctness, accounting invariants, NFT position handling, and slippage/rounding edge cases.

### Dependencies
- Crane Task C-4 must complete first (see `lib/daosys/lib/crane/UNIFIED_PLAN.md`)

### User Stories

**US-17.1: Produce a correctness + test gap memo**
As a maintainer, I want a review memo describing Slipstream vault invariants and missing tests so that we can rely on this code.

Acceptance Criteria:
- Memo lists top invariants + common failure modes
- Memo lists missing tests and the recommended test types (unit/spec/fuzz)

### Files to Create/Modify

**New Files:**
- `docs/review/slipstream-vault.md` - Review memo + prioritized test checklist

### Inventory Check (Agent must verify)
- [ ] Identify Slipstream-related contracts under `contracts/protocols/dexes/aerodrome/` and any `Slipstream*` types
- [ ] Locate existing Slipstream spec tests under `test/foundry/spec/protocol/dexes/**`

### Completion Criteria
- Memo exists with a prioritized “trust checklist” for tests

---

## Task 18: Review — Uniswap V2 Vault Correctness and Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-uniswap-v2-vault-review`
**Status:** Ready for Agent

### Description
Review the Uniswap V2 vault code and tests for correctness, especially around pool interactions, LP math, and deposit/withdraw edge cases.

### Dependencies
- Crane Task C-4 must complete first (see `lib/daosys/lib/crane/UNIFIED_PLAN.md`)

### User Stories

**US-18.1: Produce a correctness + test gap memo**
As a maintainer, I want a review memo describing Uniswap V2 vault invariants and missing tests so that we can rely on this code.

Acceptance Criteria:
- Memo lists invariants and missing tests

### Files to Create/Modify

**New Files:**
- `docs/review/uniswap-v2-vault.md` - Review memo

### Completion Criteria
- Memo exists

---

## Task 19: Review — Uniswap V3 Vault Correctness and Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-uniswap-v3-vault-review`
**Status:** Ready for Agent

### Description
Review the Uniswap V3 vault code and tests for correctness, focusing on quote correctness, rounding, tick/price boundary handling, and revert expectations.

### Dependencies
- Crane Task C-4 must complete first (see `lib/daosys/lib/crane/UNIFIED_PLAN.md`)

### User Stories

**US-19.1: Produce a correctness + test gap memo**
As a maintainer, I want a review memo describing Uniswap V3 vault invariants and missing tests so that we can rely on this code.

Acceptance Criteria:
- Memo lists invariants and missing tests

### Files to Create/Modify

**New Files:**
- `docs/review/uniswap-v3-vault.md` - Review memo

### Completion Criteria
- Memo exists

---

## Task 20: Review — Uniswap V4 Vault Correctness and Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-uniswap-v4-vault-review`
**Status:** Ready for Agent

### Description
Review the Uniswap V4 vault code and tests for correctness, focusing on hook interactions (if any), quote correctness, and revert/edge-case coverage.

### Dependencies
- Crane Task C-4 must complete first (see `lib/daosys/lib/crane/UNIFIED_PLAN.md`)

### User Stories

**US-20.1: Produce a correctness + test gap memo**
As a maintainer, I want a review memo describing Uniswap V4 vault invariants and missing tests so that we can rely on this code.

Acceptance Criteria:
- Memo lists invariants and missing tests

### Files to Create/Modify

**New Files:**
- `docs/review/uniswap-v4-vault.md` - Review memo

### Completion Criteria
- Memo exists

---

## Task 21: Review — Aerodrome Vault Correctness and Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-aerodrome-vault-review`
**Status:** Ready for Agent

### Description
Review Aerodrome vault code and tests for correctness, focusing on pool math, fee accounting, and edge-case coverage.

### Dependencies
- Crane Task C-4 must complete first (see `lib/daosys/lib/crane/UNIFIED_PLAN.md`)

### User Stories

**US-21.1: Produce a correctness + test gap memo**
As a maintainer, I want a review memo describing Aerodrome vault invariants and missing tests so that we can rely on this code.

Acceptance Criteria:
- Memo lists invariants and missing tests

### Files to Create/Modify

**New Files:**
- `docs/review/aerodrome-vault.md` - Review memo

### Completion Criteria
- Memo exists

---

## Task 22: Review — Camelot V2 Vault Correctness and Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-camelot-v2-vault-review`
**Status:** Ready for Agent

### Description
Review Camelot V2 vault code and tests for correctness, focusing on pool interactions, quote correctness, and edge-case behavior.

### Dependencies
- Crane Task C-4 must complete first (see `lib/daosys/lib/crane/UNIFIED_PLAN.md`)

### User Stories

**US-22.1: Produce a correctness + test gap memo**
As a maintainer, I want a review memo describing Camelot V2 vault invariants and missing tests so that we can rely on this code.

Acceptance Criteria:
- Memo lists invariants and missing tests

### Files to Create/Modify

**New Files:**
- `docs/review/camelot-v2-vault.md` - Review memo

### Completion Criteria
- Memo exists

---

## Task 23: Review — Deployments, CREATE3 Usage, and Script/Test Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-deployments-and-create3-usage`
**Status:** Ready for Agent

### Description
Review deployment flows and scripts to ensure IndexedEx adheres to CREATE3-only deployment rules and is adequately tested. Identify missing deployment tests for determinism and idempotency.

### Dependencies
- Crane Task C-1 and Crane Task C-2 must complete first (see `lib/daosys/lib/crane/UNIFIED_PLAN.md`)

### User Stories

**US-23.1: Validate CREATE3-only deployment invariants**
As a maintainer, I want a review confirming we never deploy contracts with `new` so that deterministic address policy remains intact.

Acceptance Criteria:
- Memo identifies all deployment entrypoints and confirms CREATE3 usage patterns

### Files to Create/Modify

**New Files:**
- `docs/review/deployments-and-create3.md` - Review memo + test gap checklist

### Completion Criteria
- Memo exists and lists missing deployment tests (determinism/idempotency)

---

## Task 24: Review — Spec Coverage Gap Audit (IndexedEx)

**Layer:** IndexedEx
**Worktree:** `review/idx-spec-coverage-gap-audit`
**Status:** Ready for Agent

### Description
Audit spec coverage by comparing the implementation surface (`contracts/**`) against the spec test suite (`test/foundry/spec/**`). Identify untested but critical code paths and propose prioritized spec tests.

### Dependencies
- None

### User Stories

**US-24.1: Produce a ranked coverage gap report**
As a maintainer, I want a ranked list of high-risk untested paths so that we can allocate test work effectively.

Acceptance Criteria:
- Report includes a Top 10 list with rationale and suggested test locations

### Files to Create/Modify

**New Files:**
- `docs/review/spec-coverage-gaps.md` - Ranked gap report

### Completion Criteria
- Gap report exists with a ranked Top 10 list

---

## Task 25: Review — Protocol DETF Correctness and Coverage

**Layer:** IndexedEx
**Worktree:** `review/idx-protocol-detf-review`
**Status:** Ready for Agent

### Description
Review Protocol DETF end-to-end (bonding + exchange-in/out + any associated vault/NFT vault semantics) for correctness and test coverage. Focus on invariants around accounting, authorization, fee semantics, and edge cases that can lead to loss of funds or stuck positions.

### Dependencies
- IndexedEx Task 5 (Protocol DETF implementation) should be in a reviewable state
- Crane Task C-2 (Diamond/proxy correctness), Crane Task C-5 (token standards / EIP-712 / permit), and Crane Task C-6 (ConstProdUtils/bonding math) should complete first (see `lib/daosys/lib/crane/UNIFIED_PLAN.md`)

### User Stories

**US-25.1: Produce a Protocol DETF trust memo**
As a maintainer, I want a memo that enumerates Protocol DETF invariants and known assumptions so that we can reason about safety and prioritize missing tests.

Acceptance Criteria:
- Memo includes: invariants, trusted roles, state transitions, external-call assumptions, and a prioritized missing-test list

**US-25.2: Add at least one high-signal spec test**
As a maintainer, I want at least one spec test added or strengthened so that critical flows are exercised and regressions are caught.

Acceptance Criteria:
- At least one spec test (or equivalent) is added/improved that covers a critical DETF flow

### Files to Create/Modify

**New Files:**
- `docs/review/protocol-detf.md` - Review memo

**Possible test touchpoints (as needed):**
- `test/foundry/spec/**` - New/updated spec tests for DETF flows
- `test/foundry/**` - Any shared fixtures/helpers needed to make the test reliable

### Completion Criteria
- Memo exists and includes a prioritized missing-test list
- At least one meaningful test improvement is implemented (or the task is marked blocked with a concrete reason)

## Completed Tasks Archive

| Task | Title | Layer | Completed |
|------|-------|-------|-----------|
| 1 | Ethereum Mainnet Fork Tests for UniswapV3Utils/Quoter | Crane | 2026-01-09 |
| 2 | Aerodrome Slipstream Utils Library | Crane | 2026-01-09 |
| 3 | Uniswap V4 Utils Library | Crane | 2026-01-09 |
| 4 | Standard Exchange Vaults for Concentrated Liquidity DEXes | IndexedEx | 2026-01-09 (Meta-task) |
| 10 | Aerodrome V1 Standard Exchange Vault Fee Compounding | IndexedEx | 2026-01-09 |
