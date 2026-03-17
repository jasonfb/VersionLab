import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { useAccount } from '../layout/AccountContext'

export default function ClientsIndex() {
  const ctx = useAccount()
  const [clients, setClients] = useState([])
  const [loading, setLoading] = useState(true)
  const [newName, setNewName] = useState('')
  const [creating, setCreating] = useState(false)
  const [error, setError] = useState(null)
  const [editingId, setEditingId] = useState(null)
  const [editingName, setEditingName] = useState('')
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    apiFetch('/api/clients')
      .then(setClients)
      .finally(() => setLoading(false))
  }, [])

  const handleCreate = async (e) => {
    e.preventDefault()
    if (!newName.trim()) return
    setCreating(true)
    setError(null)
    try {
      const client = await apiFetch('/api/clients', {
        method: 'POST',
        body: JSON.stringify({ client: { name: newName.trim() } }),
      })
      setClients((prev) => [...prev, client])
      setNewName('')
    } catch (err) {
      setError(err.message)
    } finally {
      setCreating(false)
    }
  }

  const startEditing = (client) => {
    setEditingId(client.id)
    setEditingName(client.name)
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
      const updated = await apiFetch(`/api/clients/${editingId}`, {
        method: 'PATCH',
        body: JSON.stringify({ client: { name: editingName.trim() } }),
      })
      setClients((prev) =>
        prev.map((c) => (c.id === editingId ? { ...c, name: updated.name } : c))
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
        <h4 className="mb-0">Clients</h4>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      {(ctx?.is_owner || ctx?.is_admin) && (
        <form onSubmit={handleCreate} className="mb-4">
          <div className="input-group" style={{ maxWidth: 400 }}>
            <input
              type="text"
              className="form-control"
              placeholder="New client name..."
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              required
            />
            <button className="btn btn-danger" type="submit" disabled={creating}>
              {creating ? 'Creating...' : 'Create Client'}
            </button>
          </div>
        </form>
      )}

      {clients.length === 0 ? (
        <div className="text-center py-5">
          {ctx?.is_owner || ctx?.is_admin ? (
            <>
              <i className="bi bi-person-vcard fs-1 d-block mb-3 text-muted"></i>
              <p className="text-muted">No clients yet. Create your first client to get started.</p>
            </>
          ) : (
            <>
              <i className="bi bi-lock fs-1 d-block mb-3 text-warning"></i>
              <p className="fw-semibold">You are not assigned to any clients.</p>
              <p className="text-muted">Ask the account admin to assign you to clients.</p>
            </>
          )}
        </div>
      ) : (
        <div className="list-group">
          {clients.map((c) => (
            <div
              key={c.id}
              className="list-group-item d-flex justify-content-between align-items-center"
            >
              {editingId === c.id ? (
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
                    <i className="bi bi-person-vcard me-2 text-muted"></i>
                    <Link to={`/clients/${c.id}`} className="text-decoration-none">
                      {c.name}
                    </Link>
                  </div>
                  <div className="d-flex gap-2">
                    <Link to={`/clients/${c.id}`} className="btn btn-sm btn-outline-primary">
                      Manage
                    </Link>
                    {(ctx?.is_owner || ctx?.is_admin) && (
                      <button
                        className="btn btn-sm btn-outline-secondary"
                        onClick={() => startEditing(c)}
                      >
                        <i className="bi bi-pencil"></i>
                      </button>
                    )}
                  </div>
                </>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
