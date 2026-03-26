import React, { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import { apiFetch } from '~/lib/api'
import { subscribeAdChannel } from '~/lib/cable'
import { useAccount } from '../layout/AccountContext'
import AdStyleGuideModal from './AdStyleGuideModal'
import InteractiveSvgEditor from './InteractiveSvgEditor'
import AdResizePicker from './AdResizePicker'

// Platform aspect ratio hints (for original ad display)
const PLATFORM_HINTS = {
  '1:1':    [ 'Facebook Feed', 'Instagram Square', 'LinkedIn Square', 'Pinterest Square', 'Threads', 'X Square' ],
  '4:5':    [ 'Instagram Portrait' ],
  '9:16':   [ 'Instagram Story', 'Facebook Story', 'Snapchat', 'TikTok' ],
  '16:9':   [ 'X Single Image' ],
  '300:157': [ 'Facebook Landscape', 'Reddit' ],
  '400:209': [ 'LinkedIn Single Image' ],
  '2:3':    [ 'Pinterest Standard Pin' ],
  '6:5':    [ 'Google Display', 'YouTube Display' ],
  '1:2':    [ 'Google Half Page' ],
}

export default function AdEdit() {
  const { clientId, adId } = useParams()
  const navigate = useNavigate()
  const ctx = useAccount()

  const [ad, setAd] = useState(null)
  const [loading, setLoading] = useState(true)
  const [audiences, setAudiences] = useState([])
  const [campaigns, setCampaigns] = useState([])
  const [aiServices, setAiServices] = useState([])
  const [assets, setAssets] = useState([])
  const [form, setForm] = useState(null)
  const [saving, setSaving] = useState(false)
  const [running, setRunning] = useState(false)
  const [jobError, setJobError] = useState(null)
  const [styleGuideOpen, setStyleGuideOpen] = useState(false)
  const [layerOverrides, setLayerOverrides] = useState({})

  // Two-step flow state
  const [step, setStep] = useState(1) // 1 = resize, 2 = version
  const [selectedPlatforms, setSelectedPlatforms] = useState([])
  const [resizes, setResizes] = useState([])
  const [resizing, setResizing] = useState(false)
  const [editingResize, setEditingResize] = useState(null)

  useEffect(() => {
    if (!clientId || !adId) return
    setLoading(true)
    Promise.all([
      apiFetch(`/api/clients/${clientId}/ads/${adId}`),
      apiFetch(`/api/clients/${clientId}/audiences`),
      apiFetch(`/api/clients/${clientId}/campaigns`),
      apiFetch('/api/ai_services'),
      apiFetch('/api/assets'),
    ]).then(([a, aud, c, s, ass]) => {
      setAd(a)
      setAudiences(aud)
      setCampaigns(c)
      setAiServices(s)
      setAssets(ass)
      setLayerOverrides(a.layer_overrides || {})
      setForm({
        name: a.name || '',
        audience_ids: a.audience_ids || [],
        ai_service_id: a.ai_service_id || '',
        ai_model_id: a.ai_model_id || '',
        campaign_id: a.campaign_id || '',
        nlp_prompt: a.nlp_prompt || '',
        versioning_mode: a.versioning_mode || 'retain_existing',
        keep_background: a.keep_background !== false,
        output_format: a.output_format || 'png',
        background_type: a.background_type || 'solid_color',
        background_color: a.background_color || '#000000',
        background_asset_id: a.background_asset_id || '',
        overlay_enabled: a.overlay_enabled || false,
        overlay_type: a.overlay_type || 'solid',
        overlay_color: a.overlay_color || '#FFFFFF',
        overlay_opacity: a.overlay_opacity ?? 80,
        play_button_enabled: a.play_button_enabled || false,
        play_button_style: a.play_button_style || 'circle_filled',
        play_button_color: a.play_button_color || '#FFFFFF',
      })

      // If ad already has resizes (resuming), load them and go to appropriate step
      if (a.has_resizes || a.state === 'resizing') {
        apiFetch(`/api/clients/${clientId}/ads/${adId}/resizes`).then((r) => {
          setResizes(r)
          if (r.length > 0) setStep(1)
        })
      }
      // If ad is already in versioning states, go to step 2
      if (['pending', 'merged', 'regenerating'].includes(a.state)) {
        setStep(2)
      }
    }).catch(() => {}).finally(() => setLoading(false))
  }, [clientId, adId])

  // Real-time state updates
  useEffect(() => {
    if (!adId) return
    return subscribeAdChannel(adId, {
      received(data) {
        setAd((prev) => prev ? { ...prev, state: data.state } : prev)
        if (data.error) {
          setJobError(data.error)
        }
      },
    })
  }, [adId])

  // ---- Actions ----

  const save = async () => {
    setSaving(true)
    try {
      const updated = await apiFetch(`/api/clients/${clientId}/ads/${adId}`, {
        method: 'PATCH',
        body: JSON.stringify({ ad: { ...form, layer_overrides: layerOverrides } }),
      })
      setAd(updated)
    } finally {
      setSaving(false)
    }
  }

  const runAd = async () => {
    setRunning(true)
    setJobError(null)
    try {
      // Save settings first
      await apiFetch(`/api/clients/${clientId}/ads/${adId}`, {
        method: 'PATCH',
        body: JSON.stringify({ ad: { ...form, layer_overrides: layerOverrides } }),
      })
      const updated = await apiFetch(`/api/clients/${clientId}/ads/${adId}/run`, { method: 'POST' })
      setAd(updated)
    } catch (e) {
      alert(e.message || 'Failed to run ad generation')
    } finally {
      setRunning(false)
    }
  }

  const generateResizes = async () => {
    setResizing(true)
    try {
      const result = await apiFetch(`/api/clients/${clientId}/ads/${adId}/resize`, {
        method: 'POST',
        body: JSON.stringify({ platforms: selectedPlatforms }),
      })
      setAd((prev) => ({ ...prev, state: result.state, has_resizes: true }))
      setResizes(result.resizes || [])
    } catch (e) {
      alert(e.message || 'Failed to generate resizes')
    } finally {
      setResizing(false)
    }
  }

  const handleContinueToVersioning = () => {
    setStep(2)
  }

  const handleSkipResizing = () => {
    setStep(2)
  }

  const handleBackToResize = () => {
    if (ad.state === 'merged' || ad.state === 'regenerating') {
      if (!confirm('Going back will discard all generated versions. Continue?')) return
    }
    setStep(1)
  }

  const handleEditResize = (resize) => {
    setEditingResize(resize)
  }

  const handleResizeOverridesChange = async (layerId, overrides) => {
    if (!editingResize) return
    const updatedOverrides = {
      ...editingResize.layer_overrides,
      [layerId]: { ...(editingResize.layer_overrides?.[layerId] || {}), ...overrides },
    }
    try {
      const updated = await apiFetch(
        `/api/clients/${clientId}/ads/${adId}/ad_resizes/${editingResize.id}`,
        {
          method: 'PATCH',
          body: JSON.stringify({ layer_overrides: updatedOverrides }),
        }
      )
      setResizes((prev) => prev.map((r) => r.id === updated.id ? updated : r))
      setEditingResize(updated)
    } catch (e) {
      console.error('Failed to save resize overrides:', e)
    }
  }

  // ---- Helpers ----

  const modelsForService = (serviceId) => {
    if (!serviceId) return []
    const service = aiServices.find((s) => s.id === serviceId)
    return service ? service.models : []
  }

  const toggleAudience = (id) => {
    const ids = form.audience_ids.includes(id)
      ? form.audience_ids.filter((a) => a !== id)
      : [...form.audience_ids, id]
    setForm({ ...form, audience_ids: ids })
  }

  const handleLayerOverride = (layerId, overrides) => {
    setLayerOverrides((prev) => ({
      ...prev,
      [layerId]: { ...(prev[layerId] || {}), ...overrides },
    }))
  }

  const stateBadge = (state) => {
    const colors = { setup: 'secondary', resizing: 'info', pending: 'warning text-dark', merged: 'success', regenerating: 'warning text-dark' }
    return <span className={`badge bg-${colors[state] || 'secondary'}`}>{state}</span>
  }

  const isPdf = ad?.file_content_type?.includes('pdf')
  const isSvg = ad?.file_content_type?.includes('svg')
  const hasSvg = !!ad?.svg_url
  const platformHints = ad?.aspect_ratio ? (PLATFORM_HINTS[ad.aspect_ratio] || []) : []
  const resizeCount = resizes.filter((r) => r.state === 'resized').length

  if (!ctx || loading || !form) {
    return (
      <div className="p-4">
        <div className="spinner-border spinner-border-sm" role="status">
          <span className="visually-hidden">Loading…</span>
        </div>
      </div>
    )
  }

  return (
    <div className="p-4">
      {/* Job error */}
      {jobError && (
        <div className="alert alert-danger alert-dismissible mb-3" role="alert">
          <strong>Run failed:</strong> {jobError}
          <button type="button" className="btn-close" onClick={() => setJobError(null)} />
        </div>
      )}

      {/* Header */}
      <div className="d-flex align-items-center justify-content-between mb-4">
        <div className="d-flex align-items-center gap-3">
          <button className="btn btn-sm btn-outline-secondary" onClick={() => navigate('/ads')}>
            <i className="bi bi-arrow-left"></i>
          </button>
          <div>
            <h5 className="mb-0">{ad.name}</h5>
            <div className="d-flex align-items-center gap-2 mt-1">
              {stateBadge(ad.state)}
              {ad.aspect_ratio && <span className="badge bg-light text-dark border">{ad.aspect_ratio}</span>}
              {ad.width && ad.height && (
                <small className="text-muted">{ad.width}x{ad.height}px</small>
              )}
              {platformHints.length > 0 && (
                <small className="text-muted">· {platformHints.join(', ')}</small>
              )}
            </div>
          </div>
        </div>
        <div className="d-flex gap-2">
          <button className="btn btn-sm btn-outline-secondary" onClick={() => setStyleGuideOpen(true)}>
            <i className="bi bi-info-circle me-1"></i>Style Guide
          </button>
          {(ad.state === 'merged' || ad.state === 'regenerating') && (
            <button
              className="btn btn-sm btn-outline-success"
              onClick={() => navigate(`/clients/${clientId}/ads/${adId}/results`)}
            >
              <i className="bi bi-table me-1"></i>Results
            </button>
          )}
        </div>
      </div>

      {/* Step indicator */}
      <div className="d-flex align-items-center gap-3 mb-4">
        <StepIndicator number={1} label="Resize" active={step === 1} completed={step === 2 && resizes.length > 0} />
        <div className="border-top flex-grow-0" style={{ width: 40 }}></div>
        <StepIndicator number={2} label="Version" active={step === 2} />
        {step === 2 && resizes.length > 0 && (
          <small className="text-muted ms-2">
            Versioning {resizeCount} size{resizeCount !== 1 ? 's' : ''}
          </small>
        )}
      </div>

      {/* File warnings */}
      {ad.file_warnings?.length > 0 && (
        <div className="alert alert-warning d-flex align-items-start gap-2 mb-4">
          <i className="bi bi-exclamation-triangle-fill mt-1"></i>
          <div>
            <strong>File warnings:</strong>
            <ul className="mb-0 mt-1">
              {ad.file_warnings.map((w, i) => (
                <li key={i}><small>{w.message}</small></li>
              ))}
            </ul>
          </div>
        </div>
      )}

      {/* Step 1: Resize */}
      {step === 1 && (
        <AdResizePicker
          ad={ad}
          selectedPlatforms={selectedPlatforms}
          onPlatformsChange={setSelectedPlatforms}
          resizes={resizes}
          onGenerateResizes={generateResizes}
          onEditResize={handleEditResize}
          onContinue={handleContinueToVersioning}
          onSkip={handleSkipResizing}
          resizing={resizing}
        />
      )}

      {/* Step 2: Version settings + preview */}
      {step === 2 && (
        <>
          {/* Back to resize button */}
          <div className="mb-3">
            <button className="btn btn-sm btn-outline-secondary" onClick={handleBackToResize}>
              <i className="bi bi-arrow-left me-1"></i>Back to Resize
            </button>
          </div>

          <div className="row g-4">
            {/* Left panel: settings */}
            <div className="col-lg-5">
              {/* Ad name */}
              <div className="mb-4">
                <label className="form-label fw-semibold small text-uppercase text-muted">Ad Name</label>
                <input
                  type="text"
                  className="form-control"
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                />
              </div>

              {/* Background */}
              <div className="mb-4">
                <label className="form-label fw-semibold d-flex align-items-center gap-2">
                  <i className="bi bi-layers"></i> Background
                </label>
                <div className="d-flex gap-3 mb-2">
                  <div className="form-check">
                    <input
                      className="form-check-input"
                      type="radio"
                      id="bg-solid"
                      checked={form.background_type === 'solid_color'}
                      onChange={() => setForm({ ...form, background_type: 'solid_color' })}
                    />
                    <label className="form-check-label" htmlFor="bg-solid">Solid Color</label>
                  </div>
                  <div className="form-check">
                    <input
                      className="form-check-input"
                      type="radio"
                      id="bg-image"
                      checked={form.background_type === 'image'}
                      onChange={() => setForm({ ...form, background_type: 'image' })}
                    />
                    <label className="form-check-label" htmlFor="bg-image">Image</label>
                  </div>
                </div>
                {form.background_type === 'solid_color' && (
                  <div className="d-flex align-items-center gap-2">
                    <input
                      type="color"
                      className="form-control form-control-color"
                      value={form.background_color}
                      onChange={(e) => setForm({ ...form, background_color: e.target.value })}
                    />
                    <input
                      type="text"
                      className="form-control form-control-sm"
                      style={{ maxWidth: 100 }}
                      value={form.background_color}
                      onChange={(e) => setForm({ ...form, background_color: e.target.value })}
                    />
                  </div>
                )}
                {form.background_type === 'image' && (
                  <select
                    className="form-select form-select-sm"
                    value={form.background_asset_id}
                    onChange={(e) => setForm({ ...form, background_asset_id: e.target.value })}
                  >
                    <option value="">Select an asset…</option>
                    {assets.filter((a) => a.file_url).map((a) => (
                      <option key={a.id} value={a.id}>{a.name}</option>
                    ))}
                  </select>
                )}
              </div>

              {/* Overlay */}
              <div className="mb-4">
                <div className="d-flex align-items-center justify-content-between mb-2">
                  <label className="form-label fw-semibold mb-0 d-flex align-items-center gap-2">
                    <i className="bi bi-square-half"></i> Add an overlay
                  </label>
                  <div className="form-check form-switch mb-0">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      role="switch"
                      checked={form.overlay_enabled}
                      onChange={(e) => setForm({ ...form, overlay_enabled: e.target.checked })}
                    />
                  </div>
                </div>
                {form.overlay_enabled && (
                  <>
                    <div className="d-flex gap-3 mb-2">
                      <div className="form-check">
                        <input
                          className="form-check-input"
                          type="radio"
                          id="overlay-solid"
                          checked={form.overlay_type === 'solid'}
                          onChange={() => setForm({ ...form, overlay_type: 'solid' })}
                        />
                        <label className="form-check-label" htmlFor="overlay-solid">Solid overlay</label>
                      </div>
                      <div className="form-check">
                        <input
                          className="form-check-input"
                          type="radio"
                          id="overlay-gradient"
                          checked={form.overlay_type === 'gradient'}
                          onChange={() => setForm({ ...form, overlay_type: 'gradient' })}
                        />
                        <label className="form-check-label" htmlFor="overlay-gradient">Gradient overlay</label>
                      </div>
                    </div>
                    <div className="d-flex align-items-center gap-2 mb-2">
                      <input
                        type="color"
                        className="form-control form-control-color"
                        value={form.overlay_color}
                        onChange={(e) => setForm({ ...form, overlay_color: e.target.value })}
                      />
                      <input
                        type="text"
                        className="form-control form-control-sm"
                        style={{ maxWidth: 90 }}
                        value={form.overlay_color}
                        onChange={(e) => setForm({ ...form, overlay_color: e.target.value })}
                      />
                      <label className="form-label mb-0 small text-muted">Opacity</label>
                      <input
                        type="range"
                        className="form-range"
                        style={{ maxWidth: 100 }}
                        min={0}
                        max={100}
                        value={form.overlay_opacity}
                        onChange={(e) => setForm({ ...form, overlay_opacity: parseInt(e.target.value) })}
                      />
                      <small className="text-muted">{form.overlay_opacity}%</small>
                    </div>
                  </>
                )}
              </div>

              {/* Play button */}
              <div className="mb-4">
                <div className="d-flex align-items-center justify-content-between mb-2">
                  <label className="form-label fw-semibold mb-0 d-flex align-items-center gap-2">
                    <i className="bi bi-play-circle"></i> Overlay a play button
                  </label>
                  <div className="form-check form-switch mb-0">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      role="switch"
                      checked={form.play_button_enabled}
                      onChange={(e) => setForm({ ...form, play_button_enabled: e.target.checked })}
                    />
                  </div>
                </div>
                {form.play_button_enabled && (
                  <>
                    <div className="mb-2">
                      <label className="form-label small text-muted mb-1">Play Icon Style</label>
                      <select
                        className="form-select form-select-sm"
                        value={form.play_button_style}
                        onChange={(e) => setForm({ ...form, play_button_style: e.target.value })}
                      >
                        <option value="circle_filled">Circle (Filled)</option>
                        <option value="circle_outline">Circle (Outline)</option>
                        <option value="square_filled">Square (Filled)</option>
                        <option value="triangle_only">Triangle Only</option>
                      </select>
                    </div>
                    <div className="d-flex align-items-center gap-2">
                      <label className="form-label small text-muted mb-0">Icon Color</label>
                      <input
                        type="color"
                        className="form-control form-control-color"
                        value={form.play_button_color}
                        onChange={(e) => setForm({ ...form, play_button_color: e.target.value })}
                      />
                      <input
                        type="text"
                        className="form-control form-control-sm"
                        style={{ maxWidth: 90 }}
                        value={form.play_button_color}
                        onChange={(e) => setForm({ ...form, play_button_color: e.target.value })}
                      />
                    </div>
                  </>
                )}
              </div>

              <hr />

              {/* Versioning */}
              <div className="mb-4">
                <label className="form-label fw-semibold">Versioning</label>
                <div className="form-check">
                  <input
                    className="form-check-input"
                    type="radio"
                    id="mode-retain"
                    checked={form.versioning_mode === 'retain_existing'}
                    onChange={() => setForm({ ...form, versioning_mode: 'retain_existing' })}
                  />
                  <label className="form-check-label" htmlFor="mode-retain">Retain Existing Content</label>
                </div>
                <div className="form-check">
                  <input
                    className="form-check-input"
                    type="radio"
                    id="mode-version"
                    checked={form.versioning_mode === 'version_ads'}
                    onChange={() => setForm({ ...form, versioning_mode: 'version_ads' })}
                  />
                  <label className="form-check-label" htmlFor="mode-version">Version Ads</label>
                </div>
              </div>

              {form.versioning_mode === 'version_ads' && (
                <>
                  {/* Campaign */}
                  <div className="mb-3">
                    <label className="form-label fw-semibold">
                      Campaign <span className="text-muted fw-normal">(optional)</span>
                    </label>
                    <select
                      className="form-select form-select-sm"
                      value={form.campaign_id}
                      onChange={(e) => setForm({ ...form, campaign_id: e.target.value })}
                    >
                      <option value="">No campaign</option>
                      {campaigns.map((c) => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                  </div>

                  {/* NLP Prompt */}
                  <div className="mb-3">
                    <label className="form-label fw-semibold">Campaign Context / NLP Prompt</label>
                    <textarea
                      className="form-control form-control-sm"
                      rows={3}
                      value={form.nlp_prompt}
                      onChange={(e) => setForm({ ...form, nlp_prompt: e.target.value })}
                      placeholder="Describe the campaign purpose and goal…"
                    />
                  </div>

                  {/* Audiences */}
                  <div className="mb-3">
                    <label className="form-label fw-semibold">Select Audiences</label>
                    {audiences.length === 0 ? (
                      <p className="text-muted small">No audiences for this client.</p>
                    ) : (
                      <div className="border rounded p-3">
                        {audiences.map((a) => (
                          <div key={a.id} className="form-check">
                            <input
                              className="form-check-input"
                              type="checkbox"
                              id={`aud-${a.id}`}
                              checked={form.audience_ids.includes(a.id)}
                              onChange={() => toggleAudience(a.id)}
                            />
                            <label className="form-check-label" htmlFor={`aud-${a.id}`}>{a.name}</label>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Background source */}
                  <div className="mb-3">
                    <label className="form-label fw-semibold">Background</label>
                    <div className="form-check">
                      <input
                        className="form-check-input"
                        type="radio"
                        id="bg-keep"
                        checked={form.keep_background}
                        onChange={() => setForm({ ...form, keep_background: true })}
                      />
                      <label className="form-check-label" htmlFor="bg-keep">Keep background image</label>
                    </div>
                    <div className="form-check">
                      <input
                        className="form-check-input"
                        type="radio"
                        id="bg-dam"
                        checked={!form.keep_background}
                        onChange={() => setForm({ ...form, keep_background: false })}
                      />
                      <label className="form-check-label" htmlFor="bg-dam">System chooses from Asset Library</label>
                    </div>
                  </div>

                  {/* AI Service / Model */}
                  <div className="row mb-3">
                    <div className="col-6">
                      <label className="form-label fw-semibold small">AI Service</label>
                      <select
                        className="form-select form-select-sm"
                        value={form.ai_service_id}
                        onChange={(e) => setForm({ ...form, ai_service_id: e.target.value, ai_model_id: '' })}
                      >
                        <option value="">None</option>
                        {aiServices.map((s) => (
                          <option key={s.id} value={s.id}>{s.name}</option>
                        ))}
                      </select>
                    </div>
                    <div className="col-6">
                      <label className="form-label fw-semibold small">AI Model</label>
                      <select
                        className="form-select form-select-sm"
                        value={form.ai_model_id}
                        onChange={(e) => setForm({ ...form, ai_model_id: e.target.value })}
                        disabled={!form.ai_service_id}
                      >
                        <option value="">Select a model…</option>
                        {modelsForService(form.ai_service_id).map((m) => (
                          <option key={m.id} value={m.id}>{m.name}</option>
                        ))}
                      </select>
                    </div>
                  </div>
                </>
              )}

              {/* Output format */}
              <div className="mb-4">
                <label className="form-label fw-semibold">Output Format</label>
                <div className="d-flex gap-3">
                  <div className="form-check">
                    <input
                      className="form-check-input"
                      type="radio"
                      id="fmt-png"
                      checked={form.output_format === 'png'}
                      onChange={() => setForm({ ...form, output_format: 'png' })}
                    />
                    <label className="form-check-label" htmlFor="fmt-png">PNG</label>
                  </div>
                  <div className="form-check">
                    <input
                      className="form-check-input"
                      type="radio"
                      id="fmt-jpg"
                      checked={form.output_format === 'jpg'}
                      onChange={() => setForm({ ...form, output_format: 'jpg' })}
                    />
                    <label className="form-check-label" htmlFor="fmt-jpg">JPG</label>
                  </div>
                </div>
              </div>

              {/* Action buttons */}
              <div className="d-flex gap-2 flex-wrap">
                <button className="btn btn-outline-secondary btn-sm" onClick={save} disabled={saving}>
                  {saving ? 'Saving…' : 'Save Settings'}
                </button>
                {form.versioning_mode === 'version_ads' && (ad.state === 'setup' || ad.state === 'resizing') && (
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={runAd}
                    disabled={running || !form.ai_service_id || !form.ai_model_id || form.audience_ids.length === 0}
                    title={
                      !form.ai_service_id ? 'Select an AI service'
                      : !form.ai_model_id ? 'Select an AI model'
                      : form.audience_ids.length === 0 ? 'Select at least one audience'
                      : undefined
                    }
                  >
                    {running ? (
                      <><span className="spinner-border spinner-border-sm me-1" />Generating…</>
                    ) : (
                      <><i className="bi bi-stars me-1"></i>Generate Ads</>
                    )}
                  </button>
                )}
                {(ad.state === 'pending' || ad.state === 'regenerating') && (
                  <span className="d-flex align-items-center gap-1 text-warning">
                    <span className="spinner-border spinner-border-sm" role="status" />
                    <small>{ad.state === 'regenerating' ? 'Regenerating…' : 'Generating…'}</small>
                  </span>
                )}
              </div>
            </div>

            {/* Right panel: preview */}
            <div className="col-lg-7">
              <div className="sticky-top" style={{ top: '1rem' }}>
                <label className="form-label fw-semibold small text-uppercase text-muted mb-2">Preview</label>
                {hasSvg ? (
                  <div className="position-relative rounded overflow-hidden border" style={{ ...( form.background_type === 'solid_color' ? { backgroundColor: form.background_color } : {} ), maxWidth: '100%' }}>
                    <InteractiveSvgEditor
                      svgUrl={ad.svg_url}
                      layers={ad.parsed_layers}
                      onLayerOverridesChange={handleLayerOverride}
                      initialOverrides={layerOverrides}
                    />
                    {form.overlay_enabled && (
                      <div style={{
                        position: 'absolute',
                        inset: 0,
                        background: form.overlay_type === 'gradient'
                          ? `linear-gradient(to bottom, transparent, ${form.overlay_color}${Math.round(form.overlay_opacity * 2.55).toString(16).padStart(2, '0')})`
                          : form.overlay_color + Math.round(form.overlay_opacity * 2.55).toString(16).padStart(2, '0'),
                        pointerEvents: 'none',
                      }} />
                    )}
                    {form.play_button_enabled && (
                      <div className="position-absolute top-50 start-50 translate-middle" style={{ pointerEvents: 'none' }}>
                        <PlayButtonIcon style={form.play_button_style} color={form.play_button_color} />
                      </div>
                    )}
                  </div>
                ) : (
                  <AdPreview
                    ad={ad}
                    form={form}
                    isPdf={isPdf}
                    isSvg={isSvg}
                  />
                )}

                {/* Parsed layers */}
                {ad.parsed_layers?.length > 0 && (
                  <div className="mt-3">
                    <label className="form-label fw-semibold small text-uppercase text-muted">Detected Text Layers</label>
                    <div className="border rounded p-2" style={{ maxHeight: 200, overflowY: 'auto' }}>
                      {ad.parsed_layers.filter((l) => l.type === 'text').map((layer, i) => (
                        <div key={i} className="d-flex align-items-start gap-2 py-1 border-bottom last-border-0">
                          <i className="bi bi-text-left text-muted mt-1 small"></i>
                          <div>
                            <small className="text-muted d-block">{layer.id}</small>
                            <span style={{ fontSize: '0.85rem' }}>{layer.content}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </>
      )}

      {/* Resize editor modal */}
      {editingResize && (
        <div className="modal show d-block" style={{ backgroundColor: 'rgba(0,0,0,0.5)' }} onClick={(e) => { if (e.target === e.currentTarget) setEditingResize(null) }}>
          <div className="modal-dialog modal-xl modal-dialog-centered">
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title">
                  Edit Resize — {editingResize.dimensions}
                  <small className="text-muted ms-2">{editingResize.label}</small>
                </h5>
                <button type="button" className="btn-close" onClick={() => setEditingResize(null)} />
              </div>
              <div className="modal-body">
                {editingResize.resized_svg_url ? (
                  <InteractiveSvgEditor
                    svgUrl={editingResize.resized_svg_url}
                    layers={editingResize.resized_layers}
                    onLayerOverridesChange={handleResizeOverridesChange}
                    initialOverrides={editingResize.layer_overrides || {}}
                  />
                ) : (
                  <div className="text-center text-muted py-5">
                    <i className="bi bi-image fs-2 d-block mb-2"></i>
                    <small>No SVG available for this resize</small>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      <AdStyleGuideModal
        open={styleGuideOpen}
        warnings={ad.file_warnings || []}
        onClose={() => setStyleGuideOpen(false)}
      />
    </div>
  )
}

function StepIndicator({ number, label, active, completed }) {
  const bgClass = active ? 'bg-danger text-white' : completed ? 'bg-success text-white' : 'bg-light text-muted border'
  return (
    <div className="d-flex align-items-center gap-2">
      <span
        className={`rounded-circle d-flex align-items-center justify-content-center ${bgClass}`}
        style={{ width: 28, height: 28, fontSize: '0.8rem', fontWeight: 600 }}
      >
        {completed ? <i className="bi bi-check"></i> : number}
      </span>
      <span className={`small fw-semibold ${active ? '' : 'text-muted'}`}>{label}</span>
    </div>
  )
}

function AdPreview({ ad, form, isPdf, isSvg }) {
  if (!ad.file_url) {
    return (
      <div
        className="border rounded d-flex align-items-center justify-content-center text-muted"
        style={{ minHeight: 300 }}
      >
        <div className="text-center">
          <i className="bi bi-image fs-2 d-block mb-2"></i>
          <small>No file uploaded</small>
        </div>
      </div>
    )
  }

  const overlayStyle = form.overlay_enabled
    ? {
        position: 'absolute',
        inset: 0,
        background: form.overlay_type === 'gradient'
          ? `linear-gradient(to bottom, transparent, ${form.overlay_color}${Math.round(form.overlay_opacity * 2.55).toString(16).padStart(2, '0')})`
          : form.overlay_color + Math.round(form.overlay_opacity * 2.55).toString(16).padStart(2, '0'),
        pointerEvents: 'none',
      }
    : null

  const backgroundStyle =
    form.background_type === 'solid_color'
      ? { backgroundColor: form.background_color }
      : {}

  return (
    <div className="position-relative rounded overflow-hidden border" style={{ ...backgroundStyle, maxWidth: '100%' }}>
      {isSvg && (
        <img
          src={ad.file_url}
          alt={ad.name}
          style={{ display: 'block', maxWidth: '100%', height: 'auto' }}
        />
      )}
      {isPdf && (
        <object
          data={`${ad.file_url}#toolbar=0`}
          type="application/pdf"
          style={{ width: '100%', minHeight: 400, display: 'block' }}
        >
          <div className="p-4 text-center text-muted">
            <i className="bi bi-file-earmark-pdf fs-2 d-block mb-2"></i>
            <small>PDF preview not available in this browser.</small>
            <a href={ad.file_url} target="_blank" rel="noreferrer" className="d-block mt-1 small">
              Open PDF
            </a>
          </div>
        </object>
      )}
      {!isSvg && !isPdf && (
        <div className="p-4 text-center text-muted">
          <i className="bi bi-file-earmark fs-2 d-block mb-2"></i>
          <small>File uploaded</small>
        </div>
      )}

      {overlayStyle && <div style={overlayStyle}></div>}

      {form.play_button_enabled && (
        <div
          className="position-absolute top-50 start-50 translate-middle"
          style={{ pointerEvents: 'none' }}
        >
          <PlayButtonIcon style={form.play_button_style} color={form.play_button_color} />
        </div>
      )}
    </div>
  )
}

function PlayButtonIcon({ style, color }) {
  const size = 64
  if (style === 'circle_filled') {
    return (
      <svg width={size} height={size} viewBox="0 0 64 64">
        <circle cx="32" cy="32" r="30" fill={color} opacity="0.85" />
        <polygon points="25,18 52,32 25,46" fill="white" />
      </svg>
    )
  }
  if (style === 'circle_outline') {
    return (
      <svg width={size} height={size} viewBox="0 0 64 64">
        <circle cx="32" cy="32" r="30" fill="none" stroke={color} strokeWidth="3" opacity="0.85" />
        <polygon points="25,18 52,32 25,46" fill={color} opacity="0.85" />
      </svg>
    )
  }
  if (style === 'square_filled') {
    return (
      <svg width={size} height={size} viewBox="0 0 64 64">
        <rect x="2" y="2" width="60" height="60" rx="6" fill={color} opacity="0.85" />
        <polygon points="22,16 52,32 22,48" fill="white" />
      </svg>
    )
  }
  // triangle_only
  return (
    <svg width={size} height={size} viewBox="0 0 64 64">
      <polygon points="12,8 60,32 12,56" fill={color} opacity="0.85" />
    </svg>
  )
}
