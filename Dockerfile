# ──────────────────────────────────────────────────────────────────────
#  OmniRoute — optional Dockerfile for Coolify ("Dockerfile" build pack)
#
#  The Docker Hub image is ready to use as-is — the preferred deployment
#  is docker-compose.yml from this repo ("Docker Compose Empty" build
#  pack). This file is only useful if you prefer a simple Dockerfile /
#  Docker Image resource in Coolify, or want to bake something extra
#  into the image.
#
#  Built into the image (no need to repeat):
#    EXPOSE 20128, USER node, DATA_DIR=/app/data,
#    HEALTHCHECK: node healthcheck.mjs (every 30 s),
#    ENTRYPOINT: check-permissions.sh → node dev/run-standalone.mjs
#
#  For production pin a version instead of latest, e.g.:
#    FROM diegosouzapw/omniroute:3.8.46
#  Chromium variant (web-cookie providers: gemini-web / claude-web):
#    FROM diegosouzapw/omniroute:latest-web
# ──────────────────────────────────────────────────────────────────────
FROM diegosouzapw/omniroute:latest

# Data must persist across deployments — in Coolify add a Storage/Volume
# mounted at /app/data (owner: uid 1000 / user node).
VOLUME /app/data

EXPOSE 20128
