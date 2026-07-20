#!/usr/bin/env bash
#
# k8s-deploy.sh — runs ON the VM (invoked over SSH by GitHub Actions).
# Tells the k3s cluster to roll out a new image, then waits for
# Kubernetes' own rollout status check to confirm it's healthy.
# Kubernetes handles the rolling update, readiness gating, and
# (on failure) we trigger its native rollback.
#
# Required environment variables:
#   IMAGE_NAME    e.g. myuser/nest-app
#   IMAGE_TAG     e.g. a1b2c3d4e5f6 (short git SHA)
#   NAMESPACE     e.g. app
#   DEPLOYMENT    e.g. nest-app
#   CONTAINER     e.g. nest-app (the container name inside the pod spec)

set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/home/deploy/.kube/config}"

: "${IMAGE_NAME:?IMAGE_NAME is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${NAMESPACE:?NAMESPACE is required}"
: "${DEPLOYMENT:?DEPLOYMENT is required}"
: "${CONTAINER:?CONTAINER is required}"

FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
ROLLOUT_TIMEOUT="120s"

log() { echo "[k8s-deploy] $(date -u +'%Y-%m-%dT%H:%M:%SZ') - $*"; }

log "Setting ${DEPLOYMENT}/${CONTAINER} image to ${FULL_IMAGE}..."
kubectl set image "deployment/${DEPLOYMENT}" "${CONTAINER}=${FULL_IMAGE}" -n "${NAMESPACE}"

log "Waiting for rollout to complete (timeout ${ROLLOUT_TIMEOUT})..."
if kubectl rollout status "deployment/${DEPLOYMENT}" -n "${NAMESPACE}" --timeout="${ROLLOUT_TIMEOUT}"; then
  log "Rollout successful. ${DEPLOYMENT} is now running ${FULL_IMAGE}."
else
  log "!! Rollout failed or timed out. Rolling back to previous revision."
  kubectl rollout undo "deployment/${DEPLOYMENT}" -n "${NAMESPACE}"
  kubectl rollout status "deployment/${DEPLOYMENT}" -n "${NAMESPACE}" --timeout="${ROLLOUT_TIMEOUT}"
  log "Rollback complete."
  exit 1
fi