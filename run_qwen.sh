#!/bin/bash

# ============================================
# Qwen2.5 7B 启动脚本 (AMD Radeon 780M)
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 环境变量
export HSA_OVERRIDE_GFX_VERSION="11.0.2"
export OLLAMA_IGPU_ENABLE=1
export OLLAMA_VULKAN=1
export OLLAMA_HOST="http://127.0.0.1:11434"

# 模型名称
MODEL="qwen2.5:7b"
OLLAMA_PID=""
LLAMA_PID=""

# 清理函数：退出时关闭所有子进程
cleanup() {
    echo -e "\n${YELLOW}正在关闭 Ollama 服务...${NC}"
    
    # 关闭通过 ollama serve 启动的进程
    if [ ! -z "$OLLAMA_PID" ] && kill -0 "$OLLAMA_PID" 2>/dev/null; then
        kill -TERM "$OLLAMA_PID" 2>/dev/null
        wait "$OLLAMA_PID" 2>/dev/null
    fi
    
    # 关闭 llama-server 子进程
    pkill -f "llama-server" 2>/dev/null
    pkill -f "ollama_llama_server" 2>/dev/null
    
    echo -e "${GREEN}✓ 已关闭所有 Ollama 相关进程${NC}"
    exit 0
}

# 捕获 Ctrl+C 和退出信号
trap cleanup SIGINT SIGTERM EXIT

# 打印标题
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  启动 Qwen2.5 7B 模型 (AMD Radeon 780M)${NC}"
echo -e "${BLUE}============================================${NC}"

# 检查 Ollama 是否已安装
if ! command -v ollama &> /dev/null; then
    echo -e "${RED}错误: 未找到 ollama 命令，请先安装 Ollama${NC}"
    exit 1
fi

# 检查端口是否被占用
if lsof -i :11434 > /dev/null 2>&1; then
    echo -e "${YELLOW}警告: 端口 11434 已被占用，正在尝试关闭已有服务...${NC}"
    pkill -f "ollama serve" 2>/dev/null
    pkill -f "ollama_llama_server" 2>/dev/null
    sleep 2
fi

# 启动 Ollama 服务 (后台运行)
echo -e "${GREEN}正在启动 Ollama 服务...${NC}"
ollama serve &
OLLAMA_PID=$!

# 等待服务启动
echo -e "${YELLOW}等待 Ollama 服务就绪...${NC}"
sleep 3

# 检查服务是否启动成功
if ! curl -s "http://127.0.0.1:11434" > /dev/null 2>&1; then
    echo -e "${RED}错误: Ollama 服务启动失败${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Ollama 服务已启动 (PID: $OLLAMA_PID)${NC}"

# 检查模型是否已下载
echo -e "${YELLOW}检查模型 $MODEL 是否存在...${NC}"
if ! ollama list | grep -q "$MODEL"; then
    echo -e "${YELLOW}模型未找到，正在下载 $MODEL ... (约 4.7GB)${NC}"
    ollama pull "$MODEL"
else
    echo -e "${GREEN}✓ 模型 $MODEL 已存在${NC}"
fi

# 加载模型并进入交互模式
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✓ 一切就绪，正在加载模型...${NC}"
echo -e "${YELLOW}提示: 按 Ctrl+C 可同时关闭服务和模型${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# 运行模型 (前台运行，这样 Ctrl+C 会触发 cleanup)
ollama run "$MODEL"

# 如果 ollama run 退出（正常或异常），cleanup 会被触发