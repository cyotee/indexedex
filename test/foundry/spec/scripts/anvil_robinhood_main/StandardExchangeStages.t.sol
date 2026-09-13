// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {Phase_06_Stage_10_RebasingAwareERC4626Pkg as RebasingStage} from "scripts/foundry/anvil_robinhood_main/Phase_06_Stage_10_RebasingAwareERC4626Pkg.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV2Factory} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {IUniswapV2StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v2/IUniswapV2StandardExchangeDFPkg.sol";
import {IUniswapV3StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v3/IUniswapV3StandardExchangeDFPkg.sol";
import {LaunchState} from "scripts/foundry/anvil_robinhood_main/LaunchState.sol";
import {RobinhoodCanonicalLib} from "scripts/foundry/anvil_robinhood_main/RobinhoodCanonicalLib.sol";
import {Phase_05_Stage_04_UniswapV3StandardExchangePkg as V3Stage} from "scripts/foundry/anvil_robinhood_main/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol";
import {Phase_05_Stage_06_UniswapV2StandardExchangePkg as V2Stage} from "scripts/foundry/anvil_robinhood_main/Phase_05_Stage_06_UniswapV2StandardExchangePkg.sol";

import {IVaultRegistryVaultPackageQuery} from "contracts/interfaces/IVaultRegistryVaultPackageQuery.sol";
import {Phase_06_Stage_05_OrbitalBufferHookPkg as OrbitalStage} from "scripts/foundry/anvil_robinhood_main/Phase_06_Stage_05_OrbitalBufferHookPkg.sol";

contract StandardExchangeStages is TestBase_VaultComponents {
    LaunchState internal state;

    function setUp() public override {
        super.setUp();
        IOperable(address(create3Factory)).setOperator(owner, true);
        state.create3Factory = create3Factory;
        state.diamondPackageFactory = diamondPackageFactory;
        state.indexedexManager = indexedexManager;
        state.erc20Facet = erc20Facet;
        state.erc5267Facet = erc5267Facet;
        state.erc2612Facet = erc2612Facet;
        state.erc4626Facet = erc4626Facet;
        state.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        state.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        state.multiStepOwnableFacet = multiStepOwnableFacet;
        // Real external protocol implementations at the stage's canonical pins.
        deployCodeTo("UniV2Factory.sol:UniV2Factory", abi.encode(address(this)), RobinhoodCanonicalLib.v2Factory());
        deployCodeTo("UniV2Router02.sol:UniV2Router02", abi.encode(RobinhoodCanonicalLib.v2Factory(), RobinhoodCanonicalLib.weth()), RobinhoodCanonicalLib.v2Router());
        deployCodeTo("UniswapV3Factory.sol:UniswapV3Factory", RobinhoodCanonicalLib.v3Factory());
    }

    function test_v2Stage_replayAndRegisteredVaultDeposit() public {
        vm.startPrank(owner);
        V2Stage.execute(state);
        vm.stopPrank();
        address package_ = state.uniV2SePkg;
        bytes32 config_ = keccak256(abi.encode(IDiamondFactoryPackage(package_).diamondConfig()));
        vm.startPrank(owner);
        V2Stage.execute(state);
        vm.stopPrank();
        assertEq(state.uniV2SePkg, package_);
        assertEq(keccak256(abi.encode(IDiamondFactoryPackage(package_).diamondConfig())), config_);
        (SimpleMintableERC20 a, SimpleMintableERC20 b) = _assets();
        IUniswapV2Pair pair = IUniswapV2Pair(IUniswapV2Factory(RobinhoodCanonicalLib.v2Factory()).createPair(address(a), address(b)));
        a.mint(address(pair), 100 ether);
        b.mint(address(pair), 100 ether);
        uint256 lp = pair.mint(address(this));
        address vault = IUniswapV2StandardExchangeDFPkg(package_).deployVault(pair);
        _assertDeposit(vault, IERC20(address(pair)), lp);
    }

    function test_v3Stage_replayAndRegisteredVaultDeposit() public {
        vm.startPrank(owner);
        V3Stage.execute(state);
        vm.stopPrank();
        address package_ = state.uniV3SePkg;
        bytes32 config_ = keccak256(abi.encode(IDiamondFactoryPackage(package_).diamondConfig()));
        vm.startPrank(owner);
        V3Stage.execute(state);
        vm.stopPrank();
        assertEq(state.uniV3SePkg, package_);
        assertEq(keccak256(abi.encode(IDiamondFactoryPackage(package_).diamondConfig())), config_);
        (SimpleMintableERC20 a, SimpleMintableERC20 b) = _assets();
        IUniswapV3Pool pool = IUniswapV3Pool(IUniswapV3Factory(RobinhoodCanonicalLib.v3Factory()).createPool(address(a), address(b), 3000));
        pool.initialize(uint160(1 << 96));
        address vault = IUniswapV3StandardExchangeDFPkg(package_).deployVault(pool);
        address[] memory tokens = new address[](2);
        tokens[0] = pool.token0(); tokens[1] = pool.token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether; amounts[1] = 100 ether;
        a.mint(address(this), 110 ether); b.mint(address(this), 100 ether);
        a.approve(vault, 100 ether); b.approve(vault, 100 ether);
        IStandardExchangeInMulti(vault).exchangeInManyToOne(tokens, amounts, IERC20(vault), 1, address(this), false, block.timestamp);
        _assertDeposit(vault, IERC20(address(a)), 10 ether);
    }

    function test_orbitalStage_replayRegisteredPackageAndDeployableFacets() public {
        vm.startPrank(owner);
        OrbitalStage.execute(state);
        vm.stopPrank();
        address package_ = state.orbitalHookPkg;
        assertTrue(IVaultRegistryVaultPackageQuery(address(indexedexManager)).isPackage(package_));
        assertGt(package_.code.length, 0);
        assertLe(package_.code.length, 24_576);
        IDiamondFactoryPackage.DiamondConfig memory config_ = IDiamondFactoryPackage(package_).diamondConfig();
        assertGt(config_.facetCuts.length, 0);
        for (uint256 i; i < config_.facetCuts.length; ++i) {
            address facet_ = config_.facetCuts[i].facetAddress;
            assertGt(facet_.code.length, 0);
            assertLe(facet_.code.length, 24_576);
            assertGt(config_.facetCuts[i].functionSelectors.length, 0);
        }
        vm.startPrank(owner);
        OrbitalStage.execute(state);
        vm.stopPrank();
        assertEq(state.orbitalHookPkg, package_);
        assertEq(keccak256(abi.encode(IDiamondFactoryPackage(package_).diamondConfig())), keccak256(abi.encode(config_)));
    }

    /// @notice The default wrapper stage is repeatable and creates a usable package without TokenStaking.
    function test_rebasingStage_replayAndVaultRoundTrip() public {
        vm.startPrank(owner);
        RebasingStage.execute(state);
        address package_ = state.rebasingAwareErc4626Pkg;
        address facet_ = address(state.rebasingAwareErc4626Facet);
        RebasingStage.execute(state);
        vm.stopPrank();
        assertEq(state.rebasingAwareErc4626Pkg, package_);
        assertEq(address(state.rebasingAwareErc4626Facet), facet_);
        assertGt(package_.code.length, 0);
        assertGt(facet_.code.length, 0);
        assertEq(state.tokenStakingPkg, address(0));
        assertEq(address(state.tokenStakingFacet), address(0));

        (SimpleMintableERC20 asset,) = _assets();
        IERC4626 vault = IRebasingAwareERC4626DFPkg(package_).deployVault(IERC20Metadata(address(asset)));
        assertEq(IERC20Metadata(address(vault)).name(), "Wrapped Stage asset A");
        assertEq(IERC20Metadata(address(vault)).symbol(), "wA");
        asset.mint(address(this), 100 ether);
        asset.approve(address(vault), 100 ether);
        uint256 shares = vault.deposit(100 ether, address(this));
        asset.mint(address(vault), 50 ether);
        assertEq(vault.totalAssets(), 150 ether);
        assertApproxEqAbs(vault.redeem(shares, address(this), address(this)), 150 ether, 2);
    }

    function _assets() private returns (SimpleMintableERC20 a, SimpleMintableERC20 b) {
        a = new SimpleMintableERC20("Stage asset A", "A");
        b = new SimpleMintableERC20("Stage asset B", "B");
    }

    function _assertDeposit(address vault, IERC20 asset, uint256 amount) private {
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(vault));
        asset.approve(vault, amount);
        uint256 quoted = IStandardExchangeIn(vault).previewExchangeIn(asset, amount, IERC20(vault));
        assertGt(quoted, 0);
        uint256 heldBefore = IERC20(vault).balanceOf(address(this));
        uint256 received = IStandardExchangeIn(vault).exchangeIn(asset, amount, IERC20(vault), quoted, address(this), false, block.timestamp);
        assertEq(received, quoted);
        assertEq(IERC20(vault).balanceOf(address(this)) - heldBefore, received);
    }
}
