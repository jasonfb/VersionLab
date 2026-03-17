import React, { useState, useEffect, useRef, useCallback } from 'react'
import { useParams, Link } from 'react-router-dom'
import { apiFetch, apiUpload } from '~/lib/api'

const STATUS_OPTIONS = ['draft', 'active', 'completed', 'archived']
const STATUS_COLORS = { draft: 'secondary', active: 'success', completed: 'primary', archived: 'dark' }

export default function CampaignDetail() {
  const { clientId, campaignId } = useParams()
  const [campaign, setCampaign] = useState(null)
  const [documents, setDocuments] = useState([])
  const [links, setLinks] = useState([])
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState(null)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState(null)
  const pollRef = useRef(null)

  const load = useCallback(() => {
    return Promise.all([
      apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}`),
      apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}/campaign_documents`),
      apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}/campaign_links`),
    ]).then(([c, docs, lnks]) => {
      setCampaign(c)
      setDocuments(docs)
      setLinks(lnks)
      if (!form) {
        setForm({
          name: c.name || '',
          description: c.description || '',
          goals: c.goals || '',
          status: c.status || 'draft',
          start_date: c.start_date || '',
          end_date: c.end_date || '',
        })
      }
    })
  }, [clientId, campaignId])

  useEffect(() => {
    load().finally(() => setLoading(false))
  }, [load])

  // Poll while AI summary is generating
  useEffect(() => {
    if (!campaign) return
    if (campaign.ai_summary_state === 'generating') {
      pollRef.current = setTimeout(() => {
        apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}`).then((c) => {
          setCampaign(c)
        })
      }, 3000)
    }
    return () => clearTimeout(pollRef.current)
  }, [campaign, clientId, campaignId])

  const handleSave = async (e) => {
    e.preventDefault()
    setSaving(true)
    setSaved(false)
    setError(null)
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}`, {
        method: 'PATCH',
        body: JSON.stringify({ campaign: form }),
      })
      setCampaign(updated)
      setSaved(true)
      setTimeout(() => setSaved(false), 3000)
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  const handleSummarize = async () => {
    try {
      await apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}/summarize`, { method: 'POST' })
      setCampaign((c) => ({ ...c, ai_summary_state: 'generating' }))
    } catch (err) {
      setError(err.message)
    }
  }

  if (loading || !form) return <Spinner />

  return (
    <div className="p-4" style={{ maxWidth: 800 }}>
      <div className="mb-3">
        <Link to={`/clients/${clientId}`} className="text-muted small">
          <i className="bi bi-arrow-left me-1"></i>Back to Client
        </Link>
      </div>

      {error && <div className="alert alert-danger alert-dismissible">
        {error}
        <button type="button" className="btn-close" onClick={() => setError(null)} />
      </div>}

      {/* ── Campaign Fields ─────────────────────────────────────────── */}
      <form onSubmit={handleSave}>
        <div className="d-flex justify-content-between align-items-start mb-4">
          <div className="flex-grow-1 me-3">
            <input
              type="text"
              className="form-control form-control-lg fw-bold border-0 ps-0"
              style={{ fontSize: '1.4rem', background: 'transparent' }}
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="Campaign name"
              required
            />
          </div>
          <div className="d-flex gap-2 align-items-center">
            <select
              className="form-select form-select-sm"
              style={{ width: 'auto' }}
              value={form.status}
              onChange={(e) => setForm({ ...form, status: e.target.value })}
            >
              {STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>
              ))}
            </select>
            <button className="btn btn-danger btn-sm" type="submit" disabled={saving}>
              {saving ? 'Saving...' : 'Save'}
            </button>
            {saved && <span className="text-success small"><i className="bi bi-check-circle me-1"></i>Saved</span>}
          </div>
        </div>

        <div className="row mb-3">
          <div className="col-md-6">
            <label className="form-label text-muted small fw-semibold text-uppercase" style={{ letterSpacing: '0.06em' }}>
              Start Date
            </label>
            <input
              type="date"
              className="form-control form-control-sm"
              value={form.start_date}
              onChange={(e) => setForm({ ...form, start_date: e.target.value })}
            />
          </div>
          <div className="col-md-6">
            <label className="form-label text-muted small fw-semibold text-uppercase" style={{ letterSpacing: '0.06em' }}>
              End Date
            </label>
            <input
              type="date"
              className="form-control form-control-sm"
              value={form.end_date}
              onChange={(e) => setForm({ ...form, end_date: e.target.value })}
            />
          </div>
        </div>

        <div className="mb-3">
          <label className="form-label text-muted small fw-semibold text-uppercase" style={{ letterSpacing: '0.06em' }}>
            Description
          </label>
          <textarea
            className="form-control"
            rows={4}
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
            placeholder="Describe this campaign — its purpose, context, and messaging direction..."
          />
        </div>

        <div className="mb-4">
          <label className="form-label text-muted small fw-semibold text-uppercase" style={{ letterSpacing: '0.06em' }}>
            Goals &amp; Objectives
          </label>
          <textarea
            className="form-control"
            rows={3}
            value={form.goals}
            onChange={(e) => setForm({ ...form, goals: e.target.value })}
            placeholder="What are the specific goals of this campaign? KPIs, desired outcomes, success metrics..."
          />
        </div>
      </form>

      <hr className="my-4" />

      {/* ── Documents ───────────────────────────────────────────────── */}
      <SectionHeading icon="bi-file-earmark-text">Reference Documents</SectionHeading>
      <DocumentsSection clientId={clientId} campaignId={campaignId} documents={documents} setDocuments={setDocuments} />

      <hr className="my-4" />

      {/* ── Links ───────────────────────────────────────────────────── */}
      <SectionHeading icon="bi-link-45deg">Reference Links</SectionHeading>
      <LinksSection clientId={clientId} campaignId={campaignId} links={links} setLinks={setLinks} />

      <hr className="my-4" />

      {/* ── AI Summary ──────────────────────────────────────────────── */}
      <SectionHeading icon="bi-stars">AI Campaign Summary</SectionHeading>
      <AiSummarySection campaign={campaign} onSummarize={handleSummarize} />
    </div>
  )
}

