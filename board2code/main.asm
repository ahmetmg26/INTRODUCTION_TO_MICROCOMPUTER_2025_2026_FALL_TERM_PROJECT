;====================================================================
; DOSYA: main.asm
; PROJE: BOARD #2 - FINAL CODE
;====================================================================
; BAGLANTILAR:
; LCD: RS->RE0, E->RE1, RW->RB7, D4-D7->RD4-RD7
; SENSORLER: RA0(LDR), RA1(POT)
; MOTOR: RB0-RB3
;====================================================================

    LIST P=16F877A
    #INCLUDE <P16F877A.INC>

    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF & _CP_OFF

;====================================================================
; DEGISKENLER
;====================================================================

    CBLOCK 0x20
        LCD_TEMP, D1, D2
        LIGHT_VAL         ; Light intensity (R2.2.2-1)
        POT_VAL           ; Potentiometer value
        ; Outdoor temperature and pressure (R2.2.3-1, R2.2.3-2) - same address
        OUTDOOR_TEMP      ; Use this for both temperature and pressure
        LIGHT_THRESHOLD
        ; MOTOR
        MOTOR_STEP_IDX, MOTOR_MASK
        ; Curtain status (R2.2.1-1) and light/rotary output (R2.2.2-2, R2.2.4-1) - same address
        CURTAIN_POS_H
        CURTAIN_POS_L     ; This will be used for curtain status, light, and rotary
        TARGET_POS_H, TARGET_POS_L
        ; HESAPLAMA
        TEMP_H, TEMP_L, PERCENTAGE
        DECIMAL_PART    ; <--- YENI DEGISKEN (Ondalik Kisim icin)
        ; BCD
        BCD_THOUSANDS, BCD_HUNDREDS, BCD_TENS, BCD_UNITS
        LOOP_COUNTER
    ENDC

    ; Alias definitions for requirements (EQU ile ayn? adres)
    OUTDOOR_PRESSURE   EQU OUTDOOR_TEMP      ; R2.2.3-2
    CURTAIN_STATUS     EQU CURTAIN_POS_L     ; R2.2.1-1
    LIGHT_OUTPUT       EQU CURTAIN_POS_L     ; R2.2.2-2
    ROTARY_OUTPUT      EQU CURTAIN_POS_L     ; R2.2.4-1

    #DEFINE LCD_RS PORTE, 0
    #DEFINE LCD_E  PORTE, 1
    #DEFINE LCD_RW PORTB, 7

    ORG     0x00
    GOTO    MAIN

MAIN:
    ;--- PORT AYARLARI ---
    BANKSEL ADCON1
    MOVLW   b'00000100' ; RA0, RA1 Analog (Sola Dayal?)
    MOVWF   ADCON1
    BANKSEL TRISA
    BSF     TRISA, 0
    BSF     TRISA, 1
    BANKSEL TRISB
    CLRF    TRISB
    BANKSEL TRISD
    CLRF    TRISD
    CLRF    TRISE
    BANKSEL ADCON0
    MOVLW   b'10000001'
    MOVWF   ADCON0
    BANKSEL PORTA
    CLRF    PORTB
    CLRF    PORTD
    CLRF    PORTE
    
    ;--- BA?LANGI? ---
    CLRF    MOTOR_STEP_IDX
    CLRF    CURTAIN_POS_H 
    CLRF    CURTAIN_POS_L
    CLRF    BCD_THOUSANDS
    
    MOVLW   d'100'        ; E?ik De?eri
    MOVWF   LIGHT_THRESHOLD
    MOVLW   d'50'
    MOVWF   LOOP_COUNTER

    CALL    LCD_INIT
    CALL    DRAW_STATIC_SCREEN

;====================================================================
; ANA DONGU
;====================================================================
LOOP:
    CALL    READ_SENSORS
    CALL    DETERMINE_TARGET
    CALL    PROCESS_MOVEMENT
    
    DECFSZ  LOOP_COUNTER, F
    GOTO    SKIP_LCD
    MOVLW   d'50'
    MOVWF   LOOP_COUNTER
    CALL    UPDATE_SCREEN
