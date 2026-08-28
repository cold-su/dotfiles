DIR=${${(%):-%x}:A:h}
source $DIR/omz/omz.zsh

# Ollama 环境变量
export OLLAMA_VULKAN=1
export HSA_OVERRIDE_GFX_VERSION="11.0.2"
export OLLAMA_IGPU_ENABLE=1
export OLLAMA_MAX_VRAM=6442450944   # 约 6GB
export OLLAMA_CONTEXT_LENGTH=1024