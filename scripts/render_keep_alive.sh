#!/bin/bash
# ==============================================================================
# Cognidoc AI — Render Free Tier 24/7 Keep-Alive Pinger
# ==============================================================================
# Render.com bepul tarifida 15 daqiqa davomida so'rov kelmasa, server "uyqu"
# rejimiga (spin down) o'tadi va keyingi so'rov 50+ soniya kutishga sabab bo'ladi.
# Ushbu skript har 10 daqiqada (600 soniya) /health/live endpointiga yengil
# GET so'rov yuborib, serverni 24/7 doimiy uyg'oq (HOT) holatda ushlab turadi.
# ==============================================================================

URL="${RENDER_URL:-https://document-workspace-g59a.onrender.com/health/live}"
INTERVAL="${PING_INTERVAL_SEC:-600}" # 10 daqiqa (Render 15 daqiqada uxlaydi)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================================${NC}"
echo -e "${GREEN}🚀 Cognidoc AI — Render Keep-Alive Service Boshlandi${NC}"
echo -e "🔗 Target URL : ${YELLOW}${URL}${NC}"
echo -e "⏱️  Interval   : Har ${INTERVAL} soniyada (${INTERVAL}/60 daqiqa)"
echo -e "${BLUE}======================================================${NC}"

count=0

while true; do
    count=$((count + 1))
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # curl orqali HTTP status code va bajarilish vaqtini (latency) olamiz
    http_response=$(curl -s -L -w "%{http_code} %{time_total}" -o /dev/null --max-time 30 "$URL" 2>/dev/null)
    exit_code=$?

    http_status=$(echo "$http_response" | awk '{print $1}')
    latency=$(echo "$http_response" | awk '{print $2}')

    if [ $exit_code -eq 0 ] && [ "$http_status" -eq 200 ]; then
        echo -e "[${timestamp}] #${count} [${GREEN}OK 200${NC}] Latency: ${latency}s — Server faol va uyg'oq! ⚡"
    elif [ $exit_code -eq 0 ] && [ -n "$http_status" ]; then
        echo -e "[${timestamp}] #${count} [${YELLOW}HTTP ${http_status}${NC}] Latency: ${latency}s — Javob qaytdi."
    else
        echo -e "[${timestamp}] #${count} [${RED}FAILED${NC}] Ulanishda xatolik yuz berdi (Exit: ${exit_code}). Qayta urinilmoqda..."
    fi

    sleep "$INTERVAL"
done
