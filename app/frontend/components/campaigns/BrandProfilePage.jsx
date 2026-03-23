import React from 'react'
import { useAccount } from '../layout/AccountContext'
import { BrandProfileTab } from '../clients/ClientDetail'

export default function BrandProfilePage() {
  const ctx = useAccount()
  const clientId = ctx?.current_client_id

  if (!ctx) return null

  if (!clientId) {
    return (
      <div className="p-4">
        <div className="alert alert-warning">No client selected. Use the Client switcher to choose a client.</div>
      </div>
    )
  }

  return (
    <div className="p-4" style={{ maxWidth: 760 }}>
      <h4 className="mb-4">Brand Profile</h4>
      <BrandProfileTab clientId={clientId} />
    </div>
  )
}
