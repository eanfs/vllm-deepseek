# DeepSeek-OCR vLLM 部署项目

## 项目概述

本项目是一个基于 Docker Compose 的 DeepSeek-OCR 模型一键部署解决方案，使用 [vLLM](https://docs.vllm.ai/) 作为推理引擎，提供 OpenAI 兼容的 API 接口。

### 核心功能

- 通过 Docker Compose 一键部署 DeepSeek-OCR 模型
- 基于 vLLM 推理引擎，提供高性能推理服务
- OpenAI 兼容 API，支持 curl 和 Python 调用
- 支持 ModelScope 和 HuggingFace 两种模型源

### 技术栈

| 组件 | 说明 |
|------|------|
| vLLM | 高性能 LLM 推理引擎 |
| Docker | 容器化部署 |
| Docker Compose | 多容器编排 |
| ModelScope / HuggingFace | 模型下载源 |
| NVIDIA GPU | GPU 加速推理 |

---

## 快速开始

### 启动服务

```bash
# 使用默认配置启动（基于 HuggingFace）
docker compose up -d

# 或使用 ModelScope 版本
docker compose -f docker-compose.modelscope.yml up -d
```

### 验证服务

```bash
# 健康检查
curl http://localhost:8000/health

# 查看已加载的模型
curl http://localhost:8000/v1/models

# 运行测试
python test_ocr.py
python test_ocr2.py
```

---

## 文件结构

| 文件/目录 | 说明 |
|-----------|------|
| `Dockerfile` | vLLM 容器镜像定义 |
| `docker-compose.yml` | Docker Compose 配置（HuggingFace 版） |
| `docker-compose.modelscope.yml` | Docker Compose 配置（ModelScope 版） |
| `entrypoint.sh` | 容器启动脚本（含 GPU 诊断、模型下载） |
| `start_vllm.sh` | 简化版 vLLM 启动脚本 |
| `test_ocr.py` / `test_ocr2.py` | OCR 测试脚本 |
| `test_ocr.sh` | 批量测试脚本 |
| `download_model.py` | 模型下载脚本 |
| `.env.example` | 环境变量配置示例 |
| `.env.ocr2` | DeepSeek-OCR-2 配置 |
| `.env.modelscope` | ModelScope 配置 |
| `build-docker.sh` | Docker 镜像构建脚本 |
| `diagnose_cuda.sh` | CUDA 诊断脚本 |
| `toggle_nvidia.sh` | NVIDIA 驱动切换脚本 |
| `models/` | 本地模型存储目录 |

---

## 配置文件说明

### 环境变量 (.env)

在 `.env.example` 或 `.env.ocr2` 中配置：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `HF_TOKEN` | - | HuggingFace Token（下载模型需要） |
| `VLLM_IMAGE_TAG` | `latest` | vLLM Docker 镜像版本 |
| `MODEL_ID` | `deepseek-ai/DeepSeek-OCR` | 模型 ID |
| `HOST_PORT` | `8000` | 主机端口 |
| `GPU_COUNT` | `all` | GPU 数量 |
| `MAX_MODEL_LEN` | `8192` | 最大序列长度 |
| `GPU_MEMORY_UTILIZATION` | `0.90` | GPU 显存使用率 |

### docker-compose.yml 关键配置

- 使用 `runtime: nvidia` 启用 NVIDIA GPU
- `privileged: true` 解决 cgroups 权限问题
- `ipc: host` 允许共享内存访问
- `shm_size: 16gb` 增加共享内存大小

---

## 常用命令

```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 查看资源使用
docker stats deepseek-ocr2-vllm

# 重新构建镜像
docker compose build --no-cache

# 进入容器调试
docker exec -it deepseek-ocr2-vllm bash
```

---

## API 使用

### curl 调用示例

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-ai/DeepSeek-OCR",
    "messages": [
      {
        "role": "user",
        "content": [
          {"type": "image_url", "image_url": {"url": "图片URL"}},
          {"type": "text", "text": "Free OCR."}
        ]
      }
    ],
    "max_tokens": 4096,
    "temperature": 0.0
  }'
```

### Python 调用示例

```python
from openai import OpenAI

client = OpenAI(api_key="EMPTY", base_url="http://localhost:8000/v1")

response = client.chat.completions.create(
    model="deepseek-ai/DeepSeek-OCR",
    messages=[
        {
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": "图片URL"}},
                {"type": "text", "text": "Free OCR."}
            ]
        }
    ],
    max_tokens=4096,
    temperature=0.0
)
print(response.choices[0].message.content)
```

---

## OCR 提示词

| 提示词 | 说明 |
|--------|------|
| `Free OCR.` | 自由格式 OCR，自动识别文本 |
| `<\|grounding\|>Convert the document to markdown.` | 转换为 Markdown 格式 |
| `Parse the figure.` | 解析图片内容 |
| `Describe this image in detail.` | 详细描述图片 |

---

## 已知问题与解决方案

### DeepSeek-OCR-2 不支持当前 vLLM 版本

**问题**: `ValueError: Model architectures ['DeepseekOCR2ForCausalLM'] are not supported`

**解决方案**:
1. 使用 vLLM nightly build: `vllm/vllm-openai:latest-nightly`
2. 使用 `unsloth/DeepSeek-OCR-2` 模型而非 `deepseek-ai/DeepSeek-OCR-2`
3. 或使用 HuggingFace Transformers 作为后端: `--model-impl transformers`

### 显存不足 (OOM)

- 降低 `GPU_MEMORY_UTILIZATION`（如 `0.80`）
- 减小 `MAX_MODEL_LEN`（如 `4096`）

### 模型下载慢

设置 HuggingFace 镜像:
```bash
HF_ENDPOINT=https://hf-mirror.com
```

---

## 开发约定

1. **模型路径**: 模型下载到 `./models` 目录
2. **端口**: 默认使用 `8000`，如有冲突可通过 `.env` 修改
3. **GPU 配置**: 默认使用全部可用 GPU
4. **日志级别**: 通过 `VLLM_LOGGING_LEVEL` 环境变量设置
5. **健康检查**: 容器配置了 healthcheck，首次加载模型较慢属正常现象

---

## 参考链接

- [vLLM 官方文档](https://docs.vllm.ai/)
- [DeepSeek-OCR 模型卡片](https://huggingface.co/deepseek-ai/DeepSeek-OCR)
- [DeepSeek-OCR-2 模型卡片](https://huggingface.co/deepseek-ai/DeepSeek-OCR-2)
- [vLLM DeepSeek-OCR 使用指南](https://docs.vllm.ai/projects/recipes/en/latest/DeepSeek/DeepSeek-OCR.html)
