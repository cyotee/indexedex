# Secure development checklist (incident-driven)

**Contents**

- How to use
- Checklist (bad → correct → ID → test name)

Use while writing Facets, Targets, DFPkgs, vaults, routers, and helpers. Pair with `crane-adversarial-testing` ship gate.

## How to use

For each money path or external call, walk the list. Any **P0** gap needs a hermetic test (or explicit NatSpec deferral) before “adversarially tested.”

## Checklist

### 1. Accounting / credit

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| `balanceOf(this) >= amountIn` then credit `amountIn` | Measure **delta** since balBefore / last reserve | I1–I3, K | `test_I1_pretransferred_noTransfer_noCredit` |
| Include foreign tokens in `totalAssets` | Only product assets; document inventory policy | A, K | `test_A_totalAssets_ignores_nonAsset_donation` |
| Zero `totalSupply` with residual assets mintable free | Dead shares / virtual offset / init gate | **A0** | `test_A0_residualAssets_zeroSupply_firstMinterCannotDrain` |
| Refund `address(this).balance − floor` / `balanceOf − min` to caller | Refund only **this-call overpay** or caller tracked credit | **E6**, L1 | `test_E6_surplusRefund_cannotDrainPriorInventory` |
| Maintain `liquidity`/reserve field but transfer from raw balance | Gate extracts by books **or** drop the field; keep books == balance | K, E | `test_K_booksMatchBalance_noFreeExtract` |

### 2. Pricing

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| Raw spot for high-value mint without policy | TWAP / deadband / dual gates | B, L3 | `test_B1_skew_mint_burn_noFreeLunch_or_bounded` |
| Price from pair balance without sync awareness | Use reserves intentionally; handle FoT | L1–L3 | `test_L1_untrackedSurplus_cannotFreeMint` |

### 3. AMM interaction

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| Treat pair surplus as free protocol inventory | Books == balances; no public skim of protocol surplus | L1 | `test_L1_skimClass_surplus_not_creditable` |
| FoT underlying credited at nominal | Credit actualIn only | L2, I4 | `test_L2_feeOnTransfer_creditActualIn` |

### 4. External calls / reentrancy

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| External call before state finalization | CEI + nonReentrant / IsLocked on value paths | C | `test_C2_reenter_redeem_IsLocked` |
| User `target + calldata` with held allowance | No arbitrary call; allowlisted ops only | M1 | `test_M1_userCalldata_cannotSpendAllowance` |

### 5. Allowances

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| Infinite approval to open helper | Minimal Permit2 / exact allowance; no open helper | M3 | `test_M3_noThirdPartyAllowanceSweep` |
| Unvalidated swap target | Allowlist router; measure amountOut | M2 | `test_M2_hostileSwapTarget_reverts` |

### 6. Signatures

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| Accept ecrecover == address(0) or dummy v/r/s | Strict ECDSA; reject zero signer | O1 | `test_O1_invalidOrZeroSigner_reverts` |
| No nonce / deadline | Replay-safe nonces + deadline | O2 | `test_O2_signatureReplay_reverts` |
| Wrong EIP-712 domain | Canonical domain + typehash | O3, I5 | `test_O3_wrongDomain_reverts` |

### 7. Diamond surface

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| Facet omits Target money function | Target API ⊆ facetFuncs ⊆ cuts ⊆ loupe | J1–J3 | `test_J2_proxyLoupe_allProductSelectors` |
| Control list copied from incomplete Facet | Control from **Target/interface** | J1 | declaration Behavior tests |

### 8. Multi-step flows

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| Quote units then settle after untrusted callback | Atomic quote/settle; freeze units; no hostile hook inflate | N1 | `test_N1_midFlowHook_cannotInflateCredit` |
| Preview differs from execute silently | Match or documented tolerance | N2 | `test_N2_preview_matches_execute` |

### 9. Access / init

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| Leftover public `initialize` | One-shot init; unowned DETF post-deploy | F | `test_F_eoa_cannot_reinitialize` |
| Privileged mint callable by EOA | onlyOwner / operable as designed | F2–F3 | `test_F2_randomEoa_cannot_privilegedMint` |
| Permissionless migrate/resize/reclaim that can pay surplus to caller | Auth-gate **or** refund math that cannot touch untracked inventory | **F5**, L1 | `test_L1_F5_publicReclaim_cannotExtractTradingProceeds` |

### 10. Tests (meta)

| Bad | Correct | ID | Suggested test |
|-----|---------|-----|----------------|
| Happy path only | Adversarial catalog P0 + defer NatSpec | DoD | suite under `adversarial/**` |
| Fork profit as security | Blocked exploit or bounded intentional risk | — | never `assertGt(profit)` as DoD |
| Mock SUT | CREATE3 + DFPkg + registry path | — | gold TestBase |

## Related

- `hermetic-test-templates.md` — copyable stubs
- `theme-to-catalog.md` — full theme map
- Crane `references/implementation-test-dod.md`
