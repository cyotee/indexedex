'use client'

import {
  Address,
  concatHex,
  Hash,
  TypedDataDefinition,
  encodeAbiParameters,
  keccak256,
  toHex,
} from 'viem'

const PERMIT2_NAME = 'Permit2'

const PERMIT_TRANSFER_FROM_TYPE = [
  { name: 'permitted', type: 'TokenPermissions' },
  { name: 'spender', type: 'address' },
  { name: 'nonce', type: 'uint256' },
  { name: 'deadline', type: 'uint256' },
  { name: 'witness', type: 'Witness' },
] as const

const TOKEN_PERMISSIONS_TYPE = [
  { name: 'token', type: 'address' },
  { name: 'amount', type: 'uint256' },
] as const

const WITNESS_TYPE_STRING =
  'Witness witness)TokenPermissions(address token,uint256 amount)Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)'

const WITNESS_TYPE = [
  { name: 'owner', type: 'address' },
  { name: 'pool', type: 'address' },
  { name: 'tokenIn', type: 'address' },
  { name: 'tokenInVault', type: 'address' },
  { name: 'tokenOut', type: 'address' },
  { name: 'tokenOutVault', type: 'address' },
  { name: 'amountIn', type: 'uint256' },
  { name: 'limit', type: 'uint256' },
  { name: 'deadline', type: 'uint256' },
  { name: 'wethIsEth', type: 'bool' },
  { name: 'userData', type: 'bytes32' },
] as const

const EMPTY_USERDATA_HASH = keccak256('0x')

const PERMIT2_DOMAIN_TYPE = [
  { name: 'name', type: 'string' },
  { name: 'chainId', type: 'uint256' },
  { name: 'verifyingContract', type: 'address' },
] as const

export type WitnessData = {
  owner: Address
  pool: Address
  tokenIn: Address
  tokenInVault: Address
  tokenOut: Address
  tokenOutVault: Address
  amountIn: bigint
  limit: bigint
  deadline: bigint
  wethIsEth: boolean
  userData: Hash
}

export type Permit2SignatureParams = {
  token: Address
  amount: bigint
  nonce: bigint
  deadline: bigint
  owner: Address
  spender: Address
  witness: WitnessData
}

export function getPermit2DomainSeparator(
  chainId: number,
  permit2Address: Address
): string {
  return keccak256(
    encodeAbiParameters(PERMIT2_DOMAIN_TYPE, [
      PERMIT2_NAME,
      BigInt(chainId),
      permit2Address,
    ])
  )
}

export function getPermitTypehash(): Hash {
  const stub =
    'PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,'
  return keccak256(
    toHex(stub + WITNESS_TYPE_STRING, { size: 1024 })
  )
}

export function getTokenPermissionsTypehash(): Hash {
  return keccak256(
    toHex('TokenPermissions(address token,uint256 amount)', { size: 1024 })
  )
}

export function getWitnessTypehash(): Hash {
  return keccak256(toHex(WITNESS_TYPE_STRING, { size: 2048 }))
}

export function getFullDomainSeparator(
  chainId: number,
  permit2Address: Address
): TypedDataDefinition {
  const message = {} as Record<string, unknown>
  return {
    domain: {
      name: PERMIT2_NAME,
      chainId,
      verifyingContract: permit2Address,
    },
    types: {
      EIP712Domain: PERMIT2_DOMAIN_TYPE,
    },
    primaryType: 'EIP712Domain',
    message,
  }
}

export function getPermit2TypedData(
  chainId: number,
  permit2Address: Address,
  params: Permit2SignatureParams
): TypedDataDefinition {
  const { token, amount, nonce, deadline, owner, spender, witness } = params

  const message = {
    permitted: {
      token,
      amount,
    },
    spender,
    nonce,
    deadline,
    witness,
  }

  return {
    domain: {
      name: PERMIT2_NAME,
      chainId,
      verifyingContract: permit2Address,
    },
    types: {
      EIP712Domain: PERMIT2_DOMAIN_TYPE,
      PermitWitnessTransferFrom: PERMIT_TRANSFER_FROM_TYPE,
      TokenPermissions: TOKEN_PERMISSIONS_TYPE,
      Witness: WITNESS_TYPE,
    },
    primaryType: 'PermitWitnessTransferFrom',
    message,
  }
}

