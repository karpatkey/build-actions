#!/bin/bash
set -e

if [[ "$GITHUB_EVENT_NAME" == "release" && "$GITHUB_EVENT_ACTION" == "published" ]]; then
  echo "🔄 Preparing image override patch for ArgoCD Image Updater..."

  REPO_NAME="${GITHUB_REPOSITORY##*/}"
  TAG_NAME="${GITHUB_REF#refs/tags/}"
  IMAGE_TAG="europe-docker.pkg.dev/karpatkey-data-warehouse/karpatkey/${REPO_NAME}:${TAG_NAME}"
  FILE_PATH="GitOps/${REPO_NAME}/.image-updater-${REPO_NAME}-prod.yaml"

  git config --global user.name "github-actions"
  git config --global user.email "ci@karpatkey.com"

  git clone https://x-access-token:${KPK_DEVOPS_PAT}@github.com/karpatkey/kpk-devops.git
  cd kpk-devops

  mkdir -p "$(dirname "$FILE_PATH")"

  # NOTE: No leading indentation in YAML block to avoid invalid formatting
  cat > "$FILE_PATH" <<EOF
kustomize:
  images:
    - ${IMAGE_TAG}
EOF

  git add "$FILE_PATH"
  git commit -m "chore(ci): update image tag for ${REPO_NAME} to ${TAG_NAME}

- Created or updated: ${FILE_PATH}
- Image: ${IMAGE_TAG}
- Triggered by GitHub release."
  git push origin main
else
  echo "ℹ️ Not a release event, skipping prod update."
fi
