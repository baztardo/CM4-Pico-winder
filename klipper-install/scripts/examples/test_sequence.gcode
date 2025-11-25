; Test Winding Sequence
; Simple test to verify system operation
; Generated: 2024-11-25

; Home and calibrate
HOME_TRAVERSE

; Query system status
QUERY_ANGLE_SENSOR
QUERY_HW_COUNTER

; Run short winding test (1 layer at low speed)
M117 Starting test winding...
WINDER_START RPM=100 LAYERS=1

; Test complete
M117 Test complete

