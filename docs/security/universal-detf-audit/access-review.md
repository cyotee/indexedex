# Universal DETF access and collector review

Static review, 2026-09-05. Reviewed universal Uni V4 DETF / bond NFT authority, fee-oracle manager setters, and shipped FeeCollector selectors and deployment wiring. Applied the [access-control checklist](https://raw.githubusercontent.com/austintgriffith/evm-audit-skills/main/evm-audit-access-control/references/checklist.md). No transactions, Forge commands, or production edits were performed by this reviewer. No exploit instructions are included.

## Confirmed authority boundary requiring product consideration

`contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultTarget.sol:579` permits both the DETF and the **current oracle feeTo** to harvest protocol NFT rewards to a caller-selected recipient (authorization at line 583). This is broader than collecting the fee-owned standing NFT's rewards. `contracts/oracles/fee/VaultFeeOracleManagerFacet.sol:73` allows the oracle owner to replace feeTo immediately; the repository setter at `contracts/oracles/fee/VaultFeeOracleRepo.sol:122` imposes no recipient-type check. Consequently immutable DETF instances still depend on manager authority for this reward-custody boundary.

Suggested correction if protocol-owned rewards must remain exclusively available for reserve compound and claim settlement: restrict `reallocateDetfNftRewards` to the DETF, preserving a distinct collection path for fee-owned NFTs. Both reviewed legitimate DETF callers pass the DETF as recipient: `UniswapV4DetfCommon.sol:370` and `UniswapV4DetfTarget.sol:937` in the same `detf/` directory. This is an explicit privileged capability, not a newly established unprivileged authorization bypass; changing it requires alignment with the intended fee policy.

## Collector routing and capability limits

- `contracts/fee/collector/FeeCollectorDFPkg.sol:113` installs exactly four facets: diamond cut, multistep ownership, fee push, and fee manager. The manager exports only `syncReserve`, `syncReserves`, and `pullFee` at `contracts/fee/collector/FeeCollectorManagerFacet.sol:43`; push exports only `pushSingleTokenFee` at `contracts/fee/collector/FeeCollectorSingleTokenPushFacet.sol:53`.
- `contracts/fee/collector/FeeCollectorManagerTarget.sol:51` makes ERC20 withdrawal owner-only. Permissionless reserve sync and fee push merely read and record actual balances (`FeeCollectorManagerTarget.sol:27`, `FeeCollectorSingleTokenPushTarget.sol:32`). They do not initiate conversion, claim rewards, approve spending, or donate to another DETF.
- The fee standing NFT is minted to the initialization-time feeTo at `contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultTarget.sol:184`. Its reward claim requires the NFT owner or DETF at line 285. The shipped collector has no dedicated method to make this NFT claim or transfer the NFT. Its owner can upgrade the collector; the existing ERC20 `pullFee` method alone does not collect unclaimed NFT rewards. If collection of these rewards is required, add and test an explicitly scoped collector claim capability separately from onward conversion economics.
- No implemented collector-to-protocol-DETF conversion/donation mechanism was found. This is an unresolved downstream product/configuration boundary, not a failure of the user-confirmed producer-to-feeTo-to-collector route.

Deployment checks support the shipped capability set: `scripts/foundry/anvil_robinhood_main/Phase_04_Stage_01_FeeCollectorAndManager.sol:59` and its `anvil_robinhood_testnet` counterpart deploy the same standard collector facets and pass `owner_` into `deployFeeCollector` at line 67. The stage wrapper passes the launch `owner` at `scripts/foundry/anvil_robinhood_main/Phase_04_Stage_01_FeeCollectorAndManager.s.sol:24`. The fee-DETF script likewise passes `owner` at `scripts/foundry/anvil_robinhood_fee_detf/Script_02_DeployIndexedexCore.s.sol:99`; Base main does so at `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol:190`. Searches of `scripts/foundry` found no collector-specific upgrade or ownership transfer to a protocol DETF. This does not establish any deployed instance's current owner or facet set.

## Authorization checks observed

- The parent's current `closeBondMature` owner check is present at `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:687`; no duplicate remediation was attempted.
- Bond NFT position creation, retirement, sale, principal mutation, and held-token transfer are DETF-owner restricted. Selling separately verifies the supplied seller against the current NFT owner; user reward claims verify current ownership. Standing reward IDs cannot be retired or sold through the reviewed methods.
- Donation callbacks use `_requireBondNft` (`UniswapV4DetfCommon.sol:81`), claim-liquidity settlement checks its bond/claim/self caller set (`UniswapV4DetfTarget.sol:917`), and atomic compound is self-only (`UniswapV4DetfCommon.sol:365`). Public child completion uses stored package/configuration arguments with one-time storage guards (`UniswapV4DetfTarget.sol:962`, `:991`).
- Fee destination changes are owner-only; fee/terms setters are owner-or-operator. These are intentional mutable manager powers, not instance ownership. No new missing authorization check was confirmed in the bounded reviewed entry points beyond the parent's already-fixed close path.

## Coverage limits

Static source inspection only. No deployed diamond selector/owner verification, runtime regression tests, full ERC721/diamond implementation audit, complete launch audit, or claim-token arithmetic review was performed. Other specialists cover hook accounting and reentrancy. This report does not establish production readiness.
