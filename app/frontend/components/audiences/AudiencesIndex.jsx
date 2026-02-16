import React, { useState, useEffect } from 'react'
import { apiFetch } from '~/lib/api'

export default function AudiencesIndex() {
  const [projects, setProjects] = useState([])
  const [selectedProjectId, setSelectedProjectId] = useState('')
  const [audiences, setAudiences] = useState([])
  const [loadingProjects, setLoadingProjects] = useState(true)
  const [loadingAudiences, setLoadingAudiences] = useState(false)
  const [editingId, setEditingId] = useState(null)
  const [editForm, setEditForm] = useState({ name: '', details: '' })
  const [newForm, setNewForm] = useState(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    apiFetch('/api/projects')
      .then(setProjects)
      .finally(() => setLoadingProjects(false))
  }, [])

  useEffect(() => {
    if (!selectedProjectId) {
      setAudiences([])
      return
    }
    setLoadingAudiences(true)
    setEditingId(null)
    setNewForm(null)
    apiFetch(`/api/projects/${selectedProjectId}/audiences`)
      .then(setAudiences)
      .finally(() => setLoadingAudiences(false))
  }, [selectedProjectId])

  const startEditing = (audience) => {
    setEditingId(audience.id)
    setEditForm({ name: audience.name, details: audience.details || '' })
    setNewForm(null)
  }

  const cancelEditing = () => {
    setEditingId(null)
    setEditForm({ name: '', details: '' })
  }

  const saveEdit = async () => {
    setSaving(true)
    try {
      const updated = await apiFetch(`/api/projects/${selectedProjectId}/audiences/${editingId}`, {
        method: 'PATCH',
        body: JSON.stringify({ audience: editForm }),
      })
      setAudiences((prev) => prev.map((a) => (a.id === editingId ? { ...a, ...updated } : a)))
      setEditingId(null)
    } finally {
      setSaving(false)
    }
  }

  const startNew = () => {
    setNewForm({ name: '', details: '' })
    setEditingId(null)
  }

  const cancelNew = () => setNewForm(null)

  const saveNew = async () => {
    setSaving(true)
    try {
      const created = await apiFetch(`/api/projects/${selectedProjectId}/audiences`, {
        method: 'POST',
        body: JSON.stringify({ audience: newForm }),
      })
      setAudiences((prev) => [created, ...prev])
      setNewForm(null)
    } finally {
      setSaving(false)
    }
  }

  const deleteAudience = async (id) => {
    if (!confirm('Delete this audience?')) return
    await apiFetch(`/api/projects/${selectedProjectId}/audiences/${id}`, { method: 'DELETE' })
    setAudiences((prev) => prev.filter((a) => a.id !== id))
    if (editingId === id) setEditingId(null)
  }

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
        <h4 className="mb-0">Audiences</h4>
        {selectedProjectId && (
          <button className="btn btn-danger" onClick={startNew} disabled={!!newForm}>
            <i className="bi bi-plus-lg me-1"></i> New Audience
          </button>
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
          <i className="bi bi-people fs-1 d-block mb-3"></i>
          <p>Select a project to view its audiences.</p>
        </div>
      ) : loadingAudiences ? (
        <div className="p-4">
          <div className="spinner-border spinner-border-sm" role="status">
            <span className="visually-hidden">Loading...</span>
          </div>
        </div>
      ) : (
        <>
          {newForm && (
            <div className="card mb-3">
              <div className="card-body">
                <div className="mb-2">
                  <input
                    type="text"
                    className="form-control"
                    placeholder="Audience name"
                    value={newForm.name}
                    onChange={(e) => setNewForm({ ...newForm, name: e.target.value })}
                  />
                </div>
                <div className="mb-2">
                  <textarea
                    className="form-control"
                    placeholder="Details (optional)"
                    rows={3}
                    value={newForm.details}
                    onChange={(e) => setNewForm({ ...newForm, details: e.target.value })}
                  />
                </div>
                <div className="d-flex gap-2">
                  <button className="btn btn-danger btn-sm" onClick={saveNew} disabled={saving || !newForm.name.trim()}>
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                  <button className="btn btn-outline-secondary btn-sm" onClick={cancelNew}>Cancel</button>
                </div>
              </div>
            </div>
          )}

          {audiences.length === 0 && !newForm ? (
            <div className="text-center text-muted py-5">
              <i className="bi bi-people fs-1 d-block mb-3"></i>
              <p>No audiences yet. Create your first audience to get started.</p>
              <button className="btn btn-outline-danger" onClick={startNew}>
                Create Audience
              </button>
            </div>
          ) : (
            <div className="list-group">
              {audiences.map((a) =>
                editingId === a.id ? (
                  <div key={a.id} className="list-group-item">
                    <div className="mb-2">
                      <input
                        type="text"
                        className="form-control"
                        value={editForm.name}
                        onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                      />
                    </div>
                    <div className="mb-2">
                      <textarea
                        className="form-control"
                        rows={3}
                        value={editForm.details}
                        onChange={(e) => setEditForm({ ...editForm, details: e.target.value })}
                      />
                    </div>
                    <div className="d-flex gap-2">
                      <button className="btn btn-danger btn-sm" onClick={saveEdit} disabled={saving || !editForm.name.trim()}>
                        {saving ? 'Saving...' : 'Save'}
                      </button>
                      <button className="btn btn-outline-secondary btn-sm" onClick={cancelEditing}>Cancel</button>
                    </div>
                  </div>
                ) : (
                  <div
                    key={a.id}
                    className="list-group-item list-group-item-action d-flex justify-content-between align-items-start"
                  >
                    <div className="cursor-pointer flex-grow-1" onClick={() => startEditing(a)}>
                      <div className="d-flex align-items-center">
                        <i className="bi bi-people me-2 text-muted"></i>
                        <strong>{a.name}</strong>
                      </div>
                      {a.details && <small className="text-muted d-block mt-1">{a.details}</small>}
                    </div>
                    <div className="d-flex align-items-center gap-2 ms-3">
                      <small className="text-muted">{new Date(a.updated_at).toLocaleDateString()}</small>
                      <button
                        className="btn btn-outline-danger btn-sm"
                        onClick={(e) => { e.stopPropagation(); deleteAudience(a.id) }}
                        title="Delete"
                      >
                        <i className="bi bi-trash"></i>
                      </button>
                    </div>
                  </div>
                )
              )}
            </div>
          )}
        </>
      )}
    </div>
  )
}
