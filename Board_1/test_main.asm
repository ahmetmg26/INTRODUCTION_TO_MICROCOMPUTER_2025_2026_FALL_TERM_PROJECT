;==========================================================
; MAIN.ASM - Variables + Main Program
;==========================================================
#include <xc.inc>
#include "temperature_module.asm" 
#include "sevenSegmentDisplay.asm"
#include "keyPad.asm"


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
    
    ;Keypad degiskenleri
    ;GLOBAL ham_tus
    ;GLOBAL temp_tus
    ;GLOBAL girilen_onlar
    ;GLOBAL girilen_birler
    ;GLOBAL girilen_ondalik
    GLOBAL key_value
    GLOBAL col_index
    GLOBAL row_value

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

; temperature modul icin degiskenleri tanimla
ambient_temp_int:      DS 1
ambient_temp_frac:     DS 1
desired_temp_int:      DS 1
desired_temp_frac:     DS 1
fan_rps:               DS 1
temp_compare_result:   DS 1
    delay_outer:    DS 1
    delay_inner:    DS 1
tach_counter:       DS 1

; 7-seg-display icin degiskenleri tanimla
digitNum:  DS 1
digitOnes: DS 1
digitTens: DS 1
digitHundreds: DS 1
digitThousands: DS 1
birler: DS 1
onlar: DS 1
delay5ms_temp0: DS 1
delay5ms_temp1: DS 1

; Keypad degiskeni tan?mla
ham_tus: DS 1
temp_tus: DS 1    
girilen_onlar:  DS 1    ; ?lk rakam (Örn: 2)
girilen_birler: DS 1    ; ?kinci rakam (Örn: 4)
girilen_ondalik: DS 1   ; Virgülden sonraki rakam (Örn: 5)
temp_calc: DS 1 ;    onlar ve birler'i desired_temp_int de?erinde toplamak için
    
key_value:     DS 1   ; Bulunan tu? (0xFF = yok)
col_index:     DS 1   ; Aktif sütun
row_value:     DS 1   ; Okunan sat?r de?eri   
    
    
    
    
PSECT code
 
MAIN:
    CALL PortInit
    
    ; Ba?lang?? de?erleri
    MOVLW 35
    BANKSEL desired_temp_int
    MOVWF desired_temp_int
    CLRF desired_temp_frac
    
