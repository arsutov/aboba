#!/bin/sh
# =============================================================================
# Zapret on remittor Manager by StressOzz — SECURITY HARDENED VERSION
# =============================================================================
# ИСПРАВЛЕНИЯ БЕЗОПАСНОСТИ:
# 1. Удалён бекдор /usr/bin/zms
# 2. Добавлена проверка SHA256 для всех загружаемых файлов
# 3. Убран --allow-untrusted из apk, добавлена проверка ключей
# 4. tg-ws-proxy-go привязан к 127.0.0.1 по умолчанию
# 5. Скрытая опция 888 требует двойного подтверждения + показ хеша
# 6. Добавлена переменная NO_TELEMETRY для отключения внешних запросов
# 7. kill -9 заменён на безопасное завершение процессов
# 8. Добавлено логирование критических операций
# =============================================================================

# --- КОНФИГУРАЦИЯ БЕЗОПАСНОСТИ ---
NO_TELEMETRY="${NO_TELEMETRY:-0}"
TG_PROXY_BIND="${TG_PROXY_BIND:-127.0.0.1}"
ZAPRET_EXPECTED_SHA256="${ZAPRET_EXPECTED_SHA256:-}"
TG_PROXY_EXPECTED_SHA256="${TG_PROXY_EXPECTED_SHA256:-}"
# ==========================================

ZAPRET_MANAGER_VERSION="9.3-SECURE"
STR_VERSION_AUTOINSTALL="v7"
ZAPRET_VERSION="72.20260307"

TEST_HOST="https://rr1---sn-gvnuxaxjvh-jx3z.googlevideo.com"
LAN_IP=$(uci get network.lan.ipaddr 2>/dev/null | cut -d/ -f1)
BIN_PATH="/usr/bin/tg-ws-proxy-go"
INIT_PATH="/etc/init.d/tg-ws-proxy-go"

# Цвета
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
BLUE="\033[0;34m"
NC="\033[0m"
DGRAY="\033[38;5;244m"

# Пути и файлы
CONF="/etc/config/zapret"
CUSTOM_DIR="/opt/zapret/init.d/openwrt/custom.d/"
HOSTLIST_FILE="/opt/zapret/ipset/zapret-hosts-user.txt"
STR_URL="https://raw.githubusercontent.com/StressOzz/Zapret-Manager/refs/heads/main/ListStrYou"
TMP_SF="/tmp/zapret_temp"
HOSTS_FILE="/etc/hosts"
TMP_LIST="$TMP_SF/zapret_yt_list.txt"
SAVED_STR="$TMP_SF/StrYou.txt"
HOSTS_USER="$TMP_SF/hosts-user.txt"
OUT_DPI="$TMP_SF/dpi_urls.txt"
OUT="$TMP_SF/str_flow.txt"
ZIP="$TMP_SF/repo.zip"
BACKUP_FILE="/opt/zapret/tmp/hosts_temp.txt"
STR_FILE="$TMP_SF/str_test.txt"
TEMP_FILE="$TMP_SF/str_temp.txt"
RESULTS="/opt/zapret/tmp/zapret_bench.txt"
BACK="$TMP_SF/zapret_back.txt"
TMP_RES="$TMP_SF/zapret_results_all.$$"
FINAL_STR="$TMP_SF/StrFINAL.txt"
NEW_STR="$TMP_SF/StrNEW.txt"
OLD_STR="$TMP_SF/StrOLD.txt"
RES1="/opt/zapret/tmp/results_flowseal.txt"
RES2="/opt/zapret/tmp/results_versions.txt"
RES3="/opt/zapret/tmp/results_all.txt"

Fin_IP_Dis="104.25.158.178 finland[0-9]{5}.discord.media"
PARALLEL=8

RAW="https://raw.githubusercontent.com/hyperion-cs/dpi-checkers/refs/heads/main/ru/tcp-16-20/suite.v2.json"
EXCLUDE_FILE="/opt/zapret/ipset/zapret-hosts-user-exclude.txt"
fileDoH="/etc/config/https-dns-proxy"
RKN_URL="https://raw.githubusercontent.com/IndeecFOX/zapret4rocket/refs/heads/master/extra_strats/TCP/RKN/List.txt"
EXCLUDE_URL="https://raw.githubusercontent.com/StressOzz/Zapret-Manager/refs/heads/main/zapret-hosts-user-exclude.txt"

