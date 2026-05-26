import { defineConfig } from 'vite'
import { resolve } from 'path'
import { execSync } from 'child_process'
import { createRequire } from 'module'
import RubyPlugin from 'vite-plugin-ruby'

const require = createRequire(import.meta.url)
const heliosPressPath = execSync('bundle show helios-press').toString().trim()
const heliosVideosPath = execSync('bundle show helios-videos').toString().trim()

export default defineConfig({
  plugins: [
    RubyPlugin(),
  ],
  resolve: {
    alias: {
      'helios/press': resolve(heliosPressPath, 'app/javascript/helios/press'),
      'helios/videos': resolve(heliosVideosPath, 'app/javascript/helios/videos'),
      // Pin peer deps so gem JS resolves them from the project's node_modules
      '@hotwired/stimulus': resolve(__dirname, 'node_modules/@hotwired/stimulus'),
      'sortablejs': resolve(__dirname, 'node_modules/sortablejs'),
      '@rails/activestorage': resolve(__dirname, 'node_modules/@rails/activestorage'),
    },
  },
})
