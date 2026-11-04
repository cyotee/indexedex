# Identity

- Member: astra.
- Run: se-fullspread-implementation-plan-20261104.
- Profile: research.
- Phase: initial independent response.
- Requested role: council-member.
- Requested model: chatgpt-subscription/gpt-6-astra:high.
- Actual runtime model, provider, reasoning setting, and role: not exposed.
- Runtime task ID: not exposed. No task ID is inferred from artifact paths.
- Peers read before submission: no.

# Question and targets

Write a complete implementation and testing plan for UniswapV4FullSpreadStandardExchangeVault from the current PRD, without leaving a product decision to the implementer. Conclusions contains the complete plan. This response does not authorize implementation or amend the PRD.

# Evidence

The following are observations of the admitted sources, not execution results. In Conclusions, PRD identifiers refer to the complete current file at PRD below; section numbers refer to this plan unless explicitly identified otherwise.

| Reference | Source read and use |
| --- | --- |
| PRD | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md, read in full, lines 1-688. Source of the family requirements, FS-A01-FS-A39, and the complete 45-row audit inventory. |
| Brief | docs/research/se-fullspread-implementation-plan-20261104/brief.md, especially Requirement law the plan must copy and Plan shape. Required readings and implementation-name choices. |
| Overrides | contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md:43-55. November 4 event, operator, disable, and inventory locks. |
| Pretransfer | docs/vaults/PRETRANSFER_DIRECTIVE.md, complete. Unbooked custody, caller maximum, short declaration, EOA restriction, and caller-owned share burn. |
| ABI | docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md, complete. Owner lock and accepted scalar and bundle signatures; earlier contrary advisory prose is superseded. |
| Consumers | docs/research/se-fullspread-preview-consumers-20261103/REPORT.md and INDEX.md, both read. The index is cited, not reproduced. Its 1626 occurrences in 618 files are a textual migration inventory, not 1626 independent decoders. |
| Gas | contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md:954-968. 12,000,000 inclusive transaction budget, 11,900,000 cold measured call body plus 100,000 overhead, and 5,000,000 preview budget. No PairToken economics are inherited. |
| Operators | lib/crane/contracts/access/operable/IOperable.sol, isOperator, isOperatorFor, setOperator, and setOperatorFor declarations and documented events. The two appointment signatures are setOperator(address,bool) and setOperatorFor(bytes4,address,bool). |
| Floor | lib/crane/contracts/tokens/ERC20/ERC20Repo.sol:329-346. _mint directly increments balanceOf and totalSupply and emits Transfer; it does not call the zero-recipient-rejecting _increaseBalanceOf. |
| Disable | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol:365-380. The observed predicate checks disable when tokenIn is not address(this). Its observed deadline order is NOT copied: FullSpread's later deadline-first lock wins. |
| Factory | lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:31,49-58,230-231,414-451. Names PostDeployAccountHookFacet.sol and removes its selectors after deployment. |
| Package pattern | contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol:22-42 and UniswapV4PairTokenStandardExchangeVaultDFPkg.sol:327-464. Typed bindings, linked-component validation, and _expectedSelectors are architecture examples only. The latter file:260-265 initializes metadata, EIP-712 name/version, and separate face/discovery ordering. S1-ARCH-04:209-221 is the shared-facet reference, subordinate to FullSpread's selective cut. |
| Matrix | The seven FS-TEST-04 behavior files were searched directly. All exist and declare _newFixture(): single:82, constantProduct/single:66, dual:61, orbital:65, weighted:46, stable/quad/curve:51, stable/quad/balancer:59. Their virtual tests provide family-row extension points. |

# Assumptions

The current PRD and dated overrides are operative. Earlier retirement notices do not prohibit writing this expressly requested new plan, and this plan does not restore deleted code. Names selected below are implementation names, not new economics, selectors with invented hex values, or owner locks. Source observations establish interfaces and required behavior; they do not establish runtime correctness, gas feasibility, or a successful hook bind.

The vault uses the repository token policy: no fee-on-transfer or rebasing underlying; different ordinary ERC-20 decimals are supported. Pause and blacklist failures remain possible token failures, not an invitation to add an allowlist. No independent price feed, TWAP guard, or external valuation requirement is assumed.

# Coverage

Conclusions contains all 19 requested sections in order. Section 17 assigns all 39 FS-A identifiers, including the four withdrawn rows, and all 45 APEX-2026-010 through APEX-2026-054 inventory rows. A no disposition remains no; its file assignment is an exclusion-record location, not a new audit regression. Section 18 maps every requested requirement identifier to the implementation and test sections. Sections 4, 5, 6, 12, and 19 choose the previously unnamed implementation details. No peer response, coordinator draft, or other member file was read.

# Conclusions

## 1. Authority. The plan does not authorize implementation.

This is the implementation and testing plan for one registry-deployed Crane diamond, one hookless V4 pool key, one full-range salt-zero position owned by that diamond, and one ERC-20 share supply. Executing the plan requires a separate implementation instruction. No contract, test, interface, registry, hook, configuration, deployment, or PRD is changed by this response.

Build the family in the new fullSpread directory. Do not restore the deleted legacy V4 families, copy Weir's multi-vault manager, or host this implementation in PairToken or Wings. The only public money operations are the accepted Standard Exchange routes and the locked maintenance operations. There is no sleeve, second share ledger, ERC-4626 or ERC-5115 surface, internal rate provider, or new price protection.

## 2. Sources and precedence.

Apply the November 4 locks in the PRD and Overrides first, then unreplaced November 3 locks, then remaining PRD requirements. Pretransfer is binding for the flag; the later FullSpread bundle-atomicity and one-token-shortfall rules specify its route behavior. Apply the ABI report's owner lock, not its earlier recommendation for WithRefund siblings. Use the preview-consumer report for enumeration, not its stale principal-only withdrawal sentence. FS-OWN-30 supplies the complete exiting claim.

FS-TEST-04 is the audit inventory of record. Do not read the old audit to invent dispositions, reopen a no row, add an ID, or carry forward an expected-result-blocked cell. The gas sentences identified in Evidence are retained engineering constraints, not permission to inherit PairToken's issuance, sleeve, caps, fallback, or rate rules. Package pattern files are examples of validation and factory use only.

Repository factory, registry, compiler, and production-first test rules apply during a separately authorized implementation. Build production artifacts before tests because FactoryServices consume out/ bytecode. Use Solar and no viaIR. This plan's commands and tests are future work, not commands executed in this research phase.

## 3. Adopted readings.

1. A pass-through is one exact-input pool swap, with the direction's MIN_SQRT_PRICE + 1 or MAX_SQRT_PRICE - 1 limit. It is not the liquidity-targeting entry swap.
2. The FS-OWN-33 liquidity-targeting swap is used only for a one-sided deposit or a one-token maintenance balance. It maximizes the following addition's liquidity, leaves any remainder in the processed input token, and has no 48% rule, tighter price limit, zap cap, or tick cap.
3. One planned manager action is one swap or one modifyLiquidity. A locked swap-then-add is two sequential unlocks in the same public call, not one unlock with two actions. Between these actions allow only completion of the first action's settlement; do not insert unrelated external calls, owner/oracle lookups, or payouts.
4. Canonical exchangeIn alone may borrow an already-open manager unlock. It does not call unlock or unlockCallback. The other money/maintenance routes retain ManagerAlreadyUnlocked.
5. Fees collected by deposits are booked, never new-depositor credit. Exits apportion principal, unpaid fees, and previously booked balances before burn. Maintenance processes collected fees and booked balances without minting shares.
6. Donation() and Compounded() are empty markers. Donation is not an interface. No fee-origin store is introduced.
7. Maintenance has three authorization arms: live feeTo owner, global operator, or function operator for msg.sig. Only the live owner appoints either kind.
8. A deadline miss is checked before all other route work, including disable. Disable rejects every non-withdrawal money execution route except donate and compound. It does not suppress views.
9. Bundle pretransfer insufficiency reverts before any leg is spent or minted, without a new error or selector assertion. A one-token underlying shortfall instead spends nothing and returns the available unbooked amount under the minimum-output rules.
10. The floor uses ERC20Repo._mint(address(0), 1_000). Initialized, idle, callback-hash, and reservation checks on a borrowed path have no newly named error; their failures are not relabeled ReentrantOperation or SettlementMismatch.
11. The gas ceilings are unchanged. Hook compositions are measured as entire transactions, including both vault operations and hook work. A budget failure is unresolved evidence, not a silent route cap.

## 4. File map, including Crane files and family files.

Define F as contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ and P as UniswapV4FullSpreadStandardExchangeVault. These abbreviations expand literally in the following filenames; they are not abbreviated source filenames.