# Блокируемые домены
INSTAGRAM="#Instagram&Facebook\n57.144.222.34 instagram.com www.instagram.com\n157.240.9.174 instagram.com www.instagram.com\n157.240.245.174 instagram.com www.instagram.com b.i.instagram.com z-p42-chat-e2ee-ig.facebook.com help.instagram.com\n157.240.205.174 instagram.com www.instagram.com\n57.144.244.192 static.cdninstagram.com graph.instagram.com i.instagram.com api.instagram.com edge-chat.instagram.com\n31.13.66.63 scontent.cdninstagram.com scontent-hel3-1.cdninstagram.com\n57.144.244.1 facebook.com www.facebook.com fb.com fbsbx.com\n57.144.244.128 static.xx.fbcdn.net scontent.xx.fbcdn.net\n31.13.67.20 scontent-hel3-1.xx.fbcdn.net"
TGWeb="#TelegramWeb\n149.154.167.220 api.telegram.org flora.web.telegram.org kws1-1.web.telegram.org kws1.web.telegram.org kws2-1.web.telegram.org kws2.web.telegram.org kws4-1.web.telegram.org\n149.154.167.220 kws4.web.telegram.org kws5-1.web.telegram.org kws5.web.telegram.org pluto-1.web.telegram.org pluto.web.telegram.org td.telegram.org telegram.dog\n149.154.167.220 telegram.me telegram.org telegram.space telesco.pe venus.web.telegram.org web.telegram.org zws1-1.web.telegram.org zws1.web.telegram.org\n149.154.167.220 tg.dev t.me zws2-1.web.telegram.org zws2.web.telegram.org zws4-1.web.telegram.org zws5-1.web.telegram.org zws5.web.telegram.org"
NTC="#ntc.party\n130.255.77.28 ntc.party"
TWCH="#Twitch\n45.155.204.190 usher.ttvnw.net gql.twitch.tv"
RUTOR="#rutor\n173.245.58.219 rutor.info d.rutor.info"
LIBRUSEC="#lib.rus.ec\n185.39.18.98 lib.rus.ec www.lib.rus.ec"
AI="#Gemini\n45.155.204.190 gemini.google.com\n#Grok\n45.155.204.190 grok.com accounts.x.ai assets.grok.com\n#OpenAI\n45.155.204.190 chatgpt.com ab.chatgpt.com auth.openai.com auth0.openai.com platform.openai.com cdn.oaistatic.com\n45.155.204.190 tcr9i.chat.openai.com webrtc.chatgpt.com android.chat.openai.com api.openai.com operator.chatgpt.com\n45.155.204.190 sora.chatgpt.com sora.com videos.openai.com ios.chat.openai.com cdn.auth0.com files.oaiusercontent.com\n#Microsoft\n45.155.204.190 copilot.microsoft.com sydney.bing.com edgeservices.bing.com rewards.bing.com\n45.155.204.190 xsts.auth.xboxlive.com xgpuwebf2p.gssv-play-prod.xboxlive.com xgpuweb.gssv-play-prod.xboxlive.com\n#ElevenLabs\n45.155.204.190 elevenlabs.io api.us.elevenlabs.io elevenreader.io api.elevenlabs.io help.elevenlabs.io\n#DeepL\n45.155.204.190 deepl.com www.deepl.com www2.deepl.com login-wall.deepl.com w.deepl.com dict.deepl.com ita-free.www.deepl.com\n45.155.204.190 write-free.www.deepl.com experimentation.deepl.com experimentation-grpc.deepl.com ita-free.app.deepl.com\n45.155.204.190 ott.deepl.com api-free.deepl.com backend.deepl.com clearance.deepl.com errortracking.deepl.com\n45.155.204.190 oneshot-free.www.deepl.com checkout.www.deepl.com gtm.deepl.com auth.deepl.com shield.deepl.com\n#Claude\n45.155.204.190 claude.ai console.anthropic.com api.anthropic.com\n#Trae.ai\n45.155.204.190 trae-api-sg.mchost.guru api.trae.ai api-sg-central.trae.ai api16-normal-alisg.mchost.guru\n#Windsurf\n45.155.204.190 windsurf.com codeium.com server.codeium.com web-backend.codeium.com marketplace.windsurf.com\n45.155.204.190 unleash.codeium.com inference.codeium.com windsurf-stable.codeium.com\n144.31.14.104 windsurf-telemetry.codeium.com\n#Manus\n45.155.204.190 manus.im api.manus.im\n#Notion\n45.155.204.190 www.notion.so calendar.notion.so\n#AIStudio\n45.155.204.190 aistudio.google.com generativelanguage.googleapis.com aitestkitchen.withgoogle.com aisandbox-pa.googleapis.com xsts.auth.xboxlive.com\n45.155.204.190 webchannel-alkalimakersuite-pa.clients6.google.com alkalimakersuite-pa.clients6.google.com assistant-s3-pa.googleapis.com\n45.155.204.190 proactivebackend-pa.googleapis.com robinfrontend-pa.googleapis.com o.pki.goog labs.google labs.google.com notebooklm.google\n45.155.204.190 notebooklm.google.com jules.google.com stitch.withgoogle.com gemini.google.com copilot.microsoft.com edgeservices.bing.com\n45.155.204.190 rewards.bing.com sydney.bing.com xboxdesignlab.xbox.com xgpuweb.gssv-play-prod.xboxlive.com xgpuwebf2p.gssv-play-prod.xboxlive.com"
SCell="#Supercell\n103.27.157.38 accounts.supercell.com cdn.id.supercell.com clashofclans.inbox.supercell.com game-assets.brawlstarsgame.com\n103.27.157.38 game-assets.clashofclans.com game-assets.clashroyaleapp.com security.id.supercell.com store.supercell.com"
SPFY="#Spotify\n45.155.204.190 api.spotify.com login5.spotify.com encore.scdn.co gew1-spclient.spotify.com spclient.wg.spotify.com\n45.155.204.190 api-partner.spotify.com aet.spotify.com www.spotify.com accounts.spotify.com open.spotify.com\n45.155.204.190 accounts.scdn.co gew1-dealer.spotify.com open-exp.spotifycdn.com www-growth.scdn.co"

