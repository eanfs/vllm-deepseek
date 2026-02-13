import os
from modelscope import snapshot_download

def download_model(model_id, cache_dir='/root/.cache/modelscope'):
    """从 ModelScope 下载模型"""
    print(f"正在从 ModelScope 下载模型: {model_id}")
    
    model_path = snapshot_download(
        model_id,
        cache_dir=cache_dir,
        revision='master'  # 或指定版本
    )
    
    print(f"模型下载完成，路径: {model_path}")
    return model_path

if __name__ == "__main__":
    import sys
    model_id = sys.argv[1] if len(sys.argv) > 1 else "unsloth/DeepSeek-OCR-2-bf16"
    download_model(model_id)