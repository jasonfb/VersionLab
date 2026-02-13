import React from 'react'
import { Outlet } from 'react-router-dom'
import Sidebar from './Sidebar'
import AccountSwitcher from './AccountSwitcher'

export default function AppLayout() {
  return (
    <div className="app-layout d-flex vh-100">
      <Sidebar />
      <div className="flex-grow-1 d-flex flex-column overflow-hidden">
        <header className="app-topbar d-flex align-items-center justify-content-between px-3 border-bottom">
          <div></div>
          <AccountSwitcher />
        </header>
        <main className="flex-grow-1 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
