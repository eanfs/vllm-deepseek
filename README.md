# 🔍 DeepSeek-OCR vLLM 部署

通过 Docker Compose 一键部署 [DeepSeek-OCR](https://huggingface.co/deepseek-ai/DeepSeek-OCR) 模型，基于 [vLLM](https://docs.vllm.ai/) 推理引擎，提供 OpenAI 兼容 API。

## 📋 环境要求

| 组件 | 要求 |
|------|------|
| **GPU** | NVIDIA GPU，≥16GB 显存 (推荐 A100/L40S/4090) |
| **驱动** | NVIDIA Driver ≥ 525.60.13 |
| **Docker** | Docker Engine ≥ 24.0 |
| **NVIDIA 容器工具** | [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) |
| **磁盘** | 建议预留 ≥30GB 用于模型缓存 |

## 🚀 快速启动

### 1. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env，填入你的 HuggingFace Token
vim .env
```

### 2. 启动服务

```bash
docker compose up -d
```

### 3. 查看启动日志

```bash
# 等待出现 "Started server process" 表示启动成功
docker compose logs -f
```

### 4. 验证服务

```bash
# 健康检查
curl http://localhost:8000/health

# 查看已加载的模型
curl http://localhost:8000/v1/models
```

## 📡 API 使用

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
          {
            "type": "image_url",
            "image_url": {
              "url": "https://ofasys-multimodal-wlcb-3-toshanghai.oss-accelerate.aliyuncs.com/wpf272043/keepme/image/receipt.png"
            }
          },
          {
            "type": "text",
            "text": "Free OCR."
          }
        ]
      }
    ],
    "max_tokens": 4096,
    "temperature": 0.0,
    "skip_special_tokens": false,
    "vllm_xargs": {
      "ngram_size": 30,
      "window_size": 90,
      "whitelist_token_ids": [128821, 128822]
    }
  }'
```

### Python 调用示例

```bash
pip install openai
python test_ocr.py
```

详见 [test_ocr.py](./test_ocr.py)。

## 💡 常用 OCR 提示词

| 提示词 | 说明 |
|--------|------|
| `Free OCR.` | 自由格式 OCR，自动识别文本 |
| `<\|grounding\|>Convert the document to markdown.` | 将文档转换为 Markdown 格式 |
| `Read all the text in the image.` | 读取图片中所有文本 |
| `Convert the table to markdown.` | 将表格转换为 Markdown |

> **提示**: DeepSeek-OCR 使用**普通提示词**效果优于指令格式（instruction format）。

## ⚙️ 配置说明

所有配置项在 `.env` 文件中修改：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `HF_TOKEN` | (空) | HuggingFace Token |
| `VLLM_IMAGE_TAG` | `latest` | vLLM Docker 镜像版本 |
| `HOST_PORT` | `8000` | 主机端口号 |
| `GPU_COUNT` | `all` | GPU 数量 |
| `MAX_MODEL_LEN` | `8192` | 最大序列长度 |
| `GPU_MEMORY_UTILIZATION` | `0.90` | GPU 显存使用率 |
| `HF_CACHE_DIR` | `~/.cache/huggingface` | 模型缓存路径 |

## 🛠 常用命令

```bash
# 启动
docker compose up -d

# 停止
docker compose down

# 查看日志
docker compose logs -f

# 重启
docker compose restart

# 查看资源使用
docker stats deepseek-ocr
```

## ❓ 常见问题

### 模型下载很慢？
设置 HuggingFace 镜像（中国大陆用户）：
```bash
# 在 .env 中添加 / 或在 docker-compose.yml 的 environment 中添加
HF_ENDPOINT=https://hf-mirror.com
```

### 显存不足 (OOM)？
- 降低 `GPU_MEMORY_UTILIZATION`（如 `0.80`）
- 减小 `MAX_MODEL_LEN`（如 `4096`）

### 健康检查失败？
模型首次加载较慢，请耐心等待。查看日志确认加载进度：
```bash
docker compose logs -f vllm
```

## 📚 参考资料

- [vLLM Docker 部署文档](https://docs.vllm.ai/en/stable/deployment/docker/)
- [DeepSeek-OCR 模型卡片](https://huggingface.co/deepseek-ai/DeepSeek-OCR)
- [vLLM DeepSeek-OCR 使用指南](https://docs.vllm.ai/projects/recipes/en/latest/DeepSeek/DeepSeek-OCR.html)
- [DeepSeek-OCR GitHub](https://github.com/deepseek-ai/DeepSeek-OCR)
