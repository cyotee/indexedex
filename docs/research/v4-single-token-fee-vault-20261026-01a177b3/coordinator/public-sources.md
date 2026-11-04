# Coordinator-fetched public pages

Fetched 2026-10-26 by the coordinator. These are page extracts, not the search-tool summaries. Members may still open the pages themselves. A recommendation that cites a page not opened here or by that member stays unverified.

## ICHI vault build

URL: https://docs.ichi.org/ichi-docs-v3/ichi-vaults/technical-concepts/vault-build

Fetched text says ICHI-Vaults manage one Uniswap V3 pool. The default strategy is single-sided deployment. Only the vault owner may rebalance. Fees above a factory base fee accrue to LPs through the vault's assets. Share issuance aims at a fair amount that would cause zero gain or loss if the shares were liquidated immediately. The page says the system uses the lesser asset value to deposit and the larger value to estimate pool value, compares a TWAP, usually one hour, with spot, and rejects a transaction when spot and TWAP differ by more than a threshold, initially 1 percent, and the latest observation is in the current block. Withdrawal returns the vault's assets. The formulas on the page are images, so the exact mint equation was not extracted as text.

This is a priced mint. It is not, on this page, an exit that pays only one token.

## Arrakis docs introduction

URL: https://docs.arrakis.finance/text/arrakisModular/guides/quickstart/introduction.html

The fetched page is Arrakis Pro, not a public ERC-20 depositor vault. It says the issuer owns a vault NFT, Arrakis runs an offchain strategy, and transferring the NFT transfers the funds. Optional Uniswap v4 hooks include price convergence against an external reference and dynamic fees. That external reference is outside this council's premise. This page does not describe a multi-user single-token exit.

## Bunni docs

URL: https://docs.bunni.xyz/docs/v2/guides/pool-creation

Not fetched. The TLS handshake failed. Do not describe that page.

## Bunni incident

URL: https://www.coinspect.com/learn-evm-attacks/cases/bunni/

Fetched text says Bunni V2, a Uniswap V4 hook with a custom liquidity distribution function, lost about $8.4M. The stated cause is rounding down in `BunniHubLogic::withdraw()` when decreasing idle balance by `balance.mulDiv(shares, currentTotalSupply)`. The writeup says the attacker used swaps to push the active balance to a few wei, repeated small withdrawals, then traded against the reduced liquidity estimate. This is not a recommendation of Bunni accounting.

## What these pages do not settle

None of the fetched pages shows a design that earns pool swap fees, mints without marking untraded inventory at the pool price, exits in one token, and exposes a one-share withdrawal-and-sale preview that another hook can trust. That remains the council's question.
