import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { apiFetch } from '~/lib/api'

export default function ProjectsIndex() {
  const [projects, setProjects] = useState([])
  const [loading, setLoading] = useState(true)
  const [newName, setNewName] = useState('')
  const [creating, setCreating] = useState(false)
  const [error, setError] = useState(null)

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
            <Link
              key={p.id}
              to={`/projects/${p.id}/templates`}
              className="list-group-item list-group-item-action d-flex justify-content-between align-items-center"
            >
              <div>
                <i className="bi bi-folder me-2 text-muted"></i>
                {p.name}
              </div>
              <i className="bi bi-chevron-right text-muted"></i>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
