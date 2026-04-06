import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { useAccount } from '../layout/AccountContext'
import SubscriptionTab from './SubscriptionTab'

export default function SettingsPage() {
  const ctx = useAccount()
  const [tab, setTab] = useState('account')

  const hasBillingAccess = ctx?.is_owner || ctx?.is_admin || ctx?.is_billing_admin

  const tabs = [
    { key: 'account', label: 'Account' },
    { key: 'usage', label: 'AI Usage' },
    { key: 'users', label: 'Users' },
    ...(hasBillingAccess ? [{ key: 'subscription', label: 'Subscription' }] : []),
  ]

  return (
    <div className="p-4">
      <h4 className="mb-4">Settings</h4>
      <ul className="nav nav-tabs mb-4">
        {tabs.map(({ key, label }) => (
          <li key={key} className="nav-item">
            <button
              className={`nav-link ${tab === key ? 'active' : ''}`}
              onClick={() => setTab(key)}
            >
              {label}
            </button>
          </li>
        ))}
      </ul>

      {tab === 'account' && <AccountTab />}
      {tab === 'usage' && <UsageTab />}
      {tab === 'users' && <UsersTab />}
      {tab === 'subscription' && <SubscriptionTab />}
    </div>
  )
}

// ─── Account Tab ─────────────────────────────────────────────────────────────

