# Manual UI Route Test Checklist

Use this as a single place to track which UI routes you’ve manually tested, what passed/failed, and any notes.

## Test Session Metadata

- Date: **2026-07-25**
- Tester: Wave 1.5 agent session (Playwright + on-chain smokes against **then-running** local RPC)
- Git branch / commit: local workspace (Wave 1.5 verification)
- RPC / Network: existing local RPC `http://127.0.0.1:8545`, chain **11155111** (`local_testing` artifacts)
- ChainId: **11155111**
- Deploy this session: **forbidden going forward** (see `ROADMAP.md` § Do not deploy). Historical Wave 1.5 used a pre-existing/local stack; **do not re-run** stage scripts for checklist completion.
- Env: `NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=local_testing`; `NEXT_PUBLIC_EARN_DETF_EMBED=false` shared default (lab true only if operator opts in)
- Notes: strategy deposit OK (non-zero minOut); DETF bond OK (rateAsset path); free mint may be threshold-gated; lab embed mount proven; `local_testing` registry fix in `addresses/index.js`

## **Standard Exchange Router Routes**

| Argument      | Balancer Swap | Vault Pass-Through Swap | Vault Deposit | Vault Withdraw | Vault Deposit -> Balancer Swap | Balancer Swap -> Vault Withdraw | Vault Deposit -> Balancer Swap -> Vault Withdraw | 
| :-----------: | :-----------: | :---------------------: | :-----------: | :------------: | :----------------------------: | :-----------------------------: | :----------------------------------------------: |
| pool          | pool          | vault                   | vault         | vault          | pool                           | pool                            | pool                                             |
| tokenIn       | sell token    | sell token              | deposit token | vault          | deposit token                  | sell token                      | deposit token                                    |
| tokenInVault  | address(0)    | vault                   | vault         | address(0)     | deposit vault                  | address(0)                      | deposit vault                                    |
| tokenOut      | buy token     | buy token               | vault         | withdraw token | buy token                      | withdraw token                  | withdraw token                                   |
| tokenOutVault | address(0)    | vault                   | address(0)    | vault          | address(0)                     | withdraw vault                  | withdraw vault                                   |

## Global Preconditions (do once per session)

**Do not deploy** contracts or re-run `local_testing.sh` to complete this checklist. Use committed `app/addresses/**` and any RPC the operator already provides.

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| App boots (`next dev`) with no redbox errors | [✅] | [ ] | `/earn` 200 on local_testing |
| Wallet connect works (connect, disconnect, reconnect) | [✅] | [ ] | Playwright injected EIP-1193 |
| Correct chain selected | [✅] | [ ] | App Network Sepolia **11155111** when using that artifact set |
| Addresses load (no “missing deployment/address” errors) | [✅] | [ ] | After index.js local_testing registry fix |
| Basic reads work (balances / block number updates) | [✅] | [ ] | When RPC present; else document skip |

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

## Wave 1 — money path & a11y (2026-07)

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Deposit four-state CTA: disconnected → Connect | [ ] | [ ] | ActionCta data-gate=disconnected |
| Wrong network → Switch; approve/execute disabled | [ ] | [ ] | wallet chain ≠ app chain |
| Sequential approve legs (token→Permit2, then permit2→router) | [ ] | [ ] | split handlers only |
| Deposit only after quote; minOut from preview+slippage | [ ] | [ ] | no silent minOut=0 |
| Wallet reject recovers (pending cleared, error message) | [ ] | [ ] | parseContractError |
| Reduced motion: UI usable with prefers-reduced-motion | [ ] | [ ] | no critical motion-only affordances |
| No RICH/RICHIR on Earn detail / stepper | [ ] | [ ] | role names / symbol primary |
| `/seigniorage` single-hops to `/earn?type=seigniorage-detf` | [ ] | [ ] | |
| DETF embed flag off in prod (`NEXT_PUBLIC_EARN_DETF_EMBED=false`) | [ ] | [ ] | enable only after mint/bond e2e |
| No production Admin nav 404 | [ ] | [ ] | Admin only when SHOW_DEBUG |
| **Release gate (not Wave 1 merge blocker):** brand lock / OG metadata | [ ] | [ ] | Rule 8 pre-publish |

---

## Wave 2 — fee-accrual DETF narrative (2026-07-26)

**Status: closed.** Do not re-open for residual redesign. Agent entry: `ROADMAP.md`.

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Landing featured → `/staking?detf=` | [✅] | [ ] | Playwright `wave2-fee-detf.spec.ts` |
| More → Fee-accrual DETF → `/staking` | [✅] | [ ] | `Header.tsx` |
| Earn grid has no fee-detf rows; banner → staking | [✅] | [ ] | |
| `/earn/0xFeeDetf` → `/staking?detf=` | [✅] | [ ] | |
| Token Open {symbol} | [✅] | [ ] | |
| Portfolio empty → staking | [✅] | [ ] | |
| Staking mint/bond chrome loads | [✅] | [ ] | |
| Vitest fee list + Earn exclude | [✅] | [ ] | |

**Env:** Prefer `node scripts/next.mjs dev --port 3001` (avoid `npm run dev` killing :3000).

**Regression:** `E2E_SKIP_WEBSERVER=1 E2E_BASE_URL=http://127.0.0.1:3001 npx playwright test e2e/wave2-fee-detf.spec.ts`

---

## PR8 — SharePositionCard (2026-07-26)

**Status: shipped.** See `ROADMAP.md` § PR8 acceptance.

| Check | Pass | Fail | Notes |
|---|:--:|:--:|---|
| Sanitizers + unit tests | [✅] | [ ] | `sanitizeShareFields.test.ts` |
| SharePositionCard + Portfolio wire | [✅] | [ ] | vault / DETF / bond Share |
| Token no invent claim | [✅] | [ ] | |
| LaunchBanner env | [✅] | [ ] | `NEXT_PUBLIC_SHOW_LAUNCH_BANNER` |

---

## Notes / Bugs Found

- Wave 2 + PR8 complete 2026-07-26. Fresh agents: open `ROADMAP.md` — residual only (PR9 / brand / Wave 3).

