import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { useAccount } from '../layout/AccountContext'

export default function EmailTemplatesIndex() {
  const ctx = useAccount()
  const clientId = ctx?.current_client_id
  const [templates, setTemplates] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!clientId) return
    setLoading(true)
    apiFetch(`/api/clients/${clientId}/email_templates`)
      .then(setTemplates)
      .finally(() => setLoading(false))
  }, [clientId])

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
    <div className="p-4">
      <div className="d-flex justify-content-between align-items-center mb-4">
        <div>
          <h4 className="mb-0">Email Templates</h4>
          {ctx.is_agency && ctx.clients?.find((c) => c.id === clientId) && (
            <small className="text-muted">
              {ctx.clients.find((c) => c.id === clientId)?.name}
            </small>
          )}
        </div>
        {clientId && (
          <Link to={`/clients/${clientId}/templates/new`} className="btn btn-danger">
            <i className="bi bi-plus-lg me-1"></i> New Template
          </Link>
        )}
      </div>

      {templates.length === 0 ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-file-earmark-code fs-1 d-block mb-3"></i>
          <p>No templates yet. Create your first email template to get started.</p>
          {clientId && (
            <Link to={`/clients/${clientId}/templates/new`} className="btn btn-outline-danger">
              Create Template
            </Link>
          )}
        </div>
      ) : (
        <div className="list-group">
          {templates.map((t) => (
            <Link
              key={t.id}
              to={`/clients/${clientId}/templates/${t.id}`}
              className="list-group-item list-group-item-action d-flex justify-content-between align-items-center"
            >
              <div>
                <i className="bi bi-file-earmark-code me-2 text-muted"></i>
                {t.name}
              </div>
              <small className="text-muted">
                {new Date(t.updated_at).toLocaleDateString()}
              </small>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
