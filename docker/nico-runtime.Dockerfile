FROM node:24.13.0-bookworm-slim

WORKDIR /app/services/nico-runtime

COPY services/nico-runtime/package*.json ./
RUN npm ci --include=dev

COPY services/nico-runtime ./
RUN npm run build && npm prune --omit=dev

ENV NODE_ENV=production
ENV PORT=3108

EXPOSE 3108

CMD ["npm", "start"]