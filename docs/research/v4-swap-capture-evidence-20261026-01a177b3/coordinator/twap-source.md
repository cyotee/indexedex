# TWAP source check

Read 2026-10-26 from the live tree. Not an execution of `TwapRetroactive.t.sol`. Not a Wings profit result.

## What the code does

`UniswapV4MultiPoolTwapOracleTarget.update(PoolKey)` is public. It reads `StateLibrary.getSlot0` and passes that tick to `UniswapV4TruncatedTwapOracleLib.write`. The function body read here has no `isUnlocked` check.

`write` does not credit the elapsed gap with the previously recorded tick. After the first observation, it sets `recordedTick = truncate(tick_, state_.prevTick)` and stores:

```text
tickCumulative = last.tickCumulative + recordedTick * delta
delta = time_ - last.blockTimestamp
```

`truncate` moves the live tick by at most `MAX_ABS_TICK_MOVE = 9116` from `prevTick`. The capped live tick is then applied across the whole idle gap. A successful write also sets `state_.lastTimestamp = time_`, so `writeAge` restarts.

`observe` and `consult` read the live slot0 tick and pass it into the library. If the queried time is after the last stored observation, `getSurroundingObservations` builds the later point with `transform(beforeOrAt, target, tick_)`. `transform` adds `tick_ * delta` to the cumulative. `observe` truncates that tick before the call. A read can therefore fill an unwritten tail with the current truncated tick without storing a new observation.

## What this is not

This oracle is a poke record of this pool. It is not a historical mean of prices between pokes, and it is not a price from another venue. Crediting the gap with the previous tick would stop the retroactive fill. It would not reconstruct the missing interval, and the tick stored at the next poke could still be the manipulated tick. With no other pool, nothing in this source forces an outside arbitrageur to restore the price.

Using this value as a mint reference, or as a band around a same-pool execution price, can add delay and a cap. It does not make the deposit-swap or exit-swap ledger in `research/EXECUTED.md` safe. Those rows do not read this oracle. A frozen pre-trade reference was the control that removed the executed-price gain in the earlier same-pool model; this implementation is not that frozen reference.

Line numbers are from the tree opened for this note. They can move.
