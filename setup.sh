#!/bin/bash
# setup.sh - Интерактивная установка HestiaCP

set -e

# ============================================
# ЦВЕТА ДЛЯ ВЫВОДА
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# ФУНКЦИИ
# ============================================
print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║     🚀  INTERACTIVE HESTIACP SETUP                      ║"
    echo "║     Автоматическая настройка доменов                     ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${CYAN}▶ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# ============================================
# 1. ЗАПРОС ДАННЫХ
# ============================================
clear
print_header

echo -e "${YELLOW}Для установки HestiaCP потребуется ввести несколько параметров${NC}"
echo -e "${YELLOW}Все остальные настройки будут применены автоматически${NC}\n"

# Запрос имени пользователя HestiaCP
while true; do
    echo -e "${CYAN}➜ Введите имя пользователя для HestiaCP (которое создавали при установке):${NC}"
    echo -e "${YELLOW}   (например: admin, batrider, webmaster и т.д.)${NC}"
    read -p "Имя пользователя: " HESTIA_USER
    
    if [ -n "$HESTIA_USER" ]; then
        print_success "Имя пользователя: $HESTIA_USER"
        break
    else
        print_error "Имя пользователя не может быть пустым!"
    fi
done

echo ""

# Запрос пароля
while true; do
    echo -e "${CYAN}➜ Введите пароль для администратора HestiaCP:${NC}"
    read -s HESTIA_PASSWORD
    echo
    echo -e "${CYAN}➜ Повторите пароль:${NC}"
    read -s HESTIA_PASSWORD_CONFIRM
    echo
    
    if [ "$HESTIA_PASSWORD" = "$HESTIA_PASSWORD_CONFIRM" ]; then
        if [ ${#HESTIA_PASSWORD} -ge 8 ]; then
            print_success "Пароль принят"
            break
        else
            print_error "Пароль должен быть минимум 8 символов!"
        fi
    else
        print_error "Пароли не совпадают!"
    fi
done

echo ""

# Запрос hostname
while true; do
    echo -e "${CYAN}➜ Введите hostname (домен сервера, например: www.myserver.com):${NC}"
    read HOSTNAME
    
    if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_success "Hostname принят: $HOSTNAME"
        break
    else
        print_error "Некорректный домен! Пример: www.myserver.com"
    fi
done

echo ""

# Запрос email (опционально)
echo -e "${CYAN}➜ Введите email для сертификатов (оставьте пустым для стандартного):${NC}"
read EMAIL_INPUT

if [ -z "$EMAIL_INPUT" ]; then
    EMAIL="admin@$HOSTNAME"
    print_info "Использован стандартный email: $EMAIL"
else
    EMAIL="$EMAIL_INPUT"
    print_success "Email принят: $EMAIL"
fi

echo ""

# ============================================
# 2. ВВОД ДОМЕНОВ (ЛЮБОЙ ФОРМАТ)
# ============================================
echo -e "${CYAN}➜ Вставьте список доменов (в любом формате):${NC}"
echo -e "${YELLOW}Поддерживаются форматы:${NC}"
echo "  • Через пробел: site1.com site2.com site3.com"
echo "  • Каждый с новой строки:"
echo "    site1.com"
echo "    site2.com"
echo "    site3.com"
echo "  • Смешанный формат"
echo -e "${YELLOW}Для завершения ввода нажмите Ctrl+D (или дважды Enter)${NC}"
echo -e "${CYAN}➜ Вставьте список доменов:${NC}"

# Читаем многострочный ввод
DOMAIN_INPUT=""
while IFS= read -r line; do
    [ -z "$line" ] && continue
    DOMAIN_INPUT="$DOMAIN_INPUT $line"
done

# Разбиваем на массив
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

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_error "Установка отменена"
    exit 0
fi

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
    print_error "Ошибка установки HestiaCP!"
    exit 1
fi

print_success "HestiaCP установлен!"

print_info "Ожидание запуска сервисов..."
sleep 10

# ============================================
# 5. ЗАГРУЗКА ФУНКЦИЙ HESTIACP
# ============================================
print_step "Загрузка функций HestiaCP"

source /usr/local/hestia/bin/hestia.conf 2>/dev/null || true
source /usr/local/hestia/func/main.sh 2>/dev/null || true

if ! command -v v-add-domain &> /dev/null; then
    print_error "Команды HestiaCP не найдены!"
    exit 1
fi

print_success "Функции HestiaCP загружены"

# ============================================
# 6. ДОБАВЛЕНИЕ ДОМЕНОВ
# ============================================
print_step "Добавление доменов (${#DOMAINS[@]} шт.)"

SUCCESS_COUNT=0
FAILED_DOMAINS=()

for domain in "${DOMAINS[@]}"; do
    echo -n "  ➕ $domain ... "
    
    v-add-domain "$HESTIA_USER" "$domain" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}❌ (возможно уже существует)${NC}"
        FAILED_DOMAINS+=("$domain")
    fi
    
    v-add-web-domain "$HESTIA_USER" "$domain" 2>/dev/null
done

print_success "Добавлено доменов: $SUCCESS_COUNT из ${#DOMAINS[@]}"

if [ ${#FAILED_DOMAINS[@]} -gt 0 ]; then
    print_warning "Проблемы с доменами: ${FAILED_DOMAINS[*]}"
fi

# ============================================
# 7. ЗАГРУЗКА ВАШИХ ФАЙЛОВ
# ============================================
print_step "Загрузка ваших файлов на домены"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Список файлов для загрузки
FILES_TO_UPLOAD=()

# Ищем все файлы в текущей папке
for file in "$SCRIPT_DIR"/*; do
    filename=$(basename "$file")
    if [ "$filename" != "setup.sh" ] && [ -f "$file" ]; then
        FILES_TO_UPLOAD+=("$file")
        print_success "  ✅ Найден: $filename"
    fi
done

if [ ${#FILES_TO_UPLOAD[@]} -eq 0 ]; then
    print_error "❌ Нет файлов для загрузки!"
    print_info "Положите ваши файлы в одну папку со скриптом"
    exit 1
fi

print_info "Всего найдено файлов: ${#FILES_TO_UPLOAD[@]}"
print_info "Загрузка файлов на все домены..."

for domain in "${DOMAINS[@]}"; do
    PUBLIC_HTML="/home/$HESTIA_USER/web/$domain/public_html"
    
    if [ ! -d "$PUBLIC_HTML" ]; then
        print_warning "  ⚠️ $domain - директория не найдена, создаём..."
        mkdir -p "$PUBLIC_HTML"
    fi
    
    # Удаляем старый index.html (если есть)
    if [ -f "$PUBLIC_HTML/index.html" ]; then
        rm -f "$PUBLIC_HTML/index.html"
        print_success "  🗑️ $domain - удалён старый index.html"
    fi
    
    # Копируем все ваши файлы
    for file in "${FILES_TO_UPLOAD[@]}"; do
        filename=$(basename "$file")
        cp "$file" "$PUBLIC_HTML/"
        print_success "  📤 $domain - загружен $filename"
    done
    
    # Устанавливаем права
    chown -R "$HESTIA_USER":"$HESTIA_USER" "$PUBLIC_HTML"
    chmod 755 "$PUBLIC_HTML"
done

print_success "Все файлы загружены на все домены"

# ============================================
# 8. УСТАНОВКА SSL И ВКЛЮЧЕНИЕ HTTPS
# ============================================
print_step "Установка SSL и настройка HTTPS"

SSL_SUCCESS=0
SSL_FAILED=0

for domain in "${DOMAINS[@]}"; do
    echo -e "\n  🔐 Обработка: $domain"
    
    # 1. Устанавливаем Let's Encrypt сертификат
    echo -n "    Установка SSL... "
    v-add-letsencrypt-domain "$HESTIA_USER" "$domain" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SSL установлен${NC}"
        ((SSL_SUCCESS++))
        
        # 2. Включаем автоматический редирект HTTP -> HTTPS
        echo -n "    Включение HTTPS редиректа... "
        v-add-web-domain-ssl-force "$HESTIA_USER" "$domain" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Включён${NC}"
        else
            echo -e "${YELLOW}⚠️ Возможно уже активен${NC}"
        fi
    else
        echo -e "${RED}❌ Ошибка SSL для $domain${NC}"
        ((SSL_FAILED++))
    fi
done

echo ""
print_success "SSL установлен для $SSL_SUCCESS доменов"
if [ $SSL_FAILED -gt 0 ]; then
    print_warning "SSL не установлен для $SSL_FAILED доменов"
fi

# ============================================
# 9. ИТОГОВАЯ ИНФОРМАЦИЯ
# ============================================
print_step "✅ УСТАНОВКА ЗАВЕРШЕНА!"

echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  🎉  ВСЕ ДОМЕНЫ УСПЕШНО НАСТРОЕНЫ!                      ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${BLUE}📊 СТАТИСТИКА:${NC}"
echo -e "  ✅ Установлен HestiaCP"
echo -e "  ✅ Пользователь: ${GREEN}$HESTIA_USER${NC}"
echo -e "  ✅ Добавлено доменов: ${#DOMAINS[@]}"
echo -e "  ✅ Загружено файлов: ${#FILES_TO_UPLOAD[@]}"
echo -e "  ✅ SSL: $SSL_SUCCESS из ${#DOMAINS[@]}"
echo -e "  ✅ HTTPS редирект: ${GREEN}Включён${NC}"
echo ""

echo -e "${BLUE}🔗 ВАШИ ДОМЕНЫ (ВСЕ РАБОТАЮТ ЧЕРЕЗ HTTPS):${NC}"
for domain in "${DOMAINS[@]}"; do
    echo -e "  🔒 https://$domain"
done

echo ""
echo -e "${BLUE}📝 ДОСТУП К ПАНЕЛИ:${NC}"
echo -e "  🌐 https://$HOSTNAME:8083"
echo -e "  👤 Логин: ${GREEN}$HESTIA_USER${NC}"
echo -e "  🔑 Пароль: ${GREEN}$HESTIA_PASSWORD${NC}"
echo ""

if [ ${#FAILED_DOMAINS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️ Проблемы с доменами:${NC}"
    for d in "${FAILED_DOMAINS[@]}"; do
        echo -e "  - $d (возможно уже существует)"
    done
    echo ""
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 ГОТОВО! ВСЕ СИСТЕМЫ РАБОТАЮТ!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Сохраняем информацию в файл
cat > /root/hestia_setup_info.txt <<EOF
===========================================
ИНФОРМАЦИЯ ОБ УСТАНОВКЕ
===========================================
Дата: $(date)
Hostname: $HOSTNAME
Email: $EMAIL
Пароль: $HESTIA_PASSWORD
Пользователь: $HESTIA_USER
Доменов: ${#DOMAINS[@]}

Список доменов:
$(for d in "${DOMAINS[@]}"; do echo "  - $d"; done)

Загруженные файлы:
$(for f in "${FILES_TO_UPLOAD[@]}"; do echo "  - $(basename $f)"; done)

Доступ к панели:
  https://$HOSTNAME:8083
  Логин: $HESTIA_USER
  Пароль: $HESTIA_PASSWORD
===========================================
EOF

print_success "Информация сохранена в /root/hestia_setup_info.txt"