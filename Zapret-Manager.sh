#!/bin/sh
# ==========================================
# Zapret on OpenWrt Manager by StressOzz
# Версия: 9.3 (исправленная)
# ==========================================
# shellcheck disable=SC2034,SC2155,SC2086,SC2046,SC2016

# === КОНФИГУРАЦИЯ БЕЗОПАСНОСТИ ===
set -eu  # Выход при ошибке, необъявленных переменных
# Примечание: pipefail не поддерживается в POSIX sh, используем явные проверки

# === ОБРАБОТКА СИГНАЛОВ ===
cleanup() {
    [ -n "${TMP_SF:-}" ] && [ -d "$TMP_SF" ] && rm -rf "$TMP_SF" 2>/dev/null || true
    exit "${1:-0}"
}
trap 'cleanup 130' INT TERM
trap 'cleanup 143' QUIT

# === ВЕРСИИ И ПУТИ ===
ZAPRET_MANAGER_VERSION="9.3"
STR_VERSION_AUTOINSTALL="v7"
ZAPRET_VERSION="72.20260307"
TEST_HOST="https://rr1---sn-gvnuxaxjvh-jx3z.googlevideo.com"

# === ЦВЕТОВОЙ ВЫВОД (безопасный) ===
if [ -t 1 ]; then
    GREEN='\033[1;32m' RED='\033[1;31m' CYAN='\033[1;36m'
    YELLOW='\033[1;33m' MAGENTA='\033[1;35m' BLUE='\033[0;34m'
    NC='\033[0m' DGRAY='\033[38;5;244m'
else
    GREEN='' RED='' CYAN='' YELLOW='' MAGENTA='' BLUE='' NC='' DGRAY=''
fi

# === ПУТИ (с проверкой) ===
BIN_PATH="/usr/bin/tg-ws-proxy-go"
INIT_PATH="/etc/init.d/tg-ws-proxy-go"
CONF="/etc/config/zapret"
CUSTOM_DIR="/opt/zapret/init.d/openwrt/custom.d/"
HOSTLIST_FILE="/opt/zapret/ipset/zapret-hosts-user.txt"
TMP_SF="/tmp/zapret_temp_$$"  # Уникальный каталог для процесса

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
log_info() { printf "%b%s%b\n" "${CYAN}" "$*" "${NC}" >&2; }
log_error() { printf "%b[ОШИБКА] %s%b\n" "${RED}" "$*" "${NC}" >&2; }
log_success() { printf "%b[OK] %s%b\n" "${GREEN}" "$*" "${NC}" >&2; }

# Безопасное чтение с валидацией
read_safe() {
    local var="$1" prompt="${2:-}" default="${3:-}"
    printf "%s" "$prompt" >&2
    IFS= read -r input || return 1
    if [ -z "$input" ] && [ -n "$default" ]; then
        printf -v "$var" '%s' "$default"
    else
        printf -v "$var" '%s' "$input"
    fi
}

# Проверка переменной окружения
require_env() {
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            log_error "Требуется переменная окружения: $var"
            return 1
        fi
    done
}

# Безопасное скачивание с проверкой
safe_wget() {
    local url="$1" output="$2" timeout="${3:-30}"
    if ! wget -q --https-only --timeout="$timeout" -U "Mozilla/5.0 (OpenWrt)" \
         -O "$output" "$url" 2>/dev/null; then
        log_error "Не удалось скачать: $url"
        return 1
    fi
    # Проверка: файл не пустой
    if [ ! -s "$output" ]; then
        log_error "Скачанный файл пуст: $output"
        rm -f "$output" 2>/dev/null
        return 1
    fi
    return 0
}

# Инициализация временной директории
init_temp() {
    mkdir -p "$TMP_SF" || { log_error "Не удалось создать $TMP_SF"; return 1; }
    chmod 700 "$TMP_SF" || true
}

# === ОСНОВНЫЕ ПЕРЕМЕННЫЕ (после инициализации) ===
LAN_IP="$(uci get network.lan.ipaddr 2>/dev/null | cut -d/ -f1 || echo '192.168.1.1')"
STR_URL="https://raw.githubusercontent.com/StressOzz/Zapret-Manager/refs/heads/main/ListStrYou"
EXCLUDE_URL="https://raw.githubusercontent.com/StressOzz/Zapret-Manager/refs/heads/main/zapret-hosts-user-exclude.txt"

