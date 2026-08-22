# Product Requirements Document (PRD)

## Title

**DETF reserve donation** — permissionless capital donate onto Bond NFT reserve LP, 4626-credited to token id 0

## Status

**DRAFT v0.3** — 2026-08-22. Alignment locks **D29** (donate), **D30**, **D31**. Implement only from [`DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md`](./DETF_ALIGNMENT_IMPLEMENTATION_AND_TEST_PLAN.md) Stages **I–O** (donate is M–O).

| Field | Value |
|-------|--------|
| **Status** | **DRAFT v0.3** — 2026-08-22. Implement from alignment plan Stages I–O. |
| **Home** | `contracts/vaults/detf/DETF_RESERVE_DONATION_PRD.md` |
| **Alignment lock** | [`DETF_ALIGNMENT_PRD.md`](./DETF_ALIGNMENT_PRD.md) **D29** (process) and **D30** (Uni V4 owner ops while PoolManager is locked) |
| **Scope** | Every true DETF under `contracts/vaults/detf/protocols/dexes/**` that holds reserve LP on the Bond NFT (D13) |
| **Depends on** | D9 (only DETF adds/removes Uni V4 reserve LP), D10 (originalShares are the 4626 principal; N10 conversion), D13 (NFT custody), D15/D18/D25 (id 0 is how the protocol acquires LP), D30 (owner swap/withdraw during host lock) |
| **Not this file** | Protocol compound / expansion ([`docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`](../../../docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md)). Family curve and mint `tokenIn` lists (family PRDs, alignment §16.2). Live mint still uses D11 unassigned LP (no originalShares mint). |

**Short name:** reserve donation.

---

## 0. Intent

The DETF owns liquidity through Bond NFT `originalShares`. Users buy that ownership by bonding capital plus unboosted matching DETF. Token id 0 is the protocol slice; the rebasing claim token is a 4626 on id 0. Ids 1 and 2 never provided reserve capital: they cannot close or sell, and they take only a fee-oracle cut of minted DETF rewards (D2/D17).

Protocol-acquired LP is booked on **id 0** so the rebasing token’s zap-out rate can rise. That is already true of sell-in (D10), `buyClaim` (D18), and mature-close DETF rejoin (D25). Donate is the same acquisition class: someone pushes joinable capital (or existing reserve LP, or DETF) into a live instance and receives **nothing**. New 4626 shares go to id 0 only.

Fee routers (FeeCollector, hook `feeTo`, SE usage-fee recipients, keepers) need that path. `exchangeIn` → DETF already joins non-DETF capital onto the NFT but **mints DETF to the caller** (D11). `bond` opens a new user NFT. `compoundProtocolRewards` joins **pending DETF** and credits id 0. None of those is a fee gift.

Free liquid DETF remains a **second** claim on the same NFT LP (D13: `lpOut = detfIn * nftLp / detfSupply`). Burns dilute every originalShares holder, including id 0. That is accepted.

### 0.1 Goals

1. Add one permissionless donate route that accepts family live-mint / bond capital (`pairToken` / buffer / rateAsset, `vaultShare`, SE `tokens()` the family already settles), **DETF**, and already-minted reserve `lpToken`, and joins them into the reserve.
2. Put the **public** function on the Bond NFT vault, which already holds reserve LP (D13).
3. Credit new `originalShares` **only to token id 0** at the current 4626 rate. No DETF mint. No user-bond shares. No ids 1/2 LP. User `convertToAssets` stays flat (NAV unchanged; id 0’s share count rises).
4. Keep Uni V4 D9: the DETF diamond is the only contract that calls hook add-liquidity. The NFT does not call the hook.
5. Let FeeCollector keep calling `IDetf.donate` by forwarding to the NFT.
6. Owner host ops required by donate join (and by D15’s DETF buy) must run while Uniswap PoolManager / Balancer Vault is locked (D30).

### 0.2 Non-goals (v1)

