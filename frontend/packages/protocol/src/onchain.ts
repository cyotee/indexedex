export const ZERO_ADDR = '0x0000000000000000000000000000000000000000' as const

export function isZeroAddress(address: `0x${string}`): boolean {
  return address.toLowerCase() === ZERO_ADDR
}

export type BytecodeClient = {
  getBytecode: (args: { address: `0x${string}` }) => Promise<`0x${string}` | undefined>
}

export async function hasBytecode(client: BytecodeClient, address: `0x${string}`): Promise<boolean> {
  const bytecode = await client.getBytecode({ address })
  return !!bytecode && bytecode !== '0x'
}