export async function signPermit2Witness(
  signTypedData: (data: TypedDataDefinition) => Promise<Hash>,
  chainId: number,
  permit2Address: Address,
  params: Permit2SignatureParams
): Promise<Hash> {
  const typedData = getPermit2TypedData(chainId, permit2Address, params)
  return signTypedData(typedData)
}

export function createWitnessFromSwapParams(
  owner: Address,
  pool: Address,
  tokenIn: Address,
  tokenInVault: Address,
  tokenOut: Address,
  tokenOutVault: Address,
  amountIn: bigint,
  limit: bigint,
  deadline: bigint,
  wethIsEth: boolean,
  userData: Hash = EMPTY_USERDATA_HASH
): WitnessData {
  return {
    owner,
    pool,
    tokenIn,
    tokenInVault,
    tokenOut,
    tokenOutVault,
    amountIn,
    limit,
    deadline,
    wethIsEth,
    userData,
  }
}

const DOMAIN_TYPEHASH = keccak256(toHex('EIP712Domain(string name,uint256 chainId,address verifyingContract)'))
const TOKEN_PERMISSIONS_TYPEHASH = keccak256(toHex('TokenPermissions(address token,uint256 amount)'))
const WITNESS_TYPEHASH = keccak256(
  toHex(
    'Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)'
  )
)
const PERMIT_STUB =
  'PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,'

export function buildPermit2WitnessDigest(params: {
  chainId: number
  permit2Address: Address
  token: Address
  amount: bigint
  nonce: bigint
  deadline: bigint
  spender: Address
  witness: WitnessData
}): Hash {
  const domainSeparator = keccak256(
    encodeAbiParameters(
      [
        { name: 'typeHash', type: 'bytes32' },
        { name: 'nameHash', type: 'bytes32' },
        { name: 'chainId', type: 'uint256' },
        { name: 'verifyingContract', type: 'address' },
      ],
      [DOMAIN_TYPEHASH, keccak256(toHex(PERMIT2_NAME)), BigInt(params.chainId), params.permit2Address]
    )
  )

  const tokenPermissionsHash = keccak256(
    encodeAbiParameters(
      [
        { name: 'typeHash', type: 'bytes32' },
        { name: 'token', type: 'address' },
        { name: 'amount', type: 'uint256' },
      ],
      [TOKEN_PERMISSIONS_TYPEHASH, params.token, params.amount]
    )
  )

  const witnessHash = keccak256(
    encodeAbiParameters(
      [
        { name: 'typeHash', type: 'bytes32' },
        { name: 'owner', type: 'address' },
        { name: 'pool', type: 'address' },
        { name: 'tokenIn', type: 'address' },
        { name: 'tokenInVault', type: 'address' },
        { name: 'tokenOut', type: 'address' },
        { name: 'tokenOutVault', type: 'address' },
        { name: 'amountIn', type: 'uint256' },
        { name: 'limit', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
        { name: 'wethIsEth', type: 'bool' },
        { name: 'userData', type: 'bytes32' },
      ],
      [
        WITNESS_TYPEHASH,
        params.witness.owner,
        params.witness.pool,
        params.witness.tokenIn,
        params.witness.tokenInVault,
        params.witness.tokenOut,
        params.witness.tokenOutVault,
        params.witness.amountIn,
        params.witness.limit,
        params.witness.deadline,
        params.witness.wethIsEth,
        params.witness.userData,
      ]
    )
  )

  const permitTypeHash = keccak256(toHex(PERMIT_STUB + WITNESS_TYPE_STRING))

  const permitHash = keccak256(
    encodeAbiParameters(
      [
        { name: 'typeHash', type: 'bytes32' },
        { name: 'tokenPermissionsHash', type: 'bytes32' },
        { name: 'spender', type: 'address' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
        { name: 'witnessHash', type: 'bytes32' },
      ],
      [permitTypeHash, tokenPermissionsHash, params.spender, params.nonce, params.deadline, witnessHash]
    )
  )

  return keccak256(concatHex(['0x1901', domainSeparator, permitHash]))
}
