// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4DetfMigrationSnapshot, MigrationSnapshotConsumer, MigrationSnapshotMathExposure} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol";
import {IUniswapV4DetfMigrationSnapshot as Snapshot} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol";
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
    function test_MigrationSnapshot_RealProxyCaptureAndFreeze() public {
        uint256 sourceSupply = IERC20(detf).totalSupply();
        uint256 hookShares = IERC20(reserveHook).totalSupply();
        consumer.capture();
        _assertOracle(address(0), pairA, 2 ether);
        _assertOracle(pairB, pairB, 3 ether);
        bytes memory beforeBook = consumer.snapshotBytes();
        Snapshot.Snapshot memory captured = abi.decode(beforeBook, (Snapshot.Snapshot));
        uint256 inputIndex = captured.routes[0].index;
        assertEq(captured.book.legs[inputIndex].weight, 3e17, "general exponent numerator");
        for (uint256 i; i < captured.book.legs.length; ++i) {
            if (captured.book.legs[i].token == detf) {
                assertEq(captured.book.legs[i].weight, 4e17, "general exponent denominator");
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
        emit log_named_bytes32("snapshot id", abi.decode(beforeBook, (Snapshot.Snapshot)).id);
        emit log_named_uint("frozen ETH user", beforeEth);
        emit log_named_uint("frozen DTF user", beforeDtf);
        emit log_named_uint("changed live ETH user", _oracle(pairA, 2 ether).user);
    }

    function test_MigrationSnapshot_SameBookZeroGroupingAndNonlinearity() public {
        consumer.capture();
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
        vm.expectRevert(Snapshot.SnapshotAlreadyCaptured.selector);
        consumer.capture();
    }

    function test_MigrationSnapshot_PrimaryBranchNotClosedGateFallback() public {
        consumer.capture();
        assertFalse(detfInfo.isMintingAllowed(IERC20(pairA)), "ordinary primary gate closed");
        (uint256 fallbackOutput,) = IStandardExchangeIn(detf).previewExchangeIn(IERC20(pairA), 2 ether, IERC20(detf));
        _assertOracle(address(0), pairA, 2 ether);
        assertNotEq(consumer.evaluate(address(0), 2 ether).user, fallbackOutput, "do not substitute fallback");
    }

    function test_MigrationSnapshot_NaturallyOpenGatePublicPreview() public {
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
        consumer.capture();
        _assertOracle(address(0), pairA, 2 ether);
        (uint256 publicOutput,) = IStandardExchangeIn(detf).previewExchangeIn(IERC20(pairA), 2 ether, IERC20(detf));
        assertEq(consumer.evaluate(address(0), 2 ether).user, publicOutput, "open public primary branch");
    }

    function test_MigrationSnapshot_MappedNativeMaxInBoundary() public {
        consumer.capture();
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

    function test_MigrationSnapshot_FeesAndRegistryFrozenSeparately() public {
        consumer.capture();
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
        disabled.capture();
        uint256 disabledCredit = disabled.evaluate(address(0), 2 ether).user;
        assertEq(disabledCredit, _oracle(pairA, 2 ether).user);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(se0, false);
        assertFalse(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(se0));
        assertNotEq(disabledCredit, _oracle(pairA, 2 ether).user);
        assertEq(disabled.evaluate(address(0), 2 ether).user, disabledCredit);
    }

    function test_MigrationSnapshot_V3BackingAndSupplyFreeze() public {
        consumer.capture();
        bytes memory bytesBefore = consumer.snapshotBytes();
        uint256 frozen = consumer.evaluateOriginals(2 ether, 3 ether);
        Frozen.Request memory request = Frozen.Request(pairA, se0, reserveHook, Frozen.Mode.OrdinaryDeposit);
        Frozen.Inputs memory beforeInputs = Frozen(se0).captureFrozenQuoteInputs(request);
        uint256 liveBefore = _oracle(pairA, 2 ether).user;
        vm.prank(detfUser);
        IERC20(pairA).transfer(se0, 10 ether);
        Frozen.Inputs memory afterInputs = Frozen(se0).captureFrozenQuoteInputs(request);
        assertNotEq(afterInputs.reserve0 + afterInputs.reserve1, beforeInputs.reserve0 + beforeInputs.reserve1);
        assertNotEq(_oracle(pairA, 2 ether).user, liveBefore, "donation changes live quote");
        assertEq(consumer.evaluateOriginals(2 ether, 3 ether), frozen);
        vm.prank(detfUser);
        IStandardExchangeIn(se0).exchangeIn(IERC20(pairA), 10 ether, IERC20(se0), 0, detfUser, false, block.timestamp);
        assertNotEq(IERC20(se0).totalSupply(), beforeInputs.supply, "real SE deposit changes supply");
        assertEq(consumer.evaluateOriginals(2 ether, 3 ether), frozen);
        assertEq(consumer.snapshotBytes(), bytesBefore);
    }

    function test_MigrationSnapshot_UnsupportedConversionAtomic() public {
        MigrationSnapshotConsumer unsupported = _consumer(se0, pairB, bytes32("unsupported"));
        vm.expectRevert(abi.encodeWithSelector(Snapshot.UnsupportedRoute.selector, se0, se0, pairA));
        unsupported.capture();
        assertEq(unsupported.snapshotBytes().length, 0, "no partially sealed book");
        vm.expectRevert(Snapshot.SnapshotNotCaptured.selector);
        unsupported.evaluate(address(0), 1);
        Frozen.Request memory request = Frozen.Request(se0, pairA, reserveHook, Frozen.Mode.OrdinaryRedemption);
        vm.expectRevert(abi.encodeWithSelector(Frozen.UnsupportedFrozenQuote.selector, se0, se0, pairA, request.mode));
        Frozen(se0).captureFrozenQuoteInputs(request);
    }

    function test_MigrationSnapshot_InstalledSelectorsAndInterfaceCompatibility() public view {
        assertNotEq(IDiamondLoupe(reserveHook).facetAddress(Capture.captureWeightedMintBook.selector), address(0));
        assertTrue(IERC165(reserveHook).supportsInterface(type(Capture).interfaceId));
        assertTrue(IERC165(reserveHook).supportsInterface(type(IStandardExchangeIn).interfaceId));
        assertNotEq(IDiamondLoupe(se0).facetAddress(Frozen.captureFrozenQuoteInputs.selector), address(0));
        assertTrue(IERC165(se0).supportsInterface(type(Frozen).interfaceId));
        assertTrue(IERC165(se0).supportsInterface(type(IStandardExchangeIn).interfaceId));
        Capture.Book memory book = Capture(reserveHook).captureWeightedMintBook();
        assertEq(book.legs.length, 3);
        for (uint256 i; i < 3; ++i) {
            assertLe(book.legs[i].captureFacet.code.length, 24576);
        }
        assertLe(IDiamondLoupe(reserveHook).facetAddress(Capture.captureWeightedMintBook.selector).code.length, 24576);
    }

    function test_MigrationSnapshot_ExactRevertAndEndpoints() public {
        consumer.capture();
        uint256[5] memory amounts = [uint256(1), 1e9, 1 ether, 1000 ether, type(uint256).max];
        for (uint256 i; i < amounts.length; ++i) {
            (bool ok, bytes memory result) = address(this).staticcall(abi.encodeCall(this.oracleResult, (pairA, amounts[i])));
            (bool frozenOk, bytes memory frozenResult) = address(consumer).staticcall(
                abi.encodeCall(consumer.evaluate, (address(0), amounts[i]))
            );
            assertEq(frozenOk, ok, "same success domain");
            if (!ok) assertEq(frozenResult, result, "exact revert bytes");
            else {
                Snapshot.Result memory expected = abi.decode(result, (Snapshot.Result));
                Snapshot.Result memory actual = abi.decode(frozenResult, (Snapshot.Result));
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
        fullP.capture();
        assertEq(fullP.evaluate(address(0), 1 ether).user, 0, "computed zero user");
        assertGt(fullP.evaluate(address(0), 1 ether).gross, 0);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setVaultDexSwapFee(reserveHook, 1e18);
        MigrationSnapshotConsumer invalidFee = _consumer(pairA, pairB, bytes32("invalidFee"));
        invalidFee.capture();
        vm.expectRevert(Claim.InvalidFeeWad.selector);
        invalidFee.evaluate(address(0), 1 ether);
    }

    function oracleResult(address pair, uint256 amount) external view returns (Snapshot.Result memory) {
        return _oracle(pair, amount);
    }

    function test_MigrationSnapshot_RealPoolSwapAndNoLiveStorageReads() public {
        consumer.capture();
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

    function test_MigrationSnapshot_UnitArithmeticDomains() public {
        MigrationSnapshotMathExposure math = MigrationSnapshotMathExposure(create3Factory.create3(
            ArtifactCreationCode.creationCode(create3Factory, "TestBase_UniswapV4DetfMigrationSnapshot.sol:MigrationSnapshotMathExposure"),
            bytes32("snapshotMath")
        ));
        assertEq(math.net(1050, 3e15), 1047);
        math.requireRecognized(
            IDiamondLoupe(se0).facetAddress(Frozen.captureFrozenQuoteInputs.selector),
            IDiamondLoupe(se0).facetAddress(IStandardExchangeIn.previewExchangeIn.selector)
        );
        address captureFacet = IDiamondLoupe(se0).facetAddress(Frozen.captureFrozenQuoteInputs.selector);
        vm.expectRevert(abi.encodeWithSelector(
            FrozenQuote.UnrecognizedFrozenImplementation.selector, captureFacet, captureFacet
        ));
        math.requireRecognized(captureFacet, captureFacet);
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
    function test_MigrationSnapshot_UnitAllLegProviderOutcomes() public {
        consumer.capture();
        Snapshot.Snapshot memory s = abi.decode(consumer.snapshotBytes(), (Snapshot.Snapshot));
        MigrationSnapshotMathExposure math = MigrationSnapshotMathExposure(create3Factory.create3(
            ArtifactCreationCode.creationCode(create3Factory, "TestBase_UniswapV4DetfMigrationSnapshot.sol:MigrationSnapshotMathExposure"),
            bytes32("providerOutcomeMath")
        ));
        uint256 third = s.routes[1].index;
        assertGt(s.book.legs[third].seReserve, 0, "held non-input leg");
        s.book.legs[third].rate.success = false;
        vm.expectRevert(Claim.RateProviderFailed.selector);
        math.evaluate(s, address(0), 1 ether);
        s.book.legs[third].rate.success = true;
        s.book.legs[third].rate.data = hex"01";
        vm.expectRevert(Claim.RateProviderFailed.selector);
        math.evaluate(s, address(0), 1 ether);
        s.book.legs[third].rate.data = abi.encode(uint256(0));
        vm.expectRevert(Claim.RateProviderFailed.selector);
        math.evaluate(s, address(0), 1 ether);
        s.book.legs[third].provider = address(0);
        vm.expectRevert(Claim.RateProviderRequired.selector);
        math.evaluate(s, address(0), 1 ether);
        s.book.legs[third].seReserve = 0;
        assertEq(math.evaluate(s, address(0), 1 ether).user, consumer.evaluate(address(0), 1 ether).user,
            "unused missing provider is not evaluated");
    }

    function test_MigrationSnapshot_ZeroFeeAndZeroSeigniorage() public {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultDexSwapFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultSeigniorageIncentivePercentage(0);
        vm.stopPrank();
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).dexSwapFeeOfVault(reserveHook), 0);
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf), 0);
        consumer.capture();
        _assertOracle(address(0), pairA, 1 ether);
        _assertOracle(pairB, pairB, 2 ether);
        Snapshot.Result memory r = consumer.evaluate(address(0), 1 ether);
        assertEq(r.pairEquivalent, r.boosted);
        assertEq(r.boosted, r.net);
        assertEq(r.gross, r.user);
    }
}

/// @notice Independent real-proxy decimal fixture, not rescaled synthetic book fields.
contract UniswapV4DetfMigrationSnapshotDecimalsTest is TestBase_UniswapV4Detf_Weighted_Univ3Se_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 18; }

    function test_MigrationSnapshot_RealProxySixNineEighteen() public {
        _firstBond(_uPair(100));
        MigrationSnapshotConsumer frozen = MigrationSnapshotConsumer(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "TestBase_UniswapV4DetfMigrationSnapshot.sol:MigrationSnapshotConsumer"),
            abi.encode(Snapshot.Source(detf, address(indexedexManager), pairA, pairB)), bytes32("decimalSnapshot")
        ));
        frozen.capture();
        assertEq(IERC20Metadata(pairA).decimals(), 6);
        assertEq(IERC20Metadata(pairB).decimals(), 18);
        assertEq(IERC20Metadata(detf).decimals(), 9);
        uint256 p = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageIncentivePercentageOfVault(detf);
        address[2] memory pairs = [pairA, pairB];
        uint256[2] memory amounts = [uint256(2e6), uint256(3e18)];
        uint256 sum;
        for (uint256 i; i < 2; ++i) {
            uint256 pairEq = IMigrationPairPreview(detf).peekPairEq(i == 0 ? se0 : se1, pairs[i], amounts[i]);
            uint256 boosted = Math.mulDiv(pairEq, 1e18 + p, 1e18);
            (uint256 gross,) = IStandardExchangeIn(reserveHook).previewExchangeIn(IERC20(pairs[i]), boosted, IERC20(detf));
            (uint256 user,) = DETFMintSplitLib._splitLiveGross(gross, p);
            Snapshot.Result memory result = frozen.evaluate(i == 0 ? address(0) : pairB, amounts[i]);
            assertEq(result.pairEquivalent, pairEq);
            assertEq(result.boosted, boosted);
            assertEq(result.gross, gross);
            assertEq(result.user, user);
            sum += user;
        }
        assertEq(frozen.evaluateOriginals(amounts[0], amounts[1]), sum);
    }
}

/// @notice A real receipt wrapper is explicitly excluded; a fixture model is not code recognition.
contract UniswapV4DetfMigrationSnapshotReceiptExclusionTest is TestBase_UniswapV4Detf_Weighted {
    function test_MigrationSnapshot_UnknownReceiptModelFailsCaptureAtomically() public {
        _firstBond(100 ether);
        MigrationSnapshotConsumer frozen = MigrationSnapshotConsumer(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "TestBase_UniswapV4DetfMigrationSnapshot.sol:MigrationSnapshotConsumer"),
            abi.encode(Snapshot.Source(detf, address(indexedexManager), address(pair0), address(pair1))), bytes32("receiptExclusion")
        ));
        vm.expectRevert(abi.encodeWithSelector(Snapshot.UnsupportedRoute.selector, se0, address(pair0), se0));
        frozen.capture();
        assertEq(frozen.snapshotBytes().length, 0, "unsupported does not install a snapshot");
    }
}
