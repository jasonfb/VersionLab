import { createConsumer } from '@rails/actioncable'

let consumer = null

function getConsumer() {
  if (!consumer) consumer = createConsumer()
  return consumer
}

// Subscribe to MergeChannel for a given mergeId.
// Returns an unsubscribe function.
export function subscribeMergeChannel(mergeId, { received }) {
  const subscription = getConsumer().subscriptions.create(
    { channel: 'MergeChannel', merge_id: mergeId },
    { received }
  )
  return () => subscription.unsubscribe()
}
