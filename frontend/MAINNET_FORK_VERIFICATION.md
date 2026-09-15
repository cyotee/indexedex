# Next.js 16: Robinhood mainnet fork verification

## Snapshot and isolation

- Chain: Robinhood mainnet, `4663`.
- Latest block selected when Anvil started: `63405378`.
- Block hash: `0x75c7d7ed57372fb83baf3b7d5453be657f547321d641b61c614b4abaf0c25247`.
- Anvil: `1.5.1`, Prague, bound to `127.0.0.1` only.
- Port `8545`: standard browser/transaction tests and local dev browsing.
- Port `18545`: disposable migration/preflight fork at the same snapshot.
- The public upstream started returning HTTP 403 challenges on uncached reads.
  Both forks were recreated at the verified snapshot using the existing authenticated
  Alchemy provider. Credentials are not stored in this document or frontend config.
- No contracts were redeployed. All state changes and signed transactions occurred
  on the local forks, never on mainnet. Migration tests check receipts and balances
  and restore their snapshots.

The frontend test build uses the committed `chain/4663` mainnet artifacts with
`NEXT_PUBLIC_LOCAL_RPC_URL=http://127.0.0.1:8545` and
`NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=anvil_robinhood_main`.
The name of this artifact environment does not imply demo contracts were deployed.

## Results

The first full fork run completed with **41 passed, 5 failed, 6 skipped**.
After correcting test readiness and replacing an obsolete first-bond address
fixture, focused reruns verified:

- WETH bond purchase through the UI, payment balance decrease, bond NFT mint,
  and funded sDETF escrow increase.
- Partial/max migration claims, wallet rejection, receipt-retry recovery,
  delayed SY redemption, unstaking and restaking, with receipt/calldata/balance assertions.
- Disconnected and empty-wallet claim guards.
- RPC failure, account change and wrong-network clearing of actionable positions.
- Both synthetic prices against their actual onchain legs.
- First-bond token choices against `acceptedBondTokens()` of the active DETF,
  discovered through the staking migration adapter rather than the stale catalog entry.
- The 10-DTF acquisition preflight, with actual simulation and a read-only wallet
  blocking submission; direct staking is independently checked with `eth_call` overrides.

Preflight reruns used a locally funded Anvil account (100 DTF and 2 WETH with the
required DTF approval). The old hardcoded wallet has zero DTF/WETH at this snapshot.
These setup transfers/wrapping/approval were local fork transactions only.
`E2E_MAINNET_RPC_URL` and `E2E_MAINNET_WALLET` now allow the read-only specs to use
that fork/account while retaining their no-signing/no-submission guard.

## Still not an all-green suite

- `morpho-market-form.spec.ts` expects TTUSDE/TTWETH demo options absent from the
  current mainnet configuration.
- The weighted-listing scenario expects a prepopulated listed-vault selector;
  the committed mainnet strategy-vault fixtures do not provide that setup.
- The bond-limit preflight assumes **1 WETH** exceeds the per-transaction limit.
  At this snapshot it produces a valid purchase quote. That fixed-size assumption
  must be replaced with a bound derived from current pool state.
- Two deposit-panel cases skip for missing strategy-vault fixtures; two archived
  Balancer swap/deposit cases are explicitly disabled in their source.

Do not present the focused successful reruns as one full green suite. Demo-fixture
coverage and the changing-liquidity-limit case still need separate treatment.

The two local dev variants are restarted with the loopback fork RPC: ports 3002
(IndexedEx, notice off) and 3003 (DTF, notice on). Production deployment settings
are unchanged.