// ─── Documents Section ────────────────────────────────────────────────────────

function DocumentsSection({ clientId, campaignId, documents, setDocuments }) {
  const [uploading, setUploading] = useState(false)
  const [dragOver, setDragOver] = useState(false)
  const [error, setError] = useState(null)
  const inputRef = useRef(null)

  const uploadFile = async (file) => {
    setUploading(true)
    setError(null)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const doc = await apiUpload(`/api/clients/${clientId}/campaigns/${campaignId}/campaign_documents`, formData)
      setDocuments((prev) => [...prev, doc])
    } catch (err) {
      setError(err.message)
    } finally {
      setUploading(false)
    }
  }

  const handleDrop = (e) => {
    e.preventDefault()
    setDragOver(false)
    const files = Array.from(e.dataTransfer.files)
    files.forEach(uploadFile)
  }

  const handleFileInput = (e) => {
    Array.from(e.target.files).forEach(uploadFile)
    e.target.value = ''
  }

  const handleDelete = async (id) => {
    if (!confirm('Remove this document?')) return
    try {
      await apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}/campaign_documents/${id}`, { method: 'DELETE' })
      setDocuments((prev) => prev.filter((d) => d.id !== id))
    } catch (err) {
      setError(err.message)
    }
  }

  const docIcon = (contentType) => {
    if (!contentType) return 'bi-file-earmark'
    if (contentType.includes('pdf')) return 'bi-file-earmark-pdf text-danger'
    if (contentType.includes('word') || contentType.includes('document')) return 'bi-file-earmark-word text-primary'
    if (contentType.includes('image')) return 'bi-file-earmark-image text-success'
    if (contentType.includes('spreadsheet') || contentType.includes('excel')) return 'bi-file-earmark-spreadsheet text-success'
    return 'bi-file-earmark text-secondary'
  }

  const formatBytes = (bytes) => {
    if (!bytes) return ''
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  return (
    <div>
      {error && <div className="alert alert-danger alert-dismissible py-2 mb-3">{error}<button type="button" className="btn-close" onClick={() => setError(null)} /></div>}

      {/* Drop zone */}
      <div
        className={`rounded border-2 border-dashed d-flex align-items-center justify-content-center mb-3 ${dragOver ? 'border-danger bg-danger bg-opacity-10' : 'border-secondary'}`}
        style={{ border: '2px dashed', minHeight: 100, cursor: 'pointer', transition: 'all 0.15s' }}
        onDragOver={(e) => { e.preventDefault(); setDragOver(true) }}
        onDragLeave={() => setDragOver(false)}
        onDrop={handleDrop}
        onClick={() => inputRef.current?.click()}
      >
        <input ref={inputRef} type="file" multiple className="d-none" onChange={handleFileInput} />
        {uploading ? (
          <span className="text-muted d-flex align-items-center gap-2">
            <span className="spinner-border spinner-border-sm" />
            Uploading...
          </span>
        ) : (
          <span className="text-muted">
            <i className="bi bi-cloud-upload me-2 fs-5"></i>
            Drop files here or click to browse
            <small className="d-block text-center mt-1" style={{ fontSize: '0.75rem' }}>PDF, Word, images, and more</small>
          </span>
        )}
      </div>

      {/* Document list */}
      {documents.length > 0 && (
        <div className="list-group">
          {documents.map((doc) => (
            <div key={doc.id} className="list-group-item d-flex align-items-center gap-3 py-2">
              <i className={`bi ${docIcon(doc.content_type)} fs-5 flex-shrink-0`}></i>
              <div className="flex-grow-1 overflow-hidden">
                <div className="fw-semibold text-truncate" style={{ fontSize: '0.9rem' }}>{doc.display_name}</div>
                <div className="d-flex gap-2 align-items-center">
                  {doc.byte_size && <small className="text-muted">{formatBytes(doc.byte_size)}</small>}
                  {doc.has_extracted_text && (
                    <small className="text-success"><i className="bi bi-check-circle me-1"></i>Text extracted</small>
                  )}
                </div>
              </div>
              <button
                className="btn btn-sm btn-outline-danger flex-shrink-0"
                onClick={() => handleDelete(doc.id)}
              >
                <i className="bi bi-trash"></i>
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

// ─── Links Section ────────────────────────────────────────────────────────────

function LinksSection({ clientId, campaignId, links, setLinks }) {
  const [urlInput, setUrlInput] = useState('')
  const [adding, setAdding] = useState(false)
  const [error, setError] = useState(null)

  const handleAdd = async (e) => {
    e.preventDefault()
    const url = urlInput.trim()
    if (!url) return
    setAdding(true)
    setError(null)
    try {
      const link = await apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}/campaign_links`, {
        method: 'POST',
        body: JSON.stringify({ url }),
      })
      setLinks((prev) => [...prev, link])
      setUrlInput('')
    } catch (err) {
      setError(err.message)
    } finally {
      setAdding(false)
    }
  }

  const handleDelete = async (id) => {
    try {
      await apiFetch(`/api/clients/${clientId}/campaigns/${campaignId}/campaign_links/${id}`, { method: 'DELETE' })
      setLinks((prev) => prev.filter((l) => l.id !== id))
    } catch (err) {
      setError(err.message)
    }
  }

  return (
    <div>
      {error && <div className="alert alert-danger alert-dismissible py-2 mb-3">{error}<button type="button" className="btn-close" onClick={() => setError(null)} /></div>}

      <form onSubmit={handleAdd} className="mb-3">
        <div className="input-group">
          <span className="input-group-text"><i className="bi bi-link-45deg"></i></span>
          <input
            type="url"
            className="form-control"
            placeholder="https://example.com/brand-guide"
            value={urlInput}
            onChange={(e) => setUrlInput(e.target.value)}
            required
          />
          <button className="btn btn-outline-secondary" type="submit" disabled={adding}>
            {adding ? <span className="spinner-border spinner-border-sm" /> : 'Add Link'}
          </button>
        </div>
      </form>

      {links.length > 0 && (
        <div className="d-flex flex-column gap-2">
          {links.map((link) => (
            <LinkPreviewCard key={link.id} link={link} onDelete={() => handleDelete(link.id)} />
          ))}
        </div>
      )}
    </div>
  )
}

