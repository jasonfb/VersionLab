import { defineConfig } from 'vite'
import { resolve } from 'path'
import { execSync } from 'child_process'
import RubyPlugin from 'vite-plugin-ruby'

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
    },
  },
})
