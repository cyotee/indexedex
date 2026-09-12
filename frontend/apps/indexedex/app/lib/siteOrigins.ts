/** Keep application navigation on the current IndexedEx host, including local previews. */
export function appPath(path: string): string {
  return path.startsWith('/') ? path : `/${path}`
}
