/**
 * Compute the CSS object-position value for cropping a background image
 * to a target aspect ratio while keeping the subject centered.
 *
 * Currently uses center-crop heuristic. Future: use focal point from
 * AI vision API (stored as asset.focal_point) to keep faces/subjects
 * in frame and avoid putting text over people.
 *
 * @param {object} asset - Asset with { width, height, focal_point? }
 * @param {number} targetWidth - Target canvas width
 * @param {number} targetHeight - Target canvas height
 * @returns {string} CSS object-position value (e.g., "center", "30% 40%")
 */
export function getCropPosition(asset, targetWidth, targetHeight) {
  // Future: if asset has AI-detected focal point, use it
  if (asset?.focal_point) {
    return `${asset.focal_point.x}% ${asset.focal_point.y}%`
  }

  // Default: center crop
  return 'center'
}