| File under F | Responsibility |
| --- | --- |
| interfaces/IP.sol, meaning interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol | Accepted interface composition, family errors, paired and maintenance events. No factory-owned interface aggregation or Donation interface. |
| interfaces/IPDFPkg.sol, meaning interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol | PkgInit, PkgArgs, package API and package errors. Structs live on the interface. |
| PDFPkg.sol | Immutable bindings, validation, exact selector cut, registry dispatch and proxy initialization. |
| PComponent_FactoryService.sol | Artifact-backed CREATE3 deployment of linked libraries and family components; assemble typed package inputs through the manager registration path. |
| PComponentBindings.sol | Fixed six-library binding metadata and hash validation. linkedComponents is facet metadata, not a proxy selector. |
| PTypes.sol | In-memory state, route, action, receipt, quote and settlement structures. |
| PRepo.sol | Family namespace, lifecycle state, booked balances, reservations, and committed callback hash. |
| PMath.sol | Raw-liquidity issuance and burn fractions, WAD fee netting, and existing V4 amount/liquidity rounding operations. |
| PProjection.sol | Economic-state read and projected position amounts, unpaid fees and post-action state. |
| PSwapProjection.sol | The specified V4 swap simulation, tick/fee progression, and the FS-OWN-33 one-sided sizing calculation. This assignment is an implementation name/placement, not new economics. |
| PPlanner.sol | The single quote/plan engine shared by previews and execution; ordered swap/modifyLiquidity actions, amounts, fee/book allocations, refunds and final outputs. |
| PExecutionPreparation.sol | The already required funding, reservation, pretransfer-maximum, caller-share authority and action-payload preparation. No automatic compound. |
| PExecution.sol | Execute selected manager actions and common settlement; apply validated receipts, bookings, share changes, refunds and payouts. |
| PMoneyFacet.sol and PMoneyTarget.sol | Five money/maintenance methods and the IOperable surface required by the later appointment lock, using the existing moneyFacet input. |
| PQuoteFacet.sol and PQuoteTarget.sol | Three accepted exact-in previews through PPlanner. |
| POutFacet.sol and POutTarget.sol | Zero previewExchangeOut and unavailable exchangeOut, with deadline/disable precedence. |
| PQueryFacet.sol and PQueryTarget.sol | reserveOfToken and reserves only. |
| PCallbackFacet.sol and PCallbackTarget.sol | Authenticated, single-use unlockCallback dispatcher. |
| PLiveOwnerModifiers.sol | Live feeTo-only appointment check. Filename is an implementation name. |
| PLiveOperableModifiers.sol | Three-arm maintenance check. Filename is an implementation name. |
| test/bases/TestBase_P.sol | Real-production TestBase, expanded to TestBase_UniswapV4FullSpreadStandardExchangeVault.sol. |

Create the reusable Crane pairs at lib/crane/contracts/protocols/dexes/uniswap/v4/aware/:

- UniswapV4ProtocolAwareRepo.sol and UniswapV4ProtocolAwareFacet.sol, with interface IUniswapV4ProtocolAware.sol in that directory.
- UniswapV4SinglePositionAwareRepo.sol and UniswapV4SinglePositionAwareFacet.sol, with interface IUniswapV4SinglePositionAware.sol there.

Those interface filenames and the single-position directory are implementation names. Keep the protocol components together in one Repo, and the position configuration together in the other. Do not create seven per-component repos. Deploy the facets through a Crane FactoryService, choosing UniswapV4Aware_FactoryService.sol in the same directory as an implementation filename. Crane specs are lib/crane/test/foundry/spec/protocols/dexes/uniswap/v4/aware/UniswapV4ProtocolAware.t.sol and UniswapV4SinglePositionAware.t.sol. They test reusable behavior separately from the registered vault.

Reuse ERC20Facet, ERC2612Facet, ERC5267Facet, MultiAssetBasicVaultFacet and the existing standard-vault facet. Factory evidence comes first: DiamondPackageCallBackFactory.sol:31 names lib/crane/contracts/factories/diamondPkg/PostDeployAccountHookFacet.sol; :230-231 and :414-451 show its post-deploy removal. Therefore PostDeployAccountHookFacet.sol is the selected, evidenced temporary-hook filename, not a new family file. Do not put it or factory introspection facets in PkgInit.

The seven family specs and seven hook-row filenames are named in sections 16-17. Return-ABI migration includes the shared interfaces and indexed live consumers, not just this new family's files.

## 5. Package, initialization, and validation, with the chosen field names.

Use this concrete PkgInit binding order. The ordering and newly chosen names are implementation details; every binding is included in bindingHash:

1. erc20Facet, erc2612Facet, erc5267Facet, basicVaultFacet, standardVaultFacet.
2. moneyFacet, quoteFacet, outFacet, queryFacet, callbackFacet.
3. uniswapV4ProtocolAwareFacet, uniswapV4SinglePositionAwareFacet: the chosen names for the two required Crane facet inputs.
4. poolManager, registry, oracle, diamondFactory, linkedLibraries.
5. weth, positionDescriptor, positionManager, quoter, stateView, reservesLens, universalRouter.

The last six architecture names after weth are the chosen names for the six architecture addresses besides poolManager. linkedLibraries is address[6] in the exact order Math, Projection, SwapProjection, Planner, Execution, ExecutionPreparation. Do not use an open IFacet array or add syMoneyFacet, syQueryFacet, wrappedNative, a rate binding, or an operator-facet package field. Host the required IOperable methods in moneyFacet rather than invent another package input.

The seven V4 infrastructure addresses are package immutables. At instance initialization write their values once into UniswapV4ProtocolAwareRepo. WETH is passed per deployment through weth and written with WETHAwareRepo._setWeth; no Robinhood constant is hardcoded. Registry, oracle and factory remain the bound infrastructure. Do not add a second family copy of protocol addresses or a stored feeTo owner.

PkgArgs contains only PoolKey poolKey, string name, string symbol. Package validation checks code-bearing required components, exact supported facet selectors, family linked-component hashes and fixed library bindings. Reject invalid components with InvalidComponent; specifically reject cuts containing getRate or rateAsset. Validate only that the pool is initialized on the bound manager and has hook address zero; use InvalidPoolKey. Do not restore the PairToken domain, minimum spacing, rateAsset, wrapper collision, zap-limit or allowlist checks. Do not invent an exclusion for a face collapse after WETH substitution.

calcSalt and processArgs execute in the factory delegatecall context, resolving package immutables through the package's self-call pattern. deployment identity includes canonical arguments and bindingHash. processArgs requires BOTH msg.sender == registry and address(this) == diamondFactory, otherwise NotCalledByRegistry. deployVault(PkgArgs) returns the registered vault address through the bound registry. No alternative direct diamond factory deployment is accepted in production or the family tests.

initAccount verifies the bound package/arguments/factory initialization context and rejects mismatches with InvalidInitializationContext; repeated initialization reverts AlreadyInitialized. Initialize ERC20Repo with name, symbol and 18 decimals. Initialize EIP712Repo with PkgArgs.name and version "1"; this version is an implementation value, following the cited package pattern, not a new token or fee rule. Domain chain ID and verifying contract resolve for this proxy. Initialize the stable vaultTokens face list in PoolKey order, with WETH replacing native, and standard-vault declarations through the shared repositories. A sorted copy may be used for registry discovery/contents hashing; it must not reorder the public positional face list.

Initialize SinglePositionAware with poolKey, TickMath.minUsableTick(tickSpacing), TickMath.maxUsableTick(tickSpacing), bytes32(0). Start with no position liquidity, no shares, no booked balances, zero reservations and an empty callback commitment. The first successful public deposit creates the position. Do not seed a floor during package initialization or approve Permit2 through a typed bool-returning token call. If an approval is necessary on a deployment path, use the repository safe optional-return token operation.

## 6. Storage.

Choose the family namespace "indexedex.vaults.standard.exchange.uniswap.v4.fullspread". Its slot is bytes32(uint256(keccak256(abi.encode(namespace))) - 1), not the hash of packed text. This is a chosen implementation name. Assert that it differs from the actual PairToken and Wings slots in package tests; never assume a string difference alone proves the numeric assertion.

Family storage holds initialized state, the public-operation guard/lifecycle state, the pending action commitment, bookedBalance0/bookedBalance1, and operation reservations for each currency and caller shares. These field names are implementation names. Persist only accounting/lifecycle data needed across the callback; carry transient calculations and selected actions in memory/payload. At stable completion reservations and commitment are zero and the public-operation guard is released.

ERC20Repo is the only share ledger. OperableRepo is the only operator-grant store. WETHAwareRepo is the WETH binding. UniswapV4ProtocolAwareRepo stores the seven architecture addresses; UniswapV4SinglePositionAwareRepo stores the key, ticks and salt. Shared basic-vault storage holds face membership, not the family reserve valuation. Use the existing bound fee-oracle storage path without caching its owner.

Do not persist position liquidity as an authoritative duplicate of manager state, a last-committed reserve snapshot, a local-reserve target, a rate asset, provider address, fee-origin tags, virtual shares, or second supply. Read deployed liquidity live. Read reserves as existing position amounts plus unpaid fees, excluding all local custody, even booked custody.

For custody accounting distinguish: booked holder balances; the current operation's reserved inputs/output claims; and unbooked held tokens. Available pretransfer input is unbooked held balance, excluding booked and already-reserved custody. Funds received while settling an action cannot be reclassified as a later caller's input. Normalize native/WETH only at settlement boundaries; never book the same value under both representations.

## 7. Selector cut.

Construct and validate an explicit _expectedSelectors manifest. Use the pattern at the cited PairToken DFPkg:327-464 and S1-ARCH-04, not its actual old selector lists or its 61-selector count. The final persistent proxy manifest is the disjoint union of package selectors and persistent factory selectors. linkedComponents and facet metadata are not installed proxy selectors.

