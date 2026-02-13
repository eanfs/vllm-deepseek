FROM vllm/vllm-openai:latest

WORKDIR /app

# 安装 modelscope 和 DeepSeek-OCR 完整依赖
# 基于官方 requirements.txt: https://github.com/deepseek-ai/DeepSeek-OCR/blob/main/requirements.txt
# vllm 镜像已包含: transformers, tokenizers, Pillow, numpy
RUN pip install --no-cache-dir \
    modelscope \
    PyMuPDF \
    img2pdf \
    einops \
    easydict \
    addict \
    matplotlib \
    --break-system-packages

# 注意：vLLM 基础镜像已包含 flash-attn
# 如需特定版本，需先安装 git: RUN apt-get update && apt-get install -y git

# 设置环境变量
ENV MODELSCOPE_CACHE=/models
ENV HF_ENDPOINT=https://hf-mirror.com

# 复制启动脚本
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]