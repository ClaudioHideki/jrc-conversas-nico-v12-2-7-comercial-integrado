FROM node:24.13.0-bookworm-slim
WORKDIR /srv
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts
COPY *.mjs ./
USER node
CMD ["node", "--max-old-space-size=128", "server.mjs"]
