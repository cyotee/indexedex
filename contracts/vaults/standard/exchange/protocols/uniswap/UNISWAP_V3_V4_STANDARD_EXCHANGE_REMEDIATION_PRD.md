# Uniswap V3 and V4 Standard Exchange — Shared Remediation PRD

**Implementation:** See [new-version code and integration notes](README.md) and the linked validation record. This PRD retains the broader release matrix.

**Status:** New V3/V4 implementations and focused regression suite complete; broader release matrix retained
**Date:** 2026-09-15
**Deliverables:** two new vault versions, with equivalent liquidity economics and independently verified token delivery

## 1. Scope and authority

The owner requires new versions of **both** the Uniswap V3 and Uniswap V4 Standard Exchange vaults. They must manage liquidity according to the same V2-style constant-product/proportional-ownership model, with protocol-specific execution adapters. Both must fix the reported stale-reserve pretransfer vulnerability.

| Family | Preserved reference — do not change | New implementation |
|---|---|---|
| V3 | `contracts/protocols/dexes/uniswap/v3/` | `contracts/vaults/standard/exchange/protocols/uniswap/v3/` |
| V4 | `contracts/protocols/dexes/uniswap/v4/` | `contracts/vaults/standard/exchange/protocols/uniswap/v4/` |

This shared PRD governs security requirements, family parity, preservation, and completion. The [constant-product accounting PRD][economics] supplies the shared economic reference and unresolved execution decisions; its original V4-only scope is expanded by this document to include V3. The [V3 companion PRD][v3-prd] records adapter-specific obligations. Keep the original accounting PRD at its existing path so prior links remain valid.

Preserve both old source trees, their provenance, and the initial investigation. Do not modify deployed vaults, send transactions, change live settings, or infer an upgrade/migration path for immutable instances. Documentation and new-version implementation are distinct from deployment authorization.

## 2. Two separate problems

### 2.1 Constant-product consistency

The economic work must compare entry and exit with an independently specified constant-product swap/proportional-liquidity reference. A large payout or profit against a differently priced market is not alone evidence of a bug. The correction to the original market-value interpretation remains in force; this work does not substitute oracle-NAV issuance.

### 2.2 P0: false pretransfer credit

The reported vulnerability is a **token-delivery validation error**, independent of that economic question. A caller supplying no new tokens must not receive a deposit-funded share or asset output merely because a pool price or position value changed. Fixing a mint formula, keeping reserves balanced, or reducing the sleeve target does not establish token delivery.

This security requirement is settled and must not wait for the open constant-product venue/fee decisions. Reproduce the vulnerability on the preserved implementations, then prove the correction on both new implementations.

## 3. Report and evidence boundaries

Source: [auditor post][auditor-post], whose text the owner supplied in this conversation after direct retrieval from X returned HTTP 403.

The supplied account describes:

- An independent, byte-for-byte testnet deployment, funded by the researchers rather than a demonstration against the project's users.
- An honest deposit that creates a deployed position, followed by an ordinary pool trade.
- A later caller claiming a pretransfer without delivering tokens, receiving `3.029254145383447796` shares and reportedly redeeming them for `3.8655` tokens.
- Named project testnet vaults being unarmed at the time of the report because they had no deployed positions. That historical condition does not establish present safety.

These demonstration amounts are **auditor-reported**, not independently replayed in this work. The supplied text refers to a transaction link but does not include its URL/hash. Preserve that distinction. The post does not demonstrate an attack on the user's deployed vaults. Any claim about a specific live instance requires its address, deployment/bytecode verification, state, and separate evidence.

Local source inspection confirms equivalent executable logic in `_secureTokenTransfer` in:

- [UniswapV3StandardExchangeCommon.sol][old-v3-common], approximately line 855.
- [UniswapV4StandardExchangeCommon.sol][old-v4-common], approximately line 1270.

