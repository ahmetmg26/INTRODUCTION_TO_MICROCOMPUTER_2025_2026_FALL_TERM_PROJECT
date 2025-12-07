#include <xc.inc>

; -- RAM ADRESLER? (20H'den ba?lat?l?r) --
KeyData     EQU 0x20    ; Bas?lan tu?un de?eri (0-15 veya FFh: Tu? bas?lmad?)
KeyTemp     EQU 0x21    ; Geçici kay?tç?
delay_temp0 EQU 0x22    ; Gecikme sayac?
delay_temp1 EQU 0x23    ; Gecikme sayac?

; -- Reset Vektörü ve Program Ba?lang?c? --
    PSECT resetVec, class=CODE, delta=2
    ORG 0x00
    GOTO MAIN

    PSECT code, class=CODE, delta=2
 
 MAIN:
    CALL INIT           ; Port ayarlar?
    MOVLW 0xFF          ; Ba?lang?çta tu? bas?lmad?
    MOVWF KeyData

LOOP:
    CLRWDT              ; Watchdog Timer'? temizle
    CALL KEYPAD_SCAN    ; Keypad'i oku

    ; Tu? de?erini kullanmak için buraya kod ekle
    ; Örn: MOVF KeyData, W
    ; E?er KeyData = 0x05 ise, '5' tu?u bas?lm?? demektir.

    GOTO LOOP
    
    
INIT:
BSF STATUS, 5       ; Bank 1'e geç

; TRISB Ayar?: 
; RB7-RB4 (Sat?rlar) = Giri? (1)
; RB3-RB0 (Sütunlar) = Ç?k?? (0)
MOVLW 0xF0          ; 11110000B
MOVWF TRISB

; WPU Ayar?: Dahili Pull-up Dirençleri kullan?l?r
; PORTB'deki tüm pinler için pull-up etkinle?tirilir.
MOVLW 0x00
MOVWF OPTION_REG    ; RBPU biti (Bit 7) 0'a çekilerek Pull-up etkinle?tirilir.

BCF STATUS, 5       ; Bank 0'a geç

CLRF PORTB          ; Ç?k?? pinlerini ba?lang?çta temizle
RETURN
    
DELAY_50MS:
    MOVLW 0x20          ; D?? döngü (Yakla??k 32)
    MOVWF delay_temp1
D1_LOOP:
    MOVLW 0xFF          ; ?ç döngü (255)
    MOVWF delay_temp0
D2_LOOP:
    DECFSZ delay_temp0, F
    GOTO D2_LOOP
    DECFSZ delay_temp1, F
    GOTO D1_LOOP
    RETURN