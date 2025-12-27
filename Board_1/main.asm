; BOARD 1 - Sicaklik Kontrol (ornek.asm'den uyarlanmis)
; Heater=RA1, Cooler=RA2, Temp=RA0, Tach=RA4
; 7-Segment: RD0-RD7, Digits: RC0-RC3
; Keypad: RB0-RB3 rows, RB4-RB7 cols

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

    ; Fan hizi olcumu (cooler calisiyor mu?)
    BTFSS PORTA, 2
    GOTO fan_off
    CALL measure_fan_speed
    GOTO fan_done
fan_off:
    CLRF fan_speed
fan_done:

    ; Sicaklik kontrolu
    ; target_val > adc_val -> Isit
    ; target_val < adc_val -> Sogut
    
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
    BSF PORTA, 1        ; Heater ON (RA1)
    BCF PORTA, 2        ; Cooler OFF (RA2)
    GOTO DISPLAY_SECTION

TURN_ON_COOLER:
    BCF PORTA, 1        ; Heater OFF
    BSF PORTA, 2        ; Cooler ON
    GOTO DISPLAY_SECTION

TURN_OFF_ALL:
    BCF PORTA, 1
    BCF PORTA, 2

DISPLAY_SECTION:
    ; key_step 0 ise normal display, degil ise menu
    MOVF key_step, F
    BTFSS STATUS, 2
    GOTO SHOW_MENU
    
    ; Normal display - mode'a gore goster
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
    MOVF fan_speed, W
    GOTO convert_to_bcd

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
    ; Mode gostergesini decimal2'ye yaz
    MOVF display_mode, W
    MOVWF decimal2
    GOTO do_display

SHOW_MENU:
    ; key_step 1 ise tire goster
    MOVF key_step, W
    XORLW 1
    BTFSC STATUS, 2
    GOTO show_dashes
    
    ; Girilen rakamlari goster
    MOVF digit1, W
    MOVWF tens
    MOVF digit2, W
    MOVWF ones
    MOVF digit3, W
    MOVWF decimal1
    CLRF decimal2
    GOTO do_display

show_dashes:
    CLRF tens           ; 0 goster (tire yerine)
    CLRF ones
    CLRF decimal1
    CLRF decimal2
    GOTO do_display

do_display:
    MOVLW 15
    MOVWF disp_loop

DISPLAY_REFRESH:
    ; Digit 1 (RC0) - Onlar
    MOVF tens, W
    CALL get_code_safe
    MOVWF PORTD
    BSF PORTC, 0
    CALL delay_mux
    BCF PORTC, 0

    ; Digit 2 (RC1) - Birler + DP
    MOVF ones, W
    CALL get_code_safe
    IORLW 10000000B
    MOVWF PORTD
    BSF PORTC, 1
    CALL delay_mux
    BCF PORTC, 1

    ; Digit 3 (RC2) - Ondalik1
    MOVF decimal1, W
    CALL get_code_safe
    MOVWF PORTD
    BSF PORTC, 2
    CALL delay_mux
    BCF PORTC, 2

    ; Digit 4 (RC3) - Mode
    MOVF decimal2, W
    CALL get_code_safe
    MOVWF PORTD
    BSF PORTC, 3
    CALL delay_mux
    BCF PORTC, 3
    
    DECFSZ disp_loop, F
    GOTO DISPLAY_REFRESH

    ; Mode rotasyonu (sadece key_step=0 iken)
    MOVF key_step, F
    BTFSS STATUS, 2
    GOTO skip_rotation
    
    INCF cycle_count, F
    MOVF cycle_count, W
    SUBLW 100               ; 30'dan 100'e arttirildi (daha yavas)
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
; FAN HIZI OLCUMU
; TMR0 counter mode - RA4/T0CKI'dan pulse sayar
; ============================================
measure_fan_speed:
    INCF timer_tick, F
    MOVF timer_tick, W
    SUBLW 50            ; 50 dongu sonra oku
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
    
    ; Row 0 (RB0=LOW)
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
    
    ; Row 1 (RB1=LOW)
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
    
    ; Row 2 (RB2=LOW)
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
    
    ; Row 3 (RB3=LOW)
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

; Tus birakilana kadar bekle (display gosterirken)
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
    ; A tusu - giris basla
    MOVF last_key, W
    XORLW 10
    BTFSC STATUS, 2
    GOTO key_A
    
    ; # tusu - onayla
    MOVF last_key, W
    XORLW 15
    BTFSC STATUS, 2
    GOTO key_confirm
    
    ; * tusu - ondalik
    MOVF last_key, W
    XORLW 14
    BTFSC STATUS, 2
    GOTO key_star
    
    ; 0-9 rakam mi?
    MOVF last_key, W
    SUBLW 9
    BTFSS STATUS, 0
    RETURN
    
    ; key_step 0 ise atla
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
    
    ; Hesapla: digit1*10 + digit2
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
    
    ; Aralik: 10-50
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
    RETLW 01000000B     ; Tire
    RETLW 00000000B

; ============================================
; INIT
; ============================================
init:
    BSF STATUS, 5       ; Bank 1
    
    ; Port yonleri
    MOVLW 0b00010001    ; RA0=in(ADC), RA4=in(Tach/T0CKI), RA1,RA2=out
    MOVWF TRISA
    
    MOVLW 11110000B     ; RB0-3=out(rows), RB4-7=in(cols)
    MOVWF TRISB
    
    CLRF TRISC          ; RC0-7 output (display)
    CLRF TRISD          ; RD0-7 output (segments)
    
    ; ADC ayari - right justified, AN0 analog
    MOVLW 10001110B
    MOVWF ADCON1
    
    ; OPTION_REG: TMR0 counter mode, RA4/T0CKI, falling edge
    ; Bit 5: T0CS=1 (T0CKI pin)
    ; Bit 4: T0SE=1 (falling edge)
    ; Bit 3: PSA=1 (prescaler to WDT, not TMR0)
    ; Bit 7: RBPU=0 (pull-ups enabled)
    MOVLW 10101000B
    MOVWF OPTION_REG
    
    BCF STATUS, 5       ; Bank 0
    
    ; Portlari temizle
    CLRF PORTA
    CLRF PORTC
    CLRF PORTD
    MOVLW 11111111B
    MOVWF PORTB
    
    ; ADCON0: Fosc/32, AN0, ADC ON
    MOVLW 10000001B
    MOVWF ADCON0
    
    ; TMR0 sifirla
    CLRF TMR0
    
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

    END