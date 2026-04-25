#!/bin/bash
# Cách dùng: ./ha_room.sh "Tên Phòng"
# Ví dụ: ./ha_room.sh "Phòng khách"

ROOM=$1

curl -sS -X POST "http://127.0.0.1:8123/api/template" \
  -H "Authorization: Bearer $(tr -d '\r\n' < ~/.config/ha_token)" \
  -H "Content-Type: application/json" \
  -d "{\"template\":\"{{ area_entities('$ROOM') | join('\\n') }}\"}"