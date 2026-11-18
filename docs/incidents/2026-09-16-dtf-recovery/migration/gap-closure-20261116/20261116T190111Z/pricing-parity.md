# Observed raw-hook parity

Integrated C4 exited 0. 39 tests passed: 6 new raw-hook tests, 14 existing snapshot tests, and 19 existing weighted pricing tests.

The gross oracle is the comparison hook's previewExchangeIn, not a copied formula. R2's output provider is the SE-share-derived se0/pairA policy rate, not the parent DETF economic price. A stored zero fee reads back as the vault-type default; the zero-seigniorage control uses the hook's actual reported fee. The worker's passing run recorded one native9 pair as gross 1168562 and user 1110133.

Log: c4.log.
