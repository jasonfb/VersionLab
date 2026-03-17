import React, { createContext, useContext, useState, useEffect } from 'react'
import { apiFetch } from '~/lib/api'

const AccountContext = createContext(null)

export function AccountProvider({ children }) {
  const [state, setState] = useState(null)

  useEffect(() => {
    apiFetch('/api/accounts').then(setState)
  }, [])

  const switchAccount = async (accountId) => {
    await apiFetch('/api/switch_account', {
      method: 'POST',
      body: JSON.stringify({ account_id: accountId }),
    })
    window.location.reload()
  }

  const switchClient = async (clientId) => {
    await apiFetch('/api/switch_client', {
      method: 'POST',
      body: JSON.stringify({ client_id: clientId }),
    })
    window.location.reload()
  }

  const refresh = () => apiFetch('/api/accounts').then(setState)

  return (
    <AccountContext.Provider value={state ? { ...state, switchAccount, switchClient, refresh } : null}>
      {children}
    </AccountContext.Provider>
  )
}

export function useAccount() {
  return useContext(AccountContext)
}
