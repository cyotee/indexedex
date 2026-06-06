import { readFile, stat } from 'node:fs/promises'
import { join, relative, sep, posix } from 'node:path'
import fg from 'fast-glob'
import type { ManifestFragment } from './types.js'
import { knownTypeDirs } from './deriveTags.js'

/**
 * Reads all fragments under the given absolute fragments root.
 * Returns [] if the directory doesn't exist.
 */
export async function readFragmentsForInput(fragmentsRoot: string): Promise<ManifestFragment[]> {
  try {
    const s = await stat(fragmentsRoot)
    if (!s.isDirectory()) return []
  } catch {
    return []
  }

  const patterns = knownTypeDirs().map((d) => `${d}/**/*.json`)
  const files = await fg(patterns, { cwd: fragmentsRoot, absolute: true })

  const fragments: ManifestFragment[] = []
  for (const file of files) {
    const raw = await readFile(file, 'utf8')
    const parsed = JSON.parse(raw) as ManifestFragment

    const relPath = relative(fragmentsRoot, file).split(sep).join(posix.sep)
    const segments = relPath.split('/').slice(0, -1)
    const typeDir = segments.join('/')
    const collapsed = collapseToKnownTypeDir(typeDir)

    fragments.push({
      ...parsed,
      sourcePath: file,
      sourceTypeDir: collapsed,
    })
  }

  return fragments
}

function collapseToKnownTypeDir(relTypeDir: string): string {
  for (const known of knownTypeDirs()) {
    if (relTypeDir === known || relTypeDir.startsWith(known + '/')) {
      return known
    }
  }
  return relTypeDir
}
