#!/bin/bash
# setup.sh - Полная установка HestiaCP

set -e

# ============================================
# ЦВЕТА
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
ORANGE='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================
# ФУНКЦИИ
# ============================================
print_header() {
    echo -e "${MAGENTA}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║     🚀  ${BOLD}AUTO HESTIACP SETUP${NC}${MAGENTA}                              ║"
    echo "║     ${WHITE}Полная автоматическая установка${MAGENTA}                        ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${WHITE}${BOLD}▶ $1${NC}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════════${NC}"
}

print_success() { echo -e "  ${GREEN}${BOLD}✅ $1${NC}"; }
print_error() { echo -e "  ${RED}${BOLD}❌ $1${NC}"; }
print_info() { echo -e "  ${BLUE}${BOLD}ℹ️ $1${NC}"; }
print_warning() { echo -e "  ${YELLOW}${BOLD}⚠️ $1${NC}"; }
print_domain() { echo -e "  ${MAGENTA}${BOLD}🌐 $1${NC}"; }
print_file() { echo -e "    ${GREEN}📄 $1${NC}"; }
print_ssl() { echo -e "  ${ORANGE}${BOLD}🔐 $1${NC}"; }
print_separator() { echo -e "${CYAN}────────────────────────────────────────────────────────────────────${NC}"; }

