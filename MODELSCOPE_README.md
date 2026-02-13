# 使用 ModelScope 部署 DeepSeek-OCR

通过 ModelScope（魔搭社区）下载模型，避免 HuggingFace 访问问题。

## 📋 步骤 1：安装 ModelScope SDK

```bash
pip install modelscope
```

## 📥 步骤 2：下载模型

```bash
# 方式 1: 使用脚本下载（推荐）
python download_modelscope.py

# 方式 2: 直接运行 Python 代码
python3 <<'EOF'
from modelscope import snapshot_download

model_dir = snapshot_download(
    'deepseek-ai/DeepSeek-OCR',
    cache_dir='./models',
    revision='master'
)
print(f"模型已下载到: {model_dir}")
EOF
```

下载大小约 **26GB**，请耐心等待。

## ⚙️ 步骤 3：配置环境变量

```bash
# 复制配置文件
cp .env.modelscope .env

# 如需修改，编辑 .env
# 主要配置项：
# - MODELSCOPE_MODEL_DIR: 模型本地路径（默认 ./models/deepseek-ai/DeepSeek-OCR）
# - HOST_PORT: 服务端口（默认 8000）
# - GPU_MEMORY_UTILIZATION: 显存使用率（默认 0.90）
# - MAX_MODEL_LEN: 最大序列长度（默认 8192）
```

## 🚀 步骤 4：启动服务

```bash
# 启动 Docker 容器
docker compose -f docker-compose.modelscope.yml up -d

# 查看启动日志
docker compose -f docker-compose.modelscope.yml logs -f

# 等待出现 "就绪状态/ready" 表示启动成功
```

## ✅ 步骤 5：验证服务

```bash
# 健康检查
curl http://localhost:8000/health

# 查看已加载的模型
curl http://localhost:8000/v1/models
```

## 📡 使用 API

使用方式与原来完全一致，参考 `test_ocr.py`:

```bash
# 安装 OpenAI SDK
pip install openai

# 运行测试
python test_ocr.py
```

## 🛠 常用命令

```bash
# 查看日志
docker compose -f docker-compose.modelscope.yml logs -f

# 停止服务
docker compose -f docker-compose.modelscope.yml down

# 重启服务
docker compose -f docker-compose.modelscope.yml restart

# 查看资源使用
docker stats deepseek-ocr
```

## 📝 文件说明

| 文件 | 说明 |
|------|------|
| `docker-compose.modelscope.yml` | ModelScope 版本的 Docker 配置 |
| `.env.modelscope` | ModelScope 环境变量配置 |
| `download_modelscope.py` | 模型下载脚本 |

## ❓ 常见问题

### Q: 下载速度慢？
A: ModelScope 已经在国内优化，速度通常比 HuggingFace 快。如仍慢，可尝试：
   - 使用代理
   - 切换网络环境

### Q: 模型路径找不到？
A: 运行下载脚本后，确认输出中的路径，然后在 `.env` 中设置 `MODELSCOPE_MODEL_DIR`

### Q: 显存不足？
A: 在 `.env` 中降低 `GPU_MEMORY_UTILIZATION`（如 `0.80`）

### Q: 如何更新模型？
A: 删除 `./models` 目录，重新运行 `download_modelscope.py`