| Cut destination | Installed functions |
| --- | --- |
| erc20Facet | name, symbol, decimals, totalSupply, balanceOf, allowance, approve, transfer, transferFrom. |
| erc2612Facet | permit, nonces, DOMAIN_SEPARATOR. |
| erc5267Facet | eip712Domain. |
| basicVaultFacet | vaultTokens only; filter the shared facet rather than installing its stored-balance reserve readers. |
| standardVaultFacet | vaultFeeTypeIds, contentsId, vaultTypes, vaultConfig. |
| moneyFacet | exchangeIn, exchangeBundleInForSingleOut, exchangeBundleOut, donate, compound; setOperator, setOperatorFor, isOperator, isOperatorFor implementing the locked IOperable behavior. This placement is an implementation choice. |
| quoteFacet | previewExchangeIn, previewExchangeBundleInForSingleOut, previewExchangeBundleOut. |
| outFacet | previewExchangeOut, exchangeOut. |
| queryFacet | reserveOfToken, reserves only. |
| callbackFacet | unlockCallback. |
| uniswapV4ProtocolAwareFacet | poolManager, positionDescriptor, positionManager, quoter, stateView, reservesLens, universalRouter. The six additional getter names are implementation names for the required stored components. |
| uniswapV4SinglePositionAwareFacet | poolKey, tickLower, tickUpper, positionSalt, positionLiquidity. positionSalt is the chosen name for the stored salt getter. |

The family has no poolManager or poolKey implementation competing with the Crane facets. positionLiquidity uses StateLibrary.getPositionInfo with address(this), stored ticks and salt, not PositionManager NFT accounting or StateView as an execution dependency.

Preserve scalar parameter selectors: previewExchangeIn 0x89d61912 and exchangeIn 0xd02d3063, both with two-word returns. Register IStandardExchangeIn as 0x59fb2971, not 0x8c8035da or 0x676ec907. Bundle selectors are the accepted 0xc2fe8c7c, 0xe7886166, 0xa5952fc2 and 0x11993461; verify interface IDs 0x2576ed1a and 0xb40c1ba3 using type(I).interfaceId in the implementation tests before registration. Register only truthfully implemented interfaces; do not advertise an empty inherited aggregate as a capability.

Exclude asset, getRate, rateAsset, basket, localReserves, wrappedNative, all ERC-5115 selectors, depositPair/redeemPair and their previews, previewWithdrawalMode, previewZapCredit, maxZapBps/maxZapTickMove, WithRefund siblings, exchangeInUnlocked and the three speculative quote interfaces. No new hex selectors are guessed. Factory ERC-165, ERC-8109 and loupe remain callable; the temporary postDeploy hook follows actual factory removal and must not remain an unprivileged entry point after deployment.

## 8. Check order for each public mutator.

The following is the implementation order for the financial entrypoints. Where the PRD does not specify priority between two otherwise valid rejects, this order is an implementation choice, not a new error contract. All public money routes are nonpayable; raw value is rejected at the ABI boundary.

| Mutator | Ordered checks and action |
| --- | --- |
| exchangeIn | Deadline first; classify whether the route is an actual share-to-underlying withdrawal for disable; enforce disable; acquire/check the public-operation guard and initialized state; reject zero/self recipient, identical tokens, zero input and zero/unsupported token route; check caller funding/share authority and pretransfer eligibility; read manager unlocked state and validate locked/borrowed context; reserve inputs; plan, execute, verify minima, mint/burn, refund/payout, release guard. |
| exchangeBundleInForSingleOut | Deadline; disable (always blocked when disabled); public guard/initialization; recipient; amounts length == vaultTokens length, nonempty/non-all-zero input and supported share output; pretransfer code check and ALL declared-balance checks before processing any leg; manager must be locked; fund/reserve both legs; proportional add, book fees, net mint, minima and refunds; PairDeposited; release. |
| exchangeBundleOut | Deadline; classify a share input plus the two valid underlying outputs as withdrawal, then disable; guard/initialization; recipient; nonzero amount, nonempty output list, minima length, no duplicates, no zero addresses or input in outputs; require exactly the two faces, accepting caller order; caller share ownership/approval and flag checks; manager must be locked; remove/apportion, verify per-index minima, burn caller shares and pay in requested order; PairRedeemed; release. |
| exchangeOut | Deadline; disabled route always VaultDisabled because no supported withdrawal execution exists here; on an enabled vault revert ExchangeOutNotAvailable without funding, allowance changes or state mutation. |
| donate | No deadline and no disable block. Guard/initialization; live owner/global/function authorization; valid underlying face or share; nonzero supply before any swap; pretransfer or caller funding/share authority; manager must be locked; process donation and maintenance, settle/book, then markers; release. |
| compound | No deadline and no disable block. Guard/initialization; live owner/global/function authorization; manager must be locked; if there are no unpaid fees and no booked balances, return without state changes/events; otherwise collect, process and book, emitting Compounded only on a deposit. |
| setOperator / setOperatorFor | Live feeTo-owner check before changing OperableRepo; set/revoke exactly the global grant or specified selector grant, emit IOperable's matching event and return bool. Operator status alone cannot appoint. No stored-owner check. |
| unlockCallback | Bound manager caller; active guard; committed operation/payload hash; single-use consumption; execute exactly the committed action and settle; reject forged, replayed or unsolicited callbacks. This is not an alternate deposit entrypoint. |

The inherited ERC-20 approve/transfer/transferFrom and permit methods retain their shared token/permit checks; they are not Standard Exchange execution routes. The disable table does not introduce a transfer freeze or a stored-owner gate on operator appointment. Views, including operator queries, do not execute financial routes.

For a locked one-token underlying pretransfer whose declaration exceeds available unbooked balance, do not pull, swap, add, or mint. Return zero output and the actual unbooked amount to the payer when the caller minimum permits zero; a binding positive minimum still fails atomically under the existing minimum error. No new shortfall error is introduced. This special path does not permit spending parked shares: all share burns require caller ownership/approval, regardless of pretransferred. EOA pretransfer stays rejected. A bundle shortfall always reverts before any leg, even if all minima are zero.

## 9. One-sided deposit, bundle deposit, one-token exit, both-token exit, and pass-through.

Use raw V4 liquidity and native token units, never decimals-normalized amounts, for issuance. Read totalSupply S and existing deployed liquidity L before a new deposit addition. Fees and local balances do not enter L. Let added liquidity be dL. For genesis require dL > 1_000, mint floor 1_000 to address(0) with ERC20Repo._mint, and set grossShares = dL - 1_000. Otherwise grossShares = floor(dL * S / L), using full-precision multiplication/division. Metadata decimals is 18; it does not scale S, dL or the floor.

Resolve feeTo and usageFeeOfVault(this) before the manager action chain. Apply f = min(resolvedFee, 3e17). If feeTo is zero, feeShares = 0; otherwise feeShares = floor(grossShares * f / 1e18). Mint only feeShares to feeTo and grossShares - feeShares to recipient, skipping zero mints. No fee-on-fee mint. Net depositor shares are amountOut and the minimum/preview value. Zero configured fee stays zero; 1e13 charges 0.001% without rounding the setting to three digits. This clamp never writes the oracle.

**One-sided deposit.** Pull the entire declaration or reserve its eligible pretransfer maximum. Planner selects the FS-OWN-33 balancing swap and following full-range addition. The swap's received opposite token must be entirely allocated to that addition; its unswapped processed-token balance supplies the other side, and any remainder is in the original input token. The selected swap input is not the amount of processed token consumed by the add. Settle the swap action, then the addition action; book the addition's feesAccrued separately, including incumbent fees realized by that addition, without adding them to dL or the caller's allocation. Mint net shares only for actual added liquidity. Refund original input not kept to msg.sender, never recipient and never the booking store. Do not require full swap consumption or add IncompleteConversion.

**Bundle deposit.** Inputs are positional in stable vaultTokens order. A zero slot is not a provided token; validate positive slots without inventing a one-sided balancing route for the bundle. Use the pool ratio to add the proportional pair, without a swap. Book returned feesAccrued, mint under the same genesis/later fee formula, and refund each declared token remainder to the payer. AmountsLengthMismatch, unavailable route, minimum and funding errors use accepted interfaces. A successful call returns net shares and the ordered refunds and emits PairDeposited(msg.sender).

**Both exits.** Before burn snapshot S, L, unpaid fees F_i and already booked balance B_i. For caller-owned shares s, compute l = floor(L*s/S), feeClaim_i = floor(F_i*s/S), bookedClaim_i = floor(B_i*s/S), multiplying before dividing. Remove l from this diamond's sole position. Separate actual principal receipt P_i from feesAccrued; do not count collected fees again as old booked balances. The exiting claim C_i = P_i + feeClaim_i + bookedClaim_i. Keep B_i - bookedClaim_i and newly collected fees less feeClaim_i booked for the remaining holders. The floor stays in S. Do not allocate all residual custody to a supposed last live holder and thereby erase the floor's fraction.

**One-token exit.** Use exchangeIn(share,s,selectedUnderlying,...). Swap exactly C_opposing, comprising unwanted principal plus the exiting holder's opposing unpaid-fee and booked claims. Add swap output to C_selected. Full conversion is required: if any unwanted exiting amount remains, revert AmountOutNotMet, without final burn or payouts. Do not book, return in a surprise token, or keep that residual. Check the caller's minimum against the final selected-token payout, burn only caller shares under the accepted approval flow, and pay recipient. Standing-holder booked inventory is never a swap input. Fees generated for the remaining position by this exit's swap are later live position fees, not an extra pre-burn exit claim.