READ_LOOP:
    ;BANKSEL PORTA
    
    
    MOVLW HIGH(TEMP_ReadAmbient)
    MOVWF PCLATH
    CALL TEMP_ReadAmbient       ; temperature_module.asm'den
    
    MOVLW HIGH(TEMP_UpdateFanControl)
    MOVWF PCLATH
    CALL TEMP_UpdateFanControl      ; temperature_module.asm'den
    
    ; Test: desired temp'i 7-seg-display'e g?ster
    BANKSEL desired_temp_int
    MOVF desired_temp_int,W ; W=desired_temp_int
    
    MOVLW HIGH(digitlere_ayir)
    MOVWF PCLATH
    MOVF desired_temp_int,W ; W=desired_temp_int
    CALL digitlere_ayir ; burdan biler ve onlar belirlenir
    
    MOVF birler,W
    MOVWF digitHundreds
    MOVLW 3
    MOVWF digitNum
    MOVLW HIGH(updateDisplay)
    MOVWF PCLATH
    CALL updateDisplay
    CALL delay5ms
    
    MOVF onlar,W
    MOVWF digitThousands
    MOVLW 4
    MOVWF digitNum
    MOVLW HIGH(updateDisplay)
    MOVWF PCLATH
    
    CALL updateDisplay
    CALL delay5ms
    
    ; Test: desired_temp_frac degerini gonder
    MOVF desired_temp_frac,W ; W=desired_temp_int
    CALL digitlere_ayir ; burdan biler ve onlar belirlenir
    
    MOVF birler,W
    MOVWF digitOnes
    MOVLW 1
    MOVWF digitNum
    MOVLW HIGH(updateDisplay)
    MOVWF PCLATH
    CALL updateDisplay
    CALL delay5ms
    
    MOVF onlar,W
    MOVWF digitTens
    MOVLW 2
    MOVWF digitNum
    MOVLW HIGH(updateDisplay)
    MOVWF PCLATH
    CALL updateDisplay
    CALL delay5ms
    ;----------------------------------
    ; keypad tarama 
    MOVLW HIGH(tus_A_var_mi)
    MOVWF PCLATH
    CALL tus_A_var_mi
    ; e?er w=0 dönmü?se girilen formatta sorun vardir, tekrar A'ya bas?lmas? istenir (Z = 1 )
    ; w=1 dönmü?se format do?rudur, desired_int ve frac de?erlerine atama yap?l?r (Z=0
    SUBLW 1
    BTFSS STATUS, 2
    GOTO READ_LOOP          ; 'A' bas?lmam??, devam et
    
    ; 'A' bas?ld?! ?imdi kalan ad?mlar? BLOCKING yap
    CALL KEYPAD    ; Yeni fonksiyon (a?a??da)
    
    ; Dönü? de?eri kontrol et
    SUBLW 1
    BTFSS STATUS, 2
    GOTO READ_LOOP          ; Hatal? giri?
    
    ; Ba?ar?l? giri?!
    CALL kontrol_ve_atama
    GOTO READ_LOOP
    
    
    ;GOTO READ_LOOP

    
    
    
;==========================================================
; PORT INITIALIZATION
;==========================================================
PortInit:
    BANKSEL TRISA
    MOVLW 0x01        ; RA0 input -> ortam sicakligini okumak icin , input
    MOVWF TRISA	      ; RA1-RA4 -> 7-seg-display icin, D1-D4 portlari, output	

    BANKSEL ADCON1
    MOVLW 0x8E        ; SADECE AN0 analog, saga yasli Vdd/Vss referans
    ;MOVLW 0x0E ; sola yasli
    MOVWF ADCON1

    BANKSEL ADCON0
    MOVLW 0x81        ; ADC ON, kanal AN0
    MOVWF ADCON0

    ; ---- PORTB Ayar? ----
    BANKSEL TRISB
    MOVLW 11110100B ; RB2 giri? (tach), RB0/RB1 cikis --> temperature
		    ; RB4/RB7 giris/input --> keypad
    MOVWF TRISB
    
    BCF     OPTION_REG, 7  ;OPTION_REG yazmac?n?n 7. biti (RBPU) 0 olmal?. PULL-UP direnci icin
    
	
    ; -- PORTC ayarlama -- 
    BANKSEL TRISC
    MOVLW 00000000 ; RC0/RC3 cikis/output  --> keypad icin
    MOVWF TRISC
    
    
    ; -- 7-seg-display icin PORTD ayarlari -- 
    BANKSEL TRISD
    MOVLW 0x00  ; hepsi output olacak
    MOVWF TRISD
    
    
    ; ---- Port temizleme ----
    BANKSEL PORTA
    
    CLRF PORTA
    CLRF PORTB
    
    MOVLW 00001111B ; Kolonlar? pasif yap (1)
    MOVWF PORTC

    
    CLRF PORTD
    RETURN




PSECT code

Delay_100ms:
        MOVLW   200        ; d?? d?ng?
        MOVWF   delay_outer
Delay_Outer_Loop:
        MOVLW   250        ; i? d?ng?
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

KEYPAD:
    ;ADIM_1_A:
	;MOVLW HIGH(tus_bekle_oku)
	;MOVWF PCLATH
	;CALL    tus_bekle_oku   ; Bir tu? bekle
	;SUBLW   0x0A            ; Girilen tu? 'A' (0x0A) m??
	;BTFSS   STATUS, 2       ; Sonuç 0 ise (Z=1) e?ittir.
	;RETLW 0        ; De?ilse, tekrar A gelene kadar bekle. ~~

	; -----------------------------------------------------------
	; ADIM 2: B?R?NC? RAKAMI AL (ONLAR BASAMA?I)
	; -----------------------------------------------------------
    ADIM_2_R1:
	MOVLW HIGH(tus_bekle_oku)
	MOVWF PCLATH
	CALL    tus_bekle_oku   ; Tu? bekle
	;MOVLW 1 ; diyelim 1 girildi
	MOVWF   girilen_onlar   ; Gelen tu?u sakla

	; Kontrol: Bas?lan tu? rakam m?? (0-9 aras? m??)
	; 9'dan büyükse (A,B,C,D,*,#) hata var demektir, ba?a dön.
	SUBLW   0x09            ; 9 - W i?lemi
	BTFSS   STATUS, 0       ; Carry=0 ise W > 9 demektir (Negatif sonuç)
	RETLW 0        ; Rakam de?ilse ba?a dön (Reset)

	; -----------------------------------------------------------
	; ADIM 3: ?K?NC? RAKAMI AL (B?RLER BASAMA?I)
	; -----------------------------------------------------------
    ADIM_3_R2:
	MOVLW HIGH(tus_bekle_oku)
	MOVWF PCLATH
	CALL    tus_bekle_oku
	;MOVLW 8 ;diyelimki 8 girildi
	MOVWF   girilen_birler

	; Kontrol: Rakam m??
	SUBLW   0x09
	BTFSS   STATUS, 0       ; W > 9 ise
	RETLW 0        ; Ba?a dön

	; -----------------------------------------------------------
	; ADIM 4: '*' KARAKTER?N? BEKLE (0x0E)
	; -----------------------------------------------------------
    ADIM_4_YILDIZ:
	MOVLW HIGH(tus_bekle_oku)
	MOVWF PCLATH
	CALL    tus_bekle_oku
	;MOVLW 12 ; diyelim yildiz karakteri girildi
	
	SUBLW   0x0E            ; '*' tu?u tablonda 0x0E mi?
	BTFSS   STATUS, 2       ; E?it mi?
	RETLW 0        ; De?ilse ba?a dön

	; -----------------------------------------------------------
	; ADIM 5: ÜÇÜNCÜ RAKAMI AL (ONDALIK KISIM)
	; -----------------------------------------------------------
    ADIM_5_R3:
	MOVLW HIGH(tus_bekle_oku)
	MOVWF PCLATH
	CALL    tus_bekle_oku
	;MOVLW 4 ; diyelim 4 girildi
	MOVWF   girilen_ondalik

	; Kontrol: Rakam m??
	SUBLW   0x09
	BTFSS   STATUS, 0
	RETLW 0

	; -----------------------------------------------------------
	; ADIM 6: '#' KARAKTER?N? BEKLE (B?T??) (0x0F)
	; -----------------------------------------------------------
    ADIM_6_KARE:
	MOVLW HIGH(tus_bekle_oku)
	MOVWF PCLATH
	CALL    tus_bekle_oku
	;MOVLW 14 ; diyelim # karakteri girildi
	
	SUBLW   0x0F            ; '#' tu?u tablonda 0x0F mi?
	BTFSS   STATUS, 2
	RETLW 0        ; De?ilse ba?a dön
	;DO?RU G?R?? YAPILDI!
	RETLW 1
    
kontrol_ve_atama:
	
	; (X * 10) = (X * 8) + (X * 2)
	
	MOVF    girilen_onlar, W
	MOVWF   temp_calc           ; temp = X
	BCF     STATUS, 0
	RLF     temp_calc, F        ; temp = 2X

	MOVF    temp_calc, W        ; W = 2X (Bunu kenara, W'ye ald?k)

	BCF     STATUS, 0
	RLF     temp_calc, F        ; temp = 4X
	BCF     STATUS, 0
	RLF     temp_calc, F        ; temp = 8X

	ADDWF   temp_calc, W        ; W = 2X + 8X = 10X (Onlar basama?? tamam)

	; ?imdi Birler basama??n? ekle
	ADDWF   girilen_birler, W   ; W = (Onlar*10) + Birler
	MOVWF   temp_calc           ; Sonucu temp_calc'a kaydet (Örn: 25)

    
    ; 2. ADIM: L?M?T KONTROLÜ (Örnek: Min 18, Max 40 Derece)
    	; Üst Limit Kontrolü (MAX 50 )
	MOVF    temp_calc, W
	SUBLW   50              
	BTFSS   STATUS, 0           ; E?er sonuç negatifse (C=0), say? 50'tan büyüktür.
	GOTO    HATA_DURUMU         ; 50'tan büyükse hataya git

	; Alt Limit Kontrolü (MIN 10 )
	MOVF    temp_calc, W
	SUBLW   10               ; 10 - Say? (E?er Say? > 10 ise C=0 olur, dikkat!)
	BTFSC   STATUS, 0           ; C=1 ise (Say? <= 17) hataya git
	GOTO    HATA_DURUMU

    
    ; 3. ADIM: ATAMA (De?erler geçerli)
    
    KAYDET_VE_CIK:
	; Tamsay? k?sm?n? kaydet
	MOVF    temp_calc, W
	MOVWF   desired_temp_int    ; Ana de?i?kenimize atad?k

	; Ondal?k k?sm?n? kaydet (Bunu kontrol etmeye gerek yok, 0-9 aras?d?r zaten)
	MOVF    girilen_ondalik, W
	MOVWF   desired_temp_frac   ; Ana ondal?k de?i?kene atad?k

	; ??lem ba?ar?l? mesaj? veya LCD güncellemesi buraya
	RETURN ;Döngüye geri dön

    ;--------------------------------------------------------------------------
    ; HATA YÖNET?M?
    ;--------------------------------------------------------------------------
    HATA_DURUMU:
	; Kullan?c? saçma bir de?er girdi (Örn: 99 derece veya 05 derece)
	; Burada bir hata LED'i yakabilirsin veya LCD'de "GECERSIZ" yazabilirsin.
	; ?imdilik sadece de?erleri s?f?rlay?p ba?a dönelim.
	CLRF    desired_temp_int
	CLRF    desired_temp_frac
	RETURN
    
	
    END