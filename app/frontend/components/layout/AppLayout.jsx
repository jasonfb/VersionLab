import React from 'react'
import { Outlet } from 'react-router-dom'
import Sidebar from './Sidebar'
import AccountSwitcher from './AccountSwitcher'
import ClientSwitcher from './ClientSwitcher'
import { AccountProvider } from './AccountContext'
import TrialExpiredBanner from './TrialExpiredBanner'

export default function AppLayout() {
  return (
    <AccountProvider>
      <div className="app-layout d-flex vh-100">
        <Sidebar />
        <div className="flex-grow-1 d-flex flex-column overflow-hidden">
          <header className="app-topbar d-flex align-items-center justify-content-between px-3 border-bottom">
            <div></div>
            <div className="d-flex align-items-center">
              <ClientSwitcher />
              <AccountSwitcher />
            </div>
          </header>
          <main className="flex-grow-1 overflow-auto">
            <Outlet />
          </main>
        </div>
      </div>
      <TrialExpiredBanner />
    </AccountProvider>
  )
}
