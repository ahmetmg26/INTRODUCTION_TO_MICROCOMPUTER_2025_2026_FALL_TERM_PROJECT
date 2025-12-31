;====================================================================
; DOSYA: main.asm
; PROJE: BOARD #2 - FINAL CODE
;====================================================================
; BA?LANTILAR:
; LCD: RS->RE0, E->RE1, RW->RB7, D4-D7->RD4-RD7
; SENSÖRLER: RA0(LDR), RA1(POT)
; MOTOR: RB0-RB3
;====================================================================

    LIST P=16F877A
    #INCLUDE <P16F877A.INC>

    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF & _CP_OFF

;====================================================================
; DE???KENLER
;====================================================================
    CBLOCK 0x20
        LCD_TEMP, D1, D2
        LIGHT_VAL, POT_VAL, LIGHT_THRESHOLD
        
        ; MOTOR
        MOTOR_STEP_IDX, MOTOR_MASK
        
        ; KONUM (16-bit)
        CURTAIN_POS_H, CURTAIN_POS_L
        TARGET_POS_H, TARGET_POS_L
        
        ; HESAPLAMA
        TEMP_H, TEMP_L, PERCENTAGE
        DECIMAL_PART
        
        ; BCD
        BCD_THOUSANDS, BCD_HUNDREDS, BCD_TENS, BCD_UNITS
        
        LOOP_COUNTER
        
        ; UART
        UART_RX_BYTE
        UART_OVERRIDE       ; 1 = UART kontrolu, 0 = otomatik kontrol
        
        ; Outdoor Temperature (sabit 25.0 C)
        OUTDOOR_TEMP_INT, OUTDOOR_TEMP_FRAC
        
        ; Outdoor Pressure (sabit 1013 hPa)
        OUTDOOR_PRESS_H, OUTDOOR_PRESS_L, OUTDOOR_PRESS_FRAC
        
        ; Desired Curtain Status
        DESIRED_CURTAIN_INT, DESIRED_CURTAIN_FRAC
    ENDC

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
    
    ;--- BA?LANGIÇ ---
    CLRF    MOTOR_STEP_IDX
    CLRF    CURTAIN_POS_H 
    CLRF    CURTAIN_POS_L
    CLRF    BCD_THOUSANDS
    
    MOVLW   d'100'        ; Esik Degeri
    MOVWF   LIGHT_THRESHOLD
    MOVLW   d'50'
    MOVWF   LOOP_COUNTER
    
    ; Outdoor Temperature: 25.0 C
    MOVLW   d'25'
    MOVWF   OUTDOOR_TEMP_INT
    CLRF    OUTDOOR_TEMP_FRAC
    
    ; Outdoor Pressure: 1013.0 hPa (HIGH=3, LOW=245 -> 3*256+245=1013)
    MOVLW   d'3'
    MOVWF   OUTDOOR_PRESS_H
    MOVLW   d'245'
    MOVWF   OUTDOOR_PRESS_L
    CLRF    OUTDOOR_PRESS_FRAC
    
    ; Desired Curtain: 0%
    CLRF    DESIRED_CURTAIN_INT
    CLRF    DESIRED_CURTAIN_FRAC
    
    ; UART override: 0 = otomatik, 1 = UART kontrolu
    CLRF    UART_OVERRIDE

    CALL    LCD_INIT
    CALL    UART_INIT       ; UART baslat
    CALL    DRAW_STATIC_SCREEN