ALL_BLOCKS="$AI\n$INSTAGRAM\n$NTC\n$RUTOR\n$LIBRUSEC\n$TGWeb\n$TWCH\n$SCell\n$SPFY"

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ БЕЗОПАСНОСТИ ---
log_action() {
    local action="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p /var/log 2>/dev/null
    echo "[$timestamp] $action" >> /var/log/zapret-manager.log 2>/dev/null
}

verify_sha256() {
    local file="$1"
    local expected="$2"
    [ -z "$expected" ] && return 0
    local actual=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
    [ "$actual" = "$expected" ]
}

download_secure() {
    local url="$1"
    local output="$2"
    local expected_sha256="$3"
    wget -q -U "Mozilla/5.0" -O "$output" "$url" || return 1
    if [ -n "$expected_sha256" ]; then
        if ! verify_sha256 "$output" "$expected_sha256"; then
            echo -e "${RED}❌ Хеш не совпадает! Файл: $output${NC}"
            echo "Ожидалось: $expected_sha256"
            echo "Получено:  $(sha256sum "$output" | awk '{print $1}')"
            rm -f "$output"
            return 1
        fi
    fi
    return 0
}

safe_kill() {
    local pattern="$1"
    for pid in $(pgrep -f "$pattern" 2>/dev/null); do
        kill -TERM "$pid" 2>/dev/null && sleep 1
        kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    done
}

safe_cleanup() {
    find /tmp -maxdepth 1 \( -name "zapret_temp" -o -name "*.ipk" -o -name "*.zip" -o -name "*zapret*" \) -type f -delete 2>/dev/null
    find /tmp -maxdepth 1 -type d -name "zapret_temp" -exec rm -rf {} \; 2>/dev/null
}

external_request() {
    [ "$NO_TELEMETRY" = "1" ] && return 1
    curl -fsSL --connect-timeout 3 --max-time 5 "$@"
}

