import React, { useState, useEffect, useRef } from 'react'
import { apiFetch } from '~/lib/api'

export default function AccountSwitcher() {
  const [accounts, setAccounts] = useState([])
  const [currentAccountId, setCurrentAccountId] = useState(null)
  const [open, setOpen] = useState(false)
  const ref = useRef()

  useEffect(() => {
    apiFetch('/api/accounts').then((data) => {
      setAccounts(data.accounts)
      setCurrentAccountId(data.current_account_id)
    })
  }, [])

  useEffect(() => {
    function handleClick(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  const currentAccount = accounts.find((a) => a.id === currentAccountId)

  if (accounts.length <= 1) return null

  const switchAccount = async (id) => {
    await apiFetch('/api/switch_account', {
      method: 'POST',
      body: JSON.stringify({ account_id: id }),
    })
    setCurrentAccountId(id)
    setOpen(false)
    window.location.reload()
  }

  return (
    <div className="position-relative" ref={ref}>
      <button
        className="btn btn-sm btn-outline-secondary d-flex align-items-center gap-1"
        onClick={() => setOpen(!open)}
      >
        <i className="bi bi-building"></i>
        {currentAccount?.name || 'Account'}
        <i className="bi bi-chevron-down" style={{ fontSize: '0.7rem' }}></i>
      </button>
      {open && (
        <div
          className="position-absolute bg-white border rounded shadow-sm mt-1"
          style={{ zIndex: 1000, minWidth: 180 }}
        >
          {accounts.map((a) => (
            <button
              key={a.id}
              className={`dropdown-item px-3 py-2 ${a.id === currentAccountId ? 'active' : ''}`}
              onClick={() => switchAccount(a.id)}
            >
              {a.name}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
