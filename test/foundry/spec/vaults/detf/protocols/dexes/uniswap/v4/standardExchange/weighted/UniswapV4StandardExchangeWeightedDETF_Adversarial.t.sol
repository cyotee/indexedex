// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF,
    IUniswapV4StandardExchangeWeightedDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    UniswapV4StandardExchangeWeightedDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedDETFRepo.sol";

/// @dev Hostile pair: transferFrom reenters target, then completes (records nested error).
contract HostileWeightedPairToken is SimpleMintableERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor() SimpleMintableERC20("HostileWgtPair", "HWGT") {}

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
        reentryAttempts = 0;
        nestedCallSucceeded = false;
        nestedErrorSelector = bytes4(0);
    }

    function disarm() external {
        armed = false;
    }

    function transferFrom(address from_, address to_, uint256 value_) public override returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            unchecked {
                ++reentryAttempts;
            }
            (bool ok_, bytes memory ret_) = target.call(reentryCall);
            nestedCallSucceeded = ok_;
            if (!ok_ && ret_.length >= 4) {
                bytes4 sel;
                assembly {
                    sel := mload(add(ret_, 0x20))
                }
                nestedErrorSelector = sel;
            }
            _depth = 0;
        }
        uint256 allowed = allowance[from_][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= value_, "allowance");
            allowance[from_][msg.sender] = allowed - value_;
        }
        _transfer(from_, to_, value_);
        return true;
    }
}

/// @notice Nested reentrancy during transferFrom → IsLocked; empty protocol burn.
contract UniswapV4StandardExchangeWeightedDETF_Adversarial is
    TestBase_UniswapV4StandardExchangeWeightedDETF
{
    HostileWeightedPairToken internal hostilePair;
    address internal hostileDetf;
    IUniswapV4StandardExchangeWeightedDETF internal hostileDetfInfo;
    IStandardExchangeIn internal hostileDetfX;

    function setUp() public override {
        super.setUp();

        // Hostile bare pair + real SE on token0: n=3 so we can first-bond both pairs.
        hostilePair = new HostileWeightedPairToken();
        IERC20[] memory pairs_ = new IERC20[](2);
        pairs_[0] = IERC20(address(token0));
        pairs_[1] = IERC20(address(hostilePair));
        IStandardExchangeProxy[] memory ses_ = new IStandardExchangeProxy[](2);
        ses_[0] = IStandardExchangeProxy(se0);
        ses_[1] = IStandardExchangeProxy(address(0));
        IERC20[] memory shares_ = new IERC20[](2);
        address[] memory rps_ = new address[](2);
        uint256[] memory pairW_ = new uint256[](2);
        pairW_[0] = 0.33e18;
        pairW_[1] = 0.34e18;
        uint256[] memory rates_ = new uint256[](2);
        rates_[0] = DEFAULT_CREATION;
        rates_[1] = DEFAULT_CREATION;

        IUniswapV4StandardExchangeWeightedDETDFPkg.PkgArgs memory args = IUniswapV4StandardExchangeWeightedDETDFPkg
            .PkgArgs({
            name: "Hostile Wgt DETF",
            symbol: "hWgt",
            pairTokens: pairs_,
            standardExchanges: ses_,
            vaultShares: shares_,
            rateProviders: rps_,
            detfWeight: 0.33e18,
            pairWeights: pairW_,
            creationPairPerDetfWad: rates_,
            openingPairPerDetfWad: new uint256[](2),
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Open,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            creator: address(0),
            claimName: "",
            claimSymbol: "",
            bondName: "",
            bondSymbol: ""
        });

        hostileDetf = _deployDetfWired(args);
        hostileDetfInfo = IUniswapV4StandardExchangeWeightedDETF(hostileDetf);
        hostileDetfX = IStandardExchangeIn(hostileDetf);
        _setBondTermsFor(hostileDetf);

        hostilePair.mint(detfUser, 10_000_000 ether);
        token0.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        hostilePair.approve(hostileDetf, type(uint256).max);
        token0.approve(hostileDetf, type(uint256).max);
        vm.stopPrank();

        // First bond both externals → live
        uint256[] memory amts = new uint256[](2);
        amts[0] = 400 ether;
        amts[1] = 400 ether;
        _firstBondOn(hostileDetf, amts, address(token0));
        assertTrue(hostileDetfInfo.isReserveLive(), "hostile detf live");
    }

    function test_reentrancy_mint_hitsIsLocked() public {
        // Nested exchangeIn reentry during hostile pair transferFrom of primary mint.
        bytes memory reentry = abi.encodeWithSelector(
            IStandardExchangeIn.exchangeIn.selector,
            IERC20(address(hostilePair)),
            uint256(1 ether),
            IERC20(hostileDetf),
            uint256(0),
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        hostilePair.arm(hostileDetf, reentry);

        vm.startPrank(detfUser);
        uint256 out_ = hostileDetfX.exchangeIn(
            IERC20(address(hostilePair)),
            50 ether,
            IERC20(hostileDetf),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();

        assertGt(out_, 0, "outer mint completed");
        assertGe(hostilePair.reentryAttempts(), 1, "reentry attempted during transferFrom");
        assertFalse(hostilePair.nestedCallSucceeded(), "nested mint blocked");
        assertEq(hostilePair.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "IsLocked");
        hostilePair.disarm();
    }

    function test_emptyProtocolLp_burn_usesNftLp() public {
        // First bond: id 0 originalShares = 0, but NFT holds bond LP (D13).
        address d2 = _deployDetfWired(_openArgsUnique("emptyLp"));
        IUniswapV4StandardExchangeWeightedDETF info2 = IUniswapV4StandardExchangeWeightedDETF(d2);
        IStandardExchangeIn ex2 = IStandardExchangeIn(d2);
        address p0 = info2.pairToken(0);
        uint256[] memory amts = new uint256[](1);
        amts[0] = 100 ether;
        _firstBondOn(d2, amts, p0);
        assertEq(info2.protocolLp(), 0, "id 0 originalShares empty");
        assertGt(IERC20(info2.reserveHook()).balanceOf(info2.bondNftVault()), 0, "NFT holds LP");
        uint256 free_ = IERC20(d2).balanceOf(detfUser);
        require(free_ > 0, "L1 free DETF");
        uint256 burnAmt_ = free_ / 10;
        if (burnAmt_ == 0) burnAmt_ = free_;
        vm.startPrank(detfUser);
        IERC20(d2).approve(d2, type(uint256).max);
        uint256 out_ = ex2.exchangeIn(IERC20(d2), burnAmt_, IERC20(p0), 0, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(out_, 0, "D13 burn against NFT LP");
    }
}
