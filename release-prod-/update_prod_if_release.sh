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

# Determine final YAML path
if [[ -n "${CUSTOM_PATH:-}" ]]; then
  FILE_PATH="${CUSTOM_PATH}/.argocd-source-${REPO_NAME}.yaml"
else
  FILE_PATH="GitOps/${REPO_NAME}/prod/.argocd-source-${REPO_NAME}.yaml"
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

if [[ -n "${CUSTOM_IMAGE_LIST:-}" ]]; then
  log "ℹ️ Using custom image list:"
  echo "$CUSTOM_IMAGE_LIST" | tr '|' '\n' | while read -r image; do
    trimmed=$(echo "$image" | xargs)
    [[ -n "$trimmed" ]] && echo "    - ${trimmed}:${TAG}" >> "$FILE_PATH"
  done
else
  echo "    - europe-docker.pkg.dev/karpatkey-data-warehouse/karpatkey/${REPO_NAME}:${TAG}" >> "$FILE_PATH"
fi

# Commit if changes exist
if ! git diff --quiet HEAD -- "$FILE_PATH"; then
  git add "$FILE_PATH"
  git commit -m "chore(ci): update ${REPO_NAME} to ${TAG}

- Created or updated: ${FILE_PATH}
- Triggered by GitHub release."
  git push origin main
  log "✅ Tag update pushed successfully"
else
  log "✅ No changes detected, skipping commit"
fi

# Cleanup
rm -rf "$TEMP_DIR"
