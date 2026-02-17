import React from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import ErrorBoundary from './ErrorBoundary'
import AppLayout from './layout/AppLayout'
import ProjectsIndex from './projects/ProjectsIndex'
import EmailTemplatesIndex from './templates/EmailTemplatesIndex'
import TemplatesIndex from './templates/TemplatesIndex'
import TemplateNew from './templates/TemplateNew'
import TemplateEdit from './templates/TemplateEdit'
import MergesIndex from './merges/MergesIndex'
import SettingsPlaceholder from './SettingsPlaceholder'
import AssetsIndex from './assets/AssetsIndex'
import AudiencesIndex from './audiences/AudiencesIndex'

export default function App() {
  return (
    <ErrorBoundary>
    <BrowserRouter basename="/app">
      <Routes>
        <Route element={<AppLayout />}>
          <Route index element={<Navigate to="/projects" replace />} />
          <Route path="projects" element={<ProjectsIndex />} />
          <Route path="templates" element={<EmailTemplatesIndex />} />
          <Route path="projects/:projectId/templates" element={<TemplatesIndex />} />
          <Route path="projects/:projectId/templates/new" element={<TemplateNew />} />
          <Route path="projects/:projectId/templates/:id" element={<TemplateEdit />} />
          <Route path="audiences" element={<AudiencesIndex />} />
          <Route path="assets" element={<AssetsIndex />} />
          <Route path="merge" element={<MergesIndex />} />
          <Route path="settings" element={<SettingsPlaceholder />} />
        </Route>
      </Routes>
    </BrowserRouter>
    </ErrorBoundary>
  )
}
