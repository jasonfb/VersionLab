import React from 'react'
import { NavLink } from 'react-router-dom'
import logoIcon from '../../../assets/images/version-lab-icon.png'

const navItems = [
  { to: '/projects', icon: 'bi-folder', label: 'Projects' },
  { to: '/templates', icon: 'bi-file-earmark-code', label: 'Templates' },
  { to: '/audiences', icon: 'bi-people', label: 'Audiences' },
  { to: '/assets', icon: 'bi-images', label: 'Assets' },
  { to: '/merge', icon: 'bi-intersect', label: 'Merge' },
  { to: '/settings', icon: 'bi-gear', label: 'Settings' },
]

export default function Sidebar() {
  return (
    <div className="app-sidebar d-flex flex-column align-items-center py-3">
      <div className="sidebar-logo mb-4">
        <img src={logoIcon} alt="Version Lab" />
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
