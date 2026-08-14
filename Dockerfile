FROM lscr.io/linuxserver/radarr:latest AS base

FROM node:20-alpine AS frontend-builder

WORKDIR /build
COPY package.json yarn.lock tsconfig.json ./
COPY frontend/ ./frontend/
# --env production is NOT optional here. Radarr serves its chunks with
# Cache-Control: max-age=31536000, public - a year, immutable - because it
# assumes content-hashed filenames. webpack.config.js only emits
# '[name]-[contenthash].js' when env.production is set; a plain `yarn build`
# emits '[name].js'. So a dev build writes the same filename on every rebuild
# and browsers plus Cloudflare keep serving the first copy they ever cached
# for a year. index.html is no-store, so with hashes the cache busts itself.
RUN yarn install --frozen-lockfile && yarn build --env production

# translate() strings are served from a backend file (Localization/Core/en.json)
# that a frontend-only build never touches. The accessibility branch adds keys
# the base image does not ship; a missing key falls through to the raw key name,
# which screen readers then announce. Merge the fork's keys UNDER the base file
# so base values win on conflicts and nothing the LinuxServer build ships gets
# clobbered.
COPY src/NzbDrone.Core/Localization/Core/en.json ./en.fork.json
COPY --from=base /app/radarr/bin/Localization/Core/en.json ./en.base.json
RUN node -e "\
const fs = require('fs'); \
const fork = JSON.parse(fs.readFileSync('./en.fork.json', 'utf8')); \
const base = JSON.parse(fs.readFileSync('./en.base.json', 'utf8')); \
const merged = { ...fork, ...base }; \
fs.writeFileSync('./en.merged.json', JSON.stringify(merged, null, 2) + '\n'); \
console.log('localization: ' + Object.keys(base).length + ' base + ' + (Object.keys(merged).length - Object.keys(base).length) + ' fork-only = ' + Object.keys(merged).length); \
"

FROM lscr.io/linuxserver/radarr:latest

# The frontend build emits different bundle filenames than the packaged
# production build, so copying over the top leaves orphaned bundles that
# still contain the PRE-PATCH code. index.html never references them so
# they're inert, but grepping the container for a fixed string then finds it
# and makes the patch look like it failed. Clear the directory first.
# Verified safe: webpack copies frontend/src/*.html (login.html, oauth.html)
# and emits Content/, index.html and its chunks - everything the base ships.
RUN rm -rf /app/radarr/bin/UI
COPY --from=frontend-builder /build/_output/UI/ /app/radarr/bin/UI/
COPY --from=frontend-builder /build/en.merged.json /app/radarr/bin/Localization/Core/en.json
