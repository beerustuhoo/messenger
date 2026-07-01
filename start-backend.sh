#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
docker compose -f backend/docker-compose.yml up --build -d

lan_ip=""
if command -v ip >/dev/null 2>&1; then
  lan_ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')
elif command -v hostname >/dev/null 2>&1; then
  lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

echo ""
echo "Backend started!"
echo "  API:        http://localhost:3000"
echo "  Health:     http://localhost:3000/health"
echo "  Mail inbox: http://localhost:8025"
echo ""
echo "Mobile Messenger app (releases/app-release.apk):"
echo "  Emulator / Nox / BlueStacks:  http://10.0.2.2:3000  (default — no setup)"
if [ -n "$lan_ip" ]; then
  echo "  Physical phone (same Wi-Fi):  http://YOUR_PC_IP:3000"
  echo "    This machine's IP:          http://${lan_ip}:3000"
  echo "    -> Login screen: tap the Server button -> Test -> Save"
else
  echo "  Physical phone: set Server URL in app to http://YOUR_PC_IP:3000"
fi
echo ""
echo "Stop with: docker compose -f backend/docker-compose.yml down"