1. Auto-compound of user or id-1/id-2 `claimRewards` DETF.
2. Balanced multi-leg joins (skew from a single donated leg is accepted, same as v1 protocol compound).
3. Collapsing donate(DETF) into `buyClaim` (donate mints no claim tokens) or into a DETF burn (donated DETF is joined as the self-leg).
4. Changing Policy/Open gates or first-bond / inert rules. Donate does **not** realize expansion (D31). Native ETH is not a donate token.
5. Closing Balancer public join (D9 exception stays).
6. Using leftover `UniV4DetfBondNft` (dual-OOR listing package). Production Bond NFT is `detf/common/bondNft/DETFNFTVault*`.
7. A donate-to-hook richness path that bypasses the NFT and D9 (opening-price adversarial rule stays).
8. Giving donated LP to user bonds or to ids 1 and 2.
9. Changing D11 live mint (still unassigned LP, still mints free DETF to the caller).
10. Guaranteeing that donate cannot open a Policy mint gate. Richer backing can raise synthetic. That is not an exploit; the donor received no DETF.

---

## 1. Locked decisions (summary)

| ID | Topic | Decision |
|----|-------|----------|
| **N1** | Public surface | Bond NFT `donate(...)`. Permissionless. Live only. |
| **N2** | Join executor | DETF diamond `joinDonatedCapital(...)`. `onlyBondNft`. Host-specific join. LP `to` = Bond NFT. |
| **N3** | FeeCollector | `IDetf.donate` forwards to NFT `donate` with `minLpOut = 0`. Pretransfer destination is the **NFT**. NatSpec on `IDetf.donate` is superseded by this file. |
| **N4** | Accounting | Physical LP lands on the NFT. **`addToDETFNFT(id 0, ΔL)`** at the current 4626 rate (`convertToShares(ΔL)` with N10). No user-bond shares. Ids 1 and 2 get none. |
| **N5** | No DETF print | Donate does not mint DETF, does not split a pot (D3/D4). Existing DETF may be **joined** as the self-leg (not burned). |
| **N6** | Token set | Family live-mint / bond capital: `pairToken` / buffer / rateAsset, `vaultShare` (and each vault share on multi-SE families), SE `tokens()` the family already settles, **DETF (`address(this)`)**, and `lpToken`. |
| **N7** | Join shape | Single-sided into the matching reserve leg (settle `vaultShare` / SE token to the family pair or buffer, then host `depositSingle` / Balancer single-sided join). **DETF** → self-leg join (`depositSingle(DETF)` / Balancer DETF-leg join). `lpToken` donate is a pull only, then still **N4** (credit id 0 for inbound LP delta). |
| **N8** | Liveness | Revert if `!isReserveLive`. No donate on an inert instance. |
| **N9** | Expansion / gates | Does **not** realize expansion. Not a mint/burn path: Policy gates do not block donate. Synthetic may move. D2 **does** run (id 0 effectiveShares change). |
| **N10** | 4626 conversion | `convertToAssets(s)` uses existing `BetterMath` + `decimalOffset`. Numerator is `lpToken.balanceOf(NFT)`. Denominator is **`totalOriginalShares`**, not effective shares, and **does not** subtract id 0. `s` is **originalShares**. |
| **N11** | Who gets the LP | **Id 0 only.** User bonds’ `convertToAssets` is unchanged (more id 0 shares at the same NAV). Ids 1 and 2 stay at 0 originalShares (D17 / FC9). Claim tokens share id 0’s NAV. |
| **N12** | D13 burn | `lpOut = detfIn * nftLp / detfSupply` still uses **all** physical NFT LP, including donated LP. Free DETF burn dilutes every originalShares holder, including id 0. Accepted. |
| **N13** | Event donor | `ReserveDonated` records the economic donor. If `msg.sender` is the DETF diamond, donor is `IDetf.donate`’s `msg.sender`. Otherwise donor is `msg.sender`. EOAs cannot spoof donor. |
| **N14** | `O == 0` | Allowed while live (last user bond may have D25-closed). Donate 1:1-credits id 0, so `totalOriginalShares` becomes the new LP. The next user bond cannot swallow the gift via D10’s empty-share branch. |
| **N15** | Funding | Classic `transferFrom`, **Permit2 allowance**, **Permit2 signature**, and `pretransferred` unbooked surplus (non-LP). **No native ETH.** `lpToken` credits **this-call inbound LP delta** only. |

---

## 2. Why the Bond NFT is the public surface

Reserve LP already sits on the Bond NFT (D13). Donate’s economic effect is “more LP in that wallet, more id 0 originalShares.” Callers that already talk to the NFT (FeeCollector wiring, keepers, tests) should not have to know the reserve host.

