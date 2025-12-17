#include <xc.inc> 
; istenen s?cakl?k, ortam s?cakligi, fan h?z? 2 saniye aral?klarla gösterilir
;FONKSIYONLARIN bildirisi
GLOBAL digitlere_ayir  ; burada D1-D4 icin hangi sayilar old. belirlenir
GLOBAL updateDisplay   ; hangi D1-D4 icin bit oruntusunu gonderme
GLOBAL getDisplayNumber ;abcdefgh ledlerinin hangisinin yanacagini belirleme

    
    
    
;GLOBAL DEGISKENLER bildirisi
GLOBAL ambient_temp_int
    
GLOBAL desired_temp_int
    
GLOBAL fan_rps

GLOBAL digitNum
GLOBAL digitOnes
GLOBAL digitTens
GLOBAL digitHundreds
GLOBAL digitThousands
GLOBAL birler
GLOBAL onlar
    
    
;LOCAL degiskenlerin tanimlanmasi
PSECT udata

result: DS 1
remainder: DS 1
counter: DS 1
sayi: DS 1
temp_sayi: DS 1
number: DS 1    
tmp: DS 1
    
; Fonksiyonlar    
PSECT code,class=CODE,delta=2   
digitlere_ayir:
    ;..._temp_int ve ..._temp_frac kisimlarini digitlere ayirir
    ; WREG'e atilan sicaklik degerini digitlere ayirir
    MOVWF sayi   ; sayi=W
    MOVLW 0
    CALL divide_10 ; buradan kalan ve bölüm, birler ve onlar basama?? olur
    MOVF remainder,W
    MOVWF birler
    MOVF result,W
    MOVWF onlar
    
    RETURN
;---------------------------------------------------------------
    
    divide_10:
	MOVF sayi, W
	MOVWF temp_sayi         
	MOVLW 8
	MOVWF counter           
	CLRF result             
	CLRF remainder          

    process:
    ; Adim 1: result'i sola kaydir (once!)
    BCF STATUS, STATUS_C_POSITION
    RLF result, F
    
    ; Adim 2: temp_sayi'nin MSB'sini remainder'a kaydir
    RLF temp_sayi, F     ; temp_sayi sola, MSB -> Carry
    RLF remainder, F     ; Carry -> remainder'in LSB'si
    
    ; Adim 3: remainder >= 10 kontrolu
    MOVLW 10
    SUBWF remainder, W   ; W = remainder - 10
    BTFSS STATUS, STATUS_C_POSITION
    GOTO next            ; remainder < 10 ? sonraki iterasyon
    
    ; Adim 4: remainder = remainder - 10
    MOVLW 10
    SUBWF remainder, F
    BSF result, 0        ; Bolum bitini set et
    
    next:
	DECFSZ counter, F
	GOTO process
	RETURN
;--------------------------------------------------------------- 
updateDisplay:
    
    MOVLW HIGH(updateDisplay) ; Önce PCLATH'? bu fonksiyonun sayfas?na ayarla
    MOVWF PCLATH
    
    MOVLW 0
    MOVF digitNum , W
    
    ;MOVLW HIGH(updateDisplay) ; Bu etiketin oldu?u yerin Yüksek Adresini al
    ;MOVWF PCLATH              ; PCLATH'a yükle (Art?k do?ru sayfaday?z)
    MOVF digitNum , W
    ADDWF PCL,F
    NOP
    GOTO updateDisplay_ONES ;Update ones
    GOTO updateDisplay_TENS ;Update tens
    GOTO updateDisplay_HUNDREDS ;Update hundreds
    GOTO updateDisplay_THOUSANDS ;Update thousands
    updateDisplay_ONES:
    CLRF PORTA ;Reset digits
    MOVF digitOnes, W
    CALL getDisplayNumber ;Get the diplay number
    MOVWF PORTD ;Set the display number
    MOVLW 00000010B ; RA1 = 1 
    MOVWF PORTA ;Select ones digit
    GOTO updateDisplay_END
    updateDisplay_TENS:
    CLRF PORTA ;Reset digit
    MOVF digitTens, W
    CALL getDisplayNumber ;Get the diplay number
    MOVWF PORTD ;Set the display number
    MOVLW 00000100B ; RA2=1
    MOVWF PORTA ;Select tens digit
    GOTO updateDisplay_END
    updateDisplay_HUNDREDS:
    CLRF PORTA ;Reset digit
    MOVF digitHundreds, W
    CALL getDisplayNumber ;Get the diplay number
    MOVWF PORTD ;Set the display number
    MOVLW 00001000B ; RA3=1
    MOVWF PORTA ;Select hundreds digit
    GOTO updateDisplay_END
    updateDisplay_THOUSANDS:
    CLRF PORTA ;Reset digit
    MOVF digitThousands, W
    CALL getDisplayNumber ;Get the diplay number
    MOVWF PORTD ;Set the display number
    MOVLW 00010000B
    MOVWF PORTA ;Select thousands digit
    GOTO updateDisplay_END
    updateDisplay_END:
    RETURN
    
;------------------------------------------------------------    
    
    
getDisplayNumber:
    MOVWF number  ;number=W
    
    MOVLW 0
    SUBWF number, w
    BTFSS STATUS, STATUS_C_POSITION
    RETLW 0 ; if(number<0)
    MOVF number, w
    SUBLW 15
    BTFSS STATUS, STATUS_C_POSITION
    RETLW 0 ; if(number>15)
    ; else
    MOVF number, W
    ADDWF PCL,F
    RETLW 11111100B ; 0
    RETLW 01100000B ; 1
    RETLW 11011010B ; 2
    RETLW 11110010B ; 3
    RETLW 01100110B ; 4
    RETLW 10110110B ; 5
    RETLW 10111110B ; 6
    RETLW 11100000B ; 7
    RETLW 11111110B ; 8
    RETLW 11110110B ; 9
    RETLW 11101110B ; A
    RETLW 00111110B ; B (b)
    RETLW 10011100B ; C
    RETLW 01111010B ; D (d)
    RETLW 10011110B ; E