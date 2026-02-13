#!/usr/bin/env bash
#
# DeepSeek-OCR vLLM 测试脚本
# 使用方法:
#   bash test_ocr.sh                    # 使用默认远程图片
#   bash test_ocr.sh local              # 使用本地 frames/ 目录图片
#   bash test_ocr.sh local 5            # 只测试前 5 张
#   MODEL_NAME=unsloth/DeepSeek-OCR-2-bf16 bash test_ocr.sh  # 自定义模型
#

set -euo pipefail

# 默认配置
MODE="${1:-remote}"
LIMIT="${2:-0}"  # 0 表示不限制
API_BASE="${VLLM_API_URL:-http://localhost:8000}"
MODEL_NAME="${MODEL_NAME:-unsloth/DeepSeek-OCR-2-bf16}"
MAX_TOKENS="${MAX_TOKENS:-4096}"
TIMEOUT="${TIMEOUT:-120}"

# 本地图片目录
FRAMES_DIR="${FRAMES_DIR:-./frames}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# ---- 获取模型列表 ----
check_models() {
    log_info "获取模型列表..."
    
    curl -s "${API_BASE}/v1/models" | python3 -m json.tool 2>/dev/null || \
        curl -s "${API_BASE}/v1/models"
    
    echo ""
}

# ---- 远程 OCR 测试 ----
test_remote() {
    local prompt="$1"
    local image_url="$2"
    local test_name="$3"
    
    log_info "测试: ${test_name}"
    echo "   图片: ${image_url}"
    echo "   提示词: ${prompt}"
    
    local start_time
    start_time=$(date +%s)
    
    local http_code
    http_code=$(curl -s -o /tmp/ocr_response.json -w "%{http_code}" \
        -X POST "${API_BASE}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${MODEL_NAME}\",
            \"messages\": [{\"role\": \"user\", \"content\": [
                {\"type\": \"image_url\", \"image_url\": {\"url\": \"${image_url}\"}},
                {\"type\": \"text\", \"text\": \"${prompt}\"}
            ]}],
            \"max_tokens\": ${MAX_TOKENS},
            \"temperature\": 0.0
        }" 2>/dev/null || echo "000")
    
    local elapsed=$(( $(date +%s) - start_time ))
    
    if [ "$http_code" != "200" ]; then
        log_error "请求失败 (HTTP ${http_code})"
        [ -f /tmp/ocr_response.json ] && cat /tmp/ocr_response.json
        return 1
    fi
    
    python3 -c "
import json
with open('/tmp/ocr_response.json') as f:
    data = json.load(f)
content = data['choices'][0]['message']['content']
usage = data.get('usage', {})
print('=' * 60)
print(content[:2000] + '...' if len(content) > 2000 else content)
print('=' * 60)
print(f'📊 Tokens: 输入={usage.get(\"prompt_tokens\", \"?\")} 输出={usage.get(\"completion_tokens\", \"?\")}')
" 2>/dev/null
    
    echo "⏱️ 耗时: ${elapsed}s"
    return 0
}

# ---- 本地图片 OCR 测试 ----
test_local_image() {
    local image_path="$1"
    local frame_num="$2"
    local prompt="$3"
    
    # 检查文件是否存在
    if [ ! -f "$image_path" ]; then
        log_error "文件不存在: $image_path"
        return 1
    fi
    
    # 获取图片 base64
    local base64_data
    base64_data=$(base64 -i "$image_path" | tr -d '\n')
    
    # 根据文件类型确定 mime 类型
    local mime_type="image/png"
    case "${image_path##*.}" in
        jpg|jpeg) mime_type="image/jpeg" ;;
        png) mime_type="image/png" ;;
        webp) mime_type="image/webp" ;;
        gif) mime_type="image/gif" ;;
    esac
    
    local start_time
    start_time=$(date +%s)
    
    local http_code
    http_code=$(curl -s -o /tmp/ocr_response.json -w "%{http_code}" \
        -X POST "${API_BASE}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"${MODEL_NAME}\",
            \"messages\": [{\"role\": \"user\", \"content\": [
                {\"type\": \"image_url\", \"image_url\": {\"url\": \"data:${mime_type};base64,${base64_data}\"}},
                {\"type\": \"text\", \"text\": \"${prompt}\"}
            ]}],
            \"max_tokens\": ${MAX_TOKENS},
            \"temperature\": 0.0
        }" 2>/dev/null || echo "000")
    
    local elapsed=$(( $(date +%s) - start_time ))
    
    if [ "$http_code" != "200" ]; then
        log_error "请求失败 (HTTP ${http_code}) - 帧 #$frame_num"
        return 1
    fi
    
    # 提取内容
    local content
    content=$(python3 -c "
import json
with open('/tmp/ocr_response.json') as f:
    data = json.load(f)
print(data['choices'][0]['message']['content'][:500] if data['choices'][0]['message']['content'] else '无内容')
" 2>/dev/null || echo "解析失败")
    
    echo -e "${CYAN}[帧 #$frame_num]${NC} ${elapsed}s → ${content:0:200}..."
    return 0
}

# ---- 批量测试本地图片 ----
test_local_batch() {
    local prompt="$1"
    
    # 检查目录是否存在
    if [ ! -d "$FRAMES_DIR" ]; then
        log_error "目录不存在: $FRAMES_DIR"
        return 1
    fi
    
    # 获取图片列表
    local frames
    frames=$(find "$FRAMES_DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) | sort)
    
    if [ -z "$frames" ]; then
        log_error "未找到图片文件"
        return 1
    fi
    
    local total=0
    local success=0
    
    echo ""
    while IFS= read -r frame; do
        total=$((total + 1))
        
        # 检查是否超过限制
        if [ "$LIMIT" != "0" ] && [ $total -gt $LIMIT ]; then
            break
        fi
        
        printf "处理: %s ... " "$(basename "$frame")"
        if test_local_image "$frame" "$total" "$prompt" 2>/dev/null; then
            success=$((success + 1))
        fi
        echo ""
        
    done <<< "$frames"
    
    echo ""
    log_info "完成: $success/$total 张图片处理成功"
    
    # 保存完整结果
    if [ $success -gt 0 ]; then
        log_success "结果已保存到 /tmp/ocr_response.json"
    fi
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
    echo ""
    
    check_models
    
    if [ "$MODE" = "local" ]; then
        # 本地模式
        echo "========================================"
        echo "  本地图片批量测试"
        echo "========================================"
        echo "目录: ${FRAMES_DIR}"
        echo "提示词: Free OCR."
        echo ""
        test_local_batch "Free OCR."
    else
        # 远程模式
        local test_url="${TEST_IMAGE_URL:-https://ofasys-multimodal-wlcb-3-toshanghai.oss-accelerate.aliyuncs.com/wpf272043/keepme/image/receipt.png}"
        
        echo "========================================"
        echo "  测试 1: Free OCR"
        echo "========================================"
        test_remote "Free OCR." "$test_url" "Free OCR"
        echo ""
        
        echo "========================================"
        echo "  测试 2: Grounding Mode"
        echo "========================================"
        test_remote "<|grounding|>Convert the document to markdown." "$test_url" "Grounding"
    fi
    
    echo ""
    echo "========================================"
    echo "  ✅ 测试完成"
    echo "========================================"
}

main "$@"
