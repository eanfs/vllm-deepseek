# 使用 vLLM 0.8.5 官方镜像
FROM vllm/vllm-openai:v0.8.5

WORKDIR /app

# 安装 modelscope
RUN pip install modelscope --no-deps

# 安装 modelscope 依赖（避免版本冲突）
RUN pip install tqdm requests pyyaml sortedcontainers addict yapf attrs

# 设置环境变量
ENV MODELSCOPE_CACHE=/models
ENV HF_ENDPOINT=https://hf-mirror.com

# 复制启动脚本
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]