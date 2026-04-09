import React, { useState, useEffect } from 'react'
import { apiFetch } from '~/lib/api'
import { useAccount } from '../layout/AccountContext'
import CheckoutModal from './CheckoutModal'
import PaymentHistory from './PaymentHistory'

export default function SubscriptionTab() {
  const ctx = useAccount()
  const [data, setData] = useState(null)
  const [paymentMethods, setPaymentMethods] = useState([])
  const [loading, setLoading] = useState(true)
  const [showCheckout, setShowCheckout] = useState(false)

  const canManage = ctx?.is_owner || ctx?.is_admin || ctx?.is_billing_admin

  const fetchData = () => {
    Promise.all([
      apiFetch('/api/subscription'),
      canManage ? apiFetch('/api/payment_methods') : Promise.resolve([]),
    ])
      .then(([subData, pmData]) => {
        setData(subData)
        setPaymentMethods(pmData)
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    fetchData()
  }, [canManage])

  const handleCheckoutSuccess = () => {
    setShowCheckout(false)
    setLoading(true)
    fetchData()
    ctx.refresh()
  }

  const handleSetDefault = async (pmId) => {
    await apiFetch(`/api/payment_methods/${pmId}/set_default`, { method: 'POST' })
    setPaymentMethods((prev) =>
      prev.map((pm) => ({ ...pm, is_default: pm.id === pmId }))
    )
  }

  const handleRemoveCard = async (pmId) => {
    if (!confirm('Remove this payment method?')) return
    await apiFetch(`/api/payment_methods/${pmId}`, { method: 'DELETE' })
    setPaymentMethods((prev) => prev.filter((pm) => pm.id !== pmId))
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

  const sub = data?.subscription
  const tiers = data?.tiers || []

  return (
    <div style={{ maxWidth: 700 }}>
      {/* Trial expired banner */}
      {sub?.trial_expired && (
        <div className="alert alert-danger d-flex align-items-center gap-2 mb-4">
          <i className="bi bi-exclamation-triangle-fill"></i>
          <div>
            <strong>Your free trial has ended.</strong> Choose a plan to continue using VersionLab.
          </div>
        </div>
      )}

      {/* Current Plan */}
      <div className="card mb-4">
        <div className="card-header fw-semibold">Current Plan</div>
        <div className="card-body">
          <div className="d-flex justify-content-between align-items-start">
            <div>
              <div className="d-flex align-items-center gap-2 mb-2">
                <span className="fs-5 fw-semibold">{sub?.tier_name || 'No Plan'}</span>
                {sub?.is_free_trial && !sub?.trial_expired && (
                  <span className="badge bg-info">Trial</span>
                )}
                {sub?.is_overdue && (
                  <span className="badge bg-danger">Overdue</span>
                )}
              </div>
              {sub && !sub.is_free_trial && (
                <div className="text-muted small">
                  {sub.billing_interval === 'annual' ? 'Annual' : 'Monthly'} billing
                  &nbsp;&middot;&nbsp;
                  ${(sub.price_cents / 100).toFixed(2)}/{sub.billing_interval === 'annual' ? 'yr' : 'mo'}
                </div>
              )}
              {sub && (
                <div className="text-muted small mt-1">
                  {sub.is_free_trial
                    ? `Trial ${sub.trial_expired ? 'expired' : 'ends'} ${formatDate(sub.paid_through_date)}`
                    : `Paid through ${formatDate(sub.paid_through_date)}`
                  }
                </div>
              )}
            </div>
            {canManage && (
              <button className="btn btn-danger btn-sm" onClick={() => setShowCheckout(true)}>
                <i className="bi bi-arrow-up-circle me-1"></i>
                {sub?.is_free_trial || !sub ? 'Choose a Plan' : 'Upgrade'}
              </button>
            )}
          </div>
        </div>
      </div>

      {/* VersionLab Tokens */}
      {sub?.tokens && (
        <div className="card mb-4">
          <div className="card-header fw-semibold d-flex justify-content-between align-items-center">
            <span>
              <i className="bi bi-lightning-charge-fill me-1 text-warning"></i>
              VersionLab Tokens
            </span>
            <span className="text-muted small fw-normal">
              Cycle: {formatDate(sub.tokens.cycle_start)} – {formatDate(sub.tokens.cycle_end)}
            </span>
          </div>
          <div className="card-body">
            <div className="d-flex justify-content-between mb-1">
              <span className="small text-muted">Used this cycle</span>
              <span className="small fw-semibold">
                {sub.tokens.used_this_cycle.toLocaleString()} / {sub.tokens.monthly_allotment.toLocaleString()}
              </span>
            </div>
            <div className="progress mb-3" style={{ height: 8 }}>
              <div
                className={`progress-bar ${sub.tokens.overage_tokens > 0 ? 'bg-danger' : 'bg-success'}`}
                role="progressbar"
                style={{
                  width: `${Math.min(
                    100,
                    (sub.tokens.used_this_cycle / Math.max(1, sub.tokens.monthly_allotment)) * 100
                  )}%`,
                }}
              />
            </div>
            <div className="row text-center small">
              <div className="col">
                <div className="text-muted">Allotment</div>
                <div className="fw-semibold">{sub.tokens.monthly_allotment.toLocaleString()}</div>
              </div>
              <div className="col">
                <div className="text-muted">Remaining</div>
                <div className="fw-semibold">{sub.tokens.remaining.toLocaleString()}</div>
              </div>
              <div className="col">
                <div className="text-muted">Overage</div>
                <div className={`fw-semibold ${sub.tokens.overage_tokens > 0 ? 'text-danger' : ''}`}>
                  {sub.tokens.overage_tokens.toLocaleString()}
                </div>
              </div>
              <div className="col">
                <div className="text-muted">Overage charge</div>
                <div className={`fw-semibold ${sub.tokens.overage_cents > 0 ? 'text-danger' : ''}`}>
                  ${(sub.tokens.overage_cents / 100).toFixed(2)}
                </div>
              </div>
            </div>
            <div className="alert alert-info small mt-3 mb-0">
              <i className="bi bi-info-circle me-1"></i>
              <strong>Remember:</strong> You get {sub.tokens.monthly_allotment.toLocaleString()} VersionLab tokens
              per month included. VersionLab tokens do not map 1:1 to the AI tokens you see from
              the AI providers. More expensive models use tokens faster. After{' '}
              {sub.tokens.monthly_allotment.toLocaleString()} tokens, you will pay an overage fee of $
              {(sub.tokens.overage_rate_per_1000_cents / 100 / 1000).toFixed(3)} per token, billed
              at the end of your billing cycle.
            </div>
          </div>
        </div>
      )}

      {/* Next Payment */}
      {sub && !sub.is_free_trial && !sub.trial_expired && (
        <div className="card mb-4">
          <div className="card-header fw-semibold">Next Payment</div>
          <div className="card-body">
            <div className="d-flex justify-content-between align-items-center">
              <div>
                <div className="fw-semibold">
                  ${((sub.price_cents + (sub.tokens?.overage_cents || 0)) / 100).toFixed(2)}
                </div>
                <div className="text-muted small">
                  Due {formatDate(sub.paid_through_date)}
                  {sub.tokens?.overage_cents > 0 && (
                    <> &middot; includes ${(sub.tokens.overage_cents / 100).toFixed(2)} token overage</>
                  )}
                </div>
              </div>
              {paymentMethods.length > 0 && (
                <div className="text-muted small">
                  <i className="bi bi-credit-card me-1"></i>
                  {paymentMethods.find((pm) => pm.is_default)?.display_name || paymentMethods[0]?.display_name}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Payment Methods */}
      {canManage && (
        <div className="card mb-4">
          <div className="card-header fw-semibold">Payment Methods</div>
          <div className="card-body">
            {paymentMethods.length === 0 ? (
              <div className="text-muted small text-center py-2">
                No payment methods on file.
              </div>
            ) : (
              <div className="list-group list-group-flush">
                {paymentMethods.map((pm) => (
                  <div key={pm.id} className="list-group-item d-flex justify-content-between align-items-center px-0">
                    <div>
                      <i className="bi bi-credit-card me-2"></i>
                      <span className="fw-semibold">{pm.card_brand?.toUpperCase()}</span>
                      <span className="text-muted ms-1">ending in {pm.card_last4}</span>
                      <span className="text-muted small ms-2">{pm.card_exp_month}/{pm.card_exp_year}</span>
                      {pm.is_default && <span className="badge bg-secondary ms-2 fw-normal">Default</span>}
                    </div>
                    <div className="d-flex gap-1">
                      {!pm.is_default && (
                        <button
                          className="btn btn-outline-secondary btn-sm"
                          onClick={() => handleSetDefault(pm.id)}
                          title="Set as default"
                        >
                          Set default
                        </button>
                      )}
                      <button
                        className="btn btn-outline-danger btn-sm"
                        onClick={() => handleRemoveCard(pm.id)}
                        title="Remove"
                      >
                        <i className="bi bi-trash"></i>
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Payment History */}
      {canManage && (
        <div className="card mb-4">
          <div className="card-header fw-semibold">Payment History</div>
          <div className="card-body p-0">
            <PaymentHistory />
          </div>
        </div>
      )}

      {/* Checkout Modal */}
      {showCheckout && (
        <CheckoutModal
          tiers={tiers}
          currentTierSlug={sub?.tier_slug}
          stripePublishableKey={data?.stripe_publishable_key}
          paymentMethods={paymentMethods}
          onClose={() => setShowCheckout(false)}
          onSuccess={handleCheckoutSuccess}
        />
      )}
    </div>
  )
}

function formatDate(dateStr) {
  if (!dateStr) return '—'
  return new Date(dateStr + 'T00:00:00').toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}
