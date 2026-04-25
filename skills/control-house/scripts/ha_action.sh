#!/bin/bash
# Cách dùng: ./ha_action.sh <domain> <service> <entity_id>
# Ví dụ: ./ha_action.sh switch turn_on switch.bom_nuoc

DOMAIN=$1
SERVICE=$2
ENTITY_ID=$3

curl -sS -X POST "http://127.0.0.1:8123/api/services/$DOMAIN/$SERVICE" \
  -H "Authorization: Bearer $(cat ~/.config/ha_token)" \
  -H "Content-Type: application/json" \
  -d "{\"entity_id\":\"$ENTITY_ID\"}"