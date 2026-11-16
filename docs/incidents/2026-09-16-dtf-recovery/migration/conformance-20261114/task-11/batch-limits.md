# Task 11 batch limits

Gas-only evidence for current bytecode, chain 4663, historical block 108944663
(0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733).
The authenticated transaction limit is 32,000,000; the recorded header limit
is 0x4000000000000, so the applicable minimum is 32,000,000. The local 100m
block setting is never the admission policy. The retained raw policy log is
`docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery/implementation/chain-gas-limits.log`, SHA-256 `8c6e29f6470180b1f429f737586a6048b121a1200029d3bc9759eb50af04485f`.
`signed-envelopes/source-manifest.json` binds its historical diagnosis record.

Largest tested admitted shapes: loading 64 recipients with one whole original
each; independent issuance 32 recipients with one whole original each; one
recipient with 64 whole originals for loading and issuance. These axes do not
admit their Cartesian product or arbitrary calldata. The 3/2 estimate envelope
for each admitted sample fits the ceiling. Existing operator operations select
one complete recipient, so no production signing/resume mismatch was exposed
and no global signing-policy change was made. Regroup only between complete
records; never split or merge an economic original. The Foundry 64-recipient
issuance is measured above the limit, and its actual capped local simulation
rejects before signing/sending with unchanged nonce.

Recovery admits up to eight WeightedClaim stages or one other typed step.
The signed samples cover one and eight at custody populations 8 and 24, plus
one WeightedUnstake. Recovery samples are independent local snapshot branches:
each receipt was checked canonical at capture, then the branch was reverted
to preserve identical selected source state. They are historical experiment
receipts, not simultaneously surviving final-chain receipts. The existing
fork gas suite separately asserts selected cost is independent of 24 unrelated
surrenders. Holder transfers/approvals/surrenders are fixture setup, not admitted
gas samples; their permissive envelopes do not establish target feasibility.

Two distinct owners/parents retain two-step preparation/publication and four
signed 32m construction receipts. Historical preparations 19,746,568/19,595,700
and publications 29,905,302/29,344,006 remain historical-source observations;
the new table/receipt files carry current measurements. No obsolete
44,353,454 number is substituted.

Every number below occurs in `attempt-signed-final/raw.log`; receipts and signed
bytes are in `signed-envelopes/{transactions,constrained-receipts,operation-gas}.json`.
Accepting command argv and exit codes are in each attempt's raw.log/commands.json.
Earlier failed attempts remain recorded and are not successful measurements.

