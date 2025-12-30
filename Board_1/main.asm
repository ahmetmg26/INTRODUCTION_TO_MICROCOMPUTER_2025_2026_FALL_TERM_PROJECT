; BOARD 1 - Sicaklik Kontrol
; Heater=RA1, Cooler=RA2, Temp=RA0, Tach=RA4
; 7-Segment: RD0-RD7, Digits: RC0-RC3
; Keypad: RB0-RB3 rows, RB4-RB7 cols
; UART: RC6=TX, RC7=RX
;
; UART PROTOKOL (Binary Command-Response):
; PC -> PIC Komutlari:
;   0x01 = Get desired temp fractional
;   0x02 = Get desired temp integral
;   0x03 = Get ambient temp fractional
;   0x04 = Get ambient temp integral
;   0x05 = Get fan speed
;   10xxxxxx = Set desired temp fractional (6-bit deger)
;   11xxxxxx = Set desired temp integral (6-bit deger)

PROCESSOR 16F877A
#include <xc.inc>

CONFIG FOSC=XT, WDTE=OFF, PWRTE=ON, BOREN=ON, LVP=OFF
CONFIG CPD=OFF, WRT=OFF, CP=OFF

PSECT udata_bank0
    delay1:      DS 1
    disp_loop:   DS 1
    
    adc_val:     DS 1
    target_val:  DS 1
    target_decimal: DS 1
    fan_speed:   DS 1
    timer_tick:  DS 1
    tens:        DS 1
    ones:        DS 1
    decimal1:    DS 1
    decimal2:    DS 1
    digit_temp:  DS 1
    
    last_key:    DS 1
    key_step:    DS 1
    digit1:      DS 1
    digit2:      DS 1
    digit3:      DS 1
    
    display_mode: DS 1
    cycle_count:  DS 1
    
    ; UART
    rx_byte:     DS 1
    tx_byte:     DS 1

PSECT resetVec, class=CODE, delta=2
    ORG 0x00
    GOTO MAIN

PSECT code
MAIN:
    CALL init
    
    MOVLW 25
    MOVWF target_val
    CLRF target_decimal
    CLRF key_step
    MOVLW 0xFF
    MOVWF last_key
    CLRF display_mode
    CLRF cycle_count
    CLRF fan_speed
    CLRF timer_tick

MAIN_LOOP:
    BCF STATUS, 5
    BCF STATUS, 6
    
    ; UART komut kontrol
    CALL uart_check_command
    
    CALL check_keypad
    
    ; ADC oku
    BSF ADCON0, 2
wait_adc:
    BTFSC ADCON0, 2
    GOTO wait_adc
    
    ; ADC sonucunu oku (right justified)
    BSF STATUS, 5       ; Bank 1
    MOVF ADRESL, W
    BCF STATUS, 5       ; Bank 0
    
    MOVWF adc_val
    BCF STATUS, 0
    RRF adc_val, F      ; /2

    ; Fan hizi olcumu
    BTFSS PORTA, 2
    GOTO fan_off
    CALL measure_fan_speed
    GOTO fan_done
fan_off:
    CLRF fan_speed
fan_done:

    ; Sicaklik kontrolu
    MOVF adc_val, W
    SUBWF target_val, W
    BTFSS STATUS, STATUS_C_POSITION
    GOTO TURN_ON_COOLER

    MOVF target_val, W
    SUBWF adc_val, W
    BTFSS STATUS, 0
    GOTO TURN_ON_HEATER

    GOTO TURN_OFF_ALL

TURN_ON_HEATER:
    BSF PORTA, 1
    BCF PORTA, 2
    GOTO DISPLAY_SECTION

TURN_ON_COOLER:
    BCF PORTA, 1
    BSF PORTA, 2
    GOTO DISPLAY_SECTION

TURN_OFF_ALL:
    BCF PORTA, 1
    BCF PORTA, 2