;====================================================================
; ANA DÖNGÜ
;====================================================================
LOOP:
    CALL    UART_CHECK      ; UART komut kontrolu
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
; SENSÖRLER
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
    ; UART override kontrolu - eger UART_OVERRIDE=1 ise hedefi degistirme
    MOVF    UART_OVERRIDE, W
    BTFSS   STATUS, Z       ; Z=0 ise UART_OVERRIDE != 0
    RETURN                  ; UART kontrolu aktif, cik
    
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
    ; Ayd?nl?k -> Potansiyometre -> Hedef
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
    
    ; S?n?r Kontrolü (1000)
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
; MOTOR HAREKET?
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
    
    BTFSS   STATUS, C       ; C=0 ise Mevcut > Hedef (Aç?l?yor)
    GOTO    ACTION_OPEN
    
    CALL    STEP_CCW        ; Kapat (CCW)
    INCF    CURTAIN_POS_L, F
    BTFSC   STATUS, Z
    INCF    CURTAIN_POS_H, F
    RETURN

ACTION_OPEN:
    CALL    STEP_CW         ; Aç (CW)
    MOVF    CURTAIN_POS_L, W
    BTFSC   STATUS, Z
    DECF    CURTAIN_POS_H, F
    DECF    CURTAIN_POS_L, F
    RETURN

;--- MOTOR SÜRÜCÜ ---
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
; EKRAN GÜNCELLEME
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
    
    ; --- YÜZDE HESABI (Ad?m / 10 = Yüzde) ---
    ; Örn: 125 Ad?m -> 125 / 10 = 12 (Tam), Kalan 5 (Ondal?k) -> %12.5
    
    CLRF    PERCENTAGE
    CLRF    DECIMAL_PART
    
    MOVF    CURTAIN_POS_L, W
    MOVWF   TEMP_L
    MOVF    CURTAIN_POS_H, W
    MOVWF   TEMP_H
    
CALC_PCT:
    ; 10'dan küçük kalana kadar ç?kar
    MOVF    TEMP_H, W
    BTFSS   STATUS, Z
    GOTO    SUB_10
    MOVLW   d'10'
    SUBWF   TEMP_L, W
    BTFSS   STATUS, C       ; E?er TEMP_L < 10 ise C=0 olur
    GOTO    FINISH_CALC     ; Döngü bitti
    
SUB_10:
    MOVLW   d'10'
    SUBWF   TEMP_L, F
    BTFSS   STATUS, C       ; Borç var m??
    DECF    TEMP_H, F
    INCF    PERCENTAGE, F   ; Tam k?sm? art?r
    GOTO    CALC_PCT

FINISH_CALC:
    ; Döngü bitti?inde TEMP_L içinde kalan say? (0-9) bizim ondal?k k?sm?m?zd?r!
    MOVF    TEMP_L, W
    MOVWF   DECIMAL_PART
    
SHOW_PCT:
    ; Tam K?s?m
    MOVF    PERCENTAGE, W
    CALL    SHOW_3DIGIT
    
    ; Nokta
    MOVLW   '.'
    CALL    SEND_CHAR
    
    ; Ondal?k K?s?m (Canl? Kalan De?er)
    MOVF    DECIMAL_PART, W
    ADDLW   '0'             ; ASCII yap
    CALL    SEND_CHAR
    
    ; Yüzde ??areti
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

;--- GEC?KMELER ---
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

;====================================================================
; UART FONKSIYONLARI
; Protokol:
;   GET: 0x01=LDR, 0x02=Position(%), 0x03=Position(decimal)
;   SET: 0x80|value = Hedef pozisyon ayarla (0-100)
;====================================================================
UART_INIT:
    ; 9600 baud @ 4MHz
    BANKSEL TRISC
    BSF     TRISC, 7        ; RC7 = RX (giris)
    BCF     TRISC, 6        ; RC6 = TX (cikis)
    
    BANKSEL SPBRG
    MOVLW   d'25'           ; 9600 baud @ 4MHz
    MOVWF   SPBRG
    
    BANKSEL TXSTA
    MOVLW   b'00100100'     ; TX enable, BRGH=1, Async
    MOVWF   TXSTA
    
    BANKSEL RCSTA
    MOVLW   b'10010000'     ; Serial enable, RX enable
    MOVWF   RCSTA
    
    BANKSEL PORTA
    RETURN

