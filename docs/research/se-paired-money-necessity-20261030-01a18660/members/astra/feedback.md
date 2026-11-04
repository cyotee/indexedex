# Astra advisory feedback

## Identity

- Assigned member: Astra.
- Requested model and reasoning: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, account route, reasoning, role, and task identity: not exposed.
- Scope: one advisory pass on the supplied coordinator draft, using the admitted evidence already read for the initial contribution.

## Draft under review

- Draft ID: `se-paired-money-necessity-20261030-01a18660-r1`.
- Path: `docs/research/se-paired-money-necessity-20261030-01a18660/coordinator/draft.md`.
- Supplied SHA-256: `45ade63e616ad59fb2a61ec0efb22ede5eba1f0ea850334d672349993af90e5e`.
- The hash is supplied provenance, not independently recomputed verification.
- The complete draft was read.

## Disposition

**Support with corrections.**

I support mapping `depositPair`, `previewDepositPair`, `redeemPair`, and `previewRedeemPair` to the four named accepted bundle functions, and keeping `donate` and `compound`. The draft should retain that six-function disposition. Its explanation must distinguish equivalent exchange purpose from identical custody, native delivery, quoting, and redemption behavior.

## Corrections

### 1. Proposed text: maxima and temporary custody

Replace the paragraph beginning "Maxima versus a declared amount" with:

> **Recommendation:** The difference between maxima and declared amounts plus refunds is not sufficient to retain `depositPair`. The old paired ERC-20 path pulls only accepted amounts; the accepted bundle pull path requires funding and authorization for the full declaration, then transfers unkept input back to the caller. Equal net consumption does not make those funding requirements identical, and a required refund transfer can fail. Accept this custody difference for one canonical bundle deposit route. Do not change the standard into a pull-only-accepted route. Removing the paired alias removes a second public entry path that could disagree; it does not by itself prove consistent accounting.

Reason: "The caller is made whole either way" conceals a material balance/allowance and execution difference. The accepted report's refund rule and stage-one S1-OP-01 distinguish these behaviors.

### 2. Proposed text: make the native-I/O recommendation explicit

Replace the raw-ETH paragraph with:

> **Recommendation:** Use wrapped ERC-20 faces for this family's paired bundle entry and payout, and remove the raw-ETH conveniences with the four mapped selectors. Neither accepted bundle function accepts `msg.value` or `address(0)`, and neither supplies raw-ETH payout. This is a proposed product trade-off, not complete preservation of the old methods. Do not extend the standard or invent a replacement product function here. If the owner requires direct raw-ETH paired I/O, the proposed wrapped-only mapping is insufficient and must be reconsidered before implementation.

Also change "tokensOut are the two currencies" in the redemption row to "tokensOut are the two underlying ERC-20 faces, using the configured wrapper for a native leg."

Reason: The current paragraph removes the paired selector while leaving its lost capability undecided. A recommendation can choose wrapped-only I/O without claiming owner approval. Address native deposits as well as native redemption: `depositPair` also supplies a capability the standard does not preserve.

### 3. Preserved disagreements: correct Astra's position

Replace the Astra attribution with:

> Astra: recommend wrapped-only paired entry and payout, explicitly accepting removal of the raw-ETH conveniences; do not extend the standard. Raw-ETH delivery is a real capability of the old paired methods, not a capability of the accepted bundle routes.

Replace the final cell's "The product decision is left open" with:

> The coordinator recommends wrapped-only paired I/O and no standard extension. Owner acceptance of that product trade-off remains outstanding; it is not a locked decision.

Reason: My original did not merely identify a "real unpaired capability" and leave the recommendation open. It expressly recommended wrapped-only paired I/O. Preserve other members' recorded alternatives, but distinguish a concrete council recommendation from the owner's remaining authority to accept it. I have not independently checked peer originals in this advisory.

### 4. Proposed text: preserve paired withdrawal rather than only its name

Add after the six-function table:

> **Recommendation:** The share-input bundle route with both underlying faces should redeem proportionally without selling an unwanted leg, including complete terminal withdrawal where the family's accounting permits it. Consume and burn all submitted shares or revert; return zero share refund on success for this paired withdrawal route. The generic standard permits a refund and does not itself require that stricter family behavior. Preserve recipient, deadline, share minimum, and aligned per-token output floors in the mapped calls. Standard input-funding and pretransfer rules are not the old paired method's direct caller-share-burn contract.

Reason: Merely selecting share input and two output addresses does not establish full-share redemption, proportional allocation, or no-sale settlement. These are recommendations for the mapped economic route, not obligations created by the generic ABI. Avoid silently claiming that the old absence of a share-transfer allowance requirement is preserved.

### 5. Proposed text: explain why both paired previews can disappear

Add:

> **Recommendation:** Remove both paired preview selectors with their mutators and use the corresponding standard previews. For deposit, quoted consumed input at each index is `amountsIn[i] - amountsRefunded[i]`; this includes any input-denominated fee charged and is not necessarily position principal. For redemption, the two quoted receipts follow `tokensOut` order, and the additional refund is denominated in shares. Have the standard previews model the family's selected paired economic path, including maintenance and rounding, rather than retain a second quote path. The accepted standard does not itself promise the old execution-equivalent preview guarantee.

Reason: The table names replacements but does not explain recovery of the old accepted-input information or distinguish quote capability from quote guarantees. E2-E4 of my initial response already support these distinctions.

### 6. Evidence gaps: do not elevate the stage-one equation into new-family law

Replace the second bullet with:

> Mapping specifies the exchange surface, not the new family's issuance, reserve-credit, maintenance, or withdrawal equations. The stage-one PRD, including S1-ACC-07, is historical explanatory context, not interface or accounting authority for this new family. This advisory does not choose or replace those equations.

Reason: "It does not replace S1-ACC-07" can read as making that historical equation binding here. The brief expressly limits the older PRD's authority.

## Limits

This advisory neither replaces the original response or coordinator draft nor authorizes implementation or a PRD lock. It requests no further advisory round. No peer responses, project implementation, or new external sources were read for this pass; no hash command, test, build, deployment, Git operation, or delegation was performed. Only this assigned feedback file was written.
