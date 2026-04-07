#!/usr/bin/env bash
set -euo pipefail

REGISTRY="ghcr.io"
BUILDER_NAME="odp-qemu-builder"
CACHE_DIR="${HOME}/.cache/docker-buildx/${BUILDER_NAME}"
PLATFORMS="linux/amd64,linux/arm64"

# ---------------------------------------------------------------------------
# Derive owner/repo from the git remote, mirroring github.repository
# ---------------------------------------------------------------------------
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
if [[ -z "$REMOTE_URL" ]]; then
    echo "error: no git remote 'origin' found" >&2
    exit 1
fi

# Accept both SSH (git@github.com:owner/repo.git) and HTTPS forms
REPO=$(echo "$REMOTE_URL" \
    | sed -E 's|.*github\.com[:/]([^/]+/[^/]+)|\1|; s|\.git$||')

if [[ "$REPO" == "$REMOTE_URL" ]]; then
    echo "error: could not parse a GitHub owner/repo from remote URL: $REMOTE_URL" >&2
    exit 1
fi

# ghcr.io requires the image name to be lowercase
# Push to the repo-scoped package (e.g. ghcr.io/owner/repo/qemu)
IMAGE="${REGISTRY}/$(echo "$REPO" | tr '[:upper:]' '[:lower:]')/qemu"

# ---------------------------------------------------------------------------
# Tags: branch + short SHA, plus 'latest' on main
# ---------------------------------------------------------------------------
GIT_SHA=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_SHA_FULL=$(git rev-parse HEAD)

TAGS=(
    "--tag" "${IMAGE}:${GIT_BRANCH}"
    "--tag" "${IMAGE}:sha-${GIT_SHA}"
)
if [[ "$GIT_BRANCH" == "main" ]]; then
    TAGS+=("--tag" "${IMAGE}:latest")
fi

# ---------------------------------------------------------------------------
# Ensure a dedicated buildx builder exists (docker-container driver gives us
# persistent --mount=type=cache storage between local builds)
# ---------------------------------------------------------------------------
if ! docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
    echo "Creating buildx builder '${BUILDER_NAME}'..."
    docker buildx create \
        --name "$BUILDER_NAME" \
        --driver docker-container \
        --bootstrap
fi

# ---------------------------------------------------------------------------
# Log in to ghcr.io if not already authenticated
# ---------------------------------------------------------------------------
if ! docker login "$REGISTRY" --username ignored --password /dev/null 2>/dev/null; then
    echo "Logging in to ${REGISTRY}..."
    docker login "$REGISTRY"
fi

# ---------------------------------------------------------------------------
# Build and push
# Local layer cache uses type=local so it persists across runs without needing
# GHA infrastructure.  A new destination is written alongside the old one and
# swapped in afterwards to prevent unbounded cache growth.
# ---------------------------------------------------------------------------
mkdir -p "$CACHE_DIR"

echo
echo "Building ${IMAGE} for ${PLATFORMS}"
echo "  branch : ${GIT_BRANCH}"
echo "  sha    : ${GIT_SHA}"
echo "  tags   : ${TAGS[*]}"
echo

docker buildx build \
    --builder "$BUILDER_NAME" \
    --platform "$PLATFORMS" \
    "${TAGS[@]}" \
    --label "org.opencontainers.image.source=https://github.com/${REPO}" \
    --label "org.opencontainers.image.revision=${GIT_SHA_FULL}" \
    --label "org.opencontainers.image.ref.name=${GIT_BRANCH}" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --cache-from "type=local,src=${CACHE_DIR}" \
    --cache-to  "type=local,dest=${CACHE_DIR}-new,mode=max" \
    --push \
    .

# Rotate cache: replace old with new to avoid unbounded growth
rm -rf "$CACHE_DIR"
mv "${CACHE_DIR}-new" "$CACHE_DIR"

echo
echo "Done. Pushed:"
for tag in "${TAGS[@]}"; do
    [[ "$tag" == --tag ]] && continue
    echo "  ${tag}"
done
