import React, { useState, useRef, useEffect } from 'react'
import { useAccount } from './AccountContext'

export default function ClientSwitcher() {
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

  if (!ctx || !ctx.is_agency) return null

  const currentProject = ctx.projects?.find((p) => p.id === ctx.current_project_id)

  return (
    <div className="position-relative me-2" ref={ref}>
      <button
        className="btn btn-sm btn-outline-secondary d-flex align-items-center gap-1"
        onClick={() => setOpen(!open)}
      >
        <i className="bi bi-person-vcard"></i>
        {currentProject?.name || 'Select Client'}
        <i className="bi bi-chevron-down" style={{ fontSize: '0.7rem' }}></i>
      </button>
      {open && (
        <div
          className="position-absolute bg-white border rounded shadow-sm mt-1"
          style={{ zIndex: 1000, minWidth: 180 }}
        >
          {ctx.projects?.map((p) => (
            <button
              key={p.id}
              className={`dropdown-item px-3 py-2 ${p.id === ctx.current_project_id ? 'active' : ''}`}
              onClick={() => { ctx.switchProject(p.id); setOpen(false) }}
            >
              {p.name}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
