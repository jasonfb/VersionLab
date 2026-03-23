import React, { useEffect } from 'react'

export default function AdStyleGuideModal({ open, warnings = [], onClose }) {
  useEffect(() => {
    const handler = (e) => { if (e.key === 'Escape') onClose() }
    if (open) window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [open, onClose])

  if (!open) return null

  return (
    <div
      className="modal d-block"
      tabIndex="-1"
      style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}
      onClick={onClose}
    >
      <div
        className="modal-dialog modal-lg modal-dialog-scrollable"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="modal-content">
          <div className="modal-header">
            <h5 className="modal-title d-flex align-items-center gap-2">
              <i className="bi bi-file-earmark-text text-muted"></i>
              Ad Upload Style Guide
            </h5>
            <button type="button" className="btn-close" onClick={onClose} />
          </div>
          <div className="modal-body" style={{ fontSize: '0.9rem' }}>
            {/* File warnings for this specific ad */}
            {warnings.length > 0 && (
              <div className="alert alert-warning mb-4">
                <strong><i className="bi bi-exclamation-triangle me-1"></i>Warnings for this file:</strong>
                <ul className="mb-0 mt-2">
                  {warnings.map((w, i) => (
                    <li key={i}>{w.message}</li>
                  ))}
                </ul>
              </div>
            )}

            <Section title="File Format Requirements">
              <ul>
                <li>Export as <strong>SVG or PDF only</strong></li>
                <li>Do not upload PNG, JPG, EPS, or AI files</li>
                <li>Ensure the file contains <strong>editable layers</strong></li>
                <li>Do not flatten the file before export</li>
              </ul>
            </Section>

            <Section title="Live Text Requirements">
              <ul>
                <li>Preserve <strong>live text</strong> — do not convert text to outlines</li>
                <li>Do not rasterize text</li>
                <li>Use real space characters between words</li>
                <li>Avoid manual letter-by-letter positioning to simulate spacing</li>
                <li>Avoid exporting text as vector paths</li>
              </ul>
              <div className="alert alert-info py-2 px-3 small mt-2">
                Text converted to outlines or vector paths cannot be edited inside Version Lab.
              </div>
            </Section>

            <Section title="Layer Structure Recommendations">
              <ul>
                <li>Keep headline, subheadline, body, and CTA text on <strong>separate layers</strong></li>
                <li>Keep logos on their own layer</li>
                <li>Keep background image or background color on its own layer</li>
                <li>Avoid merging all elements into a single group</li>
              </ul>
            </Section>

            <Section title="Background Image Requirements">
              <ul>
                <li>Background images must meet minimum export size for selected ad dimensions</li>
                <li>Do not upscale images before export</li>
                <li>Avoid embedding low-resolution raster images</li>
                <li>Maintain original image resolution</li>
              </ul>
            </Section>

            <Section title="Spacing and Typography Best Practices">
              <ul>
                <li>Use standard word spacing (space bar)</li>
                <li>Avoid replacing spaces with tracking adjustments</li>
                <li>Avoid converting each word into separate positioned glyph blocks</li>
                <li>Ensure fonts are embedded or available</li>
              </ul>
            </Section>

            <Section title="Export Recommendations">
              <p><strong>For SVG:</strong></p>
              <ul>
                <li>Preserve text as text</li>
                <li>Do not outline fonts</li>
                <li>Avoid flattening groups</li>
              </ul>
              <p><strong>For PDF:</strong></p>
              <ul>
                <li>Export with editable text enabled</li>
                <li>Do not flatten transparency</li>
                <li>Do not convert text to outlines</li>
              </ul>
            </Section>

            <Section title="Adobe Illustrator — Export Settings">
              <p>Before exporting:</p>
              <ul>
                <li>Keep all text as live text</li>
                <li>Do not convert text to outlines</li>
                <li>Keep headline, body, and CTA text on separate layers</li>
                <li>Keep background on its own layer</li>
              </ul>
              <p><strong>When exporting as SVG:</strong></p>
              <ul>
                <li>File → Save As → SVG</li>
                <li>Preserve text as editable text</li>
                <li>Do not outline fonts</li>
                <li>Avoid flattening transparency</li>
                <li>Do not embed raster previews unless required</li>
              </ul>
              <p><strong>When exporting as PDF:</strong></p>
              <ul>
                <li>File → Save As → Adobe PDF</li>
                <li>Do not convert text to outlines</li>
                <li>Do not flatten transparency</li>
                <li>Preserve Illustrator editing capabilities</li>
                <li>Avoid exporting as a flattened image-only PDF</li>
              </ul>
            </Section>

            <Section title="Adobe InDesign — Export Settings">
              <p>Before exporting:</p>
              <ul>
                <li>Ensure all text remains live and editable</li>
                <li>Do not convert text to outlines</li>
                <li>Keep text frames separate for headline, body, and CTA</li>
                <li>Avoid merging all elements into a single grouped object</li>
              </ul>
              <p><strong>When exporting as PDF:</strong></p>
              <ul>
                <li>File → Export → Adobe PDF (Print)</li>
                <li>Do not convert text to outlines</li>
                <li>Do not flatten transparency</li>
                <li>Preserve editable text</li>
                <li>Avoid rasterizing spreads</li>
              </ul>
              <div className="alert alert-info py-2 px-3 small mt-2">
                InDesign does not export native SVG with full layer fidelity. If SVG is required, export through Illustrator while preserving live text.
              </div>
            </Section>

            <Section title="Common Causes of Word Spacing Loss">
              <p>Word spacing issues usually occur when text is not stored as natural text with real space characters.</p>
              <p>Common causes include:</p>
              <ul>
                <li>Replacing space characters with manual tracking adjustments</li>
                <li>Creating separate text objects for each word</li>
                <li>Converting text to outlines or vector paths</li>
                <li>Exporting PDFs that flatten text into positioned glyphs</li>
                <li>Using text effects that break natural word boundaries</li>
              </ul>
              <p><strong>Why this matters:</strong></p>
              <p>Version Lab detects words based on real space characters. If words are separated using tracking or manual positioning instead of actual space characters, editing may fail or spacing may collapse.</p>
              <p>To prevent this:</p>
              <ul>
                <li>Use the space bar for word spacing</li>
                <li>Keep full phrases inside a single text frame</li>
                <li>Avoid outlining fonts before export</li>
                <li>Do not manually adjust spacing to simulate gaps between words</li>
              </ul>
            </Section>

            <Section title="If Issues Are Detected">
              <p>Version Lab validates all uploaded creatives.</p>
              <ul>
                <li>Files that do not contain editable layers or live text will be blocked.</li>
                <li>Files with spacing or word-boundary issues may trigger a text integrity warning and require confirmation before editing.</li>
              </ul>
            </Section>
          </div>
          <div className="modal-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose}>Close</button>
          </div>
        </div>
      </div>
    </div>
  )
}

function Section({ title, children }) {
  return (
    <div className="mb-4">
      <h6 className="text-uppercase fw-semibold text-muted mb-2" style={{ fontSize: '0.72rem', letterSpacing: '0.08em' }}>
        {title}
      </h6>
      {children}
    </div>
  )
}
