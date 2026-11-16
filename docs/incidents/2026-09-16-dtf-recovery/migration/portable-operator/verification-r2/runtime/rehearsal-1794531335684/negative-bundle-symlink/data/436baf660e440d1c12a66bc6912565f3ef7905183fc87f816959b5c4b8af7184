# Actual EOA-owner funding: bounded source admission contract

Date: 2026-11-12. Producer proposal only. This follow-up qualifies fixture
acquisition; it does not replace or edit any prior verdict.

## 1. Row admission

| Row | Fixed chain4663 source | This follow-up |
| --- | --- | --- |
| E-S | `0xb7d4bb379d361ad442cddee53ea71a33957826a7` | **not-ready**: collector and its actual owner each hold zero. No withdrawal, donation or positive custody was attempted. |
| E-P | `0x923877336b14662cfb5b3a60b14e7d716d54a888` | **admitted-proposal, external-owner-donation-dependent**, for signed exact native18 approved custody-and-hold of the specifically acquired physical LP. |
| W-P | `0x46e068c2393e189fbc86632f67210af253a42aa8` | **admitted-proposal, external-owner-donation-dependent**, for signed exact native18 approved custody-and-hold of the specifically acquired physical LP. |
| W-SW | `0x999dae02d22e5fee1c4508430d5196d31d631009` | Prior independent source-only custody admission retained unchanged; no new transfer, custody or liquidation experiment. |

E-P/W-P admission depends on an existing external fee-collector owner's
voluntary release and subsequent personal donation. It is not a public
acquisition path for a generic user, authority possessed by Migration, donor
private-key control, a historical original, an operational award, a conversion
route or production integration approval. Independent follow-up admission
belongs to the separate verifier lane.

## 2. Exact authority and operation boundaries

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-20-se-lp-source`.
Unchanged HEAD: `1df9076c73b94a4f63172395763fa8cdd48fe060`.
Branch: `work/dtf-migration-phase-20-se-lp-source`.
Writes are confined to this `owner-funding/` directory.

The complete root follow-up brief authorizes only a disposable loopback18570
fork of chain4663, block108944663, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
This historical source pin is not the funded Migration quote snapshot.

Actual collector: `0x20af9a1e21a59a411cd3b0c40e70af9084770b2e`.
Actual owner: `0x72bea6fa3e68ef18c87d045aac7c4aa5249d933b`.
The fork reconfirms `owner()` and empty owner code `0x`; this authenticates
the deployed owner address, not its private key. Collector code is 370 bytes,
keccak256
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.
`pullFee(address,uint256,address)` selector `0x45e94ee3` actually routes to
`0xF7A99a0aeD1A4252C71c99FDD2a5B3250a41f669`, whose runtime keccak256 is
`0x7ae5c353c623b635938a7bb3ebc07cb3eda6469b2cd9dbf76c8bed336ff0b5cb`.
Full runtime bytes and the collector's complete selector table are bound in
`runtime.json.bindings` and raw `rpc.json`.

`contracts/fee/collector/FeeCollectorManagerTarget.sol:67-70` explains a
current onlyOwner transfer. It is explanatory source, not proof that the
current artifact equals the legacy deployed facet. The earlier sealed
comparison reported an artifact mismatch; this follow-up neither replaces
that result nor reads a changing production artifact. Actual caller, fixed
selector, deployed routing, receipt, return, token balances and state diffs
establish these particular local releases.

| Operation | Actual authority | Admitted local evidence |
| --- | --- | --- |
| Collector `pullFee(token,q,owner)` | Only the actually observed existing EOA owner, simulated by local impersonation | Positive bounded collector inventory only; recipient is that same owner; exact debit/credit, supply and routing preservation |
| Personal `token.transfer(controlledWallet,q)` | That EOA acting as holder of the newly released tokens | Separately impersonated local personal donation, not a donor-key signature |
| Source approval and custody invocation | Controlled wallet's own real development signatures | Actual source allowance plus fixed-source helper pull from that same wallet to fixed helper custody |
| Wrong wallet / missing synthetic record | No eligible helper authority | Real signed rejection without measured custody/accounting changes |
| Recovery, source enablement or legacy LP-owner operation | Not granted | No such transaction; all old negative findings retained |

No contract-valued owner, infrastructure holder or collector contract was
impersonated. ED `0xaf0e1967c8f755c747615c5427108bc549ca1122` remains E-P's
owner; WD `0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7` remains W-P's
owner. Neither was called as an impersonated owner. There was no role or
ownership change, state/code/balance injection, arbitrary executor, LP mint,
liquidity exit, source enablement or public transaction.

## 3. Actual inventory and bounded acquisition

All quantities below are raw native18 integers. Each source reports 18 decimals.

| Row | Collector before | Released to actual owner | Collector after |
| --- | ---: | ---: | ---: |
| E-S | 0 | no operation | 0 |
| E-P | 453163036817578813953732920170 | 10020 | 453163036817578813953732910150 |
| W-P | 1516646747724649142 | 10030 | 1516646747724639112 |

The owner initially held zero of all three tokens. Each successful release
credited exactly q to the owner, then a separate personal transfer credited
exactly q to controlled wallet
`0xb24e6C5d01d14be3918ed712aCe1b2f7F2Bef53a`.
After donation the owner again holds zero E-P/W-P. Each release returned
ABI bool true, with status1 and actual token Transfer logs. State-diff
traces show exactly two token storage deltas, -q and +q, no collector
storage change and no code change. Ordinary gas/nonce and fee-recipient ETH
changes are transaction effects, not injected balances.

E-S remains precisely not-ready under this path: no collector inventory
exists to release. No zero withdrawal, alternate target, substituted
infrastructure holder or unsupported call was tried. This is not a holder
census or proof that no legitimate acquisition could ever exist.

## 4. Fixed source custody and synthetic recurrence

Controlled wallet uses public development mnemonic
`test test test test test test test test test test test junk`,
derivation `m/44'/60'/0'/0/140`. Other controlled wallet is
`0xFaF513321611B74ca918dF250d6ac38d43ab57f8`, derivation141.
Development account0 genuinely signs gas transfers and helper deployments.
No gas balance is injected. All34 signed transaction payloads, recovered
signers and canonical receipts are in `runtime.json.signed`.
The four impersonated donor transactions are separately labeled in
`runtime.json.donor`; they must never be counted as controlled signatures.

