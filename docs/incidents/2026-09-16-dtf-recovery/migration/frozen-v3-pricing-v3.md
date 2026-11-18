# Frozen V3 pricing, migration book version 3

The owner selected the new V3 pricing model on November 17, 2026. This changes
the manual migration pricing format to represent the liquidity-based V3 vault.
It does not restore Standardized Yield, `quoteAssets`, or a capture selector on
that vault. It does not upgrade or migrate a deployed vault.

## Public APIs and stored versions

- `setMigrationWeightedPricingV3(InputsV3)` installs a version-3 book.
- `migrationWeightedPricingV3()` reads that book, or a normalized legacy book.
- The legacy setter and getter retain their existing ABI. Legacy books remain
  version 2, retain their IDs, and use their original arithmetic.
- The legacy getter rejects a version-3 book with
  `MigrationWeightedPricingVersionMismatch(2, 3)`.
- The encoding discriminator is appended to migration storage. Existing nonempty
  storage with discriminator zero denotes the legacy encoding.

Both setters require the current Crane owner and the existing idle, pre-activation
conditions. Activation removes both setters and their administration interfaces.
Replacement does not reprice previously recorded entitlements or issued bonds.

## Frozen deposit payload

`VersionedInputs` contains an explicit version and encoded data. Version 1 is the
legacy scalar input format. Version 2 contains `SwapDepositV2`: the exchange,
request, bound pool and tokens, share supply, position liquidity, usage fee,
fee recipient, and a complete pool snapshot.

The pool snapshot includes price, tick, active liquidity, spacing, swap fee,
endpoint liquidity limits, the complete covered bitmap-word interval, sorted
nonzero bitmap words, and matching initialized-tick gross/net liquidity records.
An omitted word inside the declared complete interval is zero. An access outside
that interval is an error. Empty-word boundaries and zero-net initialized ticks
remain part of the swap simulation.

Validation checks the canonical interval, word/tick correspondence, ordering,
liquidity prefixes, active liquidity, price/tick consistency, and deposit
identities. It establishes internal consistency, not historical authenticity.
The current owner remains responsible for the manually supplied operands.

## Evaluation

The evaluator makes no live pool, provider, registry, or oracle calls. It uses the
same swap-step arithmetic as the live Crane V3 quoter and the same sizing and
gross-share arithmetic as the V3 vault.

One-sided deposits retain the 49% swap, exact output-consumption requirement,
1,000-liquidity genesis floor, fee deduction and clamp, and original-input refund.
In particular, when integer liquidity cannot consume all hypothetical swap
output, the established vault's result is zero shares and a full original-input
refund. This matches the actual V4 vault; there is no new booked-output-dust rule.
A failed genesis remains non-executable.

The migration credit sequence remains uplift, trading fee, frozen deposit receipt,
refund plus rated shares, weighted output budget, and DETF split. Each original
contribution and its ETH/DTF components use the unchanged book independently.
The live external Standard Exchange rate provider is unchanged; this format does
not replace its executable preview with NAV.

## Acquisition and resource limits

`UniswapV3FrozenQuoteFixture` is a differential-test collector supplied with
explicit exchange/pool/oracle deployment bindings. It reads the complete domain
in one view call and either returns a validated snapshot or reverts. The production
setter and valuation code do not invoke the collector.

Sparse storage avoids allocating payload entries for zero words without omitting
their swap boundaries. No step cap or truncated capture produces substitute
pricing. A complete book must fit the transaction budget for its owner submission;
the implementation does not claim that every theoretically possible V3 pool can
be installed within a fixed gas ceiling.

Verification receipts are recorded with the consumer-regression task. The new
book integration is not a claim that every mixed-decimal one-sided first-bond
payment is executable.
