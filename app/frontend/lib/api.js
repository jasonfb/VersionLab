export const csrfToken = () =>
  document.querySelector('meta[name="csrf-token"]')?.content

export async function apiFetch(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken(),
      ...options.headers,
    },
  })

  if (!response.ok) {
    const body = await response.json().catch(() => ({}))
    throw new Error(body.errors?.join(', ') || `Request failed: ${response.status}`)
  }

  if (response.status === 204) return null
  return response.json()
}

export async function apiUpload(path, formData) {
  const response = await fetch(path, {
    method: 'POST',
    headers: { 'X-CSRF-Token': csrfToken() },
    body: formData,
  })

  if (!response.ok) {
    const body = await response.json().catch(() => ({}))
    throw new Error(body.errors?.join(', ') || `Upload failed: ${response.status}`)
  }

  return response.json()
}
