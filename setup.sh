#!/bin/bash

# Minecraft 抗攻擊 Proxy 安裝腳本
# 適用於 Ubuntu 和 Debian 系統
# 作用：隱藏 Minecraft 伺服器真實 IP、抵擋 DDoS 攻擊、保留玩家真實 IP

# 設置顏色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查是否為 root 用戶
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}請使用 root 權限運行此腳本 (sudo ./minecraft-proxy-setup.sh)${NC}"
  exit 1
fi

# 顯示歡迎信息
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}    Minecraft 伺服器抗攻擊 Proxy 安裝腳本${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${BLUE}此腳本將幫助您設置一個 HAProxy 作為 Minecraft 伺服器的前端代理${NC}"
echo -e "${BLUE}可以隱藏真實 IP 並抵擋 DDoS 攻擊${NC}"
echo ""

# 檢測系統類型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
    echo -e "${YELLOW}檢測到系統: $OS $VERSION${NC}"
else
    echo -e "${RED}無法檢測到操作系統類型，請確保您使用的是 Ubuntu 或 Debian${NC}"
    exit 1
fi

# 檢查是否為 Ubuntu 或 Debian
if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    echo -e "${RED}此腳本僅支援 Ubuntu 和 Debian 系統${NC}"
    exit 1
fi

# 安裝必要的軟件包
echo -e "${YELLOW}正在更新系統並安裝必要的軟件包...${NC}"
apt update -y
apt install -y sudo curl ufw net-tools

# 獲取當前 IP 地址
INSTANCE_IPV4=$(curl -4fsSL ip.denpa.io || curl -4fsSL ifconfig.me || curl -4fsSL ipinfo.io/ip)
if [ -z "$INSTANCE_IPV4" ]; then
    echo -e "${RED}無法獲取當前主機的 IP 地址，請檢查網絡連接${NC}"
    exit 1
fi
echo -e "${GREEN}當前主機 IP: $INSTANCE_IPV4${NC}"

# 設置變數
echo -e "${YELLOW}設置代理配置...${NC}"
read -p "請輸入要在此主機上開放的 Minecraft 端口 [預設: 25565]: " EXPOSED_PORT
EXPOSED_PORT=${EXPOSED_PORT:-25565}

read -p "請輸入 BungeeCord/Paper 伺服器的 IP 地址: " BACKEND_IP
while [ -z "$BACKEND_IP" ]; do
    echo -e "${RED}伺服器 IP 不能為空${NC}"
    read -p "請輸入 BungeeCord/Paper 伺服器的 IP 地址: " BACKEND_IP
done

read -p "請輸入 BungeeCord/Paper 伺服器的端口 [預設: 25577]: " BACKEND_PORT
BACKEND_PORT=${BACKEND_PORT:-25577}

BACKEND_HOST="${BACKEND_IP}:${BACKEND_PORT}"
echo -e "${GREEN}設置完成:${NC}"
echo -e "- 此主機端口: ${EXPOSED_PORT}"
echo -e "- 後端伺服器: ${BACKEND_HOST}"

# 配置防火牆
echo -e "${YELLOW}配置防火牆...${NC}"
ufw allow ssh
ufw allow $EXPOSED_PORT
ufw allow 8404
echo "y" | ufw enable 2>/dev/null || echo -e "${YELLOW}UFW 可能已啟用或不可用${NC}"
echo -e "${GREEN}防火牆已配置${NC}"

# 啟用 BBR
echo -e "${YELLOW}正在啟用 Google BBR 優化網絡...${NC}"
cat > /etc/sysctl.d/99-bbr.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl --system

# 確認 BBR 啟用
if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
    echo -e "${GREEN}Google BBR 已成功啟用${NC}"
else
    echo -e "${YELLOW}無法啟用 Google BBR，但這不影響代理功能${NC}"
fi

# 安裝 HAProxy
echo -e "${YELLOW}正在安裝與配置 HAProxy...${NC}"
apt install -y haproxy

# 配置 HAProxy - 修正後的配置
cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # 預設參數
    maxconn 65536
    tune.ssl.default-dh-param 2048

defaults
    log     global
    mode    tcp
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend minecraft
    bind *:${EXPOSED_PORT}
    default_backend minecraft_backend
    
    # 基本 DDoS 防護 - 修正後的配置
    stick-table type ip size 100k expire 30s store conn_rate(3s)
    tcp-request connection reject if { src_conn_rate gt 10 }
    tcp-request connection track-sc0 src

backend minecraft_backend
    server minecraft ${BACKEND_HOST} send-proxy
    
# 統計頁面 - 修正後的配置
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
EOF

# 優化系統限制
cat > /etc/security/limits.d/haproxy.conf << EOF
*               soft    nofile          65535
*               hard    nofile          65535
EOF

# 重啟 HAProxy
systemctl restart haproxy
systemctl enable haproxy

# 檢查 HAProxy 是否正常運行
if systemctl is-active --quiet haproxy; then
    echo -e "${GREEN}HAProxy 已成功安裝並啟動${NC}"
else
    echo -e "${RED}HAProxy 安裝失敗，請檢查錯誤信息${NC}"
    echo -e "${YELLOW}執行以下命令查看詳細錯誤：${NC}"
    echo -e "${YELLOW}systemctl status haproxy${NC}"
    echo -e "${YELLOW}haproxy -c -f /etc/haproxy/haproxy.cfg${NC}"
    exit 1
fi

# 提醒用戶設置 BungeeCord
echo -e "${YELLOW}重要提醒：${NC}"
echo -e "1. 請確保您的 BungeeCord/Paper 伺服器已啟用 PROXY Protocol:"
echo -e "   在 BungeeCord 的 config.yml 中設置 proxy_protocol: true"
echo -e ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}安裝完成!${NC}"
echo -e "${GREEN}您現在可以使用 ${INSTANCE_IPV4}:${EXPOSED_PORT} 連接到您的 Minecraft 伺服器${NC}"
echo -e "${GREEN}HAProxy 統計頁面: http://${INSTANCE_IPV4}:8404/stats${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "${YELLOW}請務必保護好您的後端伺服器 IP (${BACKEND_HOST})，避免被直接攻擊${NC}"

# 顯示系統狀態
echo -e "${BLUE}系統狀態:${NC}"
echo -e "HAProxy 狀態: $(systemctl is-active haproxy)"
echo -e "防火牆狀態: $(systemctl is-active ufw 2>/dev/null || echo '未啟用')"
echo -e "開放端口: ${EXPOSED_PORT} (Minecraft), 22 (SSH), 8404 (HAProxy 統計)"