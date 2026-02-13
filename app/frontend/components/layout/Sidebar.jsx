import React from 'react'
import { NavLink } from 'react-router-dom'

const navItems = [
  { to: '/templates', icon: 'bi-file-earmark-code', label: 'Templates' },
  { to: '/assets', icon: 'bi-images', label: 'Assets' },
  { to: '/merge', icon: 'bi-intersect', label: 'Merge' },
  { to: '/settings', icon: 'bi-gear', label: 'Settings' },
]

export default function Sidebar() {
  return (
    <div className="app-sidebar d-flex flex-column align-items-center py-3">
      <div className="sidebar-logo mb-4">
        <span className="fw-bold text-danger fs-5">V</span>
      </div>
      <nav className="flex-grow-1 d-flex flex-column gap-1">
        {navItems.map(({ to, icon, label }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              `sidebar-icon d-flex flex-column align-items-center justify-content-center rounded p-2 text-decoration-none ${
                isActive ? 'active' : ''
              }`
            }
            data-tooltip={label}
          >
            <i className={`bi ${icon} fs-5`}></i>
          </NavLink>
        ))}
      </nav>
    </div>
  )
}
