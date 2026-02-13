#!/usr/bin/env python3
"""
DeepSeek-OCR-2 测试脚本

使用方法:
    python test_ocr2.py
"""

import os
from openai import OpenAI

# 配置
BASE_URL = os.getenv("VLLM_API_URL", "http://localhost:8000/v1")
MODEL_NAME = os.getenv("VLLM_MODEL_NAME", "deepseek-ai/DeepSeek-OCR-2")


def test_ocr():
    client = OpenAI(api_key="EMPTY", base_url=BASE_URL, timeout=3600)

    # 示例图片 URL
    image_url = os.getenv(
        "TEST_IMAGE_URL",
        "https://ofasys-multimodal-wlcb-3-toshanghai.oss-accelerate.aliyuncs.com/wpf272043/keepme/image/receipt.png",
    )

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": image_url}},
                {"type": "text", "text": "Free OCR."},
            ],
        }
    ]

    print(f"调用模型: {MODEL_NAME}")
    print(f"API 地址: {BASE_URL}")
    print("-" * 60)

    try:
        response = client.chat.completions.create(
            model=MODEL_NAME, messages=messages, max_tokens=2048, temperature=0.0
        )

        result = response.choices[0].message.content
        print(f"✓ OCR 结果:")
        print("-" * 60)
        print(result)
        print("-" * 60)
        return result

    except Exception as e:
        print(f"✗ 调用失败: {e}")
        return None


if __name__ == "__main__":
    test_ocr()
