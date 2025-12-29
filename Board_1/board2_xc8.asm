; ====================================================================
; DOSYA: board2_xc8.asm
; PROJE: BOARD #2 - FINAL CODE (XC8 Uyumlu)
; ====================================================================
; BAGLANTILAR:
; LCD: RS->RE0, E->RE1, RW->RB7, D4-D7->RD4-RD7
; SENSORLER: RA0(LDR), RA1(POT)
; MOTOR: RB0-RB3
; ====================================================================

PROCESSOR 16F877A
#include <xc.inc>

CONFIG FOSC=HS, WDTE=OFF, PWRTE=ON, BOREN=OFF, LVP=OFF, CPD=OFF, WRT=OFF, CP=OFF

; ====================================================================
; DEGISKENLER - Sabit adresler (MPASM uyumlu)
; ====================================================================
LCD_TEMP        EQU 0x20
D1              EQU 0x21
D2              EQU 0x22
LIGHT_VAL       EQU 0x23
POT_VAL         EQU 0x24
LIGHT_THRESHOLD EQU 0x25
MOTOR_STEP_IDX  EQU 0x26
MOTOR_MASK      EQU 0x27
CURTAIN_POS_H   EQU 0x28
CURTAIN_POS_L   EQU 0x29
TARGET_POS_H    EQU 0x2A
TARGET_POS_L    EQU 0x2B
TEMP_H          EQU 0x2C
TEMP_L          EQU 0x2D
PERCENTAGE      EQU 0x2E
DECIMAL_PART    EQU 0x2F
BCD_THOUSANDS   EQU 0x30
BCD_HUNDREDS    EQU 0x31
BCD_TENS        EQU 0x32
BCD_UNITS       EQU 0x33
LOOP_COUNTER    EQU 0x34

PSECT resetVec, class=CODE, delta=2
    ORG 0x00
    GOTO MAIN

PSECT code

MAIN:
    ; --- PORT AYARLARI ---
    BSF     STATUS, 5       ; Bank 1
    MOVLW   0b00000100      ; RA0, RA1 Analog (Sola Dayali)
    MOVWF   ADCON1
    BSF     TRISA, 0
    BSF     TRISA, 1
    CLRF    TRISB
    CLRF    TRISD
    CLRF    TRISE
    BCF     STATUS, 5       ; Bank 0
    
    MOVLW   0b10000001
    MOVWF   ADCON0
    CLRF    PORTB
    CLRF    PORTD
    CLRF    PORTE
    
    ; --- BASLANGIC ---
    CLRF    MOTOR_STEP_IDX
    CLRF    CURTAIN_POS_H 
    CLRF    CURTAIN_POS_L
    CLRF    BCD_THOUSANDS
    
    MOVLW   100             ; Esik Degeri
    MOVWF   LIGHT_THRESHOLD
    MOVLW   50
    MOVWF   LOOP_COUNTER

    CALL    LCD_INIT
    CALL    DRAW_STATIC_SCREEN

; ====================================================================
; ANA DONGU
; ====================================================================
LOOP:
    CALL    READ_SENSORS
    CALL    DETERMINE_TARGET
    CALL    PROCESS_MOVEMENT
    
    DECFSZ  LOOP_COUNTER, F
    GOTO    SKIP_LCD
    MOVLW   50
    MOVWF   LOOP_COUNTER
    CALL    UPDATE_SCREEN
SKIP_LCD:
    CALL    DELAY_MOTOR
    GOTO    LOOP

; ====================================================================
; SENSORLER
; ====================================================================
READ_SENSORS:
    ; LDR OKU
    BCF     ADCON0, 5       ; CHS2
    BCF     ADCON0, 4       ; CHS1
    BCF     ADCON0, 3       ; CHS0
    CALL    DELAY_ADC
    BSF     ADCON0, 2       ; GO
