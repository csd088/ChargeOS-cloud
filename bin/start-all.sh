#!/usr/bin/env bash
# ============================================================
# 慧知充电桩平台 (hcp-cloud) 一键启动脚本
#   - 检查中间件 (MySQL 3307 / Redis 6379)
#   - 启动嵌入式 Nacos (hcp-register, 8848) 并等待就绪
#   - 按依赖顺序启动全部微服务
# 日志与 PID 均输出到项目根目录 logs/ 下
# 用法: ./bin/start-all.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"
mkdir -p "${LOG_DIR}"

# ---------- 基础配置 (如需调整请修改此处) ----------
MYSQL_PORT=3307          # hcp-mysql 容器映射端口
MYSQL_DB=vhcp_config     # Nacos 配置库
MYSQL_PWD=password       # MySQL root 密码
REDIS_PORT=6379
NACOS_PORT=8848

# ---------- 颜色输出 ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info(){ echo -e "${GREEN}[INFO]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){  echo -e "${RED}[ERROR]${NC} $*"; }

# ---------- 工具 ----------
port_open(){ nc -z -w 2 127.0.0.1 "$1" >/dev/null 2>&1; }

start_service() {
  local name="$1" jar_rel="$2" port="$3" xmx="$4"
  local jar="${PROJECT_ROOT}/${jar_rel}"
  if [ ! -f "${jar}" ]; then
    warn "${name}: jar 不存在 (${jar_rel})，跳过。请先执行 mvn package"
    return 1
  fi
  if port_open "${port}"; then
    warn "${name}: 端口 ${port} 已被占用，跳过"
    return 1
  fi
  info "启动 ${name} (端口 ${port})..."
  nohup java -Dfile.encoding=utf-8 -Xms256m -Xmx${xmx:-512m} \
    -jar "${jar}" > "${LOG_DIR}/${name}.log" 2>&1 &
  echo $! > "${LOG_DIR}/${name}.pid"
  sleep 1
}

# ============================================================
# 1. 环境检查
# ============================================================
command -v java >/dev/null 2>&1 || { err "未找到 java，请先安装 JDK 1.8"; exit 1; }
info "项目根目录: ${PROJECT_ROOT}"

echo
info "检查中间件..."
port_open ${MYSQL_PORT} || { err "MySQL(127.0.0.1:${MYSQL_PORT}) 未就绪，请先启动 hcp-mysql 容器"; exit 1; }
port_open ${REDIS_PORT} || { err "Redis(127.0.0.1:${REDIS_PORT}) 未就绪，请先启动 Redis"; exit 1; }
info "中间件 OK: MySQL(${MYSQL_PORT}) / Redis(${REDIS_PORT})"

# ============================================================
# 2. 启动 Nacos
# ============================================================
echo
if port_open ${NACOS_PORT}; then
  warn "Nacos(${NACOS_PORT}) 已在运行，跳过启动"
else
  info "启动 Nacos (hcp-register)..."
  MYSQL_PWD=${MYSQL_PWD} MYSQL_PORT=${MYSQL_PORT} MYSQL_DB=${MYSQL_DB} \
  nohup java -Dfile.encoding=utf-8 -Xms256m -Xmx512m \
    -jar "${PROJECT_ROOT}/hcp-register/target/hcp-register.jar" \
    > "${LOG_DIR}/hcp-register.log" 2>&1 &
  echo $! > "${LOG_DIR}/hcp-register.pid"
  # 轮询等待 Nacos 就绪 (最长 60s)
  for i in $(seq 1 60); do
    if curl -s "http://127.0.0.1:${NACOS_PORT}/nacos/v1/console/health/readiness" >/dev/null 2>&1; then
      info "Nacos 就绪 (${i}s)"
      break
    fi
    if [ "${i}" -eq 60 ]; then
      err "Nacos 启动超时，请查看 ${LOG_DIR}/hcp-register.log"
      exit 1
    fi
    sleep 1
  done
fi

# ============================================================
# 3. 启动业务服务 (依赖顺序: 基础服务在前)
# ============================================================
echo
info "启动业务服务..."

# 文件服务 (被 system 等依赖)
start_service hcp-file       hcp-modules/hcp-file/target/hcp-file.jar         39300 512m
# 网关
start_service hcp-gateway    hcp-gateway/target/hcp-gateway.jar               38080 1024m
# 认证中心
start_service hcp-auth       hcp-auth/target/hcp-auth.jar                     39200 512m
# 系统模块
start_service hcp-system     hcp-modules/hcp-system/target/hcp-system.jar     39201 512m
# 运营/核心业务
start_service hcp-operator   hcp-modules/hcp-operator/target/hcp-operator.jar 39206 512m
# 小程序端
start_service hcp-mp         hcp-modules/hcp-mp/target/hcp-mp.jar             39207 512m
# 代码生成
start_service hcp-gen        hcp-modules/hcp-gen/target/hcp-gen.jar           39202 512m
# 监控中心
start_service hcp-monitor    hcp-visual/hcp-monitor/target/hcp-monitor.jar    39100 512m
# 定时任务 (XXL-JOB)
start_service hcp-job        hcp-modules/hcp-job/target/hcp-job.jar           39204 512m
# 演示服务
start_service hcp-demo       hcp-demo/target/hcp-demo.jar                     39203 512m
# 模拟桩 (开源版缺实现类，可能启动失败，如失败可忽略)
start_service hcp-simulator  hcp-modules/hcp-simulator/target/hcp-simulator.jar 39208 512m

# ============================================================
# 4. 等待启动并汇总状态
# ============================================================
echo
info "服务启动中，等待 60s 后检查状态..."
sleep 60

echo
info "========== 服务状态汇总 =========="
for entry in \
    "hcp-register|8848" "hcp-gateway|38080" "hcp-auth|39200" \
    "hcp-system|39201" "hcp-operator|39206" "hcp-mp|39207" \
    "hcp-file|39300" "hcp-gen|39202" "hcp-monitor|39100" \
    "hcp-job|39204" "hcp-demo|39203" "hcp-simulator|39208"; do
  name="${entry%%|*}"; port="${entry##*|}"
  if port_open "${port}"; then
    echo -e "  ${GREEN}${name}  (${port})  ✔ 运行${NC}"
  else
    echo -e "  ${RED}${name}  (${port})  ✘ 未就绪${NC}"
  fi
done
echo
info "完成。Nacos 控制台: http://127.0.0.1:8848/nacos  (nacos/nacos)"
info "网关入口: http://127.0.0.1:38080"
info "停止全部服务请运行: ./bin/stop-all.sh"
