# UI Manual Test Status

## **Standard Exchange Router Routes**

| Argument      | Balancer Swap | Vault Pass-Through Swap | Vault Deposit | Vault Withdraw | Vault Deposit -> Balancer Swap | Balancer Swap -> Vault Withdraw | Vault Deposit -> Balancer Swap -> Vault Withdraw | 
| :-----------: | :-----------: | :---------------------: | :-----------: | :------------: | :----------------------------: | :-----------------------------: | :----------------------------------------------: |
| pool          | pool          | vault                   | vault         | vault          | pool                           | pool                            | pool                                             |
| tokenIn       | sell token    | sell token              | deposit token | vault          | deposit token                  | sell token                      | deposit token                                    |
| tokenInVault  | address(0)    | vault                   | vault         | address(0)     | deposit vault                  | address(0)                      | deposit vault                                    |
| tokenOut      | buy token     | buy token               | vault         | withdraw token | buy token                      | withdraw token                  | withdraw token                                   |
| tokenOutVault | address(0)    | vault                   | address(0)    | vault          | address(0)                     | withdraw vault                  | withdraw vault                                   |

## **Standard Exchange Router UI Test Status**

| Swap Type                                        | UI Token Test Status  | UI ETH In Test Status   | UI ETH Out Test Status | Test Suite Status |
| :----------------------------------------------: | :-------------------: | :---------------------: | :--------------------: | :---------------: |
| (Balancer Swap)                                    | Success             |                         |                        | ✅ **COMPLETE** |
| (Vault Pass-Through Swap)                          | Success             |                         |                        | ✅ **COMPLETE** |
| (Vault Deposit)                                    | Success             |                         |                        | ✅ **COMPLETE** |
| (Vault Withdraw)                                   | Success             |                         |                        | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap)                   | Success             |                         |                        | ✅ **COMPLETE** |
| (Balancer Swap -> Vault Withdraw)                  | Success             |                         |                        | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap -> Vault Withdraw) | Reverts 0x4bdace13  |                         | N/A                    | ✅ **COMPLETE** |

## **Standard Exchange Batch Router UI Test Status**

| Swap Type                                                                               | UI Token Test Status  | UI ETH In Test Status   | UI ETH Out Test Status | Test Suite Status |
| :-------------------------------------------------------------------------------------: | :-------------------: | :---------------------: | :--------------------: | :---------------: |
| (Balancer Swap) -> (Balancer Swap)                                                      | Success               |                  |        | ✅ **COMPLETE** |
| (Balancer Swap) -> (Vault Pass-Through Swap)                                            |                |                  |        | ✅ **COMPLETE** |
| (Balancer Swap) -> (Vault Deposit)                                                      |                |                  |        | ✅ **COMPLETE** |
| (Balancer Swap) -> (Vault Withdraw)                                                     |                |                  |        | ✅ **COMPLETE** |
| (Balancer Swap) -> (Vault Deposit -> Balancer Swap)                                     |                |                  |        | ✅ **COMPLETE** |
| (Balancer Swap) -> (Balancer Swap -> Vault Withdraw)                                    |                |                  |        | ✅ **COMPLETE** |
| (Vault Pass-Through Swap) -> (Balancer Swap)                                            |                |                  |                 | ✅ **COMPLETE** |
| (Vault Pass-Through Swap) -> (Vault Pass-Through Swap)                                  |                |                  |                 | ✅ **COMPLETE** |
| (Vault Pass-Through Swap) -> (Vault Deposit)                                            |                |                  |                 | ✅ **COMPLETE** |
| (Vault Pass-Through Swap) -> (Vault Withdraw)                                           |                |                  |                 | ✅ **COMPLETE** |
| (Vault Pass-Through Swap) -> (Vault Deposit -> Balancer Swap)                           |                |                  |                 | ✅ **COMPLETE** |
| (Vault Pass-Through Swap) -> (Balancer Swap -> Vault Withdraw)                          |                |                  |                 | ✅ **COMPLETE** |
| (Vault Deposit) -> (Balancer Swap)                                                      |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit) -> (Vault Pass-Through Swap)                                            |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit) -> (Vault Deposit)                                                      |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit) -> (Vault Withdraw)                                                     |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit) -> (Vault Deposit -> Balancer Swap)                                     |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit) -> (Balancer Swap -> Vault Withdraw)                                    |                |                  |                     | ✅ **COMPLETE** |
| (Vault Withdraw) -> (Balancer Swap)                                                     |                |                      |                 | ✅ **COMPLETE** |
| (Vault Withdraw) -> (Vault Pass-Through Swap)                                           |                |                      |                 | ✅ **COMPLETE** |
| (Vault Withdraw) -> (Vault Deposit)                                                     |                |                      |                 | ✅ **COMPLETE** |
| (Vault Withdraw) -> (Vault Withdraw)                                                    |                |                      |                 | ✅ **COMPLETE** |
| (Vault Withdraw) -> (Vault Deposit -> Balancer Swap)                                    |                |                      |                 | ✅ **COMPLETE** |
| (Vault Withdraw) -> (Balancer Swap -> Vault Withdraw)                                   |                |                      |                 | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap) -> (Balancer Swap)                                     |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap) -> (Vault Pass-Through Swap)                           |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap) -> (Vault Deposit)                                     |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap) -> (Vault Withdraw)                                    |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap) -> (Vault Deposit -> Balancer Swap)                    |                |                  |                     | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap) -> (Balancer Swap -> Vault Withdraw)                   |                |                  |                     | ✅ **COMPLETE** |
| (Balancer Swap -> Vault Withdraw) -> (Balancer Swap)                                    |                |                      |                 | ✅ **COMPLETE** |
| (Balancer Swap -> Vault Withdraw) -> (Vault Pass-Through Swap)                          |                |                      |                 | ✅ **COMPLETE** |
| (Balancer Swap -> Vault Withdraw) -> (Vault Deposit)                                    |                |                      |                 | ✅ **COMPLETE** |
| (Balancer Swap -> Vault Withdraw) -> (Vault Withdraw)                                   |                |                      |                 | ✅ **COMPLETE** |
| (Balancer Swap -> Vault Withdraw) -> (Vault Deposit -> Balancer Swap)                   |                |                      |                 | ✅ **COMPLETE** |
| (Balancer Swap -> Vault Withdraw) -> (Balancer Swap -> Vault Withdraw)                  |                |                      |                 | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap -> Vault Withdraw) -> (Balancer Swap)                   | Reverts 0x4bdace13    |                  | N/A                    | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap -> Vault Withdraw) -> (Vault Pass-Through Swap)         | Reverts 0x4bdace13    |                  | N/A                    | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap -> Vault Withdraw) -> (Vault Deposit)                   | Reverts 0x4bdace13    |                  | N/A                    | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap -> Vault Withdraw) -> (Vault Withdraw)                  | Reverts 0x4bdace13    |                  | N/A                    | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap -> Vault Withdraw) -> (Vault Deposit -> Balancer Swap)  | Reverts 0x4bdace13    |                  | N/A                    | ✅ **COMPLETE** |
| (Vault Deposit -> Balancer Swap -> Vault Withdraw) -> (Balancer Swap -> Vault Withdraw) | Reverts 0x4bdace13    |                  | N/A                    | ✅ **COMPLETE** |