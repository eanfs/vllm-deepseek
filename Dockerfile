FROM vllm/vllm-openai:latest

WORKDIR /app

# 安装 modelscope
RUN pip install modelscope --break-system-packages

# 设置环境变量
ENV MODELSCOPE_CACHE=/models
ENV HF_ENDPOINT=https://hf-mirror.com

# 复制启动脚本
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]