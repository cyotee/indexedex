// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @title DETFProtocolCompoundLib
/// @notice Shared pure helpers for Phase 1 protocol seigniorage compound (Stage 00).
/// @dev Product law: `DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` Phase 1.
///
/// # Ownership
///
/// **Compound is DETF-orchestrated**, not bond-vault-orchestrated. Families implement
/// `_tryCompoundProtocolRewards` / public `compoundProtocolRewards` using this dust gate
/// plus existing harvest + single-sided DETF join + `addToDETFNFT` plumbing.
/// Bond NFT continues to expose free-DETF harvest (`reallocateDetfNftRewards`); it does
/// **not** call the DETF on every user `claimRewards` (avoids vault→DETF reentrancy).
///
/// # Normative call order (Stage 00 law for Stages 01–04)
///
/// ```text
/// 1. Update global bond rewards on the bond NFT vault
/// 2. Measure detf-owned NFT pending reward DETF (earned)
/// 3. If !isCompoundable(pending): return (no-op)
/// 4. Harvest detf-NFT rewards to the DETF diamond only as part of the successful compound path
/// 5. Single-sided DETF join into reservePool → BPT out
/// 6. Credit BPT to detf-owned NFT principal (addToDETFNFT / family equivalent)
/// ```
///
/// # Preferred atomicity
///
/// Preferred v1 **pull** pattern on public `compoundProtocolRewards` and lazy hooks:
/// measure pending → if compoundable, harvest + join + BPT credit in one atomic path.
/// Harvest only when join succeeds (or reverse harvest on join failure). Never wipe
/// reward debt without a successful join that credits BPT.
///
/// # Lazy hook vs standalone public compound
///
/// - `_tryCompoundProtocolRewards()` (internal): **best-effort** — swallows join failure
///   (or returns false / zeros); never corrupts debt; never fails the outer user path
///   solely because join reverts.
/// - `compoundProtocolRewards()` (external): may surface success via return values /
///   events (`ProtocolRewardsCompounded` / optional `ProtocolCompoundSkipped`); still must
///   not strand inconsistent debt. Prefer the same try semantics as the lazy hook.
///
/// # Scope locks
///
/// - Only **detf-owned NFT** rewards auto-compound (single-sided DETF self-leg join).
/// - User and fee-recipient NFT rewards stay claimable free DETF while locked — no auto-compound.
/// - No Balancer / diamond calls in this library (family-specific join lives in family Common).
/// - No natural supply expansion logic (Stages 05–09).
library DETFProtocolCompoundLib {
    /// @notice Default dust below which protocol compound is a no-op.
    /// @dev `1` wei DETF: pending at dust is not compoundable; dust+1 is.
    ///      Families may use a larger local dust if join dust forces it; this constant is
    ///      the Stage 00 / shared default documented by unit tests.
    uint256 internal constant DEFAULT_COMPOUND_DUST = 1;

    /// @notice True when `pending_` is strictly above the default compound dust.
    /// @dev `isCompoundable(0) == false`, `isCompoundable(DEFAULT_COMPOUND_DUST) == false`,
    ///      `isCompoundable(DEFAULT_COMPOUND_DUST + 1) == true`.
    /// @param pending_ Detf-owned NFT pending reward DETF amount (wei).
    /// @return True if a compound attempt should proceed past the dust gate.
    function isCompoundable(uint256 pending_) internal pure returns (bool) {
        return pending_ > DEFAULT_COMPOUND_DUST;
    }

    /// @notice True when `pending_` is strictly above `dust_`.
    /// @dev Family override path when join dust requires a threshold other than
    ///      `DEFAULT_COMPOUND_DUST`. Same strict-greater semantics as `isCompoundable`.
    /// @param pending_ Detf-owned NFT pending reward DETF amount (wei).
    /// @param dust_ Family- or call-site dust threshold (wei).
    /// @return True if a compound attempt should proceed past the dust gate.
    function isCompoundable(uint256 pending_, uint256 dust_) internal pure returns (bool) {
        return pending_ > dust_;
    }
}
