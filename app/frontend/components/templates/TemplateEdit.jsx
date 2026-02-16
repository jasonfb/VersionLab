import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import {
  insertTextPlaceholder,
  removeTextPlaceholder,
  insertImageMarker,
  removeImageMarker,
  buildPreviewHtml,
} from '~/lib/variableSelection'
import VariablePopover from './VariablePopover'

export default function TemplateEdit() {
  const { projectId, id } = useParams()
  const navigate = useNavigate()
  const iframeRef = useRef(null)
  const [template, setTemplate] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [name, setName] = useState('')
  const [rawSourceHtml, setRawSourceHtml] = useState('')
  const [originalRawSourceHtml, setOriginalRawSourceHtml] = useState(null)
  const [sections, setSections] = useState([])
  const [expandedSection, setExpandedSection] = useState(null)
  const [activeTab, setActiveTab] = useState('sections')
  const [error, setError] = useState(null)
  const [popover, setPopover] = useState(null)
  const [hoveredVarId, setHoveredVarId] = useState(null)
  const [resetting, setResetting] = useState(false)
  const expandedSectionRef = useRef(null)

  // Flat list of every variable across all sections (for preview builder)
  const allVariables = useMemo(
    () => sections.flatMap((s) => s.variables || []),
    [sections],
  )

  useEffect(() => {
    apiFetch(`/api/projects/${projectId}/email_templates/${id}`)
      .then((data) => {
        setTemplate(data)
        setName(data.name)
        setRawSourceHtml(data.raw_source_html || '')
        setOriginalRawSourceHtml(data.original_raw_source_html || null)
        setSections(data.sections || [])
      })
      .finally(() => setLoading(false))
  }, [id])

  // Keep ref in sync so iframe handlers always read the latest value
  // without needing to re-run the effect (which rewrites the document).
  useEffect(() => {
    expandedSectionRef.current = expandedSection
  }, [expandedSection])

  // Write preview HTML into iframe and attach event listeners.
  // Uses expandedSectionRef so we only rewrite when content changes.
  useEffect(() => {
    const iframe = iframeRef.current
    if (!iframe || !rawSourceHtml) return

    const preview = buildPreviewHtml(rawSourceHtml, allVariables)
    let removeListeners = null

    const writeAndAttach = () => {
      const doc = iframe.contentDocument
      if (!doc) return

      doc.open()
      doc.write(preview)
      doc.close()

      const handleMouseUp = () => {
        const selection = doc.getSelection()
        if (!selection || selection.isCollapsed || !selection.toString().trim()) return
        if (!expandedSectionRef.current) return

        // Don't allow selecting inside an existing variable span
        const anchor = selection.anchorNode?.parentElement
        if (anchor?.closest('[data-vl-var]')) return

        const range = selection.getRangeAt(0)
        const rect = range.getBoundingClientRect()
        const iframeRect = iframe.getBoundingClientRect()

        // Figure out which occurrence (0-based) of the selected text the
        // user chose in the visible document.  We count how many full matches
        // start *before* this selection's start offset in the body text.
        // This occurrence index is stable regardless of {{vl:…}} tokens in
        // the raw HTML because those tokens don't contain normal prose.
        let occurrenceIndex = 0
        try {
          const preRange = doc.createRange()
          preRange.setStart(doc.body, 0)
          preRange.setEnd(range.startContainer, range.startOffset)
          const preText = preRange.toString()
          const bodyText = doc.body.textContent || ''
          const selText = selection.toString()
          const norm = (s) => s.replace(/\s+/g, ' ')
          const normBody = norm(bodyText)
          const normSel = norm(selText)
          const normPreLen = norm(preText).length
          let pos = 0
          while (true) {
            const idx = normBody.indexOf(normSel, pos)
            if (idx === -1 || idx >= normPreLen) break
            occurrenceIndex++
            pos = idx + 1
          }
        } catch (e) {
          console.warn('[handleMouseUp] occurrence calc error:', e)
        }

        console.log('[handleMouseUp] selection:', {
          selectedText: selection.toString(),
          occurrenceIndex,
        })

        setPopover({
          type: 'text',
          selectedText: selection.toString(),
          occurrenceIndex,
          top: iframeRect.top + rect.bottom + 4,
          left: iframeRect.left + rect.left,
        })
      }

      const handleClick = (e) => {
        const img = e.target.closest('img')
        if (!img || img.hasAttribute('data-vl-var')) return
        if (!expandedSectionRef.current) return

        e.preventDefault()
        const rect = img.getBoundingClientRect()
        const iframeRect = iframe.getBoundingClientRect()

        setPopover({
          type: 'image',
          imgSrc: img.getAttribute('src') || '',
          top: iframeRect.top + rect.bottom + 4,
          left: iframeRect.left + rect.left,
        })
      }

      doc.addEventListener('mouseup', handleMouseUp)
      doc.addEventListener('click', handleClick)

      removeListeners = () => {
        doc.removeEventListener('mouseup', handleMouseUp)
        doc.removeEventListener('click', handleClick)
      }
    }

    if (iframe.contentDocument?.readyState === 'complete') {
      writeAndAttach()
    } else {
      iframe.addEventListener('load', writeAndAttach, { once: true })
    }

    return () => {
      if (removeListeners) removeListeners()
    }
  }, [rawSourceHtml, allVariables])

  // Highlight hovered variable in iframe
  useEffect(() => {
    const doc = iframeRef.current?.contentDocument
    if (!doc) return

    doc.querySelectorAll('[data-vl-var]').forEach((el) => {
      el.style.outline = ''
    })

    if (hoveredVarId) {
      const el = doc.querySelector(`[data-vl-var="${hoveredVarId}"]`)
      if (el) el.style.outline = '2px solid #dc3545'
    }
  }, [hoveredVarId])

  const handleSave = async () => {
    setSaving(true)
    setError(null)
    try {
      const payload = { name, raw_source_html: rawSourceHtml }
      if (!originalRawSourceHtml && rawSourceHtml) {
        payload.original_raw_source_html = rawSourceHtml
      }
      const data = await apiFetch(`/api/projects/${projectId}/email_templates/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ email_template: payload }),
      })
      setTemplate((prev) => ({ ...prev, name, raw_source_html: rawSourceHtml }))
      if (data.original_raw_source_html) {
        setOriginalRawSourceHtml(data.original_raw_source_html)
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  const handleReset = async (mode) => {
    const message = mode === 'blank'
      ? 'Reset to blank? This will delete all HTML, variables, and sections.'
      : 'Reset to original HTML? This will delete all variables and sections.'
    if (!window.confirm(message)) return
    setResetting(true)
    setError(null)
    try {
      const data = await apiFetch(`/api/projects/${projectId}/email_templates/${id}/reset`, {
        method: 'POST',
        body: JSON.stringify({ mode }),
      })
      setRawSourceHtml(data.raw_source_html || '')
      setOriginalRawSourceHtml(data.original_raw_source_html || null)
      setSections(data.sections || [])
      setExpandedSection(null)
      setTemplate((prev) => ({ ...prev, raw_source_html: data.raw_source_html }))
    } catch (err) {
      setError(err.message)
    } finally {
      setResetting(false)
    }
  }

  const handleAddSection = async () => {
    try {
      const data = await apiFetch(`/api/projects/${projectId}/email_templates/${id}/sections`, {
        method: 'POST',
      })
      setSections((prev) => [...prev, { ...data, variables: [] }])
      setExpandedSection(data.id)
    } catch (err) {
      setError(err.message)
    }
  }

  const handleDeleteSection = async (sectionId) => {
    // Remove any variable tokens/markers from the HTML before deleting
    const section = sections.find((s) => s.id === sectionId)
    let updatedHtml = rawSourceHtml
    if (section?.variables?.length) {
      for (const v of section.variables) {
        if (v.variable_type === 'image') {
          updatedHtml = removeImageMarker(updatedHtml, v.id)
        } else {
          updatedHtml = removeTextPlaceholder(updatedHtml, v.id, v.default_value)
        }
      }
    }

    try {
      await apiFetch(`/api/projects/${projectId}/email_templates/${id}/sections/${sectionId}`, {
        method: 'DELETE',
        body: JSON.stringify({ raw_source_html: updatedHtml }),
      })
      setRawSourceHtml(updatedHtml)
      setSections((prev) => {
        const updated = prev.filter((s) => s.id !== sectionId)
        return updated.map((s, i) => ({ ...s, position: i + 1 }))
      })
      if (expandedSection === sectionId) setExpandedSection(null)
    } catch (err) {
      setError(err.message)
    }
  }

  const handleCreateVariable = useCallback(
    async () => {
      console.log('[createVar] called', { expandedSection, popover, rawSourceHtmlLen: rawSourceHtml?.length })
      if (!expandedSection) {
        console.log('[createVar] BAIL: no expanded section')
        return
      }

      const varId = crypto.randomUUID()
      let defaultValue, updatedHtml

      if (popover.type === 'image') {
        console.log('[createVar] image type, imgSrc:', popover.imgSrc)
        const result = insertImageMarker(rawSourceHtml, popover.imgSrc, varId)
        defaultValue = result.defaultValue
        updatedHtml = result.updatedHtml
      } else {
        const selectedText = popover.selectedText
        console.log('[createVar] text type, selectedText:', JSON.stringify(selectedText))
        if (!selectedText) {
          console.log('[createVar] BAIL: no selectedText in popover')
          setPopover(null)
          return
        }
        const result = insertTextPlaceholder(rawSourceHtml, selectedText, varId, popover.occurrenceIndex)
        console.log('[createVar] insertTextPlaceholder result:', result ? 'found match' : 'null (no match in raw HTML)')
        if (!result) {
          setPopover(null)
          return
        }
        defaultValue = result.defaultValue
        updatedHtml = result.updatedHtml
      }

      console.log('[createVar] sending API request, varId:', varId, 'defaultValue:', defaultValue)
      try {
        const data = await apiFetch(
          `/api/projects/${projectId}/email_templates/${id}/sections/${expandedSection}/variables`,
          {
            method: 'POST',
            body: JSON.stringify({
              variable: {
                id: varId,
                name: defaultValue,
                variable_type: popover.type,
                default_value: defaultValue,
              },
              raw_source_html: updatedHtml,
            }),
          }
        )
        console.log('[createVar] API success, response:', data)

        setRawSourceHtml(updatedHtml)
        setSections((prev) =>
          prev.map((s) =>
            s.id === expandedSection
              ? { ...s, variables: [...(s.variables || []), data] }
              : s
          )
        )
      } catch (err) {
        console.error('[createVar] API error:', err)
        setError(err.message)
      }

      setPopover(null)
    },
    [projectId, id, expandedSection, popover, rawSourceHtml]
  )

  const handleDeleteVariable = useCallback(
    async (sectionId, varId) => {
      const section = sections.find((s) => s.id === sectionId)
      const variable = section?.variables?.find((v) => v.id === varId)
      if (!variable) return

      let updatedHtml
      if (variable.variable_type === 'image') {
        updatedHtml = removeImageMarker(rawSourceHtml, varId)
      } else {
        updatedHtml = removeTextPlaceholder(rawSourceHtml, varId, variable.default_value)
      }

      try {
        await apiFetch(
          `/api/projects/${projectId}/email_templates/${id}/sections/${sectionId}/variables/${varId}`,
          {
            method: 'DELETE',
            body: JSON.stringify({ raw_source_html: updatedHtml }),
          }
        )

        setRawSourceHtml(updatedHtml)
        setSections((prev) =>
          prev.map((s) =>
            s.id === sectionId
              ? { ...s, variables: (s.variables || []).filter((v) => v.id !== varId) }
              : s
          )
        )
      } catch (err) {
        setError(err.message)
      }
    },
    [projectId, id, rawSourceHtml, sections]
  )

  const cancelPopover = useCallback(() => setPopover(null), [])

  if (loading) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status" />
      </div>
    )
  }

  if (!template) {
    return <div className="p-4 text-danger">Template not found.</div>
  }

  return (
    <div className="d-flex h-100">
      {/* Left sidebar panel */}
      <div
        className="border-end bg-light d-flex flex-column flex-shrink-0"
        style={{ width: 280 }}
      >
        <div className="p-3 border-bottom d-flex align-items-center gap-2">
          <button
            className="btn btn-sm btn-link text-dark p-0"
            onClick={() => navigate(`/projects/${projectId}/templates`)}
          >
            <i className="bi bi-arrow-left"></i>
          </button>
          <h6 className="mb-0 text-truncate flex-grow-1">{name}</h6>
        </div>

        {/* Subtabs */}
        <div className="d-flex border-bottom">
          <button
            className={`btn btn-sm flex-fill rounded-0 border-0 py-2 ${activeTab === 'sections' ? 'fw-semibold border-bottom border-2 border-danger' : 'text-muted'}`}
            onClick={() => setActiveTab('sections')}
          >
            Sections
          </button>
          <button
            className={`btn btn-sm flex-fill rounded-0 border-0 py-2 ${activeTab === 'details' ? 'fw-semibold border-bottom border-2 border-danger' : 'text-muted'}`}
            onClick={() => setActiveTab('details')}
          >
            Details
          </button>
        </div>

        <div className="p-3 flex-grow-1 overflow-auto">
          {activeTab === 'details' && (
            <>
              <div className="mb-3">
                <label className="form-label small fw-semibold">Template Name</label>
                <input
                  type="text"
                  className="form-control form-control-sm"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>

              <div className="mb-3">
                <label className="form-label small fw-semibold">Source HTML</label>
                {originalRawSourceHtml ? (
                  <textarea
                    className="form-control form-control-sm font-monospace bg-light"
                    rows={10}
                    value={originalRawSourceHtml}
                    readOnly
                  />
                ) : (
                  <textarea
                    className="form-control form-control-sm font-monospace"
                    rows={10}
                    value={rawSourceHtml}
                    onChange={(e) => setRawSourceHtml(e.target.value)}
                    placeholder="Paste your email HTML here..."
                  />
                )}
              </div>

              {originalRawSourceHtml && (
                <div className="d-flex gap-2">
                  <button
                    className="btn btn-sm btn-outline-danger flex-fill"
                    onClick={() => handleReset('original')}
                    disabled={resetting}
                  >
                    {resetting ? 'Resetting...' : 'Reset to Original'}
                  </button>
                  <button
                    className="btn btn-sm btn-outline-secondary flex-fill"
                    onClick={() => handleReset('blank')}
                    disabled={resetting}
                  >
                    {resetting ? 'Resetting...' : 'Reset to Blank'}
                  </button>
                </div>
              )}
            </>
          )}

          {activeTab === 'sections' && (
            <>
              <div className="d-flex align-items-center justify-content-between mb-3">
                <span className="small fw-semibold text-muted text-uppercase">Sections</span>
                <button
                  className="btn btn-sm btn-outline-secondary d-flex align-items-center gap-1"
                  onClick={handleAddSection}
                  title="Add section"
                >
                  <i className="bi bi-plus"></i>
                </button>
              </div>

              {sections.length === 0 && (
                <div className="text-muted small text-center py-4">
                  <i className="bi bi-layers d-block fs-4 mb-2"></i>
                  No sections yet. Click + to add one.
                </div>
              )}

              {sections.map((section) => (
                <div key={section.id} className="mb-2 border rounded bg-white">
                  <div
                    className="d-flex align-items-center px-3 py-2"
                    style={{ cursor: 'pointer' }}
                    onClick={() =>
                      setExpandedSection(expandedSection === section.id ? null : section.id)
                    }
                  >
                    <i
                      className={`bi me-2 small ${expandedSection === section.id ? 'bi-chevron-down' : 'bi-chevron-right'}`}
                    ></i>
                    <span className="small fw-medium flex-grow-1">
                      Section {section.position}
                    </span>
                    <button
                      className="btn btn-sm btn-link text-danger p-0"
                      onClick={(e) => {
                        e.stopPropagation()
                        handleDeleteSection(section.id)
                      }}
                      title="Remove section"
                    >
                      <i className="bi bi-trash small"></i>
                    </button>
                  </div>
                  {expandedSection === section.id && (
                    <div className="px-3 pb-3 pt-1 border-top">
                      {(!section.variables || section.variables.length === 0) ? (
                        <p className="text-muted small mb-0">
                          Select text or click an image in the preview to create a variable.
                        </p>
                      ) : (
                        <ul className="list-unstyled mb-0">
                          {section.variables.map((v) => (
                            <li
                              key={v.id}
                              className="d-flex align-items-center gap-2 py-1 small"
                              onMouseEnter={() => setHoveredVarId(v.id)}
                              onMouseLeave={() => setHoveredVarId(null)}
                            >
                              <i className={`bi ${v.variable_type === 'image' ? 'bi-image' : 'bi-type'} text-muted`}></i>
                              <span className="flex-grow-1 text-truncate">{v.default_value}</span>
                              <button
                                className="btn btn-sm btn-link text-danger p-0"
                                onClick={() => handleDeleteVariable(section.id, v.id)}
                                title="Delete variable"
                              >
                                <i className="bi bi-x-lg small"></i>
                              </button>
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </>
          )}
        </div>

        <div className="p-3 border-top">
          {error && <div className="alert alert-danger py-1 px-2 small">{error}</div>}
          <button
            className="btn btn-danger btn-sm w-100"
            onClick={handleSave}
            disabled={saving}
          >
            {saving ? 'Saving...' : 'Save Template'}
          </button>
        </div>
      </div>

      {/* Main content area - HTML preview */}
      <div className="flex-grow-1 overflow-auto">
        <div className="d-flex justify-content-between align-items-center px-3 py-2 border-bottom bg-white">
          <span className="fw-semibold">Template Preview</span>
          <small className="text-muted">
            {expandedSection
              ? 'Select text or click an image to create a variable'
              : 'Expand a section to start creating variables'}
          </small>
        </div>
        <div className="p-3">
          {rawSourceHtml ? (
            <div
              className="mx-auto bg-white shadow-sm"
              style={{ maxWidth: 680 }}
            >
              <iframe
                ref={iframeRef}
                title="Template Preview"
                style={{ width: '100%', minHeight: 'calc(100vh - 140px)', border: 'none' }}
                sandbox="allow-same-origin"
              />
            </div>
          ) : (
            <div className="text-center text-muted py-5">
              <i className="bi bi-code-square fs-1 d-block mb-3"></i>
              <p>Paste HTML source in the sidebar to see a preview.</p>
            </div>
          )}
        </div>
      </div>

      {/* Variable creation popover */}
      {popover && (
        <VariablePopover
          position={{ top: popover.top, left: popover.left }}
          variableType={popover.type}
          onConfirm={handleCreateVariable}
          onCancel={cancelPopover}
        />
      )}
    </div>
  )
}
