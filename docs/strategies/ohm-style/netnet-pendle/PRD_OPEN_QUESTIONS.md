We need to define exactly how the assets held by the hook become inputs to the selected Weighted calculations—and how each quoted operation changes those assets and LP claims.
You have already selected the curve, custody model, public HLP access, input destinations and ownership restrictions. Those are not open choices. What remains is the accounting specification that makes them work together.

1. Map actual holdings to pricing balances
The hook holds several economically different components:
- Pendle LP.
- Retained YT.
- Accrued interest and already-claimed interest cash.
- Custom NET/USDG V2 SE shares.
- Existing NET-DETF inventory.
- Any residual assets from conversion or rollover.
The Weighted math expects balances, rates and weights. We must specify the mapping:
Accounting question	Why it matters
Which holdings contribute to each pricing leg?	A trading currency is not necessarily the asset physically held.
How are Pendle LP and retained YT valued together?	Their value must not be counted twice.
How are NET and sNET normalized?	They can represent related exposure without being interchangeable raw quantities.
How are V2 SE shares valued?	Counting both the shares and their underlying LP would duplicate backing.
How is DETF inventory represented?	Self-issued DETF is trading inventory, not independently acquired external capital.
Deliverable: a table mapping each custody component to its ownership, valuation, pricing leg and permitted uses.
2. Separate valuation from spendable inventory
An asset can support the hook’s accounted value without being available for every output route.
Your requirements already distinguish:
- Ordinary NET/sNET swap outputs: interest inventory only; no principal substitution or complete drainage.
- HLP exits: the holder’s selected proportional or Weighted-priced exit rights.
- DETF burn funding: assets attributable to the DETF’s actual HLP ownership.
- Fee-owned rewards: unavailable for strategy spending, including failed transfers awaiting retry.
We must express those distinctions in the ledger and execution rules. A successful price calculation cannot be treated as proof that the selected route can deliver its output.
3. Define the quote-and-settlement transition for each operation
For every join, swap, exit and burn, the plan needs an explicit sequence:
1. Establish the coherent pre-operation state.
2. Reconcile relevant interest, rewards and prior receipts.
3. Calculate the quote using the correct balances, rates, weights and fees.
4. Execute the required external operations.
5. Measure actual receipts and expenditure.
6. Update custody accounting and mint/burn or transfer the appropriate tokens.
7. Check limits and final conservation; otherwise revert.
For example, a NET-input swap acquires Keep-YT exposure but delivers existing DETF. We must specify how the acquired LP/YT and any residual cash change the pricing book, not merely say “NET goes to Pendle.”
4. Specify HLP issuance and exits
The selected behavior is clear; its exact accounting still needs to be written:
- New HLP must pay for its share of existing accrued value.
- HLP transfers carry that value without leaving a second claim with the seller.
- Proportional exits allocate components proportionally.
- Unbalanced and single-token exits use the selected Weighted calculations—not a proportional-output cap.
- Remaining holders must not subsidize an exit through omitted costs or misclassified cash.
This requires exact fee, rounding, residual and final-exit rules.
5. Construct the DETF-owned burn-pricing book
Your burn must be quoted against only the reserve exposure attributable to the DETF’s HLP, not the entire shared hook.
We therefore need to specify:
- How that owned exposure is derived from the shared book.
- How its components map into the finite-size Weighted quote.
- How the quoted output is physically realized.
- How HLP, underlying holdings and DETF supply change afterward.
The synthetic TWAP decides whether to burn. It does not determine the payout or remove the need to prove funding.
6. Demonstrate first-bond initialization
The first bond must initialize the required Weighted book while accrued interest may be zero.
We need a concrete initial balance/rate mapping that simultaneously satisfies:
- The selected opening price.
- The reference math’s initialization requirements.
- Nonzero HLP issuance.
- The separation between principal and interest.
We cannot manufacture an interest balance by labeling contributed principal as earned yield. If the selected mapping cannot initialize, that is a concrete incompatibility to bring back to you—not permission for an implementer to invent a seed mechanism.
Do you need to make decisions now?
Not from this list alone. The next step is to derive this accounting specification from the selected Weighted implementation, Pendle operations and your PRD.
Most of it should be a determinate technical design. If that work exposes multiple economically different possibilities—such as unspecified weights or a valuation choice that changes who receives value—we should present the specific alternatives and consequences to you before freezing the plan.
The required result is a worked accounting model, with numerical examples and conservation checks, that the implementing agent can follow without choosing the economics.