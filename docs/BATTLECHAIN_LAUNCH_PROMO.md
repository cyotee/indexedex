# BattleChain Launch Promo — Community Greenfield + Crane

**Status:** Aligned with Crane greenfield master plan (2026-07-26)  
**Network:** BattleChain **testnet** only today — chain id **627**  
**RPC:** `https://testnet.battlechain.com` (Foundry alias **`battlechain-sepolia`**)  
**Explorer:** `https://explorer.testnet.battlechain.com`  
**Normative launch context:** [`LAUNCH_PLAN.md`](./LAUNCH_PLAN.md) §1.4b  
**Normative deploy checklist:** Crane [`docs/deployment/BC_GREENFIELD_MASTER_PLAN.md`](../lib/crane/docs/deployment/BC_GREENFIELD_MASTER_PLAN.md)  
**PRD / gaps / commands:** Crane `docs/deployment/BC_GREENFIELD_*.md`  
**X drafts (community voice):** Crane [`docs/deployment/BC_GREENFIELD_X_POSTS.md`](../lib/crane/docs/deployment/BC_GREENFIELD_X_POSTS.md)  
**Operator CWD:** Crane root (`lib/crane`) for all forge deploys  
**Sepolia→BC bridge:** `scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol`  
**Legacy minimal promo:** `scripts/foundry/Script_Promo_BC_Launch.s.sol` (fallback only; prefer greenfield phases)

---

## 1. Dual narrative (required)

IndexedEx / RICH CCA is the **Base capital raise**. BattleChain is **not** the sale venue.

### 1.1 Public — “look what we’re doing for the community”

Lead every external post with the **gift**:

| Say | Why it lands |
|-----|----------------|
| We’re deploying **Crane + a full DeFi toolkit** on BattleChain testnet for **builders, agents, and whitehats** | Generosity / open infra |
| **Safe Harbor** + attack mode — come **build or break it** | Security culture without claiming “audited” |
| Addresses on **docs**, not hex spam | Professional community ops |
| Bind what BC already provides; **ship what Crane owns** so others can compose | Collaborative with Cyfrin/BC, not competing |
| Phase posts: factories → Balancer V3 → Aave → more ports | Steady drumbeat during CCA window |

**Canonical public lines** (edit only for accuracy after live): Crane `BC_GREENFIELD_X_POSTS.md`.

### 1.2 Internal — “don’t look behind the curtain”

Do **not** put these in public posts. Ops and agents may know them:

| Reality | Implication |
|---------|-------------|
| Credible BC **launch promo needs surface area** | A sample ERC20 alone is not enough; greenfield multi-protocol *is* the stage |
| **We need our own stack on BC** (CREATE3, Balancer V3, ports) for adversarial validation | Same work serves community *and* our readiness |
| Product (IndexedEx / SingleVault DETF) may follow | Public reason remains **community lab**, not “so we can ship our DETF” |
| No external audit budget | Safe Harbor + greenfield is the substitute narrative substrate |

**Rule:** If a draft sounds like “we deployed this because we had to for IndexedEx,” rewrite as “we opened this toolkit for the community / whitehats.”

---

## 2. Why this exists (combined goals)

| Goal | Public framing | Internal framing |
|------|----------------|------------------|
| **Crane** | Diamond + CREATE3 open for builders | Our deployment foundation live on adversarial L2 |
| **Protocol ports** | Shared DeFi lab (Balancer, Aave, Uni, …) | Greenfield PRD phases we must run for promo depth |
| **Safe Harbor / attack mode** | Ethical hacker invitation | Security theater + real break-it surface |
| **Launch calendar** | Parallel goodwill during RICH CCA | Attention graph without competing for auction capital |

**Not** a token sale. **Not** where CCA proceeds or treasury live.

---

## 3. Scope matrix

### 3.1 Greenfield (authoritative — prefer this)

Follow Crane master plan phases. **No live BC broadcast until master plan §0** (all phase scripts written + local/fork tested).

| Public beat | Phase | Notes |
|-------------|-------|--------|
| Factories + core stubs, Safe Harbor lineage | **1** | Create3, diamond pkg factory, ERC20Permit, Uni V2/V4 PM, Permit2; bind BC WETH/Uni V3 |
| **Balancer V3** “ready to use” | **2** | Vault, TimelockAuthorizer, pool factories — community DEX surface |
| **Aave** supply/borrow surface | **3** | Path B / library precompile per Aave steps doc |
| Euler / Venus binds | **4–5** | Bind scripts |
| Aerodrome, Uni extras, Camelot, Liquity, Sky, Reliquary, Pendle, Frax, … | **6–13** | Expand after core gift; see gap report |

