#!/bin/bash
# ================================================
# ChargeOS 微服务一键启动脚本
# 使用方式: ./start-all.sh
# ================================================

echo "================================================"
echo "          ChargeOS 微服务启动脚本"
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

# 创建日志目录
mkdir -p "$LOG_DIR"

# 停止已占用端口的进程
echo "【清理】检查并释放已占用端口..."
for service in "${SERVICES[@]}"; do
    PORT=$(echo "$service" | cut -d':' -f2)
    PID=$(lsof -ti:"$PORT")
    if [ -n "$PID" ]; then
        echo "  释放端口 $PORT (PID: $PID)"
        kill -9 "$PID" 2>/dev/null
        sleep 1
    fi
done

echo ""
echo "【启动】按顺序启动服务..."
echo ""

# 启动服务
for service in "${SERVICES[@]}"; do
    SERVICE_NAME=$(echo "$service" | cut -d':' -f1)
    PORT=$(echo "$service" | cut -d':' -f2)
    SERVICE_DIR="$BASE_DIR/hcp-modules/$SERVICE_NAME"
    
    if [ "$SERVICE_NAME" = "hcp-gateway" ]; then
        SERVICE_DIR="$BASE_DIR/hcp-gateway"
    fi
    
    if [ ! -d "$SERVICE_DIR" ]; then
        echo "  ❌ 服务目录不存在: $SERVICE_DIR"
        continue
    fi
    
    echo "  🚀 启动 $SERVICE_NAME (端口: $PORT)..."
    cd "$SERVICE_DIR"
    
    # 创建日志文件
    LOG_FILE="$LOG_DIR/${SERVICE_NAME}.log"
    
    # 使用nohup后台启动，输出到日志文件
    nohup mvn spring-boot:run -q > "$LOG_FILE" 2>&1 &
    
    # 记录PID到文件
    echo $! > "$LOG_DIR/${SERVICE_NAME}.pid"
    
    # 等待服务启动
    echo "     等待服务启动..."
    sleep 8
    
    # 检查是否启动成功
    PID=$(cat "$LOG_DIR/${SERVICE_NAME}.pid" 2>/dev/null)
    if kill -0 "$PID" 2>/dev/null; then
        echo "     ✅ 启动成功 (PID: $PID)"
    else
        echo "     ❌ 启动失败，请查看日志: $LOG_FILE"
        tail -20 "$LOG_FILE"
    fi
    
    echo ""
done

echo "================================================"
echo "            启动脚本执行完成"
echo "================================================"
echo ""
echo "【服务状态】"
for service in "${SERVICES[@]}"; do
    SERVICE_NAME=$(echo "$service" | cut -d':' -f1)
    PORT=$(echo "$service" | cut -d':' -f2)
    
    if lsof -Pi:"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "  ✅ $SERVICE_NAME : $PORT (运行中)"
    else
        echo "  ❌ $SERVICE_NAME : $PORT (未启动)"
    fi
done

echo ""
echo "【日志目录】$LOG_DIR"
echo "【前端代理】http://localhost:8080/dev-api -> 网关 http://localhost:1026"