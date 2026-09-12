const bondTermsTuple = {
  type: 'tuple',
  components: [
    { name: 'minLockDuration', type: 'uint256' },
    { name: 'maxLockDuration', type: 'uint256' },
    { name: 'minBonusPercentage', type: 'uint256' },
    { name: 'maxBonusPercentage', type: 'uint256' },
  ],
} as const

export const FEE_ORACLE_ABI = [
  { type: 'function', name: 'owner', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'pendingOwner', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }] },
  { type: 'function', name: 'isOperator', stateMutability: 'view', inputs: [{ name: 'query', type: 'address' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'feeTo', stateMutability: 'view', inputs: [], outputs: [{ type: 'address' }] },

  { type: 'function', name: 'defaultUsageFee', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'defaultDexSwapFee', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'defaultBondTerms', stateMutability: 'view', inputs: [], outputs: [{ ...bondTermsTuple, name: 'bondTerms_' }] },
  { type: 'function', name: 'defaultSeigniorageIncentivePercentage', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'defaultSeigniorageFeeToSharePercentage', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'defaultSeigniorageCreatorSharePercentage', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'defaultLiquidReservePercentage', stateMutability: 'view', inputs: [], outputs: [{ type: 'uint256' }] },

  { type: 'function', name: 'usageFeeVaultTypeIds', stateMutability: 'view', inputs: [], outputs: [{ type: 'bytes4[]' }] },
  { type: 'function', name: 'dexSwapFeeVaultTypeIds', stateMutability: 'view', inputs: [], outputs: [{ type: 'bytes4[]' }] },
  { type: 'function', name: 'bondVaultTypesIds', stateMutability: 'view', inputs: [], outputs: [{ type: 'bytes4[]' }] },
  { type: 'function', name: 'seigniorageVaultTypeIds', stateMutability: 'view', inputs: [], outputs: [{ type: 'bytes4[]' }] },

  { type: 'function', name: 'defaultUsageFeeOfTypeId', stateMutability: 'view', inputs: [{ type: 'bytes4' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'defaultDexSwapFeeOfTypeId', stateMutability: 'view', inputs: [{ type: 'bytes4' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'defaultBondTermsOfVaultTypeId', stateMutability: 'view', inputs: [{ type: 'bytes4' }], outputs: [{ ...bondTermsTuple, name: 'bondTerms_' }] },
  { type: 'function', name: 'seigniorageIncentivePercentageOfTypeId', stateMutability: 'view', inputs: [{ type: 'bytes4' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'seigniorageFeeToSharePercentageOfTypeId', stateMutability: 'view', inputs: [{ type: 'bytes4' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'seigniorageCreatorSharePercentageOfTypeId', stateMutability: 'view', inputs: [{ type: 'bytes4' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'defaultLiquidReservePercentageOfTypeId', stateMutability: 'view', inputs: [{ type: 'bytes4' }], outputs: [{ type: 'uint256' }] },

  { type: 'function', name: 'usageFeeOfVault', stateMutability: 'view', inputs: [{ type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'dexSwapFeeOfVault', stateMutability: 'view', inputs: [{ type: 'address' }], outputs: [{ type: 'uint256' }] },
  { type: 'function', name: 'bondTermsOfVault', stateMutability: 'view', inputs: [{ type: 'address' }], outputs: [{ ...bondTermsTuple, name: 'bondTerms_' }] },
  {
    type: 'function',
    name: 'seigniorageSplitOfVault',
    stateMutability: 'view',
    inputs: [{ type: 'address' }],
    outputs: [
      { name: 'p', type: 'uint256' },
      { name: 'f', type: 'uint256' },
      { name: 'c', type: 'uint256' },
    ],
  },
  { type: 'function', name: 'liquidReservePercentageOfVault', stateMutability: 'view', inputs: [{ type: 'address' }], outputs: [{ type: 'uint256' }] },

  { type: 'function', name: 'setFeeTo', stateMutability: 'nonpayable', inputs: [{ type: 'address' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultUsageFee', stateMutability: 'nonpayable', inputs: [{ type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultDexSwapFee', stateMutability: 'nonpayable', inputs: [{ type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultBondTerms', stateMutability: 'nonpayable', inputs: [{ name: 'bondTerms', ...bondTermsTuple }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultSeigniorageIncentivePercentage', stateMutability: 'nonpayable', inputs: [{ type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultSeigniorageFeeToSharePercentage', stateMutability: 'nonpayable', inputs: [{ type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultSeigniorageCreatorSharePercentage', stateMutability: 'nonpayable', inputs: [{ type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultSeignioragePotShares', stateMutability: 'nonpayable', inputs: [{ type: 'uint256' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultLiquidReservePercentage', stateMutability: 'nonpayable', inputs: [{ type: 'uint256' }], outputs: [{ type: 'bool' }] },

  { type: 'function', name: 'setDefaultUsageFeeOfTypeId', stateMutability: 'nonpayable', inputs: [{ type: 'bytes4' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultDexSwapFeeOfTypeId', stateMutability: 'nonpayable', inputs: [{ type: 'bytes4' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultBondTermsOfTypeId', stateMutability: 'nonpayable', inputs: [{ type: 'bytes4' }, { name: 'bondTerms', ...bondTermsTuple }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultSeigniorageIncentivePercentageOfTypeId', stateMutability: 'nonpayable', inputs: [{ type: 'bytes4' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultSeignioragePotSharesOfTypeId', stateMutability: 'nonpayable', inputs: [{ type: 'bytes4' }, { type: 'uint256' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setDefaultLiquidReservePercentageOfTypeId', stateMutability: 'nonpayable', inputs: [{ type: 'bytes4' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },

  { type: 'function', name: 'setUsageFeeOfVault', stateMutability: 'nonpayable', inputs: [{ type: 'address' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setVaultDexSwapFee', stateMutability: 'nonpayable', inputs: [{ type: 'address' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setVaultBondTerms', stateMutability: 'nonpayable', inputs: [{ type: 'address' }, { name: 'bondTerms', ...bondTermsTuple }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setSeigniorageIncentivePercentageOfVault', stateMutability: 'nonpayable', inputs: [{ type: 'address' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setSeignioragePotSharesOfVault', stateMutability: 'nonpayable', inputs: [{ type: 'address' }, { type: 'uint256' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
  { type: 'function', name: 'setLiquidReservePercentageOfVault', stateMutability: 'nonpayable', inputs: [{ type: 'address' }, { type: 'uint256' }], outputs: [{ type: 'bool' }] },
] as const

export type BondTerms = {
  minLockDuration: bigint
  maxLockDuration: bigint
  minBonusPercentage: bigint
  maxBonusPercentage: bigint
}

export function asBondTerms(raw: unknown): BondTerms | null {
  if (raw == null) return null
  if (Array.isArray(raw) && raw.length >= 4) {
    try {
      return {
        minLockDuration: BigInt(raw[0] as bigint),
        maxLockDuration: BigInt(raw[1] as bigint),
        minBonusPercentage: BigInt(raw[2] as bigint),
        maxBonusPercentage: BigInt(raw[3] as bigint),
      }
    } catch {
      return null
    }
  }
  if (typeof raw === 'object' && raw !== null && 'minLockDuration' in raw) {
    const o = raw as BondTerms
    try {
      return {
        minLockDuration: BigInt(o.minLockDuration),
        maxLockDuration: BigInt(o.maxLockDuration),
        minBonusPercentage: BigInt(o.minBonusPercentage),
        maxBonusPercentage: BigInt(o.maxBonusPercentage),
      }
    } catch {
      return null
    }
  }
  return null
}
