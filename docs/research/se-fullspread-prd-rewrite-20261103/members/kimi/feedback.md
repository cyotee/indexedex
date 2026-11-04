# Kimi advisory feedback

## Identity

- Member: `kimi`
- Phase: advisory review
- Requested role: `council-member`
- Requested model: `kimi-coding/k3.1-pro:high`
- Continued conversation: yes
- Initial response: preserved at `members/kimi/response.md`; not edited
- Owned feedback path: `members/kimi/feedback.md`
- Runtime identity not supplied by the assignment: not exposed
- Peers read before this feedback: no

## Draft under review

`docs/research/se-fullspread-prd-rewrite-20261103/coordinator/draft.md`, the coordinator merge. This was the only file opened for this advisory pass. The review question is whether it copies the locked decisions without adding economics or leaving a contradicted sentence beside a lock.

## Disposition

requested-changes

## Concerns

1. **Draft section 1.4, FS-OWN-17 and FS-OWN-22: restore the surviving WETH address rule.** The draft says the WETH address used for native substitution is a “gap” and that no constant is named. The unreversed FS-OWN-17 lock already names the wrapper as the network `WETH` constant, `WETH9` on Robinhood. Removing `PkgInit.wrappedNative` and `wrappedNative()` did not withdraw that constant. Replace the gap statement with that existing rule while retaining the prohibitions on a wrapped-native package field and getter. This restores a locked requirement; it does not add a replacement binding or new economics.

2. **Draft section 1.4, FS-OWN-30: use the accepted bundle-minimum error.** The sentence saying a caller-set minimum reverts `AmountOutNotMet` or `MinAmountNotMet` retains a stale, undeclared bundle error beside the accepted ABI. Keep `AmountOutNotMet` for the one-token exit as locked by F6. For the bundle route, name the accepted `MinAmountNotMetAt(uint256 index, uint256 minAmount, uint256 actualAmount)` error already recognized in draft section 3. Do not retain `MinAmountNotMet` as another route error.

No other added economics or affirmative sentence contradicting a later lock was found in the reviewed draft. In particular, the draft correctly applies the live-`feeTo()` authorization, fee netting and clamp, deposit fee booking, before-burn exit apportioning, both-token no-swap exit, one-token conversion, fieldless events, view behavior, tuple ABI and consumer migration, greatest-liquidity swap shape, and pretransfer overstated-maximum rule.

## What was not adopted from others

No peer response or peer feedback was read, so this section does not independently attribute text to another member. Relative to Kimi's preserved initial response, the coordinator did not adopt the added acceptance-row identifiers or concrete names for the two Crane facet inputs and seven architecture-binding fields. Those were editorial rather than locked requirements, and their omission is not a concern. The initial response's retention of the network `WETH`/`WETH9` constant was not adopted and is the subject of Concern 1. The batch-composition statement, PoolManager event-correlation rule, and repeated processing of booked remainders were adopted.

## Limits

This feedback reviews only the named coordinator draft. It does not authorize implementation, consumer migration, a PRD edit, or replacement of the draft. No other document was reopened; no peer material was read; no sub-agents, Forge, tests, installs, deploys, wallets, or Git were used. The initial response and all non-owned files remain unchanged.
