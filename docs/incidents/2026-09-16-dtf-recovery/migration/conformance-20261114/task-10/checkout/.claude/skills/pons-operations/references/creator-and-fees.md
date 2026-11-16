# pons creator, fees, and CTO

Sources: https://docs.ponsfamily.com/ · https://docs.ponsfamily.com/v2 · fetched 2026-07-29

## Creating a launch

### v1 checklist

- [ ] Metadata: name, symbol, image, description, social links
- [ ] Fee / creator wallet set correctly (cannot “rename” uniqueness of symbol)
- [ ] **0.0005 ETH** launch fee available
- [ ] Understand: fixed **1e9** supply, locked LP, 1% pool fee, WETH-only
- [ ] Fee split snapshot: 70/30 (current factory) or 90/10 (legacy) — immutable per token

### v2 checklist

- [ ] `launchEnabled()` / whitelist if restricted (`whitelistedLaunchers`)
- [ ] Choose **enabled** `launchConfigId` after reading live config
- [ ] Choose approved quote asset or native ETH (zero address)
- [ ] Set `creatorTaxBps` ≤ `maxCreatorTaxBps()` (0 = standard fee only)
- [ ] Decide `buybackEnabled`
- [ ] Pin `expectedEconomics` from `previewLaunchEconomics`
- [ ] Pay exact `launchFee()`
- [ ] Confirm full supply mints to curve (no creator pre-bag)

## Claiming fees

### v1

- Creator share accrues on locked position.
- Claim from pons interface when available.
- If unclaimed, protocol automation may claim and route to creator payout wallet.
- Split never changes after launch.

### v2

Fees credit **escrow** (pull model so a bad recipient cannot jam everyone):

| Balance | Claim method |
|---------|----------------|
| Native ETH launches | `balanceOf(recipient)` → `claim()` |
| Custom-pair quote asset | `balanceOfToken(recipient, quote)` → `claimToken(quote)` |
| Released buyback vest | Credited as **launch token** → `claimToken(launchToken)` |

Multiple launches against different pairs ⇒ **multiple separate balances**.

### Redirect fee recipient

- **v2:** current recipient calls `transferCreatorFeeRecipient(token, newRecipient)` — immediate; moves future fees + buyback share; does not move already-credited escrow (claim first).
- **CTO / administrative:** form + review; v2 protocol proposal has public timelock (3 days + 3 day execute window).

## Buybacks (v2)

- Optional; funded from **creator share**, not from extra trader tax beyond policy.
- Tokens bought back → vault; **5-year** linear vest with weighted start; not burned.
- Anyone can `release` once vested; split to creator + protocol.
- If buyback would smash price / no liquidity → skipped; funds to creator normally.

## Community takeover (CTO)

**Use when:** clear abandonment + active community wants fee control.

**Form:** https://forms.gle/JjrWvybFeNfE5v8F6

**Does not change:** token, pool, locked liquidity, supply, tax, trading rules.

**Does change:** who receives creator fees (and v2 buyback share) + creator-facing surfaces.

Approval is administrative, not endorsement. Never share keys; never send funds to “process” an application.

### v2 pending proposals

Holders should be able to see proposed new recipient + effective date before it lands. Creator moving fees during wait does not cancel a protocol proposal.

## Support

Integration / partnership / quote-asset proposals: contact@ponsfamily.com
