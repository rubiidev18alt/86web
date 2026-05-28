import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'
import { readFileSync } from 'fs'

const { version } = JSON.parse(readFileSync('./package.json', 'utf-8'))

export default defineConfig({
  define: {
    __APP_VERSION__: JSON.stringify(version),
  },
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    host: '0.0.0.0',
    port: Number(process.env.VITE_HOST_PORT || 8086),
    proxy: {
      '/api': { target: 'http://localhost:8000', changeOrigin: true },
      '/vnc': { target: 'ws://localhost:8001', ws: true, changeOrigin: true },
      '/vms': { target: 'http://localhost:8001', changeOrigin: true },
    },
  },
})