The NFT still cannot add Uni V4 liquidity itself. Alignment D9: hook add/remove is `onlyOwner`, owner = DETF diamond. A Bond NFT `depositSingle` on the hook would revert once `ownerOnlyLiquidity` is on.

So the split is:

```text
caller  →  Bond NFT.donate          (pull token, public)
               │
               ▼
          DETF.joinDonatedCapital   (settle + host join, onlyBondNft)
               │
               ▼
          reserve host              (hook depositSingle / Balancer join)
               │
               ▼
          LP minted to Bond NFT
               │
               ▼
          addToDETFNFT(id 0, ΔL)    (4626 at current rate)
```

Balancer D9 still allows public pool joins. Outsiders could transfer BPT straight to the NFT. That raises `balanceOf` **without** N4 until someone `donate(lpToken)` credits the inbound delta to id 0, or a later bond uses D10 against the new `L`. Uni V4 outsiders cannot mint hook LP, so Uni V4 donate of non-LP tokens must go through this route. Optional later: set hook `feeTo` to the Bond NFT so protocol-fee LP lands on the NFT; then `donate(lpToken)` books it to id 0.

---

## 3. Surfaces (normative ABI)

Names may move for stack pressure. Selectors and semantics are the law.

### 3.1 Bond NFT (public)

```solidity
function donate(
    IERC20 token,
    uint256 amount,
    uint256 minLpOut,
    bool pretransferred,
    uint256 deadline
) external returns (uint256 lpOut);

function donateWithPermit2Allowance(/* same money args + Permit2 allowance packing */)
    external returns (uint256 lpOut);

function donateWithPermit2Signature(/* same money args + Permit2 signature packing */)
    external returns (uint256 lpOut);

function previewDonate(IERC20 token, uint256 amount) external view returns (uint256 lpOut);
```

Permit2 packing matches the Uni V4 CP hook `depositSingle` Permit2 paths (allowance + signature). Names may move; both Permit2 modes are required. **No native ETH.** `IDetf.donate(token, amount, pretransferred)` ABI stays frozen (void); Permit2 callers use the NFT.

Rules:

1. `nonReentrant`. Honor `deadline`. `amount == 0` reverts `ZeroAmount`.
2. Live only: call DETF `isReserveLive()` (or equivalent) and revert `ReserveNotLive` if false.
3. Pull (one of):
   - `pretransferred=false`: `transferFrom(msg.sender, address(this), amount)` then credit **observed inbound delta** (I1 / L-CLAIM-3).
   - Permit2 allowance or signature: pull via Permit2 to this NFT, then credit observed inbound delta.
   - `pretransferred=true` and `token != lpToken`: credit **unbooked surplus** of that token (permissionless sweep of idle pair / vaultShare / DETF / SE tokens on the NFT).
   Do not trust caller `amount` as the booked figure.
4. If `token == lpToken`: credit **this-call inbound LP delta** only. Do not treat the whole `balanceOf(NFT)` as new. `lpOut = inboundLpDelta`. Do not call DETF join. Then N4: `addToDETFNFT(id 0, lpOut)`.
5. Else: approve/push `token` to the DETF (exact amount, reset allowance after) and call `joinDonatedCapital`. `lpOut` is the host LP minted to this NFT. Then N4.
6. If `lpOut < minLpOut`, revert slippage. `minLpOut == 0` means no bound (FeeCollector).
7. **Do** `addToDETFNFT(id 0, lpOut)`. Do not `createPosition` for the donor. Do not change user-bond `originalShares`.
8. Do **not** realize expansion (D31: donate is not a realize path). Do not `compoundProtocolRewards` on this path. D2 top-up **does** run because id 0 effectiveShares changed.
9. Emit `ReserveDonated(donor, token, amountIn, lpOut)` with N13 donor.

`previewDonate` uses the same settle + host preview as execution, then `convertToShares` of that LP (preview of id 0 credit, not a second mint). `token == lpToken` returns `amount` (assumes a pull of `amount`). Unknown token returns 0 (preview) / `InvalidRoute` (execute). Inert preview returns 0.

Join slippage is checked on the NFT after the host join in the **same transaction**; a revert rolls the join. `joinDonatedCapital` has no `minLpOut`.