**Policy:** use BattleChain-provided contracts; only deploy Crane-owned gaps.  
Lineage: Create3Factory + `ChildContractScope.All` covers children when agreement lists the factory.

### 3.2 Legacy Wave A (minimal fallback)

Only if greenfield live is delayed and a **thin** announcement is required:

| Component | Role |
|-----------|------|
| Create3Factory + DiamondPackageCallBackFactory | Root lineage |
| ERC20Permit DFPkg + sample token | Demo (not mainnet RICH) |
| Uni V2 + V4 PM + Permit2 | Crane create3 gaps |
| BC WETH + Uni V3 | Bind only |
| Safe Harbor + attack mode | Promo hygiene |

Prefer **not** to announce “full toolkit” until Phase 2+ actually live.

### 3.3 Product wave (after greenfield base — quiet)

| Component | Public | Internal |
|-----------|--------|----------|
| IndexedEx manager / SingleVault DETF (RICH) | Optional “we also ship products here” *later* | Needs greenfield Balancer + factories first |
| Full explorer verification | Batch after addresses stable | Ops |

### Explicit non-claims

- BattleChain testnet is **not** production.  
- Ports may be **faithful vendors** for testing; not every mainnet peripheral is live.  
- Sample / greenfield tokens are **not** mainnet RICH.  
- Attack mode does **not** mean “audited.”  
- Greenfield is **not** “we finished an external audit.”

---

## 3. Network facts

| Item | Value |
|------|--------|
| Testnet chain id | **627** |
| Mainnet chain id (future) | **626** |
| BC Deployer (testnet) | `0x0f75289c6b883b885A1fDF9BCCABE1bbFB094077` |
| Agreement factory (testnet) | `0xf52CEA27b9E20D03Ec48CDe4fafF8F27565646f2` |
| Attack registry (testnet) | `0x22134e878c409a0Eab7259d873b38e26Ca966d3C` |
| Safe Harbor registry (testnet) | `0x07E09f67B272aec60eebBfB3D592eC649BDCFEFc` |
| Docs | https://docs.battlechain.com/llms-full.txt |

---

## 4. Operator runbook

### Prerequisites (from Crane root)

```bash
cd daosys/lib/indexedex/lib/crane   # canonical CWD for Crane deploys
export DEPLOYER=$(cast wallet address --account deployer)

# Fund BattleChain via on-chain bridge (Sepolia L1 → chain 627) — see BATTLECHAIN_DEPLOY_PLAN.md
L2_DEPOSIT_WEI=500000000000000000 forge script \
  scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol:Script_Bridge_SepoliaToBattleChain \
  --rpc-url sepolia_public --broadcast --account deployer --sender $DEPLOYER -vv

cast balance $DEPLOYER --rpc-url battlechain-sepolia
```

### Dry-run (local mock, from Crane root)

```bash
forge test --match-contract Pilot_BC_Promo_Launch_LocalMock_Test -vv
# Minimal pilot (if preferred):
# forge test --match-path "test/foundry/spec/pilot/Pilot_BC_ERC20Permit_LocalMock.t.sol" -vv
```

### Live testnet — greenfield (preferred)

**Gate:** Crane `BC_GREENFIELD_MASTER_PLAN.md` §0 all checked.  
**Commands:** Crane `BC_GREENFIELD_COMMANDS.md` / `BC_GREENFIELD_SCRIPT_GUIDE.md` — one phase at a time → update addresses docs → post matching draft from `BC_GREENFIELD_X_POSTS.md`.

Public sequence example: Phase 1 factories → Phase 2 Balancer V3 → Phase 3 Aave → …

### Live testnet broadcast (legacy minimal promo only)

```bash
forge script scripts/foundry/Script_Promo_BC_Launch.s.sol:Script_Promo_BC_Launch \
  --rpc-url battlechain-sepolia \
  --broadcast \
  --skip-simulation \
  --account deployer \
  --sender $DEPLOYER \
  -vv
```

**Required:** `--skip-simulation` on BattleChain forge broadcasts (BC skill / docs).

Outputs:

- Console logs of all addresses  
- `script/output/battlechain_promo_manifest.json` (addresses for announcement)

### Post-deploy

1. Confirm agreement + attack mode on explorer / BC registry queries.  
2. Fill [`battlechain/promo_addresses.md`](./battlechain/promo_addresses.md) from manifest.  
3. Publish announcement (see §6).  
4. Optionally open Safe Harbor bounty details / contacts for real security inbox.

