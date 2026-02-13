# 使用 ModelScope 部署 DeepSeek-OCR-2

通过 ModelScope（魔搭社区）下载 **DeepSeek-OCR-2** 模型，避免 HuggingFace 访问问题。

## 📋 重要说明

**DeepSeek-OCR-2 与 DeepSeek-OCR 的区别：**
- **DeepSeek-OCR-2** 不需要 `logits-processor` 和 `mm-processor-cache` 等参数
- 使用 **vLLM v0.8.5** 版本以确保兼容性
- 模型大小约 **26GB**

## 📥 步骤 1：下载模型

### 安装 ModelScope SDK
```bash
pip install modelscope
```

### 创建虚拟环境并下载
```bash
python3 -m venv venv
source venv/bin/activate
pip install modelscope

python download_modelscope.py
# 选择 2 (DeepSeek-OCR-2)
```

或直接运行：
```bash
source venv/bin/activate
python3 <<'EOF'
from modelscope import snapshot_download

model_dir = snapshot_download(
    'deepseek-ai/DeepSeek-OCR-2',
    cache_dir='./models',
    revision='master'
)
print(f"模型已下载到: {model_dir}")
EOF
```

## ⚙️ 步骤 2：配置环境变量

```bash
# 复制配置文件
cp .env.ocr2 .env

# 查看配置（如需修改）
cat .env
```

主要配置项：
- `MODELSCOPE_MODEL_DIR`: 模型本地路径（默认 ./models/deepseek-ai/DeepSeek-OCR-2）
- `HOST_PORT`: 服务端口（默认 8000）
- `GPU_MEMORY_UTILIZATION`: 显存使用率（默认 0.90）
- `MAX_MODEL_LEN`: 最大序列长度（默认 8192）

## 🚀 步骤 3：启动服务

```bash
# 启动 Docker 容器
docker compose -f docker-compose.modelscope.yml up -d

# 查看启动日志
docker compose -f docker-compose.modelscope.yml logs -f

# 等待出现 "Uvicorn running on http://0.0.0.0:8000" 表示启动成功
```

## ✅ 步骤 4：验证服务

```bash
# 健康检查
curl http://localhost:8000/health

# 查看已加载的模型
curl http://localhost:8000/v1/models
```

## 📡 使用 API

### curl 调用示例

```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-ai/DeepSeek-OCR-2",
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "image_url",
            "image_url": {
              "url": "https://example.com/receipt.png"
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
    "temperature": 0.0
  }'
```

### Python 调用示例

```bash
pip install openai
python test_ocr2.py
```

## 💡 常用 OCR 提示词

| 提示词 | 说明 |
|--------|------|
| `Free OCR.` | 自由格式 OCR，自动识别文本 |
| `<|grounding|>Convert the document to markdown.` | 将文档转换为 Markdown 格式 |
| `Read all the text in the image.` | 读取图片中所有文本 |

## 🛠 常用命令

```bash
# 查看日志
docker compose -f docker-compose.modelscope.yml logs -f

# 停止服务
docker compose -f docker-compose.modelscope.yml down

# 重启服务
docker compose -f docker-compose.modelscope.yml restart

# 查看资源使用
docker stats deepseek-ocr-2

# 进入容器调试
docker exec -it deepseek-ocr-2 bash
```

## ❓ 常见问题

### Q: 启动失败，提示版本不兼容？
A: 确保 Docker 镜像使用 `vllm/vllm-openai:v0.8.5-cu121`，这是 DeepSeek-OCR-2 要求的版本。

### Q: 模型路径找不到？
A: 运行 `ls -la ./models/` 查看实际路径，然后在 `.env` 中设置正确的 `MODELSCOPE_MODEL_DIR`

### Q: 显存不足？
A: 在 `.env` 中降低 `GPU_MEMORY_UTILIZATION`（如 `0.80`）

### Q: 下载速度慢？
A: ModelScope 已在国内优化，确保网络连接正常。

### Q: 如何切换回 DeepSeek-OCR (第一代)？
A: 下载第一代模型并更新 `.env` 中的路径即可。但注意需要不同的 vLLM 配置。

## 📝 文件说明

| 文件 | 说明 |
|------|------|
| `docker-compose.modelscope.yml` | Docker 配置（使用 vLLM v0.8.5） |
| `.env.ocr2` | DeepSeek-OCR-2 环境变量配置 |
| `download_modelscope.py` | 模型下载脚本 |
| `test_ocr2.py` | OCR-2 测试脚本 |

## 📚 参考资料

- [DeepSeek-OCR-2 GitHub](https://github.com/deepseek-ai/DeepSeek-OCR-2)
- [DeepSeek-OCR-2 HuggingFace](https://huggingface.co/deepseek-ai/DeepSeek-OCR-2)
- [vLLM 官方文档](https://docs.vllm.ai/)
