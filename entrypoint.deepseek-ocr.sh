#!/bin/bash
set -e

echo "==================================="
echo "DeepSeek-OCR vLLM 启动"
echo "==================================="

# GPU 诊断
echo "-----------------------------------"
echo "GPU 诊断信息:"
echo "-----------------------------------"

# 检查 NVIDIA SMI
if command -v nvidia-smi &> /dev/null; then
    echo "✓ nvidia-smi 可用"
    nvidia-smi
else
    echo "✗ nvidia-smi 不可用"
fi

# 检查环境变量
echo "CUDA_VISIBLE_DEVICES: ${CUDA_VISIBLE_DEVICES:-未设置}"
echo "NVIDIA_VISIBLE_DEVICES: ${NVIDIA_VISIBLE_DEVICES:-未设置}"

# 检查 GPU 设备节点
echo "-----------------------------------"
echo "GPU 设备节点:"
ls -la /dev/nvidia* 2>/dev/null || echo "⚠️ 未找到 /dev/nvidia* 设备节点"
echo ""

# 检查 CUDA 库
echo "CUDA 库检查:"
ldconfig -p 2>/dev/null | grep -i cuda | head -5 || echo "⚠️ 未找到 CUDA 库"
ldconfig -p 2>/dev/null | grep -i libcuda | head -5 || echo "⚠️ 未找到 libcuda"
echo ""

# 低级 CUDA 诊断
echo "低级 CUDA 初始化测试:"
python3 << 'DIAGEOF'
import ctypes, os

# 检查环境变量
for var in ['CUDA_VISIBLE_DEVICES', 'NVIDIA_VISIBLE_DEVICES', 'NVIDIA_DRIVER_CAPABILITIES']:
    print(f"  {var}: {os.environ.get(var, '未设置')}")

# 尝试加载 libcuda.so 并调用 cuInit
try:
    libcuda = ctypes.CDLL("libcuda.so.1")
    result = libcuda.cuInit(0)
    if result == 0:
        print("  ✓ cuInit(0) 成功 (返回 0)")
        # 获取设备数量
        count = ctypes.c_int()
        libcuda.cuDeviceGetCount(ctypes.byref(count))
        print(f"  ✓ CUDA 设备数量: {count.value}")
    else:
        print(f"  ✗ cuInit(0) 失败，错误码: {result}")
        # CUDA 错误码对照: 100=NoDevice, 999=Unknown, 304=NotInitialized
        error_names = {100: "CUDA_ERROR_NO_DEVICE", 999: "CUDA_ERROR_UNKNOWN",
                       304: "CUDA_ERROR_NOT_INITIALIZED", 1: "CUDA_ERROR_INVALID_VALUE",
                       2: "CUDA_ERROR_OUT_OF_MEMORY", 35: "CUDA_ERROR_INSUFFICIENT_DRIVER"}
        print(f"  错误含义: {error_names.get(result, '未知错误码')}")
except Exception as e:
    print(f"  ✗ 无法加载 libcuda.so.1: {e}")
DIAGEOF

echo "-----------------------------------"

# 检查 PyTorch CUDA
echo "PyTorch CUDA 检查:"
python3 << 'PYEOF'
import torch
print(f"PyTorch 版本: {torch.__version__}")
print(f"CUDA 编译版本: {torch.version.cuda}")
print(f"CUDA 可用: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"CUDA 设备数量: {torch.cuda.device_count()}")
    for i in range(torch.cuda.device_count()):
        print(f"  设备 {i}: {torch.cuda.get_device_name(i)}")
        print(f"  显存: {torch.cuda.get_device_properties(i).total_memory / 1024**3:.2f} GB")
else:
    print("⚠️  CUDA 不可用！")
    import os
    print(f"环境变量检查:")
    print(f"  CUDA_VISIBLE_DEVICES: {os.environ.get('CUDA_VISIBLE_DEVICES', '未设置')}")
    print(f"  NVIDIA_VISIBLE_DEVICES: {os.environ.get('NVIDIA_VISIBLE_DEVICES', '未设置')}")
PYEOF
echo "-----------------------------------"

# 如果 CUDA 不可用，退出
python3 -c "import torch; exit(0 if torch.cuda.is_available() else 1)" || {
    echo "✗ CUDA 初始化失败，无法继续！"
    echo "请检查："
    echo "1. nvidia-docker 是否正确安装"
    echo "2. docker-compose.yml 中的 runtime: nvidia 配置"
    echo "3. --gpus all 参数是否正确"
    exit 1
}

echo "✓ CUDA 初始化成功"

# 配置
MODEL_ID="${MODEL_ID:-deepseek-ai/DeepSeek-OCR}"
CACHE_DIR="${MODELSCOPE_CACHE:-/models}"

echo "模型 ID: $MODEL_ID"
echo "缓存目录: $CACHE_DIR"

# 下载模型
python3 << 'PYEOF'
import os
from modelscope import snapshot_download

model_id = os.environ.get('MODEL_ID', 'deepseek-ai/DeepSeek-OCR')
cache_dir = os.environ.get('MODELSCOPE_CACHE', '/models')

model_path = f"{cache_dir}/{model_id}"

if not os.path.exists(model_path):
    print(f"下载模型: {model_id}")
    try:
        downloaded_path = snapshot_download(
            model_id, 
            cache_dir=cache_dir,
            revision='master'
        )
        print(f"✓ 模型下载成功: {downloaded_path}")
    except Exception as e:
        print(f"✗ ModelScope 下载失败: {e}")
        print("尝试从 HuggingFace 下载...")
        from huggingface_hub import snapshot_download as hf_download
        downloaded_path = hf_download(
            repo_id=model_id,
            cache_dir=cache_dir
        )
        print(f"✓ HuggingFace 下载成功: {downloaded_path}")
else:
    print(f"✓ 模型已存在: {model_path}")
PYEOF

# 查找模型路径
MODEL_PATH=$(find $CACHE_DIR -type f -name "config.json" | grep -i deepseek-ocr | head -1 | xargs dirname)

if [ -z "$MODEL_PATH" ]; then
    echo "✗ 未找到模型文件！"
    exit 1
fi

echo "实际模型路径: $MODEL_PATH"

echo "-----------------------------------"
echo "启动 vLLM 服务..."
echo "-----------------------------------"

# 配置参数
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-2}"

echo "Tensor Parallel Size: $TENSOR_PARALLEL_SIZE"

# 启动 vLLM (DeepSeek-OCR 需要禁用 Flash Attention 以兼容老显卡)
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

exec python3 -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_PATH" \
    --trust-remote-code \
    --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION:-0.75}" \
    --max-model-len "${MAX_MODEL_LEN:-8192}" \
    --enforce-eager \
    --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
    --host 0.0.0.0 \
    --port 8000 \
    ${EXTRA_ARGS}