**Both-token exit.** exchangeBundleOut accepts share input and exactly both faces, in caller-specified order. Remove/apportion once, do not swap, enforce minAmountsOut at the caller's indices using MinAmountNotMetAt, burn caller shares, and pay those two claims. It returns amountsOut in that order and zero share refund for a successfully fully consumed share declaration, and emits PairRedeemed(msg.sender). A one-output bundle is unavailable, not the one-token exit API.

**Pass-through.** exchangeIn(face0,amount,face1,...) or reverse performs one exact-input swap on the bound pool with the unbounded directional limit. It does not run FS-OWN-33, add/remove this position, mint/burn shares, take a usage fee, or compound. Return the actual output and same-input refund under FS-OWN-32. Honor minAmountOut. A disabled pass-through reverts, including on borrowed unlock.

All routes pay outputs to recipient and refunds to msg.sender, skip zero refund transfers, and revert atomically on required delivery failure. They do not adopt unrelated unbooked balances. A user operation does not deploy standing-holder booked balances or call public maintenance.

## 10. donate and compound.

Implement donate(address token,uint256 amount,bool pretransferred) and compound(). The first has no recipient/deadline and the second has no arguments. Use the live authorization in section 14, keep them available while disabled, and reject an open manager unlock. A donation is unavailable before first supply and must fail before any swap; no newly named error is specified for that condition.

For underlying donation, acquire the directed amount using the same declared-maximum/unbooked-custody distinction as the pretransfer directive. Pull the directed amount on the pull path. A valid donation contributes no shares. A share donation burns caller-authorized shares without removing liquidity or swapping shares; then its compounding work processes the vault's collected fees/booked tokens. Never burn share tokens parked on the vault as the caller's donation credit.

Collect unpaid position fees by a zero-liquidity modifyLiquidity when collection is needed; this collection is a manager action with its own locked unlock. Combine collected fees, pre-existing booked balances and any directed underlying donation. Do not use the deployed position as swap inventory.

If that processing balance has exactly one nonzero token, use the same FS-OWN-33 swap/add sizing as a one-sided deposit, at the unbounded price limit. If it already has both tokens, make the proportional addition without a swap. Scarcity is the ratio-relative side, not the numerically smaller token amount. Consume the scarcer side of the matched deposit and retain the other-side remainder. Execute the simplest single selected processing sequence; do not retry, choose a collection-only fallback, catch a failed step, or insist that the remainder be small.

After settlement, book the actual held remainder rather than the planner's algebraic leftover. This deliberately can book stray transfers, including non-atomic pretransfers; callers must transfer and consume atomically. Do not refund a valid donation/compound remainder. Do not apply this actual-balance booking rule to user entry refunds. The one-token maximum-shortfall branch still processes none of the insufficient directed input and refunds available unbooked input as required by FS-OWN-32; existing booked/collected maintenance balances remain distinguishable from that refunded declaration.

A clean compound with no fees/booked remainder is a true no-op with no event. A successful donate emits Donation() even if nothing was deposited. Emit Compounded() exactly when a deposit uses collected fees or previously booked tokens, including during donate. A deposit solely from a fresh donation emits Donation but does not invent fee origin for Compounded; once a donation remainder is booked, it is treated as fees on a later call. No persistent fee-origin tracking is needed. A deposit-nothing maintenance call emits no Compounded, and a reverting call leaves neither marker.

The accepted owner/operator sandwich exposure remains. Do not represent the authorization check as a price defense or add a fee cap, tick bound, protected price, or disclosure selector.

## 11. Locked and borrowed unlock paths.

Hold one public-operation guard from before funding/token calls through final payout and all manager actions. Internal action execution/accounting/settlement is shared. The only difference is how the manager becomes available and which completion condition is applicable.

**Locked dispatcher:** for each swap or modifyLiquidity action commit keccak256(abi.encode(operation,payload)), then call manager.unlock once. Callback checks caller, held guard and exact commitment, consumes the commitment before executing, performs that single action, settles it and validates the vault-owned unlock's completion. After unlock returns verify the manager is locked again and the commitment consumed before progressing. Do not bunch multiple selected actions into one callback. Deposit swap/add is two unlocks; an exit remove/swap is two; a fee-collection poke counts separately when selected. Do not make an unrelated external call between sequential actions; action settlement is the only inter-action external work. Keep cached bindings/fee inputs and the plan in memory. Callback replay, nested unlock and an unsolicited manager callback fail.

**Borrowed dispatcher:** before starting, the diamond must be initialized and idle, with empty commitment and zero reservations, and its own two backing-currency deltas must be zero. Check these before marking the new operation active; distinguish an active reentrant call (ReentrantOperation) from unnamed state-precondition failures. Nonzero own-delta context is rejected; do not relabel it as a generic idle failure. The caller has code, funds its own input, supplies pretransferred=false, and owns/authorizes shares burned. Invalid borrowed context uses InvalidUnlockedContext and normal funding/route failures retain inherited errors. Raw value fails nonpayability, not an internal invented msg.value error.

Run the same plan directly through manager.swap/modifyLiquidity on this diamond's pool, without unlock or unlockCallback. There is no payer parameter, callback-data authority, foreign creditor, hook allowlist or nested external request to settle a third party. A funded non-hook contract is valid. A batch containing other V4 pools is valid.

For each owed ERC-20 currency perform sync(currency), transfer the exact debt to the manager, then settle; only then take owed credits. For native debt unwrap only the required WETH boundary amount and sync native immediately before value settlement, resetting a prior ERC-20 sync checkpoint rather than assuming it remains usable. Wrap manager-native credits before any caller-facing ERC-20 payout/refund. No native caller payout and no double-counted WETH/native backing are allowed.

The sync slots are manager-global. Never use settleFor on a foreign address, consume foreign credits, or clear another actor's sync checkpoint as camouflage. If the selected action cannot close this diamond's touched currency deltas through its own funds, revert SettlementMismatch. Before borrowed return assert this diamond's deltas are zero, not the global nonzero-delta count. Outer hook/router deltas may remain; their eventual settlement is the outer actor's obligation.

Any failure rolls back this call and descendants. A propagated failure rolls back the outer transaction too. If the outer actor catches a failed vault call, the vault is restored, the manager remains under the outer unlock, and the outer actor still owes its own deltas. There is no sleeve fallback or automatic compound in either path.

## 12. Quotes and previews.

Choose UniswapV4FullSpreadStandardExchangeVaultPlanner as the one shared quote engine. Both quote targets and execution preparation call that engine with the same economic state and route intent. Projection reads pool price, initialized ticks/liquidity, fee growth, this position, supply and book; SwapProjection models the selected swaps using the same V4 integer math, fee and tick progression as execution. Execution sends the resulting manager parameters and reconciles actual receipts; it does not calculate an independent second economic quote.

For FS-OWN-33 sizing, solve the integer feasibility problem for maximum added liquidity at the post-swap price: swap output supplies exactly the other-token addition requirement, original input pays swap input plus the processed-token addition requirement, and only original input may remain. Implement deterministic integer search over feasible liquidity/swap quantities using the complete swap projection and the actual rounded addition amounts, including tick-boundary candidates. Resolve equal-liquidity candidates by spending the least original input. This tie-break is an implementation choice for the specified maximum-liquidity/refund result, not a new cap. Validate final integer candidates against exact projected receipts; prove no larger feasible candidate remains in the search interval. Do not approximate with 48%, about-half, a fixed retry count, a fixed tick walk, or an input-delta/add-cost confusion. Internal swap sizing does not create a public exact-out route.

Exit simulation first projects the removal and fee/book allocation, then the swap against the post-removal pool. It must not quote the exit swap using pre-removal liquidity. Deposit simulation accounts for the post-swap price and the same mint fee clamp. Every preview excludes pre-existing fees from mint credit and includes the exiting holder's fees/booked claim for redemption. Both-token exit preview has no simulated swap. Pass-through uses its own exact-input swap intent, not the liquidity-targeting intent.

previewExchangeIn returns (netSharesOrPayout, sameTokenRefund); previewExchangeBundleInForSingleOut returns (netShares, positionalRefunds); previewExchangeBundleOut returns (callerOrderedOutputs, shareRefund). Unsupported scalar routes return zeros; unsupported bundle routes return a zero-valued result with array shape appropriate to the declaration, without an execution error. previewExchangeOut always returns zero and retains its one-word ABI. Refund previews assume declared funds exist and must not read caller or vault custody to establish the declaration's availability. Execution's shortfall refund may differ. At equal economic state, successful exit amountOut/amountsOut must match execution, and caller minima bind; the refund-word exception is not an exit-output exception.

Economic reads remain live while the manager is busy or unlocked and do not revert a vault-defined error. reserveOfToken returns zero outside vaultTokens. reserves and reserveOfToken use the existing position-amount and fee-owed reads; do not add a new conversion through the stored Reserves Lens, a local term, or a snapshot. Quote work has no artificial step cap, QuoteWorkLimit, partial-result success or minimum tick spacing. An EVM out-of-gas remains distinct from an invented admission error. Prove correctness against real manager outcomes and measure actual work under section 17 rather than claiming an unmeasured gas guarantee.