SKIP_LCD:
    CALL    DELAY_MOTOR
    GOTO    LOOP

;====================================================================
; SENSORLER
;====================================================================
READ_SENSORS:
    ; LDR OKU
    BCF     ADCON0, CHS2
    BCF     ADCON0, CHS1
    BCF     ADCON0, CHS0
    CALL    DELAY_ADC
    BSF     ADCON0, GO
W_LDR:
    BTFSC   ADCON0, GO
    GOTO    W_LDR
    MOVF    ADRESH, W
    MOVWF   LIGHT_VAL
    
    ; POT OKU
    BCF     ADCON0, CHS2
    BCF     ADCON0, CHS1
    BSF     ADCON0, CHS0
    CALL    DELAY_ADC
    BSF     ADCON0, GO
W_POT:
    BTFSC   ADCON0, GO
    GOTO    W_POT
    MOVF    ADRESH, W
    MOVWF   POT_VAL
    RETURN

;====================================================================
; HEDEF BELIRLEME
;====================================================================
DETERMINE_TARGET:
    ; 1. Karanlik mi?
    MOVF    LIGHT_VAL, W
    SUBWF   LIGHT_THRESHOLD, W
    BTFSC   STATUS, C
    GOTO    MODE_NIGHT
    GOTO    MODE_MANUAL

MODE_NIGHT:
    ; Karanlik -> Tam Kapat (%100 = 1000 Adim)
    MOVLW   HIGH d'1000'
    MOVWF   TARGET_POS_H
    MOVLW   LOW  d'1000'
    MOVWF   TARGET_POS_L
    RETURN

MODE_MANUAL:
    ; Aydinlik -> Potansiyometre -> Hedef
    CLRF    TARGET_POS_H
    MOVF    POT_VAL, W
    MOVWF   TARGET_POS_L
    
    ; Pot * 4
    BCF     STATUS, C
    RLF     TARGET_POS_L, F
    RLF     TARGET_POS_H, F ; x2
    BCF     STATUS, C
    RLF     TARGET_POS_L, F
    RLF     TARGET_POS_H, F ; x4
    
    ; Sinir Kontrolu (1000)
    MOVF    TARGET_POS_H, W
    SUBLW   0x03
    BTFSS   STATUS, C
    GOTO    LIMIT_MAX
    MOVF    TARGET_POS_H, W
    XORLW   0x03
    BTFSS   STATUS, Z
    RETURN
    MOVLW   0xE8
    SUBWF   TARGET_POS_L, W
    BTFSS   STATUS, C
    GOTO    LIMIT_MAX
    RETURN

LIMIT_MAX:
    MOVLW   HIGH d'1000'
    MOVWF   TARGET_POS_H
    MOVLW   LOW  d'1000'
    MOVWF   TARGET_POS_L
    RETURN

;====================================================================
; MOTOR HAREKETI
;====================================================================
PROCESS_MOVEMENT:
    MOVF    CURTAIN_POS_H, W
    XORWF   TARGET_POS_H, W
    BTFSS   STATUS, Z
    GOTO    CHECK_DIR
    MOVF    CURTAIN_POS_L, W
    XORWF   TARGET_POS_L, W
    BTFSC   STATUS, Z
    RETURN  ; Dur

CHECK_DIR:
    MOVF    CURTAIN_POS_L, W
    SUBWF   TARGET_POS_L, W
    MOVF    CURTAIN_POS_H, W
    BTFSS   STATUS, C
    ADDLW   1
    SUBWF   TARGET_POS_H, W
    
    BTFSS   STATUS, C       ; C=0 ise Mevcut > Hedef (Aciliyor)
    GOTO    ACTION_OPEN
    
    CALL    STEP_CCW        ; Kapat (CCW)
    INCF    CURTAIN_POS_L, F
    BTFSC   STATUS, Z
    INCF    CURTAIN_POS_H, F
    RETURN

