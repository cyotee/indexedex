// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IMorpho, MarketParams} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {Morpho} from "@crane/contracts/external/morpho/blue/Morpho.sol";
import {OracleMock} from "@crane/contracts/external/morpho/blue/mocks/OracleMock.sol";
import {AdaptiveCurveIrm} from "@crane/contracts/external/morpho/blue-irm/AdaptiveCurveIrm.sol";
import {ORACLE_PRICE_SCALE} from "@crane/contracts/external/morpho/blue/libraries/ConstantsLib.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IMorphoBlueStandardExchangeDFPkg
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/IMorphoBlueStandardExchangeDFPkg.sol";
import {
    MorphoBlue_Component_FactoryService
} from "contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlue_Component_FactoryService.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title SeMatrix_MorphoFixture
 * @notice Morpho Blue SE row fixture (open item 1 PRD §5, M6). Face token: the 18-decimal loan token
 *         of a hermetic Morpho Blue market created by this fixture (`TestBase_MorphoBlue` pattern:
 *         `new Morpho(owner)`, `AdaptiveCurveIrm`, `OracleMock` at `ORACLE_PRICE_SCALE`, `enableIrm`,
 *         `enableLltv`, `createMarket`) and seeded with a direct supply so the SE quotes on a live
 *         market. The SE is deployed through the production Morpho Blue SE package via the IndexedEx
 *         manager (`deployMorphoBlueStandardExchangeDFPkg` then `pkg.deployVault`).
 * @dev No R14 leftover case: the SE hard-supplies every measured inbound (`_supplyInBound`, no
 *      try/catch), so `hasPartialCase()` is false and the row runs the rounding-to-zero control (M7).
 *      The package and the hermetic Morpho singleton are shared across the legs of one hook: pass
 *      the previous fixture's `pkg()` / `morpho()` to reuse them (zero deploys fresh ones). Each leg
 *      still gets its own loan token, collateral token, oracle, IRM and market.
 */
contract SeMatrix_MorphoFixture is SeMatrixFixture {
    using MorphoBlue_Component_FactoryService for ICreate3FactoryProxy;

    uint256 internal constant DEFAULT_LLTV = 0.8e18;
    /// @dev Direct market seed supplied by the fixture (not through the SE) so quotes run on a live market.
    uint256 internal constant MARKET_SEED = 1_000e18;

    IMorphoBlueStandardExchangeDFPkg public sePkg;
    IMorpho public morpho;
    AdaptiveCurveIrm public irm;
    OracleMock public oracle;
    MintableERC20Decimals public loanToken;
    MintableERC20Decimals public collateralToken;
    MarketParams internal marketParams;
    address internal seVault;

    constructor(Ctx memory c, address existingPkg, address existingMorpho) SeMatrixFixture(c) {
        morpho = existingMorpho == address(0) ? IMorpho(address(new Morpho(c.owner))) : IMorpho(existingMorpho);
        sePkg = existingPkg == address(0) ? _deployPkg(c) : IMorphoBlueStandardExchangeDFPkg(existingPkg);

        irm = new AdaptiveCurveIrm(address(morpho));
        oracle = new OracleMock();
        oracle.setPrice(ORACLE_PRICE_SCALE);
        loanToken = new MintableERC20Decimals("Matrix Morpho Loan", "mLOAN", 18);
        collateralToken = new MintableERC20Decimals("Matrix Morpho Collateral", "mCOLL", 18);

        vm.startPrank(c.owner);
        morpho.enableIrm(address(irm));
        if (!morpho.isLltvEnabled(DEFAULT_LLTV)) morpho.enableLltv(DEFAULT_LLTV);
        vm.stopPrank();

        marketParams = MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(collateralToken),
            oracle: address(oracle),
            irm: address(irm),
            lltv: DEFAULT_LLTV
        });
        morpho.createMarket(marketParams);
        _seedMarket();

        vm.prank(c.owner);
        seVault = sePkg.deployVault(IMorphoBlueStandardExchangeDFPkg.PkgArgs({morpho: morpho, marketParams: marketParams}));
    }

    function _deployPkg(Ctx memory c) private returns (IMorphoBlueStandardExchangeDFPkg pkg_) {
        IMorphoBlueStandardExchangeDFPkg.PkgInit memory init;
        init.erc20Facet = c.erc20Facet;
        init.erc5267Facet = c.erc5267Facet;
        init.erc2612Facet = c.erc2612Facet;
        vm.startPrank(_factoryOwner());
        init.morphoBlueErc4626Facet = c.create3Factory.deployMorphoBlueERC4626Facet();
        init.multiAssetBasicVaultFacet = c.multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = c.multiAssetStandardVaultFacet;
        init.exchangeInFacet = c.create3Factory.deployMorphoBlueStandardExchangeInFacet();
        init.exchangeOutFacet = c.create3Factory.deployMorphoBlueStandardExchangeOutFacet();
        init.markerFacet = c.create3Factory.deployMorphoBlueStandardExchangeMarkerFacet();
        vm.stopPrank();
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(c.indexedexManager));
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(c.indexedexManager));
        init.permit2 = c.permit2;
        vm.prank(c.owner);
        pkg_ = MorphoBlue_Component_FactoryService.deployMorphoBlueStandardExchangeDFPkg(c.indexedexManager, init);
    }

    /// @dev Live-market seed: the fixture supplies loan tokens straight to Morpho on its own behalf.
    function _seedMarket() private {
        loanToken.mint(address(this), MARKET_SEED);
        loanToken.approve(address(morpho), MARKET_SEED);
        morpho.supply(marketParams, MARKET_SEED, 0, address(this), "");
    }

    /* ----------------------------- identity ------------------------------ */

    function familyName() external pure override returns (string memory) {
        return "MorphoBlueStandardExchange";
    }

    /// @notice Shared SE package (deployed once per hook, reused by later legs).
    function pkg() external view returns (address) {
        return address(sePkg);
    }

    function market() external view returns (MarketParams memory) {
        return marketParams;
    }

    function faceToken() public view override returns (address) {
        return address(loanToken);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    /* ------------------------------ funding ------------------------------ */

    function fund(address to, uint256 amount) external override {
        loanToken.mint(to, amount);
    }

    /* -------------------------- R14 partial case -------------------------- */

    function hasPartialCase() external pure override returns (bool) {
        return false;
    }

    function limitCapacity(uint256) external pure override {
        revert("morpho: no partial case (hard supply, zero leftover)");
    }

    function openCapacity() external override {}

    function seBooked() external view override returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(address(loanToken));
    }

    /* --------------------------- operative failure ------------------------ */

    /// @notice Reverts the hermetic Morpho `supply` (the SE's operative call in `_supplyInBound`)
    ///         with `rejectBytes()`; previews and every SE precheck still pass.
    function armOperativeRevert() external override {
        vm.mockCallRevert(address(morpho), abi.encodeWithSelector(bytes4(keccak256("supply((address,address,address,address,uint256),uint256,uint256,address,bytes)"))), rejectBytes());
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    /* ------------------------------- AMM ---------------------------------- */

    function isAmm() external pure override returns (bool) {
        return false;
    }
}
