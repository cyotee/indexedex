# pons risk, CTO, and disclosures

Sources: https://docs.ponsfamily.com/ · https://docs.ponsfamily.com/v2 · fetched 2026-07-29

## End-user risk disclosures (both generations)

- Tokens are user-created and experimental; can lose **all** value.
- Names, symbols, and images can be copied — **always verify token address**.
- Prices move quickly; liquidity can be thin; displayed values are estimates, not execution guarantees.
- Smart contracts, wallets, RPCs, and indexers can fail.
- pons UI is not investment advice or a quality signal.
- **Graduation is not a quality signal.**

### v1-specific

- Always WETH-quoted Uniswap V3 pool from launch.
- Launch-window buy limits do not restrict sells/transfers.

### v2-specific

- Creator may set a **creator tax** (capped, fixed at create) — read before trading.
- Custom-pair launches carry **pairing asset risk** (price and liquidity) on top of launch risk.
- Graduation = curve sold out; not endorsement.
- Transactions may be irreversible.

### v2 permanent locks

- Graduated liquidity has **no unlock** path (not creator, not pons).
- Locked excess supply and tokens sent to contracts by mistake are unrecoverable by design.
- Mid-graduation rescue after 7 days is exceptional and permanently marked.

## Community takeovers (CTO)

**What changes:** creator fee recipient (and v2 buyback share). Social surfaces where applicable.

**What does not change:** token supply, pricing, pool, locked liquidity, tax, trading mechanics.

### Process

1. Request via [pons CTO form](https://forms.gle/JjrWvybFeNfE5v8F6).
2. Team review — administrative only; **not** safety/value endorsement.
3. Use only when original creator clearly abandoned and an active community requests fee control.

### v2 routes

| Route | Behavior |
|-------|----------|
| Voluntary | Creator points fees to community wallet immediately |
| Protocol proposal | Public 3-day delay, then 3-day execute window; anyone can execute; pons can cancel during wait |

- Creator moving fees during a pending proposal **does not cancel** the proposal (anti-theft design).
- Surface `pendingCreatorFeeRecipient(token)` (`effectiveAt` / `expiresAt`) so holders get advance notice.

### Security hygiene

- Never share private keys or seed phrases.
- pons will never ask users to send funds to process a CTO application.

## Protocol revenue notes (v1 docs)

- Manual/automated TWAP buyback using **~80%** of protocol fees (not yet immutable/decentralized).
- **~20%** toward infrastructure and team.
- Protocol buybacks acquire PONS and send to burn address; burn-adjusted mcap = `price × (totalSupply − burned)`.

## Attribution

- Onchain data is public; integrators are responsible for use.
- Write product name **pons** (lowercase); link the app when referencing.
- Do not imply partnership/endorsement without written agreement.
- Do not present third-party services as operated by pons.
