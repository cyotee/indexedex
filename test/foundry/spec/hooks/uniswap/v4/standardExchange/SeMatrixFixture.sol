// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

/**
 * @title SeMatrixFixture
 * @notice One Standard Exchange (SE) family adapter for the D20 / R10.3 hook × SE matrix (open
 *         item 1 PRD, M6). A concrete fixture deploys the SE through its real package or CREATE3
 *         path on its own protocol fixture and exposes the face token the hook leg is bound to.
 * @dev Deployed with `new` from the test contract, so cheatcodes are allowed here. Every method
 *      that changes the SE's dependency state (capacity, operative failure) acts on the protocol
 *      fixture or a non-SUT stub, never on the SE, the hook, a package or the registry.
 */
abstract contract SeMatrixFixture {
    Vm internal constant vm = Vm(VM_ADDRESS);

    /// @dev Shared IndexedEx handles from the hook TestBase (the SeMatrix_<Family>Deploy.sol Ctx).
    struct Ctx {
        ICreate3FactoryProxy create3Factory;
        IIndexedexManagerProxy indexedexManager;
        address owner;
        IPermit2 permit2;
        IFacet erc20Facet;
        IFacet erc2612Facet;
        IFacet erc5267Facet;
        IFacet erc4626Facet;
        IFacet erc4626StandardVaultFacet;
        IFacet multiAssetBasicVaultFacet;
        IFacet multiAssetStandardVaultFacet;
    }

    /// @dev Non-SUT dependency failure payload used by `armOperativeRevert` implementations.
    error DependencyRejected(bytes32 tag);

    Ctx internal ctx;

    constructor(Ctx memory c) {
        ctx = c;
    }

    /// @dev The CREATE3 factory's facet deploy helpers are owner/operator gated; the test contract
    ///      owns the factory, so fixtures prank it around facet deployments.
    function _factoryOwner() internal view returns (address) {
        return IMultiStepOwnable(address(ctx.create3Factory)).owner();
    }

    function rejectBytes() public pure returns (bytes memory) {
        return abi.encodeWithSelector(DependencyRejected.selector, keccak256("APEX-SE-MATRIX"));
    }

    /* ----------------------------- identity ------------------------------ */

    function familyName() external pure virtual returns (string memory);

    /// @notice Face token the hook leg is bound to; the SE accepts it as `tokenIn` with `tokenOut == se()`.
    function faceToken() public view virtual returns (address);

    /// @notice The SE diamond (also the share token every hook binds).
    function se() public view virtual returns (address);

    function faceDecimals() public view virtual returns (uint8) {
        return IERC20Metadata(faceToken()).decimals();
    }

    function seDecimals() public view virtual returns (uint8) {
        return IERC20Metadata(se()).decimals();
    }

    /* ------------------------------ funding ------------------------------ */

    /// @notice Whole face units the single-CP row seeds the hook with; Balancer pool SEs keep the
    ///         hook's claim well under the pool's minimum invariant ratio (0.7) by seeding less.
    function seedFaceUnits() external pure virtual returns (uint256) {
        return 100;
    }

    /// @notice Give `to` `amount` raw face-token units.
    function fund(address to, uint256 amount) external virtual;

    /* -------------------------- R14 partial case -------------------------- */

    /// @notice True when the family has a partial-consumption case (a capacity gate that books the
    ///         remainder on the SE); false means the row runs the rounding-to-zero control instead.
    function hasPartialCase() external pure virtual returns (bool);

    /// @notice Leave exactly `allowFace` raw face units of investable capacity on the SE's dependency.
    ///         Later input above that is booked on the SE (D22 / D31), not refunded.
    function limitCapacity(uint256 allowFace) external virtual;

    /// @notice Remove the capacity limit so the next investing operation sweeps the booked remainder.
    function openCapacity() external virtual;

    /// @notice Face units the SE holds booked (not invested) right now.
    function seBooked() external view virtual returns (uint256);

    /// @notice True when a later investing operation sweeps the booked remainder (D31). False for
    ///         families whose face input is a permanent sleeve credit on the buffering route
    ///         (Lido: WETH→SE credits `liquidReserveEth`; only `rebalance` / `exchangeInEth` stake).
    function sweepsOnNextInvest() external pure virtual returns (bool) {
        return true;
    }

    /// @notice True when the hook's buffering route reaches an operative dependency call that
    ///         `armOperativeRevert` can make fail. False when the route only books locally (Lido).
    function operativeRevertReachable() external pure virtual returns (bool) {
        return true;
    }

    /* --------------------------- operative failure ------------------------ */

    /// @notice Make the SE's operative investment call revert with `rejectBytes()` while every
    ///         precheck still passes, so the hook operation must revert with those bytes.
    function armOperativeRevert() external virtual;

    function disarmOperativeRevert() external virtual;

    /* ------------------------------- AMM ---------------------------------- */

    /// @notice AMM families reserve unpaired leftover on the SE (D33) and expose the pair's other token.
    function isAmm() external pure virtual returns (bool);

    function otherToken() external view virtual returns (address) {
        return address(0);
    }

    function fundOther(address, uint256) external virtual {}
}
