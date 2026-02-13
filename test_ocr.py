#!/usr/bin/env python3
"""
DeepSeek-OCR vLLM 测试脚本

使用方法:
    # 使用 URL 图片测试
    python test_ocr.py

    # 使用本地图片测试
    python test_ocr.py --image /path/to/image.jpg

    # 指定提示词
    python test_ocr.py --prompt "Convert the document to markdown."

    # 指定 API 地址
    python test_ocr.py --api-base http://192.168.1.100:8000/v1

依赖:
    pip install openai
"""

import argparse
import base64
import time
import sys

from openai import OpenAI


# ============================================
# 默认配置
# ============================================
DEFAULT_API_BASE = "http://localhost:8000/v1"
DEFAULT_MODEL = "deepseek-ai/DeepSeek-OCR"
DEFAULT_PROMPT = "Free OCR."
DEFAULT_TEST_IMAGE_URL = (
    "https://ofasys-multimodal-wlcb-3-toshanghai.oss-accelerate.aliyuncs.com"
    "/wpf272043/keepme/image/receipt.png"
)


def encode_image_to_base64(image_path: str) -> str:
    """将本地图片编码为 base64 data URI"""
    import mimetypes

    mime_type, _ = mimetypes.guess_type(image_path)
    if mime_type is None:
        mime_type = "image/jpeg"

    with open(image_path, "rb") as f:
        data = base64.b64encode(f.read()).decode("utf-8")

    return f"data:{mime_type};base64,{data}"


def run_ocr(
    api_base: str,
    model: str,
    image_source: str,
    prompt: str,
    max_tokens: int = 4096,
) -> str:
    """调用 DeepSeek-OCR API 进行 OCR 识别"""
    client = OpenAI(
        api_key="EMPTY",
        base_url=api_base,
        timeout=3600,
    )

    messages = [
        {
            "role": "user",
            "content": [
                {
                    "type": "image_url",
                    "image_url": {"url": image_source},
                },
                {
                    "type": "text",
                    "text": prompt,
                },
            ],
        }
    ]

    print(f"📤 发送请求...")
    print(f"   模型: {model}")
    print(f"   提示词: {prompt}")
    print(f"   图片: {image_source[:80]}{'...' if len(image_source) > 80 else ''}")
    print()

    start = time.time()
    response = client.chat.completions.create(
        model=model,
        messages=messages,
        max_tokens=max_tokens,
        temperature=0.0,
        extra_body={
            "skip_special_tokens": False,
            "vllm_xargs": {
                "ngram_size": 30,
                "window_size": 90,
                "whitelist_token_ids": [128821, 128822],
            },
        },
    )
    elapsed = time.time() - start

    result = response.choices[0].message.content
    usage = response.usage

    print(f"✅ 响应耗时: {elapsed:.2f}s")
    if usage:
        print(f"   输入 tokens: {usage.prompt_tokens}")
        print(f"   输出 tokens: {usage.completion_tokens}")
    print(f"\n{'='*60}")
    print(f"📝 OCR 结果:")
    print(f"{'='*60}\n")
    print(result)

    return result


def main():
    parser = argparse.ArgumentParser(
        description="DeepSeek-OCR vLLM 测试工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--api-base",
        default=DEFAULT_API_BASE,
        help=f"API 地址 (默认: {DEFAULT_API_BASE})",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"模型名称 (默认: {DEFAULT_MODEL})",
    )
    parser.add_argument(
        "--image",
        default=None,
        help="本地图片路径（不指定则使用默认测试 URL 图片）",
    )
    parser.add_argument(
        "--image-url",
        default=None,
        help="远程图片 URL",
    )
    parser.add_argument(
        "--prompt",
        default=DEFAULT_PROMPT,
        help=f"OCR 提示词 (默认: {DEFAULT_PROMPT})",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=4096,
        help="最大输出 tokens (默认: 4096)",
    )

    args = parser.parse_args()

    # 确定图片来源
    if args.image:
        print(f"📁 使用本地图片: {args.image}")
        image_source = encode_image_to_base64(args.image)
    elif args.image_url:
        image_source = args.image_url
    else:
        print(f"🌐 使用默认测试图片 URL")
        image_source = DEFAULT_TEST_IMAGE_URL

    try:
        run_ocr(
            api_base=args.api_base,
            model=args.model,
            image_source=image_source,
            prompt=args.prompt,
            max_tokens=args.max_tokens,
        )
    except Exception as e:
        print(f"\n❌ 错误: {e}", file=sys.stderr)
        print(f"\n💡 请确认:", file=sys.stderr)
        print(f"   1. vLLM 服务已启动: docker compose up -d", file=sys.stderr)
        print(f"   2. 模型加载完成: docker compose logs -f", file=sys.stderr)
        print(f"   3. API 地址正确: {args.api_base}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
