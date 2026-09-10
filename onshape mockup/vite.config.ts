import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/postcss';
import { sites } from '@openai/sites-vite-plugin';
import { cloudflare } from '@cloudflare/vite-plugin';
import { fileURLToPath, URL } from 'node:url';
export default defineConfig({
  resolve: { alias: { '@': fileURLToPath(new URL('.', import.meta.url)) } },
  css: { postcss: { plugins: [tailwindcss()] } },
  plugins: [
    react(),
    sites(),
    cloudflare({
      viteEnvironment: { name: 'server' },
      config: {
        name: 'cad-studio',
        main: 'worker.ts',
        compatibility_date: '2026-05-01',
        assets: {
          binding: 'ASSETS',
          directory: './dist/client',
          not_found_handling: 'single-page-application',
        },
      },
    }),
  ],
  server: { host: '0.0.0.0', port: 5179, strictPort: true },
});