### 3.2 DETF (Bond NFT only)

```solidity
function joinDonatedCapital(
    IERC20 token,
    uint256 amount,
    uint256 deadline
) external returns (uint256 lpOut);

function previewJoinDonatedCapital(IERC20 token, uint256 amount)
    external
    view
    returns (uint256 lpOut);
```

Rules:

1. `msg.sender == bondNftVault`. Anyone else reverts `NotAuthorized`.
2. Reuse the family’s `_settleToPair` / mint-capital settle (pair, `vaultShare`, SE `tokens()`, buffer where that is the mint capital).
3. If `token` is DETF (`address(this)`): self-leg join (Uni V4: hook `depositSingle(DETF, …, to=NFT)`; Balancer: single-sided DETF-leg join). Do not mint DETF. Do not burn DETF. Do not mint claim tokens.
4. Else: host join is the family’s **single-sided** join of that non-DETF leg used by live mint. LP recipient is the Bond NFT, never the diamond and never the donor.
5. After join, sync expected hold reserves as other mint paths do. D30: this join must succeed even if PoolManager / Balancer Vault is already unlocked in this transaction.
6. Vault disable (CROPS): inbound donate reverts; mature close / claim redeem still work.

### 3.3 `IDetf.donate` (forwarder)

Existing:

```solidity
function donate(IERC20 token, uint256 amount, bool pretransferred) external;
```

Revise NatSpec to this process (join + id 0 4626). Not “depends on the implementation.” Family owns the join helper and token list; the process is universal.

Implementation:

1. `bondNftVault.donate(token, amount, 0, pretransferred, block.timestamp + 1)`.
2. **Locked pretransfer destination: Bond NFT.** Collector transfers accepted **non-LP** tokens to the NFT, then calls `IDetf.donate` with `pretransferred=true`. The diamond only forwards. Do not support two different pretransfer destinations in v1.
3. Return value may stay `void` on `IDetf` (ABI freeze for collectors). NFT `donate` returns `lpOut`.
4. Donor for the NFT event is `IDetf.donate`’s `msg.sender`.

### 3.4 Where the code lives

| Piece | Path |
|-------|------|
| NFT `donate` / `previewDonate` | `detf/common/bondNft/` (`DETFNFTVaultTarget` + facet selectors + `IDetfBondInventoryPolicy` or a small `IDetfReserveDonation` on the NFT) |
| DETF join | Each family exchange/bonding common (reuse `_settleToPair` + `_depositSinglePair` / `_depositSingleDetf` / Balancer join). Shared interface on `IDetf` or `IDetfReserveDonation` |
| Forwarder | Family facet that already exposes bonding, **or** a shared snippet if every family diamond implements `IDetf` |
| N10 conversion | `DETFNFTVaultRepo._totalLpReserveForConversion` (and Composed’s NFT repo if that family is in scope after D13 custody) |

Do not add donate to leftover `UniV4DetfBondNft`.

---

## 4. Accounting

### 4.1 Physical LP and id 0 shares

Let `L` = `lpToken.balanceOf(bondNft)` before donate, `ΔL` = LP minted (or inbound LP delta), `O` = `totalOriginalShares`, `O0` = id 0 `originalShares`.

After a successful donate:

```text
L'  = L + ΔL
ΔO  = convertToShares(ΔL)     // N10; if O == 0 or L == 0: ΔO = ΔL (D10 empty branch)
O'  = O + ΔO
O0' = O0 + ΔO
convertToAssets(s) = BetterMath(s, L', O', decimalOffset)   // Floor
```

User originalShares `s_u` are unchanged, so `convertToAssets(s_u)` is unchanged at the same NAV. Id 0 has more shares at that NAV: the rebasing token is richer. Ids 1 and 2 still have `originalShares == 0`.

D2 then tops up ids 1 and 2 **effectiveShares** to `f` and `c` of the new `O` (reward weight only).

### 4.2 Conversion dependency (must fix if still wrong)

`DETFNFTVaultRepo._totalLpReserveForConversion` today can subtract protocol **effective** shares from the denominator while using **all** physical LP as the numerator. That overpays user bonds and would leak donated / rejoined id 0 LP to users.

Donate ship gate requires N10: denominator is `totalOriginalShares`, numerator is physical LP on the NFT, `decimalOffset` kept, input is originalShares. Mature close must pass originalShares (not effectiveShares) into `convertToAssets`.

