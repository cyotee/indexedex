// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ONE_WAD} from "@crane/contracts/constants/Constants.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";

import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRouter.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";

import {ISeigniorageDETFErrors} from "contracts/interfaces/ISeigniorageDETFErrors.sol";
import {
    IBalancerV3StandardExchangeRouterPrepay
} from "contracts/interfaces/IBalancerV3StandardExchangeRouterPrepay.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {SeigniorageDETFRepo} from "contracts/vaults/seigniorage/SeigniorageDETFRepo.sol";
import {SeigniorageDETFExchangeInTarget} from "contracts/vaults/seigniorage/SeigniorageDETFExchangeInTarget.sol";
import {SeigniorageDETFExchangeOutTarget} from "contracts/vaults/seigniorage/SeigniorageDETFExchangeOutTarget.sol";

// TODO Deprecate for using ERC20 mint burn package. Make package if it doesn't exist.
contract MockERC20MintBurn is IERC20MintBurn {
    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function mint(address account, uint256 amount) external returns (bool) {
        totalSupply += amount;
        balanceOf[account] += amount;
        return true;
    }

    function burn(address account, uint256 amount) external returns (bool) {
        balanceOf[account] -= amount;
        totalSupply -= amount;
        return true;
    }
}

contract MockReserveVault {
    address internal _asset;

    constructor(address asset_) {
        _asset = asset_;
    }

    function asset() external view returns (address) {
        return _asset;
    }
}

contract MockWeightedPool {
    uint256[2] internal _weights;

    constructor(uint256 weight0, uint256 weight1) {
        _weights[0] = weight0;
        _weights[1] = weight1;
    }

    function getNormalizedWeights() external view returns (uint256[] memory weights) {
        weights = new uint256[](2);
        weights[0] = _weights[0];
        weights[1] = _weights[1];
    }
}

contract MockBalancerV3Vault {
    uint256[] internal _balances;
    uint256 internal _swapFee;

    constructor(uint256[] memory balances_, uint256 swapFee_) {
        _balances = balances_;
        _swapFee = swapFee_;
    }

    function getCurrentLiveBalances(address) external view returns (uint256[] memory balances) {
        balances = _balances;
    }

    function getStaticSwapFeePercentage(address) external view returns (uint256) {
        return _swapFee;
    }

    function setBalances(uint256[] memory balances_) external {
        _balances = balances_;
    }
}

contract ExchangeInHarness is SeigniorageDETFExchangeInTarget {
    using SeigniorageDETFRepo for SeigniorageDETFRepo.Storage;

    function init(
        address balV3Vault,
        address reservePool,
        address reserveVault,
        address reserveVaultRateTarget,
        IERC20MintBurn seigniorageToken,
        uint256 selfIndex,
        uint256 reserveIndex
    ) external {
        ERC20Repo._initialize("RBT", "RBT", 18);

        BalancerV3VaultAwareRepo._initialize(IVault(balV3Vault));

        // Minimal repo init; most fields are irrelevant for the sRBT routes.
        SeigniorageDETFRepo._initialize(
            IVaultFeeOracleQuery(address(0)),
            IBalancerV3StandardExchangeRouterPrepay(address(0)),
            IStandardExchange(reserveVault),
            IERC20(reserveVaultRateTarget),
            seigniorageToken
        );

        SeigniorageDETFRepo.Storage storage detfStorage = SeigniorageDETFRepo._layout();
        detfStorage._initialize(selfIndex, 0.8e18, reserveIndex, 0.2e18, ISeigniorageNFTVault(address(0)));
        ERC4626Repo._initialize(IERC20(reservePool), 18, 9);
    }

    function mintRbt(address to, uint256 amount) external {
        ERC20Repo._mint(to, amount);
    }

    function balanceOfRbt(address account) external view returns (uint256) {
        return ERC20Repo._balanceOf(account);
    }
}

contract ExchangeOutHarness is SeigniorageDETFExchangeOutTarget {
    using SeigniorageDETFRepo for SeigniorageDETFRepo.Storage;

    function init(
        address balV3Vault,
        address reservePool,
        address reserveVault,
        address reserveVaultRateTarget,
        IERC20MintBurn seigniorageToken,
        uint256 selfIndex,
        uint256 reserveIndex
    ) external {
        ERC20Repo._initialize("RBT", "RBT", 18);

        BalancerV3VaultAwareRepo._initialize(IVault(balV3Vault));

        SeigniorageDETFRepo._initialize(
            IVaultFeeOracleQuery(address(0)),
            IBalancerV3StandardExchangeRouterPrepay(address(0)),
            IStandardExchange(reserveVault),
            IERC20(reserveVaultRateTarget),
            seigniorageToken
        );

        SeigniorageDETFRepo.Storage storage detfStorage = SeigniorageDETFRepo._layout();
        detfStorage._initialize(selfIndex, 0.8e18, reserveIndex, 0.2e18, ISeigniorageNFTVault(address(0)));
        ERC4626Repo._initialize(IERC20(reservePool), 18, 9);
    }

    function mintRbt(address to, uint256 amount) external {
        ERC20Repo._mint(to, amount);
    }

    function balanceOfRbt(address account) external view returns (uint256) {
        return ERC20Repo._balanceOf(account);
    }
}

