export function fundedBondRole(tokenId: bigint): 'Protocol' | 'Fee recipient' | 'Creator' | undefined {
  return tokenId === 0n ? 'Protocol' : tokenId === 1n ? 'Fee recipient' : tokenId === 2n ? 'Creator' : undefined
}

/** Linear vesting permits partial principal claims; funded rewards have no maturity gate. */
export function fundedBondClaimAvailability(input: {
  tokenId: bigint
  principalDue?: bigint
  rewardsDue?: bigint
  pending?: boolean
}) {
  const purchased = input.tokenId >= 3n
  const principal = input.principalDue ?? 0n
  const rewards = input.rewardsDue ?? 0n
  return {
    rewards: purchased && !input.pending && rewards > 0n,
    combined: purchased && !input.pending && principal + rewards > 0n,
  }
}