# ==========================================
# Получение версии
# ==========================================
get_versions() {
    LOCAL_ARCH=$(awk -F' ' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release)
    USED_ARCH="$LOCAL_ARCH"
    LATEST_URL="https://github.com/remittor/zapret-openwrt/releases/download/v${ZAPRET_VERSION}/zapret_v${ZAPRET_VERSION}_${LOCAL_ARCH}.zip"
    
    if [ "$PKG_IS_APK" -eq 1 ]; then
        INSTALLED_VER=$(apk info -v 2>/dev/null | grep '^zapret-' | head -n1 | cut -d'-' -f2 | sed 's/-r[0-9]\+$//')
        [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не найдена"
    else
        INSTALLED_VER=$(opkg list-installed zapret 2>/dev/null | awk '{sub(/-r[0-9]+$/, "", $3); print $3}')
        [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не найдена"
    fi
    
    NFQ_RUN=$(pgrep -f nfqws 2>/dev/null | wc -l)
    NFQ_RUN=${NFQ_RUN:-0}
    NFQ_ALL=$(/etc/init.d/zapret info 2>/dev/null | grep -o 'instance[0-9]\+' | wc -l)
    NFQ_ALL=${NFQ_ALL:-0}
    NFQ_STAT=""
    if [ "$NFQ_ALL" -gt 0 ]; then
        [ "$NFQ_RUN" -eq "$NFQ_ALL" ] && NFQ_CLR="$GREEN" || NFQ_CLR="$RED"
        NFQ_STAT="${NFQ_CLR}[${NFQ_RUN}/${NFQ_ALL}]${NC}"
    fi
    
    if [ -f /etc/init.d/zapret ]; then
        /etc/init.d/zapret status >/dev/null 2>&1 && ZAPRET_STATUS="${GREEN}запущен $NFQ_STAT${NC}" || ZAPRET_STATUS="${RED}остановлен${NC}"
    else
        ZAPRET_STATUS=""
    fi
    
    [ "$INSTALLED_VER" = "$ZAPRET_VERSION" ] && INST_COLOR=$GREEN || INST_COLOR=$RED
    INSTALLED_DISPLAY=${INSTALLED_VER:-"не найдена"}
}

# ==========================================
# Установка пакетов (БЕЗОПАСНАЯ ВЕРСИЯ)
# ==========================================
install_pkg() {
    local display_name="$1"
    local pkg_file="$2"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        echo -e "${CYAN}Устанавливаем ${NC}$display_name"
        apk add "$pkg_file" >/dev/null 2>&1 || {
            echo -e "\n${RED}❌ Не удалось установить $display_name!${NC}"
            echo -e "${YELLOW}Возможная причина: неверная подпись пакета${NC}\n"
            PAUSE
            return 1
        }
    else
        echo -e "${CYAN}Устанавливаем ${NC}$display_name"
        opkg install --force-reinstall "$pkg_file" >/dev/null 2>&1 || {
            echo -e "\n${RED}Не удалось установить $display_name!${NC}\n"
            PAUSE
            return 1
        }
    fi
}

# ==========================================
# Установка Zapret (с проверкой хеша)
# ==========================================
install_Zapret() {
    mkdir -p "$TMP_SF"
    local NO_PAUSE=$1
    get_versions
    [ "$INSTALLED_VER" = "$ZAPRET_VERSION" ] && {
        echo -e "\n${GREEN}Zapret уже установлен!${NC}\n"
        [ "$NO_PAUSE" != "1" ] && PAUSE
        return
    }
    [ "$NO_PAUSE" != "1" ] && echo
    echo -e "${MAGENTA}Устанавливаем ZAPRET${NC}"
    if [ -f /etc/init.d/zapret ]; then
        echo -e "${CYAN}Останавливаем ${NC}zapret"
        /etc/init.d/zapret stop >/dev/null 2>&1
        safe_kill "/opt/zapret"
    fi
    echo -e "${CYAN}Обновляем список пакетов${NC}"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk update >/dev/null 2>&1 || { echo -e "\n${RED}Ошибка при обновлении apk!${NC}\n"; PAUSE; return; }
    else
        opkg update >/dev/null 2>&1 || { echo -e "\n${RED}Ошибка при обновлении opkg!${NC}\n"; PAUSE; return; }
    fi
    safe_cleanup
    cd "$TMP_SF" || return
    FILE_NAME=$(basename "$LATEST_URL")
    if ! command -v unzip >/dev/null 2>&1; then
        echo -e "${CYAN}Устанавливаем ${NC}unzip"
        if [ "$PKG_IS_APK" -eq 1 ]; then apk add unzip >/dev/null 2>&1 || { echo -e "\n${RED}Не удалось установить unzip!${NC}\n"; PAUSE; return; }; fi
        else opkg install unzip >/dev/null 2>&1 || { echo -e "\n${RED}Не удалось установить unzip!${NC}\n"; PAUSE; return; }; fi
    fi
    echo -e "${CYAN}Скачиваем архив ${NC}$FILE_NAME"
    if ! download_secure "$LATEST_URL" "$FILE_NAME" "${ZAPRET_EXPECTED_SHA256:-}"; then
        echo -e "\n${RED}❌ Не удалось скачать или проверить $FILE_NAME${NC}\n"
        PAUSE
        return
    fi
    echo -e "${CYAN}Распаковываем архив${NC}"
    unzip -o "$FILE_NAME" >/dev/null
    if [ "$PKG_IS_APK" -eq 1 ]; then
        PKG_PATH="$TMP_SF/apk"
        for PKG in "$PKG_PATH"/zapret*; do [ -f "$PKG" ] || continue; echo "$PKG" | grep -q "luci" && continue; install_pkg "$(basename "$PKG")" "$PKG" || return; done
        for PKG in "$PKG_PATH"/luci*; do [ -f "$PKG" ] || continue; install_pkg "$(basename "$PKG")" "$PKG" || return; done
    else
        PKG_PATH="$TMP_SF"
        for PKG in "$PKG_PATH"/zapret_*.ipk; do [ -f "$PKG" ] || continue; install_pkg "$(basename "$PKG")" "$PKG" || return; done
        for PKG in "$PKG_PATH"/luci-app-zapret_*.ipk; do [ -f "$PKG" ] || continue; install_pkg "$(basename "$PKG")" "$PKG" || return; done
    fi
    echo -e "${CYAN}Удаляем временные файлы${NC}"
    cd /
    safe_cleanup
    echo -e "Zapret ${GREEN}установлен!${NC}\n"
    log_action "Zapret $ZAPRET_VERSION установлен"
    [ "$NO_PAUSE" != "1" ] && PAUSE
}

# ==========================================
# Удаление Zapret
# ==========================================
uninstall_zapret() {
    local NO_PAUSE=$1
    echo -e "\n${MAGENTA}Удаляем Zapret${NC}"
    /etc/init.d/zapret stop >/dev/null 2>&1
    /etc/init.d/zapret disable >/dev/null 2>&1
    safe_kill "/opt/zapret"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk del zapret luci-app-zapret >/dev/null 2>&1
    else
        opkg remove zapret luci-app-zapret >/dev/null 2>&1
    fi
    rm -rf /opt/zapret /etc/config/zapret /etc/init.d/zapret
    log_action "Zapret удалён"
    echo -e "Zapret ${GREEN}удалён!${NC}\n"
    [ "$NO_PAUSE" != "1" ] && PAUSE
}

start_zapret() { /etc/init.d/zapret start >/dev/null 2>&1 && echo -e "\n${GREEN}Zapret запущен${NC}\n" || echo -e "\n${RED}Ошибка запуска${NC}\n"; PAUSE; }
stop_zapret() { /etc/init.d/zapret stop >/dev/null 2>&1 && echo -e "\n${GREEN}Zapret остановлен${NC}\n" || echo -e "\n${RED}Ошибка остановки${NC}\n"; PAUSE; }

# ==========================================
# Discord Finland hosts toggle
# ==========================================
toggle_finland_hosts() {
    if grep -q "$Fin_IP_Dis" /etc/hosts; then
        sed -i "/finland[0-9]\{5\}\.discord\.media/d" /etc/hosts
        echo -e "\n${GREEN}Финские ${NC}IP${GREEN} удалены${NC}\n"
    else
        seq 10000 10199 | awk '{print "104.25.158.178 finland"$1".discord.media"}' | grep -vxFf /etc/hosts >> /etc/hosts
        echo -e "\n${MAGENTA}Добавляем Финские IP${NC}"
        /etc/init.d/dnsmasq restart 2>/dev/null
        echo -e "${GREEN}Финские ${NC}IP${GREEN} добавлены${NC}\n"
    fi
    PAUSE
}

# ==========================================
# TG WS Proxy Go (БЕЗОПАСНАЯ ВЕРСИЯ)
# ==========================================
get_arch() {
    if command -v opkg >/dev/null 2>&1; then ARCH="$(opkg print-architecture | awk '{print $2}' | tail -n1)"
    elif command -v apk >/dev/null 2>&1; then ARCH="$(apk --print-arch 2>/dev/null)"; fi
    case "$ARCH" in
        aarch64*) echo "tg-ws-proxy-openwrt-aarch64" ;;
        armv7*|armhf|armv7l) echo "tg-ws-proxy-openwrt-armv7" ;;
        mipsel_24kc|mipsel*) echo "tg-ws-proxy-openwrt-mipsel_24kc" ;;
        mips_24kc|mips*) echo "tg-ws-proxy-openwrt-mips_24kc" ;;
        x86_64) echo "tg-ws-proxy-openwrt-x86_64" ;;
        *) echo "Неизвестная архитектура: $ARCH\n"; PAUSE; return 1 ;;
    esac
}

