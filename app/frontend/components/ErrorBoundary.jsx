import React from 'react'

export default class ErrorBoundary extends React.Component {
  state = { error: null, errorInfo: null }

  componentDidCatch(error, errorInfo) {
    this.setState({ error, errorInfo })
  }

  render() {
    if (this.state.error) {
      return (
        <div style={{ padding: 24, fontFamily: 'monospace', maxWidth: 900, margin: '0 auto' }}>
          <h2 style={{ color: '#dc3545' }}>Something went wrong</h2>
          <pre style={{ whiteSpace: 'pre-wrap', color: '#842029', background: '#f8d7da', padding: 16, borderRadius: 6 }}>
            {this.state.error.toString()}
          </pre>
          {this.state.errorInfo && (
            <details open style={{ marginTop: 12 }}>
              <summary style={{ cursor: 'pointer', fontWeight: 600 }}>Component stack</summary>
              <pre style={{ whiteSpace: 'pre-wrap', color: '#333', background: '#f1f1f1', padding: 16, borderRadius: 6, marginTop: 8 }}>
                {this.state.errorInfo.componentStack}
              </pre>
            </details>
          )}
        </div>
      )
    }

    return this.props.children
  }
}
