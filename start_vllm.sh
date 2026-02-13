#!/bin/bash

echo "安装 DeepSeek-OCR 依赖..."
pip3 install -q addict easydict

echo "启动 vLLM API 服务器..."
python3 -m vllm.entrypoints.openai.api_server \
  --model /model \
  --trust-remote-code \
  --tokenizer-mode=slow \
  --max-model-len ${MAX_MODEL_LEN:-8192} \
  --gpu-memory-utilization ${GPU_MEMORY_UTILIZATION:-0.90} \
  --host 0.0.0.0 \
  --port 8000