ACTION_OPEN:
    CALL    STEP_CW         ; Ac (CW)
    MOVF    CURTAIN_POS_L, W
    BTFSC   STATUS, Z
    DECF    CURTAIN_POS_H, F
    DECF    CURTAIN_POS_L, F
    RETURN

;--- MOTOR SURUCU ---
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
    RETLW   b'00000001'
    RETLW   b'00000010'
    RETLW   b'00000100'
    RETLW   b'00001000'

;====================================================================
; EKRAN GUNCELLEME
;====================================================================
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
    ; Ornek: 125 Adim -> 125 / 10 = 12 (Tam), Kalan 5 (Ondalik) -> %12.5
    
    CLRF    PERCENTAGE
    CLRF    DECIMAL_PART
    
    MOVF    CURTAIN_POS_L, W
    MOVWF   TEMP_L
    MOVF    CURTAIN_POS_H, W
    MOVWF   TEMP_H
    
CALC_PCT:
    ; 10'dan kucuk kalana kadar cikar
    MOVF    TEMP_H, W
    BTFSS   STATUS, Z
    GOTO    SUB_10
    MOVLW   d'10'
    SUBWF   TEMP_L, W
    BTFSS   STATUS, C       ; Eger TEMP_L < 10 ise C=0 olur
    GOTO    FINISH_CALC     ; Dongu bitti
    
SUB_10:
    MOVLW   d'10'
    SUBWF   TEMP_L, F
    BTFSS   STATUS, C       ; Borc var mi?
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
    
    ; Yuzde isareti
    MOVLW   '%'
    CALL    SEND_CHAR
    RETURN

SHOW_3DIGIT:
    MOVWF   BCD_UNITS
    CLRF    BCD_HUNDREDS
    CLRF    BCD_TENS
CALC_100:
    MOVLW   d'100'
    SUBWF   BCD_UNITS, W
    BTFSS   STATUS, C
    GOTO    CALC_10
    MOVWF   BCD_UNITS
    INCF    BCD_HUNDREDS, F
    GOTO    CALC_100
CALC_10:
    MOVLW   d'10'
    SUBWF   BCD_UNITS, W
    BTFSS   STATUS, C
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
    BCF     LCD_RW
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
    BCF     LCD_RS
    GOTO    S_COM
SEND_CHAR:
    MOVWF   LCD_TEMP
    BSF     LCD_RS
    GOTO    S_COM
S_COM:
    BCF     LCD_RW
    MOVF    LCD_TEMP, W
    ANDLW   0xF0
    MOVWF   PORTD
    BSF     LCD_E
    NOP
    BCF     LCD_E
    SWAPF   LCD_TEMP, W
    ANDLW   0xF0
    MOVWF   PORTD
    BSF     LCD_E
    NOP
    BCF     LCD_E
    CALL    DELAY_SHORT
    RETURN

RAW_NIB:
    MOVWF   D1
    SWAPF   D1, W
    ANDLW   0xF0
    MOVWF   PORTD
    BSF     LCD_E
    NOP
    BCF     LCD_E
    CALL    DELAY_LONG
    RETURN

;--- GECIKMELER ---
DELAY_ADC:
    MOVLW   d'10'
    MOVWF   D1
ADC_LOOP: 
    DECFSZ  D1, F
    GOTO    ADC_LOOP
    RETURN

DELAY_MOTOR:
    MOVLW   d'50'
    MOVWF   D2
DM_OUTER:
    MOVLW   d'255'
    MOVWF   D1
DM_INNER:
    DECFSZ  D1, F
    GOTO    DM_INNER
    DECFSZ  D2, F
    GOTO    DM_OUTER
    RETURN

DELAY_SHORT:
    MOVLW   d'10'
    MOVWF   D1
SHRT_LOOP: 
    DECFSZ  D1, F
    GOTO    SHRT_LOOP
    RETURN

DELAY_LONG:
    MOVLW   d'100'
    MOVWF   D1
LNG_LOOP: 
    DECFSZ  D1, F
    GOTO    LNG_LOOP
    RETURN

    END