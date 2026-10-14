# Remediation PRD — correct the Uniswap family README

- **Status:** DRAFT
- **Date:** 2026-10-11
- **ID:** REQ-C05
- **Severity:** Low
- **Review target:** Current IndexedEx working tree, inspected 2026-10-11.
- **Inputs:** `docs/reviews/apex-stage2-remediation-confirmation-2026-10-11/REMEDIATION_PRD.md` REQ-C05; `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` and `:56`.
- **Authorization:** Writing this PRD does not authorize editing code in this session. A later session must be explicitly asked to implement it.

## Required outcome

The Uniswap family README matches the current tree. It does not send a later editor to a deleted V3 package, and it does not describe internal-balance redemption as a proxy self-call.

This is a documentation repair. It does not change vault behavior.

## What the file says, and what the tree is

`contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` says the preserved implementations under `contracts/protocols/dexes/uniswap/v3` and `v4` remain unchanged, are not deprecated, and remain vulnerable to delivery accounting that treats `reserveOfToken` as free plus deployed assets.

That sentence was written when FullSpread sat beside those older packages. It is no longer true of V3.

- `contracts/protocols/dexes/uniswap/` contains `v2/` and `v4/`. There is no `v3/` directory.
- The supported V3 vault is Uniswap V3 FullSpread, under `contracts/vaults/standard/exchange/protocols/uniswap/v3/`.
- Legacy V4 under `contracts/protocols/dexes/uniswap/v4` was kept. It still uses the old stored-reserve-minus-live-deployed credit. The README must not describe that retained package as the deleted V3 tree, and it must not say the deleted V3 tree is still present.

Line 56 says internal-balance redemption uses a fixed proxy self-call with `pretransferred=false`. That mechanism is the one the explicit-holder repair forbids. The holder plan also edits this sentence. Both edits must say the same thing: the holder is an argument, and a call to `address(this)` is not the redemption path. If the holder repair has not landed yet, this README edit still must not describe the self-call as current behavior.

The last sentence of line 3 remains true and stays: changing source does not upgrade immutable instances already deployed.

## Required repair

Edit only the stale sentences in that README.

Line 3 must state:

- V3 FullSpread is the supported V3 vault.
- The old package under `contracts/protocols/dexes/uniswap/v3` was removed. It is not a current source tree.
- Legacy V4 under `contracts/protocols/dexes/uniswap/v4` was retained. If the warning about stored-reserve-minus-deployed credit remains, it names that retained V4 package only.
- Source removal is not an upgrade of instances already deployed.

Line 56 must state:

- Ordinary redemption burns the original caller's shares.
- Internal-balance redemption burns shares held by the vault. The holder is `address(this)`, passed to settlement.
- It does not call `address(this)` to make `msg.sender` the vault, and it does not set `pretransferred=true` to mean the shares were already moved.

Do not leave a nearby sentence in this file that still says the deleted V3 tree remains or that the self-call is the current path. Line 13 may keep the historical hash and source-map files as historical evidence. It must not be read as a claim that `contracts/protocols/dexes/uniswap/v3` still exists. If that line can be read that way, add that the maps are historical and the old V3 tree is absent.

## Acceptance criteria

- A reader of line 3 cannot conclude that `contracts/protocols/dexes/uniswap/v3` is still in the tree.
- A reader can tell V3 FullSpread from the retained legacy V4 package.
- Any vulnerability warning names the retained V4 package, not the deleted V3 tree.
- Line 56 does not describe a proxy self-call as the current internal-balance path.
- The rest of the README is not rewritten.
- No package is created or deleted to make the old sentences true.

## Non-goals

- Do not recreate `contracts/protocols/dexes/uniswap/v3`.
- Do not delete `contracts/protocols/dexes/uniswap/v4`.
- Do not change FullSpread or legacy V4 accounting in this item. The holder repair is a separate plan.
- Do not edit other documents that may still name the deleted package. They were not re-read for this item.
- Do not treat a historical test-count paragraph as a current execution claim, and do not rerun that gate to refresh it.
- Do not deploy or upgrade live instances.

## Verification

Implement only after a separate request. The check is a read of the edited README against the current `contracts/protocols/dexes/uniswap/` directory. No Forge run is required for this prose change. If the same session also edits production source, that is outside this item.
