#!/bin/bash
set -e

log() { echo "[$(date +'%H:%M:%S')] $1"; }
error() { echo "[ERROR] $1" >&2; exit 1; }

# Ensure we're on a release event
if [[ "$GITHUB_EVENT_NAME" != "release" || "${GITHUB_EVENT_ACTION:-}" != "published" ]]; then
  log "Not a release event, skipping update"
  exit 0
fi

# Validate inputs
[[ -z "$KPK_DEVOPS_PAT" ]] && error "KPK_DEVOPS_PAT is required"
[[ -z "$GITHUB_REPOSITORY" ]] && error "GITHUB_REPOSITORY is required"

REPO_NAME="${GITHUB_REPOSITORY##*/}"
TAG="${GITHUB_REF#refs/tags/}"


# BASENAME="${OVERRIDE_BASENAME:-}"
if [[ -z "$OVERRIDE_BASENAME" ]]; then
  OVERRIDE_BASENAME="$REPO_NAME"  # fallback to old behavior
fi

# Determine final YAML path
if [[ -n "${CUSTOM_PATH:-}" ]]; then
  FILE_PATH="${CUSTOM_PATH}/.argocd-source-${OVERRIDE_BASENAME}.yaml"
else
  FILE_PATH="GitOps/${REPO_NAME}/prod/.argocd-source-${OVERRIDE_BASENAME}.yaml"
fi

log "🔄 Updating ArgoCD override: $FILE_PATH with tag $TAG"

# Git config and clone
git config --global user.name "github-actions[bot]"
git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

git clone "https://x-access-token:${KPK_DEVOPS_PAT}@github.com/karpatkey/kpk-devops.git"
cd kpk-devops

mkdir -p "$(dirname "$FILE_PATH")"

# Begin writing file
echo "kustomize:" > "$FILE_PATH"
echo "  images:" >> "$FILE_PATH"

# if [[ -n "${CUSTOM_IMAGE_LIST:-}" ]]; then
#   log "ℹ️ Using custom image list:"
#   # echo "$CUSTOM_IMAGE_LIST" | tr '|' '\n' | while read -r image; do
#   echo "$CUSTOM_IMAGE_LIST" | while read -r image; do
#     trimmed=$(echo "$image" | xargs)
#     [[ -n "$trimmed" ]] && echo "    - ${trimmed}:${TAG}" >> "$FILE_PATH"
#   done
# else
#   echo "    - europe-docker.pkg.dev/karpatkey-data-warehouse/karpatkey/${REPO_NAME}:${TAG}" >> "$FILE_PATH"
# fi

log "CUSTOM_IMAGE_LIST: ${CUSTOM_IMAGE_LIST:-'(none)'}"
log "FILE_PATH: $FILE_PATH"
log "TAG: $TAG"

if [[ -n "${CUSTOM_IMAGE_LIST:-}" ]]; then
  log "ℹ️ Using custom image list:"
  # Avoid a pipeline with set -e; trim lines safely
  while IFS= read -r image || [[ -n "$image" ]]; do
    # trim leading/trailing whitespace
    trimmed="${image#"${image%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -z "$trimmed" ]] && continue
    echo "    - ${trimmed}:${TAG}" >> "$FILE_PATH"
  done <<< "${CUSTOM_IMAGE_LIST}"
else
  echo "    - europe-docker.pkg.dev/karpatkey-data-warehouse/karpatkey/${REPO_NAME}:${TAG}" >> "$FILE_PATH"
fi

git add "$FILE_PATH"

FINAL_IMAGE="${CUSTOM_IMAGE_LIST:-europe-docker.pkg.dev/karpatkey-data-warehouse/karpatkey/${REPO_NAME}}:${TAG}"

# Commit if changes exist
if ! git diff --quiet HEAD -- "$FILE_PATH"; then
  
  git commit -m "chore(ci): update ${REPO_NAME} to ${TAG}

- Created or updated: ${FILE_PATH}
- Image: ${FINAL_IMAGE}
- Triggered by GitHub release in ${REPO_NAME} application repository."
  git push origin main
  log "✅ Tag update pushed successfully"
else
  log "✅ No changes detected, skipping commit"
fi

# Cleanup
rm -rf "$TEMP_DIR"
