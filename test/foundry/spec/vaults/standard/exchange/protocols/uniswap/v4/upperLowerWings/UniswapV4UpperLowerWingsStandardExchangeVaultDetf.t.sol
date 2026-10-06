// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {TestBase_UniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg as WingsPkg} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultComponent_FactoryService as Components} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultComponent_FactoryService.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor as Actor} from "./reference/UniswapV4UpperLowerWingsStandardExchangeVaultPoolActor.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";

/// @notice Funded V4 DETF whose reserve Standard Exchange is a Wings vault, not FullSpread.
contract UniswapV4UpperLowerWingsStandardExchangeVaultDetfTest is TestBase_UniswapV4Detf {
    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);
        _bindWings();
        _deployHookFactoryAndPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        detf = _deployHookThenDetf(_defaultDetfArgs());
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        pairToken.mint(detfUser, 1_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        IERC20(se).approve(detf, type(uint256).max);
        vm.stopPrank();
    }

    function test_fundedDetfBondsAgainstWingsReserve() public {
        uint256 before = pairToken.balanceOf(detfUser);
        (uint256 tokenId, uint256 shares) = _firstBond(1_000 ether);
        assertGt(shares, 0, "funded bond acquired protocol LP");
        assertLt(pairToken.balanceOf(detfUser), before, "bond spent the Wings face token");
        assertEq(detfInfo.hook(), reserveHook);
        tokenId;
    }

    function _bindWings() private {
        pairToken = new SimpleMintableERC20("Wings face", "FACE");
        SimpleMintableERC20 other = new SimpleMintableERC20("Wings other", "OTHR");
        address first = address(pairToken) < address(other) ? address(pairToken) : address(other);
        address second = first == address(pairToken) ? address(other) : address(pairToken);
        pm = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)), keccak256("Wings.DetfPoolManager")));
        PoolKey memory key = PoolKey(Currency.wrap(first), Currency.wrap(second), 3000, 60, IHooks(address(0)));
        pm.initialize(key, uint160(1) << 96);
        IFacet[] memory facets = new IFacet[](13);
        facets[0] = erc20Facet; facets[1] = erc5267Facet; facets[2] = erc2612Facet;
        facets[3] = multiAssetBasicVaultFacet; facets[4] = multiAssetStandardVaultFacet;
        facets[5] = Components.deployQueryFacet(create3Factory);
        facets[6] = Components.deployExecutionDelegate(create3Factory);
        facets[7] = Components.deployInFacet(create3Factory);
        facets[8] = Components.deployOutFacet(create3Factory);
        facets[9] = Components.deploySYFacet(create3Factory);
        facets[10] = Components.deployRebalanceFacet(create3Factory);
        facets[11] = Components.deployTransitionFacet(create3Factory);
        facets[12] = Components.deployEconomicFacet(create3Factory);
        vm.prank(owner);
        WingsPkg pkg = WingsPkg(indexedexManager.deployPkg(
            ArtifactCreationCode.creationCode(create3Factory, "UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol:UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg"),
            abi.encode(WingsPkg.PkgInit(facets, pm, indexedexManager, indexedexManager, permit2)),
            keccak256("Wings.DetfPackage")));
        se = pkg.deployVault(WingsPkg.PkgArgs(key, address(pairToken)));
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(0.2e18);
        Actor lp = Actor(create3Factory.create3WithArgs(type(Actor).creationCode, abi.encode(pm, address(this)), keccak256("Wings.DetfLp")));
        pairToken.mint(address(this), 1e24); other.mint(address(this), 1e24);
        pairToken.mint(address(lp), 1e24); other.mint(address(lp), 1e24);
        pairToken.approve(se, type(uint256).max);
        lp.modify(key, -887220, 887220, 1e18, bytes32(0));
        IStandardExchangeIn(se).exchangeIn(pairToken, 1_000 ether, IERC20(se), 0, address(this), false, block.timestamp);
        Rebalance(se).rebalance(0, block.timestamp);
    }
}