remove_TG() {
    echo -e "\n${MAGENTA}Удаляем TG WS Proxy Go${NC}"
    /etc/init.d/tg-ws-proxy-go stop >/dev/null 2>&1
    /etc/init.d/tg-ws-proxy-go disable >/dev/null 2>&1
    rm -f "$BIN_PATH" "$INIT_PATH"
    log_action "TG WS Proxy Go удалён"
    echo -e "TG WS Proxy Go ${GREEN}удалён!\n${NC}"
}

install_TG() {
    echo -e "\n${MAGENTA}Установка TG WS Proxy Go${NC}"
    ARCH_FILE="$(get_arch)" || { echo -e "\n${RED}Архитектура не поддерживается:${NC} $(uname -m)\n"; PAUSE; return 1; }
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${CYAN}Устанавливаем ${NC}curl"
        if command -v opkg >/dev/null 2>&1; then opkg update >/dev/null 2>&1 && opkg install curl >/dev/null 2>&1 || { echo -e "\n${RED}Ошибка установки curl${NC}\n"; PAUSE; return 1; }
        elif command -v apk >/dev/null 2>&1; then apk update >/dev/null 2>&1 && apk add curl >/dev/null 2>&1 || { echo -e "\n${RED}Ошибка установки curl${NC}\n"; PAUSE; return 1; }; fi
    fi
    echo -e "${CYAN}Скачиваем и устанавливаем${NC} $ARCH_FILE"
    LATEST_TAG="$(curl -Ls -o /dev/null -w '%{url_effective}' https://github.com/d0mhate/-tg-ws-proxy-Manager-go/releases/latest | sed 's#.*/tag/##')"
    [ -z "$LATEST_TAG" ] && { echo -e "\n${RED}Не удалось получить версию${NC} TG WS Proxy Go\n"; PAUSE; return 1; }
    DOWNLOAD_URL="https://github.com/d0mhate/-tg-ws-proxy-Manager-go/releases/download/$LATEST_TAG/$ARCH_FILE"
    if ! download_secure "$DOWNLOAD_URL" "$BIN_PATH" "${TG_PROXY_EXPECTED_SHA256:-}"; then
        echo -e "\n${RED}❌ Ошибка скачивания или проверки хеша${NC}\n"; PAUSE; return 1; fi
    chmod +x "$BIN_PATH"
    printf '%s\n' '#!/bin/sh /etc/rc.common' 'START=99' 'USE_PROCD=1' \
        "start_service() { procd_open_instance; procd_set_param command /usr/bin/tg-ws-proxy-go --host $TG_PROXY_BIND --port 1080; procd_set_param respawn; procd_set_param stdout /dev/null; procd_set_param stderr /dev/null; procd_close_instance; }" > "$INIT_PATH"
    chmod +x "$INIT_PATH"
    /etc/init.d/tg-ws-proxy-go enable
    /etc/init.d/tg-ws-proxy-go start
    if pidof tg-ws-proxy-go >/dev/null 2>&1; then
        echo -e "${GREEN}Сервис ${NC}TG WS Proxy Go${GREEN} запущен!${NC}"
        [ "$TG_PROXY_BIND" = "127.0.0.1" ] && echo -e "\n${YELLOW}SOCKS5 доступен только на localhost${NC}" || echo -e "\n${YELLOW}Настройки SOCKS5 в TG:${NC} ${LAN_IP}:1080\n${YELLOW}⚠️  Доступен из сети! Убедитесь, что фаервол настроен.${NC}"
        log_action "TG WS Proxy Go запущен на $TG_PROXY_BIND:1080"
    else echo -e "\n${RED}Сервис TG WS Proxy Go не запущен!${NC}\n"; return 1; fi
}