DISPLAY_SECTION:
    MOVF key_step, F
    BTFSS STATUS, 2
    GOTO SHOW_MENU
    
    MOVF display_mode, W
    XORLW 0
    BTFSC STATUS, 2
    GOTO prep_target
    
    MOVF display_mode, W
    XORLW 1
    BTFSC STATUS, 2
    GOTO prep_ambient
    
    MOVF display_mode, W
    XORLW 2
    BTFSC STATUS, 2
    GOTO prep_fan
    
prep_target:
    MOVF target_val, W
    MOVWF ones
    CLRF tens
prep_target_bcd:
    MOVLW 10
    SUBWF ones, W
    BTFSS STATUS, 0
    GOTO prep_target_done
    MOVWF ones
    INCF tens, F
    GOTO prep_target_bcd
prep_target_done:
    MOVF target_decimal, W
    MOVWF decimal1
    CLRF decimal2
    GOTO do_display

prep_ambient:
    MOVF adc_val, W
    GOTO convert_to_bcd

prep_fan:
    ; Fan hizi 3 basamakli gosterim (ornegin 114)
    ; Display sirasi: tens(digit0), ones(digit1), decimal1(digit2), decimal2(digit3)
    ; Yani: tens=yuzler, ones=onlar, decimal1=birler, decimal2=mode
    MOVF fan_speed, W
    MOVWF digit_temp        ; Gecici olarak sakla
    CLRF tens               ; tens = yuzler basamagi
    CLRF ones               ; ones = onlar basamagi  
    CLRF decimal1           ; decimal1 = birler basamagi
    
    ; Yuzler basamagi (100'e bol) -> tens'e koy
prep_fan_hundreds:
    MOVLW 100
    SUBWF digit_temp, W
    BTFSS STATUS, 0
    GOTO prep_fan_tens_calc
    MOVWF digit_temp
    INCF tens, F            ; tens = yuzler basamagi
    GOTO prep_fan_hundreds

prep_fan_tens_calc:
    ; Onlar basamagi -> ones'a koy
    MOVLW 10
    SUBWF digit_temp, W
    BTFSS STATUS, 0
    GOTO prep_fan_done
    MOVWF digit_temp
    INCF ones, F            ; ones = onlar basamagi
    GOTO prep_fan_tens_calc

prep_fan_done:
    ; Kalan = birler -> decimal1'e koy
    MOVF digit_temp, W
    MOVWF decimal1          ; decimal1 = birler basamagi
    MOVLW 2                 ; Mode 2 = Fan
    MOVWF decimal2
    GOTO do_display

convert_to_bcd:
    MOVWF ones
    CLRF tens
    CLRF decimal1
    CLRF decimal2
bcd_loop:
    MOVLW 10
    SUBWF ones, W
    BTFSS STATUS, 0
    GOTO display_ready
    MOVWF ones
    INCF tens, F
    GOTO bcd_loop

display_ready:
    MOVF display_mode, W
    MOVWF decimal2
    GOTO do_display

SHOW_MENU:
    MOVF key_step, W
    XORLW 1
    BTFSC STATUS, 2
    GOTO show_dashes
    
    MOVF digit1, W
    MOVWF tens
    MOVF digit2, W
    MOVWF ones
    MOVF digit3, W
    MOVWF decimal1
    CLRF decimal2
    GOTO do_display

show_dashes:
    CLRF tens
    CLRF ones
    CLRF decimal1
    CLRF decimal2
    GOTO do_display

do_display:
    MOVLW 15
    MOVWF disp_loop

DISPLAY_REFRESH:
    MOVF tens, W
    CALL get_code_safe
    MOVWF PORTD
    BSF PORTC, 0
    CALL delay_mux
    BCF PORTC, 0

    ; Ones basamagi - mode 2 degilse nokta ekle
    MOVF ones, W
    CALL get_code_safe
    ; Mode 2 (fan) mi kontrol et
    MOVWF digit_temp        ; Gecici sakla
    MOVF display_mode, W
    XORLW 2
    BTFSC STATUS, 2         ; Mode 2 ise nokta ekleme
    GOTO ones_no_dot
    MOVF digit_temp, W
    IORLW 10000000B         ; Nokta ekle (mode 0,1 icin)
    GOTO ones_display
ones_no_dot:
    MOVF digit_temp, W      ; Nokta yok (mode 2 icin)
ones_display:
    MOVWF PORTD
    BSF PORTC, 1
    CALL delay_mux
    BCF PORTC, 1

    ; Decimal1 basamagi - mode 2 ise nokta ekle
    MOVF decimal1, W
    CALL get_code_safe
    MOVWF digit_temp        ; Gecici sakla
    MOVF display_mode, W
    XORLW 2
    BTFSS STATUS, 2         ; Mode 2 degilse nokta ekleme
    GOTO dec1_no_dot
    MOVF digit_temp, W
    IORLW 10000000B         ; Nokta ekle (mode 2 icin)
    GOTO dec1_display
dec1_no_dot:
    MOVF digit_temp, W      ; Nokta yok (mode 0,1 icin)
dec1_display:
    MOVWF PORTD
    BSF PORTC, 2
    CALL delay_mux
    BCF PORTC, 2

    MOVF decimal2, W
    CALL get_code_safe
    MOVWF PORTD
    BSF PORTC, 3
    CALL delay_mux
    BCF PORTC, 3
    
    DECFSZ disp_loop, F
    GOTO DISPLAY_REFRESH

    MOVF key_step, F
    BTFSS STATUS, 2
    GOTO skip_rotation
    
    INCF cycle_count, F
    MOVF cycle_count, W
    SUBLW 30                ; ~2 saniye icin 30 dongu (her mod 2sn gorunur)
    BTFSS STATUS, 2
    GOTO skip_rotation
    
    CLRF cycle_count
    INCF display_mode, F
    MOVF display_mode, W
    SUBLW 3
    BTFSS STATUS, 2
    GOTO skip_rotation
    CLRF display_mode

skip_rotation:
    GOTO MAIN_LOOP

; ============================================
; UART KOMUT ISLEYICI
; ============================================
uart_check_command:
    ; RCIF flag kontrol
    BANKSEL PIR1
    BTFSS PIR1, 5
    GOTO uart_cmd_exit
    
    ; Overrun error kontrolu
    BANKSEL RCSTA
    BTFSC RCSTA, 1
    GOTO uart_clear_oerr
    
    ; Veriyi oku
    BANKSEL RCREG
    MOVF RCREG, W
    BCF STATUS, 5
    BCF STATUS, 6
    MOVWF rx_byte
    
    ; Komut analizi
    ; Bit 7-6 kontrol: 00=GET, 10=SET frac, 11=SET int
    
    BTFSC rx_byte, 7
    GOTO uart_set_cmd
    
    ; GET komutu (bit 7 = 0)
    MOVF rx_byte, W
    XORLW 0x01          ; Get desired temp fractional
    BTFSC STATUS, 2
    GOTO cmd_get_desired_frac
    
    MOVF rx_byte, W
    XORLW 0x02          ; Get desired temp integral
    BTFSC STATUS, 2
    GOTO cmd_get_desired_int
    
    MOVF rx_byte, W
    XORLW 0x03          ; Get ambient temp fractional
    BTFSC STATUS, 2
    GOTO cmd_get_ambient_frac
    
    MOVF rx_byte, W
    XORLW 0x04          ; Get ambient temp integral
    BTFSC STATUS, 2
    GOTO cmd_get_ambient_int
    
    MOVF rx_byte, W
    XORLW 0x05          ; Get fan speed
    BTFSC STATUS, 2
    GOTO cmd_get_fan_speed
    
    GOTO uart_cmd_exit

cmd_get_desired_frac:
    MOVF target_decimal, W
    CALL uart_send_byte
    GOTO uart_cmd_exit

cmd_get_desired_int:
    MOVF target_val, W
    CALL uart_send_byte
    GOTO uart_cmd_exit

cmd_get_ambient_frac:
    MOVLW 0             ; Fractional kisim yok (ADC tam deger)
    CALL uart_send_byte
    GOTO uart_cmd_exit

cmd_get_ambient_int:
    MOVF adc_val, W
    CALL uart_send_byte
    GOTO uart_cmd_exit

cmd_get_fan_speed:
    MOVF fan_speed, W
    CALL uart_send_byte
    GOTO uart_cmd_exit

uart_set_cmd:
    ; SET komutu (bit 7 = 1)
    ; Bit 6: 0=fractional, 1=integral
    ; Bit 5-0: 6-bit deger
    
    BTFSC rx_byte, 6
    GOTO cmd_set_desired_int
    
    ; Set fractional (10xxxxxx)
    MOVF rx_byte, W
    ANDLW 0x3F          ; Alt 6 bit (0-63 arasi)
    MOVWF target_decimal
    GOTO uart_cmd_exit

cmd_set_desired_int:
    ; Set integral (11xxxxxx)
    MOVF rx_byte, W
    ANDLW 0x3F          ; Alt 6 bit (0-63 arasi, ama 10-50 kabul edilir)
    MOVWF target_val
    
    ; Aralik kontrolu (10-50)
    MOVLW 10
    SUBWF target_val, W
    BTFSS STATUS, 0
    GOTO set_default_temp
    
    MOVLW 51
    SUBWF target_val, W
    BTFSC STATUS, 0
    GOTO set_default_temp
    
    GOTO uart_cmd_exit

set_default_temp:
    MOVLW 25
    MOVWF target_val
    GOTO uart_cmd_exit

uart_clear_oerr:
    BANKSEL RCSTA
    BCF RCSTA, 4
    BSF RCSTA, 4
    BANKSEL RCREG
    MOVF RCREG, W
    BCF STATUS, 5
    BCF STATUS, 6
    
uart_cmd_exit:
    BCF STATUS, 5
    BCF STATUS, 6
    RETURN

; ============================================
; FAN HIZI OLCUMU
; ============================================
measure_fan_speed:
    INCF timer_tick, F
    MOVF timer_tick, W
    SUBLW 50
    BTFSS STATUS, 2
    RETURN
    
    MOVF TMR0, W
    MOVWF fan_speed
    CLRF TMR0
    CLRF timer_tick
    RETURN

; ============================================
; KEYPAD
; ============================================
check_keypad:
    CALL scan_key
    
    MOVF last_key, W
    XORLW 0xFF
    BTFSC STATUS, 2
    RETURN
    
    CALL handle_key
    
    MOVLW 0xFF
    MOVWF last_key
    RETURN

scan_key:
    MOVLW 0xFF
    MOVWF last_key
    
    MOVLW 11111110B
    MOVWF PORTB
    CALL dly_stab
    BTFSS PORTB, 4
    GOTO f1
    BTFSS PORTB, 5
    GOTO f2
    BTFSS PORTB, 6
    GOTO f3
    BTFSS PORTB, 7
    GOTO fA
    
    MOVLW 11111101B
    MOVWF PORTB
    CALL dly_stab
    BTFSS PORTB, 4
    GOTO f4
    BTFSS PORTB, 5
    GOTO f5
    BTFSS PORTB, 6
    GOTO f6
    BTFSS PORTB, 7
    GOTO fB
    
    MOVLW 11111011B
    MOVWF PORTB
    CALL dly_stab
    BTFSS PORTB, 4
    GOTO f7
    BTFSS PORTB, 5
    GOTO f8
    BTFSS PORTB, 6
    GOTO f9
    BTFSS PORTB, 7
    GOTO fC
    
    MOVLW 11110111B
    MOVWF PORTB
    CALL dly_stab
    BTFSS PORTB, 4
    GOTO fS
    BTFSS PORTB, 5
    GOTO f0
    BTFSS PORTB, 6
    GOTO fH
    BTFSS PORTB, 7
    GOTO fD
    
    RETURN

f1: MOVLW 1
    MOVWF last_key
    CALL wrel
    RETURN
f2: MOVLW 2
    MOVWF last_key
    CALL wrel
    RETURN
f3: MOVLW 3
    MOVWF last_key
    CALL wrel
    RETURN
fA: MOVLW 10
    MOVWF last_key
    CALL wrel
    RETURN
f4: MOVLW 4
    MOVWF last_key
    CALL wrel
    RETURN
f5: MOVLW 5
    MOVWF last_key
    CALL wrel
    RETURN
f6: MOVLW 6
    MOVWF last_key
    CALL wrel
    RETURN
fB: MOVLW 11
    MOVWF last_key
    CALL wrel
    RETURN
f7: MOVLW 7
    MOVWF last_key
    CALL wrel
    RETURN
f8: MOVLW 8
    MOVWF last_key
    CALL wrel
    RETURN
f9: MOVLW 9
    MOVWF last_key
    CALL wrel
    RETURN
fC: MOVLW 12
    MOVWF last_key
    CALL wrel
    RETURN
fS: MOVLW 14
    MOVWF last_key
    CALL wrel
    RETURN
f0: MOVLW 0
    MOVWF last_key
    CALL wrel
    RETURN
fH: MOVLW 15
    MOVWF last_key
    CALL wrel
    RETURN
fD: MOVLW 13
    MOVWF last_key
    CALL wrel
    RETURN

wrel:
    MOVLW 50
    MOVWF disp_loop
wrel_dly:
    MOVF tens, W
    CALL get_code_safe
    MOVWF PORTD
    BSF PORTC, 0
    CALL delay_mux
    BCF PORTC, 0
    
    MOVF ones, W
    CALL get_code_safe
    IORLW 10000000B
    MOVWF PORTD
    BSF PORTC, 1
    CALL delay_mux
    BCF PORTC, 1
    
    MOVF decimal1, W
    CALL get_code_safe
    MOVWF PORTD
    BSF PORTC, 2
    CALL delay_mux
    BCF PORTC, 2
    
    MOVF decimal2, W
    CALL get_code_safe
    MOVWF PORTD
    BSF PORTC, 3
    CALL delay_mux
    BCF PORTC, 3
    
    DECFSZ disp_loop, F
    GOTO wrel_dly
    
wrel_chk:
    MOVLW 11111111B
    MOVWF PORTB
    CALL dly_stab
    
    BTFSS PORTB, 4
    GOTO wrel_chk
    BTFSS PORTB, 5
    GOTO wrel_chk
    BTFSS PORTB, 6
    GOTO wrel_chk
    BTFSS PORTB, 7
    GOTO wrel_chk
    
    RETURN

dly_stab:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    RETURN

handle_key:
    MOVF last_key, W
    XORLW 10
    BTFSC STATUS, 2
    GOTO key_A
    
    MOVF last_key, W
    XORLW 15
    BTFSC STATUS, 2
    GOTO key_confirm
    
    MOVF last_key, W
    XORLW 14
    BTFSC STATUS, 2
    GOTO key_star
    
    MOVF last_key, W
    SUBLW 9
    BTFSS STATUS, 0
    RETURN
    
    MOVF key_step, F
    BTFSC STATUS, 2
    RETURN
    
    MOVF key_step, W
    XORLW 1
    BTFSC STATUS, 2
    GOTO save_first_digit
    
    MOVF key_step, W
    XORLW 2
    BTFSC STATUS, 2
    GOTO save_second_digit
    
    MOVF key_step, W
    XORLW 4
    BTFSC STATUS, 2
    GOTO save_decimal_digit
    
    RETURN

key_A:
    MOVLW 1
    MOVWF key_step
    CLRF digit1
    CLRF digit2
    CLRF digit3
    RETURN

save_first_digit:
    MOVF last_key, W
    MOVWF digit1
    CLRF digit2
    CLRF digit3
    MOVLW 2
    MOVWF key_step
    RETURN

save_second_digit:
    MOVF last_key, W
    MOVWF digit2
    MOVLW 3
    MOVWF key_step
    RETURN

key_star:
    MOVF key_step, W
    SUBLW 1
    BTFSC STATUS, 0
    RETURN
    
    MOVLW 4
    MOVWF key_step
    RETURN

save_decimal_digit:
    MOVF last_key, W
    MOVWF digit3
    MOVLW 5
    MOVWF key_step
    RETURN

key_confirm:
    MOVF key_step, W
    SUBLW 1
    BTFSC STATUS, 0
    RETURN
    
    CLRF target_val
    MOVF digit1, W
    MOVWF delay1
    BTFSC STATUS, 2
    GOTO add_digit2
multiply_10:
    MOVLW 10
    ADDWF target_val, F
    DECFSZ delay1, F
    GOTO multiply_10

add_digit2:
    MOVF digit2, W
    ADDWF target_val, F
    
    MOVLW 10
    SUBWF target_val, W
    BTFSS STATUS, 0
    GOTO reject_value
    
    MOVLW 51
    SUBWF target_val, W
    BTFSC STATUS, 0
    GOTO reject_value
    
    MOVF digit3, W
    MOVWF target_decimal
    
    CLRF key_step
    RETURN

reject_value:
    MOVLW 25
    MOVWF target_val
    CLRF target_decimal
    CLRF key_step
    RETURN

; ============================================
; 7-SEGMENT KODU
; ============================================
get_code_safe:
    MOVWF digit_temp
    MOVF digit_temp, W
    XORLW 0
    BTFSC STATUS, 2
    RETLW 00111111B
    MOVF digit_temp, W
    XORLW 1
    BTFSC STATUS, 2
    RETLW 00000110B
    MOVF digit_temp, W
    XORLW 2
    BTFSC STATUS, 2
    RETLW 01011011B
    MOVF digit_temp, W
    XORLW 3
    BTFSC STATUS, 2
    RETLW 01001111B
    MOVF digit_temp, W
    XORLW 4
    BTFSC STATUS, 2
    RETLW 01100110B
    MOVF digit_temp, W
    XORLW 5
    BTFSC STATUS, 2
    RETLW 01101101B
    MOVF digit_temp, W
    XORLW 6
    BTFSC STATUS, 2
    RETLW 01111101B
    MOVF digit_temp, W
    XORLW 7
    BTFSC STATUS, 2
    RETLW 00000111B
    MOVF digit_temp, W
    XORLW 8
    BTFSC STATUS, 2
    RETLW 01111111B
    MOVF digit_temp, W
    XORLW 9
    BTFSC STATUS, 2
    RETLW 01101111B
    MOVF digit_temp, W
    XORLW 10
    BTFSC STATUS, 2
    RETLW 01000000B
    RETLW 00000000B

; ============================================
; INIT
; ============================================
init:
    BSF STATUS, 5
    
    MOVLW 0b00010001
    MOVWF TRISA
    
    MOVLW 11110000B
    MOVWF TRISB
    
    MOVLW 10000000B
    MOVWF TRISC
    CLRF TRISD
    
    MOVLW 10001110B
    MOVWF ADCON1
    
    MOVLW 10101000B
    MOVWF OPTION_REG
    
    BCF STATUS, 5
    
    CLRF PORTA
    CLRF PORTC
    CLRF PORTD
    MOVLW 11111111B
    MOVWF PORTB
    
    MOVLW 10000001B
    MOVWF ADCON0
    
    CLRF TMR0
    
    ; UART: 9600 baud, 4MHz
    BANKSEL SPBRG
    MOVLW 25
    MOVWF SPBRG
    
    MOVLW 00100100B
    MOVWF TXSTA
    
    BANKSEL RCSTA
    MOVLW 10010000B
    MOVWF RCSTA
    
    BCF STATUS, 5
    BCF STATUS, 6
    
    CALL delay_mux
    RETURN

; ============================================
; GECIKME
; ============================================
delay_mux:
    MOVLW 200
    MOVWF delay1
d1: 
    NOP
    DECFSZ delay1, F
    GOTO d1
    RETURN

; ============================================
; UART SEND
; ============================================
uart_send_byte:
    MOVWF tx_byte
uart_wait_tx:
    BANKSEL TXSTA
    BTFSS TXSTA, 1
    GOTO uart_wait_tx
    BANKSEL TXREG
    MOVF tx_byte, W
    MOVWF TXREG
    BCF STATUS, 5
    BCF STATUS, 6
    RETURN

    END