# Manual UI Route Test Checklist

Use this as a single place to track which UI routes you’ve manually tested, what passed/failed, and any notes.

## Test Session Metadata

- Date:
- Tester:
- Git branch / commit:
- RPC / Network (e.g. Anvil fork):
- ChainId:
- Deployer script run (yes/no + timestamp):

## **Standard Exchange Router Routes**

| Argument      | Balancer Swap | Vault Pass-Through Swap | Vault Deposit | Vault Withdraw | Vault Deposit -> Balancer Swap | Balancer Swap -> Vault Withdraw | Vault Deposit -> Balancer Swap -> Vault Withdraw | 
| :-----------: | :-----------: | :---------------------: | :-----------: | :------------: | :----------------------------: | :-----------------------------: | :----------------------------------------------: |
| pool          | pool          | vault                   | vault         | vault          | pool                           | pool                            | pool                                             |
| tokenIn       | sell token    | sell token              | deposit token | vault          | deposit token                  | sell token                      | deposit token                                    |
| tokenInVault  | address(0)    | vault                   | vault         | address(0)     | deposit vault                  | address(0)                      | deposit vault                                    |
| tokenOut      | buy token     | buy token               | vault         | withdraw token | buy token                      | withdraw token                  | withdraw token                                   |
| tokenOutVault | address(0)    | vault                   | address(0)    | vault          | address(0)                     | withdraw vault                  | withdraw vault                                   |

## Global Preconditions (do once per session)

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| App boots (`next dev`) with no redbox errors | [ ] | [ ] | [ ] |
| Wallet connect works (connect, disconnect, reconnect) | [ ] | [ ] | [ ] |
| Correct chain selected (Anvil chainId `31337` if local) | [ ] | [ ] | [ ] |
| Addresses load (no “missing deployment/address” errors) | [ ] | [ ] | [ ] |
| Basic reads work (balances / block number updates) | [ ] | [ ] | [ ] |

---

# Routes

These routes were detected from `frontend/app/**/page.tsx`.

- `/`
- `/swap`
- `/batch-swap`
- `/mint`
- `/staking`
- `/portfolio`
- `/seigniorage`
- `/vaults`
- `/create`
- `/detfs`
- `/detf`
- `/token-info`
- `/insights`
- `/test`

---

## `/` (Home)

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads with expected layout/nav | [✅] | [ ] |  |
| Header/nav links route correctly (no full reload) | [ ] | [ ] | [ ] |
| Connect state reflected in UI (address/ENS if shown) | [ ] | [ ] | [ ] |

