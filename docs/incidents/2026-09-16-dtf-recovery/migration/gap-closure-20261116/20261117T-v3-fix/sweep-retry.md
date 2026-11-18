# Sweep retry after the V3 vault fix

Fresh Anvil, chain 31337, 32,000,000 gas cap. Stage A mined, including the owner purchase. The measured cliff, activation, and principal claim mined.

sweepDust still reverted RateProviderFailed. Transaction 0xc8a5f5b69ecf69f61801855962d5b5354283b5e570d2d382368791dc903c7b82 used 31,385,515 of a 31,900,000 limit.

The deepest revert is previewExchangeIn out of gas. It was given 17,187 gas and used all of it. The earlier completed preview for this vault type used 40,809 gas. The vault fix did not make that quote fit in the gas left at the tail of sweepDust. The node cap was not raised.