There is no getRate, SY exchangeRate, NAV substitute or vault-owned provider. External IStandardExchangeRateProviderDFPkg instances use reserveVault, rateSubject and rateTarget; the hook configures them per liquidity leg. Test both underlying targets, including two pools rating the same vault against different targets, without introducing a provider-count cap or storing providers in this vault.

## 13. Events and errors.

Family money events are PairDeposited(address indexed caller), PairRedeemed(address indexed caller), Donation(), and Compounded(). The paired markers are on their mapped bundle routes only. ERC20 Transfer records mint/burn; PoolManager Swap/ModifyLiquidity, filtered by this diamond as sender, supplies execution amounts/price/liquidity. Do not add a family swap/liquidity or amount-bearing maintenance event. IOperable appointment emits its existing NewGlobalOperatorStatus and NewFunctionOperatorStatus events.

Family interface errors are InvalidUnlockedContext, SettlementMismatch, ManagerAlreadyUnlocked, ReentrantOperation, InvalidRoute, MinLiquidityNotMet and InvalidRecipient. Package errors are InvalidComponent, InvalidPoolKey, NotCalledByRegistry, InvalidInitializationContext and AlreadyInitialized. Use the existing accepted interfaces for EmptyExchange, TokenNotExchangeable, ExchangeInNotAvailable, AmountsLengthMismatch, ExchangeBundleInForSingleOutNotAvailable, TokenAmountsLengthMismatch, DuplicateOutput, MinAmountNotMetAt, ExchangeBundleOutNotAvailable, DeadlineExceeded, AmountOutNotMet and ExchangeOutNotAvailable. Use IVaultRegistryDisableQuery.VaultDisabled(address(this)) for disabled financial execution. Keep existing EOAPretransferNotAllowed and operator authorization errors at their owning interface.

ManagerAlreadyUnlocked is the vault's noncanonical-route guard, not PoolManager.AlreadyUnlocked. Do not declare a new bundle-shortfall error or pin a selector in its tests. Unnamed borrowed initialization/lifecycle/commitment/reservation rejects stay unnamed; use generic revert assertions together with unchanged-state assertions, not either named settlement/reentrancy error as a catch-all.

Do not declare IncompleteConversion, QuoteWorkLimit, rate-only errors, ExchangeInWithRefundNotAvailable, a new MinAmountNotMet, or UnderlyingUnavailable for an unpullable borrowed exit. Do not add a Donation interface or ERC-165 ID. Compute new interface/error/event selectors during implementation; this plan does not guess them.

## 14. Operators.

Resolve the current owner as address(VaultFeeOracleQueryFacet.feeTo()) on the bound oracle, whose return is IFeeCollectorProxy. It is the proxy address, not a presumed EOA behind it. Do not expose feeTo on this vault.

PLiveOwnerModifiers permits only that live owner to call setOperator(address,bool) and setOperatorFor(bytes4,address,bool). Set/revoke grants in OperableRepo and expose the corresponding IOperable read methods. PLiveOperableModifiers accepts the live owner OR a global grant OR a function grant for msg.sig. It protects donate/compound only; operators cannot appoint through their maintenance grant. Do not call MultiStepOwnableRepo._onlyOwner or OperableModifiers.onlyOwnerOrOperator, or capture feeTo at initialization.

Test global and per-selector grant/revoke independently; a donate-only grant must fail compound and vice versa. Changing oracle feeTo changes owner authority immediately. The old owner is no longer owner; an independently stored operator grant retains its ordinary OperableRepo semantics until revoked. Do not invent automatic operator-list clearing on a feeTo change. Use a caller that is neither owner nor operator for stranger negatives and distinguish it from a global operator.

## 15. Disable.

Read the live registry disable condition. Apply the V2 input-share predicate to genuine supported withdrawals, widened to all FullSpread financial routes under FS-OWN-26. Do not copy V2's observed disable-before-deadline sequence: the November 4 deadline-first lock wins.

| Disabled call | Result after an unexpired deadline, where applicable |
| --- | --- |
| underlying-to-share exchangeIn | VaultDisabled. |
| underlying-to-underlying exchangeIn | VaultDisabled. |
| share-to-underlying exchangeIn | Withdrawal stays available, subject to all ordinary checks. |
| exchangeBundleInForSingleOut | VaultDisabled. |
| share-to-both-underlyings exchangeBundleOut | Withdrawal stays available on a locked manager, subject to ordinary checks. |
| exchangeOut | VaultDisabled, not ExchangeOutNotAvailable. |
| donate / compound | Available to authorized callers with ordinary locked-manager constraints. |
| previews and reserve/position queries | Compute normally; no VaultDisabled. |

Repeat the exchangeIn rows inside borrowed hook execution: buffered withdrawal succeeds, buffered deposit and pass-through fail VaultDisabled. Run enabled exact-out negative fixtures separately. A stale deadline must win even if the vault is disabled, the input is malformed, or the route would otherwise be unavailable. Deadline equality is not a miss.

## 16. Hook integration, matrix rows, and 32-byte preview migration. Cite the consumer index. Do not paste it.

Treat return-width migration as a prerequisite to usable hook/rate fixtures. Cite docs/research/se-fullspread-preview-consumers-20261103/INDEX.md as the full occurrence inventory, with its REPORT.md as the classification evidence. Do not paste the index, count every occurrence as a decoder, or treat preserved audit copies as live implementations.

Update IStandardExchangeIn, every live implementation/override and one-word reader to the two-word return; also migrate exchangeIn decoders. For legacy full-consumption implementations use their actual unused-input behavior, including zero refund only where no refund occurs; do not fake a universal zero merely to compile. Keep parameters/selectors unchanged. Update typed destructuring even for a call that ignores output. Migrate low-level decoders and the six reported exact-32-byte gates to the accepted 64-byte tuple contract, preserving failure behavior for failed/malformed calls. Update the FundedThresholdAssertions decoder, both named frontend ABI bindings, live scripts, tests and handlers, and regenerate applicable ABI-derived bindings from source rather than hand-edit generated output. Preserve historical snapshots as evidence, explicitly classifying them as non-live.

The six gates are two sites in StandardExchangeRateProviderFacet, one in WrappedStandardExchangeRateProviderTarget, and one each in CommonBufferMultiVaultStablePoolHookTarget, MixedBufferMultiVaultStablePoolHookTarget and CommonBufferMultiVaultWeightedPoolHookTarget at the locations recorded in Evidence's Consumers report. The frontend bindings are frontend/apps/indexedex/app/insights/lib/insightsAbi.ts and frontend/packages/protocol/src/protocolDetfAbi.ts. Validate a legitimate 64-byte result, malformed/short return and failed call, and ensure amountOut, not amountRefunded, supplies the rated amount. A tuple-capable selector cannot be inferred solely from ERC-165.

Add a concrete FullSpread row beside each existing behavior contract using its _newFixture extension. Use the following exact new row filenames under test/foundry/spec/hooks/uniswap/v4/standardExchange/. These are implementation filenames. Instantiate real registered FullSpread vaults and bind the same PoolManager as the hook.

| Family / existing behavior filename | New sibling row filename | Required fixture |
| --- | --- | --- |
| single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol | single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol | One SE and pair token; borrowed mint and burn in both exact-input directions. |
| constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol | constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol | FullSpread buffered leg and a raw leg; name the actual converting leg. |
| dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol | dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol | Canonical disjoint-backing-pool cross-vault proof. |
| orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol | orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol | se0/se1/se2 and rp0/rp1/rp2, three valid legs, all roles named. |
| weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol | weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol | Two legs and an eight-leg supported setup; rated SE inventory, not an unrated raw share. |
| stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol | stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol | Four valid configured legs; a volatile vault share is not declared a peg. |
| stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol | stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchange.t.sol | Separate two- and five-leg setups, not an assumed fixed-four constructor. |

Do not weaken existing rows for other families. Override only FullSpread expectations that the current PRD replaces: user unused input is refunded; maintenance remainder is booked; exact-out execution against FullSpread is rejected. A skipped inherited success assertion alone is not evidence: replace it with the appropriate negative or supported-route assertion in the new row.

The canonical fixture places FullSpread on the converting buffered leg and a real UniswapV2StandardExchange share on an accepted non-converting leg, with different backing pool keys. UniswapV2StandardExchange is the chosen partner fixture name, not a new requirement or a claim that an identity bind already passes. Use its accepted share-transfer representation without invoking its money routes under the outer unlock; if a topology rejects that representation, retain the exact FS-HOOK-04 evidence and do not claim the required canonical proof is complete. The second vault is not asked to mint/redeem under an unlock it does not support. Configure an external rate-provider instance for FullSpread, test each underlying target and both token-index placements, and test two pools using different targets for the same vault. For each direction verify the hook actually calls FullSpread exchangeIn and that mint/burn occurs while unlocked, with hook or user recipient as appropriate. An identity-only transfer is a separate test, not this proof.

