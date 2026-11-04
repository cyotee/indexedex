// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import {SeWeightedPartialDustSeed_Test} from "./SeWeightedPartialDustSeed.t.sol";

/// Business-logic adjudication variant: production configuration ownerOnlyLiquidity=true
/// (every production DETF deploy script sets it; fee-accrual config ownerOnlyLiquidity=true).
/// owner (= the honest partial-book LP, standing in for the DETF diamond) does the partial first mint;
/// the unprivileged attacker's dust seed must revert.
contract SeWeightedPartialDustSeedProdCfg_Test is SeWeightedPartialDustSeed_Test {
    function _pkgOwnerOnlyLiquidity() internal view override returns (bool) { return true; }
    function _pkgOwner() internal view override returns (address) { return user; }

    function test_prodCfg_attackerSeedReverts() public {
        _honestPartial(2);
        uint256[] memory seed = new uint256[](3);
        seed[2] = 1e9;
        _approveAll(attacker);
        address C = toks[2];
        (bool okMint,) = C.call(abi.encodeWithSignature("mint(address,uint256)", attacker, 1000e18));
        require(okMint);
        vm.prank(attacker);
        try weighted.joinProportional(seed, attacker, 0, block.timestamp + 1 days) returns (uint256, uint256[] memory) {
            console.log("PROD CFG: attacker seed ACCEPTED");
            fail();
        } catch (bytes memory err) {
            console.log("PROD CFG: attacker seed reverted, selector:");
            console.logBytes(err);
        }
        assertFalse(weighted.isFullBook(), "still partial");
    }

}
