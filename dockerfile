# Stage 1: Build & Dependencies
FROM oven/bun:1 AS builder
WORKDIR /usr/src/app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build

# Stage 2: Production Runtime
FROM oven/bun:1-slim AS runner
WORKDIR /usr/src/app
ENV NODE_ENV=production
COPY package.json bun.lock ./
# Install only prod dependencies
RUN bun install --frozen-lockfile --production
COPY --from=builder /usr/src/app/dist ./dist
USER bun
EXPOSE 3000
CMD ["bun", "run", "dist/main.js"]
