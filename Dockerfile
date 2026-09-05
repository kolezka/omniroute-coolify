# ──────────────────────────────────────────────────────────────────────
#  OmniRoute: optional Dockerfile for Coolify's "Dockerfile" build pack.
#
#  You probably do not need this. The Docker Hub image runs as-is, and the
#  preferred deployment is docker-compose.yaml from this repo. Reach for
#  this file only if you want a plain Dockerfile resource in Coolify, or
#  need to bake something extra into the image.
#
#  Already in the base image, do not repeat it:
#    EXPOSE 20128, USER node (uid 1000), WORKDIR /app,
#    PORT=20128, HOSTNAME=0.0.0.0, NODE_ENV=production,
#    DATA_DIR=/app/data, OMNIROUTE_MEMORY_MB=1024,
#    NODE_OPTIONS=--max-old-space-size=1024,
#    HEALTHCHECK: node healthcheck.mjs (30s interval, 15s start period),
#    ENTRYPOINT check-permissions.sh, CMD node dev/run-standalone.mjs
#
#  Chromium variant, needed only for web-cookie providers
#  (gemini-web, claude-web, claude-turnstile), roughly twice the size:
#    FROM diegosouzapw/omniroute:3.8.50-web
# ──────────────────────────────────────────────────────────────────────

# Pinned on purpose. `latest` moved to a broken build once already
# (v3.8.45/3.8.46 crashed on startup, fixed in 3.8.47). Bump deliberately.
FROM diegosouzapw/omniroute:3.8.50

# Data must survive a redeploy. In Coolify add a Storage/Volume mounted at
# /app/data. If it is not writable by uid 1000 the entrypoint prints a
# warning and starts anyway; the failure surfaces later, on the first
# database write.
VOLUME /app/data

EXPOSE 20128
