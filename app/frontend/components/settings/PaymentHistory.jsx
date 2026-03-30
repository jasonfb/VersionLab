import React, { useState, useEffect } from 'react'
import { apiFetch } from '~/lib/api'

export default function PaymentHistory() {
  const [payments, setPayments] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    apiFetch('/api/payments')
      .then(setPayments)
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [])

  if (loading) {
    return (
      <div className="p-3">
        <div className="spinner-border spinner-border-sm" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    )
  }

  if (payments.length === 0) {
    return (
      <div className="text-center text-muted py-4">
        <i className="bi bi-receipt fs-1 d-block mb-2"></i>
        <p className="mb-0">No payments yet.</p>
      </div>
    )
  }

  return (
    <div className="table-responsive">
      <table className="table table-sm">
        <thead>
          <tr>
            <th className="text-muted small text-uppercase">Date</th>
            <th className="text-muted small text-uppercase">Description</th>
            <th className="text-muted small text-uppercase">Card</th>
            <th className="text-muted small text-uppercase">Amount</th>
            <th className="text-muted small text-uppercase">Status</th>
          </tr>
        </thead>
        <tbody>
          {payments.map((p) => (
            <tr key={p.id}>
              <td className="small">{new Date(p.created_at).toLocaleDateString()}</td>
              <td className="small">{p.description}</td>
              <td className="small text-muted">{p.card_display || '—'}</td>
              <td className="small">${(p.amount_cents / 100).toFixed(2)}</td>
              <td>
                <StatusBadge status={p.status} />
                {p.failure_reason && (
                  <div className="text-danger small mt-1">{p.failure_reason}</div>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function StatusBadge({ status }) {
  const colors = {
    succeeded: 'bg-success',
    failed: 'bg-danger',
    pending: 'bg-warning',
    refunded: 'bg-secondary',
  }
  return (
    <span className={`badge ${colors[status] || 'bg-secondary'} fw-normal`}>
      {status}
    </span>
  )
}