Attempt identity token == share without adding asset. If rejected, record the precise consumer, selector, arguments and revert under FS-HOOK-04; do not claim the identity row passes. Pair-overlap, SameToken, missing-interface and incompatible-denomination rejects receive the same concrete treatment only where permitted. A family topology that cannot express the canonical fixture may have a cited unresolved row, but cannot substitute that record for the canonical cross-vault proof or any FS-OWN-29 target row. Do not force two buffered legs through a shared pair mapping that cannot represent them.

Exercise the existing ERC-165-gated fallback to ordinary exact-input previews. No transition/unlock-context/exact-output-quantity quote stub is installed. A separate hook change needs the rejecting call-site evidence and separate scope; the tuple migration itself is required here. Same-backing-pool sequential composition remains unverified unless separately exercised; disjoint-pool tests never certify it.

Replace stale V4 FullSpread rows, preserve V3 rows, and update the PRD-named evidence targets after actual tests: docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json, hook-se-matrix-findings.json, hook-se-matrix-finding-descriptions.json, docs/audits/apex-2026-09-17-evidence.md, and acceptance.json item R10.3 in that evidence directory. Historical deletion/snapshot records are not passes for this implementation.

## 17. Test plan. Map every FS-A row and every 010-054 inventory row to a test file. State the gas measurement.

### Harness and execution order

Create the family TestBase under F/test/bases/, extending IndexedexTest and the canonical native-wrapper base, using the current parent setup order and artifact-backed CREATE3 PoolManager helper. All facets and package components are real; the package is manager-registered and instances are deployed through its registry deployVault. Bootstrap only through exchangeIn or exchangeBundleInForSingleOut. Use existing non-SUT mintable tokens and real manager pool operations. Never mock, etch, subclass-replace or inject storage into the vault, manager, registry, oracle, facets or package.

Implement in dependency order: shared return ABI and consumer migration; Crane aware pairs and tests; family package/storage/selector cut; shared math/projection/planner; funding and settlement/guard engine; money and maintenance targets; registered family tests; seven hook rows and evidence. After production changes build artifacts with forge build --use solar before forge test --use solar, using the repository artifact-aware targeted workflow where appropriate. Use default hermetic profile and viaIR=false, normal runtime/initcode limits and existing fuzz/invariant depth. Run only relevant suites initially, then the complete family/Crane/hook/migrated-consumer checks before claiming completion. Do not run any of them in this research assignment.

Every reverting-case assertion compares supply, involved holders, payer/recipient and vault token balances, booked and reserved custody, wrapper balances, position liquidity/key/ticks/salt, and per-address manager deltas. A failing inner call caught by the outer actor is compared before any snapshot restore; restoring a snapshot is not proof of rollback. recordLogs is used for event assertions, not presented as a transaction receipt or transaction gas record.

Pair preview/execution cases from the same economic state. Use actual returned manager receipts and independent arithmetic assertions, not only planner-equals-planner. Test both token directions, native and non-native pools, mixed 6/8/18 decimal faces, zero and nonzero pool fee, initialized tick crossings, full-range boundaries, different caller/recipient, fee-on/off and clamp boundaries, and small exact rounding cases. Fuzz ownership fractions and action sequences through real public routes; maintain invariant checks for total supply/floor, booked-versus-unbooked custody, no parked-share burns, no extra fee mint and zero stable-boundary reservations/own deltas. No sleep, probabilistic retry or test-only quote cap is needed.

### Test-file key

All seven family files below are under test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/; the abbreviations in the maps expand to these exact files.

| Key | Filename |
| --- | --- |
| Package | UniswapV4FullSpreadStandardExchangeVaultPackage.t.sol |
| Money | UniswapV4FullSpreadStandardExchangeVaultMoney.t.sol |
| Native | UniswapV4FullSpreadStandardExchangeVaultNative.t.sol |
| Quotes | UniswapV4FullSpreadStandardExchangeVaultQuotesAndRate.t.sol |
| Callbacks | UniswapV4FullSpreadStandardExchangeVaultCallbacks.t.sol |
| Borrowed | UniswapV4FullSpreadStandardExchangeVaultAlreadyUnlocked.t.sol |
| Hooks | UniswapV4FullSpreadStandardExchangeVaultBufferHookIntegration.t.sol |

Hooks includes the composition tests and references the seven exact row files in section 16. Crane aware-pair tests remain in the two Crane files named in section 4. Package tests cover typed inputs, linked-library hashes, every installed selector through the proxy, direct facet metadata versus proxy metadata, missing selectors, interface IDs, cross-instance isolation, standard permit/domain behavior and post-deploy cleanup.

### Complete FS-A map

| ID | Test file(s) | Required assertion |
| --- | --- | --- |
| FS-A01 | Package; both Crane aware tests | Exact selective cuts, all shared and Crane getters reachable, excluded surfaces absent, factory surfaces disjoint and temporary hook removed after lifecycle. |
| FS-A02 | Package | Mutate each PkgInit binding independently; bindingHash changes, including all six libraries, WETH and seven architecture addresses. |
| FS-A03 | Package | Missing/code-empty or mismatched component, hooked/uninitialized pool, wrong registry caller AND right registry/wrong execution account, wrong initialization and repeat initialization all fail atomically. No removed-argument/domain negatives. |
| FS-A04 | Package | Numeric family namespace slot differs from PairToken and Wings. |
| FS-A05 | Money; Package | Genesis dL 999/1000 rejects and dL 1001 succeeds where amounts realize it; position owner/range/salt, floor zero-address balance, total supply and fee split are exact. |
| FS-A06 | Money | Accepted bundle deposit/refunds and both-token exit in either caller output order; no swaps on either paired route. |
| FS-A07 | Money; Quotes | Pull full declaration, refund payer not recipient, pretransfer maximum cases and atomic bundle shortfall; deposit fees booked and excluded from credited liquidity. |
| FS-A08 | Money; Quotes | Exit principal/fee/book fractions exact; one-token unwanted claim fully converted or AmountOutNotMet with no burn; both-token exit has no swap. |
| FS-A09 | Money; Quotes | Enabled exact-out unavailable and zero preview without refund ABI or token/state changes. |
| FS-A10 | Native | WETH-only caller boundary and manager-only native wrap/unwrap, no value-bearing public money call. |
| FS-A11 | Money; Borrowed | User operations never auto-compound; exits pay only caller book fraction and book the rest; no fallback. |
| FS-A12 | Package | Withdrawn row: assert exchangeRate/SY selectors absent, not an exchange-rate test. |
| FS-A13 | Package; Quotes | Withdrawn row: getRate absent, no replacement formula. |
| FS-A14 | Package | Withdrawn row: no rate-only InsufficientRateSupply declaration in the family ABI. |
| FS-A15 | Quotes | Withdrawn row: test planner behavior through supported previews, never resurrect a getRate failure test. |
| FS-A16 | Money; Package | Issuance works solely from raw liquidity/supply; neither exchangeRate nor getRate is present/called. |
| FS-A17 | Callbacks; Borrowed | Observe two sequential unlocks/consumed callbacks for swap-add and remove-swap, replay reject after each, guard held between, borrowed equivalent zero unlocks. |
| FS-A18 | Callbacks | Wrong caller and unsolicited manager callback reject with no token effects. |
| FS-A19 | Borrowed | Real open-manager mint/exit has zero nested unlocks and zero own closing deltas while outer global deltas remain; position identity unchanged. |
| FS-A20 | Borrowed; Native | Code/self-funding/pretransfer-false checks, inherited funding rejects and nonpayable raw-value reject. |
| FS-A21 | Borrowed | Unfunded contract/caller without shares cannot mint or burn using the unlocked flag. |
| FS-A22 | Borrowed | Validly authorized bundle/maintenance calls on open manager reject ManagerAlreadyUnlocked; removed paired/SY selectors absent. |
| FS-A23 | Borrowed | Reverted inner call restores shares, position and complete custody before outer actor continues. |
| FS-A24 | Hooks; dual row | Actual identity-bind attempt, either accepted behavior or cited reject without asset; rejected bind is not a passing identity route. |
| FS-A25 | Hooks; all applicable rows | Actual borrowed mint/burn, hook/user recipient, position identity, deposit net fee and exiting fee/book allocation. |
| FS-A26 | Hooks; dual row | Disjoint backing keys, true zeroForOne and oneForZero exact-input operations through FullSpread. |
| FS-A27 | Hooks; seven section 16 rows | Per-topology proof or precisely cited unresolved topology record; required target-provider rows cannot be waived. |
| FS-A28 | Hooks | Hook path that actually calls exchangeOut fails closed without payout or position burn. |
| FS-A29 | Quotes; Hooks | External provider reads tuple; each underlying target, token-index placement and same vault in two differently targeted pools; no local getRate. |
| FS-A30 | Hooks | Explicitly label same-backing-pool composition unverified; do not alias the disjoint test as this proof. |
| FS-A31 | Money; Quotes; Hooks | Cold operation/preview meters and complete composed transaction measurement as below. |
| FS-A32 | Quotes; Borrowed | Live deployed reserves plus unpaid fees, unknown token zero, local book excluded; supported views work busy/unlocked with no vault error. |
| FS-A33 | Borrowed; Money | Locked/borrowed parity from identical state using common settlement, no automatic compound or fallback/performance fee. |
| FS-A34 | Borrowed | Nonzero own entry delta rejected; vault closes only its deltas while outer debts persist and are finally settled by outer actor. |
| FS-A35 | Native; Borrowed | Native sync immediately before value settlement, outer ERC-20 sync checkpoint case, no foreign credit and no duplicated WETH/native backing. |
| FS-A36 | Borrowed; Hooks | Propagated outer revert versus caught inner revert; assert exact state restoration and outer settlement responsibility. |
| FS-A37 | Borrowed | Funded non-hook contract succeeds without an allowlist. |
| FS-A38 | Money; Borrowed; Hooks; Quotes | Complete section 15 disable table and expired-deadline precedence, including buffered withdrawal/non-withdrawal. |
| FS-A39 | Money; Package | Live-owner global/function appointment, revocation, selector isolation, owner rotation and stranger rejection; no stored-owner gate. |

