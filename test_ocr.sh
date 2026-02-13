#!/usr/bin/env bash
#
# DeepSeek-OCR vLLM 测试脚本
# 使用方法:
#   bash test_ocr.sh                    # 使用默认配置
#   bash test_ocr.sh http://192.168.1.100:8000  # 自定义地址
#   MODEL_NAME=deepseek-ai/DeepSeek-OCR bash test_ocr.sh  # 自定义模型
#

set -euo pipefail

# 默认配置
API_BASE="${1:-${VLLM_API_URL:-http://localhost:8000}}"
MODEL_NAME="${MODEL_NAME:-deepseek-ai/DeepSeek-OCR}"
TEST_IMAGE_URL="${TEST_IMAGE_URL:-https://ofasys-multimodal-wlcb-3-toshanghai.oss-accelerate.aliyuncs.com/wpf272043/keepme/image/receipt.png}"
MAX_TOKENS="${MAX_TOKENS:-4096}"
TIMEOUT="${TIMEOUT:-120}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---- 工具函数 ----
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# ---- 1. 健康检查 ----
check_health() {
    log_info "检查服务健康状态..."
    
    local max_retries=5
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if curl -sf "${API_BASE}/health" > /dev/null 2>&1; then
            log_success "服务运行正常"
            return 0
        fi
        retry=$((retry + 1))
        log_warn "等待服务启动... ($retry/$max_retries)"
        sleep 3
    done
    
    log_error "服务健康检查失败"
    return 1
}

# ---- 2. 查看模型 ----
check_models() {
    log_info "获取模型列表..."
    
    local response
    response=$(curl -s "${API_BASE}/v1/models" 2>/dev/null)
    
    if [ -z "$response" ]; then
        log_error "无法连接到 API"
        return 1
    fi
    
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    
    # 检查目标模型是否加载
    if echo "$response" | grep -q "\"id\": \"${MODEL_NAME}\""; then
        log_success "模型 ${MODEL_NAME} 已加载"
    else
        log_warn "未找到模型 ${MODEL_NAME}，将使用默认模型"
    fi
    echo ""
}

# ---- 3. OCR 测试 ----
run_ocr_test() {
    local prompt="$1"
    local image_url="$2"
    local test_name="$3"
    
    log_info "执行测试: ${test_name}"
    echo "   图片: ${image_url}"
    echo "   提示词: ${prompt}"
    echo ""
    
    local start_time
    start_time=$(date +%s)
    
    local response
    local http_code
    
    # 捕获 HTTP 状态码
    http_code=$(curl -s -o /tmp/ocr_response.json -w "%{http_code}" \
        -X POST "${API_BASE}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${MODEL_NAME}\",
            \"messages\": [
                {
                    \"role\": \"user\",
                    \"content\": [
                        {\"type\": \"image_url\", \"image_url\": {\"url\": \"${image_url}\"}},
                        {\"type\": \"text\", \"text\": \"${prompt}\"}
                    ]
                }
            ],
            \"max_tokens\": ${MAX_TOKENS},
            \"temperature\": 0.0
        }" 2>/dev/null || echo "000")
    
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    
    if [ "$http_code" != "200" ]; then
        log_error "API 请求失败 (HTTP ${http_code})"
        if [ -f /tmp/ocr_response.json ]; then
            echo "错误响应:" 
            cat /tmp/ocr_response.json | python3 -m json.tool 2>/dev/null || cat /tmp/ocr_response.json
        fi
        return 1
    fi
    
    # 解析响应
    python3 -c "
import json
import sys

with open('/tmp/ocr_response.json', 'r') as f:
    data = json.load(f)

try:
    content = data['choices'][0]['message']['content']
    usage = data.get('usage', {})
    
    print('=' * 60)
    print(content)
    print('=' * 60)
    print()
    print(f'📊 Token 统计:')
    print(f'   输入: {usage.get(\"prompt_tokens\", \"N/A\")}')
    print(f'   输出: {usage.get(\"completion_tokens\", \"N/A\")}')
    print(f'   总计: {usage.get(\"total_tokens\", \"N/A\")}')
except KeyError as e:
    print(f'解析错误: {e}')
    print('原始响应:')
    print(json.dumps(data, indent=2, ensure_ascii=False))
" 2>/dev/null
    
    echo ""
    echo "⏱️  耗时: ${elapsed} 秒"
    echo ""
    
    return 0
}

# ---- 主流程 ----
main() {
    echo "========================================"
    echo "  DeepSeek-OCR vLLM 测试"
    echo "========================================"
    echo ""
    echo "配置:"
    echo "  API 地址: ${API_BASE}"
    echo "  模型名称: ${MODEL_NAME}"
    echo "  超时时间: ${TIMEOUT}s"
    echo ""
    
    # 健康检查
    check_health || exit 1
    echo ""
    
    # 查看模型
    check_models
    echo ""
    
    # ---- 测试 1: Free OCR ----
    echo "========================================"
    echo "  测试 1: Free OCR (自由识别)"
    echo "========================================"
    run_ocr_test "Free OCR." "$TEST_IMAGE_URL" "Free OCR"
    
    # ---- 测试 2: Grounding Mode ----
    echo "========================================"
    echo "  测试 2: Grounding Mode (布局保留)"
    echo "========================================"
    run_ocr_test "<|grounding|>Convert the document to markdown." "$TEST_IMAGE_URL" "Grounding Mode"
    
    # ---- 总结 ----
    echo "========================================"
    echo "  ✅ 测试完成"
    echo "========================================"
    echo ""
    echo "提示: 如需测试其他图片，可设置环境变量:"
    echo "  TEST_IMAGE_URL=https://your-image-url.com/image.png bash test_ocr.sh"
    echo ""
}

main "$@"