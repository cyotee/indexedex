// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {
    RebasingAwareERC4626_Component_FactoryService
} from "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title SeMatrix_RebasingAwareFixture
 * @notice RebasingAwareERC4626 (custody wrapper) SE row fixture (open item 1 PRD §5, M6). Face
 *         token: the configured asset, an 18-decimal hermetic `ERC20PermitMintableStub` exactly as
 *         `TestBase_RebasingAwareERC4626` uses. The SE is deployed through the production
 *         RebasingAwareERC4626 package via the IndexedEx manager
 *         (`deployRebasingAwareERC4626DFPkg` then `pkg.deployVault(asset, offset, salt)`).
 *         SE share decimals = asset decimals + decimal offset (`RebasingAwareERC4626Common.liveBook`
 *         reads `_decimalOffset()`; the package mints the share token at `assetDecimals + offset`).
 * @dev No R14 leftover case: custody deposits either take the full amount or revert, so
 *      `hasPartialCase()` is false and the row runs the rounding-to-zero control (M7).
 *      The custody SE rejects asset pretransfer on `exchangeIn` / `exchangeOut`
 *      (`IRebasingAwareERC4626.AssetPretransferNotSupported`, `RebasingAwareStandardExchangeTarget`);
 *      the hook uses the pull route (`pretransferred = false`, the SE pulls from the hook with
 *      `safeTransferFrom`), so binding and every §6 row are unaffected. The package is shared across
 *      the legs of one hook: pass the previous fixture's `pkg()` to reuse it (zero deploys a fresh one).
 */
contract SeMatrix_RebasingAwareFixture is SeMatrixFixture {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    /// @dev Same offset `RebasingAwareERC4626DFPkg.deployVault(asset)` applies by default (MIN_OFFSET).
    uint8 public constant DECIMAL_OFFSET = 10;

    IRebasingAwareERC4626DFPkg public sePkg;
    ERC20PermitMintableStub public asset;
    address internal seVault;

    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        sePkg = existingPkg == address(0) ? _deployPkg(c) : IRebasingAwareERC4626DFPkg(existingPkg);
        asset = new ERC20PermitMintableStub("Matrix Rebasing Asset", "mRA", 18, address(this), 0);
        seVault = address(sePkg.deployVault(IERC20Metadata(address(asset)), DECIMAL_OFFSET, bytes32(0)));
    }

    function _deployPkg(Ctx memory c) private returns (IRebasingAwareERC4626DFPkg pkg_) {
        vm.startPrank(_factoryOwner());
        IRebasingAwareERC4626DFPkg.PkgInit memory init = IRebasingAwareERC4626DFPkg.PkgInit({
            erc20Facet: c.erc20Facet,
            rebasingAwareErc4626Facet: c.create3Factory.deployRebasingAwareERC4626Facet(),
            diamondFactory: c.create3Factory.diamondPackageFactory(),
            standardExchangeFacet: c.create3Factory.deployRebasingAwareStandardExchangeFacet(),
            standardYieldFacet: c.create3Factory.deployRebasingAwareStandardYieldFacet(),
            vaultMetadataFacet: c.create3Factory.deployRebasingAwareVaultMetadataFacet(),
            transitionQuoteFacet: c.create3Factory.deployRebasingAwareStandardExchangeQuoteFacet(),
            vaultRegistry: IVaultRegistryDeployment(address(c.indexedexManager))
        });
        vm.stopPrank();
        vm.prank(c.owner);
        pkg_ = RebasingAwareERC4626_Component_FactoryService.deployRebasingAwareERC4626DFPkg(c.indexedexManager, init);
    }

    /* ----------------------------- identity ------------------------------ */

    function familyName() external pure override returns (string memory) {
        return "RebasingAwareERC4626";
    }

    /// @notice Shared SE package (deployed once per hook, reused by later legs).
    function pkg() external view returns (address) {
        return address(sePkg);
    }

    function faceToken() public view override returns (address) {
        return address(asset);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    /// @notice Share decimals are asset decimals plus the configured offset (18 + 10 = 28).
    function seDecimals() public view override returns (uint8) {
        return asset.decimals() + DECIMAL_OFFSET;
    }

    /* ------------------------------ funding ------------------------------ */

    function fund(address to, uint256 amount) external override {
        asset.mint(to, amount);
    }

    /* -------------------------- R14 partial case -------------------------- */

    function hasPartialCase() external pure override returns (bool) {
        return false;
    }

    function limitCapacity(uint256) external pure override {
        revert("rebasing-aware: no partial case (custody takes all or reverts)");
    }

    function openCapacity() external override {}

    function seBooked() external view override returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(address(asset));
    }

    /* --------------------------- operative failure ------------------------ */

    /// @notice Reverts the custody pull with `rejectBytes()`. `RebasingAwareERC4626Common.pullAssets`
    ///         (the operative step of `executeDeposit` / `executeMint`) opens with
    ///         `asset.totalSupply()`; nothing on the hook side or in the SE previews reads it, so every
    ///         precheck and quote still passes and only the SE's own custody step fails.
    function armOperativeRevert() external override {
        vm.mockCallRevert(address(asset), abi.encodeWithSelector(IERC20.totalSupply.selector), rejectBytes());
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    /* ------------------------------- AMM ---------------------------------- */

    function isAmm() external pure override returns (bool) {
        return false;
    }
}
