#include <xc.inc>

;GLOBAL FONKSIYONLARIN BILDIRIMI
GLOBAL tus_tara   
GLOBAL cevrim_tablosu
GLOBAL tus_bekle_oku
GLOBAL tus_A_var_mi
    
;GLOBAL DEGISKENLER
GLOBAL ham_tus
GLOBAL temp_tus
    
    
;LOCAL DEGISKENLER
    
    
    
;LOCAL degiskenlerin tanimlanmasi
PSECT udata
 

 
 
 
; Fonksiyonlar    
PSECT code,class=CODE,delta=2
 
tus_tara:
    ; --- 1. SATIRI TARA (RB0 = 0) ---
    MOVLW   11111110B    
    MOVWF   PORTB
    BTFSS   PORTB, 4        ; Sütun 1 (RB4) 0 m??
    RETLW   0            ; Evet -> Tablodaki 0. eleman (Tu? '1')
    BTFSS   PORTB, 5        ; Sütun 2 (RB5) 0 m??
    RETLW   1            ; Evet -> Tablodaki 1. eleman (Tu? '2')
    BTFSS   PORTB, 6        ; Sütun 3 (RB6) 0 m??
    RETLW   2            ; Evet -> Tablodaki 2. eleman (Tu? '3')
    BTFSS   PORTB, 7        ; Sütun 4 (RB7) 0 m??
    RETLW   3            ; Evet -> Tablodaki 3. eleman (Tu? 'A')

    ; --- 2. SATIRI TARA (RB1 = 0) ---
    MOVLW   11111101B
    MOVWF   PORTB
    BTFSS   PORTB, 4
    RETLW   4            ; Tu? '4'
    BTFSS   PORTB, 5
    RETLW   5            ; Tu? '5'
    BTFSS   PORTB, 6
    RETLW   6           ; Tu? '6'
    BTFSS   PORTB, 7
    RETLW   7            ; Tu? 'B'

    ; --- 3. SATIRI TARA (RB2 = 0) ---
    MOVLW   11111011B
    MOVWF   PORTB
    BTFSS   PORTB, 4
    RETLW   8            ; Tu? '7'
    BTFSS   PORTB, 5
    RETLW   9            ; Tu? '8'
    BTFSS   PORTB, 6
    RETLW   10           ; Tu? '9'
    BTFSS   PORTB, 7
    RETLW   11           ; Tu? 'C'

    ; --- 4. SATIRI TARA (RB3 = 0) ---
    MOVLW   11110111B
    MOVWF   PORTB
    BTFSS   PORTB, 4
    RETLW   12          ; Tu? '*'
    BTFSS   PORTB, 5
    RETLW   13           ; Tu? '0'
    BTFSS   PORTB, 6
    RETLW   14           ; Tu? '#'
    BTFSS   PORTB, 7
    RETLW   15           ; Tu? 'D'

    RETLW   0xFF            ; H?ÇB?R?NE BASILMADIYSA FF ?LE DÖN ????????????????????????????????*
    
    ;------------------------------------------------------------------------------
    
cevrim_tablosu:
    NOP
    MOVWF   ham_tus         ; Ham de?eri sakla (Kaybolmas?n)
    ADDWF   PCL, F          ; Program Sayac?na (PCL) W'yi ekle -> Z?plama yapar!
    
    ; Tablo: (Keypad üzerindeki fiziksel s?raya göre dönü?ecek de?erler)
    ; S?ralama: 1, 2, 3, A, 4, 5, 6, B... ?eklinde gider.
    
    RETLW   0x01           ; 0. ?ndeks -> Tu? '1'
    RETLW   0x02           ; 1. ?ndeks -> Tu? '2'
    RETLW   0x03           ; 2. ?ndeks -> Tu? '3'
    RETLW   0x0A          ; 3. ?ndeks -> Tu? 'A'
    
    RETLW   0x04           ; 4. ?ndeks -> Tu? '4'
    RETLW   0x05           ; 5. ?ndeks -> Tu? '5'
    RETLW   0x06           ; 6. ?ndeks -> Tu? '6'
    RETLW   0x0B           ; 7. ?ndeks -> Tu? 'B'
    
    RETLW   0x07           ; 8. ?ndeks -> Tu? '7'
    RETLW   0x08           ; 9. ?ndeks -> Tu? '8'
    RETLW   0x09           ; 10. ?ndeks -> Tu? '9'
    RETLW   0x0C           ; 11. ?ndeks -> Tu? 'C'
    
    RETLW   0x0E           ; 12. ?ndeks -> Tu? '*' (E harfi dedik örnek olarak)
    RETLW   0x00           ; 13. ?ndeks -> Tu? '0'
    RETLW   0x0F           ; 14. ?ndeks -> Tu? '#' (F harfi dedik)
    RETLW   0x0D           ; 15. ?ndeks -> Tu? 'D'
    
    
    ;--------------------------------------------------------------
    
    ;Tu?a bas?lana kadar bekler, bas?l?nca de?eri W'ye al?r,
    ; parmak çekilene kadar bekler ve döner.
tus_bekle_oku:
    ;Bas?lana kadar bekle
    
    ;CALL    tus_tara ;diyelim A basildi W=3
    
    XORLW   0xFF
    BTFSC   STATUS, 2       ; Z=1 ise (W=FF) tu? yok demektir
    GOTO    tus_bekle_oku   ; Tu? yoksa tekrar tara
    
    
    ;Tu?u al ve sakla
    CALL    tus_tara        ; Tekrar oku (W'de index var)
    
    MOVLW 3 ; diyelim A basildi
    
    CALL    cevrim_tablosu  ; Gerçek de?ere çevir (W'de A, *, 5 vs var)
    MOVWF   temp_tus        ; Kaybetmemek için sakla

    ; 3. Parmak çekilene kadar bekle (Debounce + Release)
    TUS_BIRAKMA:
	CALL    tus_tara
	XORLW   0xFF
	BTFSS   STATUS, 2       ; Z=0 ise (W!=FF) hala bas?l?
	GOTO    TUS_BIRAKMA     ; B?rak?lana kadar dön

	; 4. Saklanan de?eri W'ye yükle ve dön
	MOVF    temp_tus, W
	RETURN
    
; NON-BLOCKING: Sadece 'A' tu?unu kontrol et
tus_A_var_mi:
    RETLW   1
    CALL    tus_tara
    
    MOVLW 3
    ;XORLW   0xFF
    ;BTFSC   STATUS, 2
    ;RETLW   0               ; Tus yok
    
    ;CALL    tus_tara
    
    MOVLW 3 ; diyelim A basildi ve W=3 oldu
    
    CALL    cevrim_tablosu
    SUBLW   0x0A            ; 'A' m??
    BTFSS   STATUS, 2
    RETLW   0               ; 'A' degil
    
    ; 'A' basilmis, birakilmasini bekle
    TUS_A_BIRAKMA:
    CALL    tus_tara
    
    MOVLW 3
    
    XORLW   0xFF
    BTFSS   STATUS, 2
    GOTO    TUS_A_BIRAKMA
    
    RETLW   1               ; 'A' bas?ld?!