print_big_success() {
    echo -e "\n${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║     🎉  ${WHITE}ВСЕ ДОМЕНЫ УСПЕШНО НАСТРОЕНЫ!${GREEN}                      ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ============================================
# ЗАГРУЗКА КОМАНД HESTIACP
# ============================================
load_hestia_commands() {
    print_info "Загрузка команд HestiaCP..."
    export PATH="/usr/local/hestia/bin:$PATH"
    
    if [ -f /usr/local/hestia/func/main.sh ]; then
        source /usr/local/hestia/func/main.sh 2>/dev/null
    fi
    
    if command -v v-add-domain &> /dev/null; then
        print_success "Команды HestiaCP загружены"
        return 0
    else
        print_warning "Команды не загрузились, пробуем ещё раз через 5 секунд..."
        sleep 5
        source /usr/local/hestia/func/main.sh 2>/dev/null
        if command -v v-add-domain &> /dev/null; then
            print_success "Команды HestiaCP загружены"
            return 0
        else
            print_error "Не удалось загрузить команды HestiaCP!"
            print_info "Попробуйте перезагрузить сервер вручную и запустить скрипт снова"
            exit 1
        fi
    fi
}

# ============================================
# ФУНКЦИЯ ДОБАВЛЕНИЯ ДОМЕНА (без дублей)
# ============================================
add_domain_safe() {
    local user="$1"
    local domain="$2"
    
    # Проверяем, существует ли домен
    if v-list-web-domain "$user" "$domain" plain >/dev/null 2>&1; then
        print_info "Веб-домен $domain уже существует — используем его"
        return 0
    else
        # Добавляем домен (он сам создаст web, dns, mail)
        v-add-domain "$user" "$domain" 2>/dev/null
        if [ $? -eq 0 ]; then
            print_success "Домен $domain создан"
            return 0
        else
            print_error "Не удалось создать домен $domain"
            return 1
        fi
    fi
}

# ============================================
# ЕСЛИ HESTIACP УЖЕ УСТАНОВЛЕНА
# ============================================
if [ -f /usr/local/hestia/bin/hestia ]; then
    echo ""
    print_success "HestiaCP уже установлена!"
    print_info "Продолжаем настройку доменов..."
    
    load_hestia_commands
    
    # Запрашиваем данные
    echo -e "${CYAN}${BOLD}➜ Введите имя пользователя HestiaCP:${NC}"
    read -p "  " HESTIA_USER
    
    echo -e "${CYAN}${BOLD}➜ Введите список доменов (через пробел):${NC}"
    read -a DOMAINS
    
    print_info "Клонирование репозитория..."
    rm -rf /tmp/hestia-deploy
    git clone https://github.com/yukutakanawa/hestia-deploy.git /tmp/hestia-deploy 2>/dev/null
    
    for d in "${DOMAINS[@]}"; do
        echo ""
        print_separator
        print_domain "Обработка: $d"
        print_separator
        
        # БЕЗОПАСНОЕ добавление домена
        add_domain_safe "$HESTIA_USER" "$d"
        
        PUBLIC_HTML="/home/$HESTIA_USER/web/$d/public_html"
        mkdir -p "$PUBLIC_HTML"
        rm -f "$PUBLIC_HTML/index.html" "$PUBLIC_HTML/index.php" "$PUBLIC_HTML/.htaccess"
        
        echo "  📤 Загрузка файлов..."
        for f in /tmp/hestia-deploy/*; do
            filename=$(basename "$f")
            if [ "$filename" != "setup.sh" ] && [ "$filename" != "deploy.sh" ] && [ -f "$f" ]; then
                cp -f "$f" "$PUBLIC_HTML/"
                print_file "$filename"
            fi
        done
        
        chown -R "$HESTIA_USER":"$HESTIA_USER" "$PUBLIC_HTML"
        chmod 755 "$PUBLIC_HTML"
        chmod 644 "$PUBLIC_HTML/index.php" 2>/dev/null
        chmod 644 "$PUBLIC_HTML/.htaccess" 2>/dev/null
        
        print_ssl "Установка SSL..."
        if v-add-letsencrypt-domain "$HESTIA_USER" "$d" 2>/dev/null; then
            print_success "SSL сертификат установлен"
        else
            print_warning "SSL не установлен (возможно домен не направлен)"
        fi
        
        if v-add-web-domain-ssl-force "$HESTIA_USER" "$d" 2>/dev/null; then
            print_success "HTTPS редирект включён"
        else
            print_warning "HTTPS редирект не включён"
        fi
        
        print_success "$d готов"
    done
    
    systemctl restart php8.5-fpm 2>/dev/null || systemctl restart php8.4-fpm 2>/dev/null || systemctl restart php8.3-fpm 2>/dev/null
    
    print_big_success
    echo -e "${WHITE}${BOLD}🔗 ВАШИ ДОМЕНЫ:${NC}"
    for d in "${DOMAINS[@]}"; do
        echo -e "  ${GREEN}🔒 https://$d${NC}"
    done
    
    exit 0
fi

# ============================================
# НОВАЯ УСТАНОВКА
# ============================================
echo ""
print_info "HestiaCP не установлена. Начинаем установку..."
echo ""

# ============================================
# 1. ЗАПРОС ДАННЫХ
# ============================================
clear
print_header

echo -e "${YELLOW}${BOLD}Для установки HestiaCP потребуется ввести несколько параметров${NC}"
echo -e "${YELLOW}Все остальные настройки будут применены автоматически${NC}\n"

while true; do
    echo -e "${CYAN}${BOLD}➜ Введите имя пользователя для HestiaCP:${NC}"
    read -p "  " HESTIA_USER
    [ -n "$HESTIA_USER" ] && break
    print_error "Имя не может быть пустым!"
done
print_success "Имя пользователя: $HESTIA_USER"

echo ""

while true; do
    echo -e "${CYAN}${BOLD}➜ Введите пароль для администратора HestiaCP:${NC}"
    read -s HESTIA_PASSWORD
    echo
    echo -e "${CYAN}${BOLD}➜ Повторите пароль:${NC}"
    read -s HESTIA_PASSWORD_CONFIRM
    echo
    if [ "$HESTIA_PASSWORD" = "$HESTIA_PASSWORD_CONFIRM" ] && [ ${#HESTIA_PASSWORD} -ge 8 ]; then
        print_success "Пароль принят"
        break
    else
        print_error "Пароли не совпадают или меньше 8 символов!"
    fi
done

echo ""

while true; do
    echo -e "${CYAN}${BOLD}➜ Введите hostname (домен сервера):${NC}"
    read -p "  " HOSTNAME
    [[ "$HOSTNAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && break
    print_error "Некорректный домен! Пример: www.myserver.com"
done
print_success "Hostname: $HOSTNAME"

echo ""

echo -e "${CYAN}${BOLD}➜ Введите email для сертификатов (оставьте пустым для стандартного):${NC}"
read EMAIL_INPUT
EMAIL="${EMAIL_INPUT:-admin@$HOSTNAME}"
print_info "Email: $EMAIL"

echo ""

# ============================================
# 2. ВВОД ДОМЕНОВ
# ============================================
echo -e "${CYAN}${BOLD}➜ Вставьте список доменов (в любом формате):${NC}"
echo -e "${YELLOW}Поддерживаются форматы:${NC}"
echo "  • Через пробел: site1.com site2.com site3.com"
echo "  • Каждый с новой строки"
echo -e "${YELLOW}Для завершения ввода нажмите ${BOLD}Ctrl+D${NC}"
echo -e "${CYAN}${BOLD}➜ Вставьте список доменов:${NC}"

DOMAIN_INPUT=""
while IFS= read -r line; do
    [ -z "$line" ] && continue
    DOMAIN_INPUT="$DOMAIN_INPUT $line"
done

if [ -n "$DOMAIN_INPUT" ]; then
    read -ra DOMAINS <<< "$DOMAIN_INPUT"
    for i in "${!DOMAINS[@]}"; do
        DOMAINS[$i]=$(echo "${DOMAINS[$i]}" | xargs)
    done
    print_success "Добавлено ${#DOMAINS[@]} доменов"
else
    print_error "Не введено ни одного домена!"
    exit 1
fi

echo ""

echo -e "${GREEN}${BOLD}📋 Всего доменов: ${#DOMAINS[@]}${NC}"
echo -e "${YELLOW}Список доменов:${NC}"
for i in "${!DOMAINS[@]}"; do
    echo "  $((i+1)). ${DOMAINS[$i]}"
done

echo ""

# ============================================
# 3. ПОДТВЕРЖДЕНИЕ
# ============================================
echo -e "${YELLOW}${BOLD}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}${BOLD}Пожалуйста, проверьте введенные данные:${NC}"
echo -e "  ${WHITE}Пользователь:${NC} ${GREEN}$HESTIA_USER${NC}"
echo -e "  ${WHITE}Hostname:${NC} ${GREEN}$HOSTNAME${NC}"
echo -e "  ${WHITE}Email:${NC} ${GREEN}$EMAIL${NC}"
echo -e "  ${WHITE}Пароль:${NC} ${GREEN}********${NC}"
echo -e "  ${WHITE}Доменов:${NC} ${GREEN}${#DOMAINS[@]}${NC}"
echo -e "${YELLOW}${BOLD}══════════════════════════════════════════════════════════════════════${NC}"

read -p "Начать установку? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { print_error "Отмена"; exit 0; }

# ============================================
# 4. УСТАНОВКА HESTIACP
# ============================================
print_step "УСТАНОВКА HESTIACP"

print_info "Скачивание установщика..."
wget -q https://raw.githubusercontent.com/hestiacp/hestiacp/release/install/hst-install.sh

print_info "Запуск установки..."
bash hst-install.sh \
    --interactive no \
    --username "$HESTIA_USER" \
    --email "$EMAIL" \
    --password "$HESTIA_PASSWORD" \
    --hostname "$HOSTNAME" \
    -f

if [ $? -ne 0 ]; then
    print_error "Ошибка установки!"
    exit 1
fi

print_success "HestiaCP установлена!"

# ============================================
# 5. ЗАГРУЗКА КОМАНД
# ============================================
print_step "ЗАГРУЗКА КОМАНД HESTIACP"

print_info "Ожидание завершения установки..."
sleep 5

load_hestia_commands

# ============================================
# 6. ДОБАВЛЕНИЕ ДОМЕНОВ, ФАЙЛОВ, SSL
# ============================================
print_step "НАСТРОЙКА ДОМЕНОВ"

print_info "Клонирование репозитория с файлами..."
rm -rf /tmp/hestia-deploy
git clone https://github.com/yukutakanawa/hestia-deploy.git /tmp/hestia-deploy 2>/dev/null
if [ $? -ne 0 ]; then
    print_error "Ошибка клонирования репозитория!"
    exit 1
fi
print_success "Репозиторий склонирован"

for d in "${DOMAINS[@]}"; do
    echo ""
    print_separator
    print_domain "Обработка домена: $d"
    print_separator
    
    # БЕЗОПАСНОЕ добавление домена (без дублей)
    add_domain_safe "$HESTIA_USER" "$d"
    
    PUBLIC_HTML="/home/$HESTIA_USER/web/$d/public_html"
    mkdir -p "$PUBLIC_HTML"
    
    rm -f "$PUBLIC_HTML/index.html"
    rm -f "$PUBLIC_HTML/index.php"
    rm -f "$PUBLIC_HTML/.htaccess"
    
    echo "  📤 Загрузка файлов..."
    for f in /tmp/hestia-deploy/*; do
        filename=$(basename "$f")
        if [ "$filename" != "setup.sh" ] && [ "$filename" != "deploy.sh" ] && [ -f "$f" ]; then
            cp -f "$f" "$PUBLIC_HTML/"
            print_file "$filename"
        fi
    done
    
    chown -R "$HESTIA_USER":"$HESTIA_USER" "$PUBLIC_HTML"
    chmod 755 "$PUBLIC_HTML"
    chmod 644 "$PUBLIC_HTML/index.php" 2>/dev/null
    chmod 644 "$PUBLIC_HTML/.htaccess" 2>/dev/null
    
    print_ssl "Установка SSL..."
    if v-add-letsencrypt-domain "$HESTIA_USER" "$d" 2>/dev/null; then
        print_success "SSL сертификат установлен"
    else
        print_warning "SSL не установлен (возможно домен не направлен)"
    fi
    
    if v-add-web-domain-ssl-force "$HESTIA_USER" "$d" 2>/dev/null; then
        print_success "HTTPS редирект включён"
    else
        print_warning "HTTPS редирект не включён"
    fi
    
    print_success "$d готов"
done

# ============================================
# 7. ПЕРЕЗАПУСК PHP
# ============================================
echo ""
print_info "Перезапуск PHP-FPM..."
systemctl restart php8.5-fpm 2>/dev/null || systemctl restart php8.4-fpm 2>/dev/null || systemctl restart php8.3-fpm 2>/dev/null
print_success "PHP перезапущен"

# ============================================
# 8. ИТОГ
# ============================================
echo ""
print_big_success

echo -e "${WHITE}${BOLD}📊 СТАТИСТИКА:${NC}"
echo -e "  ${GREEN}✅ Установлен HestiaCP${NC}"
echo -e "  ${GREEN}✅ Добавлено доменов: ${#DOMAINS[@]}${NC}"
echo -e "  ${GREEN}✅ SSL установлен${NC}"
echo ""

echo -e "${WHITE}${BOLD}🔗 ВАШИ ДОМЕНЫ:${NC}"
for d in "${DOMAINS[@]}"; do
    echo -e "  ${GREEN}🔒 https://$d${NC}"
done

echo ""
echo -e "${WHITE}${BOLD}📝 ДОСТУП К ПАНЕЛИ:${NC}"
echo -e "  ${CYAN}🌐 https://$HOSTNAME:8083${NC}"
echo -e "  ${CYAN}👤 Логин: $HESTIA_USER${NC}"
echo -e "  ${CYAN}🔑 Пароль: (ваш пароль)${NC}"
echo ""

# ============================================
# 9. ПЕРЕЗАГРУЗКА (В САМОМ КОНЦЕ)
# ============================================
print_step "ЗАВЕРШЕНИЕ"
print_warning "Все настройки выполнены! Сервер будет перезагружен через 10 секунд..."
print_info "После перезагрузки все сервисы будут работать корректно."
echo ""

sleep 10
reboot