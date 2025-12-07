;==========================================================
; TEMPERATURE CONTROL MODULE
;==========================================================
#include <xc.inc>

    
    ;FONKSIYONLAR
    GLOBAL TEMP_ReadAmbient
    GLOBAL TEMP_UpdateFanControl
    GLOBAL measureFanRPS
    GLOBAL Delay_5us
    
    ;DEGISKENLER
    GLOBAL ambient_temp_int
    GLOBAL ambient_temp_frac
    GLOBAL desired_temp_int
    GLOBAL desired_temp_frac
    GLOBAL temp_compare_result
    GLOBAL fan_rps
    
    
    
PSECT code,class=CODE,delta=2

;==========================================================
; ADC ile S?cakl?k Oku
;==========================================================
TEMP_ReadAmbient:
    CALL Delay_5us
    BANKSEL ADCON0
    BSF ADCON0, 2  ; GO/DONE = 1  ile ADC ba?lat
    
TEMP_Wait:
    BTFSC ADCON0, 2
    GOTO TEMP_Wait
    
    ; Sonucu kaydet
    BANKSEL ADRESH
    MOVF ADRESH, W
    BANKSEL ambient_temp_int
    MOVWF ambient_temp_int
    
    BANKSEL ADRESL
    MOVF ADRESL, W
    BANKSEL ambient_temp_frac
    MOVWF ambient_temp_frac
    
    RETURN

    
;==========================================================
; S?cakl?k Kar??la?t?r ve Fan/Heater Kontrol
;==========================================================
TEMP_UpdateFanControl:
    BANKSEL ambient_temp_int
    MOVF ambient_temp_int, W

    ; W = desired - ambient
    SUBWF desired_temp_int, W

    ; E?er desired == ambient ? Z bayra?? 1 olur
    BTFSC STATUS, STATUS_Z_POSITION
    GOTO TEMP_Equal
    
    ; E?er desired > ambient ? C=1 (so?uk)
    BTFSC STATUS, STATUS_C_POSITION
    GOTO TEMP_Lower
    GOTO TEMP_Higher
    
    TEMP_Higher:
	; ambient >= desired ? Fan ON, Heater OFF
	BSF PORTB, 1                ; Cooler ON
	BCF PORTB, 0                ; Heater OFF
	RETURN

    TEMP_Lower:
	; ambient < desired ? Heater ON, Fan OFF
	BSF PORTB, 0                ; Heater ON
	BCF PORTB, 1                ; Cooler OFF
	RETURN

    TEMP_Equal:
	BANKSEL PORTB
	BCF PORTB,0      ; Heater OFF
	BCF PORTB,1      ; Cooler/Fan OFF
	MOVLW 0
	MOVWF temp_compare_result
	RETURN
;--------------------------------------------------------------
    
    
;========================================
; measureFanRPS()
; RB2 pulse say?m? ? fan_rps
;========================================
measureFanRPS:
    CLRF fan_rps

waitHigh:
    BTFSS PORTB,2
    GOTO waitHigh
waitLow:
    BTFSC PORTB,2
    GOTO waitLow

    ; bir darbe alg?land?
    INCF fan_rps, F

    CALL Delay_5us 

    RETURN
   

Delay_5us:
; CALL = 2 cycle
NOP          ; 1 cycle
NOP          ; 1 cycle
NOP          ; 1 cycle
RETURN       ; 2 cycle