### Complete audit inventory map

The ID prefix for every row is APEX-2026-. Copying a no row into this table records exclusion only. Package below is the home of the family surface/scope evidence for those rows, not authorization to write a regression for an excluded subsystem. This preserves every inventory mark while assigning every row a file owner.

| ID | In this plan | Test file(s) / exact scope |
| --- | --- | --- |
| 010 | yes | Money: direct transfer is neither reserves/redeemable idle nor credit beyond an eligible declared pretransfer maximum; legacy disable is not evidence. |
| 011 | yes | Money, Borrowed: repeated own/borrowed deposit-exit loops conserve raw-liquidity issuance and cannot over-mint. |
| 012 | no | Package exclusion record: no Wings liquidation quote; parity is covered by 011, no new 012 test. |
| 013 | yes | Package, Money: generic ERC-4626 deposit absent; sitting balance alone cannot mint. |
| 014 | integration only | Hooks and weighted/Curve/Balancer/orbital row files: rated SE legs are not treated as unrated raw faces. No vault-fix claim. |
| 015 | integration only | Hooks and Curve row: join/exit accounting evidence belongs to hook integration, not vault repair. |
| 016 | no | Package exclusion record: weighted dust-seed mechanism is hook code; own genesis is 034. |
| 017 | no | Package exclusion record: no Balancer caller-supplied router callback test. |
| 018 | no | Package exclusion record: no Balancer computeBalance test. |
| 019 | yes, as a negative | Money, Quotes: enabled ExchangeOutNotAvailable and zero preview, never disabled fixture. |
| 020 | no | Package exclusion record: DETF mint/bond pricing absent. |
| 021 | no | Package exclusion record: Balancer DETF bond pricing absent. |
| 022 | yes | Money, Borrowed: the same loop as 011 is labeled against both inventory IDs. |
| 023 | yes | Money: stranger maintenance rejected; only current owner/global/function operator allowed; no permissionless sleeve. Do not assert authorized sandwich prevention. |
| 024 | yes | Money, Borrowed: inspect swap input equal to complete opposing exiting claim, not standing-holder custody; unbounded limit retained. |
| 025 | no | Package exclusion record: no Wings rebalance/loss-cap operation. |
| 026 | no separate Wings test | Quotes exclusion record: no 512-step Wings quote; own dust-tick liveness belongs to 041. |
| 027 | no | Package exclusion record: no staking withdrawal queue. |
| 028 | yes | Hooks and dual row: identity-leg attempt cannot burn caller position for zero payout; rejected bind recorded rather than forced green. |
| 029 | yes, as a negative | Package, Quotes, Hooks: no getRate and no binding the full-book provider as vault rate. Correct configured external provider only. |
| 030 | integration only | Hooks and Balancer quad row: phantom-fee-LP accounting stays hook evidence, not a vault fix. |
| 031 | no | Package exclusion record: Balancer virtual-TTA join absent. |
| 032 | yes | Package: actual factory deployment removes temporary postDeploy selectors; unprivileged post-deploy call fails. |
| 033 | no | Package exclusion record: DETF primary redemption absent. |
| 034 | yes | Money: direct-transfer/genesis sequences with permanent 1,000 floor cannot inflate first-deposit issuance; first-entry dL boundary and fee split asserted. |
| 035 | no | Package exclusion record: Aave cross-version loop absent. |
| 036 | yes | Hooks: atomic staged pretransfer consumed/refunded within its operation, not credited to a later caller; non-atomic staging remains the directive's caller risk. |
| 037 | no | Package exclusion record: no re-enable of a frozen legacy vault. |
| 038 | no | Package exclusion record: sDETF staking weights absent. |
| 039 | yes | Money: maxima below/equal/above unbooked custody, booked exclusion and parked shares; bundle shortfall reverts before any spending/mint using generic revert, no new selector. |
| 040 | yes | Money, Quotes: real pool donation then authorized compound then later user deposit; shares reflect added liquidity and must not become dust from a donation-driven denominator error. |
| 041 | yes | Quotes, Money: real initialized dust ticks, normal deposit/redeem and long tick walks; no undocumented cap or minimum spacing. |
| 042 | yes | Package: real registered deployment with non-SUT token approve returning no bool; no typed Permit2 approval dependency. |
| 043 | integration only | Hooks and orbital row: radius-pinning evidence belongs to hook integration, not vault repair. |
| 044 | yes | Money, Quotes: fee deducted from gross shares, floor separate, zero/1e13/3e17/above-cap settings, net previews/minimum and holder-value round trips without extra unbacked fee mint. |
| 045 | yes | Money, Borrowed, Hooks, Quotes: section 15 matrix, deadline-before-disable, authorized maintenance availability and enabled exact-out negative kept separate. |
| 046 | no | Package exclusion record: no Balancer composite-router settlement test. |
| 047 | no | Package exclusion record: no Stata one-wei donation test; family neighbor is 040. |
| 048 | yes | Money: clean compound unchanged/no event; empty Compounded only for fees/booked deposit; empty Donation on every successful donate; remainder remains processable. |
| 049 | yes, as a negative | Money, Quotes: enabled exact-out unavailable, not a Camelot equality regression. |
| 050 | no | Package exclusion record: no truncated TWAP oracle dependency or new oracle. |
| 051 | yes | Quotes, Money, Borrowed: PPlanner is shared, same-state output matches, no nonexistent impact check and no quote step cap. |
| 052 | yes | Package: domain name == PkgArgs.name, version == "1", correct chain/proxy domain, valid standard signer permit, nonce increment, replay rejection and instance isolation. |
| 053 | no | Package exclusion record: manager ownership-transfer buffering unchanged. |
| 054 | yes | Hooks and all required unwrap rows: hook approves the real vault and completes share exit; absent-approval negative rolls back, configured positive does not freeze user. |

### Additional cases within these rows, not new inventory IDs

Exercise exact event topics and empty data for Donation/Compounded, feeTo rotation, grant revoke, fee precision/clamp, recipient zero/self/third-party, zero/duplicate/unsupported routes and bundle lengths/order, failed payout/refund rollback, actual one-token partial conversion refunds, and caller share approvals. Test genesis and subsequent bundle/one-sided issuance, no-book-adoption from ordinary input, actual-held maintenance remainder, zero/no-deposit maintenance markers, and no fee-origin storage. Pair shares and liquidity checks with holder claims so an overmint cannot hide behind unchanged token balances.

Use real manager/token callbacks to exercise reentrancy. Assert lifecycle/commitment/reservation invariants at reachable entry and exit states without injecting impossible storage into the SUT. For uninitialized direct-target context and reachable invalid callback states use generic revert where the PRD leaves the error unnamed; do not fabricate a named failure only to satisfy a test. Callback authentication/replay tests and successful guard reset after failure together cover the state machine.

### Gas measurement and release evidence

For each supported standalone money/maintenance call, establish the fixture outside the meter and measure a cold external call body, with input funding/approval setup outside but all runtime planning, token movement, manager actions, settlement and final payouts inside. Assert call-body gas <= 11,900,000 and report 100,000 reserved transaction overhead, yielding <= 12,000,000. Do not accidentally warm storage with a preview immediately before the measured call. The source is S1-GAS-01:954-968; do not import its removed mode-query, paired-selector or fallback mechanics.

Measure each supported public preview with <= 5,000,000 gas, including the full shared planner and tick traversal. Measure boundaries and nonempty fee/book states, not just empty or ordinary pools. No getRate measurement exists. Record chain, compiler/profile, fixture, storage-access assumptions and exact operation boundary alongside each result. Preserve normal runtime and initcode ceilings separately from money-call gas.

For every claimed hook-composed fixture, measure the entire actual outer transaction including hook work, both vault operations, all other legs and transaction overhead; it must be under 12,000,000. A local per-vault body estimate or recordLogs output is not that receipt. Use a real local transaction receipt when implementing the evidence workflow, or an equivalent complete outer-transaction measurement that includes its actual intrinsic/calldata cost; do not reuse the fixed standalone allowance as proof for larger composition calldata. Report any oversized route as an unresolved narrowed route with measured gas, not a passing row or waiver, and do not solve it by adding a product quote cap.

Completion requires current passing evidence for the required family and Crane tests, the canonical hook proof, required provider target rows, all supported topology rows or permitted cited unresolved topology records, migrated live consumers, code-size checks and gas. Publish a failure/unverified record instead of inventing a pass. No results in this response satisfy that future gate.

## 18. Traceability. Every FS-OWN, FS-FACET, FS-PKG, FS-MONEY, FS-UNLOCK, FS-HOOK, FS-TEST, and FS-A identifier points to a plan section.

