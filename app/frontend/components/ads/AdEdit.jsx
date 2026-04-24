import React, { useState, useEffect, useRef } from 'react'
import ReactDOM from 'react-dom'
import { useParams, useNavigate, useSearchParams, Link } from 'react-router-dom'
import { apiFetch, apiUpload } from '~/lib/api'
import { subscribeAdChannel } from '~/lib/cable'
import { useAccount } from '../layout/AccountContext'
import AdStyleGuideModal from './AdStyleGuideModal'
import InteractiveSvgEditor from './InteractiveSvgEditor'
import CompositePreview from './CompositePreview'
import AdResizePicker from './AdResizePicker'
import AdElementClassifier from './AdElementClassifier'

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
  const [searchParams, setSearchParams] = useSearchParams()
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

  // Four-step flow state: 1 = classify, 2 = resize, 3 = style, 4 = version
  // Synced with ?step= query param so reloads preserve position
  const STEP_NAMES = { 1: 'classify', 2: 'resize', 3: 'style', 4: 'version' }
  const STEP_FROM_NAME = { classify: 1, resize: 2, style: 3, version: 4 }
  const stepParam = searchParams.get('step')
  const [step, setStepRaw] = useState(STEP_FROM_NAME[stepParam] || 1)
  const setStep = (n) => {
    setStepRaw(n)
    setSearchParams({ step: STEP_NAMES[n] || 'classify' }, { replace: true })
  }
  const [selectedPlatforms, setSelectedPlatforms] = useState({})
  const [customSizes, setCustomSizes] = useState([])
  const [resizes, setResizes] = useState([])
  const [resizing, setResizing] = useState(false)
  const [editingResize, setEditingResize] = useState(null)
  const [switchingVariant, setSwitchingVariant] = useState(false)
  const toolbarPortalRef = useRef(null)
  const [stylePreviewResizeId, setStylePreviewResizeId] = useState(null) // null = original, or resize ID
  const [assetPickerOpen, setAssetPickerOpen] = useState(false)
  const [styleEditingLayer, setStyleEditingLayer] = useState(null) // layer being edited in style step

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

      // Load resizes if they exist
      const resizePromise = (a.has_resizes || a.state === 'resizing')
        ? apiFetch(`/api/clients/${clientId}/ads/${adId}/resizes`).then((r) => {
            setResizes(r)
            // Reconstruct selectedPlatforms and customSizes from existing resizes
            // so checkboxes reflect prior selections when the user returns.
            const reconstructed = {}
            const reconstructedCustom = []
            r.forEach((resize) => {
              ;(resize.platform_labels || []).forEach(({ platform, size_name }) => {
                if (platform === 'Custom') {
                  const alreadyAdded = reconstructedCustom.some(
                    (cs) => cs.width === resize.width && cs.height === resize.height
                  )
                  if (!alreadyAdded) {
                    reconstructedCustom.push({
                      label: size_name !== `${resize.width}x${resize.height}` ? size_name : '',
                      width: resize.width,
                      height: resize.height,
                    })
                  }
                } else {
                  if (!reconstructed[platform]) reconstructed[platform] = []
                  if (!reconstructed[platform].includes(size_name)) {
                    reconstructed[platform].push(size_name)
                  }
                }
              })
            })
            setSelectedPlatforms(reconstructed)
            setCustomSizes(reconstructedCustom)
            return r
          })
        : Promise.resolve([])

      resizePromise.then((loadedResizes) => {
        // If URL has a step param, respect it (user reloaded or navigated back)
        const urlStep = STEP_FROM_NAME[new URLSearchParams(window.location.search).get('step')]
        if (urlStep) {
          setStep(urlStep)
          return
        }

        // Otherwise determine initial step from ad state
        if (['pending', 'merged', 'regenerating'].includes(a.state)) {
          setStep(4)
        } else if (loadedResizes.length > 0) {
          setStep(2)
        } else if (a.classifications_confirmed) {
          setStep(2)
        } else {
          setStep(1)
        }
      })
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
        body: JSON.stringify({
          platforms: selectedPlatforms,
          custom_sizes: customSizes.filter((cs) => cs.width > 0 && cs.height > 0).map((cs) => ({
            label: cs.label || `${cs.width}x${cs.height}`,
            width: cs.width,
            height: cs.height,
          })),
        }),
      })
      setAd((prev) => ({ ...prev, state: result.state, has_resizes: true }))
      setResizes(result.resizes || [])
    } catch (e) {
      alert(e.message || 'Failed to generate resizes')
    } finally {
      setResizing(false)
    }
  }

  const handleClassificationsConfirmed = () => {
    setAd((prev) => prev ? { ...prev, classifications_confirmed: true } : prev)
    setStep(2)
  }

  const handleContinueToStyling = () => {
    setStep(3)
  }

  const handleSkipResizing = () => {
    setStep(3)
  }

  const handleContinueToVersioning = () => {
    save().then(() => setStep(4))
  }

  const handleBackToClassify = () => {
    setStep(1)
  }

  const handleBackToResize = () => {
    setStep(2)
  }

  const handleBackToStyle = () => {
    if (ad.state === 'merged' || ad.state === 'regenerating') {
      if (!confirm('Going back will discard all generated versions. Continue?')) return
    }
    setStep(3)
  }

  const handleEditResize = (resize) => {
    setEditingResize(resize)
  }

  const handleRebuildResize = async (resize) => {
    // Mark as pending in the UI immediately for feedback
    setResizes((prev) => prev.map((r) => r.id === resize.id ? { ...r, state: 'pending' } : r))
    try {
      const rebuilt = await apiFetch(
        `/api/clients/${clientId}/ads/${adId}/ad_resizes/${resize.id}/rebuild`,
        { method: 'POST' }
      )
      // Replace the old resize (by old id) with the new one
      setResizes((prev) => prev.map((r) => r.id === resize.id ? rebuilt : r))
      // Keep the editing modal in sync if this resize is currently open
      if (editingResize?.id === resize.id) setEditingResize(rebuilt)
    } catch (e) {
      alert(e.message || 'Failed to rebuild resize')
      // Restore prior state on failure
      setResizes((prev) => prev.map((r) => r.id === resize.id ? resize : r))
    }
  }

  const handleSwitchVariant = async (resize, variant) => {
    if (variant === resize.layout_variant) return
    setSwitchingVariant(true)
    try {
      const rebuilt = await apiFetch(
        `/api/clients/${clientId}/ads/${adId}/ad_resizes/${resize.id}/switch_variant`,
        { method: 'POST', body: JSON.stringify({ layout_variant: variant }) }
      )
      setResizes((prev) => prev.map((r) => r.id === resize.id ? rebuilt : r))
      if (editingResize?.id === resize.id) setEditingResize(rebuilt)
    } catch (e) {
      alert(e.message || 'Failed to switch layout variant')
    } finally {
      setSwitchingVariant(false)
    }
  }

  const handleResizeOverridesChange = async (layerId, overrides, resizeId) => {
    const targetId = resizeId || editingResize?.id
    if (!targetId) return
    const targetResize = resizes.find((r) => r.id === targetId)
    if (!targetResize) return
    const updatedOverrides = {
      ...targetResize.layer_overrides,
      [layerId]: { ...(targetResize.layer_overrides?.[layerId] || {}), ...overrides },
    }
    try {
      const updated = await apiFetch(
        `/api/clients/${clientId}/ads/${adId}/ad_resizes/${targetId}`,
        {
          method: 'PATCH',
          body: JSON.stringify({ layer_overrides: updatedOverrides }),
        }
      )
      setResizes((prev) => prev.map((r) => r.id === updated.id ? updated : r))
      if (editingResize?.id === targetId) setEditingResize(updated)
    } catch (e) {
      console.error('Failed to save resize overrides:', e)
    }
  }

  // ---- Helpers ----

  const modelsForService = (serviceId) => {
    if (!serviceId) return []
    const service = aiServices.find((s) => s.id === serviceId)
    return service ? service.models.filter((m) => m.for_text) : []
  }

  const toggleAudience = (id) => {
    const ids = form.audience_ids.includes(id)
      ? form.audience_ids.filter((a) => a !== id)
      : [...form.audience_ids, id]
    setForm({ ...form, audience_ids: ids })
  }

  const saveOverridesTimer = useRef(null)
  const handleLayerOverride = (layerId, overrides) => {
    setLayerOverrides((prev) => {
      const updated = { ...prev, [layerId]: { ...(prev[layerId] || {}), ...overrides } }
      // Debounced auto-save to server
      clearTimeout(saveOverridesTimer.current)
      saveOverridesTimer.current = setTimeout(() => {
        apiFetch(`/api/clients/${clientId}/ads/${adId}`, {
          method: 'PATCH',
          body: JSON.stringify({ ad: { layer_overrides: updated } }),
        }).catch((e) => console.error('Auto-save layer overrides failed:', e))
      }, 500)
      return updated
    })
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
        <StepIndicator number={1} label="Classify" active={step === 1} completed={step > 1} />
        <div className="border-top flex-grow-0" style={{ width: 40 }}></div>
        <StepIndicator number={2} label="Resize" active={step === 2} completed={step > 2 && resizes.length > 0} />
        <div className="border-top flex-grow-0" style={{ width: 40 }}></div>
        <StepIndicator number={3} label="Style" active={step === 3} completed={step > 3} />
        <div className="border-top flex-grow-0" style={{ width: 40 }}></div>
        <StepIndicator number={4} label="Version" active={step === 4} />
        {step === 4 && resizes.length > 0 && (
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

      {/* Step 1: Classify */}
      {step === 1 && (
        <AdElementClassifier
          ad={ad}
          clientId={clientId}
          onConfirm={handleClassificationsConfirmed}
        />
      )}

      {/* Step 2: Resize */}
      {step === 2 && (
        <>
          <div className="mb-3">
            <button className="btn btn-sm btn-outline-secondary" onClick={handleBackToClassify}>
              <i className="bi bi-arrow-left me-1"></i>Back to Classify
            </button>
          </div>
          <AdResizePicker
            ad={ad}
            selectedPlatforms={selectedPlatforms}
            onPlatformsChange={setSelectedPlatforms}
            customSizes={customSizes}
            onCustomSizesChange={setCustomSizes}
            resizes={resizes}
            onGenerateResizes={generateResizes}
            onEditResize={handleEditResize}
            onRebuildResize={handleRebuildResize}
            onContinue={handleContinueToStyling}
            onSkip={handleSkipResizing}
            resizing={resizing}
          />
        </>
      )}

      {/* Step 3: Style settings + preview */}
      {step === 3 && (
        <>
          {/* Back to resize button */}
          <div className="mb-3">
            <button className="btn btn-sm btn-outline-secondary" onClick={handleBackToResize}>
              <i className="bi bi-arrow-left me-1"></i>Back to Resize
            </button>
          </div>

          <div className="row g-4">
            {/* Left panel: style settings */}
            <div className="col-lg-5">
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
                {form.background_type === 'image' && (() => {
                  const selectedAsset = assets.find((a) => a.id === form.background_asset_id)
                  return (
                    <div>
                      {selectedAsset ? (
                        <div className="d-flex align-items-center gap-2 mb-2">
                          <img src={selectedAsset.url} alt="" style={{ width: 48, height: 48, objectFit: 'cover', borderRadius: 4 }} />
                          <div className="flex-grow-1 min-width-0">
                            <small className="d-block text-truncate fw-semibold">{selectedAsset.name}</small>
                            <small className="text-muted">{selectedAsset.width}x{selectedAsset.height}</small>
                          </div>
                          <button className="btn btn-sm btn-outline-secondary" onClick={() => setForm({ ...form, background_asset_id: '' })}>
                            <i className="bi bi-x"></i>
                          </button>
                        </div>
                      ) : null}
                      <button className="btn btn-sm btn-outline-danger" onClick={() => setAssetPickerOpen(true)}>
                        <i className="bi bi-image me-1"></i>
                        {selectedAsset ? 'Change Image' : 'Choose from Library'}
                      </button>
                    </div>
                  )
                })()}
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
                <button className="btn btn-danger btn-sm" onClick={handleContinueToVersioning} disabled={saving}>
                  {saving ? 'Saving…' : <><span className="me-1">&rarr;</span>Continue to Versioning</>}
                </button>
              </div>
            </div>

            {/* Right panel: size selector + preview */}
            <div className="col-lg-7">
              <div className="sticky-top" style={{ top: '1rem' }}>
                {/* Size selector pills */}
                {(() => {
                  const readyResizes = resizes.filter((r) => r.state === 'resized' && r.resized_svg_url)
                  const activeResize = readyResizes.find((r) => r.id === stylePreviewResizeId)
                  const bgAsset = assets.find((a) => a.id === form.background_asset_id)
                  const bgAssetUrl = bgAsset?.file_url || bgAsset?.url

                  // Determine preview dimensions
                  const previewW = activeResize ? activeResize.width : (ad.width || 1080)
                  const previewH = activeResize ? activeResize.height : (ad.height || 1080)

                  return (
                    <>
                      <div className="d-flex align-items-center gap-2 mb-3 flex-wrap">
                        <span className="small text-muted fw-semibold text-uppercase me-1">Preview:</span>
                        <button
                          className={`btn btn-sm ${!stylePreviewResizeId ? 'btn-dark' : 'btn-outline-secondary'}`}
                          onClick={() => setStylePreviewResizeId(null)}
                        >
                          Original ({ad.width}x{ad.height})
                        </button>
                        {readyResizes.map((r) => (
                          <button
                            key={r.id}
                            className={`btn btn-sm ${stylePreviewResizeId === r.id ? 'btn-dark' : 'btn-outline-secondary'}`}
                            onClick={() => setStylePreviewResizeId(r.id)}
                          >
                            {r.width}x{r.height}
                          </button>
                        ))}
                      </div>
                      {activeResize && (
                        <small className="text-muted d-block mb-2">
                          {activeResize.platform_labels?.map((l) => typeof l === 'string' ? l : `${l.platform} ${l.size_name}`).join(', ')}
                        </small>
                      )}

                      {/* Preview container with background + SVG overlay */}
                      <div
                        className="position-relative rounded overflow-hidden border"
                        style={{ maxWidth: '100%', aspectRatio: `${previewW} / ${previewH}`, maxHeight: 600, background: '#1a1a1a' }}
                      >
                        {/* Background layer */}
                        {form.background_type === 'image' && bgAssetUrl ? (
                          <img
                            src={bgAssetUrl}
                            alt=""
                            style={{
                              position: 'absolute', inset: 0,
                              width: '100%', height: '100%',
                              objectFit: 'cover', objectPosition: 'center',
                              zIndex: 0,
                            }}
                          />
                        ) : form.background_type === 'solid_color' ? (
                          <div style={{ position: 'absolute', inset: 0, backgroundColor: form.background_color, zIndex: 0 }} />
                        ) : null}

                        {/* Composite preview layer — always reconstructed from metadata */}
                        <div style={{ position: 'relative', zIndex: 1 }}>
                          <CompositePreview
                            width={previewW}
                            height={previewH}
                            layers={activeResize ? activeResize.resized_layers : (ad.classified_layers || ad.parsed_layers)}
                            fonts={ad.fonts}
                            layerOverrides={activeResize ? activeResize.layer_overrides : layerOverrides}
                            onLayerOverridesChange={activeResize
                              ? (layerId, overrides) => handleResizeOverridesChange(layerId, overrides, activeResize.id)
                              : handleLayerOverride
                            }
                            onEditLayer={(layer) => setStyleEditingLayer(layer)}
                          />
                        </div>

                        {/* Overlay layer */}
                        {form.overlay_enabled && (
                          <div style={{
                            position: 'absolute', inset: 0, zIndex: 2, pointerEvents: 'none',
                            background: form.overlay_type === 'gradient'
                              ? `linear-gradient(to bottom, transparent, ${form.overlay_color}${Math.round(form.overlay_opacity * 2.55).toString(16).padStart(2, '0')})`
                              : form.overlay_color + Math.round(form.overlay_opacity * 2.55).toString(16).padStart(2, '0'),
                          }} />
                        )}

                        {/* Play button layer */}
                        {form.play_button_enabled && (
                          <div className="position-absolute top-50 start-50 translate-middle" style={{ zIndex: 3, pointerEvents: 'none' }}>
                            <PlayButtonIcon style={form.play_button_style} color={form.play_button_color} />
                          </div>
                        )}
                      </div>
                    </>
                  )
                })()}
              </div>
            </div>
          </div>
        </>
      )}

      {/* Style step inline text editor */}
      {styleEditingLayer && (() => {
        const layer = styleEditingLayer
        const overrides = layerOverrides?.[layer.id] || {}
        const fontName = (overrides.font_family || layer.font_family || '').toLowerCase()
        const initial = {
          content: overrides.content || layer.content || '',
          font_family: overrides.font_family || layer.font_family || 'sans-serif',
          font_size: overrides.font_size || layer.font_size || '24',
          is_bold: overrides.is_bold ?? layer.is_bold ?? /bold|black|heavy/.test(fontName),
          is_italic: overrides.is_italic ?? layer.is_italic ?? /italic|oblique/.test(fontName),
          is_underline: overrides.is_underline ?? false,
          fill: overrides.fill || layer.fill || layer.color || '#FFFFFF',
          letter_spacing: overrides.letter_spacing || '0',
          line_height: overrides.line_height || '1.3',
          text_align: overrides.text_align || layer.text_align || layer.align || 'left',
        }
        return <StyleLayerEditor
          key={layer.id}
          initial={initial}
          onChange={(updated) => handleLayerOverride(layer.id, updated)}
          onClose={() => setStyleEditingLayer(null)}
        />
      })()}

      {/* Step 4: Version settings + preview */}
      {step === 4 && (
        <>
          {/* Back to style button */}
          <div className="mb-3">
            <button className="btn btn-sm btn-outline-secondary" onClick={handleBackToStyle}>
              <i className="bi bi-arrow-left me-1"></i>Back to Style
            </button>
          </div>

          <div className="row g-4">
            {/* Left panel: version settings */}
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

                  {/* AI Service / Model — only shown when customer chooses AI */}
                  {ctx?.customer_chooses_ai !== false && (
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
                  )}
                </>
              )}

              {/* Action buttons */}
              <div className="d-flex gap-2 flex-wrap">
                <button className="btn btn-outline-secondary btn-sm" onClick={save} disabled={saving}>
                  {saving ? 'Saving…' : 'Save Settings'}
                </button>
                {form.versioning_mode === 'version_ads' && (ad.state === 'setup' || ad.state === 'resizing') && (
                  <button
                    className="btn btn-danger btn-sm"
                    onClick={runAd}
                    disabled={running || (ctx?.customer_chooses_ai !== false && (!form.ai_service_id || !form.ai_model_id)) || form.audience_ids.length === 0}
                    title={
                      (ctx?.customer_chooses_ai !== false && !form.ai_service_id) ? 'Select an AI service'
                      : (ctx?.customer_chooses_ai !== false && !form.ai_model_id) ? 'Select an AI model'
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
                      classifiedLayers={ad.classified_layers}
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
              <div className="modal-header py-2">
                <h6 className="modal-title mb-0">
                  {editingResize.dimensions}
                  <small className="text-muted ms-1">{editingResize.label}</small>
                </h6>
                <button type="button" className="btn-close" onClick={() => setEditingResize(null)} />
              </div>
              <div className="d-flex align-items-center gap-2 flex-nowrap px-3 py-1 border-bottom bg-light" style={{ fontSize: '0.82rem' }}>
                <button
                  className="btn btn-outline-secondary btn-sm"
                  onClick={() => handleRebuildResize(editingResize)}
                  disabled={editingResize.state === 'pending' || switchingVariant}
                  title="Discard all edits and restore the original heuristic layout"
                >
                  {editingResize.state === 'pending' ? (
                    <><span className="spinner-border spinner-border-sm me-1" />Restoring…</>
                  ) : (
                    <><i className="bi bi-arrow-counterclockwise me-1"></i>Restore Layout</>
                  )}
                </button>
                <div className="d-flex align-items-center gap-1">
                  <small className="text-muted text-nowrap">Base layout:</small>
                  <div className="btn-group btn-group-sm">
                    {['left', 'center', 'right'].map((v) => (
                      <button
                        key={v}
                        className={`btn ${editingResize.layout_variant === v ? 'btn-dark' : 'btn-outline-secondary'}`}
                        onClick={() => handleSwitchVariant(editingResize, v)}
                        disabled={switchingVariant || editingResize.state === 'pending'}
                      >
                        {switchingVariant && editingResize.layout_variant !== v ? (
                          <span className="spinner-border spinner-border-sm" />
                        ) : (
                          <i className={`bi bi-text-${v}`} />
                        )}
                      </button>
                    ))}
                  </div>
                </div>
                <div ref={toolbarPortalRef}></div>
                <button type="button" className="btn btn-secondary btn-sm ms-auto" onClick={() => setEditingResize(null)}>
                  Done
                </button>
              </div>
              <div className="modal-body">
                {editingResize.resized_svg_url ? (
                  <InteractiveSvgEditor
                    key={`${editingResize.id}-${editingResize.updated_at || ''}`}
                    svgUrl={editingResize.resized_svg_url}
                    layers={editingResize.resized_layers}
                    classifiedLayers={editingResize.resized_layers}
                    onLayerOverridesChange={handleResizeOverridesChange}
                    initialOverrides={editingResize.layer_overrides || {}}
                    renderToolbar={(toolbar) => toolbarPortalRef.current ? ReactDOM.createPortal(toolbar, toolbarPortalRef.current) : null}
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

      {/* Background asset picker modal */}
      {assetPickerOpen && (() => {
        const maxW = Math.max(ad.width || 0, ...resizes.map((r) => r.width || 0))
        const maxH = Math.max(ad.height || 0, ...resizes.map((r) => r.height || 0))
        const imageAssets = assets.filter((a) => a.url && a.width && a.height)
        const eligible = imageAssets.filter((a) => a.width >= maxW && a.height >= maxH)
        const tooSmall = imageAssets.filter((a) => a.width < maxW || a.height < maxH)

        return (
          <div className="modal d-block" style={{ backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1060 }} onClick={() => setAssetPickerOpen(false)}>
            <div className="modal-dialog modal-lg modal-dialog-centered modal-dialog-scrollable" onClick={(e) => e.stopPropagation()}>
              <div className="modal-content">
                <div className="modal-header">
                  <h5 className="modal-title">Select Background Image</h5>
                  <button className="btn-close" onClick={() => setAssetPickerOpen(false)} />
                </div>
                <div className="modal-body">
                  {eligible.length > 0 && (
                    <div className="mb-4">
                      <small className="text-muted fw-semibold d-block mb-2">
                        Images {maxW}x{maxH}px or larger
                      </small>
                      <div className="row g-3">
                        {eligible.map((a) => (
                          <div key={a.id} className="col-4 col-md-3">
                            <div
                              className="border rounded overflow-hidden"
                              style={{
                                cursor: 'pointer',
                                borderColor: form.background_asset_id === a.id ? '#dc3545' : undefined,
                                borderWidth: form.background_asset_id === a.id ? 3 : 1,
                              }}
                              onClick={() => {
                                setForm({ ...form, background_asset_id: a.id })
                                setAssetPickerOpen(false)
                              }}
                            >
                              <img src={a.url} alt={a.name} style={{ width: '100%', aspectRatio: '1', objectFit: 'cover' }} />
                              <div className="p-1">
                                <small className="d-block text-truncate fw-semibold" style={{ fontSize: '0.7rem' }}>{a.name}</small>
                                <small className="text-muted" style={{ fontSize: '0.65rem' }}>{a.width}x{a.height}</small>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                  {tooSmall.length > 0 && (
                    <div>
                      <small className="text-muted fw-semibold d-block mb-2">Too small for your sizes</small>
                      <div className="row g-3">
                        {tooSmall.map((a) => (
                          <div key={a.id} className="col-4 col-md-3" style={{ opacity: 0.4 }}>
                            <div className="border rounded overflow-hidden" title={`${a.width}x${a.height} — needs at least ${maxW}x${maxH}`}>
                              <img src={a.url} alt={a.name} style={{ width: '100%', aspectRatio: '1', objectFit: 'cover' }} />
                              <div className="p-1">
                                <small className="d-block text-truncate" style={{ fontSize: '0.7rem' }}>{a.name}</small>
                                <small className="text-muted" style={{ fontSize: '0.65rem' }}>{a.width}x{a.height}</small>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                  {imageAssets.length === 0 && (
                    <div className="text-center text-muted py-4">
                      <i className="bi bi-image fs-2 d-block mb-2"></i>
                      No images in your asset library yet.
                    </div>
                  )}
                </div>
                <div className="modal-footer">
                  <label className="btn btn-outline-secondary" style={{ cursor: 'pointer' }}>
                    <i className="bi bi-upload me-1"></i>Upload New Image
                    <input
                      type="file"
                      accept="image/*"
                      className="d-none"
                      onChange={async (e) => {
                        const file = e.target.files?.[0]
                        if (!file) return
                        const fd = new FormData()
                        fd.append('file', file)
                        try {
                          const newAsset = await apiUpload('/api/assets', fd)
                          setAssets((prev) => [newAsset, ...prev])
                          if (newAsset.width >= maxW && newAsset.height >= maxH) {
                            setForm((f) => ({ ...f, background_asset_id: newAsset.id }))
                            setAssetPickerOpen(false)
                          }
                        } catch (err) {
                          console.error('Upload failed:', err)
                        }
                      }}
                    />
                  </label>
                  <button className="btn btn-secondary" onClick={() => setAssetPickerOpen(false)}>Cancel</button>
                </div>
              </div>
            </div>
          </div>
        )
      })()}

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

function StyleLayerEditor({ initial, onChange, onClose }) {
  const [form, setForm] = React.useState(initial)
  const posRef = React.useRef({ x: Math.min(window.innerWidth - 360, 100), y: 120 })
  const [pos, setPos] = React.useState(posRef.current)
  const dragRef = React.useRef(null)

  const emit = (updated) => { setForm(updated); onChange?.(updated) }
  const set = (key, val) => emit({ ...form, [key]: val })
  const toggle = (key) => emit({ ...form, [key]: !form[key] })

  const onDragStart = (e) => {
    e.preventDefault()
    dragRef.current = { startX: e.clientX, startY: e.clientY, origX: pos.x, origY: pos.y }
    const onMove = (ev) => {
      const dx = ev.clientX - dragRef.current.startX, dy = ev.clientY - dragRef.current.startY
      const np = { x: dragRef.current.origX + dx, y: dragRef.current.origY + dy }
      posRef.current = np; setPos(np)
    }
    const onUp = () => { document.removeEventListener('mousemove', onMove); document.removeEventListener('mouseup', onUp) }
    document.addEventListener('mousemove', onMove); document.addEventListener('mouseup', onUp)
  }

  return ReactDOM.createPortal(
    <div
      className="bg-white shadow-lg rounded border"
      style={{ position: 'fixed', left: pos.x, top: pos.y, zIndex: 9999, width: 340, maxHeight: '80vh', overflowY: 'auto', lineHeight: 'normal' }}
      onMouseDown={(e) => e.stopPropagation()}
    >
      <div className="d-flex align-items-center justify-content-between px-3 py-2 border-bottom bg-light" style={{ cursor: 'grab' }} onMouseDown={onDragStart}>
        <span className="fw-semibold small text-uppercase" style={{ letterSpacing: '0.06em' }}>Edit Text</span>
        <button className="btn btn-sm btn-link p-0 text-muted" onClick={onClose} onMouseDown={(e) => e.stopPropagation()}>
          <i className="bi bi-x-lg"></i>
        </button>
      </div>
      <div className="p-3" style={{ fontSize: '0.82rem' }}>
        <div className="mb-3">
          <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem' }}>Font Family</label>
          <input type="text" className="form-control form-control-sm" value={form.font_family} onChange={(e) => set('font_family', e.target.value)} />
        </div>
        <div className="row g-2 mb-3">
          <div className="col-5">
            <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem' }}>Size</label>
            <input type="number" className="form-control form-control-sm" value={form.font_size} onChange={(e) => set('font_size', e.target.value)} min={1} />
          </div>
          <div className="col-7">
            <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem' }}>Style</label>
            <div className="btn-group btn-group-sm w-100">
              <button className={`btn ${form.is_bold ? 'btn-danger' : 'btn-outline-secondary'}`} onClick={() => toggle('is_bold')} style={{ fontWeight: 'bold' }}>B</button>
              <button className={`btn ${form.is_italic ? 'btn-danger' : 'btn-outline-secondary'}`} onClick={() => toggle('is_italic')} style={{ fontStyle: 'italic' }}>I</button>
              <button className={`btn ${form.is_underline ? 'btn-danger' : 'btn-outline-secondary'}`} onClick={() => toggle('is_underline')} style={{ textDecoration: 'underline' }}>U</button>
            </div>
          </div>
        </div>
        <div className="mb-3">
          <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem' }}>Color</label>
          <div className="d-flex align-items-center gap-2">
            <input type="color" className="form-control form-control-color form-control-sm" style={{ width: 36, height: 32, padding: 2 }} value={form.fill} onChange={(e) => set('fill', e.target.value)} />
            <input type="text" className="form-control form-control-sm" value={form.fill} onChange={(e) => set('fill', e.target.value)} />
          </div>
        </div>
        <div className="mb-3">
          <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem' }}>Alignment</label>
          <div className="btn-group btn-group-sm w-100">
            {[{ val: 'left', icon: 'bi-text-left' }, { val: 'center', icon: 'bi-text-center' }, { val: 'right', icon: 'bi-text-right' }].map(({ val, icon }) => (
              <button key={val} className={`btn ${form.text_align === val ? 'btn-danger' : 'btn-outline-secondary'}`} onClick={() => set('text_align', val)}>
                <i className={`bi ${icon}`}></i>
              </button>
            ))}
          </div>
        </div>
        <div className="mb-2">
          <label className="form-label text-uppercase text-muted fw-semibold mb-1" style={{ fontSize: '0.68rem' }}>Content</label>
          <textarea className="form-control form-control-sm" rows={3} value={form.content} onChange={(e) => set('content', e.target.value)} />
        </div>
      </div>
    </div>,
    document.body
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
