import React, { useState, useEffect } from 'react'
import { Link, useParams } from 'react-router-dom'
import { apiFetch } from '~/lib/api'

export default function TemplatesIndex() {
  const { projectId } = useParams()
  const [templates, setTemplates] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    apiFetch(`/api/projects/${projectId}/email_templates`)
      .then(setTemplates)
      .finally(() => setLoading(false))
  }, [projectId])

  if (loading) {
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
        <div className="d-flex align-items-center gap-2">
          <Link to="/projects" className="btn btn-sm btn-link text-dark p-0">
            <i className="bi bi-arrow-left"></i>
          </Link>
          <h4 className="mb-0">Email Templates</h4>
        </div>
        <Link to={`/projects/${projectId}/templates/new`} className="btn btn-danger">
          <i className="bi bi-plus-lg me-1"></i> New Template
        </Link>
      </div>

      {templates.length === 0 ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-file-earmark-code fs-1 d-block mb-3"></i>
          <p>No templates yet. Create your first email template to get started.</p>
          <Link to={`/projects/${projectId}/templates/new`} className="btn btn-outline-danger">
            Create Template
          </Link>
        </div>
      ) : (
        <div className="list-group">
          {templates.map((t) => (
            <Link
              key={t.id}
              to={`/projects/${projectId}/templates/${t.id}`}
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
