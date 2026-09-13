"""Prepare/apply funded replacements for existing provider lifecycle tests."""
from pathlib import Path
import hashlib, json, re, sys
ROOT=Path(__file__).resolve().parents[2]
ART=Path(__file__).resolve().parent
records=[]
helper='''
    /// @dev Exercise the actual purchased bond, its funded payout and one-to-one unstaking.
    /// All protocol reserve LP remains in custody throughout maturity and redemption.
    function _assertFundedMatureClaim(address d_, uint256 id_, address holder_)
        internal returns (uint256 principal_, uint256 rewards_)
    {
        IUniswapV4Detf info_ = IUniswapV4Detf(d_);
        IDetfBondNFT nft_ = IDetfBondNFT(info_.bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        uint256 maturity_ = position_.startTimestamp + position_.vestingDuration;
        if (block.timestamp < maturity_) vm.warp(maturity_);
        IDETFFundedRewards(d_).synchronizeRewards();
        DETFFundedStakingMath.BondClaim memory quote_ = nft_.previewClaim(id_);
        assertEq(quote_.principalDue, position_.principal - position_.claimedPrincipal, "all remaining principal vested");
        IERC20 staking_ = IERC20(info_.rebasingClaimToken());
        uint256 before_ = staking_.balanceOf(holder_);
        bytes32 custody_ = _fundedLifecycleCustody(d_);
        vm.prank(holder_);
        (principal_, rewards_) = nft_.claimBond{gas: 30_000_000}(id_, holder_);
        assertEq(principal_, quote_.principalDue, "principal preview equals execution");
        assertEq(rewards_, quote_.rewardsDue, "funded reward preview equals execution");
        uint256 paid_ = principal_ + rewards_;
        assertGt(paid_, 0, "funded sDETF paid");
        assertEq(staking_.balanceOf(holder_) - before_, paid_, "exact sDETF payout");
        assertEq(_fundedLifecycleCustody(d_), custody_, "claim retains protocol LP and DETF supply");
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, id_));
        nft_.ownerOf(id_);
        _assertFundedUnstake(d_, holder_, paid_);
        assertEq(_fundedLifecycleCustody(d_), custody_, "unstaking retains protocol LP and DETF supply");
    }

    function _fundedLifecycleCustody(address d_) private view returns (bytes32) {
        IUniswapV4Detf info_ = IUniswapV4Detf(d_);
        IERC20 lp_ = IERC20(info_.hook());
        return keccak256(abi.encode(IERC20(d_).totalSupply(), lp_.balanceOf(d_), lp_.balanceOf(info_.bondNftVault())));
    }

    function _assertFundedUnstake(address d_, address holder_, uint256 amount_) internal {
        IStakedDETF staking_ = IStakedDETF(IUniswapV4Detf(d_).rebasingClaimToken());
        uint256 before_ = IERC20(d_).balanceOf(holder_);
        assertEq(staking_.previewExchangeIn(IERC20(address(staking_)), amount_, IERC20(d_)), amount_, "one-to-one unstake quote");
        vm.prank(holder_);
        uint256 out_ = staking_.exchangeIn(
            IERC20(address(staking_)), amount_, IERC20(d_), amount_, holder_, false, block.timestamp + 1 hours
        );
        assertEq(out_, amount_, "one-to-one unstake execution");
        assertEq(IERC20(d_).balanceOf(holder_) - before_, amount_, "actual held DETF redemption");
    }
'''
imports='''import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
'''
for suffix in ('','_Decimals'):
 p=ROOT/f'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf{suffix}.sol'
 before=p.read_text(); assert '_assertFundedMatureClaim' not in before
 at=before.index(';',before.index('pragma solidity'))+1
 source=before[:at]+'\n'+imports+before[at:]
 end=source.rfind('}'); source=source[:end]+helper+source[end:]
 records.append((p,before,source,['Shared owner-authorized funded principal/reward claim, NFT retirement, exact held-DETF unstake, actual custody conservation.']))
root=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se'
for p in sorted(root.rglob('*.sol')):
 before=p.read_text(); source=before; edits=[]; mapping=[]
 for m in re.finditer(r'    function (test_\w+_close)\(\) public(?: virtual)?\s*\{', before):
  opening=before.index('{',m.start()); depth=1;end=opening+1
  while depth:
   depth+=(before[end]=='{')-(before[end]=='}');end+=1
  body=before[opening+1:end-1]
  if 'closeBondMature' not in body: continue
  cut=body.find('        address[] memory toks =')
  minimal = cut < 0
  if minimal: cut=body.find('        vm.warp(')
  if cut<0: raise ValueError(str(p)+' nonstandard close fixture requires manual migration')
  setup=body[:cut].rstrip()
  replacement=before[m.start():opening+1]+setup+'''
        _assertSeAllowancesZero();
        _assertFundedMatureClaim(detf, tokenId, detfUser);
        _assertR19();
        _assertSeAllowancesZero();
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) {
                assertLe(IERC20(toks[i]).balanceOf(reserveHook), 10, "hook pair <=10 wei");
            }
        }
    }'''
  if minimal:
   assert '_assertR19' not in body and '_assertSeAllowancesZero' not in body
   replacement=before[m.start():opening+1]+setup+'\n        _assertFundedMatureClaim(detf, tokenId, detfUser);\n    }'
  edits.append((m.start(),end,replacement))
  mapping.append({'test':m.group(1),'retired_expectations':['reserve basket paid to bond owner','zero DETF basket slot','original LP shares cleared'], 'replacement':'Funded mature principal plus independently funded rewards paid as sDETF, NFT retirement, exact 1:1 DETF redemption, unchanged protocol LP; provider setup and R19/allowance diagnostics retained.'})
 if not edits:continue
 for a,b,replacement in reversed(edits):source=source[:a]+replacement+source[b:]
 # All these burn fixtures issue immediately before burning with no elapsed epoch.
 # Capture the token-specific branch before execution instead of assuming every burn is primary.
 source=source.replace('        uint256 supplyBefore = IERC20(detf).totalSupply();','        uint256 supplyBefore = IERC20(detf).totalSupply();\n        bool primaryBurn = detfInfo.isBurningAllowed(IERC20(mintToken));')
 source=source.replace('supplyBefore - burnIn, "DETF supply"','supplyBefore - (primaryBurn ? burnIn : 0), "primary burn or supply-neutral reserve swap"')
 mapping.append({'burn_supply':'No epoch elapses between the fixture mint and burn; actual selected primary branch burns supply, reserve-swap fallback is supply-neutral.'})
 records.append((p,before,source,mapping))
for p,before,source,mapping in records:
 if '--apply' in sys.argv:p.write_text(source)
 else:(ART/('pending-funded-'+p.name+'.txt')).write_text(source)
record={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; no Solidity edits', 'files':[{'path':str(p.relative_to(ROOT)), 'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest(),'mapping':m} for p,b,s,m in records]}
(ART/('v4-provider-funded-lifecycle-migration.json' if '--apply' in sys.argv else 'pending-v4-provider-funded-lifecycle-migration.json')).write_text(json.dumps(record,indent=2)+'\n')
print(record['status'],len(records),'files')
