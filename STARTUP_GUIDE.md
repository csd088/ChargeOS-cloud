# ChargeOS 启动配置说明

## 📋 概述

本文档说明 ChargeOS 微服务系统的正确启动顺序和配置修复。

---

## 🔧 已修复的问题

### 1. **Sentinel 依赖冲突** ❌ → ✅

**问题**: Sentinel 在网关和服务中导致 NullPointerException

**修复**:
- 移除了 `hcp-auth/pom.xml` 中的 `spring-cloud-starter-alibaba-sentinel` 依赖
- 移除了 `hcp-operator/pom.xml` 中的 `spring-cloud-starter-alibaba-sentinel` 依赖
- 移除了 `hcp-gateway/pom.xml` 中的 `spring-cloud-starter-alibaba-sentinel` 和 `spring-cloud-alibaba-sentinel-gateway` 依赖
- 删除了 `SentinelFallbackHandler.java`
- 简化了 `GatewayConfig.java`

### 2. **服务发现和负载均衡问题** ❌ → ✅

**问题**: Feign 客户端无法通过服务名发现 hcp-system

**修复**:
- 在 `hcp-auth/HcpAuthApplication.java` 添加了 `@EnableDiscoveryClient` 注解
- 在 `hcp-auth/pom.xml` 添加了 `spring-cloud-starter-loadbalancer` 依赖
- 在 Nacos 配置中添加了:
  ```yaml
  spring.cloud.loadbalancer.nacos.enabled: true
  ```
- 在 `hcp-gateway/application.yml` 中使用 `lb://` 代替硬编码地址

### 3. **MySQL GROUP BY 错误** ❌ → ✅

**问题**: `only_full_group_by` 模式下 SQL 语法错误

**修复**:
- 修改了 `ChargingPortMapper.xml` 中的 `selectChargingPortList` 查询
- 明确列出所有 SELECT 字段，不使用 `*`
- 正确配置 GROUP BY 子句包含所有非聚合字段

### 4. **Nacos 配置中心** ✅

**关键配置**:
```yaml
spring:
  cloud:
    nacos:
      discovery:
        namespace: hcp
        server-addr: 127.0.0.1:8848
      config:
        namespace: hcp
        server-addr: 127.0.0.1:8848
  redis:
    host: 127.0.0.1
    port: 6379
    password: root
    database: 5
  datasource:
    dynamic:
      datasource:
        master:
          url: jdbc:mysql://127.0.0.1:3307/hcp_cloud_dev?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true
```

---

## 🚀 启动脚本

### 方式一：使用新版启动脚本（推荐）

```bash
./start-all-v2.sh
```

**特点**:
- 自动编译所有修改过的服务
- 按依赖顺序启动服务
- 每个服务启动后进行健康检查
- 详细的彩色输出

### 方式二：使用健康检查脚本

```bash
# 启动所有服务后，运行健康检查
./health-check.sh
```

**检查内容**:
1. 端口监听状态
2. Nacos 服务注册
3. 登录接口测试
4. 用户信息接口测试
5. 运营接口测试

---

## 📊 服务启动顺序

```
1. Docker/Nacos/MySQL/Redis 基础设施
   ↓
2. hcp-auth (端口 39200)
   ↓
3. hcp-system (端口 39201) - 无依赖
   ↓
4. hcp-gen (端口 39202) - 无依赖
   ↓
5. hcp-operator (端口 39206) - 依赖 hcp-system
   ↓
6. hcp-gateway (端口 1026) - 依赖所有服务
```

---

## 🔍 服务端口映射

| 服务 | 端口 | 说明 |
|------|------|------|
| hcp-gateway | 1026 | API 网关 |
| hcp-auth | 39200 | 认证服务 |
| hcp-system | 39201 | 系统服务 |
| hcp-operator | 39206 | 运营服务 |
| hcp-gen | 39202 | 代码生成服务 |
| Nacos | 8848 | 注册中心 |
| MySQL | 3307 | 数据库 |
| Redis | 6379 | 缓存 |

---

## 🧪 测试命令

### 登录
```bash
curl -X POST http://127.0.0.1:1026/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### 获取 Token 后的请求
```bash
# 设置 Token
TOKEN="your_token_here"

# 获取用户信息
curl -X GET http://127.0.0.1:1026/system/user/getInfo \
  -H "Authorization: Bearer $TOKEN"

# 充电端口列表
curl -X GET "http://127.0.0.1:1026/operator/port/list?stationId=68&pageNum=1&pageSize=10" \
  -H "Authorization: Bearer $TOKEN"

# 充电统计
curl -X POST http://127.0.0.1:1026/operator/total/getChargeTotal \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"pageNum":1,"pageSize":10}'
```

---

## ⚠️ 常见问题

### 1. 服务启动后立即停止

**原因**: 端口被占用或配置错误

**解决**:
```bash
# 检查端口占用
lsof -i :1026

# 杀死占用进程
kill -9 <PID>
```

### 2. Nacos 服务未注册

**原因**: Nacos 未启动或网络问题

**解决**:
```bash
# 重启 Nacos
docker restart hcp-nacos

# 检查 Nacos 日志
docker logs hcp-nacos
```

### 3. 数据库连接失败

**原因**: MySQL 未启动或配置错误

**解决**:
```bash
# 检查 MySQL
docker ps | grep mysql

# 检查端口
lsof -i :3307
```

### 4. 登录 Token 获取失败

**原因**: Redis 未启动或 hcp-auth 未正确注册

**解决**:
```bash
# 检查 Redis
redis-cli ping

# 检查 hcp-auth 日志
tail -100 logs/hcp-auth.log
```

---

## 📝 修改的文件清单

### Java 文件
- `hcp-auth/src/main/java/com/hcp/auth/HcpAuthApplication.java` - 添加 @EnableDiscoveryClient

### 配置文件
- `hcp-auth/pom.xml` - 添加 loadbalancer，移除 sentinel
- `hcp-operator/pom.xml` - 移除 sentinel
- `hcp-gateway/pom.xml` - 移除 sentinel
- `hcp-gateway/src/main/java/com/hcp/gateway/config/GatewayConfig.java` - 移除 sentinel 配置
- `hcp-gateway/src/main/resources/application.yml` - 使用 lb:// 路由
- `hcp-modules/hcp-operator/src/main/resources/mapper/operator/ChargingPortMapper.xml` - 修复 GROUP BY

### 新增文件
- `start-all-v2.sh` - 新版启动脚本
- `health-check.sh` - 健康检查脚本

---

## 🔄 未来启动注意事项

1. **每次修改代码后**: 运行 `./start-all-v2.sh` 会自动编译
2. **仅重启服务**: 直接杀死进程后用 `mvn spring-boot:run` 启动
3. **完全重新启动**: 推荐使用 `./start-all-v2.sh`
4. **检查服务状态**: 运行 `./health-check.sh`

---

## 📞 快速诊断流程

```bash
# 1. 检查基础设施
docker ps  # Nacos, MySQL, Redis

# 2. 检查端口
lsof -i :8848  # Nacos
lsof -i :3307  # MySQL
lsof -i :6379  # Redis

# 3. 检查服务
lsof -i :1026,39200,39201,39206

# 4. 运行健康检查
./health-check.sh
```