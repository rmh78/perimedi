import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { Layout } from './components/Layout'
import { CyclePage } from './pages/CyclePage'
import { MonthPage } from './pages/MonthPage'
import { MorePage } from './pages/MorePage'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<CyclePage />} />
          <Route path="cycle" element={<Navigate to="/" replace />} />
          <Route path="today" element={<Navigate to="/" replace />} />
          <Route path="month" element={<MonthPage />} />
          <Route path="more" element={<MorePage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
