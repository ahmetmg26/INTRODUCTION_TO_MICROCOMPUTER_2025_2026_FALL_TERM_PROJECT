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
    GLOBAL ham_tus
    GLOBAL temp_tus
    GLOBAL girilen_onlar
    GLOBAL girilen_birler
    GLOBAL girilen_ondalik

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

; Keypad degiskeni tanýmla
ham_tus: DS 1
temp_tus: DS 1    
girilen_onlar:  DS 1    ; Ýlk rakam (Örn: 2)
girilen_birler: DS 1    ; Ýkinci rakam (Örn: 4)
girilen_ondalik: DS 1   ; Virgülden sonraki rakam (Örn: 5)
temp_calc: DS 1 ;    onlar ve birler'i desired_temp_int deðerinde toplamak için
PSECT code
 
MAIN:
    CALL PortInit
    
    ; Ba?lang?? de?erleri
    MOVLW 35
    BANKSEL desired_temp_int
    MOVWF desired_temp_int
    CLRF desired_temp_frac
    
READ_LOOP:
    CALL TEMP_ReadAmbient       ; temperature_module.asm'den
    CALL TEMP_UpdateFanControl      ; temperature_module.asm'den
    
    ; Test: desired temp'i 7-seg-display'e g?ster
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
    ;----------------------------------
    ; keypad tarama 
    
    CALL tus_A_var_mi
    ; eðer w=0 dönmüþse girilen formatta sorun vardir, tekrar A'ya basýlmasý istenir (Z = 1 )
    ; w=1 dönmüþse format doðrudur, desired_int ve frac deðerlerine atama yapýlýr (Z=0
    SUBLW 1
    BTFSS STATUS, 2
    GOTO READ_LOOP          ; 'A' basýlmamýþ, devam et
    
    ; 'A' basýldý! Þimdi kalan adýmlarý BLOCKING yap
    CALL KEYPAD    ; Yeni fonksiyon (aþaðýda)
    
    ; Dönüþ deðeri kontrol et
    SUBLW 1
    BTFSS STATUS, 2
    GOTO READ_LOOP          ; Hatalý giriþ
    
    ; Baþarýlý giriþ!
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
    ;MOVLW 0x8E        ; SADECE AN0 analog, saga yasli Vdd/Vss referans
    MOVLW 0x0E ; sola yasli
    MOVWF ADCON1

    BANKSEL ADCON0
    MOVLW 0x81        ; ADC ON, kanal AN0
    MOVWF ADCON0

    ; ---- PORTB Ayar? ----
    BANKSEL TRISB
    MOVLW 00000100B ; RB2 giri? (tach), RB0/RB1 cikis --> temperature
		    ; RB4/RB7 cikis --> keypad
    MOVWF TRISB
    
    BCF     OPTION_REG, 7  ;OPTION_REG yazmacýnýn 7. biti (RBPU) 0 olmalý. PULL-UP direnci icin
    
    
    ; -- PORTC ayarlama -- 
    BANKSEL TRISC
    MOVLW 00001111 ; RC0/RC3 input  --> keypad icin
    MOVWF TRISC
    
    
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
	;CALL    tus_bekle_oku   ; Bir tuþ bekle
	;SUBLW   0x0A            ; Girilen tuþ 'A' (0x0A) mý?
	;BTFSS   STATUS, 2       ; Sonuç 0 ise (Z=1) eþittir.
	;RETLW 0        ; Deðilse, tekrar A gelene kadar bekle. ~~

	; -----------------------------------------------------------
	; ADIM 2: BÝRÝNCÝ RAKAMI AL (ONLAR BASAMAÐI)
	; -----------------------------------------------------------
    ADIM_2_R1:
	CALL    tus_bekle_oku   ; Tuþ bekle
	MOVWF   girilen_onlar   ; Gelen tuþu sakla

	; Kontrol: Basýlan tuþ rakam mý? (0-9 arasý mý?)
	; 9'dan büyükse (A,B,C,D,*,#) hata var demektir, baþa dön.
	SUBLW   0x09            ; 9 - W iþlemi
	BTFSS   STATUS, 0       ; Carry=0 ise W > 9 demektir (Negatif sonuç)
	RETLW 0        ; Rakam deðilse baþa dön (Reset)

	; -----------------------------------------------------------
	; ADIM 3: ÝKÝNCÝ RAKAMI AL (BÝRLER BASAMAÐI)
	; -----------------------------------------------------------
    ADIM_3_R2:
	CALL    tus_bekle_oku
	MOVWF   girilen_birler

	; Kontrol: Rakam mý?
	SUBLW   0x09
	BTFSS   STATUS, 0       ; W > 9 ise
	RETLW 0        ; Baþa dön

	; -----------------------------------------------------------
	; ADIM 4: '*' KARAKTERÝNÝ BEKLE (0x0E)
	; -----------------------------------------------------------
    ADIM_4_YILDIZ:
	CALL    tus_bekle_oku
	SUBLW   0x0E            ; '*' tuþu tablonda 0x0E mi?
	BTFSS   STATUS, 2       ; Eþit mi?
	RETLW 0        ; Deðilse baþa dön

	; -----------------------------------------------------------
	; ADIM 5: ÜÇÜNCÜ RAKAMI AL (ONDALIK KISIM)
	; -----------------------------------------------------------
    ADIM_5_R3:
	CALL    tus_bekle_oku
	MOVWF   girilen_ondalik

	; Kontrol: Rakam mý?
	SUBLW   0x09
	BTFSS   STATUS, 0
	RETLW 0

	; -----------------------------------------------------------
	; ADIM 6: '#' KARAKTERÝNÝ BEKLE (BÝTÝÞ) (0x0F)
	; -----------------------------------------------------------
    ADIM_6_KARE:
	CALL    tus_bekle_oku
	SUBLW   0x0F            ; '#' tuþu tablonda 0x0F mi?
	BTFSS   STATUS, 2
	RETLW 0        ; Deðilse baþa dön
	;DOÐRU GÝRÝÞ YAPILDI!
	RETLW 1
    
kontrol_ve_atama:
	
	; (X * 10) = (X * 8) + (X * 2)
	
	MOVF    girilen_onlar, W
	MOVWF   temp_calc           ; temp = X
	BCF     STATUS, 0
	RLF     temp_calc, F        ; temp = 2X

	MOVF    temp_calc, W        ; W = 2X (Bunu kenara, W'ye aldýk)

	BCF     STATUS, 0
	RLF     temp_calc, F        ; temp = 4X
	BCF     STATUS, 0
	RLF     temp_calc, F        ; temp = 8X

	ADDWF   temp_calc, W        ; W = 2X + 8X = 10X (Onlar basamaðý tamam)

	; Þimdi Birler basamaðýný ekle
	ADDWF   girilen_birler, W   ; W = (Onlar*10) + Birler
	MOVWF   temp_calc           ; Sonucu temp_calc'a kaydet (Örn: 25)

    
    ; 2. ADIM: LÝMÝT KONTROLÜ (Örnek: Min 18, Max 40 Derece)
    	; Üst Limit Kontrolü (MAX 50 )
	MOVF    temp_calc, W
	SUBLW   50              
	BTFSS   STATUS, 0           ; Eðer sonuç negatifse (C=0), sayý 50'tan büyüktür.
	GOTO    HATA_DURUMU         ; 50'tan büyükse hataya git

	; Alt Limit Kontrolü (MIN 10 )
	MOVF    temp_calc, W
	SUBLW   10               ; 10 - Sayý (Eðer Sayý > 10 ise C=0 olur, dikkat!)
	BTFSC   STATUS, 0           ; C=1 ise (Sayý <= 17) hataya git
	GOTO    HATA_DURUMU

    
    ; 3. ADIM: ATAMA (Deðerler geçerli)
    
    KAYDET_VE_CIK:
	; Tamsayý kýsmýný kaydet
	MOVF    temp_calc, W
	MOVWF   desired_temp_int    ; Ana deðiþkenimize atadýk

	; Ondalýk kýsmýný kaydet (Bunu kontrol etmeye gerek yok, 0-9 arasýdýr zaten)
	MOVF    girilen_ondalik, W
	MOVWF   desired_temp_frac   ; Ana ondalýk deðiþkene atadýk

	; Ýþlem baþarýlý mesajý veya LCD güncellemesi buraya
	RETURN ;Döngüye geri dön

    ;--------------------------------------------------------------------------
    ; HATA YÖNETÝMÝ
    ;--------------------------------------------------------------------------
    HATA_DURUMU:
	; Kullanýcý saçma bir deðer girdi (Örn: 99 derece veya 05 derece)
	; Burada bir hata LED'i yakabilirsin veya LCD'de "GECERSIZ" yazabilirsin.
	; Þimdilik sadece deðerleri sýfýrlayýp baþa dönelim.
	CLRF    desired_temp_int
	CLRF    desired_temp_frac
	RETURN
    
	
    END