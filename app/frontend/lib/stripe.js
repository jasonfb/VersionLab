import { loadStripe } from '@stripe/stripe-js'

let stripePromise = null

export function getStripe(publishableKey) {
  if (!stripePromise && publishableKey) {
    stripePromise = loadStripe(publishableKey)
  }
  return stripePromise
}
