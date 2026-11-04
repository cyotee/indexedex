# Surplus-refund & structural value settlement (cross-VM harvest)

**Contents**

- Why this note exists
- Bug class (portable)
- CTF-shaped chain (intuition only)
- EVM mapping → catalog
- Secure-dev rules
- Hermetic test stubs

## Why this note exists

A Solana/Anchor CTF (`frank-amm`: constant-rate token sale + treasury migrate + **permissionless realloc** of a treasury account) demonstrates a **portable** failure class: operations that settle value as **raw account balance above a floor** to an unprivileged caller, after a permissionless path moved trading proceeds into that account.

Do **not** vendor Solana code or treat the CTF as a Foundry dependency. Harvest **patterns** into Crane/IndexedEx catalog IDs and hermetic EVM tests.

## Bug class (portable)

| Ingredient | Failure |
|------------|---------|
| Protocol holds **surplus** inventory (trading proceeds, donations, idle native/ERC20) | Assets sit on an account/contract above “required floor” (rent, reserve, min balance) |
| **Public** structural op (resize, realloc, migrate, reclaim, “refund excess”) | No authority check, or authority is meaningless for settlement |
| Settlement formula uses **`balance − floor`** (or framework rent refund of excess lamports) | Caller receives **all** surplus, not only their own overpay / tracked credit |
| Optional: internal books (`liquidity`, `totalAssets`) **desynced** from balance | Transfers use balance; books never gate extract |

Result: attacker **pays once** for product (tokens/shares), then **reclaims the payment** (and any other idle surplus) via the structural/refund path → free inventory.

## CTF-shaped chain (intuition only)

1. Buy product with native asset (min size large enough to empty inventory).
2. Permissionless **migrate** moves pool proceeds into a treasury account.
3. Permissionless **realloc / resize** settles rent delta against `rent_payer` using framework logic that effectively refunds **`lamports − new_rent_exempt`** (surplus included).
4. Attacker ends holding product **and** recovered native asset.

EVM analogue is not “Solana realloc” — it is any combination of **idle inventory** + **public reclaim that refunds raw surplus**.

## EVM mapping → catalog

| Portable theme | Catalog | Hermetic pass |
|----------------|---------|---------------|
| Refund pays `balance − floor` / raw residual to caller | **E6** | Refund ≤ this-call overpay or caller tracked credit |
| Untracked surplus extract via skim / reclaim / migrate | **L1** | No free extract; books match balances |
| Structural resize/migrate/reclaim is permissionless | **F5** | Auth-gated **or** mathematically cannot touch surplus inventory |
| Internal `liquidity` / reserve field ≠ balance used for transfer | **K**, **E** | Consistent books; transfer amount cannot orphan surplus as free |
| Unvalidated external token/vault accounts on buy path | **M2**-class / surface validation | Mint/owner/authority fixed or checked |

**Boundary:** **E6** = product’s own refund math; **L1** = surplus inventory extract (pair or native); **F5** = access on the structural op. One exploit chain may need tests under all three IDs — do not renumber A–K.

## Secure-dev rules

1. **Never** `payable(msg.sender).transfer(address(this).balance - minReserve)` when the contract holds multi-user or protocol inventory.
2. Refund only **measured overpay for this call** (`msg.value - due`) or **caller-scoped credit**.
3. Permissionless “ops” that move value (migrate, reclaim, resize-with-refund) are **money paths** — treat as **F5** + **L1**, not admin-only docs.
4. If an accounting field exists (`liquidity`, `totalDebt`, …), either **gate** extracts by books or **delete** the field; do not maintain a lie.
5. External asset accounts (token vaults, pair legs) must fix **mint/owner/authority** — never trust caller-supplied unchecked accounts for inventory.

## Hermetic test stubs

```solidity
/// @dev E6: donate/overpay then hit residual-return; prior inventory must stay.
function test_E6_surplusRefund_cannotDrainPriorInventory() public {
    address instance = _openLiveWithIdleNativeOrAsset();
    uint256 prior = _idleInventory(instance);
    uint256 overpay = 1 ether;
    // attacker triggers refund / residual-return path with overpay if applicable
    // Pass:
    assertEq(_idleInventory(instance), prior); // or prior - documented fee only
    // attacker net native gain ≤ 0 (or ≤ documented rebate)
}

/// @dev L1+F5: public migrate/reclaim after user payment cannot free-extract proceeds.
function test_L1_F5_publicReclaim_cannotExtractTradingProceeds() public {
    address instance = _openLive();
    // attacker pays for product via production entry
    // attacker calls public migrate/reclaim/resize if present
    // Pass: attacker holds product only if still net-paid; protocol surplus not in attacker wallet
}
```

## Related

- `theme-to-catalog.md`, `secure-dev-checklist.md`
- Crane `crane-adversarial-testing` (E6, L1, F5)
- `hermetic-test-templates.md`