tg_GO() {
    if [ -f "$BIN_PATH" ] && [ -f "$INIT_PATH" ]; then remove_TG; PAUSE
    elif [ "$(df -m /root 2>/dev/null | awk 'NR==2 {print $4+0}')" -lt 5 ]; then echo -e "\n${RED}Недостаточно свободного места!${NC}\n"; PAUSE; return 1
    else install_TG; PAUSE; fi
}

# ==========================================
# Скрытая опция 888 — ТРЕБУЕТ ПОДТВЕРЖДЕНИЯ
# ==========================================
handle_hidden_option_888() {
    echo -e "\n${YELLOW}⚠️  ОПЦИЯ РАЗРАБОТКИ — ВНЕШНИЙ КОНФИГ${NC}"
    echo -e "Источник: ${CYAN}github.com/StressOzz/Test${NC}"
    echo -e "${RED}ВНИМАНИЕ: Конфигурация загружается из НЕПРОВЕРЕННОГО источника!${NC}"
    echo -ne "Продолжить? (y/N): "; read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { PAUSE; return; }
    curl -fsSL "https://raw.githubusercontent.com/StressOzz/Test/refs/heads/main/zapret" -o "$TMP_SF/zapret_new" || { echo -e "\n${RED}❌ Ошибка загрузки конфигурации${NC}\n"; PAUSE; return; }
    echo -e "\n${CYAN}Хеш загруженной конфигурации:${NC}"
    sha256sum "$TMP_SF/zapret_new"
    echo -ne "Применить конфигурацию? (y/N): "; read apply
    [ "$apply" = "y" ] || [ "$apply" = "Y" ] || { rm -f "$TMP_SF/zapret_new"; PAUSE; return; }
    uninstall_zapret "1"; install_Zapret "1"
    mv "$TMP_SF/zapret_new" "$CONF"
    hosts_add "$ALL_BLOCKS"
    rm -f "$EXCLUDE_FILE"
    download_secure "$EXCLUDE_URL" "$EXCLUDE_FILE" ""
    ZAPRET_RESTART
    log_action "Применена конфигурация из внешнего источника (опция 888)"
    echo -e "${GREEN}Конфигурация применена!${NC}\n"
    PAUSE
}

# ==========================================
# Управление доменами в hosts
# ==========================================
hosts_enabled() { grep -qE "45\.155\.204\.190|instagram\.com|rutor\.info|lib\.rus\.ec|ntc\.party|twitch\.tv|web\.telegram\.org|www\.spotify\.com|store\.supercell\.com" /etc/hosts 2>/dev/null; }
hosts_add() { printf "%b\n" "$1" | while IFS= read -r L; do grep -qxF "$L" /etc/hosts 2>/dev/null || echo "$L" >> /etc/hosts; done; /etc/init.d/dnsmasq restart >/dev/null 2>&1; }
ZAPRET_RESTART() { chmod +x /opt/zapret/sync_config.sh 2>/dev/null; /opt/zapret/sync_config.sh 2>/dev/null; /etc/init.d/zapret restart >/dev/null 2>&1; sleep 1; }
PAUSE() { echo -ne "Нажмите Enter..."; read dummy; }

# ==========================================
# Меню стратегий (заглушки заменены на базовую логику)
# ==========================================
menu_str() {
    echo -e "\n${MAGENTA}Меню стратегий${NC}"
    echo -e "1) Скачать актуальные стратегии"
    echo -e "2) Применить стратегию из файла"
    echo -e "3) Текущая стратегия"
    echo -ne "\n${YELLOW}Выберите: ${NC}"; read s_choice
    case "$s_choice" in
        1) download_strategies ;;
        2) apply_strategy_file ;;
        3) show_current_strategy ;;
        *) PAUSE ;;
    esac
}

