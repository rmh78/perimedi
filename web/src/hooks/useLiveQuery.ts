import { liveQuery, type Observable } from 'dexie'
import { useEffect, useState } from 'react'

export function useLiveQuery<T>(
  querier: () => Promise<T> | T,
  deps: unknown[] = [],
  initial?: T,
): T | undefined {
  const [value, setValue] = useState<T | undefined>(initial)

  useEffect(() => {
    let cancelled = false
    const observable: Observable<T> = liveQuery(querier)
    const subscription = observable.subscribe({
      next(result) {
        if (!cancelled) setValue(result)
      },
      error(err) {
        console.error(err)
      },
    })
    return () => {
      cancelled = true
      subscription.unsubscribe()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)

  return value
}
