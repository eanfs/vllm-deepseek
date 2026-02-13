#!/bin/bash
# CUDA 诊断脚本 - 绕过 docker-compose 直接测试
# 用法: bash diagnose_cuda.sh

set -e

echo "============================================"
echo "CUDA 诊断 - 直接 docker run 测试"
echo "============================================"

IMAGE="vllm/vllm-openai:latest"

echo ""
echo ">>> 测试 1: docker run --gpus all (标准方式)"
echo "--------------------------------------------"
docker run --rm --gpus all $IMAGE python3 -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA compiled: {torch.version.cuda}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device count: {torch.cuda.device_count()}')
    print(f'Device 0: {torch.cuda.get_device_name(0)}')
    print('✓ 测试 1 通过!')
else:
    print('✗ 测试 1 失败')
" 2>&1 || echo "✗ 测试 1 执行出错"

echo ""
echo ">>> 测试 2: docker run --gpus all + cuInit 诊断"
echo "--------------------------------------------"
docker run --rm --gpus all $IMAGE python3 -c "
import ctypes, os
print('环境变量:')
for v in ['CUDA_VISIBLE_DEVICES','NVIDIA_VISIBLE_DEVICES','NVIDIA_DRIVER_CAPABILITIES']:
    print(f'  {v}: {os.environ.get(v, \"未设置\")}')

print()
print('设备节点:')
import subprocess
r = subprocess.run(['ls','-la','/dev/nvidia0','/dev/nvidiactl','/dev/nvidia-uvm'], capture_output=True, text=True)
print(r.stdout or r.stderr)

print('cuInit 测试:')
try:
    lib = ctypes.CDLL('libcuda.so.1')
    ret = lib.cuInit(0)
    print(f'  cuInit(0) = {ret}')
    if ret == 0:
        c = ctypes.c_int()
        lib.cuDeviceGetCount(ctypes.byref(c))
        print(f'  设备数: {c.value}')
        print('  ✓ cuInit 成功')
    else:
        codes = {100:'NO_DEVICE',999:'UNKNOWN',304:'NOT_INIT',35:'INSUFFICIENT_DRIVER',46:'NOT_FOUND'}
        print(f'  ✗ 错误: {codes.get(ret, f\"code={ret}\")}')
except Exception as e:
    print(f'  ✗ 加载失败: {e}')
" 2>&1 || echo "✗ 测试 2 执行出错"

echo ""
echo ">>> 测试 3: docker run --runtime=nvidia (旧方式)"
echo "--------------------------------------------"
docker run --rm --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all $IMAGE python3 -c "
import torch
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device: {torch.cuda.get_device_name(0)}')
    print('✓ 测试 3 通过!')
else:
    print('✗ 测试 3 失败')
" 2>&1 || echo "✗ 测试 3 执行出错 (runtime=nvidia 可能不可用)"

echo ""
echo ">>> 测试 4: docker run --privileged --gpus all"
echo "--------------------------------------------"
docker run --rm --privileged --gpus all $IMAGE python3 -c "
import torch
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device: {torch.cuda.get_device_name(0)}')
    print('✓ 测试 4 通过!')
else:
    print('✗ 测试 4 失败')
" 2>&1 || echo "✗ 测试 4 执行出错"

echo ""
echo ">>> 测试 5: 检查宿主机 NVIDIA Container Toolkit 版本"
echo "--------------------------------------------"
nvidia-container-cli --version 2>&1 || echo "⚠️ nvidia-container-cli 不可用"
docker info 2>/dev/null | grep -i -A2 runtimes || echo "⚠️ 无法获取 Docker runtimes 信息"

echo ""
echo "============================================"
echo "诊断完成"
echo "============================================"
