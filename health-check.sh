#!/bin/bash
# ================================================
# ChargeOS 服务健康检查和测试脚本
# ================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}     ChargeOS 服务健康检查和测试${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 服务列表（名称:端口）
SERVICES="hcp-auth:39200 hcp-system:39201 hcp-operator:39206 hcp-gen:39202 hcp-gateway:1026"

# 全局变量
TOKEN=""

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
# 函数：检查端口是否监听
# ================================================
check_port() {
    local port=$1
    if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ================================================
# 函数：检查服务健康状态
# ================================================
check_service_health() {
    local service_name=$1
    local port=$2

    print_msg "info" "检查 $service_name (端口: $port)..."

    if ! check_port "$port"; then
        print_msg "error" "$service_name 未监听端口 $port"
        return 1
    fi

    local response=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port/actuator/health" 2>/dev/null || echo "000")

    if [ "$response" = "200" ] || [ "$response" = "404" ]; then
        print_msg "success" "$service_name 健康检查通过 (HTTP $response)"
        return 0
    else
        print_msg "warn" "$service_name 健康检查异常 (HTTP $response)"
        return 1
    fi
}

# ================================================
# 函数：检查 Nacos 服务注册
# ================================================
check_nacos_service() {
    local service_name=$1

    print_msg "info" "检查 Nacos 注册: $service_name..."

    local response=$(curl -s "http://127.0.0.1:8848/nacos/v1/ns/instance/list?serviceName=$service_name&namespaceId=hcp" 2>/dev/null)

    if echo "$response" | grep -q '"hosts"'; then
        local instance_count=$(echo "$response" | grep -o '"ip"' | wc -l)
        if [ "$instance_count" -gt 0 ]; then
            print_msg "success" "$service_name 已注册到 Nacos"
            return 0
        fi
    fi

    print_msg "warn" "$service_name 未注册到 Nacos 或注册异常"
    return 1
}

# ================================================
# 函数：测试登录接口
# ================================================
test_login() {
    print_msg "info" "测试登录接口..."

    local response=$(curl -s -X POST "http://127.0.0.1:1026/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}' 2>/dev/null)

    if echo "$response" | grep -q '"code":200'; then
        TOKEN=$(echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$TOKEN" ]; then
            print_msg "success" "登录成功，获取到 Token"
            return 0
        fi
    fi

    print_msg "error" "登录失败: $response"
    return 1
}

# ================================================
# 函数：测试获取用户信息
# ================================================
test_get_user_info() {
    print_msg "info" "测试获取用户信息接口..."

    if [ -z "$TOKEN" ]; then
        print_msg "warn" "未获取到 Token，跳过用户信息测试"
        return 1
    fi

    local response=$(curl -s -X GET "http://127.0.0.1:1026/system/user/getInfo" \
        -H "Authorization: Bearer $TOKEN" 2>/dev/null)

    if echo "$response" | grep -q '"code":200'; then
        print_msg "success" "获取用户信息成功"
        return 0
    else
        print_msg "error" "获取用户信息失败: $response"
        return 1
    fi
}

# ================================================
# 函数：测试运营接口
# ================================================
test_operator_port_list() {
    print_msg "info" "测试运营接口 (充电端口列表)..."

    if [ -z "$TOKEN" ]; then
        print_msg "warn" "未获取到 Token，跳过运营接口测试"
        return 1
    fi

    local response=$(curl -s "http://127.0.0.1:1026/operator/port/list?stationId=68&pageNum=1&pageSize=10" \
        -H "Authorization: Bearer $TOKEN" 2>/dev/null)

    if echo "$response" | grep -q '"code":200'; then
        print_msg "success" "运营接口正常"
        return 0
    else
        print_msg "error" "运营接口异常: $response"
        return 1
    fi
}

# ================================================
# 函数：测试充电统计接口
# ================================================
test_operator_charge_total() {
    print_msg "info" "测试充电统计接口..."

    if [ -z "$TOKEN" ]; then
        print_msg "warn" "未获取到 Token，跳过统计接口测试"
        return 1
    fi

    local response=$(curl -s -X POST "http://127.0.0.1:1026/operator/total/getChargeTotal" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"pageNum":1,"pageSize":10}' 2>/dev/null)

    if echo "$response" | grep -q '"code":200'; then
        print_msg "success" "充电统计接口正常"
        return 0
    else
        print_msg "error" "充电统计接口异常: $response"
        return 1
    fi
}

# ================================================
# 主流程
# ================================================

echo -e "${BLUE}【1. 端口检查】${NC}"
echo ""

all_healthy=true

for service_entry in $SERVICES; do
    service_name=$(echo "$service_entry" | cut -d':' -f1)
    port=$(echo "$service_entry" | cut -d':' -f2)

    if ! check_port "$port"; then
        print_msg "error" "$service_name (端口: $port) 未启动"
        all_healthy=false
    else
        print_msg "success" "$service_name (端口: $port) 已启动"
    fi
done

echo ""
echo -e "${BLUE}【2. Nacos 服务注册检查】${NC}"
echo ""

for service_entry in $SERVICES; do
    service_name=$(echo "$service_entry" | cut -d':' -f1)
    check_nacos_service "$service_name" || true
done

echo ""
echo -e "${BLUE}【3. 接口测试】${NC}"
echo ""

if test_login; then
    test_get_user_info
    test_operator_port_list
    test_operator_charge_total
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}         健康检查完成${NC}"
echo -e "${BLUE}================================================${NC}"