// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from
    "test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from
    "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as Package} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as Weighted} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {UniswapV4StandardExchangeWeightedBufferHookTestDeployLib as Deploy} from
    "./UniswapV4StandardExchangeWeightedBufferHookTestDeployLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg as WingsPackage} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol";

/// @notice Exhaustive 24 n=2 homogeneous/raw assignment cells for this local, empty-core join/exit state.
/// @dev Explicitly not exhaustive for larger arities, economic states, heterogeneous families or DETF routes.
contract UniswapV4StandardExchangeWeightedBufferHook_WingsRecurrence is Fixture {
    HookFactory internal consumerFactory;
    Package internal consumerPackage;
    IPoolManager internal otherManager;
    WingsPackage internal otherWingsPackage;

    function setUp() public override {
        super.setUp();
        IFacet[] memory facets = _facets();
        (consumerFactory, consumerPackage) = Deploy.deployFactoryAndPackage(
            create3Factory, owner, address(indexedexManager), facets[0], facets[1], facets[2],
            facets[3], facets[4], multiStepOwnableFacet
        );
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(consumerFactory));
        otherManager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)), keccak256("Recurrence.Wings.OtherManager")
        ));
        WingsPackage.PkgInit memory init = WingsPackage.PkgInit(
            facets, otherManager, indexedexManager, indexedexManager, IPermit2(deployPermit2())
        );
        bytes memory creationCode = ArtifactCreationCode.creationCode(create3Factory,
            "UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol:UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg");
        vm.prank(owner);
        otherWingsPackage = WingsPackage(indexedexManager.deployPkg(
            creationCode, abi.encode(init), keccak256("Recurrence.Wings.OtherPackage")
        ));
    }

    function test_recurrence_WingsWeightedN2EveryOrderedTargetManagerAssignment() public {
        for (uint256 encoded = 1; encoded < 25; ++encoded) {
            uint256 snapshot = vm.snapshotState();
            uint8[] memory choices = new uint8[](2);
            choices[0] = uint8(encoded % 5);
            choices[1] = uint8(encoded / 5);
            _roundTrip(choices);
            assertTrue(vm.revertToState(snapshot));
        }
    }

    function test_recurrence_WingsWeightedEightBufferedMixedTargetsAndManagers() public {
        uint8[] memory choices = new uint8[](8);
        for (uint256 i; i < 8; ++i) choices[i] = uint8(1 + i % 4);
        _roundTrip(choices);
    }

    function _orderedTokens(uint256 n) private returns (address[] memory tokens) {
        tokens = new address[](2 * n);
        for (uint256 i; i < tokens.length; ++i) {
            tokens[i] = address(new ERC20PermitMintableStub(
                "Recurrence face", "FACE", i % 2 == 0 ? 6 : 18, address(this), 1e25
            ));
        }
        for (uint256 i; i < tokens.length; ++i) for (uint256 j = i + 1; j < tokens.length; ++j) {
            if (tokens[j] < tokens[i]) (tokens[i], tokens[j]) = (tokens[j], tokens[i]);
        }
    }

    // Sort all 2n tokens before assigning adjacent pairs. Either target of pair i
    // then precedes either target of pair i+1, preserving the enumerated ordered assignment.
    function _bindLeg(address first, address second, uint8 choice) private returns (address face, address vault) {
        if (choice == 0) return (first, address(0));
        bool different = choice >= 3;
        face = choice == 1 || choice == 3 ? first : second;
        PoolKey memory market = PoolKey(Currency.wrap(first), Currency.wrap(second), 3000, 60, IHooks(address(0)));
        IPoolManager manager = different ? otherManager : pool;
        manager.initialize(market, uint160(1) << 96);
        WingsPackage pkg = different ? otherWingsPackage : wingsPackage;
        vault = pkg.deployVault(WingsPackage.PkgArgs(market, face));
    }

    function _consumer(uint8[] memory choices) private returns (Weighted, address[] memory) {
        uint256 n = choices.length;
        address[] memory pairs = _orderedTokens(n);
        Package.PkgArgs memory args;
        args.poolManager = address(pool);
        args.feeOracle = address(indexedexManager);
        args.n = uint8(n);
        args.tokens = new address[](n);
        args.standardExchanges = new address[](n);
        args.rateProviders = new address[](n);
        args.weights = new uint256[](n);
        uint256 assigned;
        for (uint256 i; i < n; ++i) {
            (args.tokens[i], args.standardExchanges[i]) = _bindLeg(pairs[2 * i], pairs[2 * i + 1], choices[i]);
            args.rateProviders[i] = args.standardExchanges[i];
            args.weights[i] = i + 1 == n ? 1e18 - assigned : (i + 1) * 1e18 / (n * (n + 1) / 2);
            assigned += args.weights[i];
        }
        args.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(args.tokens);
        args.seDecimals = HookPkgArgsDecimalsLib.seDecimals(args.standardExchanges);
        args.ownerOnlyLiquidity = true;
        args.owner = address(this);
        address deployed = Deploy.deployHookInstance(consumerFactory, consumerPackage, args);
        for (uint256 i; i < n; ++i) for (uint256 j = i + 1; j < n; ++j) {
            IUniswapV4HookStagedPairInit(deployed).deployPair(args.tokens[i], args.tokens[j]);
        }
        assertTrue(IUniswapV4HookStagedPairInit(deployed).finalizeInitialization());
        for (uint256 i; i < n; ++i) IERC20(args.tokens[i]).approve(deployed, type(uint256).max);
        return (Weighted(deployed), args.tokens);
    }

    function _roundTrip(uint8[] memory choices) private {
        (Weighted consumer, address[] memory faces) = _consumer(choices);
        uint256[] memory amounts = new uint256[](faces.length);
        uint256[] memory balances = new uint256[](faces.length);
        for (uint256 i; i < faces.length; ++i) {
            amounts[i] = 100 * 10 ** IERC20Metadata(faces[i]).decimals();
            balances[i] = IERC20(faces[i]).balanceOf(address(this));
        }
        (uint256 expected, uint256[] memory quotedUsed) = consumer.previewJoinProportional(amounts);
        (uint256 minted, uint256[] memory used) = consumer.joinProportional(amounts, address(this), expected, block.timestamp);
        assertGt(minted, 0);
        assertEq(minted, expected);
        assertEq(used, quotedUsed);
        for (uint256 i; i < faces.length; ++i) {
            assertEq(balances[i] - IERC20(faces[i]).balanceOf(address(this)), used[i]);
        }
        uint256 burn = minted / 5;
        uint256[] memory expectedOut = consumer.previewExitProportional(burn);
        for (uint256 i; i < faces.length; ++i) balances[i] = IERC20(faces[i]).balanceOf(address(this));
        uint256[] memory paid = consumer.exitProportional(burn, address(this), expectedOut, block.timestamp);
        assertEq(paid, expectedOut);
        for (uint256 i; i < faces.length; ++i) {
            assertEq(IERC20(faces[i]).balanceOf(address(this)) - balances[i], paid[i]);
        }
        assertEq(IERC20(address(consumer)).balanceOf(address(this)), minted - burn);
    }
}
