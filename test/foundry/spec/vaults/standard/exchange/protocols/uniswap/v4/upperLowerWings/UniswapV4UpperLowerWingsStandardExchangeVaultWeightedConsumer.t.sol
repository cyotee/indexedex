// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IUniswapV4HookStagedPairInit} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as Package} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook as Weighted} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {UniswapV4StandardExchangeWeightedBufferHookTestDeployLib as Deploy} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTestDeployLib.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";

import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg as WingsPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol";

/// @notice Initial real weighted consumer cells. This is not the complete Phase 8 matrix.
contract UniswapV4UpperLowerWingsStandardExchangeVaultWeightedConsumerTest is Fixture {
    HookFactory internal hookFactory;
    Package internal hookPackage;
    IPoolManager internal separatePool;
    function setUp() public override {
        super.setUp();
        IFacet[] memory facets = _facets();
        (hookFactory, hookPackage) = Deploy.deployFactoryAndPackage(create3Factory, owner, address(indexedexManager),
            facets[0], facets[1], facets[2], facets[3], facets[4], multiStepOwnableFacet);
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));
        separatePool = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)), keccak256("Wings.ConsumerPoolManager")));
    }
    function _consumer(uint256 mask_, bool sameManager_) private returns (Weighted hook_) {
        Package.PkgArgs memory args;
        args.poolManager = sameManager_ ? address(pool) : address(separatePool);
        args.feeOracle = address(indexedexManager); args.n = 2;
        args.tokens = new address[](2); args.tokens[0] = address(token0); args.tokens[1] = address(token1);
        args.weights = new uint256[](2); args.weights[0] = 0.37e18; args.weights[1] = 0.63e18;
        args.standardExchanges = new address[](2); args.rateProviders = new address[](2);
        if (mask_ & 1 != 0) args.standardExchanges[0] = address(wings0);
        if (mask_ & 2 != 0) args.standardExchanges[1] = address(wings1);
        args.rateProviders[0] = args.standardExchanges[0]; args.rateProviders[1] = args.standardExchanges[1];
        args.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(args.tokens);
        args.seDecimals = HookPkgArgsDecimalsLib.seDecimals(args.standardExchanges);
        args.ownerOnlyLiquidity = true; args.owner = address(this);
        address deployed = Deploy.deployHookInstance(hookFactory, hookPackage, args);
        IUniswapV4HookStagedPairInit(deployed).deployPair(address(token0), address(token1));
        require(IUniswapV4HookStagedPairInit(deployed).finalizeInitialization(), "consumer finalization");
        hook_ = Weighted(deployed);
        token0.approve(deployed, type(uint256).max); token1.approve(deployed, type(uint256).max);
    }
    function test_weightedTwoLegAllBufferedMasksBothManagerRelations() public {
        for (uint256 relation; relation < 2; ++relation) for (uint256 mask = 1; mask < 4; ++mask) {
            uint256 snapshot = vm.snapshotState();
            _roundTrip(_consumer(mask, relation == 0));
            assertTrue(vm.revertToState(snapshot));
        }
    }
    function _roundTrip(Weighted hook_) private {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 * 10 ** token0.decimals(); amounts[1] = 100 * 10 ** token1.decimals();
        (uint256 preview,uint256[] memory projectedUsed) = hook_.previewJoinProportional(amounts);
        (uint256 minted,uint256[] memory used) = hook_.joinProportional(amounts, address(this), preview, block.timestamp);
        assertEq(minted, preview); assertEq(used, projectedUsed); assertGt(minted, 0);
        uint256 shares = minted / 5;
        uint256[] memory projectedOut = hook_.previewExitProportional(shares);
        uint256 before0 = token0.balanceOf(address(this)); uint256 before1 = token1.balanceOf(address(this));
        uint256[] memory paid = hook_.exitProportional(shares, address(this), projectedOut, block.timestamp);
        assertEq(paid, projectedOut);
        assertEq(token0.balanceOf(address(this)) - before0, paid[0]);
        assertEq(token1.balanceOf(address(this)) - before1, paid[1]);
        assertEq(IERC20(address(hook_)).balanceOf(address(this)), minted - shares);
    }
    function test_weightedHomogeneousEightWingsBothManagerRelations() public {
        for (uint256 relation; relation < 2; ++relation) {
            uint256 snapshot = vm.snapshotState();
            (Weighted hook, address[] memory faces) = _largeConsumer(8, 255, relation == 0);
            _largeRoundTrip(hook, faces);
            assertTrue(vm.revertToState(snapshot));
        }
    }
    function test_weightedAritiesThreeThroughSevenAlternatingMasks() public {
        for (uint8 n = 3; n < 8; ++n) {
            uint256 snapshot = vm.snapshotState();
            (Weighted hook, address[] memory faces) = _largeConsumer(n, 85 & ((uint256(1) << n) - 1), true);
            _largeRoundTrip(hook, faces);
            assertTrue(vm.revertToState(snapshot));
        }
    }
    function _largeConsumer(uint8 n_, uint256 mask_, bool sameManager_) private returns (Weighted hook_, address[] memory faces_) {
        Package.PkgArgs memory args;
        args.poolManager = sameManager_ ? address(pool) : address(separatePool);
        args.feeOracle = address(indexedexManager); args.n = n_;
        args.tokens = new address[](n_); args.standardExchanges = new address[](n_);
        args.rateProviders = new address[](n_); args.weights = new uint256[](n_);
        for (uint256 i; i < n_; ++i) (args.tokens[i], args.standardExchanges[i]) = _pairVault(i);
        // Preserve each token/vault pairing under required canonical address order.
        for (uint256 i; i < n_; ++i) for (uint256 j = i + 1; j < n_; ++j) if (args.tokens[j] < args.tokens[i]) {
            (args.tokens[i], args.tokens[j]) = (args.tokens[j], args.tokens[i]);
            (args.standardExchanges[i], args.standardExchanges[j]) = (args.standardExchanges[j], args.standardExchanges[i]);
        }
        uint256 assigned;
        for (uint256 i; i < n_; ++i) {
            if (mask_ & (uint256(1) << i) == 0) args.standardExchanges[i] = address(0);
            args.rateProviders[i] = args.standardExchanges[i];
            args.weights[i] = i + 1 == n_ ? 1e18 - assigned : (i + 1) * 1e18 / (uint256(n_) * (n_ + 1) / 2);
            assigned += args.weights[i];
        }
        args.tokenDecimals = HookPkgArgsDecimalsLib.tokenDecimals(args.tokens);
        args.seDecimals = HookPkgArgsDecimalsLib.seDecimals(args.standardExchanges);
        args.ownerOnlyLiquidity = true; args.owner = address(this);
        address deployed = Deploy.deployHookInstance(hookFactory, hookPackage, args);
        for (uint256 i; i < n_; ++i) for (uint256 j = i + 1; j < n_; ++j)
            IUniswapV4HookStagedPairInit(deployed).deployPair(args.tokens[i], args.tokens[j]);
        require(IUniswapV4HookStagedPairInit(deployed).finalizeInitialization(), "consumer finalization");
        hook_ = Weighted(deployed); faces_ = args.tokens;
        for (uint256 i; i < n_; ++i) IERC20(faces_[i]).approve(deployed, type(uint256).max);
    }
    function _pairVault(uint256 index_) private returns (address face_, address vault_) {
        ERC20PermitMintableStub first = new ERC20PermitMintableStub("Consumer face", "FACE", index_ % 2 == 0 ? 6 : 18, address(this), 1e25);
        ERC20PermitMintableStub second = new ERC20PermitMintableStub("Consumer pair", "PAIR", index_ % 2 == 0 ? 18 : 6, address(this), 1e25);
        if (address(first) > address(second)) (first, second) = (second, first);
        PoolKey memory pairKey = PoolKey(Currency.wrap(address(first)), Currency.wrap(address(second)), 3000, 60, IHooks(address(0)));
        pool.initialize(pairKey, uint160(1) << 96);
        face_ = index_ % 2 == 0 ? address(first) : address(second);
        vault_ = wingsPackage.deployVault(WingsPackage.PkgArgs(pairKey, face_));
    }
    function _largeRoundTrip(Weighted hook_, address[] memory faces_) private {
        uint256[] memory amounts = new uint256[](faces_.length);
        for (uint256 i; i < faces_.length; ++i) amounts[i] = 100 * 10 ** IERC20Metadata(faces_[i]).decimals();
        (uint256 preview,) = hook_.previewJoinProportional(amounts);
        uint256 beforeGas = gasleft();
        (uint256 minted,) = hook_.joinProportional(amounts, address(this), preview, block.timestamp);
        emit log_named_uint("consumer join subcall gas (not outer receipt)", beforeGas - gasleft());
        assertEq(minted, preview); assertGt(minted, 0);
        uint256[] memory expected = hook_.previewExitProportional(minted / 5);
        uint256[] memory balances = new uint256[](faces_.length);
        for (uint256 i; i < faces_.length; ++i) balances[i] = IERC20(faces_[i]).balanceOf(address(this));
        uint256[] memory paid = hook_.exitProportional(minted / 5, address(this), expected, block.timestamp);
        assertEq(paid, expected);
        for (uint256 i; i < faces_.length; ++i) assertEq(IERC20(faces_[i]).balanceOf(address(this)) - balances[i], paid[i]);
    }

}
