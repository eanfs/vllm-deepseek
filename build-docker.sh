#!/bin/bash
# Build Docker image for vLLM with optional PyTorch Nightly support
#
# Usage:
#   ./build-docker.sh                    # Build with stable PyTorch
#   PYTORCH_NIGHTLY=1 ./build-docker.sh  # Build with PyTorch nightly
#
# Advanced options:
#   CUDA_VERSION=12.4.0 PYTORCH_NIGHTLY=1 ./build-docker.sh
#   BUILD_TARGET=vllm-openai PYTORCH_NIGHTLY=1 ./build-docker.sh

set -euo pipefail

# Configuration with defaults
export PYTORCH_NIGHTLY=${PYTORCH_NIGHTLY:-0}
export CUDA_VERSION=${CUDA_VERSION:-12.4.0}
export PYTHON_VERSION=${PYTHON_VERSION:-3.12}

# Docker build settings
DOCKERFILE_PATH=${DOCKERFILE_PATH:-docker/Dockerfile}
BUILD_TARGET=${BUILD_TARGET:-vllm-openai}
IMAGE_TAG=${IMAGE_TAG:-}

# Determine image tag
if [ -z "$IMAGE_TAG" ]; then
    if [ "$PYTORCH_NIGHTLY" = "1" ]; then
        IMAGE_TAG="vllm-openai:nightly-cuda${CUDA_VERSION}"
    else
        IMAGE_TAG="vllm-openai:stable-cuda${CUDA_VERSION}"
    fi
fi

echo "========================================"
echo "Building vLLM Docker Image"
echo "========================================"
echo "PYTORCH_NIGHTLY: $PYTORCH_NIGHTLY"
echo "CUDA_VERSION: $CUDA_VERSION"
echo "PYTHON_VERSION: $PYTHON_VERSION"
echo "BUILD_TARGET: $BUILD_TARGET"
echo "IMAGE_TAG: $IMAGE_TAG"
echo "========================================"
echo ""

# Build command
BUILD_ARGS=(
    --build-arg "PYTORCH_NIGHTLY=$PYTORCH_NIGHTLY"
    --build-arg "CUDA_VERSION=$CUDA_VERSION"
    --build-arg "PYTHON_VERSION=$PYTHON_VERSION"
    --target "$BUILD_TARGET"
    -t "$IMAGE_TAG"
    -f "$DOCKERFILE_PATH"
)

# Add optional proxy/build args if set
if [ -n "${PIP_INDEX_URL:-}" ]; then
    BUILD_ARGS+=(--build-arg "PIP_INDEX_URL=$PIP_INDEX_URL")
fi

if [ -n "${HTTP_PROXY:-}" ]; then
    BUILD_ARGS+=(--build-arg "HTTP_PROXY=$HTTP_PROXY")
fi

if [ -n "${HTTPS_PROXY:-}" ]; then
    BUILD_ARGS+=(--build-arg "HTTPS_PROXY=$HTTPS_PROXY")
fi

# Run docker build
echo "Running: docker build ${BUILD_ARGS[*]} ."
docker build "${BUILD_ARGS[@]}" .

echo ""
echo "========================================"
echo "Build completed successfully!"
echo "Image: $IMAGE_TAG"
echo "========================================"

# Print usage hint
echo ""
echo "To run the container:"
if [ "$BUILD_TARGET" = "vllm-openai" ]; then
    echo "  docker run --gpus all -p 8000:8000 $IMAGE_TAG --model <model_name>"
else
    echo "  docker run --gpus all -it $IMAGE_TAG"
fi
