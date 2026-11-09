/** Runs `load` once and shares the result; a failed load is forgotten so the next call retries. */
export function memoLoad<T>(load: () => Promise<T>): () => Promise<T> {
  let p: Promise<T> | undefined
  return () => (p ??= load().catch(e => { p = undefined; throw e }))
}

export async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url)
  if (!res.ok) throw new Error(`${res.status} ${url}`)
  return res.json() as Promise<T>
}
