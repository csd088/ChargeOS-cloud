#!/usr/bin/env bash
# ============================================================
# 慧知充电桩平台 (hcp-cloud) 一键停止脚本
#   - 先按 PID 文件停止 (优雅 kill)
#   - 再按端口查找残留进程兜底清理
# 用法: ./bin/stop-all.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/logs"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info(){ echo -e "${GREEN}[INFO]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }

# 本项目使用的全部端口
PORTS="8848 9848 9849 38080 39200 39201 39202 39203 39204 39206 39207 39208 39100 39300"

# ---------- 1. 按 PID 文件优雅停止 ----------
echo
info "按 PID 文件停止服务..."
stopped_pids=""
if [ -d "${LOG_DIR}" ]; then
  for pf in "${LOG_DIR}"/*.pid; do
    [ -f "${pf}" ] || continue
    pid="$(cat "${pf}" 2>/dev/null)"
    name="$(basename "${pf}" .pid)"
    if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
      info "停止 ${name} (PID ${pid})"
      kill "${pid}" 2>/dev/null
      stopped_pids="${stopped_pids} ${pid}"
    fi
    rm -f "${pf}"
  done
fi

# ---------- 2. 按端口兜底清理残留 ----------
echo
info "按端口检查残留进程..."
residual=""
for port in ${PORTS}; do
  pid="$(lsof -tiTCP:${port} -sTCP:LISTEN 2>/dev/null | head -1)"
  if [ -n "${pid}" ]; then
    case " ${stopped_pids} " in
      *" ${pid} "*) ;;  # 已停止过，跳过
      *)
        warn "端口 ${port} 被 PID ${pid} 占用，停止之"
        kill "${pid}" 2>/dev/null
        residual="${residual} ${pid}"
        ;;
    esac
  fi
done

# ---------- 3. 等待退出，必要时强杀 ----------
sleep 3
all_pids="${stopped_pids}${residual}"   # 形如 " 123 456"
still=""
for pid in ${all_pids}; do
  [ -n "${pid}" ] || continue
  if kill -0 "${pid}" 2>/dev/null; then
    still="${still} ${pid}"
  fi
done
if [ -n "${still}" ]; then
  warn "以下进程未正常退出，强制终止:${still}"
  kill -9 ${still} 2>/dev/null
  sleep 1
fi

# ---------- 4. 最终确认 ----------
echo
info "最终端口检查:"
all_done=1
for port in ${PORTS}; do
  if lsof -tiTCP:${port} -sTCP:LISTEN >/dev/null 2>&1; then
    warn "  端口 ${port} 仍被占用!"
    all_done=0
  fi
done
if [ "${all_done}" -eq 1 ]; then
  info "全部服务已停止，端口已释放 ✔"
else
  err_txt="仍有端口占用，请手动检查 (lsof -iTCP -sTCP:LISTEN)"
  echo -e "${RED}[ERROR]${NC} ${err_txt}"
fi