function AccountTab() {
  const ctx = useAccount()
  const [upgrading, setUpgrading] = useState(false)
  const [upgradeError, setUpgradeError] = useState(null)
  const [confirmUpgrade, setConfirmUpgrade] = useState(false)

  if (!ctx) return <Spinner />

  const currentAccount = ctx.accounts?.find((a) => a.id === ctx.current_account_id)
  const isAgency = ctx.is_agency
  const isOwner = ctx.is_owner

  const roleBadges = []
  if (ctx.is_owner) roleBadges.push({ label: 'Owner', color: 'danger' })
  if (ctx.is_admin) roleBadges.push({ label: 'Admin', color: 'warning' })
  if (ctx.is_billing_admin) roleBadges.push({ label: 'Billing Admin', color: 'info' })
  if (roleBadges.length === 0) roleBadges.push({ label: 'Member', color: 'secondary' })

  const handleUpgrade = async () => {
    setUpgrading(true)
    setUpgradeError(null)
    try {
      await apiFetch('/api/upgrade_to_agency', { method: 'POST' })
      ctx.refresh()
    } catch (e) {
      setUpgradeError(e.message || 'Upgrade failed')
    } finally {
      setUpgrading(false)
      setConfirmUpgrade(false)
    }
  }

  return (
    <div style={{ maxWidth: 600 }}>
      <div className="card mb-4">
        <div className="card-header fw-semibold">Account Details</div>
        <div className="card-body">
          <div className="mb-3">
            <label className="form-label text-muted small text-uppercase fw-semibold" style={{ letterSpacing: '0.05em' }}>Account Name</label>
            <div className="fw-semibold fs-5">{currentAccount?.name}</div>
          </div>
          <div className="mb-3">
            <label className="form-label text-muted small text-uppercase fw-semibold" style={{ letterSpacing: '0.05em' }}>Account Type</label>
            <div className="d-flex align-items-center gap-2">
              <span className={`badge ${isAgency ? 'bg-danger' : 'bg-secondary'} fs-6 fw-normal`}>
                {isAgency ? 'Agency' : 'Personal'}
              </span>
              {isAgency && (
                <small className="text-muted">Manage multiple clients from a single account.</small>
              )}
              {!isAgency && (
                <small className="text-muted">Single-workspace account.</small>
              )}
            </div>
          </div>
          <div>
            <label className="form-label text-muted small text-uppercase fw-semibold" style={{ letterSpacing: '0.05em' }}>Your Role</label>
            <div className="d-flex gap-2 flex-wrap">
              {roleBadges.map(({ label, color }) => (
                <span key={label} className={`badge bg-${color} fw-normal`}>{label}</span>
              ))}
            </div>
          </div>
        </div>
      </div>

      {!isAgency && isOwner && (
        <div className="card border-warning">
          <div className="card-header fw-semibold text-warning-emphasis bg-warning-subtle border-warning">
            Upgrade to Agency
          </div>
          <div className="card-body">
            <p className="text-muted small mb-3">
              Upgrading to an Agency account unlocks multi-client management. You'll be able to
              create and switch between clients, each with their own templates, audiences, and assets.
              Your existing work will be preserved as your first client.
            </p>
            <p className="text-muted small mb-3">
              <strong>This upgrade is permanent</strong> and cannot be undone from within the app.
            </p>
            {upgradeError && <div className="alert alert-danger py-2 small">{upgradeError}</div>}
            {!confirmUpgrade ? (
              <button className="btn btn-warning btn-sm" onClick={() => setConfirmUpgrade(true)}>
                <i className="bi bi-arrow-up-circle me-1"></i> Upgrade to Agency
              </button>
            ) : (
              <div className="d-flex align-items-center gap-2">
                <span className="text-muted small">Are you sure?</span>
                <button className="btn btn-warning btn-sm" onClick={handleUpgrade} disabled={upgrading}>
                  {upgrading ? 'Upgrading…' : 'Yes, upgrade'}
                </button>
                <button className="btn btn-outline-secondary btn-sm" onClick={() => setConfirmUpgrade(false)}>
                  Cancel
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

// ─── AI Usage Tab ────────────────────────────────────────────────────────────

function UsageTab() {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(1)
  const [expandedMonth, setExpandedMonth] = useState(null)

  const fetchUsage = (p) => {
    setLoading(true)
    apiFetch(`/api/ai_usage_summaries?page=${p}`)
      .then((res) => {
        setData(res)
        if (p === 1 && res.usage.length > 0) {
          setExpandedMonth(res.usage[0].month)
        }
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => { fetchUsage(page) }, [page])

  const formatTokens = (n) => {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
    return n.toLocaleString()
  }

  const formatMonth = (m) => {
    const [year, month] = m.split('-')
    const date = new Date(year, month - 1)
    return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
  }

  if (loading && !data) return <Spinner />

  if (!data || data.usage.length === 0) {
    return (
      <div style={{ maxWidth: 700 }}>
        <div className="text-center text-muted py-5">
          <i className="bi bi-bar-chart fs-1 d-block mb-3"></i>
          <p>No AI usage recorded yet. Usage will appear here once AI features are used.</p>
        </div>
      </div>
    )
  }

  // Group models by service within each month
  const groupByService = (models) => {
    const grouped = {}
    models.forEach((m) => {
      if (!grouped[m.ai_service_name]) grouped[m.ai_service_name] = []
      grouped[m.ai_service_name].push(m)
    })
    return grouped
  }

  return (
    <div style={{ maxWidth: 700 }}>
      {data.usage.map((monthData, idx) => {
        const isExpanded = expandedMonth === monthData.month
        const isCurrentMonth = idx === 0 && page === 1
        const serviceGroups = groupByService(monthData.models)
        const monthTotal = monthData.models.reduce((sum, m) => sum + m.total_tokens, 0)

        return (
          <div key={monthData.month} className="card mb-3">
            <div
              className="card-header d-flex justify-content-between align-items-center"
              style={{ cursor: 'pointer' }}
              onClick={() => setExpandedMonth(isExpanded ? null : monthData.month)}
            >
              <div className="d-flex align-items-center gap-2">
                <i className={`bi bi-chevron-${isExpanded ? 'down' : 'right'}`}></i>
                <span className="fw-semibold">{formatMonth(monthData.month)}</span>
                {isCurrentMonth && <span className="badge bg-danger">Current</span>}
              </div>
              <span className="text-muted small">{formatTokens(monthTotal)} tokens</span>
            </div>

            {isExpanded && (
              <div className="card-body p-0">
                {Object.entries(serviceGroups).map(([serviceName, models]) => (
                  <div key={serviceName}>
                    <div className="px-3 py-2 bg-light border-bottom">
                      <small className="fw-semibold text-muted text-uppercase" style={{ letterSpacing: '0.05em', fontSize: '0.75rem' }}>
                        {serviceName}
                      </small>
                    </div>
                    <table className="table table-sm mb-0">
                      <thead>
                        <tr>
                          <th className="ps-3">Model</th>
                          <th className="text-end">Input</th>
                          <th className="text-end">Output</th>
                          <th className="text-end pe-3">Total</th>
                        </tr>
                      </thead>
                      <tbody>
                        {models.map((m) => (
                          <tr key={m.id}>
                            <td className="ps-3">{m.ai_model_name}</td>
                            <td className="text-end text-muted">{formatTokens(m.input_tokens)}</td>
                            <td className="text-end text-muted">{formatTokens(m.output_tokens)}</td>
                            <td className="text-end pe-3 fw-semibold">{formatTokens(m.total_tokens)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ))}
              </div>
            )}
          </div>
        )
      })}

      {data.total_pages > 1 && (
        <div className="d-flex justify-content-between align-items-center mt-3">
          <button
            className="btn btn-outline-secondary btn-sm"
            disabled={page <= 1 || loading}
            onClick={() => setPage(page - 1)}
          >
            <i className="bi bi-chevron-left me-1"></i> Newer
          </button>
          <small className="text-muted">Page {page} of {data.total_pages}</small>
          <button
            className="btn btn-outline-secondary btn-sm"
            disabled={page >= data.total_pages || loading}
            onClick={() => setPage(page + 1)}
          >
            Older <i className="bi bi-chevron-right ms-1"></i>
          </button>
        </div>
      )}
    </div>
  )
}

// ─── Users Tab ────────────────────────────────────────────────────────────────

function UsersTab() {
  const ctx = useAccount()
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [addEmail, setAddEmail] = useState('')
  const [adding, setAdding] = useState(false)
  const [addError, setAddError] = useState(null)
  const [saving, setSaving] = useState(null) // account_user id being saved

  const isOwner = ctx?.is_owner
  const isAdmin = ctx?.is_admin
  const canManage = isOwner || isAdmin

  useEffect(() => {
    if (!canManage) { setLoading(false); return }
    apiFetch('/api/account_users')
      .then(setUsers)
      .finally(() => setLoading(false))
  }, [canManage])

  const handleAdd = async (e) => {
    e.preventDefault()
    if (!addEmail.trim()) return
    setAdding(true)
    setAddError(null)
    try {
      const created = await apiFetch('/api/account_users', {
        method: 'POST',
        body: JSON.stringify({ email: addEmail.trim() }),
      })
      setUsers((prev) => [...prev, created])
      setAddEmail('')
      if (created.new_user) {
        setAddError({ type: 'info', message: `A new account was created for ${created.email}. They've been sent an email to set their password.` })
      }
    } catch (err) {
      setAddError({ type: 'error', message: err.message || 'Failed to add user' })
    } finally {
      setAdding(false)
    }
  }

  const updateRole = async (au, field, value) => {
    setSaving(au.id)
    try {
      const updated = await apiFetch(`/api/account_users/${au.id}`, {
        method: 'PATCH',
        body: JSON.stringify({ account_user: { [field]: value } }),
      })
      setUsers((prev) => prev.map((u) => (u.id === au.id ? updated : u)))
    } catch (err) {
      alert(err.message || 'Failed to update role')
    } finally {
      setSaving(null)
    }
  }

  const removeUser = async (au) => {
    if (!confirm(`Remove ${au.email} from this account?`)) return
    try {
      await apiFetch(`/api/account_users/${au.id}`, { method: 'DELETE' })
      setUsers((prev) => prev.filter((u) => u.id !== au.id))
    } catch (err) {
      alert(err.message || 'Failed to remove user')
    }
  }

  if (loading) return <Spinner />

  if (!canManage) {
    return (
      <div className="text-center text-muted py-5">
        <i className="bi bi-lock fs-1 d-block mb-3"></i>
        <p>You need Owner or Admin access to manage users.</p>
      </div>
    )
  }

  return (
    <div style={{ maxWidth: 640 }}>
      <div className="card mb-4">
        <div className="card-header fw-semibold">Add User</div>
        <div className="card-body">
          {addError && (
            <div className={`alert ${addError.type === 'info' ? 'alert-info' : 'alert-danger'} py-2 small mb-3`}>
              {addError.message}
            </div>
          )}
          <form onSubmit={handleAdd}>
            <div className="d-flex gap-2">
              <input
                type="email"
                className="form-control"
                placeholder="Email address"
                value={addEmail}
                onChange={(e) => { setAddEmail(e.target.value); setAddError(null) }}
                required
              />
              <button className="btn btn-danger" type="submit" disabled={adding} style={{ whiteSpace: 'nowrap' }}>
                {adding ? 'Adding…' : 'Add User'}
              </button>
            </div>
          </form>
        </div>
      </div>

      {ctx?.is_agency && (
        <div className="alert alert-secondary d-flex align-items-center gap-2 mb-3" style={{ fontSize: '0.875rem' }}>
          <i className="bi bi-info-circle flex-shrink-0"></i>
          <span>
            To assign users to clients, go to the{' '}
            <Link to="/clients" className="alert-link">Clients tab</Link>.
          </span>
        </div>
      )}

      <div className="list-group">
        {users.map((au) => {
          const isMe = au.user_id === ctx?.current_user_id
          const isSaving = saving === au.id
          const canEditThis = !au.is_owner || isOwner // admins can't touch owners
          const canRemoveThis = (!au.is_owner || isOwner) && !isMe
          const alwaysHasAccess = au.is_owner || au.is_admin

          return (
            <div key={au.id} className="list-group-item">
              <div className="d-flex justify-content-between align-items-start">
                <div>
                  <div className="fw-semibold">
                    {au.email}
                    {isMe && <span className="ms-2 badge bg-secondary fw-normal">You</span>}
                  </div>
                  <div className="d-flex gap-1 mt-1 flex-wrap">
                    <RoleBadge label="Owner" active={au.is_owner} color="danger" />
                    <RoleBadge label="Admin" active={au.is_admin} color="warning" />
                    <RoleBadge label="Billing Admin" active={au.is_billing_admin} color="info" />
                    {!au.is_owner && !au.is_admin && !au.is_billing_admin && (
                      <span className="badge bg-light text-dark border fw-normal">Member</span>
                    )}
                  </div>
                  {ctx?.is_agency && (
                    <div className="mt-1" style={{ fontSize: '0.8rem' }}>
                      {alwaysHasAccess ? (
                        <span className="text-muted fst-italic">Access to all clients</span>
                      ) : au.clients.length === 0 ? (
                        <span className="text-muted fst-italic">No clients assigned</span>
                      ) : (
                        <span className="text-muted">
                          {au.clients.map((c) => c.name).join(', ')}
                        </span>
                      )}
                    </div>
                  )}
                </div>
                {canRemoveThis && (
                  <button
                    className="btn btn-sm btn-outline-danger ms-3"
                    onClick={() => removeUser(au)}
                    title="Remove from account"
                  >
                    <i className="bi bi-person-x"></i>
                  </button>
                )}
              </div>

              {canEditThis && !au.is_owner && (
                <div className="d-flex gap-2 mt-2 flex-wrap">
                  <RoleToggle
                    label="Admin"
                    active={au.is_admin}
                    disabled={isSaving || isMe}
                    onChange={(val) => updateRole(au, 'is_admin', val)}
                  />
                  {isOwner && (
                    <RoleToggle
                      label="Billing Admin"
                      active={au.is_billing_admin}
                      disabled={isSaving}
                      onChange={(val) => updateRole(au, 'is_billing_admin', val)}
                    />
                  )}
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function RoleBadge({ label, active, color }) {
  if (!active) return null
  return <span className={`badge bg-${color} fw-normal`}>{label}</span>
}

function RoleToggle({ label, active, disabled, onChange }) {
  return (
    <button
      className={`btn btn-sm ${active ? 'btn-danger' : 'btn-outline-secondary'}`}
      disabled={disabled}
      onClick={() => onChange(!active)}
    >
      {active ? <><i className="bi bi-check me-1"></i>{label}</> : `+ ${label}`}
    </button>
  )
}

function Spinner() {
  return (
    <div className="p-4">
      <div className="spinner-border spinner-border-sm" role="status">
        <span className="visually-hidden">Loading...</span>
      </div>
    </div>
  )
}
