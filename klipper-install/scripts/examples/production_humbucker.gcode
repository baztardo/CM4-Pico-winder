; Production Humbucker Winding Sequence
; Wire: 43 AWG (0.056mm bare + 0.016mm coating)
; Bobbin: 6.35mm width
; Target: 5000 turns (standard humbucker)
; Generated: 2024-11-25

; ========================================
; SETUP PHASE
; ========================================

M117 Initializing...

; Home traverse and calibrate spindle
HOME_TRAVERSE

; Verify system status
QUERY_ANGLE_SENSOR
QUERY_HW_COUNTER

M117 Ready to wind

; ========================================
; WINDING PHASE
; ========================================

; Calculate layers for 5000 turns
; Bobbin width: 6.35mm
; Wire diameter (with coating): 0.072mm
; Turns per layer: 6.35 / 0.072 = 88.2 turns
; Layers needed: 5000 / 88.2 = 56.7 layers

M117 Winding 57 layers...

; Wind at moderate speed for quality
WINDER_START RPM=300 LAYERS=57

; ========================================
; COMPLETION PHASE
; ========================================

M117 Winding complete!

; Query final status
QUERY_ANGLE_SENSOR
QUERY_HW_COUNTER

; Done
M117 Production complete - 5000 turns

