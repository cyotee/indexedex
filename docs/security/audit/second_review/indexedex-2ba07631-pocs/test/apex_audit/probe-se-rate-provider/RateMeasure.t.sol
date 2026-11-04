// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {
    TestBase_CommonBufferMultiVaultStablePool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultStablePool.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

contract RateMeasure is TestBase_CommonBufferMultiVaultStablePool {
    IRateProvider rp;
    address face;

    function setUp() public override {
        super.setUp();
        face = address(seVault);
        rp = IRateProvider(RateProviderFixtureLib.providerFor(create3Factory, diamondPackageFactory, cbmvsPool, face));
    }

    function _log(string memory tag) internal view returns (uint256 r, uint256 m) {
        r = rp.getRate();try IStandardExchangeIn(cbmvsPool).previewExchangeIn(IERC20(cbmvsPool), 1e18, IERC20(face)) returns (uint256 mm, uint256) { m = mm; } catch { console2.log("  marginal preview REVERTS"); m = 1; }try IStandardExchangeIn(cbmvsPool).previewExchangeIn(IERC20(face), 1e18, IERC20(cbmvsPool)) returns (uint256 bj, uint256) { console2.log("  join 1 face -> BPT", bj); } catch { console2.log("  join preview REVERTS"); }
        (IERC20[] memory toks,, uint256[] memory bals,) = bv3Vault.getPoolTokenInfo(cbmvsPool);
        console2.log(tag);
        console2.log("  rp.getRate      ", r);
        console2.log("  marginal 1 BPT->face", m);
        console2.log("  ratio rp/marg (1e18)", r * 1e18 / m);
        for (uint256 i; i < toks.length; ++i) console2.log("  bal", address(toks[i]), bals[i]);
        console2.log("  supply", IERC20(cbmvsPool).totalSupply());
    }

    function _round(uint256 dIn) internal {
        address atk = bob;
        uint256 s = mintSharesForVault(0, atk, dIn * 2);
        uint256 daiOut = swapExactIn(atk, IERC20(face), IERC20(address(dai)), dIn);
        console2.log("swapped face in", dIn, "dai out", daiOut);
        _log("after push face in");
        uint256 back = swapExactIn(atk, IERC20(address(dai)), IERC20(face), daiOut);
        console2.log("restore face back", back);
        _log("restored");
    }

    function test_measure_100() public { _log("rest"); _round(100e18); }
    function test_measure_rev() public {
        address atk = bob;
        _mintToken(address(dai), atk, 300e18);
        uint256 out = swapExactIn(atk, IERC20(address(dai)), IERC20(face), 300e18);
        console2.log("dai in 300 face out", out);
        _log("after push dai in");
    }
    function test_measure_300() public { _round(300e18); }
    function test_measure_600() public { _round(600e18); }
}
