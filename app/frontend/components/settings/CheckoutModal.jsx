import React, { useState, useEffect } from 'react'
import { Elements, CardElement, useStripe, useElements } from '@stripe/react-stripe-js'
import { apiFetch } from '~/lib/api'
import { getStripe } from '~/lib/stripe'

export default function CheckoutModal({ tiers, currentTierSlug, stripePublishableKey, paymentMethods, onClose, onSuccess }) {
  const [step, setStep] = useState(1)
  const [selectedTier, setSelectedTier] = useState(null)
  const [billingInterval, setBillingInterval] = useState('monthly')
  const [clientSecret, setClientSecret] = useState(null)
  const [paymentIntentId, setPaymentIntentId] = useState(null)
  const [amountCents, setAmountCents] = useState(0)
  const [creditCents, setCreditCents] = useState(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  useEffect(() => {
    const handleEsc = (e) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', handleEsc)
    return () => document.removeEventListener('keydown', handleEsc)
  }, [onClose])

  const handleContinueToPayment = async () => {
    if (!selectedTier) return
    setLoading(true)
    setError(null)
    try {
      const result = await apiFetch('/api/subscription/create_payment_intent', {
        method: 'POST',
        body: JSON.stringify({ tier_slug: selectedTier.slug, billing_interval: billingInterval }),
      })
      setClientSecret(result.client_secret)
      setPaymentIntentId(result.payment_intent_id)
      setAmountCents(result.amount_cents)
      setCreditCents(result.credit_cents)
      setStep(2)
    } catch (e) {
      setError(e.message || 'Failed to create payment')
    } finally {
      setLoading(false)
    }
  }

  const handleBack = () => {
    setStep(1)
    setClientSecret(null)
    setPaymentIntentId(null)
  }

  const stripePromise = getStripe(stripePublishableKey)

  return (
    <div className="modal d-block" style={{ backgroundColor: 'rgba(0,0,0,0.5)' }} onClick={onClose}>
      <div className="modal-dialog modal-lg modal-dialog-centered" onClick={(e) => e.stopPropagation()}>
        <div className="modal-content">
          <div className="modal-header">
            <h5 className="modal-title">
              {step === 1 ? 'Choose a Plan' : 'Payment'}
            </h5>
            <button type="button" className="btn-close" onClick={onClose} />
          </div>
          <div className="modal-body">
            {error && <div className="alert alert-danger py-2 small">{error}</div>}

            {step === 1 && (
              <PlanPicker
                tiers={tiers}
                currentTierSlug={currentTierSlug}
                selectedTier={selectedTier}
                onSelect={setSelectedTier}
                billingInterval={billingInterval}
                onIntervalChange={setBillingInterval}
              />
            )}

            {step === 2 && clientSecret && (
              <Elements stripe={stripePromise} options={{ clientSecret }}>
                <CardForm
                  amountCents={amountCents}
                  creditCents={creditCents}
                  paymentIntentId={paymentIntentId}
                  clientSecret={clientSecret}
                  paymentMethods={paymentMethods}
                  onBack={handleBack}
                  onSuccess={onSuccess}
                  selectedTier={selectedTier}
                  billingInterval={billingInterval}
                />
              </Elements>
            )}
          </div>
          {step === 1 && (
            <div className="modal-footer">
              <button className="btn btn-outline-secondary" onClick={onClose}>Cancel</button>
              <button
                className="btn btn-danger"
                onClick={handleContinueToPayment}
                disabled={!selectedTier || loading}
              >
                {loading ? 'Loading...' : 'Continue to Payment'}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function PlanPicker({ tiers, currentTierSlug, selectedTier, onSelect, billingInterval, onIntervalChange }) {
  return (
    <div>
      <div className="d-flex justify-content-center mb-4">
        <div className="btn-group" role="group">
          <button
            className={`btn ${billingInterval === 'monthly' ? 'btn-danger' : 'btn-outline-secondary'}`}
            onClick={() => onIntervalChange('monthly')}
          >
            Monthly
          </button>
          <button
            className={`btn ${billingInterval === 'annual' ? 'btn-danger' : 'btn-outline-secondary'}`}
            onClick={() => onIntervalChange('annual')}
          >
            Annual
            <span className="badge bg-success ms-2">Save ~15%</span>
          </button>
        </div>
      </div>

      <div className="row g-3">
        {tiers.map((tier) => {
          const isCurrent = tier.slug === currentTierSlug
          const isSelected = selectedTier?.slug === tier.slug
          const price = billingInterval === 'annual' ? tier.annual_price_cents : tier.monthly_price_cents
          const monthlyEquivalent = billingInterval === 'annual'
            ? Math.round(tier.annual_price_cents / 12)
            : tier.monthly_price_cents

          return (
            <div key={tier.slug} className="col-md-6">
              <div
                className={`card h-100 ${isSelected ? 'border-danger' : ''} ${isCurrent ? 'border-secondary' : ''}`}
                style={{ cursor: isCurrent ? 'default' : 'pointer' }}
                onClick={() => !isCurrent && onSelect(tier)}
              >
                <div className="card-body text-center">
                  <h5 className="card-title">{tier.name}</h5>
                  <div className="fs-2 fw-bold mb-1">
                    ${(monthlyEquivalent / 100).toFixed(0)}
                    <span className="fs-6 fw-normal text-muted">/mo</span>
                  </div>
                  {billingInterval === 'annual' && (
                    <div className="text-muted small mb-3">
                      ${(price / 100).toFixed(0)} billed annually
                    </div>
                  )}
                  {isCurrent ? (
                    <span className="badge bg-secondary">Current Plan</span>
                  ) : isSelected ? (
                    <span className="badge bg-danger">Selected</span>
                  ) : (
                    <button className="btn btn-outline-danger btn-sm">Select</button>
                  )}
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

function CardForm({ amountCents, creditCents, paymentIntentId, clientSecret, paymentMethods, onBack, onSuccess, selectedTier, billingInterval }) {
  const stripe = useStripe()
  const elements = useElements()
  const [useExisting, setUseExisting] = useState(paymentMethods.length > 0 ? paymentMethods[0].id : null)
  const [useNewCard, setUseNewCard] = useState(paymentMethods.length === 0)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState(null)

  const handleSelectExisting = (pmId) => {
    setUseExisting(pmId)
    setUseNewCard(false)
  }

  const handleSelectNew = () => {
    setUseExisting(null)
    setUseNewCard(true)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!stripe) return
    setProcessing(true)
    setError(null)

    try {
      let result

      if (useNewCard) {
        const cardElement = elements.getElement(CardElement)
        result = await stripe.confirmCardPayment(clientSecret, {
          payment_method: { card: cardElement },
        })
      } else {
        const existingPm = paymentMethods.find((pm) => pm.id === useExisting)
        if (!existingPm) {
          setError('Please select a payment method')
          setProcessing(false)
          return
        }
        result = await stripe.confirmCardPayment(clientSecret, {
          payment_method: existingPm.stripe_payment_method_id,
        })
      }

      if (result.error) {
        setError(result.error.message)
        setProcessing(false)
        return
      }

      // Payment succeeded — confirm on our backend
      const stripePaymentMethodId = result.paymentIntent.payment_method
      await apiFetch('/api/subscription/confirm', {
        method: 'POST',
        body: JSON.stringify({
          payment_intent_id: paymentIntentId,
          stripe_payment_method_id: stripePaymentMethodId,
        }),
      })

      onSuccess()
    } catch (e) {
      setError(e.message || 'Payment failed')
      setProcessing(false)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <div className="mb-4">
        <div className="d-flex justify-content-between align-items-center mb-2">
          <span className="fw-semibold">{selectedTier.name} — {billingInterval}</span>
          <span className="fw-bold fs-5">${(amountCents / 100).toFixed(2)}</span>
        </div>
        {creditCents > 0 && (
          <div className="text-success small">
            <i className="bi bi-check-circle me-1"></i>
            ${(creditCents / 100).toFixed(2)} credit applied from your current plan
          </div>
        )}
      </div>

      {paymentMethods.length > 0 && (
        <div className="mb-4">
          <label className="form-label text-muted small text-uppercase fw-semibold" style={{ letterSpacing: '0.05em' }}>
            Payment Method
          </label>
          <div className="list-group mb-2">
            {paymentMethods.map((pm) => (
              <label
                key={pm.id}
                className={`list-group-item d-flex align-items-center gap-2 ${useExisting === pm.id && !useNewCard ? 'active' : ''}`}
                style={{ cursor: 'pointer' }}
              >
                <input
                  type="radio"
                  name="payment_method"
                  checked={useExisting === pm.id && !useNewCard}
                  onChange={() => handleSelectExisting(pm.id)}
                  className="form-check-input m-0"
                />
                <span>{pm.display_name}</span>
                <span className="text-muted small ms-auto">
                  {pm.card_exp_month}/{pm.card_exp_year}
                </span>
              </label>
            ))}
            <label
              className={`list-group-item d-flex align-items-center gap-2 ${useNewCard ? 'active' : ''}`}
              style={{ cursor: 'pointer' }}
            >
              <input
                type="radio"
                name="payment_method"
                checked={useNewCard}
                onChange={handleSelectNew}
                className="form-check-input m-0"
              />
              <span><i className="bi bi-plus-circle me-1"></i> Use a new card</span>
            </label>
          </div>
        </div>
      )}

      {useNewCard && (
        <div className="mb-4">
          <label className="form-label text-muted small text-uppercase fw-semibold" style={{ letterSpacing: '0.05em' }}>
            Card Details
          </label>
          <CardElement options={{
            style: {
              base: { fontSize: '16px', color: '#333', '::placeholder': { color: '#aab7c4' } },
              invalid: { color: '#dc3545' },
            },
          }} />
        </div>
      )}

      {error && <div className="alert alert-danger py-2 small">{error}</div>}

      <div className="d-flex justify-content-between">
        <button type="button" className="btn btn-outline-secondary" onClick={onBack}>
          <i className="bi bi-arrow-left me-1"></i> Back
        </button>
        <button type="submit" className="btn btn-danger" disabled={processing || !stripe}>
          {processing ? 'Processing...' : `Pay $${(amountCents / 100).toFixed(2)}`}
        </button>
      </div>
    </form>
  )
}
