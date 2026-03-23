import { createConsumer } from '@rails/actioncable'

let consumer = null

function getConsumer() {
  if (!consumer) consumer = createConsumer()
  return consumer
}

// Subscribe to EmailChannel for a given emailId.
// Returns an unsubscribe function.
export function subscribeEmailChannel(emailId, { received }) {
  const subscription = getConsumer().subscriptions.create(
    { channel: 'EmailChannel', email_id: emailId },
    { received }
  )
  return () => subscription.unsubscribe()
}

// Subscribe to AdChannel for a given adId.
// Returns an unsubscribe function.
export function subscribeAdChannel(adId, { received }) {
  const subscription = getConsumer().subscriptions.create(
    { channel: 'AdChannel', ad_id: adId },
    { received }
  )
  return () => subscription.unsubscribe()
}

// Subscribe to TemplateImportChannel for a given importId.
// Returns an unsubscribe function.
export function subscribeTemplateImportChannel(importId, { received }) {
  const subscription = getConsumer().subscriptions.create(
    { channel: 'TemplateImportChannel', import_id: importId },
    { received }
  )
  return () => subscription.unsubscribe()
}
