# Accounting witnesses — historical proposal analysis

**Superseded policy note:** PRD v0.4 O1–O6 controls. The owner selected no separate claim on unsellable inventory, first-depositor residual benefit, vault-funded costs, oracle-sourced sleeve and router-only native handling. The old choices/fee table below are preserved as the pre-ruling analysis, not current instructions. The positive-V invariant remains an engineering test obligation.

These exact arithmetic examples analyze the candidate; they do not ratify it or prove real PoolManager execution. Units below are integer target/share units with fees set to zero solely to isolate ownership. Test-local references will keep these witnesses executable.

## Positive V and unsold recovery

Incumbents own S=100 shares, 100 local target and opposing inventory producing zero target under current external depth. V_before=100. A new caller contributes 100 target retained locally, so V_after=200 and the candidate m=floor(100*(200-100)/100)=100.

If external liquidity later permits 100 target proceeds from the old opposing inventory, whole-vault V becomes 300. The entrant owns 100/200 of all assets and has gross entitlement 150. Of the 100 recovery, 50 belongs to the entrant. Incumbents receive only 150 of the 200 value they would own without entry. Conservation holds; the question is which owners should receive recovery.

Temporary external LP removal/restoration can create this entry timing. This arithmetic is a necessary ownership counterexample, not a demonstrated profitable protocol attack: actual LP capital, trading, fees and market execution remain to be tested. No fee/rounding adjustment to the candidate by itself preserves an exclusive incumbent recovery claim.

Two explicit policy choices require owner direction:

1. Fungible share owners participate proportionally in all subsequent recovery, including buyers entering at depressed realizable V. This accepts the illustrated transfer of recovery participation; it does not waive SEC-08 or prove manipulation resistance.
2. Preserve recovery claims for pre-entry incumbents. The simple fungible-share candidate cannot do this. A separately specified claim/accounting mechanism or entry restriction is required. No such mechanism is silently selected, and blanket rejection of market-limited valuations conflicts with A1.

## S > 0 and V = 0

S=100 and opposing-only inventory has no currently realizable proceeds. Adding 100 target makes V_after=100, but the candidate divides by zero. Resetting supply, minting against a virtual denominator, transferring old inventory or choosing a recapitalization exchange rate would create an unapproved ownership rule.

Proposed interim policy for review: atomically reject new issuance and zero-payout redemptions while S>0,V=0; retain all inventory and shares, allowing their value to recover. This would block these routes during that state and is not an implementation default. Whether permissionless maintenance can improve that state depends on Gate B/C loss limits.

## Credit is not generally value growth

S=1000,V_before=1000,C=100. If placement loses two target units, V_after=1098 and growth issuance is 98 shares; credit issuance would mint 100. If contribution enables 50 of incumbent recovery, V_after=1150 and growth issuance is 150, despite only 100 new target units. The owner must decide whether attributing that recovery to new capital is intended. Pre-harvest and post-harvest states cannot be interchanged.

## Bootstrap residuals

With no supply, 100 donated target and 100 caller target, allocating every initial share to the caller transfers all donated value to that caller. At a hypothetical 1:1 scale, assigning 100 shares to a permanent sink for liquidatable residuals and 100 gross shares to contribution preserves their separate attribution. Taking a permanent minimum out of the latter reduces caller shares. Scale, minimum and zero-sale opposing residual recovery remain unapproved; this example supplies no numeric defaults.

## Fees and funding proposal for review

