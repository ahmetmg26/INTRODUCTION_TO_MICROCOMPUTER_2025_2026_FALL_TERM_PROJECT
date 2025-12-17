;==========================================================
; TEMPERATURE CONTROL MODULE
;==========================================================
#include <xc.inc>
#include "delays.asm"
    
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
    
;local degiskenler
PSECT udata
adc_raw:        DS 1    ; Ham ADC deðeri (ADRESL)
adc_high:       DS 1    ; ADRESH (kullanýlmayabilir)
div_quot:       DS 1    ; Bölüm sonucu
div_rem:        DS 1    ; Kalan (fractional için)
div_count:      DS 1    ; Bölme sayacý    
    
    
PSECT code,class=CODE,delta=2

;==========================================================
; ADC ile S?cakl?k Oku
; Formül: Sýcaklýk = ADC_raw * 50 / 256
;         Basitleþtirilmiþ: Sýcaklýk ? ADC_raw / 5
;==========================================================
TEMP_ReadAmbient:
    ;BANKSEL ADCON0
    ;MOVLW   0x81            ; ADC ON, CH0, Fosc/32
    ;MOVWF   ADCON0
    
    ;CALL Delay_5us ; yeterli degilmis, 20us lazim
    MOVLW 40
    CALL delay_us
    
    
    BANKSEL ADCON0
    BSF ADCON0, 2  ; GO/DONE = 1  ile ADC ba?lat
    
TEMP_Wait:
    BTFSC ADCON0, 2
    GOTO TEMP_Wait
    
    ; 3. Sonucu oku (Saða yaslý: ADRESL = alt 8 bit)
    BSF     STATUS, 5       ; Bank 1'e geç
    MOVF    ADRESL, W       ; Alt 8 bit (ana deðer)
    BCF     STATUS, 5       ; Bank 0'a dön
    
    MOVWF   adc_raw         ; Ham deðeri sakla
    
    ; 4. ADC deðerini 5'e böl ? Sýcaklýk (integer kýsým)
    ;    Kalan * 2 ? Ondalýk kýsým (yaklaþýk)
    CALL    divide_by_5
    
    ; 5. Sonuçlarý kaydet
    MOVF    div_quot, W
    BANKSEL ambient_temp_int
    MOVWF   ambient_temp_int
    
    ; Fractional: kalan * 2 (0-4 arasý kalan ? 0,2,4,6,8)
    MOVF    div_rem, W
    ADDWF   div_rem, W      ; W = kalan * 2
    MOVWF   ambient_temp_frac
    
    RETURN
;------------------------------------------------------------
    divide_by_5:
    CLRF    div_quot
    MOVF    adc_raw, W
    MOVWF   div_rem         ; Baþlangýçta kalan = adc_raw
    
    div5_loop:
	; kalan >= 5 mi?
	MOVLW   5
	SUBWF   div_rem, W      ; W = kalan - 5
	BTFSS   STATUS, 0       ; C=0 ise kalan < 5
	RETURN                  ; Bölme bitti

	; kalan >= 5, devam et
	MOVWF   div_rem         ; kalan = kalan - 5
	INCF    div_quot, F     ; bölüm++
	GOTO    div5_loop
    
;==========================================================
; S?cakl?k Kar??la?t?r ve Fan/Heater Kontrol
;==========================================================
TEMP_UpdateFanControl:
    BANKSEL ambient_temp_int
    MOVF ambient_temp_int, W
    MOVWF   temp_compare_result     ; Gecici sakla
    
    ; W = desired - ambient
    MOVF    desired_temp_int, W
    SUBWF temp_compare_result, W

    ; E?er desired == ambient ? Z bayra?? 1 olur
    
    BTFSC STATUS, STATUS_Z_POSITION
    GOTO TEMP_Equal
    
    ; E?er desired > ambient ? C=1 (so?uk)
    BTFSC STATUS, STATUS_C_POSITION
    GOTO TEMP_Lower           ; higher olabilir kontrol gerekir
    GOTO TEMP_Higher
    
    TEMP_Higher:
	; ambient >= desired ? Fan ON, Heater OFF
	BANKSEL PORTB
	BSF PORTB, 1                ; Cooler ON
	BCF PORTB, 0                ; Heater OFF
	RETURN

    TEMP_Lower:
	; ambient < desired ? Heater ON, Fan OFF
	BANKSEL PORTB
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
    BANKSEL fan_rps
    CLRF fan_rps

waitHigh:
    BANKSEL PORTB
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