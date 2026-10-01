# Grok original — NN-02 UI / multi-product claim paths (disconfirming hunt)

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Date | 2026-09-27 |
| Mode | Research only. No RPC, browser/JS execution, shell, tests. |
| Context7 | NetNet is not a Context7 library (Getnet hits only). Unused. |

**Failed / not retried:** `lib/crane/contracts/protocols/pol/net/src/` listing; prior-session `BondDepository.sol`, `IBondDepository.sol`, `Constants.sol` (`RC_UNAVAILABLE`). Blockscout `api/v2/smart-contracts/…` and `api?module=contract&action=getabi` → **403**. Sourcify `files/any/…` → **403**; `…/sources` → **404**. App source map `https://app.netnet.capital/assets/index-LJ9ip9MD.js.map` → **404**.

---

## 1. Question and method

Does **every** NetNet bond holder share an all-note `redeem`, and does the **app** call a **selective** write? Hunt **against** the earlier “only `redeem(to)` walks everything” conclusion. Split: (a) **display/read** vs **on-chain write**; (b) **BondDepository** vs Genesis / Inverse / RWA / Superstore / TURBO.

---

## 2. Direct evidence

### 2.1 Official docs — primary offerings (BondDepository)

https://docs.netnet.capital/mechanism (2026-09-27): prices USDG or LP bonds; epoch **capacity** of **payout**, not note count. **No claim function named.** No per-note redeem described.

https://docs.netnet.capital/official-channels: BondDepository `0xff32a969A0c567129eECD926D04657728E1980C1`.

PRD v0.23 §12.1 / **NN-02 source clarification (PRD:815)**: vendor `deposit(..., to)` arbitrary recipient; `:143–165` full-history scan; no prune; `redeem(to)` = **payout recipient**, not a note subset. That is **PRD-cited vendor**, not re-read here.

### 2.2 Sourcify — deployed vs “some” verified source

https://sourcify.dev/server/v2/contract/4663/0xff32a969A0c567129eECD926D04657728E1980C1 (2026-09-27): **`exact_match`**, `verifiedAt` **2026-07-16T20:34:17Z**. Same for GenesisBond `0x575b7B7c…913f` (2026-07-16) and RwaDesk `0x99B6eE6e…1961` (2026-08-24).

**Inference only:** bytecode matches *a* verified compilation. **Files were not served**, so this pass **cannot** list deployed function signatures or prove identity with the Crane vendor tree.

### 2.3 App HTML / bundle (no JS execution)

https://app.netnet.capital/ (2026-09-27): SPA, `#root`, script **`/assets/index-LJ9ip9MD.js`**. Nav copy: “Bond Subscriptions.” **No** function names in HTML.

Bundle fetched as text; minified **single line**, webfetch truncated; grep on the save file is not a reliable ABI extract. **Cannot** state the wallet `to` / `data` the Claim button sends. Source map **absent**.

### 2.4 Other products — do not merge with BondDepository

| Product | Contract (official-channels) | Claim surface in **docs** | Same ABI as BondDepository? |
| --- | --- | --- | --- |
| **GenesisBond** | `0x575b7B7c…913f` | Founding guide: **one Claim tx**; 5-day vest from `finalize()`; soulbound **ERC-721** certificate. https://docs.netnet.capital/founding-shareholder-guide | **No** — separate offering, closed. |
| **InverseBond** | `0x92166e94…C4C9` | Mechanism: seller-initiated **buyback**, not a vesting note claim. | **No**. |
| **RWA Desk** | `0x99B6eE6e…1961` | https://docs.netnet.capital/rwa-desk : 2-day vest; “Claim it from the **subscription ledger** below the desk, **alongside any standard bonds**.” | **Unknown write.** Ledger = **UI list** unless ABI shown. |
| **Superstore PackDesk** | `0x7cf28D61…21eB` | https://docs.netnet.capital/superstore : kept wins “**same note plumbing as Real World Bonds**: amount owed, **per-address caps**, and a **paginated redeem**.” | **Different contract.** Pagination is **documented here**, not for BondDepository. |
| **TURBO** | `0x75712243…2C8a` | https://docs.netnet.capital/turbo : ERC-1155 **cards**, cash-out / knock-out; **no NET note array**. Launch series expiry **2026-09-18** (docs). | **No**. |

**Disconfirming lead (scoped):** Superstore (and by its own words RWA plumbing) advertises **paginated redeem** + per-address caps. That is **not** proof BondDepository has `redeemNote` / cursor. It **is** proof NetNet **knows** pagination on **later desks**. Do not import PackDesk pagination into PkgArgs BondDepository.

### 2.5 Public GitHub

Search did **not** surface a NetNet BondDepository repo. OlympusDAO / other “BondDepository” hits are **unrelated**. No official app source bundle beyond the minified JS.

---

## 3. Display vs write

| Layer | What we have |
| --- | --- |
| **Read / UI** | Docs + app promise a **ledger of subscriptions** (RWA + “standard bonds”). `notes(address,i)` / `pendingFor` as **views** would let the UI **draw** each note without a per-note **tx**. |
| **Write** | Mechanism docs never name a selector. App Claim/Confirm **not** decoded. Vendor/PRD: **`redeem(address to)`** aggregates vested NET for `msg.sender`. |

A per-row **Claim** button can still encode **`redeem(user)`** (one write, all notes). **UI granularity ≠ selective on-chain claim.**

---

## 4. Ordinary users vs DETF wrapper

**Not claiming an observed outage or attacker cost.**

- **EOA user:** typically few **self**-bought notes; one Claim ≈ one `redeem(self)`. Same **O(n)** walk if the depository is as PRD describes, but **n** is usually small. Unsolicited `deposit(..., user)` is still possible; docs never warn. No keeper; permissionless (mechanism §7).
- **Wrapper:** **durable** `to`, **must succeed** inside **atomic** Keep-YT+mint+stake (extra gas vs a naked Claim). Shared or predictable escrow **concentrates** many positions and **advertises** a grief target. Failure **rolls back collection** (PRD:806) — worse than a user retrying Claim later.
- **Genesis / TURBO / Inverse** holders are **not** on this array. **RWA/Superstore** holders may use **paginated** desk functions — **separate** liveness story.

---

## 5. Corrections to prior overclaims (this researcher)

- Do **not** treat unread Crane files as **this-pass** source. PRD:815 is the local citation.
- Do **not** assert the **wallet calldata**. Bundle not decoded.
- Do **not** treat Sourcify `exact_match` as ABI dump.
- Do **not** say “all NetNet bonds” share one scan — **Genesis, Inverse, TURBO, Superstore** differ.
- Superstore **paginated redeem** is **real docs**, **wrong contract** for NN-02’s PkgArgs depository unless proven shared implementation.
- No N\*, gas/note, or live DOS.

---

## 6. Gaps (still)

1. Deployed BondDepository **ABI/source text** (explorer 403; Sourcify metadata without files).  
2. App **`redeem` vs `redeemNote` vs PackDesk page** in `index-LJ9ip9MD.js`.  
3. Whether RWA “same plumbing” **is** BondDepository or a **fork with pagination**.  
4. InverseBond write ABI.  
5. Crane vendor vs 2026-07-16 Sourcify compilation **diff**.

**Until (1)–(2):** NN-02 should assume **BondDepository has no proven selective write**, while **not** claiming the **entire** NetNet UI is stuck on that walk.

Confidence: **high** on product split and Superstore pagination **docs**; **low** on app calldata; **none** on deployed BondDepository opcode list this pass.
