#!/bin/bash
set -e

if [[ "$GITHUB_EVENT_NAME" == "release" && "$GITHUB_EVENT_ACTION" == "published" ]]; then
  echo "🔄 Updating kpk-devops manifest for production release..."

  REPO_NAME="${GITHUB_REPOSITORY##*/}"
  TAG_NAME="${GITHUB_REF#refs/tags/}"
  FILE_PATH="GitOps/${REPO_NAME}/deployment.yaml"
  FULL_IMAGE="europe-docker.pkg.dev/karpatkey-data-warehouse/karpatkey/${REPO_NAME}:${TAG_NAME}"

  git config --global user.name "github-actions"
  git config --global user.email "ci@karpatkey.com"

  git clone https://x-access-token:${KPK_DEVOPS_PAT}@github.com/karpatkey/kpk-devops.git
  cd kpk-devops

  sed -i "s|\(image: .*\):.*|\1:${TAG_NAME}|" "$FILE_PATH"

  git add "$FILE_PATH"
  git commit -m "chore(ci): update prod image for ${REPO_NAME} to ${TAG_NAME}

- Updated file: ${FILE_PATH}
- New image tag: ${FULL_IMAGE}
- Triggered by GitHub release."
  git push origin main
else
  echo "ℹ️ Not a release event, skipping prod update."
fi