---

## 5. Announcement copy (community-first)

**Prefer phase drafts** in Crane `BC_GREENFIELD_X_POSTS.md` after each live phase. Below are umbrella lines for CCA-week marketing.

### Short (Gitlawb tip / X)

> We’re opening **Crane + DeFi protocol ports** on **@battlechain** testnet for the community — builders and whitehats under Safe Harbor. Come compose or break it. Addresses on our docs.  
> **RICH** capital raise is a **Base CCA** — not on BattleChain.

### Medium (docs / blog blurb)

> **A DeFi lab for the community.** Through Crane’s greenfield program we’re deploying modular diamond infrastructure and major protocol surfaces (factories, Balancer V3, Aave-class, Uni-class, and more as phases land) on **BattleChain testnet**, under **Safe Harbor**, so anyone can build, compose, and ethically attack shared tooling.
>
> That work is **for builders and security researchers**. Separately, **IndexedEx** runs the **RICH** capital raise via **Uniswap CCA on Base** — BattleChain is not the sale venue.
>
> Addresses: Crane deployment docs / address JSON (no hex in social posts). Explorer: https://explorer.testnet.battlechain.com · BC docs: https://docs.battlechain.com/

### Talking points (public)

1. **Gift first:** open toolkit for the community, not a product dump.  
2. Crane is **reusable** CREATE3 + diamonds — others can ship on it.  
3. Ports exist so **others** can compose and attack.  
4. CCA (Base) = capital; BattleChain = community lab + ethical testing.  
5. Do **not** say “we need this for our IndexedEx deploy” in public.

### Talking points (internal only)

1. Greenfield depth is **required** for a non-embarrassing BC promo.  
2. Same stack validates Crane/Balancer/ports we depend on elsewhere.  
3. Product (SingleVault DETF / IndexedEx) may follow **after** greenfield base.

---

## 6. Definition of done

### Greenfield community launch (preferred)

- [ ] Crane master plan **§0** complete (all phase scripts written + local/fork tested)  
- [ ] Live phases broadcast per commands doc (not before §0)  
- [ ] Safe Harbor + attack mode for greenfield root lineage  
- [ ] Addresses published to Crane docs / JSON (no hex in X)  
- [ ] Matching **community** X drafts posted after each phase  
- [ ] X drafts reviewed (master plan 0.2)  
- [ ] Security contact real (not example.com)  

### Minimal fallback only

- [ ] Legacy `Script_Promo_BC_Launch` if greenfield blocked  
- [ ] Manifest + `promo_addresses.md`  
- [ ] Do not claim full Balancer/Aave toolkit if not deployed  

CCA open does **not** wait on full phases 6–13.

---

## 7. Contacts / Safe Harbor fields (fill before live agreement)

| Field | Value |
|-------|--------|
| Protocol name | `Crane DeFi Ports — BattleChain Community Greenfield` |
| Security contact | **TBD** (replace example emails in scripts before broadcast) |
| Recovery address | Deployer / multisig EOA on BC testnet |
| Agreement salt | greenfield salt per Phase 1 (`crane-indexedex-bc-greenfield-v1` or live PRD value) |

---

## 8. Related paths

| Path | Role |
|------|------|
| Crane `docs/deployment/BC_GREENFIELD_MASTER_PLAN.md` | **Normative checklist** |
| Crane `docs/deployment/BC_GREENFIELD_DEPLOYMENT_PRD.md` | What to deploy |
| Crane `docs/deployment/BC_GREENFIELD_COMMANDS.md` | Live commands |
| Crane `docs/deployment/BC_GREENFIELD_X_POSTS.md` | Community X drafts |
| Crane `docs/deployment/BC_GREENFIELD_GAP_REPORT.md` | Open phase depth |
| Crane `scripts/foundry/Script_BC_Phase*.s.sol` | Greenfield phase scripts |
| Crane `scripts/foundry/Script_Promo_BC_Launch.s.sol` | Legacy minimal promo |
| Crane `scripts/foundry/Script_Bridge_SepoliaToBattleChain.s.sol` | Sepolia→BC ETH |
| IndexedEx `docs/LAUNCH_PLAN.md` §1.4b | Launch dual narrative |
| `.claude/skills/battlechain-dev-workflow/SKILL.md` | Operator skill |

---

*Promo plan 2026-07-22; greenfield community narrative 2026-07-26. Update addresses after live broadcast.*
