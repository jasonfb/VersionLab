import React from 'react'
import { BrowserRouter, Routes, Route } from 'react-router-dom'

function Home() {
  return <h1>Hello Version Lab</h1>
}

export default function App() {
  return (
    <BrowserRouter basename="/app">
      <Routes>
        <Route path="/" element={<Home />} />
      </Routes>
    </BrowserRouter>
  )
}