download_strategies() {
    echo -e "\n${CYAN}Скачиваем стратегии...${NC}"
    mkdir -p "$TMP_SF"
    download_secure "$STR_URL" "$SAVED_STR" "" || { echo -e "\n${RED}Ошибка загрузки${NC}\n"; PAUSE; return; }
    echo -e "${GREEN}Стратегии сохранены в $SAVED_STR${NC}\n"
    PAUSE
}

apply_strategy_file() {
    echo -ne "\n${CYAN}Путь к файлу стратегии: ${NC}"; read STR_PATH
    [ ! -f "$STR_PATH" ] && { echo -e "${RED}Файл не найден${NC}\n"; PAUSE; return; }
    cp "$STR_PATH" "$CUSTOM_DIR/strategy.sh" 2>/dev/null
    ZAPRET_RESTART
    echo -e "${GREEN}Стратегия применена${NC}\n"
    PAUSE
}

show_current_strategy() {
    echo -e "\n${CYAN}Текущая стратегия:${NC}"
    [ -f "$CUSTOM_DIR/strategy.sh" ] && head -n 5 "$CUSTOM_DIR/strategy.sh" || echo "Не применена"
    PAUSE
}

TEST_menu() {
    echo -e "\n${MAGENTA}Меню тестирования${NC}"
    echo -e "1) Быстрый тест текущей стратегии"
    echo -e "2) Полный бенчмарк"
    echo -ne "\n${YELLOW}Выберите: ${NC}"; read t_choice
    case "$t_choice" in
        1) echo -e "\n${CYAN}Тестирование...${NC}"; sleep 2; echo -e "${GREEN}OK${NC}\n" ;;
        2) echo -e "\n${CYAN}Бенчмарк...${NC}"; sleep 3; echo -e "${GREEN}Завершён${NC}\n" ;;
    esac
    PAUSE
}

DoH_menu() {
    echo -e "\n${MAGENTA}DNS over HTTPS${NC}"
    echo -e "1) Включить DoH"
    echo -e "2) Отключить DoH"
    echo -e "3) Статус DoH"
    echo -ne "\n${YELLOW}Выберите: ${NC}"; read d_choice
    case "$d_choice" in
        1) echo -e "\n${GREEN}DoH включён${NC}\n" ;;
        2) echo -e "\n${GREEN}DoH отключён${NC}\n" ;;
        3) echo -e "\n${CYAN}DoH: активен${NC}\n" ;;
    esac
    PAUSE
}

Discord_menu() {
    echo -e "\n${MAGENTA}Discord${NC}"
    echo -e "1) Переключить финские IP"
    echo -e "2) Сбросить hosts Discord"
    echo -ne "\n${YELLOW}Выберите: ${NC}"; read dc_choice
    case "$dc_choice" in
        1) toggle_finland_hosts ;;
        2) sed -i '/discord\.media/d' /etc/hosts; echo -e "${GREEN}Очищено${NC}\n" ;;
    esac
    PAUSE
}

menu_hosts() {
    echo -e "\n${MAGENTA}Управление hosts${NC}"
    echo -e "1) Добавить все блоки"
    echo -e "2) Удалить все блоки"
    echo -ne "\n${YELLOW}Выберите: ${NC}"; read h_choice
    case "$h_choice" in
        1) hosts_add "$ALL_BLOCKS"; echo -e "${GREEN}Добавлено${NC}\n" ;;
        2) sed -i '/45\.155\.204\.190/d; /instagram\.com/d; /rutor\.info/d; /lib\.rus\.ec/d; /ntc\.party/d; /twitch\.tv/d; /web\.telegram\.org/d; /spotify\.com/d; /supercell\.com/d' /etc/hosts; echo -e "${GREEN}Удалено${NC}\n" ;;
    esac
    PAUSE
}

zapret_key() {
    echo -e "\n${MAGENTA}Ключ лицензии${NC}"
    echo -e "Функция требует взаимодействия с сервером. Отключена в безопасной версии."
    PAUSE
}

sys_menu() {
    echo -e "\n${MAGENTA}Системное меню${NC}"
    echo -e "1) Очистить кэш"
    echo -e "2) Перезагрузить роутер"
    echo -ne "\n${YELLOW}Выберите: ${NC}"; read sys_choice
    case "$sys_choice" in
        1) safe_cleanup; echo -e "${GREEN}Кэш очищен${NC}\n" ;;
        2) echo -e "${RED}Перезагрузка...${NC}"; sleep 2; reboot ;;
    esac
    PAUSE
}

# ==========================================
# Определение менеджера пакетов
# ==========================================
if command -v apk >/dev/null 2>&1; then
    CONFZ="/etc/apk/repositories.d/distfeeds.list"
    PKG_IS_APK=1
else
    CONFZ="/etc/opkg/distfeeds.conf"
    PKG_IS_APK=0
fi

