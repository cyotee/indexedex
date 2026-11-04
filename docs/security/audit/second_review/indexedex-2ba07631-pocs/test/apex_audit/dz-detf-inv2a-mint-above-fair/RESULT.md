# dz-detf-inv2a-mint-above-fair: REFUTED (harness false positive). Not APEX-2026-020; the credit behaviour is the known APEX-2026-039 class

Source: the audit runner ~/audits/deep/detf.log, DetfInvariantTest, "INV-2a mint issued above fair price", shrunk to 7 calls.
Replay: DzInv2aReplay.t.sol. It uses verbatim copies of the p4-detf harness (DzHandler.sol and DzInvBase.t.sol, renamed only, because the the audit runner slots carry stale p4-detf versions).
Run: forge test .../DzInv2aReplay.t.sol -vv --match-contract DzInv2aReplay

## Decoded sequence
1. h_marketMove +149.93%. The arb moves the pool to pFair, which is exogenous.
2. a_pretransfer: DETF dust to staking.
3. a_burn 8.95% to SE.
4. a_mint with SE. This step is quarantined: the arb restores the pool to pFair first.
5. a_donate SE.
6. a_pretransfer: **5.293e18 SE raw-transferred by the adversary to the DETF diamond** (advGifts[detf][se] = 5.293e18).
7. a_pretransferClaim(op=0 mint, tok=SE, overclaim). It transfers amt = 11.889e18 SE and calls exchangeIn(SE, amt+extra = 15.979e18, pretransferred=true).

## Executed result
| | value |
|---|---|
| test_replay_full | reproduces the break: mintViol 1, maxMintExcessBps 3356 |
| (amt+extra)/amt | 1.3440 (3440 bps) |
| SE on the diamond before/after step 7 | 5.293e18 -> 1.203e18 (the 4.090e18 extra came out of the adversary's OWN step-6 gift) |
| overclaimAccepted / overclaimSelfFunded | 0 / 1 |
| leakViol (protocol fair equity) | 0 |
| adversary advProfit, cumulative | -94.95e18 pair wei (step 7 gives +3.98e18, which only recovers part of the 5.29e18 gift) |
| test_replay_noOverclaim (extra=0) | PASS, mintViol 0 |
| test_replay_noSelfGift (step 6 removed) | PASS. The over-claim reverts and mintViol is 0 |

DETF out = 12,219,260,027, worth 15.84e18 pair at pFair. The SE actually credited is worth 15.94e18 pair. So the mint is issued about 63 bps BELOW fair (fee plus seigniorage), not above it.

## Root cause of the break
This is a harness bug. In i_pretransferClaim(op=0), `_checkMintFair(out, pairEq*amt/(amt+extra))` charges the mint only for the tokens transferred in this action. It ignores the adversary's own earlier unbooked gift, which the DETF legitimately credits (credit = unbooked balance). The overclaim branch counts the same event as self-funded, but INV-2a does not.
- Not APEX-2026-020: every mint runs after _requireArb (pool at pFair within 0.2 bp), so no spot move is involved.
- The protocol behaviour exercised (unbooked balance usable as pretransfer credit by any contract caller) is the APEX-2026-039 / APEX-003 credit-model class. The p4 regression test_regress_break6_selfFundedOverclaim already covers it. There is no third-party victim here.

## Harness fix
In _checkMintFair for op=0, use pairEq of (amt + min(extra, advGifts[detf][tok])). Or skip the check when the over-claim is self-funded.