# === ПАУЗА (безопасная) ===
pause() {
    local msg="${1:-Нажмите Enter...}"
    printf "%s" "$msg" >&2
    IFS= read -r _ || true
}

# === РЕЗЕРВНОЕ КОПИРОВАНИЕ ===
backup_config() {
    local backup_dir="/opt/zapret_backup"
    mkdir -p "$backup_dir" || return 1
    if [ -f "$CONF" ]; then
        cp "$CONF" "${backup_dir}/zapret.conf.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
}

# === ПРОВЕРКА ПРАВ ДОСТУПА ===
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Скрипт требует прав root"
        return 1
    fi
}

# === ОПРЕДЕЛЕНИЕ ПАКЕТНОГО МЕНЕДЖЕРА ===
if command -v apk >/dev/null 2>&1; then
    CONFZ="/etc/apk/repositories.d/distfeeds.list"
    PKG_IS_APK=1
    PKGM="apk"
elif command -v opkg >/dev/null 2>&1; then
    CONFZ="/etc/opkg/distfeeds.conf"
    PKG_IS_APK=0
    PKGM="opkg"
else
    log_error "Не найден пакетный менеджер (apk/opkg)"
    exit 1
fi

# === СОЗДАНИЕ ЗАПУСКАТЕЛЯ (безопасно) ===
create_launcher() {
    local launcher="/usr/bin/zms"
    cat > "$launcher" << 'LAUNCHER_EOF'
#!/bin/sh
exec sh <(wget -q -O - --https-only https://raw.githubusercontent.com/StressOzz/Zapret-Manager/main/Zapret-Manager.sh) "$@"
LAUNCHER_EOF
    chmod +x "$launcher" 2>/dev/null || log_error "Не удалось создать $launcher"
}
create_launcher

# === ПОЛУЧЕНИЕ ВЕРСИЙ (исправлено) ===
get_versions() {
    LOCAL_ARCH=$(awk -F'"' '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release 2>/dev/null || echo "unknown")
    USED_ARCH="${LOCAL_ARCH:-unknown}"
    LATEST_URL="https://github.com/remittor/zapret-openwrt/releases/download/v${ZAPRET_VERSION}/zapret_v${ZAPRET_VERSION}_${USED_ARCH}.zip"
    
    if [ "$PKG_IS_APK" -eq 1 ]; then
        INSTALLED_VER=$(apk info -v 2>/dev/null | grep '^zapret-' | head -n1 | cut -d'-' -f2 | sed 's/-r[0-9]\+$//' || echo "")
    else
        INSTALLED_VER=$(opkg list-installed zapret 2>/dev/null | awk '{sub(/-r[0-9]+$/, "", $3); print $3}' || echo "")
    fi
    [ -z "$INSTALLED_VER" ] && INSTALLED_VER="не найдена"
    
    NFQ_RUN=$(pgrep -f nfqws 2>/dev/null | wc -l | tr -d ' ')
    NFQ_RUN=${NFQ_RUN:-0}
    NFQ_ALL=$(/etc/init.d/zapret info 2>/dev/null | grep -o 'instance[0-9]\+' | wc -l | tr -d ' ' || echo 0)
    NFQ_ALL=${NFQ_ALL:-0}
    
    if [ "$NFQ_ALL" -gt 0 ] 2>/dev/null; then
        if [ "$NFQ_RUN" -eq "$NFQ_ALL" ]; then
            NFQ_CLR="$GREEN"
        else
            NFQ_CLR="$RED"
        fi
        NFQ_STAT="${NFQ_CLR}[${NFQ_RUN}/${NFQ_ALL}]${NC}"
    fi
    
    if [ -f /etc/init.d/zapret ]; then
        if /etc/init.d/zapret status >/dev/null 2>&1; then
            ZAPRET_STATUS="${GREEN}запущен ${NFQ_STAT}${NC}"
        else
            ZAPRET_STATUS="${RED}остановлен${NC}"
        fi
    else
        ZAPRET_STATUS=""
    fi
    
    if [ "$INSTALLED_VER" = "$ZAPRET_VERSION" ]; then
        INST_COLOR=$GREEN
    else
        INST_COLOR=$RED
    fi
    INSTALLED_DISPLAY="${INSTALLED_VER:-"не найдена"}"
}

# === УСТАНОВКА ПАКЕТА (исправлено) ===
install_pkg() {
    local display_name="$1" pkg_file="$2"
    log_info "Устанавливаем $display_name"
    
    if [ "$PKG_IS_APK" -eq 1 ]; then
        if ! apk add --allow-untrusted "$pkg_file" >/dev/null 2>&1; then
            log_error "Не удалось установить $display_name"
            pause
            return 1
        fi
    else
        if ! opkg install --force-reinstall "$pkg_file" >/dev/null 2>&1; then
            log_error "Не удалось установить $display_name"
            pause
            return 1
        fi
    fi
    return 0
}

# === УСТАНОВКА ZAPRET (исправлено) ===
install_Zapret() {
    local NO_PAUSE="${1:-0}"
    
    init_temp || return 1
    get_versions
    
    if [ "$INSTALLED_VER" = "$ZAPRET_VERSION" ]; then
        log_success "Zapret уже установлен!"
        [ "$NO_PAUSE" != "1" ] && pause
        return 0
    fi
    
    [ "$NO_PAUSE" != "1" ] && echo
    log_info "Устанавливаем ZAPRET"
    
    # Остановка существующего процесса
    if [ -f /etc/init.d/zapret ]; then
        log_info "Останавливаем zapret"
        /etc/init.d/zapret stop >/dev/null 2>&1 || true
        for pid in $(pgrep -f /opt/zapret 2>/dev/null || true); do
            kill -9 "$pid" 2>/dev/null || true
        done
    fi
    
    # Обновление списков пакетов
    log_info "Обновляем список пакетов"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        if ! apk update >/dev/null 2>&1; then
            log_error "Ошибка при обновлении apk"
            pause
            return 1
        fi
    else
        if ! opkg update >/dev/null 2>&1; then
            log_error "Ошибка при обновлении opkg"
            pause
            return 1
        fi
    fi
    
    # Очистка временных файлов
    rm -rf "$TMP_SF"/* 2>/dev/null || true
    cd "$TMP_SF" || return 1
    
    FILE_NAME=$(basename "$LATEST_URL")
    
    # Установка unzip если нужно
    if ! command -v unzip >/dev/null 2>&1; then
        log_info "Устанавливаем unzip"
        if [ "$PKG_IS_APK" -eq 1 ]; then
            if ! apk add unzip >/dev/null 2>&1; then
                log_error "Не удалось установить unzip"
                pause
                return 1
            fi
        else
            if ! opkg install unzip >/dev/null 2>&1; then
                log_error "Не удалось установить unzip"
                pause
                return 1
            fi
        fi
    fi
    
    # Скачивание архива
    log_info "Скачиваем архив $FILE_NAME"
    if ! safe_wget "$LATEST_URL" "$FILE_NAME"; then
        log_error "Не удалось скачать $FILE_NAME"
        pause
        return 1
    fi
    
    # Распаковка
    log_info "Распаковываем архив"
    if ! unzip -o "$FILE_NAME" >/dev/null 2>&1; then
        log_error "Ошибка распаковки архива"
        pause
        return 1
    fi
    
    # Установка пакетов
    if [ "$PKG_IS_APK" -eq 1 ]; then
        PKG_PATH="$TMP_SF/apk"
        for PKG in "$PKG_PATH"/zapret*; do
            [ -f "$PKG" ] || continue
            echo "$PKG" | grep -q "luci" && continue
            install_pkg "$(basename "$PKG")" "$PKG" || return 1
        done
        for PKG in "$PKG_PATH"/luci*; do
            [ -f "$PKG" ] || continue
            install_pkg "$(basename "$PKG")" "$PKG" || return 1
        done
    else
        PKG_PATH="$TMP_SF"
        for PKG in "$PKG_PATH"/zapret_*.ipk; do
            [ -f "$PKG" ] || continue
            install_pkg "$(basename "$PKG")" "$PKG" || return 1
        done
        for PKG in "$PKG_PATH"/luci-app-zapret_*.ipk; do
            [ -f "$PKG" ] || continue
            install_pkg "$(basename "$PKG")" "$PKG" || return 1
        done
    fi
    
    # Очистка
    log_info "Удаляем временные файлы"
    cd / || return 1
    rm -rf "$TMP_SF" /tmp/*.ipk /tmp/*.zip /tmp/*zapret* 2>/dev/null || true
    
    log_success "Zapret установлен!"
    [ "$NO_PAUSE" != "1" ] && pause
    return 0
}

# === HOSTS: ПРОВЕРКА И ДОБАВЛЕНИЕ (исправлено) ===
hosts_enabled() {
    grep -q -E "45\.155\.204\.190|instagram\.com|rutor\.info|lib\.rus\.ec|ntc\.party|twitch\.tv|web\.telegram\.org|www\.spotify\.com|store\.supercell\.com" /etc/hosts 2>/dev/null
}

hosts_add() {
    local content="$1"
    printf "%b\n" "$content" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Экранирование для grep -F
        if ! grep -qxF "$line" /etc/hosts 2>/dev/null; then
            echo "$line" >> /etc/hosts
        fi
    done
    # Перезапуск dnsmasq с проверкой
    if [ -f /etc/init.d/dnsmasq ]; then
        /etc/init.d/dnsmasq restart >/dev/null 2>&1 || log_error "Не удалось перезапустить dnsmasq"
    fi
}

# === ПЕРЕЗАПУСК ZAPRET (исправлено) ===
ZAPRET_RESTART() {
    if [ -x /opt/zapret/sync_config.sh ]; then
        chmod +x /opt/zapret/sync_config.sh 2>/dev/null || true
        /opt/zapret/sync_config.sh >/dev/null 2>&1 || log_error "Ошибка sync_config.sh"
    fi
    if [ -x /etc/init.d/zapret ]; then
        /etc/init.d/zapret restart >/dev/null 2>&1 || log_error "Ошибка перезапуска zapret"
    fi
    sleep 1
}

# === ЗАПУСК/ОСТАНОВКА ===
start_zapret() {
    if [ -x /etc/init.d/zapret ]; then
        log_info "Запускаем Zapret"
        /etc/init.d/zapret start >/dev/null 2>&1 || log_error "Ошибка запуска"
    else
        log_error "Zapret не установлен"
    fi
}

stop_zapret() {
    if [ -x /etc/init.d/zapret ]; then
        log_info "Останавливаем Zapret"
        /etc/init.d/zapret stop >/dev/null 2>&1 || log_error "Ошибка остановки"
    fi
}

# === УДАЛЕНИЕ (исправлено) ===
uninstall_zapret() {
    local NO_PAUSE="${1:-0}"
    log_info "Удаляем Zapret"
    
    if [ -x /etc/init.d/zapret ]; then
        /etc/init.d/zapret stop >/dev/null 2>&1 || true
        /etc/init.d/zapret disable >/dev/null 2>&1 || true
    fi
    
    # Удаление пакетов
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk del zapret luci-app-zapret 2>/dev/null || true
    else
        opkg remove zapret luci-app-zapret 2>/dev/null || true
    fi
    
    # Очистка файлов
    rm -rf /opt/zapret /etc/config/zapret 2>/dev/null || true
    
    log_success "Zapret удалён"
    [ "$NO_PAUSE" != "1" ] && pause
}

# === ГЛАВНОЕ МЕНЮ (исправлено) ===
show_menu() {
    require_root || { log_error "Требуется root"; pause; return 1; }
    
    init_temp || return 1
    get_versions
    
    # Проверка конфликтов пакетов
    for pkg in byedpi youtubeUnblock; do
        if [ "$PKG_IS_APK" -eq 1 ]; then
            if apk info -e "$pkg" >/dev/null 2>&1; then
                log_error "Конфликт: установлен $pkg, Zapret может работать некорректно"
            fi
        else
            if opkg list-installed 2>/dev/null | grep -q "^$pkg "; then
                log_error "Конфликт: установлен $pkg, Zapret может работать некорректно"
            fi
        fi
    done
    
    # Проверка Flow Offloading
    if uci get firewall.@defaults[0].flow_offloading 2>/dev/null | grep -q '^1$' || \
       uci get firewall.@defaults[0].flow_offloading_hw 2>/dev/null | grep -q '^1$'; then
        if ! grep -q 'meta l4proto { tcp, udp } ct original packets ge 30 flow offload @ft;' \
               /usr/share/firewall4/templates/ruleset.uc 2>/dev/null; then
            log_error "Включён Flow Offloading! Zapret может работать некорректно. Примените FIX в системном меню."
        fi
    fi
    
    clear
    printf "╔═══════════════════════════════╗\n"
    printf "║ %bZapret Manager by StressOzz%b ║\n" "$BLUE" "$NC"
    printf "╚═══════════════════════════════╝\n"
    printf " %b%s%b\n" "$DGRAY" "v$ZAPRET_MANAGER_VERSION" "$NC"
    echo
    
    # Определение действия для Zapret
    if [ ! -f /etc/init.d/zapret ]; then
        Z_ACTION_TEXT="Установить"
        Z_ACTION_FUNC="install_Zapret"
    elif [ "$INSTALLED_VER" = "$ZAPRET_VERSION" ]; then
        Z_ACTION_TEXT="Удалить"
        Z_ACTION_FUNC="uninstall_zapret"
    else
        Z_ACTION_TEXT="Обновить"
        Z_ACTION_FUNC="install_Zapret"
    fi
    
    # Статус запуска
    if pgrep -f "/opt/zapret" >/dev/null 2>&1; then
        str_stp_zpr="Остановить"
    else
        str_stp_zpr="Запустить"
    fi
    
    # Вывод информации
    printf "%bУстановленная версия: %b%s%b\n" "$YELLOW" "$INST_COLOR" "$INSTALLED_DISPLAY" "$NC"
    [ -n "$ZAPRET_STATUS" ] && printf "%bСтатус Zapret:%b %s\n" "$YELLOW" "$NC" "$ZAPRET_STATUS"
    
    # Меню
    echo
    printf "%b1) %b%s%b Zapret\n" "$CYAN" "$GREEN" "$Z_ACTION_TEXT" "$NC"
    printf "%b2) %b%s\n" "$CYAN" "$GREEN" \
        "$([ -f "$BIN_PATH" ] && [ -f "$INIT_PATH" ] && echo "Удалить TG WS Proxy Go" || echo "Установить TG WS Proxy Go")"
    printf "%b3) %bМеню стратегий%b\n" "$CYAN" "$GREEN" "$NC"
    printf "%b4) %bМеню тестирования стратегий%b\n" "$CYAN" "$GREEN" "$NC"
    printf "%b5) %bМеню DNS over HTTPS%b\n" "$CYAN" "$GREEN" "$NC"
    printf "%b6) %bМеню настройки Discord%b\n" "$CYAN" "$GREEN" "$NC"
    printf "%b7) %bМеню управления доменами в hosts%b\n" "$CYAN" "$GREEN" "$NC"
    printf "%b8) %bУдалить → установить → настроить Zapret%b\n" "$CYAN" "$GREEN" "$NC"
    printf "%b9) %b%s Zapret%b\n" "$CYAN" "$GREEN" "$str_stp_zpr" "$NC"
    printf "%b0) %bСистемное меню%b\n" "$CYAN" "$GREEN" "$NC"
    printf "%bEnter) %bВыход%b\n" "$CYAN" "$GREEN" "$NC"
    echo
    printf "%bВыберите пункт:%b " "$YELLOW" "$NC" >&2
    
    IFS= read -r choice || choice=""
    
    case "$choice" in
        888)
            echo
            uninstall_zapret "1"
            install_Zapret "1"
            if safe_wget "https://raw.githubusercontent.com/StressOzz/Test/refs/heads/main/zapret" "$CONF"; then
                hosts_add "$ALL_BLOCKS"
                rm -f "$EXCLUDE_FILE"
                safe_wget "$EXCLUDE_URL" "$EXCLUDE_FILE" || true
                ZAPRET_RESTART
            fi
            pause
            ;;
        1) $Z_ACTION_FUNC ;;
        2) tg_GO ;;
        3) menu_str ;;
        4) TEST_menu ;;
        5) DoH_menu ;;
        6) Discord_menu ;;
        7) menu_hosts ;;
        8) zapret_key ;;
        9) 
            if pgrep -f /opt/zapret >/dev/null 2>&1; then
                stop_zapret
            else
                start_zapret
            fi
            ;;
        0) sys_menu ;;
        "") cleanup 0 ;;
        *) log_error "Неверный выбор"; pause ;;
    esac
}

# === ЗАПУСК ===
main() {
    require_root || exit 1
    init_temp || exit 1
    
    # Обработка аргументов
    case "${1:-}" in
        --help|-h)
            echo "Zapret Manager v$ZAPRET_MANAGER_VERSION"
            echo "Использование: $0 [опции]"
            echo "Опции:"
            echo "  --install    Установить Zapret"
            echo "  --uninstall  Удалить Zapret"
            echo "  --help       Показать эту справку"
            exit 0
            ;;
        --install)
            install_Zapret
            exit $?
            ;;
        --uninstall)
            uninstall_zapret
            exit $?
            ;;
    esac
    
    # Интерактивный режим
    while true; do
        show_menu || break
    done
    cleanup 0
}

# Запуск
main "$@"
