# Minecraft 抗攻擊 Proxy 設置

這個專案提供了一個自動化腳本，用於快速設置 Minecraft 伺服器的抗 DDoS 代理。
透過使用 HAProxy 作為前端代理，可以有效保護您的 Minecraft 伺服器免受直接攻擊，同時保留玩家的真實 IP 地址。

## 功能特點

- ✅ **隱藏真實伺服器 IP**：防止直接針對您的 Minecraft 伺服器進行攻擊
- ✅ **抵擋 DDoS 攻擊**：利用高性能 VPS 和 HAProxy 緩解攻擊流量
- ✅ **保留玩家真實 IP**：透過 PROXY Protocol 讓伺服器仍能看到玩家的真實 IP
- ✅ **支援多系統**：兼容 Ubuntu 和 Debian 系統
- ✅ **簡易安裝**：全自動化安裝流程，無需手動配置

## 系統架構

```
+-------------+    +----------------+    +---------+    +---------------+    +-----------------+
|             |    |                |    |         |    |               |    |                 |
|  Player A   |    | TCP connection |    | OVH VPS |    | PROXY Protocol|    | BungeeCord/Paper|
|             |    |                |    |         |    |               |    |                 |
+-------------+    +----------------+    +---------+    +---------------+    +-----------------+
```

## 需求

- 一台高性能 VPS 主機（例如 OVH、Vultr、DigitalOcean 等）
- 一台運行 BungeeCord 或 Paper 的 Minecraft 伺服器
- Ubuntu 或 Debian 操作系統

## 快速安裝

### 方法 1：直接從 GitHub 運行

```bash
bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/minecraft-proxy/main/minecraft-proxy-setup.sh)
```

### 方法 2：下載後運行

1. 下載腳本

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/minecraft-proxy/main/minecraft-proxy-setup.sh
```

2. 添加執行權限

```bash
chmod +x minecraft-proxy-setup.sh
```

3. 以 root 權限運行腳本

```bash
sudo ./minecraft-proxy-setup.sh
```

## 安裝指南

1. 運行腳本後，系統會自動檢測您的操作系統
2. 輸入以下信息：
   - 代理伺服器的端口（默認：25565）
   - BungeeCord/Paper 伺服器的 IP 地址
   - BungeeCord/Paper 伺服器的端口（默認：25577）
3. 腳本會自動完成以下操作：
   - 更新系統並安裝必要軟件包
   - 配置防火牆（UFW）
   - 啟用 Google BBR 網絡優化
   - 安裝和配置 HAProxy
   - 設置系統優化參數

## BungeeCord/Paper 設定

為了讓您的 BungeeCord 伺服器能夠獲取玩家的真實 IP，您需要啟用 PROXY Protocol：

1. 編輯 BungeeCord 的 `config.yml` 文件
2. 將 `proxy_protocol` 設置為 `true`

```yaml
listeners:
- query_port: 25577
  motd: '&1Proxy Server'
  tab_list: GLOBAL_PING
  query_enabled: false
  proxy_protocol: true  # 將此行設為 true
  ping_passthrough: false
  priorities:
  - lobby
  bind_local_address: true
  host: 0.0.0.0:25577
  max_players: 500
  tab_size: 60
  force_default_server: false
```

## 安全建議

- ⚠️ **保護後端伺服器**：請勿洩露您的 BungeeCord/Paper 伺服器的真實 IP 地址
- ⚠️ **定期更新**：確保您的系統和 HAProxy 保持最新狀態
- ⚠️ **監控**：使用 HAProxy 統計頁面 (`http://YOUR_IP:8404/stats`) 監控連接情況
- ⚠️ **防火牆**：確保您的後端伺服器只允許來自代理伺服器的連接

## 故障排除

如果您遇到問題，請檢查以下事項：

- 確認 HAProxy 是否正在運行：`systemctl status haproxy`
- 查看 HAProxy 日誌：`journalctl -u haproxy`
- 確認防火牆設置：`ufw status`
- 測試從代理伺服器到後端伺服器的連接：`telnet BACKEND_IP BACKEND_PORT`

## 高級配置

您可以編輯 `/etc/haproxy/haproxy.cfg` 文件進行更高級的 HAProxy 配置，例如：

- 調整連接限制
- 添加更強的 DDoS 防護規則
- 配置 SSL 終端
- 添加更多後端伺服器實現負載均衡

## 貢獻

歡迎提交 Pull Request 或創建 Issue 來改進這個專案！

## 許可證

[MIT 許可證](LICENSE)