| Item | Payer / recipient | Timing and accounting |
| --- | --- | --- |
| Entry usage fee | Caller / configured fee destination | Subtract externally paid target fee before credit; retained fees require explicit incumbent allocation |
| Exit usage fee | Redeemer / configured fee destination | Gross=floor(s*V/S); net=gross-usage fee; include every external outflow in local cover |
| Hypothetical swap fee | Already in V conversion proceeds | Never subtract the same simulated charge again from entitlement |
| Actual swap fee | Execution inventory / external LP and protocol | Must be funded within approved gross and holder-loss bound; it is not a second usage surcharge |
| Fee earned by remaining own LP | Incumbent book | Count once through current position fee growth, not again as local custody |
| Placement/removal rounding | Unresolved operation/holder attribution | Quantify native-unit loss, exclude fictional backing; reference tests bound one add/remove rounding gap per token per position |
| Mandatory harvest | Incumbent book before requested operation, proposed | Isolate caller credit first; losses need a separately approved total bound |
| Rebalance trading and authorized execution costs | Vault inventory | Owner-fixed A4; caller pays network gas; protocol loss/progress limits still unresolved |

No redemption-funding theorem is claimed. Proportional entitlement and prescribed partial execution require real-pool parity and same-state remaining-holder checks. A counterexample blocks that path, not permission to haircut payout.

## Current implementation arithmetic (O1–O7)

Shares use native target decimals, with initial shares equal to credited target units.
There is no sink or permanent minimum. Pre-existing inventory benefits the first holder.
For existing supply, issuance uses floor(S*credit/V), where V is the canonical post-harvest,
pre-entry value. Credit remains isolated during harvest. Placement follows minting and
its actual reserve costs affect the resulting whole book (O4); it is not deducted as a
separate depositor surcharge. This is deliberately distinct from attributing incumbent
recovery or all placement expense to the entrant through the old value-growth candidate.
The no-swap placement/harvest planner accounts each add's rounded-up cost and each
position's removable principal exactly; no fictional rounding backing is carried.
No new Wings-specific entry/exit usage fee is introduced: the existing V4 family has no
such surcharge in its money paths. LP and protocol swap fees are included by PoolManager
and by the quote, once. The live fee oracle still controls the sleeve.

Redemption entitlement is floor(s*V/S), fixed before realization. Vault reserves fund
realization; surplus remains in the book. The implementation checks remaining value
before re-placement against V minus the payout, then records actual placement costs.
This is a conservative execution check, not a proof that all required market states are
fundable. The lifecycle and adversarial tests must establish the supported domain.
Partial exits retain one local target unit. The final exit releases that minimum.
Already-unlocked exits use local cover only, including terminal exits; residual positions
can remain unowned at zero supply and benefit subsequent interaction under O1/O3.

## Withdrawal execution-cost bound (implementation, pending expanded validation)

The preserved partial-exit trace shows an opposing-wing sale of 58,392,872 input
units, followed by core removal. The strict post-payment test was one target unit
below its zero-cost reference. O4 already assigns execution costs to vault
reserves. Caller entitlement and burned shares remain fixed.

The implementation now derives an allowance from the actual intended swap path,
not a fixed wei tolerance or percentage of the vault. For each funded SwapMath
step, let f be its actual combined LP/protocol fee in input units and r its
starting marginal input-to-target conversion rate. The allowance is an upward
rounded upper bound on `(f + 1) * r + 1`: SwapMath rounds required input up by less
than one input unit and produced output down by less than one output unit. The
starting price is the highest conversion rate along that directional step. Two
ceiling Q96 conversions avoid squaring a uint160 and remain conservative. Steps
that consume no input contribute nothing. Empty ticks do not earn an allowance.

The remaining-value guard permits at most the sum of these step allowances for
swaps actually selected by funding. Without a swap it retains the exact original
guard. The allowance is not debited from V or charged again; PoolManager already
settles the real fee. Owned LP fee recovery remains in the canonical valuation.
Projection and execution use the same path calculation. This guard bounds
observable loss; it does not assert every allowed unit was actually lost.

## Measured O1 recovery participation

External full-range removal dropped incumbent V from 997272164917 to 544677734372.
A 1000000000000 target deposit at that depressed V later redeemed 1293002495260
after depth returned. Remaining V was 704269669652. The sum of payout and remaining
V is 5 units below the original V plus the deposit. O1 treats that transfer as
share participation in restored proceeds. A test that caps payout at the deposit
contradicts O1. The accepted bound is no overmint versus depressed V and no
redemption above the pre-exit share of current V.
