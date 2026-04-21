# AppForge admin_panel — Coolify / Docker build
# The Next.js app lives in admin_panel/, but the generator reads sibling
# flutter_shell/, so we copy BOTH into /app and set FLUTTER_SHELL_PATH.

FROM node:20-alpine AS deps
WORKDIR /app/admin_panel
COPY admin_panel/package.json admin_panel/package-lock.json* ./
RUN npm install --include=dev --no-audit --no-fund

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/admin_panel/node_modules ./admin_panel/node_modules
COPY admin_panel ./admin_panel
RUN cd admin_panel && npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV FLUTTER_SHELL_PATH=/app/flutter_shell

# admin_panel (built)
COPY --from=builder /app/admin_panel ./admin_panel
# flutter_shell (template tree — read at request time by the generator)
COPY flutter_shell ./flutter_shell

WORKDIR /app/admin_panel
EXPOSE 3000
CMD ["npx", "next", "start", "-p", "3000"]
