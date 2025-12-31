# Board 1 & Board 2 - Home Automation System

PIC16F877A tabanlı ev otomasyon sistemi.
Çalıştırılması gereken tüm kodlar son olarak Board_1 klasötü içerisinde toplanmıştır.
---

## Board 1 - Sıcaklık Kontrol Sistemi

| Dosya | Açıklama |
|-------|----------|
| `main.asm` | Ana kaynak kodu |
| `board1.hex` | Derlenmiş HEX |
| `board1.pzw` | PICSimLab workspace |
| `board1.pcf` | Parts configuration |

**Donanım:**
```
Heater → RA1 | Cooler → RA2 | Temp ADC → RA0 | Tach → RA4
7-Segment → RD0-RD7, RC0-RC3 | Keypad → RB0-RB7
UART → RC6 (TX), RC7 (RX) - 9600 baud
```

---

## Board 2 - Perde Kontrol Sistemi

| Dosya | Açıklama |
|-------|----------|
| `board2.asm` | Ana kaynak kodu |
| `board2.hex` | Derlenmiş HEX |
| `board2.pzw` | PICSimLab workspace |
| `board2.pcf` | Parts configuration |

**Donanım:**
```
LCD: RS → RE0, E → RE1, RW → RB7, D4-D7 → RD4-RD7
Sensörler: LDR → RA0, Potansiyometre → RA1
Motor: RB0-RB3 (Step Motor)
UART → RC6 (TX), RC7 (RX) - 9600 baud
```

---

## PC Uygulaması

| Dosya | Açıklama |
|-------|----------|
| `home_automation.py` | Board 1 UART GUI |
| `curtain_control.py` | Board 2 UART GUI |
| `main_app.py` | Ana menü |
| `requirements.txt` | Python bağımlılıkları |
| `test_main.asm` | Test kodu |
