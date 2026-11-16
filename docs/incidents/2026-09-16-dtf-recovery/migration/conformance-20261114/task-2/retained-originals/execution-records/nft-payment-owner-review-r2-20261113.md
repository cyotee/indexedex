# NFT purchase-payment review, revision 2

**Non-issuable observations. No compensation allocation is approved.**

The complete 59-record worksheet is `nft-payment-owner-review-r2-20261113.json`.
The original revision remains unchanged. This revision adds gross token-payment
observations for the four previously unresolved smart-account purchases:

| Weighted NFT | DTF paid to the bond contract | WETH wallet-transfer payment observed |
| --- | ---: | ---: |
| 19 | 100,000 | 0 |
| 20 | 200,000 | 0 |
| 23 | 200,000 | 0 |
| 42 | 400,000 | 0 |

All four purchases use smart account
`0x26acc4c07cac494d49054eaad406ef108a074a66`. Each saved transaction
contains one operation and one decoded bond call. Its exact DTF payment,
recipient NFT mint and successful operation hash reconcile in the canonical
receipt. The outer transaction sender is the bundler, not the recorded
bond-paying account. Gas costs are excluded.

`weighted-indirect-purchase-observations-20261113.json` records the exact
integer quantities, transaction/log locators, raw-file hashes, ABI references
and verification method. The wallet's 29-byte calldata suffix is preserved
without interpretation. ABI shape is not a claim of byte-for-byte wallet
implementation verification. No new chain query or restricted trace was needed.

The worksheet now contains 55 earlier source-supported direct observations and
four receipt/calldata-corroborated observations. `observedGrossPaidRaw` is the
common observation field; the distinction between those evidence bases remains
explicit. The four new observations do not silently acquire the old direct
source-support label.

Operational approval, credit and prior-compensation fields remain unset.
The subsequent owner decision for weighted NFT 3 fixes two originals:
`999999000000000` raw18 WETH and `362893857600000000000` raw18 DTF,
each producing a separate compensation bond upon the existing eligible
surrender. See `nft3-two-contributions-owner-decision-20261113.json`.
The scalar approved-original fields are not used to combine these originals.
NFT 42's historical purchase does not
override its later recorded principal retirement or create a new entitlement.
Current-control observations retain their original block pin.