W_LDR:
    BTFSC   ADCON0, 2
    GOTO    W_LDR
    MOVF    ADRESH, W
    MOVWF   LIGHT_VAL
    
    ; POT OKU
    BCF     ADCON0, 5       ; CHS2
    BCF     ADCON0, 4       ; CHS1
    BSF     ADCON0, 3       ; CHS0
    CALL    DELAY_ADC
    BSF     ADCON0, 2       ; GO
W_POT:
    BTFSC   ADCON0, 2
    GOTO    W_POT
    MOVF    ADRESH, W
    MOVWF   POT_VAL
    RETURN

; ====================================================================
; HEDEF BELIRLEME
; ====================================================================
DETERMINE_TARGET:
    ; 1. Karanlik mi?
    MOVF    LIGHT_VAL, W
    SUBWF   LIGHT_THRESHOLD, W
    BTFSC   STATUS, 0       ; C bit
    GOTO    MODE_NIGHT
    GOTO    MODE_MANUAL

MODE_NIGHT:
    ; Karanlik -> Tam Kapat (%100 = 1000 Adim)
    MOVLW   0x03            ; HIGH 1000
    MOVWF   TARGET_POS_H
    MOVLW   0xE8            ; LOW 1000
    MOVWF   TARGET_POS_L
    RETURN

MODE_MANUAL:
    ; Aydinlik -> Potansiyometre -> Hedef
    CLRF    TARGET_POS_H
    MOVF    POT_VAL, W
    MOVWF   TARGET_POS_L
    
    ; Pot * 4
    BCF     STATUS, 0       ; C
    RLF     TARGET_POS_L, F
    RLF     TARGET_POS_H, F ; x2
    BCF     STATUS, 0       ; C
    RLF     TARGET_POS_L, F
    RLF     TARGET_POS_H, F ; x4
    
    ; Sinir Kontrolu (1000)
    MOVF    TARGET_POS_H, W
    SUBLW   0x03
    BTFSS   STATUS, 0       ; C
    GOTO    LIMIT_MAX
    MOVF    TARGET_POS_H, W
    XORLW   0x03
    BTFSS   STATUS, 2       ; Z
    RETURN
    MOVLW   0xE8
    SUBWF   TARGET_POS_L, W
    BTFSS   STATUS, 0       ; C
    GOTO    LIMIT_MAX
    RETURN

LIMIT_MAX:
    MOVLW   0x03            ; HIGH 1000
    MOVWF   TARGET_POS_H
    MOVLW   0xE8            ; LOW 1000
    MOVWF   TARGET_POS_L
    RETURN

; ====================================================================
; MOTOR HAREKETI
; ====================================================================
PROCESS_MOVEMENT:
    MOVF    CURTAIN_POS_H, W
    XORWF   TARGET_POS_H, W
    BTFSS   STATUS, 2       ; Z
    GOTO    CHECK_DIR
    MOVF    CURTAIN_POS_L, W
    XORWF   TARGET_POS_L, W
    BTFSC   STATUS, 2       ; Z
    RETURN                  ; Dur

CHECK_DIR:
    MOVF    CURTAIN_POS_L, W
    SUBWF   TARGET_POS_L, W
    MOVF    CURTAIN_POS_H, W
    BTFSS   STATUS, 0       ; C
    ADDLW   1
    SUBWF   TARGET_POS_H, W
    
    BTFSS   STATUS, 0       ; C=0 ise Mevcut > Hedef (Aciliyor)
    GOTO    ACTION_OPEN
    
    CALL    STEP_CCW        ; Kapat (CCW)
    INCF    CURTAIN_POS_L, F
    BTFSC   STATUS, 2       ; Z
    INCF    CURTAIN_POS_H, F
    RETURN

ACTION_OPEN:
    CALL    STEP_CW         ; Ac (CW)
    MOVF    CURTAIN_POS_L, W
    BTFSC   STATUS, 2       ; Z
    DECF    CURTAIN_POS_H, F
    DECF    CURTAIN_POS_L, F
    RETURN

; --- MOTOR SURUCU ---
STEP_CW:
    INCF    MOTOR_STEP_IDX, F
    GOTO    APPLY_STEP
