"""Consolidate superseded D25 LP-close cases using the actual funded NFT surface."""
from pathlib import Path
import hashlib,json,re,sys
ROOT=Path(__file__).resolve().parents[2]; ART=Path(__file__).resolve().parent
folder=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
shared_imports='''import {Test} from "forge-std/Test.sol";
import {IERC721Errors} from "@crane/contracts/interfaces/IERC721Errors.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {DETFFundedBondTarget} from "contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
'''
behavior=(ART/'pending-v4-d25-behavior.txt').read_text()
wrappers='''
    function test_D25_fundedPrincipalAndRewardsPayOnlyStaking() public {
        (, uint256 id_) = _liveAliceBob();
        _assertD25FundedPayout(detfInfo, id_, d25Bob);
    }

    function test_D25_standingReceiptsAlreadyFundedBeforeClaim() public {
        (, uint256 id_) = _liveAliceBob();
        _assertD25StandingReceipts(detfInfo, id_, d25Bob);
    }

    function test_D25_reservedRolesCannotClaimPurchasedPrincipal() public {
        _liveAliceOnly();
        _assertD25ReservedPositions(detfInfo, d25Alice);
    }

    function test_D25_finalClaimRetainsProtocolLiquidity() public {
        uint256 id_ = _liveAliceOnly();
        _assertD25FinalClaim(detfInfo, id_, d25Alice);
    }
'''
records=[]
for suffix,sub in [('',folder),('_Decimals',folder/'decimals')]:
    base='UniswapV4Detf_Alignment_CloseD25Base'+suffix
    p=sub/(base+'.sol'); before=p.read_text()
    s=before[:before.index('    function _claimRewardsAs(')]+'}\n'
    s=s.replace(' is TestBase_UniswapV4Detf'+suffix+' {',' is TestBase_UniswapV4Detf'+suffix+', V4FundedD25Behavior {')
    s=re.sub(r'/// @notice Shared D25 close helpers[^\n]*',
                '/// @notice Shared funded D25 fixtures; deployment and native funding stay in the gold TestBase.',s)
    s=s.replace('/// @dev Pons V1 wrap can leave last-close DETF rejoin below MINIMUM_LIQUIDITY. Seed pair via mint.',
                '/// @dev Retain provider-specific live reserve seeding before the final funded claim.')
    if not suffix:
        at=s.index('/// @notice Shared funded')
        s=s[:at]+shared_imports+'\n'+behavior+'\n'+s[at:]
    else:
        s=s.replace('pragma solidity ^0.8.0;', 'pragma solidity ^0.8.0;\n\nimport {V4FundedD25Behavior} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25Base.sol";')
    records.append((p,before,s))
    p=sub/('UniswapV4Detf_Alignment_CloseD25OpenBase'+suffix+'.sol')
    before=p.read_text()
    s=before[:before.index('    /// @notice Close pays')]+wrappers+'}\n'
    s=s.replace('Stage 11 Open D25 IDs (PRD §7.0 / §7.4). Gold CP inherits this.',
                'D32 funded replacements for D25; shared by actual provider fixtures.')
    records.append((p,before,s))

p=folder/'UniswapV4Detf_Quad_Alignment_CloseD25.t.sol'; before=p.read_text()
s=before[:before.index('    function _detfIndex(')]+'}\n'
s=s.replace('UniswapV4Detf_Alignment_CloseD25Base','UniswapV4Detf_Alignment_CloseD25OpenBase')
s=re.sub(r'/// @notice Quad gold D25.*?contract ', '/// @notice Actual Quad binding of the shared funded D25 assertions.\ncontract ',s,flags=re.S)
records.append((p,before,s))

# Pons has independent deployment helpers. Reuse assertions without changing host setup.
for suffix,sub in [('',folder/'pons'),('_Decimals',folder/'pons/decimals')]:
    p=sub/('UniswapV4Detf_PonsV2Se_ProductLaw'+suffix+('.sol' if suffix else '.t.sol'))
    before=p.read_text();s=before
    start=s.index('    function test_D25_1_'); end=s.index('    function test_compound_',start)
    s=s[:start]+wrappers+'\n'+s[end:]
    s=s.replace('pragma solidity ^0.8.0;', 'pragma solidity ^0.8.0;\n\nimport {V4FundedD25Behavior} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25Base.sol";')
    s=s.replace('is UniswapV4Detf_PonsV2Se_Stage11Helpers'+suffix+' {','is UniswapV4Detf_PonsV2Se_Stage11Helpers'+suffix+', V4FundedD25Behavior {')
    records.append((p,before,s))
    p=sub/('UniswapV4Detf_PonsV2Se_Stage11Helpers'+suffix+'.sol')
    before=p.read_text();s=before
    start=s.index('    function _closeAs(');end=s.index('    function _claimRewardsAs(',start)
    s=s[:start]+s[end:]
    records.append((p,before,s))

for p,b,s in records:
    if '--apply' in sys.argv:p.write_text(s)
    else:(ART/('pending-funded-d25-'+p.name+'.txt')).write_text(s)
mapping={
 'D25-1, D25-2, D25-4, D25-6':'fundedPrincipalAndRewardsPayOnlyStaking: exact independent previews and sDETF receipts, raw supply/backing and all reserve token/LP balances unchanged',
 'D25-3':'standingReceiptsAlreadyFundedBeforeClaim: actual fee/creator sDETF funded before claim, no LP liability or claim-time issuance',
 'D25-5':'reservedRolesCannotClaimPurchasedPrincipal: typed reserved-role rejection',
 'D25-7, D25-lastClose':'finalClaimRetainsProtocolLiquidity: combined preview exact, last NFT retirement, protocol LP preserved and no new standing-recipient income'
}
record={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','decision':'D32 supersedes LP basket-close and id-0 rejoin economics','consolidation':'Eight cases become four per existing concrete D25 provider/native-unit fixture; common financial assertions implemented once. Actual host setup and test inheritance retained.','coverage_mapping':mapping,'files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in records]}
(ART/('v4-d25-funded-consolidation.json' if '--apply' in sys.argv else 'pending-v4-d25-funded-consolidation.json')).write_text(json.dumps(record,indent=2)+'\n')
print(record['status'],len(records),'files')
