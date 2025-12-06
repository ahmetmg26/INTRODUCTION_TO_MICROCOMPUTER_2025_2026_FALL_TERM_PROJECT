;==========================================================
; MAIN.ASM - Variables + Main Program
;==========================================================
#include <xc.inc>
#include "temperature_module.asm"  


    GLOBAL MAIN
    GLOBAL ambient_temp_int
    GLOBAL ambient_temp_frac
    
    GLOBAL desired_temp_int
    GLOBAL desired_temp_frac
    
    GLOBAL fan_rps
    GLOBAL temp_compare_result
    
     

; Configuration bits
CONFIG FOSC = XT
CONFIG WDTE = OFF
CONFIG PWRTE = ON
CONFIG CP = OFF
CONFIG BOREN = ON
CONFIG LVP = OFF
CONFIG CPD = OFF
CONFIG WRT = OFF

;==========================================================
; RESET VECTOR
;==========================================================
PSECT resetVec, class=CODE, delta=2
ORG 0x0000
    GOTO MAIN



;==========================================================
; VARIABLES - BANK0
;==========================================================
PSECT udata_bank0,class=BANK0,space=1,delta=1,noexec

ambient_temp_int:      DS 1
ambient_temp_frac:     DS 1
desired_temp_int:      DS 1
desired_temp_frac:     DS 1
fan_rps:               DS 1
temp_compare_result:   DS 1
    delay_outer:    DS 1
    delay_inner:    DS 1
tach_counter:       DS 1


PSECT code
 
MAIN:
    CALL PortInit
    
    ; Ba?lang?ç de?erleri
    MOVLW 0
    BANKSEL desired_temp_int
    MOVWF desired_temp_int
    CLRF desired_temp_frac
    
READ_LOOP:
    CALL TEMP_ReadAmbient       ; temperature_module.asm'den
    CALL TEMP_UpdateFanControl      ; temperature_module.asm'den
    
    ; Test: ambient temp'i PORTD'ye göster
    MOVF ambient_temp_int, W
    MOVWF PORTD
    
    CALL Delay_100ms
    GOTO READ_LOOP

    
    
    
;==========================================================
; PORT INITIALIZATION
;==========================================================
PortInit:
    BANKSEL TRISA
    MOVLW 0x01        ; RA0 giri? (ADC), di?erleri ç?k??
    MOVWF TRISA

    BANKSEL ADCON1
    ;MOVLW 0x8E        ; SADECE AN0 analog, saga yasli Vdd/Vss referans
    MOVLW 0x0E ; sola yasli
    MOVWF ADCON1

    BANKSEL ADCON0
    MOVLW 0x81        ; ADC ON, kanal AN0
    MOVWF ADCON0

    ; ---- PORTB Ayar? ----
    BANKSEL TRISB
    MOVLW 00000100B ; RB2 giri? (tach), RB0/RB1 ç?k??
    MOVWF TRISB

    ; ---- Port temizleme ----
    BANKSEL PORTA
    CLRF PORTA
    CLRF PORTB

    RETURN




PSECT code

Delay_100ms:
        MOVLW   200        ; d?? döngü
        MOVWF   delay_outer
Delay_Outer_Loop:
        MOVLW   250        ; iç döngü
        MOVWF   delay_inner
Delay_Inner_Loop:
        DECFSZ  delay_inner, F
        GOTO    Delay_Inner_Loop

        DECFSZ  delay_outer, F
        GOTO    Delay_Outer_Loop

        RETURN


    END