STEP_CCW:
    DECF    MOTOR_STEP_IDX, F
APPLY_STEP:
    MOVF    MOTOR_STEP_IDX, W
    ANDLW   0x03
    CALL    GET_STEP_BITS
    MOVWF   MOTOR_MASK
    MOVF    PORTB, W
    ANDLW   0xF0
    IORWF   MOTOR_MASK, W
    MOVWF   PORTB
    RETURN

GET_STEP_BITS:
    ADDWF   PCL, F
    RETLW   0b00000001
    RETLW   0b00000010
    RETLW   0b00000100
    RETLW   0b00001000

; ====================================================================
; EKRAN GUNCELLEME
; ====================================================================
UPDATE_SCREEN:
    ; --- LDR ---
    MOVLW   0xC0
    CALL    SEND_CMD
    MOVF    LIGHT_VAL, W
    CALL    SHOW_3DIGIT
    MOVLW   '.'
    CALL    SEND_CHAR
    MOVF    LIGHT_VAL, W
    ANDLW   0x07
    ADDLW   '0'
    CALL    SEND_CHAR
    MOVLW   'L'
    CALL    SEND_CHAR
    MOVLW   ' '
    CALL    SEND_CHAR
    
    ; --- YUZDE HESABI (Adim / 10 = Yuzde) ---
    CLRF    PERCENTAGE
    CLRF    DECIMAL_PART
    
    MOVF    CURTAIN_POS_L, W
    MOVWF   TEMP_L
    MOVF    CURTAIN_POS_H, W
    MOVWF   TEMP_H
    
CALC_PCT:
    ; 10'dan kucuk kalana kadar cikar
    MOVF    TEMP_H, W
    BTFSS   STATUS, 2       ; Z
    GOTO    SUB_10
    MOVLW   10
    SUBWF   TEMP_L, W
    BTFSS   STATUS, 0       ; Eger TEMP_L < 10 ise C=0 olur
    GOTO    FINISH_CALC     ; Dongu bitti
    
SUB_10:
    MOVLW   10
    SUBWF   TEMP_L, F
    BTFSS   STATUS, 0       ; Borc var mi?
    DECF    TEMP_H, F
    INCF    PERCENTAGE, F   ; Tam kismi artir
    GOTO    CALC_PCT

FINISH_CALC:
    ; Dongu bittiginde TEMP_L icinde kalan sayi (0-9) bizim ondalik kismimizdir!
    MOVF    TEMP_L, W
    MOVWF   DECIMAL_PART
    
SHOW_PCT:
    ; Tam Kisim
    MOVF    PERCENTAGE, W
    CALL    SHOW_3DIGIT
    
    ; Nokta
    MOVLW   '.'
    CALL    SEND_CHAR
    
    ; Ondalik Kisim (Canli Kalan Deger)
    MOVF    DECIMAL_PART, W
    ADDLW   '0'             ; ASCII yap
    CALL    SEND_CHAR
    
    ; Yuzde Isareti
    MOVLW   '%'
    CALL    SEND_CHAR
    RETURN

SHOW_3DIGIT:
    MOVWF   BCD_UNITS
    CLRF    BCD_HUNDREDS
    CLRF    BCD_TENS
CALC_100:
    MOVLW   100
    SUBWF   BCD_UNITS, W
    BTFSS   STATUS, 0       ; C
    GOTO    CALC_10
    MOVWF   BCD_UNITS
    INCF    BCD_HUNDREDS, F
    GOTO    CALC_100
CALC_10:
    MOVLW   10
    SUBWF   BCD_UNITS, W
    BTFSS   STATUS, 0       ; C
    GOTO    SHOW_D
    MOVWF   BCD_UNITS
    INCF    BCD_TENS, F
    GOTO    CALC_10
