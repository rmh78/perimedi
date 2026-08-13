import { useMemo, useState } from 'react'
import {
  useCycleSettings,
  useDoseLogs,
  useMedications,
  usePeriods,
  useRemarks,
  useSchedules,
} from '../hooks/useAppData'
import { expandPlannedDoses } from '../lib/schedule'
import { doseExpansionRange } from '../lib/doseRange'
import { todayKey } from '../lib/dates'
import { CycleDiagram } from '../components/CycleDiagram'
import { EditMedicationSheet } from '../components/EditMedicationSheet'
import { DayNoteSheet } from '../components/DayNoteSheet'
import type { Medication } from '../types'
import { useSelectedDate } from '../context/SelectedDateContext'

export function CyclePage() {
  const today = todayKey()
  const { selectedDate, setSelectedDate } = useSelectedDate()
  const medications = useMedications()
  const schedules = useSchedules()
  const doseLogs = useDoseLogs()
  const periods = usePeriods()
  const remarks = useRemarks()
  const settings = useCycleSettings()

  const [medSheet, setMedSheet] = useState<{
    open: boolean
    isNew: boolean
    medication: Medication | null
  }>({ open: false, isNew: false, medication: null })
  const [noteSheet, setNoteSheet] = useState<{ open: boolean; dateKey: string }>(
    { open: false, dateKey: selectedDate },
  )

  const { from: rangeStart, to: rangeEnd } = doseExpansionRange({
    today,
    selectedDate,
    periods,
    settings,
  })

  const allDoses = useMemo(
    () =>
      expandPlannedDoses({
        from: rangeStart,
        to: rangeEnd,
        medications,
        schedules,
        doseLogs,
        periods,
        settings,
      }),
    [rangeStart, rangeEnd, medications, schedules, doseLogs, periods, settings],
  )

  return (
    <div>
      <CycleDiagram
        periods={periods}
        settings={settings}
        doses={allDoses}
        remarks={remarks}
        selectedDate={selectedDate}
        onSelectDate={setSelectedDate}
        todayKey={today}
        onAddMedication={() =>
          setMedSheet({ open: true, isNew: true, medication: null })
        }
        onEditMedication={(id) => {
          const med = medications.find((m) => m.id === id) ?? null
          setMedSheet({ open: true, isNew: false, medication: med })
        }}
        onAddSymptom={(dateKey) => setNoteSheet({ open: true, dateKey })}
      />
      <EditMedicationSheet
        open={medSheet.open}
        medication={medSheet.medication}
        isNew={medSheet.isNew}
        onClose={() =>
          setMedSheet({ open: false, isNew: false, medication: null })
        }
        onSaved={() =>
          setMedSheet({ open: false, isNew: false, medication: null })
        }
      />
      <DayNoteSheet
        open={noteSheet.open}
        dateKey={noteSheet.dateKey}
        onClose={() => setNoteSheet({ open: false, dateKey: selectedDate })}
        onSaved={() => setNoteSheet({ open: false, dateKey: selectedDate })}
      />
    </div>
  )
}
