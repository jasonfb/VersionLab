import React from 'react'

export default function ({ position, variableType, onConfirm, onCancel }) {
  return (
    <div
      className="card shadow-sm position-fixed"
      style={{
        top: position.top,
        left: position.left,
        zIndex: 9999,
      }}
    >
      <div className="card-body p-2 d-flex align-items-center gap-2">
        <button className="btn btn-sm btn-danger" onClick={onConfirm}>
          <i className={`bi ${variableType === 'image' ? 'bi-image' : 'bi-type'} me-1`}></i>
          Create Variable
        </button>
        <button className="btn btn-sm btn-outline-secondary" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </div>
  )
}
