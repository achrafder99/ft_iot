#!/usr/bin/env bash
#
# deploy.sh — runs ON the Azure VM (invoked over SSH by the GitHub Actions
# workflow). Pulls the new image, swaps it in, health-checks it, and
# automatically rolls back to the previous container if the health check
# fails.
#
# Required environment variables:
#   IMAGE_NAME          e.g. myuser/my-nest-app
#   IMAGE_TAG            e.g. a1b2c3d4e5f6 (short git SHA)
#   CONTAINER_NAME       e.g. app
#   APP_PORT             e.g. 3000
#   HEALTH_PATH          e.g. /health
#   DOCKERHUB_USERNAME   (only needed if the repo is private)
#   DOCKERHUB_TOKEN      (only needed if the repo is private)

set -euo pipefail

: "${IMAGE_NAME:?IMAGE_NAME is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${CONTAINER_NAME:?CONTAINER_NAME is required}"
: "${APP_PORT:?APP_PORT is required}"
: "${VM_HOST:?VM_HOST is required}"
HEALTH_PATH="${HEALTH_PATH:-/health}"
ENV_FILE="/opt/app/.env"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
PREVIOUS_CONTAINER="${CONTAINER_NAME}_previous"
HEALTH_RETRIES=10
HEALTH_INTERVAL=3

log() { echo "[deploy] $(date -u +'%Y-%m-%dT%H:%M:%SZ') - $*"; }

# --- 0. Auth (skip silently if creds not provided, e.g. public repo) -------
if [[ -n "${DOCKERHUB_USERNAME:-}" && -n "${DOCKERHUB_TOKEN:-}" ]]; then
  log "Logging in to Docker Hub..."
  echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin
fi

# --- 1. Pull the new image -------------------------------------------------
log "Pulling ${FULL_IMAGE}..."
docker pull "${FULL_IMAGE}"

# --- 2. Preserve the currently running container as a rollback target ------
if docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  log "Stopping current container and preserving it as ${PREVIOUS_CONTAINER}..."
  docker rm -f "${PREVIOUS_CONTAINER}" >/dev/null 2>&1 || true
  docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker rename "${CONTAINER_NAME}" "${PREVIOUS_CONTAINER}" >/dev/null 2>&1 || true
else
  log "No existing container named ${CONTAINER_NAME} found; this looks like a first deploy."
fi

# --- 3. Start the new container --------------------------------------------
log "Starting new container from ${FULL_IMAGE}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${APP_PORT}:${APP_PORT}" \
  --env-file "${ENV_FILE}" \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  "${FULL_IMAGE}"

# --- 4. Health check with automatic rollback --------------------------------
rollback() {
  log "!! Health check failed. Rolling back to previous container."
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  if docker inspect "${PREVIOUS_CONTAINER}" >/dev/null 2>&1; then
    docker rename "${PREVIOUS_CONTAINER}" "${CONTAINER_NAME}"
    docker start "${CONTAINER_NAME}"
    log "Rollback complete. Previous container restored and running."
  else
    log "No previous container available to roll back to. Manual intervention required."
  fi
  exit 1
}

log "Waiting for ${CONTAINER_NAME} to become healthy on port ${APP_PORT}${HEALTH_PATH}..."
for i in $(seq 1 "${HEALTH_RETRIES}"); do
  if curl -fsS "http://localhost:${APP_PORT}${HEALTH_PATH}" >/dev/null 2>&1; then
    log "Health check passed on attempt ${i}."
    HEALTHY=1
    break
  fi
  log "Attempt ${i}/${HEALTH_RETRIES} failed, retrying in ${HEALTH_INTERVAL}s..."
  sleep "${HEALTH_INTERVAL}"
done

if [[ "${HEALTHY:-0}" != "1" ]]; then
  rollback
fi

# --- 5. Clean up now that the new container is confirmed healthy -----------
log "Deployment successful. Cleaning up previous container and dangling images."
docker rm -f "${PREVIOUS_CONTAINER}" >/dev/null 2>&1 || true
docker image prune -f >/dev/null 2>&1 || true

if [[ -n "${DOCKERHUB_USERNAME:-}" ]]; then
  docker logout >/dev/null 2>&1 || true
fi

log "Done. ${CONTAINER_NAME} is running ${FULL_IMAGE}."