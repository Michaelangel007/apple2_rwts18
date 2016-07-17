; Roland Gustafsson's RWTS18 Source
; Apple ][ Time Capsule
; https://www.youtube.com/watch?v=ScFrXoD99hw
; Transcribed by Michael Pohoreski, AppleWin "Debugger" Developer
; Assembler: ca65
.feature labels_without_colons
.feature leading_dot_in_identifiers
.P02    ; normal 6502
; Utility macros because ca65 is crap out-of-the-box for Apple 2 assembly
.macro ADR val
    .addr val
.endmacro
; Force APPLE 'text' to have high bit on; Will display as NORMAL characters
.macro ASC text
    .repeat .strlen(text), I
        .byte   .strat(text, I) | $80
    .endrep
.endmacro

.macro BYT b1,b2,b3,b4
        .byte b1

    .ifnblank b2
        .byte b2
    .endif 
    .ifnblank b3
        .byte b3
    .endif 
    .ifnblank b4
        .byte b4
    .endif 
.endmacro

; Usage: NIBS2BYTE "A","A"
.macro NIBS2BYTE c1, c2
    .local val
    .local hi, lo, val

    .if ((c1 >= '0') && (c1 <= '9'))
        hi = c1 - '0'
    .else
        .if ((c1 >= 'A') && (c1 <= 'F'))
            hi = c1 - 'A' + 10
        .else
            .if ((c1 >= 'a') && (c1 <= 'f'))
                hi = c1 - 'a' + 10
            .endif
        .endif
    .endif
    .if ((c2 >= '0') && (c2 <= '9'))
        lo = c2 - '0'
    .else
        .if ((c2 >= 'A') && (c2 <= 'F'))
            lo = c2 - 'A' + 10
        .else
            .if ((c2 >= 'a') && (c2 <= 'f'))
                lo = c2 - 'a' + 10
            .endif
        .endif
    .endif

    val = hi*16 + lo
    .byte val
.endmacro

; Convert a text string to bytes. Example: HEX "A900"
.macro HEX text
    .local c1, c2, len
    len .set .strlen(text)

    .if ((len & 1) <> 0)
        .error "HEX bytes must be even length -- one nibble too short"
        .out .sprintf( "Length: %d", n )
        .out .sprintf( "String: %s", text )
    .else
        .repeat len/2, I
            c1  .set .strat( text, I*2+0 )
            c2  .set .strat( text, I*2+1 )
         NIBS2BYTE c1, c2
        .endrep
    .endif
.endmacro
; ???
.macro NOG
.endmacro
; ???
.macro NLS
.endmacro

.macro TTL title
    .out title
.endmacro

.macro USR filename, origin
.endmacro
            __MAIN = $D000
; DOS3.3 retarded design -- stores file's meta as first 4 bytes in binary file
; Remove these 2 if running under ProDOS
            .word __MAIN         ; 2 byte BLOAD address
            .word __END - __MAIN ; 2 byte BLOAD size
            NLS
            TTL "S:RW18.D000"
            NOG
ORG         = $D000
;---------------
;
; 07/20/05
;
; 18 sector read/write routine
;
;        Copyright 1985
;     by Roland Gustafsson
;
;---------------
SN1         = $D5
SN2         = $9D
SN3         = $AA
SN4         = $D4
SNX         = $FF
;
BRBUNDID    = $A4               ; Br0derbund ID
;---------------
;
; Permanent vars
;
SLOT        = $FD
TRACK       = $FE
LASTRACK    = $FF
SLOTABS     = SLOT
;---
;
; Temporary vars
;
DAT         = $E0
;
BUF1        = DAT
BUF2        = DAT+2
BUF3        = DAT+4
LEFT        = DAT+6
TRACKGOT    = DAT+8
SECTOR      = DAT+9
RETRIES     = DAT+10
TEMP        = DAT+11
CHECKSUM    = DAT+12
TEMP1       = DAT+13
TEMP2       = DAT+14
COMMAND     = DAT+15
;
; VERY temporary vars used by SEEK
;
TMP0        = BUF1
TMP1        = BUF1+1
TMP2        = BUF2
TMP3        = BUF2+1
;------------
;
GARPAGE     = ORG+$500          ; $D500
LEFTOVER    = ORG+$600          ; $D600
BITS1       = ORG+$C00          ; $DC00
BITS2       = ORG+$D00          ; $DD00
BITS3       = ORG+$E00          ; $DE00
BUFTABLE    = ORG+$F00          ; $DF00
;
; DENIBBLE  uses $96..$FF
;
DENIBBLE    = BUFTABLE          ; $DF00
SECTDONE    = BUFTABLE+18       ; $DF12
ZPAGSAVE    = SECTDONE+6        ; $DF18
;-----------
            .org ORG
;           OBJ $0800
;-----------
            JMP RW18            ; v L#618
;-----------
;
; Valid disk nibbles
;
NIBBLES     HEX "96979A9B9D9E9FA6"
            HEX "A7ABACADAEAFB2B3"
            HEX "B4B5B6B7B9BABBBC"
            HEX "BDBEBFCBCDCECFD3"
            HEX "D6D7D9DADBDCDDDE"
            HEX "DFE5E6E7E9EAEBEC"
            HEX "EDEEEFF2F3F4F5F6"
            HEX "F7F9FAFBFCFDFEFF"
;-----------
;
; The first part make sthe disk
; look like a BSW master disk.  ; Br0derbund SoftWare??
;
SOFTSYNC    HEX "A596BFFFFEAABBAAAAFFEF9A"
;
NOTFSEC     BYT SN1,SN2
TRACKMOD    HEX "96"
SECMOD      HEX "96"
CHECKMOD    HEX "96"
            BYT SN3,SNX,SNX,0
;-----------
;
; Write routine, timing critical code!
;
; Write out #$FF sync bytes at
; 40 microseconds, # given in Y.
;
WRITETC     LDA #$FF            ; Write Timed Cycles?
            STA $C08F,X     ; 5     Q7H = DRIVE_MODE_W
            ORA $C08C,X     ; 4     Q6L = DRIVE_LATCH_R
            ROL TEMP        ; 5
_109        NOP             ; 2     ^0
            JSR _RTS        ;12
            JSR _RTS        ;12     = 40
            STA $C08C,X     ; 5     Q6L = DRIVE_LATCH_R
;                           ;
            ORA $C08C,X     ; 4     Q6L = DRIVE_LATCH_R
            DEY             ; 2
            BNE _109        ; 3/2     <0
;-----------                ;
SYNCMOD     LDY #00         ; 2
_119        LDA SOFTSYNC,Y  ; 4     ^1
            BEQ _132        ; 2/3     >2
            INY             ; 2
            NOP             ; 2
            NOP             ; 2
            NOP             ; 2
            LDX SLOT        ; 3
            STA $C08D,X     ; 5     Q6H = DRIVE_LATCH_W
;                           ;
            ORA $C08C,X     ; 4     Q6L = DRIVE_LATCH_R
            LDX SLOT        ; 3
            BNE _119        ; 3       <1
;-----------
_132        NOP             ; 2     ^2
            NOP             ; 2
            NOP             ; 2
            NOP             ; 2
IDMOD0      LDA #BRBUNDID   ; 2 Self-modified @ L#792
            STA $C08D,X     ; 5     Q6H = DRIVE_LATCH_W
;                           ;
            ORA $C08C,X     ; 4     Q6L = DRIVE_LATCH_R
            LDY #00         ; 2
            STY CHECKSUM    ; 3
;                           ;
_143        LDA (LEFT),Y    ; 5     ^0
            TAX             ; 2
            EOR CHECKSUM    ; 3
            STA CHECKSUM    ; 3
            LDA NIBBLES,X   ; 4
            NOP             ; 2
Q6HMOD0     STA $C0ED       ; 4     Q6H = DRIVE_LATCH_W Self-modifed @ L#517
;                           ;
Q6LMOD0     ORA $C0EC       ; 4     Q6L = DRIVE_LATCH_R Self-modifed @ L#510
            LDA (BUF1),Y    ; 4
            AND #$3F        ; 2     Disk nibbles 6&2 = 64
            TAX             ; 2
            EOR CHECKSUM    ; 3
            STA CHECKSUM    ; 3
            LDA NIBBLES,X   ; 4
            LDX SLOTABS     ; 4
            STA $C08D,X     ; 5     Q6H = DRIVE_LATCH_W
;                           ;
            ORA $C08C,X     ; 4     Q6L = DRIVE_LATCH_R
            LDA (BUF2),Y    ; 5
            AND #$3F        ; 2
            TAX             ; 2
            EOR CHECKSUM    ; 3
            STA CHECKSUM    ; 3
            LDA NIBBLES,X   ; 4
            LDX SLOTABS     ; 4
            STA $C08D,X     ; 5     Q6H = DRIVE_LATCH_W
;                           ;
            ORA $C08C,X     ; 4     Q6L = DRIVE_LATCH_R
            LDA (BUF3),Y    ; 5
            AND #$3F        ; 2
            TAX             ; 2
            EOR CHECKSUM    ; 3
            STA CHECKSUM    ; 3
            LDA NIBBLES,X   ; 4
            LDX SLOTABS     ; 4
            STA $C08D,X     ; 5     Q6H = DRIVE_LATCH_W
;                           ;
            ORA $C08C,X     ; 4     Q6L = DRIVE_LATCH_R
            INY             ; 2
            BNE _143        ; 3/2     <0
;                           ;
            LDX CHECKSUM    ; 3
            LDA NIBBLES,X   ; 4
            LDX SLOT        ; 3
            JSR WRNIBBL2    ; 6   v L#203
            LDA #SN4
            JSR WRNIBBLE        ; v L#200
            LDA #SNX
            JSR WRNIBBLE        ; v L#200
;
            LDA $C08E,X         ; Q7L = DRIVE_MODE_R
            LDA $C08C,X         ; Q6L = DRIVE_LATCH_R
            RTS
;
; Write a nibble
;
WRNIBBLE    NOP             ; 2 Cycles = 18
            NOP             ; 2
            CLC             ; 2
WRNIBBL2    LDX SLOT        ; 3 Cycles = 12
            STA $C08D,X     ; 5 ; Q6H = DRIVE_LATCH_W
;                           ;
            ORA $C08C,X     ; 4 ; Q6L = DRIVE_LATCH_R
            RTS
;-----------
;
; Write a track. Same parameters as
; the READ routine
; Call PRENIBL to create the $600 byte
; LEFTOVER table.
;
WRITE       JSR INITBUF
            LDY TRACK
            LDA NIBBLES,Y
            STA TRACKMOD
;
; Compute track/sector checksum
;
_222        LDA SECTOR          ; ^1
            EOR TRACK
            TAY
            LDA NIBBLES,Y
            STA CHECKMOD
;
; Point to buffers
;
            JSR GETBUFS
            LDA NIBBLES,Y
            STA SECMOD
;
            CPY #5
            BEQ _249            ;   >2
;
; If this is not the first sector,
; then don't write out BSW id bytes
; and only write out 4 self-syncs.
;
            LDA #(NOTFSEC-SOFTSYNC)
            LDY #4
            BNE _252            ;   >3
;
; First sector, write out BSW id bytes
; and 200 self-sync bytes to ensure
; the the track is erased.
;
_249        LDA #0              ; ^2
            LDY #200
;
_252        STA SYNCMOD+1       ; ^3
;
; Make disk controller happy
; by checking for write protect
;
            LDA $C08D,X         ; Q6H = DRIVE_LATCH_W
            LDA $C08E,X         ; Q7L = DRIVE_MODE_R
            SEC
            BMI _265            ;   >4
            JSR WRITETC
            INC LEFT+1
            DEC SECTOR
            BPL _222            ;   <1
_265        RTS                 ; ^4
;-----------
;
; Init SECTOR, buffer pointers.
;
INITBUF     LDA #5
            STA SECTOR
            LDY #0
            STY BUF1
            STY BUF2
            STY BUF3
            LDA #>LEFTOVER      ; /LEFTOVER == high byte
            STY LEFT
            STA LEFT+1
            LDX SLOT
            RTS
;-----------
GETNIBBL    LDX $C0EC           ; Self-modified @ L#509
            BPL *-3             ; not BPL GETNIBL ??
            LDA DENIBBLE,X
            RTS
;
; Read an entire track, with
; buffer addresses given in an 18
; byte order, BUFTABLE
;
; Return branch conditions:
;
; BCS = read error
; BNE = wrong track, A = track found
; BEQ = OK, data read in
;
READ        JSR INITBUF
            LDY #5
            LDA #48
            STA RETRIES
_301        STA SECTDONE,Y      ; ^0
            DEY
            BPL _301            ;   <0
;
READLOOP    DEC RETRIES
            BEQ READERR
            JSR READADDR
            BCS READLOOP
;
; On the right track?
;
            LDA TRACKGOT
            CMP TRACK
            CLC
            BNE _RTS            ; RTS
;
; Has this sector been read in yet?
;
            LDA SECTDONE,Y
            BEQ READLOOP
;
; Read it in!
;
            JSR READDATA
            BCS READLOOP
            LDA #0
            LDY SECTOR
            STA SECTDONE,Y
;
; Any more?
;
            LDY #5
_333        LDA SECTDONE,Y      ; ^0
            BNE READLOOP
            DEY
            BPL _333            ;   <0
            INY
_RTS        RTS                 ; RTS
;
READERR     SEC
            RTS
;-----------
;
; Read address marks
;
READADDR    LDY #$FA
            STY TEMP
_348        INY                 ; ^0
            BNE _353            ;   >1
            INC TEMP
            BEQ READERR         ; ^ L#340
;
_353        JSR GETNIBBL        ; ^1
_354        CPX #SN1            ; ^2
            BNE _348            ;   <0
            JSR GETNIBBL
            CPX #SN2
            BNE _354            ;   <2
;
            JSR GETNIBBL
            STA TRACKGOT
            JSR GETNIBBL
            STA SECTOR
            JSR GETNIBBL
            EOR TRACKGOT
            EOR SECTOR
            BNE _348            ;   <0
            JSR GETNIBBL
            CPX #SN3
            BNE _348            ;   <0
            CLC
;
; Given sector, set buffer pointers
;
GETBUFS     LDY SECTOR
            LDA BUFTABLE,Y
            STA BUF1+1
            LDA BUFTABLE+6,Y
            STA BUF2+1
            LDA BUFTABLE+12,Y
            STA BUF3+1
            RTS
;-----------
;
; Read sector.
;
; First find data mark, which is
; BRBUNID
;
READDATA    LDY #4
_391        DEY                 ; ^0
            BEQ READERR
            JSR GETNIBBL
IDMOD1      CPX #BRBUNDID       ; Self-modified @ L#793
            BNE _391            ;   <0
;
; Now read in data
;
; Initialize checksum to zero!
; See code further below to better  ; futhur -> futher
; understand what is happening here.
;
            LDY #0
            LDA TEMP1
;
; Main read loop
;
READDAT2:
Q6LMOD1     LDX $C0EC           ; Self-modified @ L#511
            BPL *-3
            EOR TEMP1
            EOR DENIBBLE,X
            STA CHECKSUM
            LDA DENIBBLE,X
            ASL
            ASL
            STA TEMP
;
Q6LMOD2     LDX $C0EC           ; Self-modified @ L#512
            BPL *-3
            AND #$C0
            ORA DENIBBLE,X
            STA (BUF1),Y
            STA TEMP1
            LDA TEMP
            ASL
            ASL

Q6LMOD3     LDX $C0EC           ; Self-modified @ L#513
            BPL *-3
            STA TEMP
            AND #$C0
            ORA DENIBBLE,X
            STA (BUF2),Y
            STA TEMP2
            LDA TEMP
            ASL
;                               ; second ASL on L#441
Q6LMOD4     LDX $C0EC           ; Self-modified @ L#514
            BPL *-3
            ASL
            ORA DENIBBLE,X
            STA (BUF3),Y
            EOR TEMP2
            EOR CHECKSUM
            INY
            BNE READDAT2        ; ^ L#408
;
; Get checksum
;
Q6LMOD5     LDX $C0EC           ; Self-modified @ L#515
            BPL *-3             ; ^
            EOR DENIBBLE,X
            EOR TEMP1
            AND #$3F
            BNE _464            ;   >0
;
            JSR GETNIBBL
            CPX #SN4
            BNE _464            ;   >0
            CLC
            RTS
;
_464        SEC                 ; ^0 BadChecksum or NotFoundSN4
            RTS
;-----------
;
; Prenibble data into LEFTOVER
; buffer.
;
; A:BUF1, B:BUF2, C:BUF3
;
; A7 A6 B7 B7 C7 C6 --> Leftovers
; A5 A4 A3 A2 A1 A0  \
; B5 B4 B3 B2 B1 B0   > Data
; C5 C4 C3 C2 C1 C0  /
;
PRENIBL     JSR INITBUF
_479        JSR GETBUFS         ; ^0
            LDA BUF1+1
            STA BUF1MOD+2       ; Self-modifies L#488 LDX $??00,Y
            LDA BUF2+1
            STA BUF2MOD+2       ; Self-modifies L#490 LDX $??00,Y
            LDA BUF3+1
            STA BUF3MOD+2       ; Self-modifies L#492 LDX $??00,Y
;
            LDY #0
BUF1MOD     LDX $FF00,Y         ; Self-modified @ L#481
            LDA BITS1,X
BUF2MOD     LDX $FF00,Y         ; Self-modified @ L#483
            ORA BITS2,X
BUF3MOD     LDX $FF00,Y         ; Self-modified @ L#485
            ORA BITS3,X
            STA (LEFT),Y
            INY
            BNE BUF1MOD
            INC LEFT+1
            DEC SECTOR
            BPL _479            ;   <0
            RTS
;-----------
;
; Prepare RW18 for use
;
; given A=slot*16
;
PREP        STA PREPSLOT
            ORA #$8C            ; $C08C,X = $C0EC = Q6L = DRIVE_LATCH_R
            STA GETNIBBL+1      ; Self-modifies L#]
            STA Q6LMOD0+1       ; Self-modifies L#151
            STA Q6LMOD1+1       ; Self-modifies L#409
            STA Q6LMOD2+1       ; Self-modifies L#419
            STA Q6LMOD3+1       ; Self-modifies L#429
            STA Q6LMOD4+1       ; Self-modifies L#439
            STA Q6LMOD5+1       ; Self-modifies L#451
            ORA #$1             ; $C08D,X = $C0ED = Q6H = DRIVE_LATCH_W
            STA Q6HMOD0+1       ; Self-modifies L#149
;
; Set up DENIBBL table, used by READ
;
            LDY #$3F            ; 6&2 disk nibbles = 64
_522        LDX NIBBLES,Y       ; ^0
            TYA
            STA DENIBBLE,X
            DEY
            BPL _522            ;   <0
;
; Set up BITS tables for PRENIBL
;
            LDY #0
_531        TYA                 ; ^1
            AND #$C0
            LSR
            LSR
            STA BITS1,Y
            LSR
            LSR
            STA BITS2,Y
            LSR
            LSR
            STA BITS3,Y
            INY
            BNE _531            ;   <1
            RTS
;-----------
;
; R/W head SEEK routine
;
; A:track
;
SEEK        ASL                 ; Apple 2 Disk ][ = 2 phases/track
            STA TMP2
            CMP LASTRACK
            BEQ SEEKDONE        ; v L#596
            LDA #0
            STA TMP0
;
SEEKLOOP    LDA LASTRACK
            STA TMP1
            SEC
            SBC TMP2
            BEQ SEEKTOG2
            BCS _568            ;   >0
            EOR #$FF            ; x-y = x + (y^FF+1) 2's compliment subtraction
            INC LASTRACK
            BCC _570            ;   >1
;
_568        ADC #$FE            ; ^0
            DEC LASTRACK
_570        CMP TMP0            ; ^1
            BCC _573            ;   >2
            LDA TMP0
_573        CMP #$0C            ; ^2
            BCS _575            ;   >3
            TAY
_575        SEC                 ; ^3
            JSR SEEKTOG1
            LDA SEEKTBL1,Y
            JSR SEEKDELY
            LDA TMP1
            CLC
            JSR SEEKTOGL
            LDA SEEKTBL2,Y
            JSR SEEKDELY
            INC TMP0
            BNE SEEKLOOP
SEEKTOG2    JSR SEEKDELY
            CLC
SEEKTOG1    LDA LASTRACK
;
SEEKTOGL    AND #$03
            ROL
            ORA SLOT
            TAX
            LDA $C080,X
SEEKDONE    LDX SLOT
            RTS
;
SEEKDELY    LDX #$13
_600        DEX                 ; ^0
            BNE _600            ;   <0
            SEC
            SBC #1
            BNE SEEKDELY
            RTS
;
; Acceleration/deceleration tables
;                               ; Lifted from Woz's code -- DOS 3.2/3.3
SEEKTBL1    HEX "01302824201E1D1C1C1C1C1C"
SEEKTBL2    HEX "702C26221F1E1D1C1C1C1C1C"
;
            ASC "COPYRIGHT 1985 "       ; 15 Wasted bytes
            ASC "BY ROLAND GUSTAFSSON"  ; 20 Wasted bytes
;-----------
;
; Entry point into RW18
;
RW18        PLA
            STA GOTBYTE+1
            PLA
            STA GOTBYTE+2
;
            JSR SWAPZPAG
;
            LDA SLOT
            CMP #00
PREPSLOT    =   *-1
            BEQ _631            ;   >0
            JSR PREP
;
_631        JSR GETBYTE         ; ^0
            STA COMMAND
            AND #$0F
            ASL
            TAX
;
            LDA CMDTABLE,X
            STA _641+1          ;   >1+1 Self-modifies L#641]
            LDA CMDTABLE+1,X
            STA _641+2          ;   >1+2 Self-modifies L#641]
_641        JSR $FFFF           ; ^1     Self-modified @ L#638-640
;
            LDA GOTBYTE+2
            PHA
            LDA GOTBYTE+1
            PHA
;
SWAPZPAG    LDX #15             ;        DAT[$0..$F] <--> ZPAGSAVE[$0..$0F]
_649        LDA DAT,X           ; ^0
            LDY ZPAGSAVE,X
            STA ZPAGSAVE,X
            STA DAT,X
            DEX
            BPL _649            ;   <0
            RTS

CMDTABLE    ADR CMDRIVON      ; Drive On       L#670
            ADR CMDRIVOF      ; Drive Off      L#697
            ADR CMSEEK        ; Seek           L#706
            ADR CMREADSQ      ; Read Sequnce   L#735
            ADR CMREADGP      ; Read Group     L#738
            ADR CMWRITSQ      ; Write Sequence L#780
            ADR CMWRITGP      ; Write Group    L#782
            ADR CMIDMOD       ; Change Id Mod  L#791
;-----------
;
; DRIVE ON
; <drive#>,<delay, in 1/10ths [of] sec[onds]>
; NOTE: Drive = 1 or 2
CMDRIVON    LDX SLOT
            JSR GETBYTE         ; A=1 (Drive 1) or 2 (Drive 2)
            ORA SLOT
            TAY                 ; Roland originally had $C089 but $C08A-1 is clearer
            LDA $C08A-1,Y       ; DRIVE_MOTOR_ON -> DRIVE_SELECT
            LDA $C089,X         ; DRIVE_MOTOR_ON
;
; Delay 1/10ths of seconds
;
            JSR GETBYTE
            BEQ _692            ;   >2
            STA TMP0            ;       $00E0
_682        LDY #$17            ; ^0    if delay=1
            LDX #0              ;       delay * < [ 23 * { 256*(6+6+2+2)+1 + 2+2 } + 1 + 5+2 ] + 6 >
;
_685        JSR _RTS            ; ^1    (6)
            DEX                 ;       (2)
            BNE _685            ;   <1  (2/3)
            DEY                 ;       (2)
            BNE _685            ;   <1  (2/3)
            DEC TMP0            ;       (5)
            BNE _682            ;   <0  (2/3)
_692        RTS                 ; ^2    (6)
;-----------
;
; DRIVE OFF
;
CMDRIVOF    LDX SLOT
            LDA $C088,X         ; DRIVE_MOTOR_OFF
            RTS
;-----------
;
; SEEK
; <check disk for LASTRACK?>,
; <track>
;
CMSEEK      JSR GETBYTE
            BEQ _727            ;   >1
;
; Force "Track error"
;
            LDA #255
            STA TRACK
            JSR READ
            BCC _724            ;   >0
;
; If CLC, then A = current track,
;         else recalibrate
;
            LDA #$A0
            STA LASTRACK
            LDA #0
            JSR SEEK
            LDA #0
_724        ASL                 ; ^0
            STA LASTRACK
;
_727        JSR GETBYTE         ; ^1
            STA TRACK
            JMP SEEK            ; ^ L#551
;-----------
;
; READSEQU
;

; READGROP
; <18 buf adr's>
;
CMREADSQ    LDX #1
            .byte $2C           ; BIT $abs == skip next instruction LDX #18
CMREADGP    LDX #18
            JSR CMADINFO        ; v L#799
;
CMREAD2     JSR READ
            BCS INCTRAK         ; v L#754 = INCTRAK?
            BEQ INCTRAK
            ASL
            STA LASTRACK
            LDA TRACK
            JSR SEEK            ; ^ L#551
            JMP CMREAD2         ; ^ L#743
;
; READ/WRITE exit.
;
INCTRAK     BIT COMMAND
            BCS WHOOP           ; v L#766 = WHOOP?
;
; If bit 6 set, then INC TRACK
;
            BVC _761            ;   >0
            INC TRACK
_761        RTS                 ; ^0
;
; If bit 7 set then whoop speaker
; WARNING: use only with READ
;
WHOOP       BPL _761            ;   <0
            LDY #0
_768        TYA                 ; ^1
            BIT $C030
_770        SEC                 ; ^2
            SBC #1
            BNE _770            ;   <2
            DEY
            BNE _768            ;   <1
            BEQ CMREAD2         ; ^ L#743
;-----------
;
; Same as READ
;
CMWRITSQ    LDX #1
            .byte $2C
CMWRITGP    LDX #18
            JSR CMADINFO        ; v L#799
            JSR PRENIBL         ; ^ L#478
            JSR WRITE           ; ^ L#215
            JSR INCTRAK         ; ^ L#754 == INCTRAK?
;-----------
;
; Chnage Br0derbund ID byte
;
CMIDMOD     JSR GETBYTE
            STA IDMOD0+1        ; Self-modifies L#136
            STA IDMOD1+1        ; Self-modifies L#394
            RTS
;-----------
;
; Get buffer info.
;
CMADINFO    STX TMP0
            LDX #0
_802        JSR GETBYTE         ; ^0
            STA BUFTABLE,X
            INX
            CPX TMP0
            BCC _802            ; BLT <0  (BLT==BCC, BGE==BCS)
            TAY
;
; If sequence, then fill table
;
_810        INY                 ; ^1
            CPX #18
            BEQ _820            ;   >2
            TYA
            STA BUFTABLE,X
            INX
            BNE _810            ;   <1
;
; Check for garbage pages
;
_820        DEX                 ; ^2
_821        LDA BUFTABLE,X      ; ^3
            BNE _825            ;   >4
            LDA #>GARPAGE       ; /GARPAGE == high byte
            STA BUFTABLE,X
_825        DEX                 ; ^4
            BPL _821            ;   <3
;
;
; SEEK desired track
;
            LDA TRACK
            JMP SEEK
;
GETBYTE     INC GOTBYTE+1       ; Self-modifies L#837 LDA $FFFF
            BNE GOTBYTE         ; v L#837
            INC GOTBYTE+2       ; Self-modifies L#837 LDA $FFFF
GOTBYTE     LDA $FFFF           ; Self-modified @ L#834-836
            RTS
;
;
;
            USR "O:RW18.D000",ORG
__END       ;END
