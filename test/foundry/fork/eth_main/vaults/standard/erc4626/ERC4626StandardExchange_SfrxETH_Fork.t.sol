// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IsfrxETH} from "@crane/contracts/protocols/tokens/stable/frax/FraxETH/IsfrxETH.sol";
import {IfrxETHMinter} from "@crane/contracts/protocols/tokens/stable/frax/FraxETH/IfrxETHMinter.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";

/**
 * @title ERC4626StandardExchange_SfrxETH_Fork
 * @notice Production-first fork proof: deploy generic ERC-4626 SE via registry on mainnet sfrxETH;
 *         assert vaultTokens membership and deposit/redeem routes.
 */
contract ERC4626StandardExchange_SfrxETH_Fork is TestBase_ERC4626StandardExchange {
    address constant SFRX_ETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address constant FRX_ETH = 0x5E8422345238F34275888049021821E8E08CAa1f;
    address constant FRX_ETH_MINTER = 0xbAFA44EFE7901E04E39Dad13167D089C559c1138;

    address internal seVault;
    address internal underlying; // frxETH

    function setUp() public override {
        // Fork mainnet before IndexedEx deploys so production addresses resolve
        string memory rpc;
        try vm.rpcUrl("ethereum_mainnet_alchemy") returns (string memory r) {
            rpc = r;
        } catch {
            try vm.rpcUrl("ethereum_mainnet_infura") returns (string memory r2) {
                rpc = r2;
            } catch {
                try vm.envString("ETH_RPC_URL") returns (string memory r3) {
                    rpc = r3;
                } catch {
                    vm.skip(true);
                    return;
                }
            }
        }
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        try this._fork(rpc) {}
        catch {
            vm.skip(true);
            return;
        }

        TestBase_ERC4626StandardExchange.setUp();

        underlying = IERC4626(SFRX_ETH).asset();
        assertEq(underlying, FRX_ETH, "sfrxETH asset is frxETH");

        seVault = _deployERC4626SE(SFRX_ETH);
        assertTrue(seVault != address(0), "vault deployed via registry");
    }

    function _fork(string memory rpc) external {
        vm.createSelectFork(rpc);
    }

    function test_Fork_VaultTokens_LengthAndMembership() public {
        address[] memory tokens = IBasicVault(seVault).vaultTokens();
        assertEq(tokens.length, 2, "vaultTokens length == 2");
        bool hasVault;
        bool hasAsset;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == SFRX_ETH) hasVault = true;
            if (tokens[i] == underlying) hasAsset = true;
        }
        assertTrue(hasVault, "protocol vault in vaultTokens");
        assertTrue(hasAsset, "underlying asset in vaultTokens");
    }

    function test_Fork_DepositRedeem_SfrxETH() public {
        // Acquire frxETH via minter, wrap to sfrxETH, then deposit into SE
        uint256 ethIn = 1 ether;
        vm.deal(address(this), ethIn + 1 ether);
        uint256 sfrxShares = IfrxETHMinter(FRX_ETH_MINTER).submitAndDeposit{value: ethIn}(address(this));
        assertGt(sfrxShares, 0, "got sfrxETH");

        IERC20(SFRX_ETH).approve(seVault, sfrxShares);
        uint256 seOut = IStandardExchangeIn(seVault).exchangeIn(
            IERC20(SFRX_ETH),
            sfrxShares,
            IERC20(seVault),
            0,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertGt(seOut, 0, "SE shares minted");
        assertEq(IERC20(seVault).balanceOf(address(this)), seOut);

        // Redeem SE → sfrxETH (protocol vault). exchangeOut amountOut = vault tokens desired.
        uint256 half = seOut / 2;
        uint256 vaultHeld = IERC20(SFRX_ETH).balanceOf(seVault);
        uint256 vaultOutWanted = vaultHeld / 2;
        require(vaultOutWanted > 0, "se must hold protocol vault tokens");
        uint256 sfrxBefore = IERC20(SFRX_ETH).balanceOf(address(this));
        uint256 spent = IStandardExchangeOut(seVault).exchangeOut(
            IERC20(seVault),
            half + 1, // max SE shares (allow 1 wei rounding headroom)
            IERC20(SFRX_ETH),
            vaultOutWanted,
            address(this),
            false,
            block.timestamp + 1 hours
        );
        assertGt(spent, 0, "spent some SE shares");
        assertLe(spent, half + 1, "did not overspend SE shares");
        assertEq(IERC20(SFRX_ETH).balanceOf(address(this)) - sfrxBefore, vaultOutWanted, "sfrx recovered");
    }

    function test_Fork_DepositUnderlying_FrxETH_Path() public {
        uint256 ethIn = 0.5 ether;
        vm.deal(address(this), ethIn + 1 ether);
        // Mint frxETH only (submit, not deposit)
        IfrxETHMinter(FRX_ETH_MINTER).submit{value: ethIn}();
        uint256 frxBal = IERC20(FRX_ETH).balanceOf(address(this));
        assertGt(frxBal, 0);

        IERC20(FRX_ETH).approve(seVault, frxBal);
        uint256 seOut = IStandardExchangeIn(seVault).exchangeIn(
            IERC20(FRX_ETH), frxBal, IERC20(seVault), 0, address(this), false, block.timestamp + 1 hours
        );
        assertGt(seOut, 0, "SE from underlying path");
    }
}