function LinkPreviewCard({ link, onDelete }) {
  const isPreviewed = !!link.fetched_at
  const hasMeta = link.title || link.description

  return (
    <div className="border rounded d-flex gap-3 overflow-hidden" style={{ background: '#fff' }}>
      {link.image_url && (
        <img
          src={link.image_url}
          alt=""
          style={{ width: 80, height: 80, objectFit: 'cover', flexShrink: 0 }}
          onError={(e) => { e.target.style.display = 'none' }}
        />
      )}
      <div className="flex-grow-1 py-2 pe-2 overflow-hidden">
        {hasMeta ? (
          <>
            <div className="fw-semibold text-truncate" style={{ fontSize: '0.9rem' }}>{link.title}</div>
            {link.description && (
              <div className="text-muted small" style={{ display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                {link.description}
              </div>
            )}
          </>
        ) : (
          <div className="text-muted small d-flex align-items-center gap-1">
            {!isPreviewed && <span className="spinner-border spinner-border-sm" />}
            <span>{isPreviewed ? 'No preview available' : 'Fetching preview...'}</span>
          </div>
        )}
        <a href={link.url} target="_blank" rel="noopener noreferrer" className="small text-muted text-truncate d-block mt-1">
          {link.url}
        </a>
      </div>
      <div className="d-flex align-items-center pe-2">
        <button className="btn btn-sm btn-outline-danger" onClick={onDelete}>
          <i className="bi bi-trash"></i>
        </button>
      </div>
    </div>
  )
}

// ─── AI Summary Section ───────────────────────────────────────────────────────

function AiSummarySection({ campaign, onSummarize }) {
  const state = campaign?.ai_summary_state
  const summary = campaign?.ai_summary
  const generatedAt = campaign?.ai_summary_generated_at

  return (
    <div>
      <p className="text-muted small mb-3">
        The AI summary is automatically generated from your description, goals, documents, and links.
        It will be used as context when generating email copy for this campaign.
      </p>

      {state === 'idle' && (
        <div className="d-flex align-items-center gap-3">
          <button className="btn btn-outline-secondary btn-sm" onClick={onSummarize}>
            <i className="bi bi-stars me-1"></i>Generate Summary
          </button>
          <span className="text-muted small">Add documents or links, then generate.</span>
        </div>
      )}

      {state === 'generating' && (
        <div className="d-flex align-items-center gap-2 text-muted">
          <span className="spinner-border spinner-border-sm text-info" />
          <span>Generating summary... this may take a moment.</span>
        </div>
      )}

      {state === 'failed' && (
        <div className="alert alert-warning d-flex align-items-center gap-3 py-2">
          <i className="bi bi-exclamation-triangle"></i>
          <span>Summary generation failed. Check that an AI key is configured for this account.</span>
          <button className="btn btn-sm btn-outline-warning ms-auto" onClick={onSummarize}>Retry</button>
        </div>
      )}

      {state === 'generated' && summary && (
        <div>
          <div
            className="border rounded p-3 mb-3"
            style={{ background: '#f8f9fa', whiteSpace: 'pre-wrap', fontSize: '0.9rem', lineHeight: 1.6, maxHeight: 500, overflowY: 'auto' }}
          >
            {summary}
          </div>
          <div className="d-flex align-items-center gap-3">
            <button className="btn btn-outline-secondary btn-sm" onClick={onSummarize}>
              <i className="bi bi-arrow-clockwise me-1"></i>Regenerate
            </button>
            {generatedAt && (
              <span className="text-muted small">
                Generated {new Date(generatedAt).toLocaleDateString()} at {new Date(generatedAt).toLocaleTimeString()}
              </span>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Shared sub-components ────────────────────────────────────────────────────

function SectionHeading({ icon, children }) {
  return (
    <h6
      className="d-flex align-items-center gap-2 text-uppercase text-muted fw-semibold mb-3"
      style={{ letterSpacing: '0.08em', borderBottom: '1px solid #dee2e6', paddingBottom: '0.5rem', fontSize: '0.72rem' }}
    >
      {icon && <i className={`bi ${icon}`}></i>}
      {children}
    </h6>
  )
}

function Spinner() {
  return (
    <div className="p-4">
      <div className="spinner-border spinner-border-sm" role="status">
        <span className="visually-hidden">Loading...</span>
      </div>
    </div>
  )
}
