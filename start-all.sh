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

# ================================================
# 函数：检查 Docker 是否运行
# ================================================
check_docker() {
    echo "【检查】Docker 状态..."
    if ! docker info >/dev/null 2>&1; then
        echo "  ❌ Docker 未运行"
        echo "  💡 请先启动 Docker Desktop"
        echo ""
        read -p "  是否已启动 Docker Desktop? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            echo "  等待 Docker 启动..."
            sleep 10
            if ! docker info >/dev/null 2>&1; then
                echo "  ❌ Docker 仍未就绪，请手动启动后重试"
                exit 1
            fi
        else
            exit 1
        fi
    fi
    echo "  ✅ Docker 运行正常"
    echo ""
}

# ================================================
# 函数：检查并启动 Nacos
# ================================================
check_nacos() {
    echo "【检查】Nacos 状态..."
    
    # 检查 Nacos 容器是否存在
    NACOS_CONTAINER=$(docker ps -a --filter "name=hcp-nacos" --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$NACOS_CONTAINER" ]; then
        echo "  ⚠️  Nacos 容器不存在，正在创建..."
        docker run -d --name hcp-nacos \
            -p 8848:8848 \
            -p 9848:9849 \
            -p 9847:9847 \
            -e MODE=standalone \
            nacos/nacos-server:2.0.3 >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo "  ✅ Nacos 容器创建成功"
        else
            echo "  ❌ Nacos 容器创建失败"
            exit 1
        fi
    else
        # 检查容器是否运行
        NACOS_STATUS=$(docker inspect --format='{{.State.Status}}' hcp-nacos 2>/dev/null)
        
        if [ "$NACOS_STATUS" != "running" ]; then
            echo "  ⚠️  Nacos 容器未运行，正在启动..."
            docker start hcp-nacos >/dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                echo "  ✅ Nacos 容器启动成功"
            else
                echo "  ❌ Nacos 容器启动失败"
                exit 1
            fi
        else
            echo "  ✅ Nacos 容器已运行"
        fi
    fi
    
    # 等待 Nacos 就绪
    echo "  等待 Nacos 服务就绪..."
    MAX_WAIT=60
    WAIT_COUNT=0
    
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        if curl -s "http://127.0.0.1:8848/nacos/v1/console/health/readiness" 2>/dev/null | grep -q "OK"; then
            echo "  ✅ Nacos 服务就绪"
            echo ""
            return 0
        fi
        
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 2))
        printf "\r  等待中... %d秒 " $WAIT_COUNT
    done
    
    echo ""
    echo "  ❌ Nacos 启动超时，请检查日志: docker logs hcp-nacos"
    exit 1
}

# ================================================
# 函数：检查 MySQL
# ================================================
check_mysql() {
    echo "【检查】MySQL 状态..."
    
    MYSQL_CONTAINER=$(docker ps --filter "name=hcp-mysql" --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$MYSQL_CONTAINER" ]; then
        echo "  ⚠️  MySQL 容器未运行"
        echo "  💡 请确保 MySQL 服务可用（端口 3307）"
    else
        echo "  ✅ MySQL 容器运行正常"
    fi
    echo ""
}

# ================================================
# 函数：检查 Redis
# ================================================
check_redis() {
    echo "【检查】Redis 状态..."
    
    REDIS_CONTAINER=$(docker ps --filter "name=redis" --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$REDIS_CONTAINER" ]; then
        # 检查本地 Redis
        if lsof -Pi :6379 -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "  ✅ Redis 运行正常（本地）"
        else
            echo "  ⚠️  Redis 未运行"
            echo "  💡 请确保 Redis 服务可用（端口 6379）"
        fi
    else
        echo "  ✅ Redis 容器运行正常"
    fi
    echo ""
}

# ================================================
# 主流程
# ================================================

# 1. 检查 Docker
check_docker

# 2. 检查 Nacos
check_nacos

# 3. 检查 MySQL
check_mysql

# 4. 检查 Redis
check_redis

# 5. 停止已占用端口的进程
echo "【清理】检查并释放已占用端口..."
for service in "${SERVICES[@]}"; do
    PORT=$(echo "$service" | cut -d':' -f2)
    PID=$(lsof -ti:"$PORT" 2>/dev/null)
    if [ -n "$PID" ]; then
        echo "  释放端口 $PORT (PID: $PID)"
        kill -9 "$PID" 2>/dev/null
        sleep 1
    fi
done

echo ""
echo "【启动】按顺序启动服务..."
echo ""

# 6. 启动服务
for service in "${SERVICES[@]}"; do
    SERVICE_NAME=$(echo "$service" | cut -d':' -f1)
    PORT=$(echo "$service" | cut -d':' -f2)
    SERVICE_DIR="$BASE_DIR/hcp-modules/$SERVICE_NAME"
    
    # 特殊路径处理
    if [ "$SERVICE_NAME" = "hcp-gateway" ]; then
        SERVICE_DIR="$BASE_DIR/hcp-gateway"
    fi
    
    if [ "$SERVICE_NAME" = "hcp-auth" ]; then
        SERVICE_DIR="$BASE_DIR/hcp-auth"
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
    sleep 10
    
    # 检查是否启动成功
    PID=$(cat "$LOG_DIR/${SERVICE_NAME}.pid" 2>/dev/null)
    if kill -0 "$PID" 2>/dev/null; then
        echo "     ✅ 启动成功 (PID: $PID)"
    else
        echo "     ❌ 启动失败，请查看日志: $LOG_FILE"
        echo ""
        echo "     最近日志:"
        tail -20 "$LOG_FILE" | sed 's/^/     /'
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
        PID=$(lsof -ti:"$PORT")
        echo "  ✅ $SERVICE_NAME : $PORT (PID: $PID)"
    else
        echo "  ❌ $SERVICE_NAME : $PORT (未启动)"
    fi
done

echo ""
echo "【日志目录】$LOG_DIR"
echo "【前端代理】http://localhost:8080/dev-api -> 网关 http://localhost:1026"
echo ""
echo "【Nacos 控制台】http://127.0.0.1:8848/nacos (账号: nacos / 密码: nacos)"
