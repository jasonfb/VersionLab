import React, { useState } from 'react'

export const SLOT_ROLES = [
  { value: 'teaser_text', label: 'Teaser Text', description: 'Pre-frame text above the main creative (short, directive)' },
  { value: 'eyebrow', label: 'Eyebrow', description: 'Context or category label before the headline (2–5 words)' },
  { value: 'headline', label: 'Headline', description: 'Primary value statement or core idea (5–12 words)' },
  { value: 'subheadline', label: 'Subheadline', description: 'Clarifies or sharpens the headline (8–20 words)' },
  { value: 'body', label: 'Body', description: 'Supporting detail that expands the headline (variable length)' },
  { value: 'cta_text', label: 'CTA Text', description: 'Action-oriented button label that drives the click (2–5 words)' },
]

export const IMAGE_LOCATION_TYPES = [
  { value: 'hero', label: 'Hero', description: 'Full-width header image at the top of the email' },
  { value: 'banner', label: 'Banner', description: 'Wide horizontal promotional strip' },
  { value: 'sidebar', label: 'Sidebar', description: 'Narrow side-column image alongside content' },
  { value: 'inline', label: 'Inline', description: 'Embedded within the content flow' },
  { value: 'footer', label: 'Footer', description: 'Image at the bottom of the email' },
]

// Renders inline in the sidebar — no floating positioning needed.
export default function VariablePopover({ variableType, selectedText, initialWordCount, onConfirm, onCancel }) {
  const [slotRole, setSlotRole] = useState('')
  const [wordCount, setWordCount] = useState(initialWordCount ?? '')
  const [imageLocation, setImageLocation] = useState('')

  const isImage = variableType === 'image'
  const selectedRoleObj = SLOT_ROLES.find((r) => r.value === slotRole)
  const selectedLocationObj = IMAGE_LOCATION_TYPES.find((l) => l.value === imageLocation)
  const canConfirm = isImage ? true : slotRole !== ''

  return (
    <div>
      <p className="small fw-semibold mb-1">New Variable from Selection</p>
      {selectedText && (
        <p className="small text-muted text-truncate mb-2">&ldquo;{selectedText}&rdquo;</p>
      )}

      {isImage ? (
        <div className="mb-3">
          <label className="form-label small fw-semibold mb-1">Image Location</label>
          <select
            className="form-select form-select-sm"
            value={imageLocation}
            onChange={(e) => setImageLocation(e.target.value)}
          >
            <option value="">Select location</option>
            {IMAGE_LOCATION_TYPES.map((l) => (
              <option key={l.value} value={l.value}>{l.label}</option>
            ))}
          </select>
          {selectedLocationObj && (
            <div className="text-muted mt-1" style={{ fontSize: '0.72rem' }}>
              {selectedLocationObj.description}
            </div>
          )}
        </div>
      ) : (
        <>
          <div className="mb-2">
            <label className="form-label small fw-semibold mb-1">
              Slot Role <span className="text-danger">*</span>
            </label>
            <select
              className="form-select form-select-sm"
              value={slotRole}
              onChange={(e) => setSlotRole(e.target.value)}
            >
              <option value="">Select role</option>
              {SLOT_ROLES.map((r) => (
                <option key={r.value} value={r.value}>{r.label}</option>
              ))}
            </select>
            {selectedRoleObj && (
              <div className="text-muted mt-1" style={{ fontSize: '0.72rem' }}>
                {selectedRoleObj.description}
              </div>
            )}
          </div>

          <div className="mb-3">
            <label className="form-label small fw-semibold mb-1">
              Word Count <span className="text-danger">*</span>
            </label>
            <input
              type="number"
              className="form-control form-control-sm"
              value={wordCount}
              min={1}
              onChange={(e) => setWordCount(e.target.value)}
              style={{ width: 90 }}
            />
            {initialWordCount != null && (
              <div className="text-muted mt-1" style={{ fontSize: '0.72rem' }}>
                Detected: {initialWordCount} words
              </div>
            )}
          </div>
        </>
      )}

      <div className="d-flex gap-2">
        <button
          className="btn btn-sm btn-danger"
          onClick={() => onConfirm({
            slotRole: isImage ? null : (slotRole || null),
            wordCount: isImage ? null : (wordCount !== '' ? parseInt(wordCount, 10) : null),
            imageLocation: isImage ? (imageLocation || null) : null,
          })}
          disabled={!canConfirm}
        >
          <i className="bi bi-check me-1"></i>
          Confirm Variable
        </button>
        <button className="btn btn-sm btn-outline-secondary" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </div>
  )
}
