# FullSpread composable exact-input quotes

The November 18, 2026 implementation request gives Uniswap V3 FullSpread and
Uniswap V4 FullSpread the same optional `IStandardExchangeStateQuote` interface.
The implementation uses their existing liquidity planners and swap arithmetic.

## Public contract

| Method | Meaning |
| --- | --- |
| `quoteExchangeState()` | Capture the current vault and backing-pool state. |
| `quoteExchangeIn(state, tokenIn, amountIn, tokenOut)` | Return the next hypothetical state, output, and caller-owned input refund. |
| `quoteExchangeSupply(state)` | Read the issued supply at that hypothetical state, including fee shares and the locked floor. |

The interface is advertised through ERC-165 and installed on the existing
exact-input query facet. State bytes are opaque to consumers and use a
vault-specific format. They are domain/version checked and cannot be passed
between vaults or between V3 and V4. State is a read-only calculation, never an
execution authorization or a credit to a particular holder.

Operations in one sequence must use an unchanged external-liquidity baseline:
capture once, feed each returned state into the next preview, and discard the
sequence when actual pool state changes. An ordinary execution still reads
live state and enforces its own funding, deadline, authorization, refund, and
minimum-output checks.

Unsupported and unavailable routes retain each vault's ordinary preview
semantics. A full-refund candidate that executes no action retains the original
state. The interface does not enable exact-output execution.

## Hook and DETF composition

When a DETF redeems incoming SE shares before swapping the resulting pair token
through its reserve hook, the hook preview first projects that external
redemption. It then prices the reserve swap from the returned state.

The state describes the vault globally. Hook-owned booked shares and local
pair tokens remain separate quantities; ambient transfers do not become the
hook's booked inventory. The new capability does not advertise the legacy
transition interface or select its different swap-pricing formula.

Each hook retains its existing pricing order:

- CP prices the deposit refund and minted shares at the post-redemption,
  pre-buffer rate.
- Weighted and Curve apply the trading fee before their pricing conversion.
- Orbital prices the full conversion before applying its trading fee.

Actual buffering, caller refunds, and proportional LP ownership remain governed
by actual receipts and the existing component-accounting rules.

The canonical Standard Exchange rate provider accepts the new state through
its existing `quoteRate` method. It retains its full-supply valuation and
normalization. The valuation operation uses a copy: its hypothetical exit does
not advance the state used by the actual composed operation.

These states project one vault and its backing pool. They do not project a
different vault's book that happens to share that pool, or arbitrary external
provider dependencies. The existing required cross-vault fixtures use disjoint
backing pools. FullSpread composed previews require the provider's existing
`IStandardExchangeRateQuote` capability; a live-only provider is rejected
instead of silently substituting a potentially stale rate. An implementation
of that capability remains responsible for its declared dependencies.

## Deployment compatibility

Existing deployed diamonds do not acquire new selectors from source changes.
V3's query facet and package use the `v4Accounting.v2` deployment identities.
V4 family facets and its package use the `.stateQuote.v1` deployment salt
suffix. Package argument layouts and vault storage layouts remain unchanged.
V3's new query facet uses the factory-aware artifact linker for its planner.

The legacy transition, external-quote, sleeve, and SY selectors remain absent
from these FullSpread packages. Neither vault gains its own `getRate`, and no
projection registry or new hook package field is introduced.

Validation results are recorded in the session's `.debug-journal.md` entry;
the presence of this interface description is not a passing-test claim.