| Identifier | Plan sections |
| --- | --- |
| FS-OWN-01 | 4, 5, 6, 7, 17: Protocol Aware pair, package immutables, externally callable Crane getters and Crane tests. |
| FS-OWN-02 | 4, 5, 6, 7, 17: SinglePositionAware and poolKey ownership. |
| FS-OWN-03 | 1, 7, 12, 17: no rateAsset/getRate or internal provider. |
| FS-OWN-04 | 1, 6, 9, 10: no sleeve or local target. |
| FS-OWN-05 | 4, 5, 7, 17: no SY fields/facets/selectors. |
| FS-OWN-06 | 5, 6, 7, 17: ticks, salt and live positionLiquidity. |
| FS-OWN-07 | 6, 7, 12, 17: deployed reserves, unpaid fees, selective basic-vault cut. |
| FS-OWN-08 | 7, 12, 16, 17: scalar tuple, interface ID, migration and exact-out ABI. |
| FS-OWN-09 | 7, 8, 9, 10, 13, 17: mapped bundles, maintenance and paired events. |
| FS-OWN-10 | 5, 7, 12: no wrappedNative field/getter or removed caps/previews. |
| FS-OWN-11 | 3, 9, 17: _mint zero-address floor and supply. |
| FS-OWN-12 | 6, 9, 10: no sleeve target/5% rule. |
| FS-OWN-13 | 8, 11, 17: borrowed exchangeIn only, no nested unlock. |
| FS-OWN-14 | 8, 10, 13, 14, 17: authorization, collection, combined maintenance balance, booking and markers. |
| FS-OWN-15 | 9, 11, 12, 17: complete exiting-claim-only conversion. |
| FS-OWN-16 | 5, 6: poolManager retained and all seven addresses initialized. |
| FS-OWN-17 | 5, 6, 9, 11, 17: WETH face and pool-only native boundary. |
| FS-OWN-18 | 5, 7, 12: seven architecture addresses, no capped-quoter product rule. |
| FS-OWN-19 | 8, 12, 15, 17: no view vault errors and zero unsupported routes. |
| FS-OWN-20 | 6, 8, 9, 17: unbooked versus booked custody and caller shares. |
| FS-OWN-21 | 8, 10, 13, 14, 17: donate signature, share burn, underlying deployment and remainder. |
| FS-OWN-22 | 5, 7, 9, 17: face order and initialized/hookless-only key validation. |
| FS-OWN-23 | 7, 17: exact selector cut and query ownership. |
| FS-OWN-24 | 9, 12, 17: net fee shares, clamp, precision, no pass-through fee. |
| FS-OWN-25 | 9, 12, 17: proportional bundle/no swap and pass-through. |
| FS-OWN-26 | 8, 15, 17: complete disable matrix. |
| FS-OWN-27 | 6, 9, 12, 17: raw liquidity, native token amounts and metadata decimals. |
| FS-OWN-28 | 8, 15, 17: deadline first. |
| FS-OWN-29 | 12, 16, 17: external providers, both targets and shared-vault multiple pools. |
| FS-OWN-30 | 9, 12, 17: fee/book claims before burn, remainder booking and exact exit preview. |
| FS-OWN-31 | 11, 17: direct borrowed removal and own settlement, no unpullable/sleeve case. |
| FS-OWN-32 | 6, 8, 9, 10, 12, 17: declared-input refund/funding rules, atomic bundle, recipients and view exceptions. |
| FS-OWN-33 | 3, 9, 10, 12, 17: greatest-liquidity one-sided swap and input-token remainder. |
| FS-FACET-01 | 4, 5, 7, 13, 17: typed inputs, manifest and error ownership. |
| FS-FACET-02 | 4, 7, 17: factory exclusions and actual temporary-hook lifecycle. |
| FS-PKG-01 | 4, 5, 6, 7, 19: binding order, registry path, fields and six libraries. |
| FS-PKG-02 | 5, 17: validation and initialization failure cases. |
| FS-MONEY-01 | 8, 9, 10, 11, 17: settlement, issuance, exits, maintenance and gas. |
| FS-UNLOCK-01 | 8, 11, 16, 17: dispatch and hook recipients. |
| FS-UNLOCK-02 | 6, 8, 11, 17: borrowed authority, lifecycle, sync and own deltas. |
| FS-UNLOCK-03 | 8, 11, 17: per-action commit/unlock/callback and guard. |
| FS-HOOK-01 | 16, 17: seven topologies and valid bindings. |
| FS-HOOK-02 | 16, 17: canonical disjoint-pool cross-vault fixture. |
| FS-HOOK-03 | 7, 8, 15, 16, 17: exact-out fail-closed versus exact-input directions. |
| FS-HOOK-04 | 16, 17: cited unresolved hook-change gate, no substitute for canonical proof. |
| FS-TEST-01 | 4, 17: production-first TestBase, single manager, real proxy and Crane tests. |
| FS-TEST-02 | 17: seven exact family spec filenames and withdrawn-test handling. |
| FS-TEST-03 | 17, complete FS-A map: every acceptance assertion. |
| FS-TEST-04 | 16, 17: matrix/evidence refresh and all 45 inventory dispositions. |
| FS-ARCH-01 | 4, 6, 19: family file split, Crane pairs, modifiers and namespace. |
| FS-RATE-01 | 7, 12, 16, 17: withdrawn vault rate and separate configured providers. |
| FS-X01 | 3, 11, 16, 17: borrowed exact-input composition. |
| FS-X02 | 7, 12, 17: withdrawn vault rate. |
| FS-X03 | 16, 17: hooks and tuple consumers. |
| FS-X04 | 8, 9, 12, 17: partial entry, refund and conversion sizing. |

FS-A01, FS-A02, FS-A03, FS-A04, FS-A05, FS-A06, FS-A07, FS-A08, FS-A09, FS-A10, FS-A11, FS-A12, FS-A13, FS-A14, FS-A15, FS-A16, FS-A17, FS-A18, FS-A19, FS-A20, FS-A21, FS-A22, FS-A23, FS-A24, FS-A25, FS-A26, FS-A27, FS-A28, FS-A29, FS-A30, FS-A31, FS-A32, FS-A33, FS-A34, FS-A35, FS-A36, FS-A37, FS-A38 and FS-A39 each point to their individually named row in section 17, which supplies the test file and assertion. Withdrawn FS-A12-FS-A15 remain withdrawn; their map records absence/redirected supported-surface coverage rather than restoring their economics.

## 19. Implementation names the PRD left open, each labeled as a name rather than a requirement.

| Item | Chosen implementation name/value; not a new requirement |
| --- | --- |
| Six architecture PkgInit fields beyond poolManager | positionDescriptor, positionManager, quoter, stateView, reservesLens, universalRouter. |
| Two Crane facet PkgInit fields | uniswapV4ProtocolAwareFacet and uniswapV4SinglePositionAwareFacet. |
| New owner modifier filename | UniswapV4FullSpreadStandardExchangeVaultLiveOwnerModifiers.sol. |
| New maintenance modifier filename | UniswapV4FullSpreadStandardExchangeVaultLiveOperableModifiers.sol. |
| Family storage namespace | indexedex.vaults.standard.exchange.uniswap.v4.fullspread, hashed with abi.encode and minus one. |
| SwapProjection assignment | UniswapV4FullSpreadStandardExchangeVaultSwapProjection.sol performs the specified swap/tick projection and one-sided liquidity sizing. |
| ExecutionPreparation assignment | UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol prepares the specified funding, reservations, caller-share authority and authenticated action payloads. |
| One shared quote engine | UniswapV4FullSpreadStandardExchangeVaultPlanner; not a new public selector, cap or alternate valuation rule. |
| Temporary-hook filename | PostDeployAccountHookFacet.sol, evidenced by DiamondPackageCallBackFactory.sol:31 and removed by its :414-451 lifecycle. It is not a new family facet. |
| Crane pair directory | lib/crane/contracts/protocols/dexes/uniswap/v4/aware/ for both pairs. |
| Crane companion interface/service names | IUniswapV4ProtocolAware.sol, IUniswapV4SinglePositionAware.sol, UniswapV4Aware_FactoryService.sol. |
| Salt getter name | positionSalt(); stored value remains the locked bytes32(0). |
| Permit domain version | "1"; domain name is the required PkgArgs.name. |
| Required IOperable implementation placement | MoneyFacet/MoneyTarget, reusing moneyFacet; no additional PkgInit field or stored-owner facet. |
| Test and row filenames | Exact filenames in sections 4, 16 and 17; suffix choices are implementation names, not new inventory IDs. |

# Limits

This is an independent research plan, not implementation authority, a PRD edit, an audit clearance, or evidence that a route has passed. No tests, builds, installs, deployments, wallet operations, Git operations, public searches, or subagents were used. No peer or coordinator draft was read. Only the assigned response artifact is written.

The admitted factory/package and matrix reads support the architectural placements, not a claim that the complete new code already exists. Gas feasibility, exact integer sizing correctness, compiled selector counts, actual hook-bind outcomes and release evidence must be established by the future implementation tests specified above. An authorized maintenance sandwich remains accepted, non-atomic pretransfer remains caller risk, and disjoint-pool composition does not prove same-pool sequential composition. No closed product lock is reopened by those evidence limits.
