# ---- Build stage ----
FROM node:24-alpine AS build
WORKDIR /app

# Install all deps (prod + dev). prisma + firebase-admin need their install
# scripts; the package.json `allowScripts` permits them.
COPY package*.json ./
RUN npm install

# Generate the Prisma client into src/generated/prisma (needed by the build).
COPY prisma ./prisma
COPY prisma7.config.ts ./
RUN npx prisma generate

# Compile the NestJS app to dist/.
COPY . .
RUN npm run build

# ---- Runtime stage ----
FROM node:24-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8080

# Prune to production deps and copy the compiled output.
COPY package*.json ./
RUN npm install --omit=dev

COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/prisma7.config.ts ./

# Cloud Run injects PORT=8080. The server reads DATABASE_URL and
# FIREBASE_SERVICE_ACCOUNT from the environment (Cloud Run settings).
EXPOSE 8080
CMD ["node", "dist/main.js"]
