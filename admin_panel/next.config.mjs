import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: { remotePatterns: [{ protocol: 'https', hostname: '**' }] },
  experimental: { serverComponentsExternalPackages: ['firebase-admin'] },
  webpack: (config) => {
    config.resolve.alias = {
      ...(config.resolve.alias || {}),
      '@': __dirname,
    };
    return config;
  },
};
export default nextConfig;
