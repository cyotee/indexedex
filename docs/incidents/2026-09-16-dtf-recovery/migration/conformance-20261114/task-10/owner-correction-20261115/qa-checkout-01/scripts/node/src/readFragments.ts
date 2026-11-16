import { readFile, stat } from 'node:fs/promises'
import { cpus } from 'node:os'
import { join, relative, sep, posix } from 'node:path'
import { promisify } from 'node:util'
import { walk } from '@nodelib/fs.walk'
import type { ManifestFragment } from './types.js'
import { knownTypeDirs } from './deriveTags.js'

const walkDirectory = promisify(walk)

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

  // The taxonomy roots are fixed and non-overlapping. Reuse the same walker
  // and traversal settings without a general-purpose glob/brace parser.
  const concurrency = Math.max(cpus().length, 1)
  const entries = await Promise.all(knownTypeDirs().map((typeDir) =>
    walkDirectory(join(fragmentsRoot, typeDir), {
      concurrency,
      pathSegmentSeparator: '/',
      followSymbolicLinks: true,
      throwErrorOnBrokenSymbolicLink: false,
      deepFilter: (entry) => !entry.name.startsWith('.'),
      entryFilter: (entry) =>
        entry.dirent.isFile() && !entry.name.startsWith('.') && entry.name.endsWith('.json'),
      errorFilter: (error) => error.code === 'ENOENT',
    })
  ))
  const files = entries.flat().map((entry) => entry.path)

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
