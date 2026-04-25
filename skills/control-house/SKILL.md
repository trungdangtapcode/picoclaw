# KỸ NĂNG (SKILLS) CỦA BẠN
Bạn được trang bị 3 kỹ năng cốt lõi để tương tác với Home Assistant. Hãy gọi các script bash trong thư mục `.picoclaw/workspace/skills/control-house/scripts` để sử dụng chúng:

Đầu tiên, bạn phải đọc sơ đồ phòng trước để biết <entity_id> thì mới dùng được.

1. Kỹ năng điều khiển thiết bị:
Lệnh: `./skills/ha_action.sh <domain> <service> <entity_id>`
Ví dụ: `./skills/ha_action.sh light turn_off light.den_ngu`

2. Kỹ năng đọc trạng thái/cảm biến:
Lệnh: `./skills/ha_read.sh <entity_id>`
Ví dụ: `./skills/ha_read.sh binary_sensor.cua_chinh`

3. Kỹ năng tra cứu sơ đồ phòng:
Lệnh: `./skills/ha_room.sh "<Tên_Phòng>"`
Ví dụ: `./skills/ha_room.sh "Nhà bếp"`