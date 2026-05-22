#!/bin/bash
# ================================================
# ChargeOS 微服务一键启动脚本（完整版）
# 版本：v2.1
# 更新内容：
#   - 修复 Sentinel 依赖问题
#   - 修复服务发现和负载均衡配置
#   - 修复 MySQL GROUP BY 错误
#   - 优化启动顺序和等待时间
#   - 修复 macOS bash 兼容性问题
# ================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}       ChargeOS 微服务启动脚本 v2.1${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 服务列表（名称:端口）
SERVICES="hcp-auth:39200 hcp-system:39201 hcp-operator:39206 hcp-gen:39202 hcp-gateway:1026"

# 基础目录
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
LOG_DIR="$BASE_DIR/logs"

# 创建日志目录
mkdir -p "$LOG_DIR"

# ================================================
# 函数：打印带颜色的消息
# ================================================
print_msg() {
    local type=$1
    local msg=$2
    case $type in
        "info") echo -e "${BLUE}[INFO]${NC} $msg" ;;
        "success") echo -e "${GREEN}[SUCCESS]${NC} $msg" ;;
        "warn") echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        "error") echo -e "${RED}[ERROR]${NC} $msg" ;;
    esac
}

# ================================================
# 函数：检查 Docker 是否运行
# ================================================
check_docker() {
    print_msg "info" "检查 Docker 状态..."
    if ! docker info >/dev/null 2>&1; then
        print_msg "error" "Docker 未运行"
        print_msg "warn" "请先启动 Docker Desktop"
        exit 1
    fi
    print_msg "success" "Docker 运行正常"
    echo ""
}

# ================================================
# 函数：检查并启动 Nacos
# ================================================
check_nacos() {
    print_msg "info" "检查 Nacos 状态..."

    NACOS_CONTAINER=$(docker ps -a --filter "name=hcp-nacos" --format "{{.Names}}" 2>/dev/null)

    if [ -z "$NACOS_CONTAINER" ]; then
        print_msg "warn" "Nacos 容器不存在，正在创建..."
        docker run -d --name hcp-nacos \
            -p 8848:8848 \
            -p 9848:9849 \
            -p 9847:9847 \
            -e MODE=standalone \
            nacos/nacos-server:2.0.3 >/dev/null 2>&1

        if [ $? -eq 0 ]; then
            print_msg "success" "Nacos 容器创建成功"
        else
            print_msg "error" "Nacos 容器创建失败"
            exit 1
        fi
    else
        NACOS_STATUS=$(docker inspect --format='{{.State.Status}}' hcp-nacos 2>/dev/null)

        if [ "$NACOS_STATUS" != "running" ]; then
            print_msg "warn" "Nacos 容器未运行，正在启动..."
            docker start hcp-nacos >/dev/null 2>&1

            if [ $? -eq 0 ]; then
                print_msg "success" "Nacos 容器启动成功"
            else
                print_msg "error" "Nacos 容器启动失败"
                exit 1
            fi
        else
            print_msg "success" "Nacos 容器已运行"
        fi
    fi

    print_msg "info" "等待 Nacos 服务就绪..."
    MAX_WAIT=90
    WAIT_COUNT=0

    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        if curl -s "http://127.0.0.1:8848/nacos/v1/console/health/readiness" 2>/dev/null | grep -q "OK"; then
            print_msg "success" "Nacos 服务就绪"
            echo ""
            return 0
        fi

        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 2))
        printf "\r  等待中... %d秒 " $WAIT_COUNT
    done

    echo ""
    print_msg "error" "Nacos 启动超时，请检查日志: docker logs hcp-nacos"
    exit 1
}

# ================================================
# 函数：检查 MySQL
# ================================================
check_mysql() {
    print_msg "info" "检查 MySQL 状态..."

    MYSQL_CONTAINER=$(docker ps --filter "name=hcp-mysql" --format "{{.Names}}" 2>/dev/null)

    if [ -z "$MYSQL_CONTAINER" ]; then
        print_msg "warn" "MySQL 容器未运行，请确保 MySQL 服务可用（端口 3307）"
    else
        print_msg "success" "MySQL 容器运行正常"
    fi
    echo ""
}

# ================================================
# 函数：检查 Redis
# ================================================
check_redis() {
    print_msg "info" "检查 Redis 状态..."

    REDIS_CONTAINER=$(docker ps --filter "name=redis" --format "{{.Names}}" 2>/dev/null)

    if [ -z "$REDIS_CONTAINER" ]; then
        if lsof -Pi :6379 -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_msg "success" "Redis 运行正常（本地）"
        else
            print_msg "warn" "Redis 未运行，请确保 Redis 服务可用（端口 6379）"
        fi
    else
        print_msg "success" "Redis 容器运行正常"
    fi
    echo ""
}

# ================================================
# 函数：停止已占用端口的进程
# ================================================
cleanup_ports() {
    print_msg "info" "清理已占用端口..."

    for service_entry in $SERVICES; do
        port=$(echo "$service_entry" | cut -d':' -f2)
        PID=$(lsof -ti:"$port" 2>/dev/null)
        if [ -n "$PID" ]; then
            print_msg "warn" "释放端口 $port (PID: $PID)"
            kill -9 "$PID" 2>/dev/null || true
            sleep 1
        fi
    done

    echo ""
}

