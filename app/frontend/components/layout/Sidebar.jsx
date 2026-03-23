import React from 'react'
import { NavLink } from 'react-router-dom'
import logoIcon from '../../../assets/images/version-lab-icon.png'
import { useAccount } from './AccountContext'

export default function Sidebar() {
  const ctx = useAccount()
  const isAgency = ctx?.is_agency
  const isAgencyAdmin = isAgency && (ctx?.is_owner || ctx?.is_admin)
  const isAgencyMember = isAgency && !isAgencyAdmin

  const navItems = [
    isAgencyAdmin && { to: '/clients', icon: 'bi-person-vcard', label: 'Clients' },
    { to: '/templates', icon: 'bi-file-earmark-code', label: 'Templates' },
    (!isAgency || isAgencyMember) && { to: '/campaigns', icon: 'bi-flag', label: 'Campaigns' },
    isAgencyMember && { to: '/brand-profile', icon: 'bi-palette', label: 'Brand' },
    { to: '/audiences', icon: 'bi-people', label: 'Audiences' },
    { to: '/assets', icon: 'bi-images', label: 'Assets' },
    { to: '/emails', icon: 'bi-intersect', label: 'Emails' },
    { to: '/ads', icon: 'bi-megaphone', label: 'Ads' },
    { to: '/settings', icon: 'bi-gear', label: 'Settings' },
  ].filter(Boolean)

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
