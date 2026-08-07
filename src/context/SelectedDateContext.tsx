import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { todayKey } from '../lib/dates'

type SelectedDateContextValue = {
  selectedDate: string
  setSelectedDate: (dateKey: string) => void
  goToToday: () => void
}

const SelectedDateContext = createContext<SelectedDateContextValue | null>(
  null,
)

export function SelectedDateProvider({ children }: { children: ReactNode }) {
  const [selectedDate, setSelectedDate] = useState(todayKey)

  const goToToday = useCallback(() => {
    setSelectedDate(todayKey())
  }, [])

  const value = useMemo(
    () => ({ selectedDate, setSelectedDate, goToToday }),
    [selectedDate, goToToday],
  )

  return (
    <SelectedDateContext.Provider value={value}>
      {children}
    </SelectedDateContext.Provider>
  )
}

export function useSelectedDate(): SelectedDateContextValue {
  const ctx = useContext(SelectedDateContext)
  if (!ctx) {
    throw new Error('useSelectedDate must be used within SelectedDateProvider')
  }
  return ctx
}
