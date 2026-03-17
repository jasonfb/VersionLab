import React, { useState, useRef, useEffect } from 'react'
import { useAccount } from './AccountContext'

export default function AccountSwitcher() {
  const ctx = useAccount()
  const [open, setOpen] = useState(false)
  const ref = useRef()

  useEffect(() => {
    function handleClick(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  if (!ctx) return null

  const currentAccount = ctx.accounts?.find((a) => a.id === ctx.current_account_id)
  const hasMultiple = ctx.accounts?.length > 1
  const isAgency = ctx.is_agency

  return (
    <div className="position-relative" ref={ref}>
      <button
        className="btn btn-sm btn-outline-secondary d-flex align-items-center gap-2"
        onClick={() => hasMultiple && setOpen(!open)}
        style={{ cursor: hasMultiple ? 'pointer' : 'default' }}
      >
        <i className="bi bi-building"></i>
        <span>{currentAccount?.name || 'Account'}</span>
        <span className={`badge ${isAgency ? 'bg-danger' : 'bg-secondary'} fw-normal`} style={{ fontSize: '0.65rem' }}>
          {isAgency ? 'Agency' : 'Personal'}
        </span>
        {hasMultiple && <i className="bi bi-chevron-down" style={{ fontSize: '0.7rem' }}></i>}
      </button>
      {open && hasMultiple && (
        <div
          className="position-absolute end-0 bg-white border rounded shadow-sm mt-1"
          style={{ zIndex: 1000, minWidth: 220 }}
        >
          {ctx.accounts?.map((a) => (
            <button
              key={a.id}
              className={`dropdown-item px-3 py-2 d-flex align-items-center justify-content-between ${a.id === ctx.current_account_id ? 'active' : ''}`}
              onClick={() => { ctx.switchAccount(a.id); setOpen(false) }}
            >
              <span>{a.name}</span>
              <span className={`badge ${a.is_agency ? 'bg-danger' : 'bg-secondary'} fw-normal ms-2`} style={{ fontSize: '0.6rem' }}>
                {a.is_agency ? 'Agency' : 'Personal'}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