SHOW_D:
    MOVF    BCD_HUNDREDS, W
    ADDLW   '0'
    CALL    SEND_CHAR
    MOVF    BCD_TENS, W
    ADDLW   '0'
    CALL    SEND_CHAR
    MOVF    BCD_UNITS, W
    ADDLW   '0'
    CALL    SEND_CHAR
    RETURN

DRAW_STATIC_SCREEN:
    MOVLW   0x80
    CALL    SEND_CMD
    MOVLW   '+'
    CALL    SEND_CHAR
    MOVLW   '2'
    CALL    SEND_CHAR
    MOVLW   '5'
    CALL    SEND_CHAR
    MOVLW   '.'
    CALL    SEND_CHAR
    MOVLW   '0'
    CALL    SEND_CHAR
    MOVLW   ' '
    CALL    SEND_CHAR
    MOVLW   'C'
    CALL    SEND_CHAR
    MOVLW   ' '
    CALL    SEND_CHAR
    MOVLW   '1'
    CALL    SEND_CHAR
    MOVLW   '0'
    CALL    SEND_CHAR
    MOVLW   '1'
    CALL    SEND_CHAR
    MOVLW   '3'
    CALL    SEND_CHAR
    MOVLW   'h'
    CALL    SEND_CHAR
    MOVLW   'P'
    CALL    SEND_CHAR
    MOVLW   'a'
    CALL    SEND_CHAR
    RETURN

LCD_INIT:
    CALL    DELAY_LONG
    BCF     PORTB, 7        ; LCD_RW
    MOVLW   0x03
    CALL    RAW_NIB
    MOVLW   0x03
    CALL    RAW_NIB
    MOVLW   0x03
    CALL    RAW_NIB
    MOVLW   0x02
    CALL    RAW_NIB
    MOVLW   0x28
    CALL    SEND_CMD
    MOVLW   0x0C
    CALL    SEND_CMD
    MOVLW   0x06
    CALL    SEND_CMD
    MOVLW   0x01
    CALL    SEND_CMD
    RETURN

SEND_CMD:
    MOVWF   LCD_TEMP
    BCF     PORTE, 0        ; LCD_RS
    GOTO    S_COM
SEND_CHAR:
    MOVWF   LCD_TEMP
    BSF     PORTE, 0        ; LCD_RS
    GOTO    S_COM
S_COM:
    BCF     PORTB, 7        ; LCD_RW
    MOVF    LCD_TEMP, W
    ANDLW   0xF0
    MOVWF   PORTD
    BSF     PORTE, 1        ; LCD_E
    NOP
    BCF     PORTE, 1        ; LCD_E
    SWAPF   LCD_TEMP, W
    ANDLW   0xF0
    MOVWF   PORTD
    BSF     PORTE, 1        ; LCD_E
    NOP
    BCF     PORTE, 1        ; LCD_E
    CALL    DELAY_SHORT
    RETURN

RAW_NIB:
    MOVWF   D1
    SWAPF   D1, W
    ANDLW   0xF0
    MOVWF   PORTD
    BSF     PORTE, 1        ; LCD_E
    NOP
    BCF     PORTE, 1        ; LCD_E
    CALL    DELAY_LONG
    RETURN

; --- GECIKMELER ---
DELAY_ADC:
    MOVLW   10
    MOVWF   D1
ADC_LOOP: 
    DECFSZ  D1, F
    GOTO    ADC_LOOP
    RETURN

DELAY_MOTOR:
    MOVLW   50
    MOVWF   D2
DM_OUTER:
    MOVLW   255
    MOVWF   D1
DM_INNER:
    DECFSZ  D1, F
    GOTO    DM_INNER
    DECFSZ  D2, F
    GOTO    DM_OUTER
    RETURN

DELAY_SHORT:
    MOVLW   10
    MOVWF   D1
SHRT_LOOP: 
    DECFSZ  D1, F
    GOTO    SHRT_LOOP
    RETURN

DELAY_LONG:
    MOVLW   100
    MOVWF   D1
LNG_LOOP: 
    DECFSZ  D1, F
    GOTO    LNG_LOOP
    RETURN

    END
