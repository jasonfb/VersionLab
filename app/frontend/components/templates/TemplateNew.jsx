import React, { useState, useRef, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { apiUpload } from '~/lib/api'
import { subscribeTemplateImportChannel } from '~/lib/cable'

const IMPORT_TYPES = {
  bundled: {
    label: 'Bundled',
    description: 'Images live inside a ZIP archive alongside the HTML file.',
    accept: '.zip',
    hint: 'Upload a .zip file containing index.html and an images/ folder.',
  },
  external: {
    label: 'External',
    description: 'Images are hosted on an external server and referenced by URL.',
    accept: '.html,.htm',
    hint: 'Upload a single .html file. All image URLs will be downloaded and imported.',
  },
}

export default function TemplateNew() {
  const { projectId } = useParams()
  const navigate = useNavigate()
  const fileInputRef = useRef(null)

  const [name, setName] = useState('')
  const [importType, setImportType] = useState(null)
  const [file, setFile] = useState(null)
  const [fileError, setFileError] = useState(null)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState(null)

  // Import-in-progress state
  const [importState, setImportState] = useState(null) // null | 'pending' | 'processing' | 'completed' | 'failed'
  const [warnings, setWarnings] = useState([])
  const [importError, setImportError] = useState(null)
  const [emailTemplateId, setEmailTemplateId] = useState(null)

  // Reset file whenever import type changes
  useEffect(() => {
    setFile(null)
    setFileError(null)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }, [importType])

  const handleFileChange = (e) => {
    const selected = e.target.files[0]
    setFileError(null)
    setFile(selected || null)
  }

  const validateFile = () => {
    if (!importType) {
      setFileError('Please select an image source type.')
      return false
    }
    if (!file) {
      setFileError('Please select a file.')
      return false
    }
    if (importType === 'bundled') {
      if (!file.name.toLowerCase().endsWith('.zip')) {
        setFileError('Bundled import requires a .zip file.')
        return false
      }
    } else {
      if (!file.name.toLowerCase().match(/\.html?$/)) {
        setFileError('External import requires an .html file.')
        return false
      }
    }
    return true
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!validateFile()) return

    setSubmitting(true)
    setError(null)

    const formData = new FormData()
    formData.append('name', name)
    formData.append('import_type', importType)
    formData.append('file', file)

    try {
      const result = await apiUpload(`/api/projects/${projectId}/template_imports`, formData)
      setEmailTemplateId(result.email_template_id)
      setImportState(result.state)

      // Subscribe to real-time updates
      const unsubscribe = subscribeTemplateImportChannel(result.id, {
        received(data) {
          setImportState(data.state)
          if (data.warnings?.length) setWarnings(data.warnings)
          if (data.error_message) setImportError(data.error_message)

          if (data.state === 'completed') {
            unsubscribe()
            // Brief pause so the user sees the completed state
            setTimeout(() => {
              navigate(`/projects/${projectId}/templates/${data.email_template_id}`)
            }, 800)
          } else if (data.state === 'failed') {
            unsubscribe()
          }
        },
      })
    } catch (err) {
      setError(err.message)
    } finally {
      setSubmitting(false)
    }
  }

  const config = importType ? IMPORT_TYPES[importType] : null
  const isImporting = importState !== null && importState !== 'failed'

  return (
    <div className="p-4" style={{ maxWidth: 640 }}>
      <h4 className="mb-4">New Email Template</h4>

      {error && <div className="alert alert-danger">{error}</div>}

      {!importState ? (
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label className="form-label">Template Name</label>
            <input
              type="text"
              className="form-control"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Monthly Newsletter"
              required
            />
          </div>

          <div className="mb-3">
            <label className="form-label d-block">Image Source</label>
            <div className="d-flex gap-3">
              {Object.entries(IMPORT_TYPES).map(([type, cfg]) => (
                <div
                  key={type}
                  className={`flex-fill border rounded p-3 ${importType === type ? 'border-danger border-2' : 'border-secondary'}`}
                  style={{ cursor: 'pointer' }}
                  onClick={() => setImportType(type)}
                >
                  <div className="d-flex align-items-center gap-2 mb-1">
                    <input
                      type="radio"
                      name="import_type"
                      value={type}
                      checked={importType === type}
                      onChange={() => setImportType(type)}
                      onClick={(e) => e.stopPropagation()}
                    />
                    <strong>{cfg.label}</strong>
                  </div>
                  <small className="text-secondary">{cfg.description}</small>
                </div>
              ))}
            </div>
          </div>

          {config && (
            <div className="mb-3">
              <label className="form-label">File</label>
              <input
                ref={fileInputRef}
                type="file"
                className={`form-control ${fileError ? 'is-invalid' : ''}`}
                accept={config.accept}
                onChange={handleFileChange}
              />
              {fileError
                ? <div className="invalid-feedback">{fileError}</div>
                : <div className="form-text">{config.hint}</div>
              }
            </div>
          )}

          {!config && fileError && (
            <div className="text-danger small mb-3">{fileError}</div>
          )}

          <div className="d-flex gap-2">
            <button type="submit" className="btn btn-danger" disabled={submitting || !name.trim() || !importType}>
              {submitting ? 'Uploading…' : 'Import Template'}
            </button>
            <button
              type="button"
              className="btn btn-outline-secondary"
              onClick={() => navigate(`/projects/${projectId}/templates`)}
            >
              Cancel
            </button>
          </div>
        </form>
      ) : (
        <ImportProgress
          state={importState}
          warnings={warnings}
          errorMessage={importError}
          onRetry={() => {
            setImportState(null)
            setWarnings([])
            setImportError(null)
          }}
          onGoToTemplate={() =>
            navigate(`/projects/${projectId}/templates/${emailTemplateId}`)
          }
        />
      )}
    </div>
  )
}

function ImportProgress({ state, warnings, errorMessage, onRetry, onGoToTemplate }) {
  const stateLabel = {
    pending: 'Queued…',
    processing: 'Importing images…',
    completed: 'Import complete!',
    failed: 'Import failed',
  }

  const stateIcon = {
    pending: <span className="spinner-border spinner-border-sm me-2" />,
    processing: <span className="spinner-border spinner-border-sm me-2" />,
    completed: <i className="bi bi-check-circle-fill text-success me-2" />,
    failed: <i className="bi bi-x-circle-fill text-danger me-2" />,
  }

  return (
    <div>
      <div className="d-flex align-items-center mb-3">
        {stateIcon[state]}
        <span className="fw-semibold">{stateLabel[state]}</span>
      </div>

      {state === 'processing' && (
        <div className="progress mb-3" style={{ height: 4 }}>
          <div className="progress-bar progress-bar-striped progress-bar-animated bg-danger w-100" />
        </div>
      )}

      {warnings.length > 0 && (
        <div className="alert alert-warning">
          <strong>Warnings:</strong>
          <ul className="mb-0 mt-1">
            {warnings.map((w, i) => <li key={i}>{w}</li>)}
          </ul>
        </div>
      )}

      {errorMessage && (
        <div className="alert alert-danger">{errorMessage}</div>
      )}

      {state === 'completed' && (
        <button className="btn btn-danger" onClick={onGoToTemplate}>
          Open Template
        </button>
      )}

      {state === 'failed' && (
        <button className="btn btn-outline-secondary" onClick={onRetry}>
          Try Again
        </button>
      )}
    </div>
  )
}
