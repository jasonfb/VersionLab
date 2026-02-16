import React, { useState, useEffect } from 'react'
import { apiFetch } from '~/lib/api'

export default function ProjectsIndex() {
  const [projects, setProjects] = useState([])
  const [loading, setLoading] = useState(true)
  const [newName, setNewName] = useState('')
  const [creating, setCreating] = useState(false)
  const [error, setError] = useState(null)
  const [editingId, setEditingId] = useState(null)
  const [editingName, setEditingName] = useState('')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    apiFetch('/api/projects')
      .then(setProjects)
      .finally(() => setLoading(false))
  }, [])

  const handleCreate = async (e) => {
    e.preventDefault()
    if (!newName.trim()) return
    setCreating(true)
    setError(null)
    try {
      const project = await apiFetch('/api/projects', {
        method: 'POST',
        body: JSON.stringify({ project: { name: newName.trim() } }),
      })
      setProjects((prev) => [...prev, project])
      setNewName('')
    } catch (err) {
      setError(err.message)
    } finally {
      setCreating(false)
    }
  }

  const startEditing = (project) => {
    setEditingId(project.id)
    setEditingName(project.name)
  }

  const cancelEditing = () => {
    setEditingId(null)
    setEditingName('')
  }

  const handleUpdate = async (e) => {
    e.preventDefault()
    if (!editingName.trim()) return
    setSaving(true)
    setError(null)
    try {
      const updated = await apiFetch(`/api/projects/${editingId}`, {
        method: 'PATCH',
        body: JSON.stringify({ project: { name: editingName.trim() } }),
      })
      setProjects((prev) =>
        prev.map((p) => (p.id === editingId ? { ...p, name: updated.name } : p))
      )
      setEditingId(null)
      setEditingName('')
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

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
        <h4 className="mb-0">Projects</h4>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      <form onSubmit={handleCreate} className="mb-4">
        <div className="input-group" style={{ maxWidth: 400 }}>
          <input
            type="text"
            className="form-control"
            placeholder="New project name..."
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            required
          />
          <button className="btn btn-danger" type="submit" disabled={creating}>
            {creating ? 'Creating...' : 'Create Project'}
          </button>
        </div>
      </form>

      {projects.length === 0 ? (
        <div className="text-center text-muted py-5">
          <i className="bi bi-folder fs-1 d-block mb-3"></i>
          <p>No projects yet. Create your first project to get started.</p>
        </div>
      ) : (
        <div className="list-group">
          {projects.map((p) => (
            <div
              key={p.id}
              className="list-group-item d-flex justify-content-between align-items-center"
            >
              {editingId === p.id ? (
                <form onSubmit={handleUpdate} className="d-flex align-items-center gap-2 flex-grow-1">
                  <input
                    type="text"
                    className="form-control form-control-sm"
                    value={editingName}
                    onChange={(e) => setEditingName(e.target.value)}
                    autoFocus
                    required
                  />
                  <button className="btn btn-sm btn-danger" type="submit" disabled={saving}>
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                  <button className="btn btn-sm btn-outline-secondary" type="button" onClick={cancelEditing}>
                    Cancel
                  </button>
                </form>
              ) : (
                <>
                  <div>
                    <i className="bi bi-folder me-2 text-muted"></i>
                    {p.name}
                  </div>
                  <button
                    className="btn btn-sm btn-outline-secondary"
                    onClick={() => startEditing(p)}
                  >
                    <i className="bi bi-pencil"></i>
                  </button>
                </>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