| Operation | Selected | Originals per recipient | Unrelated configured/custody population | Estimate | Signed gas | Actual gasUsed | Transaction |
| --- | ---: | --- | ---: | ---: | ---: | ---: | --- |
| configureIndependentAllocations | 1 | 1 | 0 | 551558 | 32000000 | 543427 | 0x9653b4adc460f964c342f4ec18172de239fe5d7ac4328850e454d84d6d312f2b |
| issueIndependentAllocations | 1 | 1 | 0 | 1027798 | 32000000 | 850202 | 0x09c337944e774f134e28394caab64d35cff189d34868dea3b6bff6dafd3ebcbd |
| configureIndependentAllocations | 8 | 1,1,1,1,1,1,1,1 | 1 | 2505017 | 32000000 | 2466612 | 0xb0fcab201c4f1d7d4d6af9e3b24586bb7923d422952f8f7bc03ffd8740a336e8 |
| issueIndependentAllocations | 8 | 1,1,1,1,1,1,1,1 | 1 | 5269849 | 32000000 | 4150454 | 0x2e1e6ff3c64065e7f8f7cfc6827f867d1d47adb4fc0516470e7d935f6d94d314 |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 9 | 4737828 | 32000000 | 4664820 | 0x207e04c9d788a9ac3adbfefa4db0535b56ee6f38a34d3c21dde0653cb73a9ad4 |
| issueIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 9 | 10260242 | 32000000 | 8080476 | 0x89edb0809b4269eeead8534b33c124a0adfa0ef4d3ddcb5cc7b128224570c6df |
| configureIndependentAllocations | 32 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 25 | 9204137 | 32000000 | 9061913 | 0xdadb95ca8b2619a811ba6bf164fd9ff3ea845efbab688065b2762509368618e5 |
| issueIndependentAllocations | 32 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 25 | 20241378 | 32000000 | 15940796 | 0xdb202e9eae7d3febe8d4ea5730e6bf9deabdd9b952c14c61843dd1d30b65d110 |
| configureIndependentAllocations | 64 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 57 | 18139789 | 32000000 | 17859090 | 0x2acc5421120ced1efffa8372d6c660720ee717d89b45f1952a6aa4f3a88adbe6 |
| configureIndependentAllocations | 1 | 1 | 121 | 551558 | 32000000 | 543427 | 0xe6cba50afeb4060e47efce24edc76308a51ad8b502253ddf061c594c21e2a579 |
| issueIndependentAllocations | 1 | 1 | 121 | 903316 | 32000000 | 727665 | 0x7f5a36d8db53016af669e37cc885a233af42fa20bce129f13d1cf0c571fe5119 |
| configureIndependentAllocations | 1 | 8 | 122 | 1846238 | 32000000 | 1818003 | 0x85fde4d98546619f62d1abceacc02b560709619dc8300beb44ed32515d294ea3 |
| issueIndependentAllocations | 1 | 8 | 122 | 1222576 | 32000000 | 1041937 | 0xcc0fff9b5e5d519efd834cbe9ccad863def111900bb2ff8d137d23ead67ba94c |
| configureIndependentAllocations | 1 | 16 | 123 | 3326117 | 32000000 | 3274903 | 0xc8714b91a35173ffb2e0111ea3a1e50962cad70ea5fe34ca3879ed66f7eddc1b |
| issueIndependentAllocations | 1 | 16 | 123 | 1587457 | 32000000 | 1401117 | 0xbc915dc838150db6a2c40d0bf08cddbd722a80e518c1e98ffcaa4d7c7d94898c |
| configureIndependentAllocations | 1 | 32 | 124 | 6286538 | 32000000 | 6189354 | 0xcf866a7619d29448ca099e9aa6b3a2e2098b6cdb037811d2067853e77913e35b |
| issueIndependentAllocations | 1 | 32 | 124 | 2317196 | 32000000 | 2119453 | 0xfc302ca8eb03ca00f41a1e0936736654c896345f1bfc2e89d589e58e820a2c2d |
| configureIndependentAllocations | 1 | 64 | 125 | 12210159 | 32000000 | 12020993 | 0x235b800d25bfbed42b939881cda827ead2c706c91dc046779de03a60eca12555 |
| issueIndependentAllocations | 1 | 64 | 125 | 3776672 | 32000000 | 3556125 | 0xba9048f6d7d545a49f042e2779b1501f6b800f844db5c3bd0a9eacb621261d32 |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 126 | 4737804 | 32000000 | 4664796 | 0x26dda692c454cd46f8ba9373cda1fda9c6dcdbeed827f7a3cf74b985cfb902b3 |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 142 | 4737816 | 32000000 | 4664808 | 0xd7edf286d8c05d6015d61013b6ab38734f7226d6ca6cceb4f0ec5a90cee0b2f3 |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 158 | 4737840 | 32000000 | 4664832 | 0xd36bc62bcdb4eb33842255aa535bcea9452e785b0ddbdff2d6237e986be954e0 |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 174 | 4737852 | 32000000 | 4664844 | 0xd55f08d0e90f297a312266d32877586331f52bcd947012d189f46cae504a85fe |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 190 | 4737792 | 32000000 | 4664784 | 0x3cd000069078ad21d879c9637bfaea6447d461dc509220fdedcb1d538d0321fd |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 206 | 4737840 | 32000000 | 4664832 | 0x79606c3058a873e53174bbd6c4e6b618e79dc5af91af0b1fcaf3b256dfa96be9 |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 222 | 4737816 | 32000000 | 4664808 | 0x38aab9b12061b22ed81cc58c35486d06454644268e72d298e06eed48db2022e5 |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 238 | 4737840 | 32000000 | 4664832 | 0xcf5c3e4e37080963da43b20249a0067461825e9dcf638df8aa0ea5f123d89d5f |
| configureIndependentAllocations | 1 | 1 | 254 | 551558 | 32000000 | 543427 | 0xf8327fc8193157b90e17ae01a217515251fe1812016b39a6454fad93e1579188 |
| issueIndependentAllocations | 1 | 1 | 254 | 903328 | 32000000 | 727677 | 0x86bdf3739973439ff4d7db4dde0bcfb1dc05575c35d78e4afdd0e9dedf9a322e |
| configureIndependentAllocations | 8 | 1,1,1,1,1,1,1,1 | 255 | 2505029 | 32000000 | 2466624 | 0x66d372a49380cb49a6cd09274df6be00d646ae146d1289a587f1da6053b6615d |
| issueIndependentAllocations | 8 | 1,1,1,1,1,1,1,1 | 255 | 5269849 | 32000000 | 4150454 | 0x19a071ced501ea15db61ff4c66259f7cd8cfdb7f03496b2167c82d504f53c6c0 |
| configureIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 263 | 4737828 | 32000000 | 4664820 | 0x31e49c7eb8111a751ab9ea9333e166fad60ad700d31d7b297de8b9760b1b2c99 |
| issueIndependentAllocations | 16 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 263 | 10260242 | 32000000 | 8080476 | 0x08f73ec1ee47fe091120d63e6c485ffa576d0fb9e046f6671b1413ca8ae353d2 |
| configureIndependentAllocations | 32 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 279 | 9204161 | 32000000 | 9061937 | 0x4c4f60994dbb767fc466ed9c74236048724864d363e09b45a79b7bb98d381482 |
| issueIndependentAllocations | 32 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 279 | 20241390 | 32000000 | 15940806 | 0xe538d179778493ab5d7cd77bd7621d6eab39bdbb00cb2e13132455371a50556b |
| configureIndependentAllocations | 64 | 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1 | 311 | 18139765 | 32000000 | 17859066 | 0x8bcbf22241505099cf806d54b5e06e6fc6cfa7c19492edb562f0c2b28b49e9f9 |
| configureIndependentAllocations | 1 | 1 | 375 | 551558 | 32000000 | 543427 | 0xc2027a958238c7a7a765cf3b1640cfcb74e9ecf74435c88b6861d6f604d34de4 |
| issueIndependentAllocations | 1 | 1 | 375 | 903316 | 32000000 | 727665 | 0x2aab4fea59d4dd3a5cb2c131e5a8099a5dd948336d6d618c85ddd94e8d8c973e |
| configureIndependentAllocations | 1 | 8 | 376 | 1846262 | 32000000 | 1818027 | 0x24aab4f995f58b4a9c00e489f8b57101954cc54de680e558ce9ee4080e527e06 |
| issueIndependentAllocations | 1 | 8 | 376 | 1222588 | 32000000 | 1041949 | 0x413278190f21b538189c43e5e9065a837438050e403f32dc61c61fc4e150d3ce |
| configureIndependentAllocations | 1 | 16 | 377 | 3326129 | 32000000 | 3274915 | 0x47fd6eb6a91e55eb013bbd1776ddd61a49b6293713e853643085e738c86cc9ca |
| issueIndependentAllocations | 1 | 16 | 377 | 1587457 | 32000000 | 1401117 | 0x1d8f9fbab45cdaac623cae5c88c7e35c8ebf4cd124afa3e4cd8f3f767cccf322 |
| configureIndependentAllocations | 1 | 32 | 378 | 6286538 | 32000000 | 6189354 | 0x63a35169192557e73f64297791c527175d2c8d7c0c8499f17ae1af1b365e1c08 |
| issueIndependentAllocations | 1 | 32 | 378 | 2317196 | 32000000 | 2119453 | 0x9bddb46c18c4229d001a70ae8c54921c90dd2778952b3aab2f31f81f92ed22b1 |
| configureIndependentAllocations | 1 | 64 | 379 | 12210063 | 32000000 | 12020897 | 0xb3c6aed861ffeb183153cfaf3a545587e9c64a369dd6874a228db100d4f49c29 |
| issueIndependentAllocations | 1 | 64 | 379 | 3776672 | 32000000 | 3556125 | 0xeb2e8e1e4e57cea109858856ec1932f13292146522a4541a1eb01ad87d0bc1ba |
| recoverMigrationNfts/WeightedClaim | 1 | - | 7 | 502744 | 32000000 | 492544 | 0xd644b4a80540b3c7c2e5d72fb25425deb6a3f8f5b2c728a7fbbcecd3922098fa |
| recoverMigrationNfts/WeightedClaim | 8 | - | 0 | 1948611 | 32000000 | 1783679 | 0x4f52361fc398d69449cc5a38949c133d86925590a42eb6e4e88fb23d05fad2fe |
| recoverMigrationNfts/WeightedClaim | 1 | - | 23 | 502744 | 32000000 | 492544 | 0x53abd7d91196c60275282876dee93ce321ffc922e9c9419da9c9d047d8a6d335 |
| recoverMigrationNfts/WeightedClaim | 8 | - | 16 | 1948611 | 32000000 | 1783679 | 0x8f75db743a14997ba4575336f476d39978b68b3c59528feb4d8522c0a165b0c9 |
| recoverMigrationNfts/WeightedUnstake | 1 | - | 24 | 391480 | 32000000 | 383019 | 0x487bd011ee11898b6ac1b49333e467b59e7e0713b8e750d41df3235b1e4ea8f4 |

Task 10's 10,000 DTF donor/bundle blocker remains open. These isolated gas
experiments do not certify its missing mixed-book, NFT 3 or lifecycle rehearsal.
No claimed-SY witness pin was retuned. No public transaction or commit was made.
