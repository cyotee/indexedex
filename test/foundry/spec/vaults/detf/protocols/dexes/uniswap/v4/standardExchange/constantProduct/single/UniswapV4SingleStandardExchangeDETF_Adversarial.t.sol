// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeDETF,
    IUniswapV4SingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";

/// @dev Hostile pair: transferFrom reenters target, then completes (records nested error).
contract HostilePairToken is SimpleMintableERC20 {
    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 private _depth;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor() SimpleMintableERC20("HostilePair", "HPAIR") {}

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

/// @notice Phase 6 adversarial: nested reentrancy during transferFrom hits IsLocked.
contract UniswapV4SingleStandardExchangeDETF_AdversarialTest is TestBase_UniswapV4SingleStandardExchangeDETF {
    HostilePairToken internal hostilePair;
    address internal hostileSe;
    address internal hostileDetf;
    IUniswapV4SingleStandardExchangeDETF internal hostileDetfInfo;
    IStandardExchangeIn internal hostileDetfX;

    function setUp() public override {
        super.setUp();

        // Deploy hostile pair + ERC-4626 SE so pair ∈ SE.tokens() for DETF postDeploy validation.
        hostilePair = new HostilePairToken();
        SimpleYieldERC4626 hostileVault = new SimpleYieldERC4626(hostilePair);
        hostileSe = _deployERC4626SE(address(hostileVault));

        IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args = _openArgs();
        args.name = "Hostile UniV4 DETF";
        args.symbol = "hDETF";
        args.standardExchangeVault = IStandardExchangeProxy(hostileSe);
        args.standardExchangeVaultShare = IERC20(address(0));
        args.pairToken = IERC20(address(hostilePair));
        args.thresholdMode = ThresholdMode.Open;

        hostileDetf = _deployDetfInstance(args);
        hostileDetfInfo = IUniswapV4SingleStandardExchangeDETF(hostileDetf);
        hostileDetfX = IStandardExchangeIn(hostileDetf);

        hostilePair.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        hostilePair.approve(hostileDetf, type(uint256).max);
        vm.stopPrank();
        _setBondTermsFor(hostileDetf, DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        // First bond → live
        vm.startPrank(detfUser);
        hostileDetfInfo.bond(
            IERC20(address(hostilePair)),
            400 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(hostileDetfInfo.isReserveLive(), "hostile detf live");
    }

    function _setBondTermsFor(address vault_, uint256 minLock_, uint256 maxLock_) internal {
        try IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(
            vault_,
            BondTerms({
                minLockDuration: minLock_,
                maxLockDuration: maxLock_,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        ) {} catch {}
    }

    function test_reentrancy_mint_hitsIsLocked() public {
        // Nested bond reentry during pair transferFrom of primary mint.
        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4SingleStandardExchangeDETF.bond.selector,
            IERC20(address(hostilePair)),
            uint256(1 ether),
            DEFAULT_MIN_LOCK,
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
        assertFalse(hostilePair.nestedCallSucceeded(), "nested bond blocked");
        assertEq(
            hostilePair.nestedErrorSelector(),
            IReentrancyLock.IsLocked.selector,
            "IsLocked"
        );
        hostilePair.disarm();
    }

    function test_protocolLp_and_userBonded_partition() public {
        // Open detf for mint after first bond
        detf = _deployDetfInstance(_openArgs());
        detfInfo = IUniswapV4SingleStandardExchangeDETF(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        pairToken.mint(detfUser, 1_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        vm.stopPrank();
        _firstBond(200 ether);
        _mintPair(50 ether);
        uint256 protocol = detfInfo.protocolLp();
        uint256 user = detfInfo.userBondedLp();
        address hook = detfInfo.reserveHook();
        address bond = detfInfo.bondNftVault();
        address claim = detfInfo.rebasingClaimToken();
        // PRD LOCK physical custody: protocol on claim, user on bond NFT (not diamond).
        assertEq(protocol, IERC20(hook).balanceOf(claim), "protocol = claim LP bal");
        assertGe(IERC20(hook).balanceOf(bond), user, "bond NFT holds >= userBondedLp");
        assertEq(IERC20(hook).balanceOf(detf), 0, "diamond holds no residual LP");
        assertGt(protocol, 0, "mint created protocol LP");
        assertGt(user, 0, "bond created user LP");
    }

    function test_acceptedBondTokens_includes_pair() public view {
        address[] memory t = detfInfo.acceptedBondTokens();
        assertEq(t[0], address(pairToken));
    }
}