# ================================================
# 函数：编译服务
# ================================================
compile_services() {
    print_msg "info" "编译需要更新的服务（修复依赖问题）..."
    echo ""

    SERVICES_TO_COMPILE=(
        "hcp-auth"
        "hcp-gateway"
        "hcp-modules/hcp-operator"
    )

    for service in "${SERVICES_TO_COMPILE[@]}"; do
        SERVICE_DIR="$BASE_DIR/$service"
        if [ -d "$SERVICE_DIR" ]; then
            print_msg "info" "编译 $service..."
            cd "$SERVICE_DIR"
            if mvn clean compile -q; then
                print_msg "success" "$service 编译成功"
            else
                print_msg "error" "$service 编译失败"
                exit 1
            fi
        fi
    done

    echo ""
}

# ================================================
# 函数：启动单个服务
# ================================================
start_service() {
    local service_name=$1
    local port=$2
    local service_dir=$3

    print_msg "info" "启动 $service_name (端口: $port)..."

    cd "$service_dir"

    LOG_FILE="$LOG_DIR/${service_name}.log"

    nohup mvn spring-boot:run -q > "$LOG_FILE" 2>&1 &
    local pid=$!

    echo $pid > "$LOG_DIR/${service_name}.pid"

    local max_wait=60
    local wait_count=0

    while [ $wait_count -lt $max_wait ]; do
        if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_msg "success" "$service_name 启动成功 (PID: $pid, 端口: $port)"
            return 0
        fi

        sleep 2
        wait_count=$((wait_count + 2))
    done

    print_msg "error" "$service_name 启动超时"
    print_msg "warn" "请查看日志: tail -50 $LOG_FILE"
    return 1
}

# ================================================
# 函数：等待服务完全就绪
# ================================================
wait_for_service() {
    local service_name=$1
    local port=$2

    print_msg "info" "等待 $service_name 完全就绪..."

    local max_wait=90
    local wait_count=0

    while [ $wait_count -lt $max_wait ]; do
        if curl -s "http://127.0.0.1:$port/actuator/health" 2>/dev/null | grep -q "UP"; then
            print_msg "success" "$service_name 健康检查通过"
            return 0
        fi

        sleep 3
        wait_count=$((wait_count + 3))
        printf "\r  等待中... %d秒 " $wait_count
    done

    echo ""
    print_msg "warn" "$service_name 健康检查超时，尝试直接访问..."

    if curl -s "http://127.0.0.1:$port" >/dev/null 2>&1; then
        print_msg "success" "$service_name 已响应请求"
        return 0
    fi

    print_msg "warn" "$service_name 可能未完全就绪，请手动检查"
    return 1
}

# ================================================
# 函数：显示服务状态
# ================================================
show_status() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}            服务状态汇总${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""

    all_running=true

    for service_entry in $SERVICES; do
        service_name=$(echo "$service_entry" | cut -d':' -f1)
        port=$(echo "$service_entry" | cut -d':' -f2)

        if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
            pid=$(lsof -ti :"$port")
            echo -e "  ${GREEN}✅${NC} $service_name : $port (PID: $pid)"
        else
            echo -e "  ${RED}❌${NC} $service_name : $port (未启动)"
            all_running=false
        fi
    done

    echo ""

    if $all_running; then
        print_msg "success" "所有服务启动成功！"
    else
        print_msg "warn" "部分服务未启动，请检查日志"
    fi

    echo ""
    echo -e "${BLUE}【重要配置】${NC}"
    echo "  - 网关端口: 1026"
    echo "  - API 前缀: /dev-api"
    echo "  - Nacos 控制台: http://127.0.0.1:8848/nacos (账号: nacos / 密码: nacos)"
    echo "  - 日志目录: $LOG_DIR"
    echo ""
    echo -e "${BLUE}【测试命令】${NC}"
    echo "  登录: curl -X POST http://127.0.0.1:1026/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin123\"}'"
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

# 5. 清理端口
cleanup_ports

# 6. 编译服务
compile_services

# 7. 启动服务（按依赖顺序）
print_msg "info" "按依赖顺序启动服务..."
echo ""

# 启动顺序很重要：
# 1. 先启动 hcp-auth, hcp-system, hcp-gen（无依赖）
# 2. 再启动 hcp-operator（依赖 hcp-system）
# 3. 最后启动 hcp-gateway（依赖所有服务）

start_service "hcp-auth" "39200" "$BASE_DIR/hcp-auth"
sleep 5
wait_for_service "hcp-auth" "39200"

start_service "hcp-system" "39201" "$BASE_DIR/hcp-modules/hcp-system"
sleep 5
wait_for_service "hcp-system" "39201"

start_service "hcp-gen" "39202" "$BASE_DIR/hcp-modules/hcp-gen"
sleep 5
wait_for_service "hcp-gen" "39202"

start_service "hcp-operator" "39206" "$BASE_DIR/hcp-modules/hcp-operator"
sleep 5
wait_for_service "hcp-operator" "39206"

start_service "hcp-gateway" "1026" "$BASE_DIR/hcp-gateway"
sleep 10
wait_for_service "hcp-gateway" "1026"

# 8. 显示状态
show_status

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}       启动脚本执行完成${NC}"
echo -e "${BLUE}================================================${NC}"