#!/bin/bash
set -e

echo "==================================="
echo "DeepSeek-OCR-2 vLLM v0.8.5 启动"
echo "==================================="

# 配置
MODEL_ID="${MODEL_ID:-deepseek-ai/DeepSeek-OCR-2}"
CACHE_DIR="${MODELSCOPE_CACHE:-/models}"
MODEL_PATH="$CACHE_DIR/$MODEL_ID"

echo "模型 ID: $MODEL_ID"
echo "缓存目录: $CACHE_DIR"
echo "模型路径: $MODEL_PATH"

# 检查 Python 版本
echo "Python 版本: $(python3 --version)"
echo "vLLM 版本: $(python3 -c 'import vllm; print(vllm.__version__)')"
echo "PyTorch 版本: $(python3 -c 'import torch; print(torch.__version__)')"

# 检查模型是否已存在
if [ ! -d "$MODEL_PATH" ]; then
    echo "-----------------------------------"
    echo "模型不存在，开始从 ModelScope 下载..."
    echo "-----------------------------------"
    
    python3 -c "
from modelscope import snapshot_download
import os

print('正在下载模型: $MODEL_ID')
try:
    model_path = snapshot_download(
        '$MODEL_ID', 
        cache_dir='$CACHE_DIR',
        revision='master'
    )
    print(f'模型下载完成: {model_path}')
except Exception as e:
    print(f'下载失败: {e}')
    # 尝试从 HuggingFace 下载
    print('尝试从 HuggingFace 下载...')
    from huggingface_hub import snapshot_download as hf_download
    model_path = hf_download(
        repo_id='$MODEL_ID',
        cache_dir='$CACHE_DIR'
    )
    print(f'HuggingFace 下载完成: {model_path}')
    "
    
    if [ $? -eq 0 ]; then
        echo "✓ 模型下载成功！"
    else
        echo "✗ 模型下载失败！"
        exit 1
    fi
else
    echo "✓ 模型已存在，跳过下载"
fi

# 查找实际的模型路径（处理 ModelScope 的缓存结构）
if [ -d "$MODEL_PATH" ]; then
    ACTUAL_MODEL_PATH="$MODEL_PATH"
else
    # ModelScope 可能使用不同的目录结构
    POSSIBLE_PATHS=(
        "$CACHE_DIR/$MODEL_ID"
        "$CACHE_DIR/hub/$MODEL_ID"
        "$CACHE_DIR/models--$(echo $MODEL_ID | tr '/' '--')/snapshots"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$path" ]; then
            # 如果是 snapshots 目录，找到最新的快照
            if [[ "$path" == *"snapshots"* ]]; then
                ACTUAL_MODEL_PATH=$(ls -td "$path"/* | head -1)
            else
                ACTUAL_MODEL_PATH="$path"
            fi
            break
        fi
    done
fi

echo "实际模型路径: $ACTUAL_MODEL_PATH"

echo "-----------------------------------"
echo "启动 vLLM 服务..."
echo "-----------------------------------"

# 启动 vLLM
exec python3 -m vllm.entrypoints.openai.api_server \
    --model "$ACTUAL_MODEL_PATH" \
    --trust-remote-code \
    --dtype bfloat16 \
    --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION:-0.9}" \
    --max-model-len "${MAX_MODEL_LEN:-8192}" \
    --host 0.0.0.0 \
    --port 8000 \
    ${EXTRA_ARGS}