UART_CHECK:
    ; Veri var mi kontrol et
    BANKSEL PIR1
    BTFSS   PIR1, RCIF      ; RCIF set mi?
    GOTO    UART_EXIT
    
    ; Overrun error kontrolu
    BANKSEL RCSTA
    BTFSC   RCSTA, OERR
    GOTO    UART_CLEAR_OERR
    
    ; Veriyi oku
    BANKSEL RCREG
    MOVF    RCREG, W
    BANKSEL UART_RX_BYTE
    MOVWF   UART_RX_BYTE
    
    ; Komut analizi
    ; Bit 7 = 1 ise SET komutu
    BTFSC   UART_RX_BYTE, 7
    GOTO    UART_SET_CMD
    
    ; GET komutlari (0x01-0x08)
    MOVF    UART_RX_BYTE, W
    XORLW   0x01            ; 0x01 = Get curtain status frac
    BTFSC   STATUS, Z
    GOTO    CMD_GET_CURTAIN_FRAC
    
    MOVF    UART_RX_BYTE, W
    XORLW   0x02            ; 0x02 = Get curtain status int
    BTFSC   STATUS, Z
    GOTO    CMD_GET_CURTAIN_INT
    
    MOVF    UART_RX_BYTE, W
    XORLW   0x03            ; 0x03 = Get outdoor temp frac
    BTFSC   STATUS, Z
    GOTO    CMD_GET_TEMP_FRAC
    
    MOVF    UART_RX_BYTE, W
    XORLW   0x04            ; 0x04 = Get outdoor temp int
    BTFSC   STATUS, Z
    GOTO    CMD_GET_TEMP_INT
    
    MOVF    UART_RX_BYTE, W
    XORLW   0x05            ; 0x05 = Get outdoor pressure frac
    BTFSC   STATUS, Z
    GOTO    CMD_GET_PRESS_FRAC
    
    MOVF    UART_RX_BYTE, W
    XORLW   0x06            ; 0x06 = Get outdoor pressure int
    BTFSC   STATUS, Z
    GOTO    CMD_GET_PRESS_INT
    
    MOVF    UART_RX_BYTE, W
    XORLW   0x07            ; 0x07 = Get light intensity frac
    BTFSC   STATUS, Z
    GOTO    CMD_GET_LIGHT_FRAC
    
    MOVF    UART_RX_BYTE, W
    XORLW   0x08            ; 0x08 = Get light intensity int
    BTFSC   STATUS, Z
    GOTO    CMD_GET_LIGHT_INT
    
    GOTO    UART_EXIT

; --- GET KOMUTLARI ---
CMD_GET_CURTAIN_FRAC:
    ; Curtain status fractional (DECIMAL_PART)
    BANKSEL DECIMAL_PART
    MOVF    DECIMAL_PART, W
    CALL    UART_SEND_BYTE
    GOTO    UART_EXIT

CMD_GET_CURTAIN_INT:
    ; Curtain status integral (PERCENTAGE)
    BANKSEL PERCENTAGE
    MOVF    PERCENTAGE, W
    CALL    UART_SEND_BYTE
    GOTO    UART_EXIT

CMD_GET_TEMP_FRAC:
    ; Outdoor temperature fractional
    BANKSEL OUTDOOR_TEMP_FRAC
    MOVF    OUTDOOR_TEMP_FRAC, W
    CALL    UART_SEND_BYTE
    GOTO    UART_EXIT

CMD_GET_TEMP_INT:
    ; Outdoor temperature integral
    BANKSEL OUTDOOR_TEMP_INT
    MOVF    OUTDOOR_TEMP_INT, W
    CALL    UART_SEND_BYTE
    GOTO    UART_EXIT

