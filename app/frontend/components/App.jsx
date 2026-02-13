import React from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import ErrorBoundary from './ErrorBoundary'
import AppLayout from './layout/AppLayout'
import TemplatesIndex from './templates/TemplatesIndex'
import TemplateNew from './templates/TemplateNew'
import TemplateEdit from './templates/TemplateEdit'
import MergePlaceholder from './MergePlaceholder'
import SettingsPlaceholder from './SettingsPlaceholder'
import AssetsIndex from './assets/AssetsIndex'

export default function App() {
  return (
    <ErrorBoundary>
    <BrowserRouter basename="/app">
      <Routes>
        <Route element={<AppLayout />}>
          <Route index element={<Navigate to="/templates" replace />} />
          <Route path="templates" element={<TemplatesIndex />} />
          <Route path="templates/new" element={<TemplateNew />} />
          <Route path="templates/:id" element={<TemplateEdit />} />
          <Route path="assets" element={<AssetsIndex />} />
          <Route path="merge" element={<MergePlaceholder />} />
          <Route path="settings" element={<SettingsPlaceholder />} />
        </Route>
      </Routes>
    </BrowserRouter>
    </ErrorBoundary>
  )
}
