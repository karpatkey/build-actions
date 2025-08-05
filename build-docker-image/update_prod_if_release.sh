#!/bin/bash
set -e

if [[ "$GITHUB_EVENT_NAME" == "release" && "$GITHUB_EVENT_ACTION" == "published" ]]; then
  echo "🔄 Preparing image override patch for ArgoCD Image Updater..."

  REPO_NAME="${GITHUB_REPOSITORY##*/}"
  TAG_NAME="${GITHUB_REF#refs/tags/}"
  FILE_PATH="GitOps/${REPO_NAME}/prod/.argocd-source-${REPO_NAME}.yaml"

  git config --global user.name "github-actions"
  git config --global user.email "ci@karpatkey.com"

  git clone https://x-access-token:${KPK_DEVOPS_PAT}@github.com/karpatkey/kpk-devops.git
  cd kpk-devops

  mkdir -p "$(dirname "$FILE_PATH")"

  {
    echo "kustomize:"
    echo "  images:"
    if [[ "$REPO_NAME" == "karpatkey-tokenized-fund" ]]; then
      # Special case: Two images for this repo
      echo "    - europe-docker.pkg.dev/karpatkey-data-warehouse/karpatkey/karpatkey-tokenized-fund-frontend:${TAG_NAME}"
      echo "    - europe-docker.pkg.dev/karpatkey-data-warehouse/karpatkey/karpatkey-tokenized-fund-backend:${TAG_NAME}"
    else
      # Default: Single image for all other repos
      echo "    - europe-docker.pkg.dev/karpatkey-data-warehouse/karpatkey/${REPO_NAME}:${TAG_NAME}"
    fi
  } > "$FILE_PATH"

  git add "$FILE_PATH"
  git commit -m "chore(ci): update image tags for ${REPO_NAME} to ${TAG_NAME}

- Created or updated: ${FILE_PATH}
- Triggered by GitHub release."
  git push origin main

else
  echo "ℹ️ Not a release event, skipping prod update."
fi
