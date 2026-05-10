#!/bin/bash
# ================================================
# ChargeOS 微服务一键停止脚本
# 使用方式: ./stop-all.sh
# ================================================

echo "================================================"
echo "          ChargeOS 微服务停止脚本"
echo "================================================"

# 服务列表配置
SERVICES=(
    "hcp-auth:39200"
    "hcp-system:39201"
    "hcp-operator:39206"
    "hcp-gen:39202"
    "hcp-gateway:1026"
)

# 基础目录
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
LOG_DIR="$BASE_DIR/logs"

echo "【停止】按顺序停止服务..."
echo ""

# 停止服务
for service in "${SERVICES[@]}"; do
    SERVICE_NAME=$(echo "$service" | cut -d':' -f1)
    PORT=$(echo "$service" | cut -d':' -f2)
    
    # 尝试从PID文件获取进程ID
    PID_FILE="$LOG_DIR/${SERVICE_NAME}.pid"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "  ⏹️  停止 $SERVICE_NAME (PID: $PID)..."
            kill -9 "$PID" 2>/dev/null
            rm -f "$PID_FILE"
            echo "     ✅ 已停止"
        else
            echo "  ⏹️  $SERVICE_NAME 进程不存在，检查端口..."
        fi
    else
        echo "  ⏹️  $SERVICE_NAME 无PID文件，检查端口..."
    fi
    
    # 额外检查端口占用并释放
    PID=$(lsof -ti:"$PORT")
    if [ -n "$PID" ]; then
        echo "     端口 $PORT 仍被占用，强制释放 (PID: $PID)..."
        kill -9 "$PID" 2>/dev/null
        sleep 1
        echo "     ✅ 端口已释放"
    fi
    
    echo ""
done

echo "================================================"
echo "            停止脚本执行完成"
echo "================================================"
echo ""
echo "【服务状态】"
for service in "${SERVICES[@]}"; do
    SERVICE_NAME=$(echo "$service" | cut -d':' -f1)
    PORT=$(echo "$service" | cut -d':' -f2)
    
    if lsof -Pi:"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "  ⚠️  $SERVICE_NAME : $PORT (仍在运行)"
    else
        echo "  ✅ $SERVICE_NAME : $PORT (已停止)"
    fi
done