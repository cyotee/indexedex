# Implementation plan — correct the Uniswap family README

- **Date:** 2026-10-11
- **Status:** ready for a separately authorized implementation session
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan and an earlier sentence conflict, the PRD controls.
- **This plan does not authorize edits.** A later session must be explicitly asked to implement it.

## What this item is

Edit prose in `contracts/vaults/standard/exchange/protocols/uniswap/README.md`. Do not change vault source. Do not create or delete a package.

## Step 1 — Replace line 3

The current sentence says the implementations under `contracts/protocols/dexes/uniswap/v3` and `v4` remain and are still vulnerable. That directory has `v2/` and `v4/` only.

The replacement must say:

- V3 FullSpread is the supported V3 vault. Its source is `contracts/vaults/standard/exchange/protocols/uniswap/v3/`.
- The old package under `contracts/protocols/dexes/uniswap/v3` was removed.
- Legacy V4 under `contracts/protocols/dexes/uniswap/v4` was retained. If the stored-reserve-minus-deployed warning stays, it names that retained package only.
- Removing source does not upgrade instances already deployed.

Do not say the deleted V3 tree remains, and do not call the retained V4 package the old V3 tree.

## Step 2 — Replace line 56

The current sentence says internal-balance redemption uses a proxy self-call. Remove that description.

The replacement must say:

- Ordinary redemption burns the original caller's shares.
- Internal-balance redemption burns shares held by the vault. The holder is `address(this)`, passed to settlement.
- Redemption does not call `address(this)` to change `msg.sender`, and it does not set `pretransferred=true` to mean the shares were already moved.

The explicit-holder plan also edits this sentence. The two edits must agree. Do not restore the self-call sentence if that plan lands first, and do not leave the self-call sentence if this plan lands first.

## Step 3 — Check the neighboring sentences

Read the rest of this file only. If line 13 can be read as a claim that `contracts/protocols/dexes/uniswap/v3` still exists, add that the source maps and hashes are historical and that the old V3 tree is absent. Do not delete those evidence files.

Do not rewrite the delivery, activation, or validation sections. Do not refresh the historical test-count paragraph by rerunning a gate.

## Step 4 — Check the tree, then stop

Confirm `contracts/protocols/dexes/uniswap/` still has no `v3/` directory and still has `v4/`. The README must match that. No Forge run is required. If the session also edits production source, that work is outside this item.

## Out of scope

- Recreating `contracts/protocols/dexes/uniswap/v3`.
- Deleting `contracts/protocols/dexes/uniswap/v4`.
- FullSpread or legacy V4 accounting.
- Other documents that still name the deleted package.
- Deployment or a live-instance upgrade.

## Done when

- Line 3 names V3 FullSpread as the supported V3 vault and says the old V3 package path is gone.
- Any vulnerability warning names retained legacy V4 only.
- Line 56 does not describe a proxy self-call as the current path.
- No package was created or deleted.

Stop after that edit. Do not deploy.