contract SeigniorageDETFExchangeRoutes_Test is Test {
    ExchangeInHarness internal inHarness;
    ExchangeOutHarness internal outHarness;

    MockERC20MintBurn internal sRbt;
    MockWeightedPool internal pool;
    MockBalancerV3Vault internal vault;

    MockERC20MintBurn internal other;
    MockReserveVault internal reserveVault;

    address internal alice;

    function setUp() public {
        alice = makeAddr("alice");

        sRbt = new MockERC20MintBurn("sRBT", "sRBT", 18);
        other = new MockERC20MintBurn("OTHER", "OTHER", 18);
        reserveVault = new MockReserveVault(address(0xDEAD));

        // 80/20 pool weights (self = 0.8, reserve = 0.2). Indices are: self=0, reserve=1.
        pool = new MockWeightedPool(0.8e18, 0.2e18);

        // Start with nonzero balances; tests will overwrite as needed.
        uint256[] memory balances = new uint256[](2);
        balances[0] = 100e18; // self balance in pool
        balances[1] = 100e18; // reserve balance in pool
        vault = new MockBalancerV3Vault(balances, 0);

        inHarness = new ExchangeInHarness();
        inHarness.init(address(vault), address(pool), address(reserveVault), address(0xCAFE), sRbt, 0, 1);

        outHarness = new ExchangeOutHarness();
        outHarness.init(address(vault), address(pool), address(reserveVault), address(0xCAFE), sRbt, 0, 1);
    }

    function _setAbovePeg() internal {
        // price = 4 * (reserve/claims) with weights 0.2/0.8.
        // Make reserve == claims => price == 4e18 (> 1e18).
        inHarness.mintRbt(alice, 100e18);
        outHarness.mintRbt(alice, 100e18);

        uint256[] memory balances = new uint256[](2);
        balances[0] = 100e18;
        balances[1] = 100e18;
        vault.setBalances(balances);
    }

    function _setAtPeg(uint256) internal {
        // Contract rule: if selfBalance == 0, diluted price is treated as exactly ONE_WAD.
        // This avoids needing to model the sRBT-debt term precisely for this unit test.
        inHarness.mintRbt(alice, 100e18);
        outHarness.mintRbt(alice, 100e18);

        uint256[] memory balances = new uint256[](2);
        balances[0] = 0;
        balances[1] = 1;
        vault.setBalances(balances);
    }

    function _setBelowPeg() internal {
        // Make reserve/claims < 0.25 => price < 1e18.
        inHarness.mintRbt(alice, 100e18);
        outHarness.mintRbt(alice, 100e18);

        uint256[] memory balances = new uint256[](2);
        balances[0] = 100e18;
        balances[1] = 10e18;
        vault.setBalances(balances);
    }

    function test_exchangeIn_RbtToSrbt_supportedViaStandardFunction() public {
        _setAbovePeg();

        vm.startPrank(alice);
        uint256 previewOut = IStandardExchangeIn(address(inHarness))
            .previewExchangeIn(IERC20(address(inHarness)), 10e18, IERC20(address(sRbt)));
        assertEq(previewOut, 10e18);

        uint256 srbtBefore = sRbt.balanceOf(alice);
        uint256 rbtBefore = inHarness.balanceOfRbt(alice);

        uint256 out = IStandardExchangeIn(address(inHarness))
            .exchangeIn(IERC20(address(inHarness)), 10e18, IERC20(address(sRbt)), 10e18, alice, false, block.timestamp);
        vm.stopPrank();

        assertEq(out, 10e18);
        assertEq(sRbt.balanceOf(alice) - srbtBefore, 10e18);
        assertEq(rbtBefore - inHarness.balanceOfRbt(alice), 10e18);
    }

    function test_exchangeIn_RbtToSrbt_belowPeg_reverts() public {
        _setBelowPeg();

        vm.startPrank(alice);
        vm.expectRevert();
        IStandardExchangeIn(address(inHarness))
            .previewExchangeIn(IERC20(address(inHarness)), 1e18, IERC20(address(sRbt)));
        vm.stopPrank();
    }

    function test_exchangeIn_SrbtToRbt_atPeg_supportedViaStandardFunction() public {
        // Give Alice sRBT to burn.
        sRbt.mint(alice, 10e18);

        _setAtPeg(10e18);

        vm.startPrank(alice);
        uint256 previewOut = IStandardExchangeIn(address(inHarness))
            .previewExchangeIn(IERC20(address(sRbt)), 10e18, IERC20(address(inHarness)));
        assertEq(previewOut, 10e18);

        uint256 srbtBefore = sRbt.balanceOf(alice);
        uint256 rbtBefore = inHarness.balanceOfRbt(alice);

        uint256 out = IStandardExchangeIn(address(inHarness))
            .exchangeIn(IERC20(address(sRbt)), 10e18, IERC20(address(inHarness)), 10e18, alice, false, block.timestamp);
        vm.stopPrank();

        assertEq(out, 10e18);
        assertEq(srbtBefore - sRbt.balanceOf(alice), 10e18);
        assertEq(inHarness.balanceOfRbt(alice) - rbtBefore, 10e18);
    }

    function test_exchangeOut_RbtToSrbt_supportedViaStandardFunction() public {
        _setAbovePeg();

        vm.startPrank(alice);
        uint256 previewIn = IStandardExchangeOut(address(outHarness))
            .previewExchangeOut(IERC20(address(outHarness)), IERC20(address(sRbt)), 5e18);
        assertEq(previewIn, 5e18);

        uint256 srbtBefore = sRbt.balanceOf(alice);
        uint256 rbtBefore = outHarness.balanceOfRbt(alice);

        uint256 amountIn = IStandardExchangeOut(address(outHarness))
            .exchangeOut(IERC20(address(outHarness)), 5e18, IERC20(address(sRbt)), 5e18, alice, false, block.timestamp);
        vm.stopPrank();

        assertEq(amountIn, 5e18);
        assertEq(sRbt.balanceOf(alice) - srbtBefore, 5e18);
        assertEq(rbtBefore - outHarness.balanceOfRbt(alice), 5e18);
    }

    function test_exchangeOut_RbtToSrbt_belowPeg_reverts() public {
        _setBelowPeg();

        vm.startPrank(alice);
        vm.expectRevert();
        IStandardExchangeOut(address(outHarness))
            .exchangeOut(IERC20(address(outHarness)), 1e18, IERC20(address(sRbt)), 1e18, alice, false, block.timestamp);
        vm.stopPrank();
    }

    function test_exchangeOut_RbtToSrbt_maxAmountExceeded_reverts() public {
        _setAbovePeg();

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MaxAmountExceeded.selector, 4e18, 5e18));
        IStandardExchangeOut(address(outHarness))
            .exchangeOut(IERC20(address(outHarness)), 4e18, IERC20(address(sRbt)), 5e18, alice, false, block.timestamp);
        vm.stopPrank();
    }

    function test_exchangeOut_SrbtToRbt_belowPeg_reverts() public {
        _setBelowPeg();
        sRbt.mint(alice, 10e18);

        vm.startPrank(alice);
        vm.expectRevert();
        IStandardExchangeOut(address(outHarness))
            .exchangeOut(IERC20(address(sRbt)), 1e18, IERC20(address(outHarness)), 1e18, alice, false, block.timestamp);
        vm.stopPrank();
    }

    function test_exchangeOut_deadlineExceeded_reverts() public {
        _setAbovePeg();

        vm.startPrank(alice);
        vm.expectRevert();
        IStandardExchangeOut(address(outHarness))
            .exchangeOut(IERC20(address(outHarness)), 1e18, IERC20(address(sRbt)), 1e18, alice, false, 0);
        vm.stopPrank();
    }

    function test_previewExchangeOut_SrbtToRbt_atPeg_returnsAmountOut() public {
        _setAtPeg(0);

        uint256 previewIn = IStandardExchangeOut(address(outHarness))
            .previewExchangeOut(IERC20(address(sRbt)), IERC20(address(outHarness)), 7e18);
        assertEq(previewIn, 7e18);
    }

    function test_exchangeOut_SrbtToRbt_atPeg_supportedViaStandardFunction() public {
        _setAtPeg(0);

        sRbt.mint(alice, 10e18);

        vm.startPrank(alice);
        uint256 srbtBefore = sRbt.balanceOf(alice);
        uint256 rbtBefore = outHarness.balanceOfRbt(alice);

        uint256 amountIn = IStandardExchangeOut(address(outHarness))
            .exchangeOut(IERC20(address(sRbt)), 7e18, IERC20(address(outHarness)), 7e18, alice, false, block.timestamp);
        vm.stopPrank();

        assertEq(amountIn, 7e18);
        assertEq(srbtBefore - sRbt.balanceOf(alice), 7e18);
        assertEq(outHarness.balanceOfRbt(alice) - rbtBefore, 7e18);
    }

    function test_previewExchangeIn_invalidRoute_reverts() public {
        _setAbovePeg();

        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(other), address(sRbt))
        );
        IStandardExchangeIn(address(inHarness)).previewExchangeIn(IERC20(address(other)), 1e18, IERC20(address(sRbt)));
    }

    function test_previewExchangeOut_invalidRoute_reverts() public {
        _setAbovePeg();

        vm.expectRevert(
            abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(other), address(sRbt))
        );
        IStandardExchangeOut(address(outHarness))
            .previewExchangeOut(IERC20(address(other)), IERC20(address(sRbt)), 1e18);
    }
}
