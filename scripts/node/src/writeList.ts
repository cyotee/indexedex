import { readFile, writeFile, mkdir } from 'node:fs/promises'
import { dirname } from 'node:path'
import type { TokenList } from './types.js'
import type { PreviousList } from './bumpVersion.js'

export async function loadPreviousList(path: string): Promise<PreviousList | null> {
  try {
    const raw = await readFile(path, 'utf8')
    const parsed = JSON.parse(raw) as TokenList
    if (!parsed.version || !Array.isArray(parsed.tokens)) return null
    return {
      major: parsed.version.major,
      minor: parsed.version.minor,
      patch: parsed.version.patch,
      tokens: parsed.tokens,
    }
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') return null
    throw err
  }
}

export async function writeList(path: string, list: TokenList): Promise<void> {
  await mkdir(dirname(path), { recursive: true })
  await writeFile(path, JSON.stringify(list, null, 2) + '\n', 'utf8')
}
