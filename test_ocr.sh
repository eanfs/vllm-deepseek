#!/usr/bin/env bash
#
# DeepSeek-OCR vLLM 测试脚本 (curl 版)
# 使用方法: bash test_ocr.sh [API_BASE_URL]
#

set -euo pipefail

API_BASE="${1:-http://localhost:8000}"

echo "======================================"
echo "  DeepSeek-OCR vLLM 测试"
echo "======================================"
echo ""

# ---- 1. 健康检查 ----
echo "🔍 [1/3] 健康检查..."
if curl -sf "${API_BASE}/health" > /dev/null 2>&1; then
    echo "   ✅ 服务正常"
else
    echo "   ❌ 服务不可用，请检查是否已启动:"
    echo "      docker compose up -d"
    echo "      docker compose logs -f"
    exit 1
fi
echo ""

# ---- 2. 查看模型 ----
echo "🔍 [2/3] 查看已加载模型..."
curl -s "${API_BASE}/v1/models" | python3 -m json.tool 2>/dev/null || \
    curl -s "${API_BASE}/v1/models"
echo ""
echo ""

# ---- 3. OCR 测试 ----
echo "🔍 [3/3] 执行 OCR 测试..."
echo "   图片: receipt.png (测试图片)"
echo "   提示词: Free OCR."
echo ""

RESPONSE=$(curl -s -X POST "${API_BASE}/v1/chat/completions" \
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
    }')

echo "======================================"
echo "📝 OCR 结果:"
echo "======================================"
echo ""
echo "${RESPONSE}" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    content = data['choices'][0]['message']['content']
    usage = data.get('usage', {})
    print(content)
    print()
    print(f'--- 输入 tokens: {usage.get(\"prompt_tokens\", \"N/A\")}')
    print(f'--- 输出 tokens: {usage.get(\"completion_tokens\", \"N/A\")}')
except Exception as e:
    print(f'解析失败: {e}')
    print('原始响应:')
    print(sys.stdin.read() if hasattr(sys.stdin, 'read') else '')
" 2>/dev/null || echo "${RESPONSE}"

echo ""
echo "✅ 测试完成!"
