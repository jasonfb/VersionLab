import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { useAccount } from '../layout/AccountContext'

const STATUS_COLORS = { draft: 'secondary', active: 'success', completed: 'primary', archived: 'dark' }

export default function CampaignsIndex() {
  const navigate = useNavigate()
  const ctx = useAccount()
  const clientId = ctx?.current_client_id
  const isAgency = ctx?.is_agency
  const isAgencyAdmin = isAgency && (ctx?.is_owner || ctx?.is_admin)

  const [campaigns, setCampaigns] = useState([])
  const [loading, setLoading] = useState(true)
  const [newName, setNewName] = useState('')
  const [creating, setCreating] = useState(false)
  const [error, setError] = useState(null)

  useEffect(() => {
    if (!clientId) return
    apiFetch(`/api/clients/${clientId}/campaigns`)
      .then(setCampaigns)
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [clientId])

  const handleCreate = async (e) => {
    e.preventDefault()
    if (!newName.trim()) return
    setCreating(true)
    setError(null)
    try {
      const campaign = await apiFetch(`/api/clients/${clientId}/campaigns`, {
        method: 'POST',
        body: JSON.stringify({ campaign: { name: newName.trim() } }),
      })
      setCampaigns((prev) => [...prev, campaign])
      setNewName('')
      navigate(`/campaigns/${campaign.id}`)
    } catch (err) {
      setError(err.message)
    } finally {
      setCreating(false)
    }
  }

  const handleDelete = async (e, id) => {
    e.stopPropagation()
    if (!confirm('Delete this campaign?')) return
    try {
      await apiFetch(`/api/clients/${clientId}/campaigns/${id}`, { method: 'DELETE' })
      setCampaigns((prev) => prev.filter((c) => c.id !== id))
    } catch (err) {
      setError(err.message)
    }
  }

  if (!ctx || loading) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="p-4" style={{ maxWidth: 720 }}>
      <h4 className="mb-4">Campaigns</h4>

      {error && <div className="alert alert-danger">{error}</div>}

      <form onSubmit={handleCreate} className="mb-4">
        <div className="input-group">
          <input
            type="text"
            className="form-control"
            placeholder="New campaign name..."
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            required
          />
          <button className="btn btn-danger" type="submit" disabled={creating}>
            {creating ? 'Creating...' : 'Add Campaign'}
          </button>
        </div>
      </form>

      {campaigns.length === 0 ? (
        <div className="text-center text-muted py-4">
          <i className="bi bi-megaphone fs-1 d-block mb-2"></i>
          <p>No campaigns yet. Create one to get started.</p>
        </div>
      ) : (
        <div className="list-group">
          {campaigns.map((c) => (
            <div
              key={c.id}
              className="list-group-item list-group-item-action d-flex justify-content-between align-items-center"
              style={{ cursor: 'pointer' }}
              onClick={() => {
                if (isAgencyAdmin) {
                  navigate(`/clients/${clientId}/campaigns/${c.id}`)
                } else {
                  navigate(`/campaigns/${c.id}`)
                }
              }}
            >
              <div>
                <div className="d-flex align-items-center gap-2">
                  <i className="bi bi-megaphone text-muted"></i>
                  <strong>{c.name}</strong>
                  <span className={`badge bg-${STATUS_COLORS[c.status] || 'secondary'}`}>{c.status}</span>
                  {c.ai_summary_state === 'generated' && (
                    <span className="badge bg-info text-dark" title="AI summary ready">
                      <i className="bi bi-stars"></i>
                    </span>
                  )}
                  {c.ai_summary_state === 'generating' && (
                    <span className="spinner-border spinner-border-sm text-info" role="status" title="Generating summary..." />
                  )}
                </div>
                {(c.start_date || c.end_date) && (
                  <small className="text-muted d-block mt-1">
                    {[c.start_date, c.end_date].filter(Boolean).join(' → ')}
                  </small>
                )}
              </div>
              <button
                className="btn btn-sm btn-outline-danger"
                onClick={(e) => handleDelete(e, c.id)}
              >
                <i className="bi bi-trash"></i>
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