The functions match after removing comments and whitespace. Do not describe the entire V3 and V4 contracts or their runtime bytecode as identical. The earlier investigation's V4 deployment provenance remains documented in the economic PRD; it does not establish any V3 deployment identity.

## 4. Mechanism and required correction

### 4.1 Mixing two different snapshots

The current pretransferred branch effectively computes:

```text
R = total token reserve stored at a prior vault synchronization
B = token balance held locally now
D = deployed token amount calculated from the current pool state

bookedLocal = max(R - D, 0)
claimable = max(B - bookedLocal, 0)
accept claimed input when claimedInput <= claimable
```

`R` and `D` need not describe the same point in time. Ordinary swaps made directly against the pool change the token composition of the vault's position without invoking a vault synchronization. If the current deployed amount of a token increases, the calculation can understate already-booked local inventory and label the difference as newly delivered input.

Illustrative units, excluding fees: the last snapshot contains `10` local plus `100` deployed tokens, so `R = 110`. An external pool trade changes that token's deployed amount to `105`; the vault still holds the same `10` local tokens and receives no transfer. The calculation now treats only `5` local tokens as booked and exposes `5` as claimable. A price-derived change has become a false proof of delivery.

Clamping at zero prevents arithmetic underflow; it does not validate the source of the apparent surplus. V4's fee-inclusive accounting and V3's fee bookkeeping must be analyzed individually, rather than assuming their whole reserve systems are identical.

### 4.2 Separate valuation from delivery

The new design must maintain distinct concepts:

| Concept | Permitted source | Purpose |
|---|---|---|
| Complete backing/valuation | Local assets, exact deployed inventory, attributable fees and liabilities | Determine valid share entitlements under the economic model. |
| Accounted local custody | Actual local token movements, accounted independently of position repricing | Distinguish assets already held from newly delivered assets. |
| Input credit for an operation | Verified delivery attributable to the supported operation, consumed once | Authorize a deposit, swap input, or refund. |

**Required property:** market price changes alone cannot increase credit available to a caller.

For pull-based input, measure the actual local balance delta around the authorized transfer and validate it under the project's token policy. Never add historical surplus to the measured input.

For pretransferred input, use a separately accounted local-custody/delivery mechanism. Specify the supported atomic push route, when its checkpoint or credit is established, which caller/operation may consume it, and when it is consumed. A price-derived deployed balance must not participate in the proof of delivery. A local balance ledger alone must not silently authorize arbitrary callers to claim another user's pending delivery or a prior donation.

Track all changes to local custody: pulls, recognized pushes, fee collection, liquidity addition/removal, swaps, transfers/refunds, and wrapping/unwrapping. Distinguish those movements from in-flight user credit and from accounting-only position repricing. Specify how donations become booked without being misattributed to the next caller.

The implementation plan must select the exact ledger/checkpoint/credit API after mapping current push integrations. Preserve genuinely funded pretransfers where required; do not claim success by disabling that branch everywhere.

### 4.3 Incomplete fixes to reject

- Refreshing reserves periodically, relying on a keeper, or assuming all swaps pass through the vault. An external pool trade can always make a position-derived snapshot stale again.
- Subtracting current deployed inventory from any previously stored total to infer delivery.
- Calling a blanket synchronization after a legitimate pretransfer and thereby booking the user's new input before recognizing it.
- Treating `balanceOf(vault) >= claimedInput` or an arbitrary old balance surplus as proof that this caller paid.
- Testing only with no deployed position or immediately after reserve synchronization.
- Fixing only share minting while leaving a direct swap or exact-output route able to consume phantom input.
- Blanket rejection of legitimate in-session operations to avoid exercising the vulnerable branch.

## 5. Required affected-surface inventory

For each family, enumerate every direct and delegated call site of `_secureTokenTransfer`, `_secureShareDelivery`, local/total reserve synchronization, and refund helpers. Include:

1. Single-token exact-input deposits and direct swaps.
2. Multi-token deposits and all legs' delivery order.
3. Exact-output swaps and any associated unused-input refunds.
4. Share delivery, burns, single-/multi-token withdrawals, and leftover self-shares.
5. Approval, permit, pretransfer, router, hook, and SY paths that reach these operations.
6. Fee collection, position import, rebalance, and external callbacks that change local inventory.

The reported root cause is in token pretransfer validation. Review share-delivery and refund paths as adjacent surfaces without assuming they have the identical bug. In particular, family-specific self-call handling and fee booking require independent verification.

## 6. Reproduction and regression tests

### 6.1 Canonical end-to-end test — both families

1. Deploy real protocol components, an IndexedEx manager/registry, and the preserved SE package through the production factory path. Use independent fixtures and funds, never an attack transaction against a live funded vault.
2. Make an honest two-token contribution that creates a nonzero position and retains positive local inventory. Record both local balances, stored reserves, deployed quantities, share supply, and ownership.
3. Use a separately funded market participant to make an ordinary swap directly through the underlying protocol, outside the SE's entrypoints. It must change the deployed token amounts without synchronizing the SE's stored total. Record the actual movement and swap costs.
4. Choose the input side on which the stale/live mismatch exposes apparent credit. The false-deposit caller starts with zero input tokens and sends no input to the vault. Keep that actor distinct from the honest depositor and market trader.
5. Call the real public pretransfer route. On the preserved version, demonstrate the false credit with exact balance/share deltas and, for the mint route, attempt redemption to establish whether it produces actual asset loss. Save the trace and precise preconditions.
6. Run the same preparation and attempt against the new version. Require a specific delivery-validation failure, zero new shares/assets for the false depositor, unchanged supply and holder entitlements across the rejected operation, and no usable residual credit.
7. In the same moved-price condition, perform a valid input through each supported delivery mechanism. It must succeed with correct credit exactly once. This distinguishes a correct repair from a disabled deposit interface.

Compare state immediately before and after the false deposit; do not demand that an honest LP's balances remain unchanged across the preceding legitimate market trade. The market trader's costs must not be misreported as zero, even though the false-deposit caller sends no tokens.

### 6.2 Mandatory matrix

| ID | Cases and acceptance |
|---|---|
| PT-01 | Canonical sequence above for both V3 and V4: preserved versions demonstrate the flaw under recorded conditions; new versions reject false credit. |
| PT-02 | Both directions of price movement and both input tokens; small and large changes, ordinary and imported positions, and different valid sleeve ratios. Include a nonzero position and local inventory. |
| PT-03 | No-price-movement and no-position controls, plus legitimate pull and push inputs after movement. Prove the test actually distinguishes the stale-reserve condition. |
| PT-04 | Every reachable exact-input/direct-swap/multi-input/exact-output use of the helper. No route may exchange existing vault inventory or issue a refund for phantom input. |
| PT-05 | Zero, short, excess, repeated, and reused delivery; previously booked self-shares; another caller's pending input; prior donation. No unfunded or duplicate credit; refunds stay within this operation's input. |
| PT-06 | Fee growth with and without price movement, collection before/after a delivery, liquidity add/remove, rebalance, import, and ETH/WETH movement. None may masquerade as the caller's transfer. |
| PT-07 | V3 bound-pool callbacks/locks and V4 outer PoolManager sessions, plus malicious reentry and interleaved callbacks. Valid funded sleeve operations remain supported without nested pool interaction. |
| PT-08 | Fuzz/invariant sequences of pool trades, deposits, withdrawals, donations, collection and rebalances: credited input is backed by verified operation delivery; a no-delivery actor cannot gain deposit-funded claims or asset outputs. |
| PT-09 | Mixed decimals, dust, reserve exhaustion, saturation branches, overflow boundaries, and failed transactions. Assert exact errors, state rollback, and consumed-credit behavior. |
| PT-10 | Paired V3/V4 scenarios satisfy the same delivery and ownership properties, with explicit allowances only for real protocol fee, tick, lock and rounding differences. |
| PT-11 | Facet declarations, package cuts, delegates and actual registry-deployed proxy calls exercise the new code. Preserve source hashes and avoid stale/ambiguous artifacts. |

