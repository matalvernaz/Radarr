FROM node:20-alpine AS frontend-builder

WORKDIR /build
COPY package.json yarn.lock tsconfig.json ./
COPY frontend/ ./frontend/
RUN yarn install --frozen-lockfile && yarn build

FROM lscr.io/linuxserver/radarr:latest

COPY --from=frontend-builder /build/_output/UI/ /app/radarr/bin/UI/