## `/swap`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads and token selectors populate | [ ]  | [ ] | [ ] |
| Pool dropdown shows expected pools | [ ]  | [ ] | [ ] |
| Pool dropdown includes `WETH (Wrap/Unwrap)` option | [ ] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Preview exact in WETH wrap `(ETH -> WETH)` | [ ]  | [ ] | [ ] |
| Explicit Wraps exact in WETH wrap `(ETH -> WETH)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out WETH wrap `(ETH -> WETH)` | [ ]  | [ ] | [ ] |
| Explicit Wraps exact out WETH wrap `(ETH -> WETH)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Preview exact in WETH unwrap `(WETH -> ETH)` | [ ]  | [ ] | [ ] |
| Signed Wraps exact in WETH unwrap `(WETH -> ETH)` | [ ]  | [ ] | [ ] |
| Signed Preview exact out WETH unwrap `(WETH -> ETH)` | [ ]  | [ ] | [ ] |
| Signed Wraps exact out WETH unwrap `(WETH -> ETH)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 → ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 → ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 → ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 → ERC20)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ERC20 → ERC20)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ERC20 → ERC20)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ERC20 → ERC20)` | [ ]  | [ ] | [ ] |
| Signed Swap exact out `(ERC20 → ERC20)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ETH → ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ETH → ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ETH → ERC20)` | [ ]  | [ ] | [ ] |
| SExplicit wap exact out `(ETH → ERC20)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ETH → ERC20)` | [NA] | [ ] | [ ] |
| Signed Swap exact in `(ETH → ERC20)` | [NA] | [ ] | [ ] |
| Signed Previews exact out `(ETH → ERC20)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ETH → ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 → ETH)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 → ETH)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 → ETH)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 → ETH)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ERC20 → ETH)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ERC20 → ETH)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ERC20 → ETH)` | [ ]  | [ ] | [ ] |
| Signed Swap exact out `(ERC20 → ETH)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 → Vault)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 → Vault)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 → Vault)` | [NA] | [ ] |  |
| Explicit Swap exact out `(ERC20 → Vault)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ERC20 → Vault)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ERC20 → Vault)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ERC20 → Vault)` | [NA] | [ ] |  |
| Signed Swap exact out `(ERC20 → Vault)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(Vault → ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(Vault → ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(Vault → ERC20)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(Vault → ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(Vault → ERC20)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(Vault → ERC20)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(Vault → ERC20)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(Vault → ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ETH → Vault)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ETH → Vault)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ETH → Vault)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ETH → Vault)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ETH → Vault)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ETH → Vault)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ETH → Vault)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ETH → Vault)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(Vault → ETH)` | [ ]  | [ ] | 
| Explicit Swap exact in `(Vault → ETH)` | [ ]  | [ ] | 
| Explicit Previews exact out `(Vault → ETH)` | [NA] | [ ] | 
| Explicit Swap exact out `(Vault → ETH)` | [NA] | [ ] | 
|--------------------------------------------------------------|
| Signed Previews exact in `(Vault → ETH)` | [ ]  | [ ] | 
| Signed Swap exact in `(Vault → ETH)` | [ ]  | [ ] | 
| Signed Previews exact out `(Vault → ETH)` | [NA] | [ ] | 
| Signed Swap exact out `(Vault → ETH)` | [NA] | [ ] | 
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ERC20 -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ERC20 -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ERC20 -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Signed Swap exact out `(ERC20 -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ETH -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ETH -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ETH -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact out `(ETH -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ETH -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ETH -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ETH -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
| Signed Swap exact out `(ETH -> ERC20 via vault)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 -> ETH via vault)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 -> ETH via vault)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 -> ETH via vault)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 -> ETH via vault)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ERC20 -> ETH via vault)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ERC20 -> ETH via vault)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ERC20 -> ETH via vault)` | [ ]  | [ ] | [ ] |
| Signed Swap exact out `(ERC20 -> ETH via vault)` | [ ]  | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 -> Vault -> Swap -> ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in E`(RC20 -> Vault -> Swap -> ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 -> Vault -> Swap -> ERC20)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 -> Vault -> Swap -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ERC20 -> Vault -> Swap -> ERC20)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ERC20 -> Vault -> Swap -> ERC20)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ERC20 -> Vault -> Swap -> ERC20)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ERC20 -> Vault -> Swap -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ETH -> Vault -> Swap -> ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ETH -> Vault -> Swap -> ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ETH -> Vault -> Swap -> ERC20)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ETH -> Vault -> Swap -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ETH -> Vault -> Swap -> ERC20)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ETH -> Vault -> Swap -> ERC20)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ETH -> Vault -> Swap -> ERC20)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ETH -> Vault -> Swap -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 -> Vault -> Swap -> ETH)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 -> Vault -> Swap -> ETH)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 -> Vault -> Swap -> ETH)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 -> Vault -> Swap -> ETH)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ERC20 -> Vault -> Swap -> ETH)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ERC20 -> Vault -> Swap -> ETH)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ERC20 -> Vault -> Swap -> ETH)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ERC20 -> Vault -> Swap -> ETH)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 -> Swap -> Vault -> ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 -> Swap -> Vault -> ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in E`(RC20 -> Swap -> Vault -> ERC20)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ERC20 -> Swap -> Vault -> ERC20)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ERC20 -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ERC20 -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ETH -> Swap -> Vault -> ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ETH -> Swap -> Vault -> ERC20)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ETH -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ETH -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ETH -> Swap -> Vault -> ERC20)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ETH -> Swap -> Vault -> ERC20)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ETH -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ETH -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 -> Swap -> Vault -> ETH)` | [ ]  | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 -> Swap -> Vault -> ETH)` | [ ]  | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ERC20 -> Swap -> Vault -> ETH)` | [ ]  | [ ] | [ ] |
| Signed Swap exact in `(ERC20 -> Swap -> Vault -> ETH)` | [ ]  | [ ] | [ ] |
| Signed Previews exact out `(ERC20 -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ERC20 -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 -> Vault -> Swap -> Vault -> ERC20)` | [ ] | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 -> Vault -> Swap -> Vault -> ERC20)` | [ ] | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 -> Vault -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 -> Vault -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(RC20 -> Vault -> Swap -> Vault -> ERC20)` | [ ] | [ ] | [ ] |
| Signed Swap exact in `(ERC20 -> Vault -> Swap -> Vault -> ERC20)` | [ ] | [ ] | [ ] |
| Signed Previews exact out `(ERC20 -> Vault -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ERC20 -> Vault -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ETH -> Vault -> Swap -> Vault -> ERC20)` | [ ] | [ ] | [ ] |
| Explicit Swap exact in `(ETH -> Vault -> Swap -> Vault -> ERC20)` | [ ] | [ ] | [ ] |
| Explicit Previews exact out `(ETH -> Vault -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
| SExplicit wap exact out `(ETH -> Vault -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ETH -> Vault -> Swap -> Vault -> ERC20)` | [ ] | [ ] | [ ] |
| Signed Swap exact in `(ETH -> Vault -> Swap -> Vault -> ERC20)` | [ ] | [ ] | [ ] |
| Signed Previews exact out `(ETH -> Vault -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ETH -> Vault -> Swap -> Vault -> ERC20)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ERC20 -> Vault -> Swap -> Vault -> ETH)` | [ ] | [ ] | [ ] |
| Explicit Swap exact in `(ERC20 -> Vault -> Swap -> Vault -> ETH)` | [ ] | [ ] | [ ] |
| Explicit Previews exact out `(ERC20 -> Vault -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ERC20 -> Vault -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ERC20 -> Vault -> Swap -> Vault -> ETH)` | [ ] | [ ] | [ ] |
| Signed Swap exact in `(ERC20 -> Vault -> Swap -> Vault -> ETH)` | [ ] | [ ] | [ ] |
| Signed Previews exact out `(ERC20 -> Vault -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ERC20 -> Vault -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Explicit Previews exact in `(ETH -> Vault -> Swap -> Vault -> ETH)` | [ ] | [ ] | [ ] |
| Explicit Swap exact in `(ETH -> Vault -> Swap -> Vault -> ETH)` | [ ] | [ ] | [ ] |
| Explicit Previews exact out `(ETH -> Vault -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
| Explicit Swap exact out `(ETH -> Vault -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Signed Previews exact in `(ETH -> Vault -> Swap -> Vault -> ETH)` | [ ] | [ ] | [ ] |
| Signed Swap exact in `(ETH -> Vault -> Swap -> Vault -> ETH)` | [ ] | [ ] | [ ] |
| Signed Previews exact out `(ETH -> Vault -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
| Signed Swap exact out `(ETH -> Vault -> Swap -> Vault -> ETH)` | [NA] | [ ] | [ ] |
|--------------------------------------------------------------|
| Errors are surfaced cleanly `(insufficient balance/allowance, bad inputs) | [ ] | [ ] | [ ] |

## `/batch-swap`

| Check | Pass | Fail | Notes |
|:--:|:--:|:--:|:--:|
| Page loads | [ ] | [ ] | [ ] |
| Can add/remove swap rows/steps | [ ] | [ ] | [ ] |
| Batch `(ERC20 -> ERC20 -> ERC20) | [ ] | [ ] | [ ] |
| Batch `(ETH -> ERC20 -> ERC20) | [ ] | [ ] | [ ] |
| Batch `(ERC20 -> ERC20 -> ETH) | [ ] | [ ] | [ ] |
| Batch `(ERC20 -> Vault Deposit -> ERC20) | [ ] | [ ] | [ ] |
| Batch `(ERC20 -> ERC20 -> Vault Deposit) | [ ] | [ ] | [ ] |
| Batch `(ETH -> Vault Deposit -> ERC20) | [ ] | [ ] | [ ] |
| Batch `(ETH -> ERC20 -> Vault Deposit) | [ ] | [ ] | [ ] |
| Batch `(ERC20 -> Vault Withdrawal -> ERC20) | [ ] | [ ] | [ ] |
| Batch `(Vault Withdrawal -> ERC20 -> ERC20) | [ ] | [ ] | [ ] |
| Batch `(ETH -> Vault Withdrawal -> ERC20) | [ ] | [ ] | [ ] |
| Batch `(Vault Withdrawal -> ERC20 -> ETH) | [ ] | [ ] | [ ] |
| Batch `(ERC20 -> Vault Withdrawal -> ETH) | [ ] | [ ] | [ ] |
| Batch quote updates sensibly | [ ] | [ ] | [ ] |
| Batch execution succeeds for a small batch | [ ] | [ ] | [ ] |
| Partial failure is handled (clear error message + no broken state) | [ ] | [ ] | [ ] |

## `/mint`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| Test token list loads (expected symbols/addresses) | [ ] | [ ] | [ ] |
| Mint flow succeeds for a test token | [ ] | [ ] | [ ] |
| Minted balance reflects in UI after tx | [ ] | [ ] | [ ] |
| Error handling for invalid amounts / permissions | [ ] | [ ] | [ ] |

## `/staking`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| Reads show expected staking state (positions/balances) | [ ] | [ ] | [ ] |
| Stake/deposit succeeds (if UI supports it) | [ ] | [ ] | [ ] |
| Withdraw succeeds | [ ] | [ ] | [ ] |
| Claim/harvest succeeds (if applicable) | [ ] | [ ] | [ ] |
| UI updates after actions without manual refresh | [ ] | [ ] | [ ] |

## `/portfolio`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads without RPC/log-scan errors | [ ] | [ ] | [ ] |
| Vault/share token balances show correctly | [ ] | [ ] | [ ] |
| Bond NFTs discovered and listed (if you own any) | [ ] | [ ] | [ ] |
| NFT metadata renders (tokenURI base64 JSON / SVG) | [ ] | [ ] | [ ] |
| `Withdraw rewards` works for a tokenId | [ ] | [ ] | [ ] |
| `Unlock` works for a tokenId (after unlock time) | [ ] | [ ] | [ ] |
| Handles “no NFTs found” state gracefully | [ ] | [ ] | [ ] |

## `/seigniorage`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| Shows expected seigniorage/bond UI elements | [ ] | [ ] | [ ] |
| Any read-only panels populate (APR/metrics if present) | [ ] | [ ] | [ ] |
| Any write actions succeed (bond/lock/claim if present) | [ ] | [ ] | [ ] |

## `/vaults`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| Vault list populates | [ ] | [ ] | [ ] |
| Clicking a vault route/action works as expected | [ ] | [ ] | [ ] |
| Empty/error states look reasonable | [ ] | [ ] | [ ] |

## `/create`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| Form inputs validate (required fields, ranges) | [ ] | [ ] | [ ] |
| Create/deploy action succeeds (if enabled) | [ ] | [ ] | [ ] |
| Post-create navigation/state update works | [ ] | [ ] | [ ] |

## `/detfs`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| List of DETFs populates (if applicable) | [ ] | [ ] | [ ] |
| Navigations/actions from list work | [ ] | [ ] | [ ] |

## `/detf`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| Shows expected DETF details | [ ] | [ ] | [ ] |
| Any actions (mint/redeem/etc.) succeed (if present) | [ ] | [ ] | [ ] |

## `/token-info`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| Token lookup/search works (if present) | [ ] | [ ] | [ ] |
| Displays token metadata and balances without errors | [ ] | [ ] | [ ] |

## `/insights`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| Charts/metrics render | [ ] | [ ] | [ ] |
| Handles “no data yet” state | [ ] | [ ] | [ ] |

## `/test`

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Page loads | [ ] | [ ] | [ ] |
| Any debug widgets function (reads/writes) | [ ] | [ ] | [ ] |

---

## Notes / Bugs Found

- 
