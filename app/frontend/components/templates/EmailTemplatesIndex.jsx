import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { apiFetch } from '~/lib/api'

export default function EmailTemplatesIndex() {
  const [projects, setProjects] = useState([])
  const [selectedProjectId, setSelectedProjectId] = useState('')
  const [templates, setTemplates] = useState([])
  const [loadingProjects, setLoadingProjects] = useState(true)
  const [loadingTemplates, setLoadingTemplates] = useState(false)

  useEffect(() => {
    apiFetch('/api/projects')
      .then(setProjects)
      .finally(() => setLoadingProjects(false))
  }, [])

  useEffect(() => {
    if (!selectedProjectId) {
      setTemplates([])
      return
    }
    setLoadingTemplates(true)
    apiFetch(`/api/projects/${selectedProjectId}/email_templates`)
      .then(setTemplates)
      .finally(() => setLoadingTemplates(false))
  }, [selectedProjectId])

  if (loadingProjects) {
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
        <h4 className="mb-0">Email Templates</h4>
        {selectedProjectId && (
          <Link to={`/projects/${selectedProjectId}/templates/new`} className="btn btn-danger">
            <i className="bi bi-plus-lg me-1"></i> New Template
          </Link>
        )}
      </div>

      <div className="mb-4" style={{ maxWidth: 400 }}>
        <label className="form-label fw-semibold">Project</label>
        <select
          className="form-select"
          value={selectedProjectId}
          onChange={(e) => setSelectedProjectId(e.target.value)}
        >
          <option value="">Select a project...</option>
          {projects.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
      </div>

      {!selectedProjectId ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-file-earmark-code fs-1 d-block mb-3"></i>
          <p>Select a project to view its email templates.</p>
        </div>
      ) : loadingTemplates ? (
        <div className="p-4">
          <div className="spinner-border spinner-border-sm" role="status">
            <span className="visually-hidden">Loading...</span>
          </div>
        </div>
      ) : templates.length === 0 ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-file-earmark-code fs-1 d-block mb-3"></i>
          <p>No templates yet. Create your first email template to get started.</p>
          <Link to={`/projects/${selectedProjectId}/templates/new`} className="btn btn-outline-danger">
            Create Template
          </Link>
        </div>
      ) : (
        <div className="list-group">
          {templates.map((t) => (
            <Link
              key={t.id}
              to={`/projects/${selectedProjectId}/templates/${t.id}`}
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