The helpers are disposable source witnesses, not Migration. Each concrete
helper hardcodes one fixed token; neither exposes an arbitrary target,
calldata, recipient, token setter or owner command. Their 874-byte deployed
runtimes match their isolated Solar artifacts after substituting only the
five compiler-declared 20-byte wallet immutable spans.

| Row | Helper custody | Acquired | Synthetic Q0 | Excluded unrelated floor | Synthetic C0 |
| --- | --- | ---: | ---: | ---: | ---: |
| E-P | `0xe65b75e7a8de220bcfec86f58c4c25a62ab7cd9b` | 10020 | 10007 | 13 | 1001 |
| W-P | `0x1fb0d426927dab092def63b73e1397b3f29e7b33` | 10030 | 10013 | 17 | 1001 |

The separately transferred floor is never booked or credited. For positive
q<=Q, this bounded witness delivers floor(C*q/Q), except terminal q==Q
delivers all remaining C; zero credit rejects. Q and C decrease only with
successful exact wallet debit/custody credit. These small synthetic values
do not establish general production full-precision arithmetic.

| Row | Finite partial q / c | Remaining Q / C | Maximum terminal q / c | Final booked / custody |
| --- | --- | --- | --- | --- |
| E-P | 4003 / 400 | 6004 / 601 | 6004 / 601 | 10007 / 10020 |
| W-P | 4007 / 400 | 6006 / 601 | 6006 / 601 | 10013 / 10030 |

Finite approvals 10007/10013 decrement to 6004/6006. Separate maximum approvals
are spent too: max becomes max-6004/max-6006 on terminal custody, not infinite
allowance semantics. Separate signed approval cleanup leaves both allowances 0.

Each newly acquired row also proves real signed missing-record, wrong-wallet,
missing-allowance and absent-balance failures. Signed transfer-away/back
tests absent control without changing Q/C. Zero-credit dust and consumed
denominator reject. The successful-inner-pull late transaction returns true
from the fixed token's transferFrom before helper LateFailure; status0,
before/after state and storage-diff traces prove rollback of wallet/custody,
allowance, Q/C and booked inventory. The preceding separate approval remains.

Q0 and C0 are disclosed synthetic constants only. They are not historical
original quantities, known ETH/DTF cost components, an approved frozen quote,
minted credit, operational compensation or a funded fresh90-day bond.

## 5. Remaining gates and preservation

All original-record requirements in `../source/contract.md` remain: actual
original wallet, fixed source/generation, evidence identity, wallet-independent
canonical origin, positive original Q0, separately known original ETH and
DTF components, and the immutable funded snapshot. Unknown is not zero.
Current holdings and these donations do not supply those inputs. Quote each
original once, not current share/LP NAV or merged nonlinear inputs.
Stage2-only surrender, actual Migration configuration and wallet gates,
cross-category duplicate exclusion, same-wallet exactly funded fresh90-day
issuance, atomic rollback, operator parity and integrated inventory protection
are unproved by these helpers. No production integration follows from this
proposal; root must read the qualified admission and independent verification.

All previous ordinary-caller and recovery failures remain valid: E-S and
W-SW disabled exits; E-P UnsupportedRoute/native NotOwner; W-P ordinary
NotOwner and ownerOnlyLiquidity=true. Owning the acquired LP grants no ED/WD
recovery authority. No W-SW replay or liquidation probe was performed.
Source recovery, operational datasets, opaque origins, archive qualifications,
host portability and target gas remain open. This helper does not address
the retained 44,653,392-gas parent versus 32,000,000 cap.

The complete 35-file original `source/`, `source-verification/` and
`holder-followup-root/` memberships and raw bytes are unchanged. The
worktree index hash, branch and HEAD are unchanged; tracked/staged diffs
are empty. Full source routing, owner bindings, bytecode and total supply
are preserved; only the specified authentic token transfer effects occur.
Checked unrelated inventories and helper floors are retained.

The owned Anvil session/PID 83130 was stopped, exit 0; no loopback18570
listener or owned PID remains. Both donor impersonation windows ended
explicitly, every receipt subscription closed, both monitors completed,
no persistent provider was created and no checkpoint exists. All probe
changes are stopped. `seal.json` binds final owned evidence except itself.
