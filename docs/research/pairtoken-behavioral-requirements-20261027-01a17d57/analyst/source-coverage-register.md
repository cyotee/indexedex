# Source coverage register

Source-side register prepared before council synthesis. This is an analyst artifact, not a normative draft or planner input. All PairToken line numbers below refer to the original source; its lines appear three lines later in the archived readable bundle.

| Topic | Original PairToken source | Required document coverage |
| --- | --- | --- |
| Key and external configuration types | 19-29; PoolKey and PoolId dependencies | Factory getters return address, uint16, int24, uint16; payable notification takes token, amount, pool ID. Key has five ordered fields and canonical ABI hash. |
| Token metadata and mappings | 47-55 | Exact getter types, approval semantics, token events. |
| Economic constants and instance identity | 59-78 | All 17 generated getters; constants are raw units; operation-scoped state is not a second claim ledger. |
| Callback operation/result data | 80-99 | Enum values, per-operation bytes, six-field static deployment result types/order. |
| Custom errors/events/modifiers | 102-130 | Thirteen declarations, unused NotFactory, five events and exact predicate/guard scope. |
| Native receiver | 133 | Empty unconditional receiver; no mint, reservation or event. |
| Initialization | 138-152 | Check order, first-caller factory, no initialized guard on other public paths, no key/hook sort policy, derived ticks and no pool creation. |
| Approve and transfers | 156-181 | Finite/max allowance, self-spender allowance, zero recipient/amount, checked sender and unchecked recipient arithmetic, no fee synchronization. |
| Mint and burn | 183-197 | Checked supply mint/unchecked balance mint, checked burn balance/unchecked burn supply, event sequence. |
| Pool identity/token getters | 201-218 | Complete key return; address-zero native representation; manager position reads owner/range/zero salt. |
| Basket and previews | 221-250 | Slot0-before-position read, amount math without clamp, idle inclusion, zero fast path, pending-fee/rounding/genesis differences. |
| Paired deposit | 256-293 | Ordered reservation/compound/quote/check/pull/add/dead mint/net mint/refund/event; gross slippage threshold. |
| Add idle | 295-303 | Current all-idle balance and price; conditional positive-liquidity unlock; no ordinary booked-ledger comparison. |
| Single-leg entry | 308-346 | Nominal cap vs actual received input, first-token branch priority, pre-zap reserve basis, half swap, tick arithmetic and post-deploy check, mint/event. |
| Paired exit | 351-364 | Recipient-before-compound, caller-only burn, per-leg minima, positive-only transfer invocation. |
| Chosen-leg exit | 366-389 | Token selection before compound, swap-only flag, wanted-plus-output, no fill assertion, unconditional selected Currency.transfer even for zero. |
| Shared redemption | 391-406 | Zero amount/supply check after compound, preburn supply/idle, checked balance burn, retained payout, unchecked narrowing, separate floors. |
| Collect/compound/protocol routing | 412-466 | Conditional collect, gross returned values, getter order, native/ERC20 routing, caught notifications vs other failures, actual idle and event trigger. |
| Ratio adjustment | 469-496 | Fitting liquidity, upward needs, leftovers, sequential price floors, tie, dust exits, active liquidity, per-side reserve, checked cap multiplication, zero-swap add attempt. |
| Share quote/zap quote | 500-529 | Four branch conditions/order, geometric product, floor sqrt, full-precision proportional quotes, ceil used/caps, no virtual offset. |
| Deploy/swap-only/unlock | 533-548 | Separate unlocks, payload packing, flag reset/restoration. |
| Callback dispatcher | 550-571 | Manager-only check before decode, known op data/results, decoded None vs malformed enum, ignored collect data. |
| Swap and add work | 576-608 | Slot0 timing, signed request conversion, price limits, positive output extraction, currency0-before-currency1 settlement, post-swap refresh, skip-add behavior and fields left zero. |
| Modify work | 610-626 | Stored key/ticks/salt/empty data, signed liquidity input, caller/fee split, settlement before consumed-amount calculation. |
| Settlement | 628-642 | Zero no-op, signed negative negation edge, native value or ERC20 sync/transfer/settle order, positive take to self. |
| Balance/native/token helpers | 646-691 | Reserved-native checked subtraction, exact msg.value, zero/native pull short paths, actual ERC20 receipt, pre-refund clear, local calls/boolean decode/approval returns. |
| Currency and wrapped errors | Currency.transfer/balanceOfSelf; CustomRevert.bubbleUpAndRevertWith | Distinct payout acceptance and WrappedError payload from local TransferFailed; zero-valued selected payout remains an external call. |
| Fixed-point and liquidity math | TickMath; SqrtPriceMath; FullMath; LiquidityAmounts; PriceMath.sqrt | Exact scale and bounds, nested rounding, full-precision versus checked products, fit branches, checked helper casts and integer sqrt. |
| Storage read/key dependencies | StateLibrary; Position.calculatePositionKey; PoolId.toId | Canonical key packing/hash and pool-manager read compatibility, distinct from vault implementation layout. |

## Explicit boundary of examination

The contract and helper semantics above are textually inspected. This register is not an execution result, deployed-system audit or proof of arithmetic algorithms. Concrete factory, fee-manager, PoolManager/Pool, configured hook/token implementations, deployment transaction and live settings remain absent. The later requirements may state their call/result contracts without fabricating their implementations.
