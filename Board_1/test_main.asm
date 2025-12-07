;==========================================================
; MAIN.ASM - Variables + Main Program
;==========================================================
#include <xc.inc>
#include "temperature_module.asm" 
#include "sevenSegmentDisplay.asm"


    GLOBAL MAIN
    
    ;temperature degiskenler
    GLOBAL ambient_temp_int
    GLOBAL ambient_temp_frac
    
    GLOBAL desired_temp_int
    GLOBAL desired_temp_frac
    
    GLOBAL fan_rps
    GLOBAL temp_compare_result 
    
    ;7-seg-display degiskenler
    GLOBAL digitNum
    GLOBAL birler
    GLOBAL onlar
    GLOBAL digitNum
    GLOBAL digitOnes
    GLOBAL digitTens
    GLOBAL digitHundreds
    GLOBAL digitThousands
     

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

; temperature modul icin degiskenler
ambient_temp_int:      DS 1
ambient_temp_frac:     DS 1
desired_temp_int:      DS 1
desired_temp_frac:     DS 1
fan_rps:               DS 1
temp_compare_result:   DS 1
    delay_outer:    DS 1
    delay_inner:    DS 1
tach_counter:       DS 1

; 7-seg-display icin degiskenler
digitNum:  DS 1
digitOnes: DS 1
digitTens: DS 1
digitHundreds: DS 1
digitThousands: DS 1
birler: DS 1
onlar: DS 1
delay5ms_temp0: DS 1
delay5ms_temp1: DS 1


PSECT code
 
MAIN:
    CALL PortInit
    
    ; Ba?lang?ç de?erleri
    MOVLW 35
    BANKSEL desired_temp_int
    MOVWF desired_temp_int
    CLRF desired_temp_frac
    
READ_LOOP:
    CALL TEMP_ReadAmbient       ; temperature_module.asm'den
    CALL TEMP_UpdateFanControl      ; temperature_module.asm'den
    
    ; Test: desired temp'i 7-seg-display'e göster
    MOVF desired_temp_int,W ; W=desired_temp_int
    CALL digitlere_ayir ; burdan biler ve onlar belirlenir
    
    MOVF birler,W
    MOVWF digitHundreds
    MOVLW 3
    MOVWF digitNum
    CALL updateDisplay
    CALL delay5ms
    
    MOVF onlar,W
    MOVWF digitThousands
    MOVLW 4
    MOVWF digitNum
    CALL updateDisplay
    CALL delay5ms
    
    ; Test: desired_temp_frac degerini gonder
    MOVF desired_temp_frac,W ; W=desired_temp_int
    CALL digitlere_ayir ; burdan biler ve onlar belirlenir
    
    MOVF birler,W
    MOVWF digitOnes
    MOVLW 1
    MOVWF digitNum
    CALL updateDisplay
    CALL delay5ms
    
    MOVF onlar,W
    MOVWF digitTens
    MOVLW 2
    MOVWF digitNum
    CALL updateDisplay
    CALL delay5ms
    
    ;san?r?m boyle
    ;CALL Delay_100ms
    GOTO READ_LOOP

    
    
    
;==========================================================
; PORT INITIALIZATION
;==========================================================
PortInit:
    BANKSEL TRISA
    MOVLW 0x01        ; RA0 input -> ortam sicakligini okumak icin , input
    MOVWF TRISA	      ; RA1-RA4 -> 7-seg-display icin, D1-D4 portlari, output	

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
    
    ; -- 7-seg-display icin PORTD ayarlari -- 
    BANKSEL TRISD
    MOVLW 0x00  ; hepsi output olacak
    MOVWF TRISD
    
    
    ; ---- Port temizleme ----
    BANKSEL PORTA
    
    CLRF PORTA
    CLRF PORTB
    CLRF PORTD
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

delay5ms:
    MOVLW 13
    MOVWF delay5ms_temp1
    delay5ms_Loop1:
    DECFSZ delay5ms_temp1,f
    GOTO delay5ms_Loop2
    RETURN ; It took 5ms, time to return
    delay5ms_Loop2:
    MOVLW 135
    MOVWF delay5ms_temp0
    delay5ms_Loop3:
    DECFSZ delay5ms_temp0,f
    GOTO delay5ms_Loop3
    NOP
    GOTO delay5ms_Loop1

    END