CMD_GET_PRESS_FRAC:
    ; Outdoor pressure fractional
    BANKSEL OUTDOOR_PRESS_FRAC
    MOVF    OUTDOOR_PRESS_FRAC, W
    CALL    UART_SEND_BYTE
    GOTO    UART_EXIT

CMD_GET_PRESS_INT:
    ; Outdoor pressure integral (sadece LOW byte gonder, 0-255)
    BANKSEL OUTDOOR_PRESS_L
    MOVF    OUTDOOR_PRESS_L, W
    CALL    UART_SEND_BYTE
    GOTO    UART_EXIT

CMD_GET_LIGHT_FRAC:
    ; Light intensity fractional (0)
    MOVLW   0x00
    CALL    UART_SEND_BYTE
    GOTO    UART_EXIT

CMD_GET_LIGHT_INT:
    ; Light intensity integral (LDR value)
    BANKSEL LIGHT_VAL
    MOVF    LIGHT_VAL, W
    CALL    UART_SEND_BYTE
    GOTO    UART_EXIT

; --- SET KOMUTLARI ---
UART_SET_CMD:
    ; Bit 6 kontrol: 0=frac, 1=int
    BTFSC   UART_RX_BYTE, 6
    GOTO    CMD_SET_CURTAIN_INT
    
    ; SET curtain fractional (10xxxxxx)
    MOVF    UART_RX_BYTE, W
    ANDLW   0x3F            ; Alt 6 bit
    MOVWF   DESIRED_CURTAIN_FRAC
    GOTO    UART_EXIT

CMD_SET_CURTAIN_INT:
    ; SET curtain integral (11xxxxxx)
    MOVF    UART_RX_BYTE, W
    ANDLW   0x3F            ; Alt 6 bit (0-63, ama 0-100 kabul)
    MOVWF   DESIRED_CURTAIN_INT
    
    ; Hedef pozisyonu hesapla: DESIRED_CURTAIN_INT * 10
    ; (100% = 1000 adim)
    CLRF    TEMP_H
    MOVWF   TEMP_L
    
    ; * 10 = * 8 + * 2
    BCF     STATUS, C
    RLF     TEMP_L, F
    RLF     TEMP_H, F       ; x2
    
    MOVF    TEMP_L, W
    MOVWF   TARGET_POS_L
    MOVF    TEMP_H, W
    MOVWF   TARGET_POS_H    ; Kaydet (x2)
    
    ; x4 daha (toplam x8)
    BCF     STATUS, C
    RLF     TEMP_L, F
    RLF     TEMP_H, F       ; x4
    BCF     STATUS, C
    RLF     TEMP_L, F
    RLF     TEMP_H, F       ; x8
    
    ; x2 + x8 = x10
    MOVF    TARGET_POS_L, W
    ADDWF   TEMP_L, F
    BTFSC   STATUS, C
    INCF    TEMP_H, F
    MOVF    TARGET_POS_H, W
    ADDWF   TEMP_H, F
    
    ; Sonucu TARGET_POS'a yaz
    MOVF    TEMP_L, W
    MOVWF   TARGET_POS_L
    MOVF    TEMP_H, W
    MOVWF   TARGET_POS_H
    
    ; UART override aktif et - otomatik kontrolu devre disi birak
    MOVLW   0x01
    MOVWF   UART_OVERRIDE
    
    GOTO    UART_EXIT

UART_CLEAR_OERR:
    BANKSEL RCSTA
    BCF     RCSTA, CREN
    BSF     RCSTA, CREN
    BANKSEL RCREG
    MOVF    RCREG, W
    GOTO    UART_EXIT

UART_EXIT:
    BANKSEL PORTA
    RETURN

UART_SEND_BYTE:
    BANKSEL TXSTA
UART_TX_WAIT:
    BTFSS   TXSTA, TRMT     ; TX buffer bos mu?
    GOTO    UART_TX_WAIT
    BANKSEL TXREG
    MOVWF   TXREG
    BANKSEL PORTA
    RETURN

    END