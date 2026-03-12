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

  const switchProject = async (projectId) => {
    await apiFetch('/api/switch_project', {
      method: 'POST',
      body: JSON.stringify({ project_id: projectId }),
    })
    window.location.reload()
  }

  return (
    <AccountContext.Provider value={state ? { ...state, switchAccount, switchProject } : null}>
      {children}
    </AccountContext.Provider>
  )
}

export function useAccount() {
  return useContext(AccountContext)
}