No mock of the vault, pool/PoolManager, manager, registry, fee oracle, or package under test. Reuse Crane protocol components and IndexedEx TestBases. A real, separately funded test trader moves price through real swap execution; do not manufacture the bug by overwriting the pool price or the stored reserve.

A deliberately vulnerable old-version comparison may assert that the false mint succeeds, clearly named as a baseline demonstration. The corrected-version security test must assert rejection and no gain. Do not weaken it to an arbitrary maximum profit or classify zero-delivery shares as acceptable constant-product arbitrage.

A mutable asset valuation after a real donation, swap, or price move does not itself violate PT-08. The invariant concerns **new input credit**, not a requirement that all token balances or share values remain constant.

## 7. V3/V4 parity

Both new versions must share the same product rules for constant-product liquidity, two-token activation, complete backing, single-token zaps, proportional ownership, fee attribution, input delivery, and rounding direction. Prefer reusable verified accounting logic in the new implementation area where it does not erase necessary protocol differences.

V3 has a bound pool and its own swap/mint callbacks and lock state. V4 has a singleton PoolManager, unlock sessions and native Currency handling. These adapters are not interchangeable. Test the same economic/delivery scenarios separately on both real protocol implementations, and document expected differences rather than demanding byte-for-byte identical contracts or numerically identical outputs with different fees.

The existing constant-product acceptance matrix applies to both families, adapting V4-specific execution cases to the actual V3 mechanism. No family can be marked complete based solely on tests of the other.

## 8. Work order and definition of done

1. Preserve both reference trees and capture exact artifact/dependency/compiler/deployment provenance.
2. Reproduce the reported pretransfer defect on both preserved implementations and map every affected route. Archive the auditor-supplied account and distinguish independent evidence from reported results.
3. Specify and implement secure delivery accounting for both new versions. This P0 correction is independent of unresolved economic choices.
4. Complete the constant-product reference specification and correct identified economic discrepancies without abandoning the owner's model.
5. Pass PT-01 through PT-11 and the applicable constant-product acceptance matrix on both new registry-deployed packages. Record build-before-test commands, revisions, fixtures, results and limitations under the repository's existing Foundry workflow.
6. Deliver separate old/new factory, facet, package, interface, storage and migration maps. Document compatibility with required hook/router/SY routes and immutable consumers.

The new code, reproduction tests, and focused regression results are linked above. The full matrix remains the broader release gate; the validation record identifies its coverage limits. Deployment and migration remain separate actions.

## References

- [Constant-product accounting PRD][economics]
- [V3 companion PRD][v3-prd]
- [Auditor post; body supplied by the owner][auditor-post]
- [Preserved V3 common implementation][old-v3-common]
- [Preserved V4 common implementation][old-v4-common]
- [MultiAssetBasicVaultRepo][reserve-repo] and [AddressSet storage layout][address-set]
- [IndexedEx testing guidance][testing] and [DETF alignment D57–D59][alignment]

[economics]: v4/UNISWAP_V4_STANDARD_EXCHANGE_CONSTANT_PRODUCT_ACCOUNTING_PRD.md
[v3-prd]: v3/UNISWAP_V3_STANDARD_EXCHANGE_REMEDIATION_PRD.md
[auditor-post]: https://x.com/willhasroot/status/2094993751147966707
[old-v3-common]: ../../../../../protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol
[old-v4-common]: ../../../../../protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol
[reserve-repo]: ../../../../basic/MultiAssetBasicVaultRepo.sol
[address-set]: ../../../../../../lib/crane/contracts/utils/collections/sets/AddressSetRepo.sol
[testing]: ../../../../../../.agents/skills/indexedex-testing/SKILL.md
[alignment]: ../../../../detf/DETF_ALIGNMENT_PRD.md
