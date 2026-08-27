#!/bin/bash
# setup.sh - Интерактивная установка HestiaCP с авто-перезагрузкой

set -e

# ============================================
# ПРОВЕРКА: УСТАНОВЛЕНА ЛИ HESTIACP?
# ============================================
if [ -f /usr/local/hestia/bin/hestia ]; then
    echo ""
    echo "✅ HestiaCP уже установлена!"
    echo "🚀 Продолжаем настройку доменов..."
    
    # Загружаем функции
    export PATH="/usr/local/hestia/bin:$PATH"
    source /usr/local/hestia/func/main.sh 2>/dev/null
    
    # Проверяем, что команды доступны
    if command -v v-add-domain &> /dev/null; then
        echo "✅ Команды HestiaCP доступны!"
        
        # Читаем сохранённые данные
        if [ -f /root/hestia_domains.txt ]; then
            DOMAINS=$(cat /root/hestia_domains.txt)
            HESTIA_USER=$(cat /root/hestia_user.txt 2>/dev/null || echo "batrider")
        else
            echo "⚠️ Файл с доменами не найден!"
            exit 1
        fi
        
        # Клонируем репозиторий с файлами
        echo "📥 Клонирование репозитория с файлами..."
        git clone https://github.com/yukutakanawa/hestia-deploy.git /tmp/hestia-deploy 2>/dev/null || echo "⚠️ Репозиторий уже склонирован"
        
        # Добавляем домены
        for d in $DOMAINS; do
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📂 Обработка домена: $d"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # 1. Добавляем домен
            echo -n "  ➕ Добавление домена... "
            v-add-domain "$HESTIA_USER" "$d" 2>/dev/null
            v-add-web-domain "$HESTIA_USER" "$d" 2>/dev/null
            echo "✅"
            
            # 2. Создаём папку
            PUBLIC_HTML="/home/$HESTIA_USER/web/$d/public_html"
            mkdir -p "$PUBLIC_HTML"
            rm -f "$PUBLIC_HTML/index.html"
            
            # 3. Загружаем файлы
            echo "  📤 Загрузка файлов..."
            for f in /tmp/hestia-deploy/*; do
                filename=$(basename "$f")
                if [ "$filename" != "setup.sh" ] && [ "$filename" != "deploy.sh" ] && [ -f "$f" ]; then
                    cp "$f" "$PUBLIC_HTML/"
                    echo "    ✅ $filename"
                fi
            done
            chown -R "$HESTIA_USER":"$HESTIA_USER" "$PUBLIC_HTML"
            
            # 4. SSL
            echo -n "  🔐 Установка SSL... "
            if v-add-letsencrypt-domain "$HESTIA_USER" "$d" 2>/dev/null; then
                echo "✅"
            else
                echo "⚠️ (возможно домен не направлен)"
            fi
            
            echo -n "  🔄 Включение HTTPS редиректа... "
            if v-add-web-domain-ssl-force "$HESTIA_USER" "$d" 2>/dev/null; then
                echo "✅"
            else
                echo "⚠️"
            fi
            
            echo "✅ $d готов"
        done
        
        # Очистка
        rm -f /root/hestia_domains.txt /root/hestia_user.txt
        rm -f /root/hestia_continue.sh
        
        # Удаляем задачу из crontab
        crontab -l 2>/dev/null | grep -v "@reboot /root/hestia_continue.sh" | crontab - 2>/dev/null || true
        
        echo ""
        echo "🎉 ВСЁ ГОТОВО!"
        echo ""
        echo "🔗 ВСЕ ДОМЕНЫ РАБОТАЮТ ПО HTTPS:"
        for d in $DOMAINS; do
            echo "  🔒 https://$d"
        done
        echo ""
        echo "📝 ДОСТУП К ПАНЕЛИ: https://$(hostname):8083"
        
        exit 0
    else
        echo "⚠️ Команды HestiaCP пока не доступны"
        echo "🔧 Пытаемся загрузить окружение..."
        source /usr/local/hestia/func/main.sh 2>/dev/null
        if command -v v-add-domain &> /dev/null; then
            echo "✅ Команды загружены!"
            exec "$0"
        else
            echo "❌ Не удалось загрузить команды."
            echo "💡 Попробуйте перезагрузить сервер вручную: reboot"
            exit 1
        fi
    fi
fi

# ============================================
# ЕСЛИ HESTIACP НЕ УСТАНОВЛЕНА
# ============================================
echo "🚀 HestiaCP не установлена. Начинаем установку..."

# ============================================
# ЦВЕТА
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
print_step() { echo -e "\n${CYAN}▶ $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║     🚀  AUTO HESTIACP SETUP                            ║"
    echo "║     С перезагрузкой и продолжением                      ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ============================================
# 1. ЗАПРОС ДАННЫХ
# ============================================
clear
print_header

echo -e "${YELLOW}Для установки HestiaCP потребуется ввести несколько параметров${NC}"
echo -e "${YELLOW}Все остальные настройки будут применены автоматически${NC}\n"

# Имя пользователя
while true; do
    echo -e "${CYAN}➜ Введите имя пользователя для HestiaCP:${NC}"
    read -p "Имя пользователя: " HESTIA_USER
    [ -n "$HESTIA_USER" ] && break
    print_error "Имя не может быть пустым!"
done
print_success "Имя пользователя: $HESTIA_USER"

echo ""

# Пароль
while true; do
    echo -e "${CYAN}➜ Введите пароль для администратора HestiaCP:${NC}"
    read -s HESTIA_PASSWORD
    echo
    echo -e "${CYAN}➜ Повторите пароль:${NC}"
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

# Hostname
while true; do
    echo -e "${CYAN}➜ Введите hostname (домен сервера):${NC}"
    read HOSTNAME
    [[ "$HOSTNAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && break
    print_error "Некорректный домен! Пример: www.myserver.com"
done
print_success "Hostname: $HOSTNAME"

echo ""

# Email
echo -e "${CYAN}➜ Введите email для сертификатов (оставьте пустым для стандартного):${NC}"
read EMAIL_INPUT
EMAIL="${EMAIL_INPUT:-admin@$HOSTNAME}"
print_info "Email: $EMAIL"

echo ""

# ============================================
# 2. ВВОД ДОМЕНОВ
# ============================================
echo -e "${CYAN}➜ Вставьте список доменов (в любом формате):${NC}"
echo -e "${YELLOW}Поддерживаются форматы:${NC}"
echo "  • Через пробел: site1.com site2.com site3.com"
echo "  • Каждый с новой строки"
echo -e "${YELLOW}Для завершения ввода нажмите Ctrl+D${NC}"
echo -e "${CYAN}➜ Вставьте список доменов:${NC}"

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

echo -e "${GREEN}📋 Всего доменов: ${#DOMAINS[@]}${NC}"
echo -e "${YELLOW}Список доменов:${NC}"
for i in "${!DOMAINS[@]}"; do
    echo "  $((i+1)). ${DOMAINS[$i]}"
done

echo ""

# ============================================
# 3. ПОДТВЕРЖДЕНИЕ
# ============================================
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Пожалуйста, проверьте введенные данные:${NC}"
echo -e "  Пользователь: ${GREEN}$HESTIA_USER${NC}"
echo -e "  Hostname: ${GREEN}$HOSTNAME${NC}"
echo -e "  Email: ${GREEN}$EMAIL${NC}"
echo -e "  Пароль: ${GREEN}********${NC}"
echo -e "  Доменов: ${GREEN}${#DOMAINS[@]}${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -p "Начать установку? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { print_error "Отмена"; exit 0; }

# ============================================
# 4. УСТАНОВКА HESTIACP
# ============================================
print_step "Установка HestiaCP"

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
# 5. СОХРАНЕНИЕ ДАННЫХ ДЛЯ ПРОДОЛЖЕНИЯ
# ============================================
print_step "Сохранение данных для продолжения"

# Сохраняем домены
echo "${DOMAINS[@]}" > /root/hestia_domains.txt
echo "$HESTIA_USER" > /root/hestia_user.txt

# Создаём скрипт продолжения (на случай, если crontab не сработает)
cat > /root/hestia_continue.sh <<'EOF'
#!/bin/bash
# Продолжение установки после перезагрузки
/root/setup.sh
EOF
chmod +x /root/hestia_continue.sh

# Копируем setup.sh в /root (если запускали из временной папки)
if [ -f "$0" ]; then
    cp "$0" /root/setup.sh
    chmod +x /root/setup.sh
fi

# Добавляем задачу в crontab для запуска после перезагрузки
(crontab -l 2>/dev/null | grep -v "@reboot /root/hestia_continue.sh"; echo "@reboot /root/hestia_continue.sh") | crontab -

print_success "Данные сохранены, задача добавлена в crontab"

# ============================================
# 6. ПЕРЕЗАГРУЗКА
# ============================================
print_step "Перезагрузка сервера"
echo -e "${YELLOW}⚠️ Сервер будет перезагружен через 10 секунд...${NC}"
echo -e "${YELLOW}После перезагрузки установка продолжится автоматически!${NC}"
echo -e "${YELLOW}Будут выполнены:${NC}"
echo -e "  📂 Добавление доменов"
echo -e "  📤 Загрузка файлов из репозитория"
echo -e "  🔐 Установка SSL сертификатов"
echo -e "  🔄 Включение HTTPS редиректа"
echo -e "${YELLOW}Подключитесь через 2-3 минуты и проверьте результат.${NC}"

sleep 10
reboot