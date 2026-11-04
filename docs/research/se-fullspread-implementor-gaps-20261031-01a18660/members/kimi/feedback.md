# Kimi advisory

- Draft reviewed: `se-fullspread-implementor-gaps-20261031-01a18660-r1`
- SHA-256 verified: `dcd2d1fd76fa2ebb501a074b1aa55b20d70173d494d104c190eec62ec5f9d0d5`
- Disposition: **request changes to member-fidelity wording**.

The draft carries most of my questions accurately: the unselected-currency credit split, sleeve refill and shortfall, `poolManager`, `wrappedNative`, aware components, raw-ETH payout, `queryFacet`, unknown-token reserves, reserve snapshot timing, and `donate`. The following corrections are needed.

## Questions for the owner, item 1

The statement that the PRD “forbids ... a holder address” does not state my genesis-floor question accurately. The cited PRD sentence says it does not **pick** a holder address; that is why the owner question exists. Describing a holder as forbidden prejudges the requested answer. My question was how the ERC-20 represents the floor, including whether any balance owns it or whether external and internal supply accounting differ.

## Questions for the owner, item 3 — omitted load-bearing question

This is not my sleeve-spending question. Item 3 asks about a call received while the PoolManager is **locked** spending the sleeve without opening an unlock. My G-04/Q-04 concerned the opposite manager state: borrowed-unlock `exchangeIn`, received while the PoolManager is **already unlocked**, where the vault is forbidden to call `unlock` again.

The omitted question is whether that borrowed-unlock route may fund its manager action and settlement from local sleeve balances or must leave the sleeve untouched. The locked-call and borrowed-unlock cases have different route preconditions and cannot be substituted for one another.

## Questions for the owner, item 9, and Preserved disagreements — omitted load-bearing question

The draft narrows raw ETH to payout and asserts that raw user entry is already nonpayable. My G-07/Q-07 expressly covered both entry and exit because the PRD's nonpayable rule is stated for borrowed `exchangeIn`; it does not by itself settle every accepted locked route. “No extension was added” also does not resolve whether an existing accepted locked route is payable.

The omitted question is whether native-pool support is wrapper-only for user entry or requires raw-ETH entry on an accepted locked route. The draft may preserve a coordinator or another member's contrary disposition, but it should not present the entry side of my question as already closed without that distinction.

## Questions for the owner, item 14, and Recommendations that close a gap

The draft does not preserve my disposition on pro-rata idle. I classified G-12 as a gap **closable from cited `_withdraw` and existing FS-A08/FS-A11 language**, and supplied exact replacement prose in R-01. I did not merely leave it as an unresolved owner question. Item 14 may contain other members' questions, but the draft should separately record my source-backed closing recommendation rather than omit that position.

No other load-bearing omission from my response is required for this advisory.

## Limits

This review addresses fidelity to my prior questions and disposition only. It answers none of the owner questions and authorizes no PRD edit or implementation.
