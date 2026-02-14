import os
import sys
from modelscope import snapshot_download

def download_model(model_id, cache_dir='/root/.cache/modelscope'):
    """从 ModelScope 下载模型"""
    model_path = f"{cache_dir}/{model_id}"
    
    # 检查模型是否已存在
    if os.path.exists(model_path):
        print(f"模型已存在: {model_path}")
        return model_path
    
    print(f"正在从 ModelScope 下载模型: {model_id}")
    
    try:
        downloaded_path = snapshot_download(
            model_id,
            cache_dir=cache_dir,
            revision='master'
        )
        print(f"✓ 模型下载完成，路径: {downloaded_path}")
        return downloaded_path
    except Exception as e:
        print(f"✗ ModelScope 下载失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # 支持的模型
    models = {
        'deepseek-ocr': 'deepseek-ai/DeepSeek-OCR',
        'step3p5-flash': 'stepfun-ai/Step-3.5-Flash',
        'step3p5-flash-fp8': 'stepfun-ai/Step-3.5-Flash-FP8',
    }
    
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg in models:
            model_id = models[arg]
        else:
            model_id = sys.argv[1]
    else:
        model_id = models['deepseek-ocr']
        print(f"未指定模型，使用默认: {model_id}")
    
    print(f"支持的模型: {', '.join(models.keys())}")
    print(f"用法: python download_model.py <model_name>")
    print(f"     python download_model.py deepseek-ocr")
    print(f"     python download_model.py step3p5-flash")
    print()
    
    cache_dir = os.environ.get('MODELSCOPE_CACHE', '/models')
    download_model(model_id, cache_dir)