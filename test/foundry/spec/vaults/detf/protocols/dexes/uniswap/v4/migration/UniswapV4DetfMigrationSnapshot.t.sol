// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4DetfMigrationSnapshot, MigrationSnapshotConsumer, MigrationSnapshotMathExposure} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol";
import {IUniswapV4DetfMigrationWeightedPricing as Pricing} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationWeightedPricing.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookCapture as Capture} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol";
import {IStandardExchangeFrozenQuoteInputs as Frozen} from "contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {UniswapV4StandardExchangeWeightedBufferHookMath as Weighted} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {UniswapV4StandardExchangeWeightedBufferHookClaimLib as Claim} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {StandardExchangeFrozenQuoteLib as FrozenQuote} from "contracts/utils/StandardExchangeFrozenQuoteLib.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IMigrationPairPreview} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol";
import {TestBase_UniswapV4Detf_Weighted_Univ3Se_Decimals} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Univ3Se_Decimals.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";

/// @notice Primary-mint parity and dependency freeze on real production proxies.
contract UniswapV4DetfMigrationSnapshotTest is TestBase_UniswapV4DetfMigrationSnapshot {
    function test_ManualDifferential_RealProxyCaptureAndFreeze() public {
        uint256 sourceSupply = IERC20(detf).totalSupply();
        uint256 hookShares = IERC20(reserveHook).totalSupply();
        consumer.set(_observedInputs());
        _assertOracle(address(0), pairA, 2 ether);
        _assertOracle(pairB, pairB, 3 ether);
        bytes memory beforeBook = consumer.snapshotBytes();
        Pricing.BookV3 memory captured = abi.decode(beforeBook, (Pricing.BookV3));
        uint256 inputIndex = captured.inputs.ethIndex;
        assertEq(captured.inputs.legs[inputIndex].weight, 3e17, "general exponent numerator");
        for (uint256 i; i < captured.inputs.legs.length; ++i) {
            if (captured.inputs.legs[i].token == detf) {
                assertEq(captured.inputs.legs[i].weight, 4e17, "general exponent denominator");
            }
        }
        assertEq(uint256(3e17) * 1e18 / 4e17, 750000000000000000, "0.75 power actually quoted");
        uint256 beforeEth = consumer.evaluate(address(0), 2 ether).user;
        uint256 beforeDtf = consumer.evaluate(pairB, 3 ether).user;
        assertEq(consumer.evaluateOriginals(2 ether, 3 ether), beforeEth + beforeDtf, "independent components");
        assertEq(IERC20(detf).totalSupply(), sourceSupply, "capture has no issuance");
        assertEq(IERC20(reserveHook).totalSupply(), hookShares, "capture has no LP change");

        uint256 liveBefore = _oracle(pairA, 2 ether).user;
        vm.startPrank(detfUser);
        IStandardExchangeIn(detf).exchangeIn(IERC20(pairA), 5 ether, IERC20(detf), 0, detfUser, false, block.timestamp);
        vm.stopPrank();
        assertNotEq(_oracle(pairA, 2 ether).user, liveBefore, "real trade changes canonical live quote");
        assertEq(consumer.evaluate(address(0), 2 ether).user, beforeEth, "frozen ETH");
        assertEq(consumer.evaluate(pairB, 3 ether).user, beforeDtf, "frozen DTF");
        assertEq(consumer.snapshotBytes(), beforeBook, "book unchanged");
        emit log_named_bytes("manual inputs and results", abi.encode(captured, consumer.evaluate(address(0), 2 ether), consumer.evaluate(pairB, 3 ether)));
        emit log_named_bytes32("manual book id", abi.decode(beforeBook, (Pricing.BookV3)).id);
        emit log_named_uint("frozen ETH user", beforeEth);
        emit log_named_uint("frozen DTF user", beforeDtf);
        emit log_named_uint("changed live ETH user", _oracle(pairA, 2 ether).user);
    }

    function test_ManualDifferential_SameBookZeroGroupingAndNonlinearity() public {
        consumer.set(_observedInputs());
        _assertOracle(address(0), pairA, 0);
        _assertOracle(pairB, pairB, 0);
        _assertOracle(address(0), pairA, 1 ether);
        _assertOracle(pairB, pairB, 2 ether);
        uint256 ethCredit = consumer.evaluate(address(0), 1 ether).user;
        uint256 dtfCredit = consumer.evaluate(pairB, 2 ether).user;
        assertEq(consumer.evaluateOriginals(0, 0), 0);
        assertEq(consumer.evaluateOriginals(1 ether, 0), ethCredit);
        assertEq(consumer.evaluateOriginals(0, 2 ether), dtfCredit);
        assertEq(consumer.evaluateOriginals(1 ether, 2 ether), dtfCredit + ethCredit);
        assertNotEq(2 * ethCredit, consumer.evaluate(address(0), 2 ether).user, "cannot merge originals");
        assertNotEq(ethCredit, consumer.evaluate(address(0), 2 ether).user / 2, "cannot requote partial input");
        bytes memory book_ = consumer.snapshotBytes();
        consumer.set(_observedInputs());
        assertEq(consumer.snapshotBytes(), book_, "identical manual values are idempotent");
    }

    function test_ManualDifferential_PrimaryBranchNotClosedGateFallback() public {
        consumer.set(_observedInputs());
        assertFalse(detfInfo.isMintingAllowed(IERC20(pairA)), "ordinary primary gate closed");
        (uint256 fallbackOutput,) = IStandardExchangeIn(detf).previewExchangeIn(IERC20(pairA), 2 ether, IERC20(detf));
        _assertOracle(address(0), pairA, 2 ether);
        assertNotEq(consumer.evaluate(address(0), 2 ether).user, fallbackOutput, "do not substitute fallback");
    }

    function test_ManualDifferential_NaturallyOpenGatePublicPreview() public {
        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(2);
        args.symbol = "openSnapshot";
        args.openingPairPerDetfWad = new uint256[](2);
        args.openingPairPerDetfWad[0] = 2.2e18;
        args.openingPairPerDetfWad[1] = 2.2e18;
        detf = _deployWeightedHookThenDetf(args);
        detfInfo = IUniswapV4Detf(detf);
        vm.startPrank(detfUser);
        IERC20(pairA).approve(detf, type(uint256).max);
        IERC20(pairB).approve(detf, type(uint256).max);
        detfInfo.bond(IERC20(pairA), 100 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp);
        vm.stopPrank();
        assertTrue(detfInfo.isMintingAllowed(IERC20(pairA)), "naturally open primary gate");
        consumer = _consumer(pairA, pairB, bytes32("openSnapshot"));
        consumer.set(_observedInputs());
        _assertOracle(address(0), pairA, 2 ether);
        (uint256 publicOutput,) = IStandardExchangeIn(detf).previewExchangeIn(IERC20(pairA), 2 ether, IERC20(detf));
        assertEq(consumer.evaluate(address(0), 2 ether).user, publicOutput, "open public primary branch");
    }

    function test_ManualDifferential_MappedNativeMaxInBoundary() public {
        consumer.set(_observedInputs());
        uint256 lo = 1 ether;
        uint256 hi = 1000 ether;
        while (hi - lo > 1) {
            uint256 mid = lo + (hi - lo) / 2;
            (bool ok, bytes memory reason) = address(consumer).staticcall(abi.encodeCall(consumer.evaluate, (address(0), mid)));
            if (ok) lo = mid;
            else {
                assertEq(reason, abi.encodeWithSelector(Weighted.MaxInRatio.selector), "only mapped max-in bounds this search");
                hi = mid;
            }
        }
        _assertOracle(address(0), pairA, lo);
        vm.expectRevert(Weighted.MaxInRatio.selector);
        consumer.evaluate(address(0), hi);
        vm.expectRevert(Weighted.MaxInRatio.selector);
        this.oracleResult(pairA, hi);
    }

    function test_ManualDifferential_FeesAndRegistryFrozenSeparately() public {
        consumer.set(_observedInputs());
        uint256 frozen = consumer.evaluateOriginals(2 ether, 3 ether);
        uint256 beforeLive = _oracle(pairA, 2 ether).user;
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(reserveHook, 1e17);
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(reserveHook), 1e17);
        assertNotEq(_oracle(pairA, 2 ether).user, beforeLive, "fee mutation effective");
        assertEq(consumer.evaluateOriginals(2 ether, 3 ether), frozen);
        beforeLive = _oracle(pairA, 2 ether).user;
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(detf, 2e17);
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf), 2e17);
        assertNotEq(_oracle(pairA, 2 ether).user, beforeLive, "p mutation effective");
        assertEq(consumer.evaluateOriginals(2 ether, 3 ether), frozen);

        beforeLive = _oracle(pairA, 2 ether).user;
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(se0, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(se0));
        assertNotEq(_oracle(pairA, 2 ether).user, beforeLive, "disabled branch is different");
        assertEq(consumer.evaluateOriginals(2 ether, 3 ether), frozen);
        MigrationSnapshotConsumer disabled = _consumer(pairA, pairB, bytes32("disabled"));
        disabled.set(_observedInputs());
        uint256 disabledCredit = disabled.evaluate(address(0), 2 ether).user;
        assertEq(disabledCredit, _oracle(pairA, 2 ether).user);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(se0, false);
        assertFalse(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(se0));
        assertNotEq(disabledCredit, _oracle(pairA, 2 ether).user);
        assertEq(disabled.evaluate(address(0), 2 ether).user, disabledCredit);
    }

    function test_ManualDifferential_V3BackingAndSupplyFreeze() public {
        consumer.set(_observedInputs());
        bytes memory bytesBefore = consumer.snapshotBytes();
        uint256 frozen = consumer.evaluateOriginals(2 ether, 3 ether);
        Pricing.InputsV3 memory beforeInputs = _observedInputs();
        bytes memory beforeDeposit = beforeInputs.legs[beforeInputs.ethIndex].deposit.data;
        uint256 beforeSupply = IERC20(se0).totalSupply();
        uint256 liveBefore = _oracle(pairA, 2 ether).user;
        vm.prank(detfUser);
        IERC20(pairA).transfer(se0, 10 ether);
        Pricing.InputsV3 memory afterInputs = _observedInputs();
        assertEq(afterInputs.legs[afterInputs.ethIndex].deposit.data, beforeDeposit, "stray custody is not a sizing operand");
        assertEq(_oracle(pairA, 2 ether).user, liveBefore, "stray custody does not change live issuance");
        assertEq(consumer.evaluateOriginals(2 ether, 3 ether), frozen);
        vm.prank(detfUser);
        IStandardExchangeIn(se0).exchangeIn(IERC20(pairA), 10 ether, IERC20(se0), 0, detfUser, false, block.timestamp);
        assertNotEq(IERC20(se0).totalSupply(), beforeSupply, "real SE deposit changes supply");
        assertEq(consumer.evaluateOriginals(2 ether, 3 ether), frozen);
        assertEq(consumer.snapshotBytes(), bytesBefore);
    }

    function test_InvalidManual_UnsupportedRoleAtomic() public {
        MigrationSnapshotConsumer unsupported = _consumer(se0, pairB, bytes32("unsupported"));
        Pricing.InputsV3 memory inputs_ = _observedInputs();
        vm.expectRevert(Pricing.MigrationWeightedPricingInvalid.selector);
        unsupported.set(inputs_);
        assertEq(unsupported.snapshotBytes().length, 0);
        vm.expectRevert(Pricing.MigrationWeightedPricingNotSet.selector);
        unsupported.evaluate(address(0), 1);
    }

    function test_ManualDifferential_InstalledSelectorsAndInterfaceCompatibility() public view {
        assertNotEq(IDiamondLoupe(reserveHook).facetAddress(Capture.captureWeightedMintBook.selector), address(0));
        assertTrue(IERC165(reserveHook).supportsInterface(type(Capture).interfaceId));
        assertTrue(IERC165(reserveHook).supportsInterface(type(IStandardExchangeIn).interfaceId));
        assertEq(IDiamondLoupe(se0).facetAddress(Frozen.captureFrozenQuoteInputs.selector), address(0));
        assertFalse(IERC165(se0).supportsInterface(type(Frozen).interfaceId));
        assertTrue(IERC165(se0).supportsInterface(type(IStandardExchangeIn).interfaceId));
        Capture.Book memory book = Capture(reserveHook).captureWeightedMintBook();
        assertEq(book.legs.length, 3);
        for (uint256 i; i < 3; ++i) {
            assertLe(book.legs[i].captureFacet.code.length, 24576);
            if (book.legs[i].standardExchange != address(0)) {
                assertFalse(book.legs[i].depositSupported, "legacy capture does not describe the new vault");
            }
        }
        Pricing.InputsV3 memory current = _observedInputs();
        assertEq(current.legs[current.ethIndex].deposit.version, 2);
        assertEq(current.legs[current.dtfIndex].deposit.version, 2);
        assertLe(IDiamondLoupe(reserveHook).facetAddress(Capture.captureWeightedMintBook.selector).code.length, 24576);
    }

    function test_ManualDifferential_ExactRevertAndEndpoints() public {
        consumer.set(_observedInputs());
        uint256[5] memory amounts = [uint256(1), 1e9, 1 ether, 1000 ether, type(uint256).max];
        for (uint256 i; i < amounts.length; ++i) {
            (bool ok, bytes memory result) = address(this).staticcall(abi.encodeCall(this.oracleResult, (pairA, amounts[i])));
            (bool frozenOk, bytes memory frozenResult) = address(consumer).staticcall(
                abi.encodeCall(consumer.evaluate, (address(0), amounts[i]))
            );
            assertEq(frozenOk, ok, "same success domain");
            if (!ok) assertEq(frozenResult, result, "exact revert bytes");
            else {
                Pricing.Result memory expected = abi.decode(result, (Pricing.Result));
                Pricing.Result memory actual = abi.decode(frozenResult, (Pricing.Result));
                assertEq(actual.pairEquivalent, expected.pairEquivalent);
                assertEq(actual.boosted, expected.boosted);
                assertEq(actual.net, expected.net);
                assertEq(actual.ratedInflow, expected.ratedInflow);
                assertEq(actual.gross, expected.gross);
                assertEq(actual.user, expected.user);
            }
        }
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(detf, 1e18);
        MigrationSnapshotConsumer fullP = _consumer(pairA, pairB, bytes32("fullP"));
        fullP.set(_observedInputs());
        assertEq(fullP.evaluate(address(0), 1 ether).user, 0, "computed zero user");
        assertGt(fullP.evaluate(address(0), 1 ether).gross, 0);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(reserveHook, 1e18);
        MigrationSnapshotConsumer invalidFee = _consumer(pairA, pairB, bytes32("invalidFee"));
        Pricing.InputsV3 memory invalid_ = _observedInputs();
        vm.expectRevert(Pricing.MigrationWeightedPricingInvalid.selector);
        invalidFee.set(invalid_);
    }

    function oracleResult(address pair, uint256 amount) external view returns (Pricing.Result memory) {
        return _oracle(pair, amount);
    }

    function test_ManualDifferential_RealPoolSwapAndNoLiveStorageReads() public {
        consumer.set(_observedInputs());
        bytes memory beforeBytes = consumer.snapshotBytes();
        uint256 frozen = consumer.evaluateOriginals(2 ether, 3 ether);
        (uint160 priceBefore,,,,,,) = univ3Pool0.slot0();
        uint256 feeBefore = univ3Pool0.feeGrowthGlobal0X128() + univ3Pool0.feeGrowthGlobal1X128();
        uint256 liveBefore = _oracle(pairA, 2 ether).user;
        address other = univ3Pool0.token0() == pairA ? univ3Pool0.token1() : univ3Pool0.token0();
        vm.prank(detfUser);
        IStandardExchangeIn(se0).exchangeIn(IERC20(pairA), 10000 ether, IERC20(other), 0, detfUser, false, block.timestamp);
        (uint160 priceAfter,,,,,,) = univ3Pool0.slot0();
        assertNotEq(priceAfter, priceBefore, "real pool price mutation");
        assertGt(univ3Pool0.feeGrowthGlobal0X128() + univ3Pool0.feeGrowthGlobal1X128(), feeBefore, "unpoked fee growth");
        assertNotEq(_oracle(pairA, 2 ether).user, liveBefore, "changed live pool quote");
        vm.record();
        assertEq(consumer.evaluateOriginals(2 ether, 3 ether), frozen);
        address[8] memory sources = [detf, reserveHook, se0, se1, address(indexedexManager), address(univ3Pool0), pairA, pairB];
        for (uint256 i; i < sources.length; ++i) {
            (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(sources[i]);
            assertEq(reads.length, 0, "no live source storage reads");
            assertEq(writes.length, 0, "no live source writes");
        }
        assertEq(consumer.snapshotBytes(), beforeBytes);
    }

    function test_ManualDifferential_UnitArithmeticDomains() public {
        MigrationSnapshotMathExposure math = MigrationSnapshotMathExposure(create3Factory.create3(
            ArtifactCreationCode.creationCode(create3Factory, "TestBase_UniswapV4DetfMigrationSnapshot.sol:MigrationSnapshotMathExposure"),
            bytes32("snapshotMath")
        ));
        assertEq(math.net(1050, 3e15), 1047);
        Pricing.InputsV3 memory current = _observedInputs();
        Frozen.VersionedInputs memory deposit = current.legs[current.ethIndex].deposit;
        math.requireSupported(deposit);
        deposit.version = 99;
        vm.expectRevert(abi.encodeWithSelector(Frozen.UnsupportedFrozenVersion.selector, 99));
        math.requireSupported(deposit);
        (uint256 user, uint256 pot) = DETFMintSplitLib._splitLiveGross(3, 5e17);
        assertEq(user, 1);
        assertEq(pot, 1);
        assertEq(math.budget(1000, 5e17, 5e17, 300), 230);
        vm.expectRevert(Weighted.MaxInRatio.selector);
        math.budget(1000, 5e17, 5e17, 301);
        assertEq(math.budget(1e24, 5e17, 5e17, 1e21), 999000999000999000000);
        assertEq(math.budget(1e24, 8e17, 2e17, 1e21), 3990019965055916000000);
        vm.expectRevert(Weighted.ZeroAmount.selector);
        math.rawOutput(1e9 - 1, 1e27, 100);
        assertEq(math.rawOutput(1e9, 1e27, 100), 1);
        assertEq(math.scale(1e6, 1e30), 1e18);
        assertEq(math.scale(1e9, 1e27), 1e18);
        assertEq(math.scale(1e18, 1e18), 1e18);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        math.net(type(uint256).max, 5e17);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        math.scale(type(uint256).max, 1e27);
    }

    /// @dev Unit-only malformed outcome vectors. No production proxy storage is modified.
    function test_InvalidManual_ProviderOperandsAndInactiveFields() public {
        Pricing.InputsV3 memory inputs_ = _observedInputs();
        inputs_.legs[inputs_.dtfIndex].rate = 0;
        vm.expectRevert(Pricing.MigrationWeightedPricingInvalid.selector);
        consumer.set(inputs_);
        inputs_ = _observedInputs();
        Frozen.SwapDepositV2 memory deposit = abi.decode(
            inputs_.legs[inputs_.dtfIndex].deposit.data, (Frozen.SwapDepositV2)
        );
        deposit.request.holder = reserveHook;
        inputs_.legs[inputs_.dtfIndex].deposit.data = abi.encode(deposit);
        vm.expectRevert(Frozen.InvalidFrozenDeposit.selector);
        consumer.set(inputs_);
        inputs_ = _observedInputs();
        inputs_.legs[inputs_.detfIndex].deposit = inputs_.legs[inputs_.dtfIndex].deposit;
        vm.expectRevert(Pricing.MigrationWeightedPricingInvalid.selector);
        consumer.set(inputs_);
    }

    function test_ManualDifferential_ZeroFeeAndZeroSeigniorage() public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(0);
        vm.stopPrank();
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(reserveHook), 0);
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf), 0);
        consumer.set(_observedInputs());
        _assertOracle(address(0), pairA, 1 ether);
        _assertOracle(pairB, pairB, 2 ether);
        Pricing.Result memory r = consumer.evaluate(address(0), 1 ether);
        assertEq(r.pairEquivalent, r.boosted);
        assertEq(r.boosted, r.net);
        assertEq(r.gross, r.user);
    }
}
