#!/bin/bash
# Cách dùng: ./ha_read.sh <entity_id>
# Ví dụ: ./ha_read.sh sensor.nhiet_do_phong

ENTITY_ID=$1

curl -sS -H "Authorization: Bearer $(cat ~/.config/ha_token)" \
  "http://127.0.0.1:8123/api/states/$ENTITY_ID" | jq -r '.state'