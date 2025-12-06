#include <xc.inc> 

; --- Configuration Bitleri (PIC-AS S?zdizimi) ---
; FOSC = XT, WDTE = OFF, PWRTE = OFF, CP = OFF, LVP = OFF (ve di?er varsay?lan ayarlar)
_CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF & _LVP_OFF & _BODEN_OFF & _CPD_OFF & _WRT_OFF
_CONFIG _CONFIG2, _BORV_21 & _VDEN_OFF 
;==========================
; Vektörler (ORG 0x0000 yerine RESET_VECTOR kullan?m?)
;==========================
    ORG 0x0000
    GOTO main
;==========================


;==========================
;      ANA PROGRAM
;==========================
main:
    ; --- TRISD Ayar? (PORTD Ç?k??) ---
    BANKSEL TRISD        ; Bank 1'e geç
    CLRF    TRISD        ; PORTD'yi ç?k?? (0) olarak ayarla
    BANKSEL PORTD        ; Bank 0'a dön

    ; --- 7 rakam?n? göster ---
    MOVLW   7            ; Gösterilecek de?eri W'ye yükle
    CALL    SEGMENT_TABLE
    
    ; W kayd?nda ?imdi 7-segment kodu var
    MOVWF   PORTD        ; Kodu PORTD'ye gönder

loop:
    GOTO loop
;==========================


;==========================
;    JUMP TABLE - Ortak Anot (CA)
;==========================
SEGMENT_TABLE:
    ADDWF PCL, F 
    
    RETLW 0x3F   ; 0
    RETLW 0x06   ; 1
    RETLW 0x5B   ; 2
    RETLW 0x4F   ; 3
    RETLW 0x66   ; 4
    RETLW 0x6D   ; 5
    RETLW 0x7D   ; 6
    RETLW 0x07   ; 7 
    RETLW 0x7F   ; 8
    RETLW 0x6F   ; 9

 END