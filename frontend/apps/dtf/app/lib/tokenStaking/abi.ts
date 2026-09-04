export const tokenStakingAbi = [
  {
    type: 'function',
    name: 'stakingToken',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    type: 'function',
    name: 'rewardReserve',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'balanceOf',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'earned',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'phase',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
  {
    type: 'function',
    name: 'previewClaim',
    stateMutability: 'view',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'stakeAmount', type: 'uint256' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'stake',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'withdraw',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'getReward',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    type: 'function',
    name: 'withdrawClaim',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'stakeAmount', type: 'uint256' }],
    outputs: [{ type: 'uint256' }],
  },
] as const

export const TOKEN_STAKING_PHASE = {
  Staking: 0,
  Migrating: 1,
  Wrapped: 2,
} as const