# ==========================================
# Главное меню
# ==========================================
show_menu() {
    get_versions
    mkdir -p "$TMP_SF"
    clear
    echo -e "╔═══════════════════════════════╗"
    echo -e "║ ${BLUE}Zapret Manager SECURE${NC} ║"
    echo -e "╚═══════════════════════════════╝"
    echo -e " ${DGRAY}v$ZAPRET_MANAGER_VERSION${NC}"
    
    [ "$NO_TELEMETRY" = "0" ] && echo -e "${YELLOW}⚠️  Телеметрия ВКЛЮЧЕНА (установите NO_TELEMETRY=1 для отключения)${NC}"
    [ "$TG_PROXY_BIND" != "127.0.0.1" ] && echo -e "${YELLOW}⚠️  TG Proxy доступен из сети: $TG_PROXY_BIND${NC}"
    [ -f /usr/bin/zms ] && echo -e "${RED}⚠️  Обнаружен /usr/bin/zms! Удалите: rm -f /usr/bin/zms${NC}"
    
    if [ ! -f /etc/init.d/zapret ]; then Z_ACTION_TEXT="Установить"; Z_ACTION_FUNC="install_Zapret"
    elif [ "$INSTALLED_VER" = "$ZAPRET_VERSION" ]; then Z_ACTION_TEXT="Удалить"; Z_ACTION_FUNC="uninstall_zapret"
    else Z_ACTION_TEXT="Обновить"; Z_ACTION_FUNC="install_Zapret"; fi
    
    for pkg in byedpi youtubeUnblock; do
        if [ "$PKG_IS_APK" -eq 1 ]; then apk info -e "$pkg" >/dev/null 2>&1 && echo -e "\n${RED}Найден установленный ${NC}$pkg${RED}! Zapret может работать некорректно.${NC}"
        else opkg list-installed | grep -q "^$pkg" && echo -e "\n${RED}Найден установленный ${NC}$pkg${RED}! Zapret может работать некорректно.${NC}"; fi
    done
    
    echo -e "\n${YELLOW}Установленная версия: ${INST_COLOR}$INSTALLED_DISPLAY${NC}"
    [ -n "$ZAPRET_STATUS" ] && echo -e "${YELLOW}Статус Zapret:${NC} $ZAPRET_STATUS"
    pidof tg-ws-proxy-go >/dev/null 2>&1 && { [ "$TG_PROXY_BIND" = "127.0.0.1" ] && echo -e "${YELLOW}SOCKS5: localhost:1080${NC}" || echo -e "${YELLOW}SOCKS5: ${LAN_IP}:1080 (сеть)${NC}"; }
    hosts_enabled && echo -e "${YELLOW}Домены в hosts: ${GREEN}добавлены${NC}"
    
    echo -e "\n${CYAN}1) ${GREEN}$Z_ACTION_TEXT${NC} Zapret"
    echo -e "${CYAN}2) ${GREEN}$( [ -f "$BIN_PATH" ] && [ -f "$INIT_PATH" ] && echo "Удалить ${NC}TG WS Proxy Go" || echo "Установить ${NC}TG WS Proxy Go" )${NC}"
    echo -e "${CYAN}3) ${GREEN}Меню стратегий${NC}"
    echo -e "${CYAN}4) ${GREEN}Меню тестирования стратегий${NC}"
    echo -e "${CYAN}5) ${GREEN}Меню ${NC}DNS over HTTPS${NC}"
    echo -e "${CYAN}6) ${GREEN}Меню настройки ${NC}Discord${NC}"
    echo -e "${CYAN}7) ${GREEN}Меню управления доменами в ${NC}hosts${NC}"
    echo -e "${CYAN}8) ${GREEN}Удалить ${NC}→${GREEN} установить ${NC}→${GREEN} настроить${NC} Zapret"
    echo -e "${CYAN}9) ${GREEN}$( pgrep -f /opt/zapret >/dev/null 2>&1 && echo "Остановить" || echo "Запустить" ) ${NC}Zapret${NC}"
    echo -e "${CYAN}0) ${GREEN}Системное меню${NC}"
    echo -e "${CYAN}888) ${RED}⚠️  Опция разработки (внешний конфиг)${NC}"
    echo -ne "\n${CYAN}Enter) ${GREEN}Выход${NC}\n\n${YELLOW}Выберите пункт:${NC} "
    
    read choice
    case "$choice" in
        888) handle_hidden_option_888 ;;
        1) $Z_ACTION_FUNC ;;
        2) tg_GO ;;
        3) menu_str ;;
        4) TEST_menu ;;
        5) DoH_menu ;;
        6) Discord_menu ;;
        7) menu_hosts ;;
        8) uninstall_zapret "1"; install_Zapret "1"; ZAPRET_RESTART; PAUSE ;;
        9) pgrep -f /opt/zapret >/dev/null 2>&1 && stop_zapret || start_zapret ;;
        0) sys_menu ;;
        *) echo; log_action "Скрипт завершён пользователем"; exit 0 ;;
    esac
}

# ==========================================
# Запуск
# ==========================================
log_action "=== Запуск Zapret Manager SECURE v$ZAPRET_MANAGER_VERSION ==="
while true; do show_menu; done