This is a D10 repair with blast radius beyond donate.

### 4.3 Family `protocolLp()` getters

Do not invent a third donated-LP bucket. Keep each family’s getter formula. Donate increases `nftLp` and id 0 originalShares together, so an id-0 4626 getter rises by construction. Uni V4 CP `nftLp - userBondedLp` also rises (userBondedLp unchanged).

### 4.4 Interaction with other paths

| Path | After donate |
|------|----------------|
| Mature close (D25) | User still gets only their originalShares NAV (unchanged by donate). DETF from their unwind still rejoins to id 0 |
| Sell → claim (D10) | User’s originalShares move to id 0. Id 0 is already larger from donate |
| Live mint (D11) | Still unassigned-LP for that mint’s non-DETF join; still prints DETF. Distinct from donate |
| Protocol compound | Still pending DETF on id 0 → self-leg join → originalShares to id 0. Same destination as donate, different source |
| `buyClaim` (D18) | Same join + id 0 credit as donate(DETF), **plus** claim mint to the caller |
| Free DETF burn (D13) | Uses larger `nftLp`. Dilutes id 0 and user originalShares |

v1 does **not** fence donated LP from D13 burns. A fence would need a second ledger.

---

## 5. Accepted tokens (N6)

Execute `InvalidRoute` unless `token` is one of:

1. Family `pairToken` / buffer / rateAsset used as live-mint capital.
2. `standardExchangeVaultShare` (and each vault share on multi-SE families).
3. Tokens in the backing SE `tokens()` / `vaultTokens()` that the family already settles in `_settleToPair` or mint.
4. DETF (`address(this)` on the diamond).
5. Reserve `lpToken` (hook LP or BPT).

`acceptedBondTokens()` lists (1)–(3). Document DETF and `lpToken` as donate-only extras if omitted from that view.

**Forbidden on this route:**

- Arbitrary ERC-20s. No `processArgs` allowlist beyond the family’s existing mint/bond set plus DETF plus `lpToken`.
- Fee-on-transfer (universal token policy). Pull still books **delta**.

Multi-leg families (Orbital, Weighted, Quad, MVW, MixedBuffer, Composed): donate **one** listed leg per call. Skew is accepted. Do not require the caller to donate every leg.

---

## 6. Family join table

| Family | Typical `token` | Join |
|--------|-----------------|------|
| Uni V4 CP | `pairToken`, `vaultShare`, SE tokens, DETF | Settle to `pairToken` then hook `depositSingle(pairToken, …, to=NFT)`; DETF → `_depositSingleDetf(…, to=NFT)` |
| Uni V4 Orbital / Weighted / Quad | `pairToken(i)`, `vaultShare(i)`, DETF | Single-sided that pair (or DETF self-leg) into the family buffer hook, LP to NFT |
| Balancer Single SE | `vaultShare`, pair/rateAsset if the mint list includes it, DETF | Single-sided Balancer join of that leg, BPT to NFT |
| Mixed-buffer | `bufferToken`, each `vaultShare`, DETF | Single-sided that leg |
| Multi-vault weighted / Composed | family mint `tokenIn` list, DETF | Single-sided corresponding reserve leg |

Empty-book / pre-live joins stay **first bond** (D16). Donate does not bootstrap.

Hook `depositWithSeShares` is proportional (raw DETF + SE shares). Donate must **not** mint DETF to fill that shape. `vaultShare` donate settles through the SE to pair/buffer, then single-sided pair join.

D30: Uni V4 `depositSingle` from the DETF owner must work even when PoolManager is already unlocked in this transaction.

---

## 7. Liveness, gates, expansion, fees

| Question | Answer |
|----------|--------|
| Inert? | Revert. |
| Policy mint/burn gate? | Does not apply. Donate is not mint or burn. |
| May synthetic rise enough to open mint? | Yes. Caller spent capital and received no DETF. That is not an exploit. |
| Realize expansion? | No. Same class as primary mint: not bond / `claimRewards` / `compoundProtocolRewards`. |
| Usage fee / seigniorage `p`? | No. No DETF quote. |
| D2 top-up? | **Yes.** Id 0 originalShares/effectiveShares changed. |
| Oracle `feeTo` as the only caller? | No. Permissionless. FeeCollector is one caller. |

