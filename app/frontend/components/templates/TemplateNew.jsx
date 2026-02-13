import React, { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { apiFetch } from '~/lib/api'

export default function TemplateNew() {
  const { projectId } = useParams()
  const navigate = useNavigate()
  const [name, setName] = useState('')
  const [rawSourceHtml, setRawSourceHtml] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    try {
      const result = await apiFetch(`/api/projects/${projectId}/email_templates`, {
        method: 'POST',
        body: JSON.stringify({
          email_template: { name, raw_source_html: rawSourceHtml },
        }),
      })
      navigate(`/projects/${projectId}/templates/${result.id}`)
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="p-4" style={{ maxWidth: 720 }}>
      <h4 className="mb-4">New Email Template</h4>

      {error && <div className="alert alert-danger">{error}</div>}

      <form onSubmit={handleSubmit}>
        <div className="mb-3">
          <label className="form-label">Template Name</label>
          <input
            type="text"
            className="form-control"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Monthly Newsletter"
            required
          />
        </div>
        <div className="mb-3">
          <label className="form-label">Raw Source HTML</label>
          <textarea
            className="form-control font-monospace"
            rows={16}
            value={rawSourceHtml}
            onChange={(e) => setRawSourceHtml(e.target.value)}
            placeholder="Paste your email HTML here..."
          />
        </div>
        <div className="d-flex gap-2">
          <button type="submit" className="btn btn-danger" disabled={saving}>
            {saving ? 'Creating...' : 'Create Template'}
          </button>
          <button
            type="button"
            className="btn btn-outline-secondary"
            onClick={() => navigate(`/projects/${projectId}/templates`)}
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  )
}
