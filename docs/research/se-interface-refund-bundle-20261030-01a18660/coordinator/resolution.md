# Coordinator resolution

- Draft reviewed: se-interface-refund-bundle-20261030-01a18660-r1
- Draft path: docs/research/se-interface-refund-bundle-20261030-01a18660/coordinator/draft.md
- Draft SHA-256, coordinator-supplied and not recomputed by members: 4e37ac6e38c6fd71dde40fd5f1402408d5131df556a98ad2e0f535958269c2cf
- Final: docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md
- These revisions are coordinator choices after one advisory pass. They are not a new member vote.

| Concern | Disposition |
| --- | --- |
| Astra C1, MiniMax C-1: a return change is not a selector change, and not every old decoder fails | Adopted. The final narrows that claim. MiniMax withdrew the selector claim. |
| Draft sentence that current hooks call the old functions | Removed. No hook caller was examined. |
| G1, MiniMax C-3: `minAmountsOut` is an input floor, not an exact output amount | Adopted. The signatures stay. The prose is corrected. |
| G2: preview does not bind execution bit-for-bit | Adopted. |
| G3, Astra C2: pull the declaration, then transfer the unkept amount; refunded wei are not a deposit | Adopted as settlement text. No new error. |
| G4: carry the current pretransfer comment onto the new functions | Adopted. `EOAPretransferNotAllowed` is not redeclared. |
| G5, Astra C3 and C4: state which input reverts which error, including empty input | Adopted as rules. Error signatures stay. |
| G6: the share may be absent from `vaultTokens()`; new functions sit beside and do not extend the old ones | Adopted. |
| G7: do not accept or wrap `address(0)` | Adopted. |
| Astra C3: `vaultTokens()` order stability is a conformance requirement for the positional bundle, not an existing Basic Vault guarantee | Adopted. |
| Astra C4: reject a zero output recipient | Adopted. Rejecting the vault itself as recipient is also adopted, and labeled a coordinator addition. |
| MiniMax C-2: the interface text needs the settlement rules, not only error names | Adopted in the final NatSpec. No parameter was added. |
| MiniMax C-6: computed selector tags | Adopted after a local `cast sig` of the final signatures. Interface ids are the XOR of those function selectors and must be rechecked with `type(I).interfaceId` before ERC-165 use. |
| MiniMax C-7: an inheriting aggregate has no usable ERC-165 id | Adopted as a reason not to add an aggregate. The disagreement that one should exist is preserved. |
| Kimi: add an exact-out refund surface and change current returns | Not adopted. Recorded as dissent. |
| Astra and MiniMax: named exact-out refund sibling | Not adopted. Recorded as dissent. |
| MiniMax and Kimi: owner-named `exchangeBundleOut` should be exact-out | Not adopted. Recorded as dissent. `exchangeOutOneToMany` stays the current exact-out many route. |