---

## 8. Related paths (do not collapse)

| Mechanism | Capital in | DETF minted? | LP / shares |
|-----------|------------|--------------|-------------|
| **Donate (this PRD)** | pair / vaultShare / SE token / DETF / existing LP | No | LP to NFT, **originalShares to id 0** |
| Live mint D11 | same non-DETF capital | Yes, to caller + pot | LP to NFT, **no** new originalShares |
| Bond | same capital | Yes, join `G` into pool | LP to NFT, **new** user originalShares |
| `buyClaim` | DETF | No | Self-leg join, originalShares to id 0, **claim minted** |
| Protocol compound | pending DETF on id 0 | No (already minted) | Self-leg join, originalShares to id 0 |
| Mature close D25 | (unwind) | No; withdrawn DETF **rejoined** | originalShares to id 0 for the rejoin |
| Idle ERC-20 on the diamond | anything | n/a | **Not** counted. Not a donate. Sweep is out of v1 |
| Transfer `vaultShare` to the hook | SE shares | n/a | Raises `_seClaim()` without LP mint. **Forbidden as a product path.** Adversarial richness. Donate must mint (or pull) LP onto the NFT |

Hook protocol-fee LP mint (`_mintProtocolFeeIfNeeded` → `feeTo`) is **not** this route. A later deploy choice may set hook `feeTo` to the Bond NFT so those LP tokens land on the NFT; `donate(lpToken)` then books inbound delta to id 0. Do not require that in v1.

---

## 9. Errors, events, access

Use existing family errors where they already exist.

| Condition | Error |
|-----------|--------|
| `amount == 0` or zero pull delta / zero unbooked surplus | `ZeroAmount` |
| not live | `ReserveNotLive` / family equivalent |
| unknown token | `InvalidRoute(token, expected)` |
| `joinDonatedCapital` not from NFT | `NotAuthorized` |
| `lpOut < minLpOut` | `MinAmountNotMet` / family slippage |
| past deadline | existing deadline error |
| host join returns 0 LP | revert (do not silently accept a zero join) |
| `pretransferred=true` on **lpToken** and no this-call inbound LP delta | revert (I1: no free credit of booked reserve LP) |
| `pretransferred=true` on **non-LP** and unbooked surplus is 0 | revert (I1) |
| instance disabled | inbound revert (CROPS); not a donate-specific error |

Event on the NFT:

```text
ReserveDonated(address indexed donor, address indexed token, uint256 amountIn, uint256 lpOut)
```

`amountIn` is the observed inbound delta of the donated token (not the caller’s `amount`, not the post-settle pair amount).

---

## 10. Testing (ship gate)

Production-first. Gold family TestBase. No mock of DETF, Bond NFT, hook/pool, manager, registry, fee oracle, or backing SE.

Prefix unique per family, e.g. `test_N1_donate_pairToken_credits_id0`.

