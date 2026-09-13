// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_CommonBufferMultiVaultStablePool_Decimals} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultStablePool_Decimals.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {
    ICommonBufferMultiVaultStablePool
} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePool.sol";
import {ICommonBufferMultiVaultStablePoolPkg} from "contracts/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/ICommonBufferMultiVaultStablePoolPkg.sol";

/**
 * @title CommonBufferMultiVaultStable_WalkAndExhaust
 * @notice S11 walk: first vault fails SE I/O, second succeeds; AllVaultsExhausted when all fail.
 * @dev HostileSE_V3PooStaCom is a non-SUT harness (mintable SE double). SUT remains production pool/pkg/registry.
 */
abstract contract CommonBufferMultiVaultStable_WalkAndExhaust_Decimals is TestBase_CommonBufferMultiVaultStablePool_Decimals {
    function _targetVaultCount() internal pure override returns (uint8) {
        return 1; // default fixture unused for custom deploys
    }

    /// @notice Deposit walk: hostile vault0 fails exchangeIn; real vault1 succeeds.
    function test_S11_walk_deposit_secondVaultSucceeds() public {
        HostileSE_V3PooStaCom h0 = new HostileSE_V3PooStaCom(IERC20(address(rateAsset)));
        h0.mintShares(alice, CBMVS_INIT_SHARES * 5);
        rateAsset.mint(address(h0), CBMVS_INIT_BUFFER * 5);
        rateAsset.mint(alice, CBMVS_INIT_BUFFER * 5);
        mintSharesForVault(0, alice, CBMVS_INIT_SHARES * 5);

        address pool = _deployTwoVaultPool(IStandardExchange(address(h0)), IStandardExchange(address(seVault)));
        _initTwoVaultPool(pool, address(h0), address(seVault));

        ICommonBufferMultiVaultStablePool p = ICommonBufferMultiVaultStablePool(pool);
        // Equal init depths → shallowest = 0 (lowest index). Force fail on vault0 deposit.
        h0.setFailExchangeIn(true);

        uint256 vBefore = p.virtualBuffer();
        int256 d1Before = p.hookShareDelta(1);
        uint256 amt = _from18(address(rateAsset), 100e18);
        rateAsset.mint(alice, amt);
        vm.startPrank(alice);
        rateAsset.approve(address(router), type(uint256).max);
        uint256 out = router.swapSingleTokenExactIn(
            pool, IERC20(address(rateAsset)), IERC20(address(seVault)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
        assertGt(out, 0);
        uint8 dBuf = rateAsset.decimals();
        uint256 bump = dBuf >= 18 ? amt : amt * (10 ** (18 - uint256(dBuf)));
        assertEq(p.virtualBuffer(), vBefore + bump);
        assertGt(p.hookShareDelta(1), d1Before, "walk deposited into vault1 after vault0 fail");
    }

    /// @notice Pre-seat walk: hostile fails exchangeOut; real vault delivers buffer.
    function test_S11_walk_preSeat_secondVaultSucceeds() public {
        HostileSE_V3PooStaCom h0 = new HostileSE_V3PooStaCom(IERC20(address(rateAsset)));
        h0.mintShares(alice, CBMVS_INIT_SHARES * 5);
        rateAsset.mint(address(h0), CBMVS_INIT_BUFFER * 5);
        mintSharesForVault(0, alice, CBMVS_INIT_SHARES * 5);

        address pool = _deployTwoVaultPool(IStandardExchange(address(h0)), IStandardExchange(address(seVault)));
        _initTwoVaultPool(pool, address(h0), address(seVault));

        ICommonBufferMultiVaultStablePool p = ICommonBufferMultiVaultStablePool(pool);
        h0.setFailExchangeOut(true);

        // Sell real SE shares for buffer - equal depth redeem rank tries index 0 first (fails) then seVault.
        uint256 amt = 20e18;
        assertGe(IERC20(address(seVault)).balanceOf(alice), amt);
        uint256 vBefore = p.virtualBuffer();
        vm.startPrank(alice);
        IERC20(address(seVault)).approve(address(router), type(uint256).max);
        uint256 out = router.swapSingleTokenExactIn(
            pool, IERC20(address(seVault)), IERC20(address(rateAsset)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
        assertGt(out, 0, "walk pre-seat via real vault");
        assertLt(p.virtualBuffer(), vBefore);
    }

    /// @notice Both vaults fail exchangeIn → AllVaultsExhausted.
    function test_S11_allVaultsExhausted_selector() public {
        HostileSE_V3PooStaCom h0 = new HostileSE_V3PooStaCom(IERC20(address(rateAsset)));
        HostileSE_V3PooStaCom h1 = new HostileSE_V3PooStaCom(IERC20(address(rateAsset)));
        h0.mintShares(alice, CBMVS_INIT_SHARES * 3);
        h1.mintShares(alice, CBMVS_INIT_SHARES * 3);
        rateAsset.mint(address(h0), CBMVS_INIT_BUFFER * 3);
        rateAsset.mint(address(h1), CBMVS_INIT_BUFFER * 3);

        address pool = _deployTwoVaultPool(IStandardExchange(address(h0)), IStandardExchange(address(h1)));
        _initTwoVaultPool(pool, address(h0), address(h1));

        h0.setFailExchangeIn(true);
        h1.setFailExchangeIn(true);

        uint256 amt = _from18(address(rateAsset), 5e18);
        rateAsset.mint(alice, amt);
        vm.startPrank(alice);
        rateAsset.approve(address(router), type(uint256).max);
        vm.expectRevert(ICommonBufferMultiVaultStablePool.AllVaultsExhausted.selector);
        router.swapSingleTokenExactIn(
            pool, IERC20(address(rateAsset)), IERC20(address(h0)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
    }

    /// @notice Both vaults fail exchangeOut on pre-seat → AllVaultsExhausted.
    function test_S11_preSeat_allVaultsExhausted_selector() public {
        HostileSE_V3PooStaCom h0 = new HostileSE_V3PooStaCom(IERC20(address(rateAsset)));
        HostileSE_V3PooStaCom h1 = new HostileSE_V3PooStaCom(IERC20(address(rateAsset)));
        h0.mintShares(alice, CBMVS_INIT_SHARES * 5);
        h1.mintShares(alice, CBMVS_INIT_SHARES * 5);
        rateAsset.mint(address(h0), CBMVS_INIT_BUFFER * 5);
        rateAsset.mint(address(h1), CBMVS_INIT_BUFFER * 5);

        address pool = _deployTwoVaultPool(IStandardExchange(address(h0)), IStandardExchange(address(h1)));
        _initTwoVaultPool(pool, address(h0), address(h1));

        h0.setFailExchangeOut(true);
        h1.setFailExchangeOut(true);

        uint256 amt = 20e18;
        assertGe(IERC20(address(h0)).balanceOf(alice), amt);
        vm.startPrank(alice);
        IERC20(address(h0)).approve(address(router), type(uint256).max);
        vm.expectRevert(ICommonBufferMultiVaultStablePool.AllVaultsExhausted.selector);
        router.swapSingleTokenExactIn(
            pool, IERC20(address(h0)), IERC20(address(rateAsset)), amt, 0, type(uint256).max, false, bytes("")
        );
        vm.stopPrank();
    }

    function _deployTwoVaultPool(IStandardExchange v0, IStandardExchange v1) internal returns (address pool) {
        for (uint256 i; i < users.length; ++i) {
            vm.startPrank(users[i]);
            IERC20(address(v0)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(v0), address(router), type(uint160).max, type(uint48).max);
            IERC20(address(v1)).approve(address(permit2), type(uint256).max);
            permit2.approve(address(v1), address(router), type(uint160).max, type(uint48).max);
            rateAsset.approve(address(permit2), type(uint256).max);
            permit2.approve(address(rateAsset), address(router), type(uint160).max, type(uint48).max);
            vm.stopPrank();
        }
        IStandardExchange[] memory vaults = new IStandardExchange[](2);
        vaults[0] = v0;
        vaults[1] = v1;
        IRateProvider[] memory rps = new IRateProvider[](2);
        pool = cbmvsPkg.deployPool(
            ICommonBufferMultiVaultStablePoolPkg.PkgArgs({
                bufferToken: IERC20(address(rateAsset)),
                vaultCount: 2,
                standardExchangeVaults: vaults,
                vaultShareRateProviders: rps,
                amplificationParameter: CBMVS_AMP
            })
        );
        approveForPool(IERC20(pool));
    }

    function _initTwoVaultPool(address pool, address share0, address share1) internal {
        uint256 bufAmt = _from18(address(rateAsset), CBMVS_INIT_BUFFER);
        rateAsset.mint(alice, bufAmt * 4);
        vm.startPrank(alice);
        rateAsset.approve(address(router), type(uint256).max);
        IERC20(share0).approve(address(router), type(uint256).max);
        IERC20(share1).approve(address(router), type(uint256).max);
        (IERC20[] memory toks,,,) = bv3Vault.getPoolTokenInfo(pool);
        uint256[] memory amounts = new uint256[](toks.length);
        for (uint256 i; i < toks.length; ++i) {
            if (address(toks[i]) == address(rateAsset)) {
                amounts[i] = bufAmt;
            } else {
                amounts[i] = CBMVS_INIT_SHARES;
            }
        }
        router.initialize(pool, toks, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }
}

/// @dev Minimal hostile SE for walk/exhaust tests (non-SUT double).
contract HostileSE_V3PooStaCom {
    string public name = "HostileSE_V3PooStaCom";
    string public symbol = "hSE";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable bufferToken;
    bool public failExchangeIn;
    bool public failExchangeOut;

    constructor(IERC20 bufferToken_) {
        bufferToken = bufferToken_;
    }

    function setFailExchangeIn(bool v) external {
        failExchangeIn = v;
    }

    function setFailExchangeOut(bool v) external {
        failExchangeOut = v;
    }

    function mintShares(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function previewExchangeIn(IERC20, uint256 amountIn, IERC20) external pure returns (uint256) {
        return amountIn;
    }

    function exchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20, uint256, address recipient, bool, uint256)
        external
        returns (uint256 amountOut)
    {
        if (failExchangeIn) revert("HostileSE_V3PooStaCom: exchangeIn");
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        amountOut = amountIn;
        balanceOf[recipient] += amountOut;
        totalSupply += amountOut;
    }

    function previewExchangeOut(IERC20, IERC20, uint256 amountOut) external pure returns (uint256) {
        return amountOut;
    }

    function exchangeOut(
        IERC20,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool,
        uint256
    ) external returns (uint256 amountIn) {
        if (failExchangeOut) revert("HostileSE_V3PooStaCom: exchangeOut");
        amountIn = amountOut;
        require(amountIn <= maxAmountIn, "maxIn");
        balanceOf[msg.sender] -= amountIn;
        totalSupply -= amountIn;
        tokenOut.transfer(recipient, amountOut);
    }
}
