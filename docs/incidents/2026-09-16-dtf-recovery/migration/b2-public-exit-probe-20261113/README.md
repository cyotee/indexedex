# B2 public-exit probe and remaining recovery decision

The earlier DETF adapter is installed as appended recovery stage11, EarlierConvert. It fixes the missing Migration dispatch but does not fix legacy infrastructure. The operator encodes11 and validates conversion fields; its five focused tests passed. Production diagnostics and scoped whitespace checks passed.

## Observed local-fork results

- At the unchanged chain4663/block108944663 fork, the real migration adapter reaches VaultDisabled(EARLIER_SE). The new regression passed and proves complete rollback of selected ED inventory, custody, temporary allowance, DTF output and funded bond state.
- A second test used the real legacy registry owner and its public disable-manager API to enable the earlier SE only on the owned local fork. No source bytecode/storage injection or public governance transaction was used. The registry's effective disabled flag became false.
- Conversion then failed deeper: ED.exchangeIn -> EL.withdrawSingle -> ES.exchangeIn -> ES.transferFrom(EL,ES,4776221877393118436655727368096), propagating TransferFromFailed(). The original local positive test remains failing; it has not been skipped, deleted or weakened into a passing negative.

The exact retained trace and process exits are in results.json. The passing disabled case was mon_HK02F1TV37B2A513/bash166, gas3868995. The failing enabled case was mon_W7JYGTV3V0JE3GN8/bash167, gas3917605. Both used artifact-first FOUNDRY_PROFILE=fork python3 scripts/forge-artifacts.py test contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationRecoveryTarget.sol --test-root test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/MigrationEarlierLiquid.t.sol -- --match-test <the named test> -j 1 --compute-units-per-second 10 --rpc-timeout 120 -vvvv. Exact test names are in results.json. The skipped subsequent Bun command was executed separately and passed5/5 as mon_3DDCVGARRVNQWNCE/bash168.

## Source observation versus inference

Authenticated archived UniswapV4SingleStandardExchangeDETFFacet.sol lines25137-25174 require ED burn output to be the fixed pair token and call _withdrawSinglePair. Lines24894-24900 approve physical LP to itself and invoke withdrawSingle; there is no migration-caller branch that can grant the nested SE allowance. Lines24999-25014 route receipt-authorized claimLiquidity through the same helper. Archived RebasingClaimTokenFacet.sol lines10382-10404 burns receipt shares and calls that claimLiquidity.

Therefore the earlier receipt route shares the failing downstream helper (source observation), but the enabled earlier receipt conversion has not separately been executed (limit). No successful ER conversion is claimed. Provisional ER changes were restored before another approach; no incomplete ER adapter, storage field or selector remains installed.

The source archive is /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/earlier-cp/probe-alchemy-retry.source.json. Line numbers above refer to its unescaped contract source content.

## Other B2 rows

Earlier and weighted physical LP exits still require legacy-parent/authorized-collector authority that migration custody lacks. Enabling SEs does not grant it. Permanent custody-only treatment has not been authorized.

Both direct SE exits were subsequently demonstrated after conditional local enablement and installed as fixed stages12 WeightedWethSeConvert and13 EarlierSeConvert. Real Migration tests passed conversion, measured DTF booking, donation, late-batch rollback, preservation of100 unsolicited source units and unchanged funded bonds. The weighted test used genuine preexisting owner-held shares. The earlier positive fixture used a genuine paid source acquisition, funded through an existing weighted NFT claim and conversion; the original tiny EOA holding was below one raw DTF unit. Its failed positive attempt is preserved, and that dust case now has explicit rejection-without-burn coverage alongside the non-dust positive. See se-results.json for separate results and limits. These conditional successes do not enable the public legacy sources or resolve the earlier DETF internal withdrawal failure.

Two owner requirement questions are pending: whether physical LP recovery remains a prerequisite, and whether earlier DETF/receipt successful recovery remains required despite the broken legacy exit. With no answer, both original requirements remain open. There is no authorization here to change legacy permissions, replace immutable contracts, bypass the internal transfer, or declare whole-plan completion.
