import React from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import ErrorBoundary from './ErrorBoundary'
import AppLayout from './layout/AppLayout'
import ClientsIndex from './clients/ClientsIndex'
import ClientDetail from './clients/ClientDetail'
import CampaignDetail from './clients/CampaignDetail'
import EmailTemplatesIndex from './templates/EmailTemplatesIndex'
import TemplatesIndex from './templates/TemplatesIndex'
import TemplateNew from './templates/TemplateNew'
import TemplateEdit from './templates/TemplateEdit'
import EmailsIndex from './emails/EmailsIndex'
import EmailDetail from './emails/EmailDetail'
import EmailResultsPage from './emails/EmailResultsPage'
import SettingsPage from './settings/SettingsPage'
import AssetsIndex from './assets/AssetsIndex'
import AudiencesIndex from './audiences/AudiencesIndex'
import AudienceDetail from './audiences/AudienceDetail'
import CampaignsIndex from './campaigns/CampaignsIndex'
import BrandProfilePage from './campaigns/BrandProfilePage'
import AdsIndex from './ads/AdsIndex'
import AdEdit from './ads/AdEdit'
import AdResults from './ads/AdResults'
import { useAccount } from './layout/AccountContext'

function HomeRedirect() {
  const ctx = useAccount()
  if (!ctx) return null
  const isAgencyAdmin = ctx.is_agency && (ctx.is_owner || ctx.is_admin)
  return <Navigate to={isAgencyAdmin ? '/clients' : '/templates'} replace />
}

function AgencyRoute({ children }) {
  const ctx = useAccount()
  if (!ctx) return null
  if (!ctx.is_agency || !(ctx.is_owner || ctx.is_admin)) return <Navigate to="/templates" replace />
  return children
}

export default function App() {
  return (
    <ErrorBoundary>
    <BrowserRouter basename="/app">
      <Routes>
        <Route element={<AppLayout />}>
          <Route index element={<HomeRedirect />} />
          <Route path="clients" element={<AgencyRoute><ClientsIndex /></AgencyRoute>} />
          <Route path="clients/:clientId" element={<AgencyRoute><ClientDetail /></AgencyRoute>} />
          <Route path="clients/:clientId/campaigns/:campaignId" element={<AgencyRoute><CampaignDetail /></AgencyRoute>} />
          <Route path="campaigns" element={<CampaignsIndex />} />
          <Route path="campaigns/:campaignId" element={<CampaignDetail />} />
          <Route path="brand-profile" element={<BrandProfilePage />} />
          <Route path="templates" element={<EmailTemplatesIndex />} />
          <Route path="clients/:clientId/templates" element={<TemplatesIndex />} />
          <Route path="clients/:clientId/templates/new" element={<TemplateNew />} />
          <Route path="clients/:clientId/templates/:id" element={<TemplateEdit />} />
          <Route path="audiences" element={<AudiencesIndex />} />
          <Route path="audiences/:audienceId" element={<AudienceDetail />} />
          <Route path="assets" element={<AssetsIndex />} />
          <Route path="emails" element={<EmailsIndex />} />
          <Route path="clients/:clientId/emails/:emailId" element={<EmailDetail />} />
          <Route path="clients/:clientId/emails/:emailId/results" element={<EmailResultsPage />} />
          <Route path="ads" element={<AdsIndex />} />
          <Route path="clients/:clientId/ads/:adId" element={<AdEdit />} />
          <Route path="clients/:clientId/ads/:adId/results" element={<AdResults />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
    </ErrorBoundary>
  )
}