| ID | Must prove |
|----|------------|
| **DN1** | After first bond, `donate(pairToken)` increases `lpToken.balanceOf(NFT)` and id 0 `originalShares`. DETF `totalSupply` unchanged. User DETF balance unchanged. User-bond `originalShares` unchanged. User `convertToAssets` unchanged (N10 NAV). |
| **DN2** | Same for `vaultShare` (settle path). |
| **DN3** | `donate(lpToken)` credits **this-call** inbound LP to id 0 with no host join (Balancer: mint BPT elsewhere if D9 allows; Uni V4: only LP already in test control). Pre-existing NFT LP is not double-credited. |
| **DN4** | `donate(DETF)`: donor DETF down, `totalSupply` unchanged, `nftLp` up, id 0 originalShares up, no claim minted. Not `InvalidRoute`. Not a burn. |
| **DN5** | Inert donate reverts. |
| **DN6** | Two user bonders: after donate, both `convertToAssets` unchanged. Id 0 `convertToAssets` rises. Id 1 / 2 `convertToAssets == 0` before and after (FC9). |
| **DN7** | `IDetf.donate` forwarder: non-LP tokens on the NFT, `pretransferred=true`, same id 0 credit as NFT `donate`. Event `donor` is the collector, not the diamond. |
| **DN8** | `joinDonatedCapital` from an EOA reverts `NotAuthorized`. |
| **DN9** | `pretransferred=true`, no inbound delta / no unbooked surplus: revert; attacker product balances unchanged. Happy-path `pretransferred=true` with a real prior non-LP transfer does not cover this. |
| **DN10** | `previewDonate` equals execution `lpOut` on closed-form families (few-wei only if a Balancer multi-leg join forces it, documented). |
| **DN11** | Uni V4: with `ownerOnlyLiquidity` on, a direct hook `depositSingle` from a non-DETF address reverts. Donate still succeeds. |
| **DN12** | Donate does not call expansion realize: `lastExpansionTimestamp` and `pendingExpansionDetf` unchanged when time has accrued (compare to a `claimRewards` control that does realize). |
| **DN13** | After donate, a D13/D20 burn still succeeds; `nftLp` used in the burn formula includes donated LP. |
| **DN14** | Mature close after donate: user non-DETF out matches pre-donate snapshot (same bond, no other state change); withdrawn DETF is rejoined to id 0 (D25), not burned. |
| **DN15** | Conversion uses N10: donate does **not** raise user `convertToAssets` via a protocol-share haircut. `decimalOffset` still applied. |
| **DN16** | Last user bond D25-closes (`O` may be only id 0 or 0) → donate → id 0 originalShares include the gift → next user bond does **not** capture donated LP via D10 empty-share `originalShares = G`. |
| **DN17** | D2: after donate, ids 1 and 2 `effectiveShares` still `f` and `c` of the new total (reward weight only). |
| **DN18** | Vault disabled: donate reverts; mature close still works (CROPS). |

---

## 11. Implementation notes (not a substitute for a plan)

1. Add NFT functions and selectors on the common Bond NFT package so every family that already uses `DETFNFTVault` inherits donate without a second NFT type.
2. Add `joinDonatedCapital` on each in-scope family facet. Uni V4 CP can clone `_mintDetfFromPair`’s settle + `_depositSinglePair(…, _bondLpHolder())` and delete the DETF mint/split; DETF donate uses `_depositSingleDetf`.
3. Fix N10 conversion in `DETFNFTVaultRepo` in the same change set as donate. Donate tests will fail if NAV math still haircuts protocol effective shares.
4. Coding sequence is alignment plan Stages **I–O**. N10 is I. D30 is J. D25 is K. D15+D31 is L. Donate Uni V4 CP is M. Other Uni V4 is N. Balancer is O (Composed blocked until D13 NFT custody).
5. Optional later: set Uni V4 hook protocol-fee `feeTo` to the Bond NFT so swap-minted protocol LP can be booked via `donate(lpToken)`. Not required to close this PRD.

---

## 12. Doc follow-through (when code lands)

- This file: mark LOCKED and date.
- Alignment D29 / D30: expand §21 / §22 if the summary here drifts.
- `IDetf.donate` NatSpec.
- `IDetfBondInventoryPolicy` (or NFT interface) + facet selector lists.
- Family PRDs: one line under user routes pointing here (do not copy the join table).
- `docs/agent/INDEXEDEX_AGENT_LAW.md`: donate is Bond NFT public / DETF join / no DETF mint / originalShares to id 0 / N10 4626.
- Uni V4 reserve hook PRDs: D30 owner swap/withdraw while PoolManager is locked.
- Opening-price PRD adversarial line stays: no diamond-impersonation hook `depositSingle` as a richness cheat. Product donate after live is a different path.

---

## Changelog

| Version | Date | Notes |
|---------|------|--------|
| v0.1 | 2026-08-21 | Draft. Public donate on Bond NFT. DETF-only host join (D9). D11 unassigned LP. pairToken + vaultShare. IDetf.donate forwarder. N10 conversion. |
| v0.2 | 2026-08-22 | Intent: protocol acquires LP on id 0. N4 `addToDETFNFT(id 0)`. Donate accepts DETF (self-leg join, no burn, no claim). N10 keeps decimalOffset. Event donor. Unbooked surplus pretransfer. D2 runs. O=0 credits id 0. D13 burns still dilute. D30 owner host ops while locked. |
| v0.3 | 2026-08-22 | Permit2 allowance + signature on NFT donate; still no native ETH. D31: donate still does not realize expansion. Owner `depositSingle` at MIN must mint lpOut > 0. |
