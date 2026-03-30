import React from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import { useAccount } from './AccountContext'

export default function TrialExpiredBanner() {
  const ctx = useAccount()
  const location = useLocation()
  const navigate = useNavigate()

  if (!ctx?.subscription?.trial_expired) return null
  if (location.pathname === '/settings') return null

  return (
    <div
      className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
      style={{ backgroundColor: 'rgba(0,0,0,0.6)', zIndex: 1050 }}
    >
      <div className="card shadow-lg" style={{ maxWidth: 480 }}>
        <div className="card-body text-center p-5">
          <i className="bi bi-clock-history fs-1 text-danger d-block mb-3"></i>
          <h4 className="mb-3">Your Free Trial Has Ended</h4>
          <p className="text-muted mb-4">
            Choose a plan to continue using VersionLab. Your data is safe and waiting for you.
          </p>
          <button
            className="btn btn-danger"
            onClick={() => navigate('/settings')}
          >
            <i className="bi bi-arrow-up-circle me-1"></i>
            Choose a Plan
          </button>
        </div>
      </div>
    </div>
  )
}
