         LST OFF
         TTL "S:RW18.D000"

ORG      =   $D000
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
SN1      =   $D5
SN2      =   $9D
SN3      =   $AA
SN4      =   $D4
SNX      =   $FF
;
BRBUNDID =   $A4
;---------------
;
; Permanent vars
;
SLOT     EQU $FD
TRACK    EQU $FE
LASTRACK EQU $FF
SLOTABS  = SLOT
;---
;
; Temporary vars
;
DAT      EQU $E0
;
BUF1     EQU DAT
BUF2     EQU DAT+2
BUF3     EQU DAT+4
LEFT     EQU DAT+6
TRACKGOT EQU DAT+8
SECTOR   EQU DAT+9
RETRIES  EQU DAT+10
TEMP     EQU DAT+11
CHECKSUM EQU DAT+12
TEMP1    EQU DAT+13
TEMP2    EQU DAT+14
COMMAND  EQU DAT+15
;
; VERY temporary vars used by SEEK
;
TMP0     EQU BUF1
TMP1     EQU BUF1+1
TMP2     EQU BUF2
TMP3     EQU BUF2+1
;------------
;
GARPAGE  =   ORG+$500
LEFTOVER =   ORG+$600
BITS1    =   ORG+$C00
BITS2    =   ORG+$D00
BITS3    =   ORG+$E00
BUFTABLE =   ORG+$F00
;
; DENIBBLE  uses $96..$FF
;
DENIBBLE =   BUFTABLE
SECTDONE =   BUFTABLE+18
ZPAGSAVE =   SECTDONE+6
;-----------
         ORG ORG
;        OBJ $0800
;-----------
         JMP RW18
;-----------
;
; Valid disk nibbles
;
NIBBLES  HEX 96979A9B9D9E9FA6
         HEX A7ABACADAEAFB2B3
         HEX B4B5B6B7B9BABBBC
         HEX BDBEBFCBCDCECFD3
         HEX D6D7D9DADBDCDDDE
         HEX DFE5E6E7E9EAEBEC
         HEX EDEEEFF2F3F4F5F6
         HEX F7F9FAFBFCFDFEFF
;-----------
;
; The first part make sthe disk
; look like a BSW master disk.
;
SOFTSYNC HEX A596BFFFFEAABBAAAAFFEF9A
;
NOTFSEC  DB  SN1,SN2
TRACKMOD HEX 96
SECMOD   HEX 96
CHECKMOD HEX 96
         DB  SN3,SNX,SNX,0
;-----------
;
; Write routine, timing critical code!
;
; Write out #$FF sync bytes at
; 40 microseconds, # given in Y.
;
WRITETC  LDA #$FF
         STA $C08F,X         ; 5
         ORA $C08C,X         ; 4
         ROL TEMP            ; 5
:0       NOP                 ; 2
         JSR RTS             ; 12
         JSR RTS             ; 12
         STA $C08C,X         ; 5
;
         ORA $C08C,X         ; 4
         DEY                 ; 2
         BNE :0              ; 3/2
;-----------
SYNCMOD  LDY #00             ; 2
:1       LDA SOFTSYNC,Y      ; 4
         BEQ :2              ; 2/3
         INY                 ; 2
         NOP                 ; 2
         NOP                 ; 2
         NOP                 ; 2
         LDX SLOT            ; 3
         STA $C08D,X         ; 5
;
         ORA $C08C,X         ; 4
         LDX SLOT            ; 3
         BNE :1              ; 3
;-----------
:2       NOP                 ; 2
         NOP                 ; 2
         NOP                 ; 2
         NOP                 ; 2
IDMOD0   LDA #BRBUNDID       ; 2
         STA $C08D,X         ; 5
;
         ORA $C08C,X         ; 4
         LDY #00             ; 2
         STY CHECKSUM        ; 3
;                            ;
IDMOD0LP LDA (LEFT),Y        ; 5
         TAX                 ; 2
         EOR CHECKSUM        ; 3
         STA CHECKSUM        ; 3
         LDA NIBBLES,X       ; 4
         NOP                 ; 2
Q6HMOD0  STA $C0ED           ; 4
;                            ;
Q6LMOD0  ORA $C0EC           ; 4
         LDA (BUF1),Y        ; 4
         AND #$3F            ; 2
         TAX                 ; 2
         EOR CHECKSUM        ; 3
         STA CHECKSUM        ; 3
         LDA NIBBLES,X       ; 4
         LDX SLOTABS         ; 4
         STA $C08D,X         ; 5
;
         ORA $C08C,X         ; 4
         LDA (BUF2),Y        ; 5
         AND #$3F            ; 2
         TAX                 ; 2
         EOR CHECKSUM        ; 3
         STA CHECKSUM        ; 3
         LDA NIBBLES,X       ; 4
         LDX SLOTABS         ; 4
         STA $C08D,X         ; 5
;
         ORA $C08C,X         ; 4
         LDA (BUF3),Y        ; 5
         AND #$3F            ; 2
         TAX                 ; 2
         EOR CHECKSUM        ; 3
         STA CHECKSUM        ; 3
         LDA NIBBLES,X       ; 4
         LDX SLOTABS         ; 4
         STA $C08D,X         ; 5
;
         ORA $C08C,X         ; 4
         INY                 ; 2
         BNE IDMOD0LP        ; 3/2
;
         LDX CHECKSUM        ; 3
         LDA NIBBLES,X       ; 4
         LDX SLOT            ; 3
         JSR WRNIBBL2        ; 6
         LDA #SN4
         JSR WRNIBBLE
         LDA #SNX
         JSR WRNIBBLE
;
         LDA $C08E,X
         LDA $C08C,X
         RTS
;
; Write a nibble
;
WRNIBBLE NOP                 ; 2
         NOP                 ; 2
         CLC                 ; 2
WRNIBBL2 LDX SLOT            ; 3
         STA $C08D,X         ; 5
;
         ORA $C08C,X         ; 4
         RTS
;-----------
;
; Write a track. Same parameters as
; the READ routine
; Call PRENIBL to create the $600 byte
; LEFTOVER table.
;
WRITE    JSR INITBUF
         LDY TRACK
         LDA NIBBLES,Y
         STA TRACKMOD
;
; Compute track/sector checksum
;
:1       LDA SECTOR
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
         BEQ :2
;
; If this is not the first sector,
; then don't write out BSW id bytes
; and only write out 4 self-syncs.
;
         LDA #NOTFSEC-SOFTSYNC
         LDY #4
         BNE :3
;
; First sector, write out BSW id bytes
; and 200 self-sync bytes to ensure
; the the track is erased.
;
:2       LDA #0
         LDY #200
;
:3       STA SYNCMOD+1
;
; Make disk controller happy
; by checking for write protect
;
         LDA $C08D,X
         LDA $C08E,X
         SEC
         BMI :4
         JSR WRITETC
         INC LEFT+1
         DEC SECTOR
         BPL :1
:4       RTS
;-----------
;
; Init SECTOR, buffer pointers.
;
INITBUF  LDA #5
         STA SECTOR
         LDY #0
         STY BUF1
         STY BUF2
         STY BUF3
         LDA #>LEFTOVER
         STY LEFT
         STA LEFT+1
         LDX SLOT
         RTS
;-----------
GETNIBBL LDX $C0EC
         BPL *-3
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
READ     JSR INITBUF
         LDY #5
         LDA #48
         STA RETRIES
:0       STA SECTDONE,Y
         DEY
         BPL :0
;
READLOOP DEC RETRIES
         BEQ READERR
         JSR READADDR
         BCS READLOOP
;
; On the right track?
;
         LDA TRACKGOT
         CMP TRACK
         CLC
         BNE RTS
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
:0       LDA SECTDONE,Y
         BNE READLOOP
         DEY
         BPL :0
         INY
RTS      RTS
;
READERR  SEC
         RTS
;-----------
;
; Read address marks
;
READADDR LDY #$FA
         STY TEMP
:0       INY
         BNE :1
         INC TEMP
         BEQ READERR
;
:1       JSR GETNIBBL
:2       CPX #SN1
         BNE :0
         JSR GETNIBBL
         CPX #SN2
         BNE :2
;
         JSR GETNIBBL
         STA TRACKGOT
         JSR GETNIBBL
         STA SECTOR
         JSR GETNIBBL
         EOR TRACKGOT
         EOR SECTOR
         BNE :0
         JSR GETNIBBL
         CPX #SN3
         BNE :0
         CLC
;
; Given sector, set buffer pointers
;
GETBUFS  LDY SECTOR
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
READDATA LDY #4
RDDATA2  DEY
         BEQ READERR
         JSR GETNIBBL
IDMOD1   CPX #BRBUNDID
         BNE RDDATA2
;
; Now read in data
;
; Initialize checksum to zero!
; See code furthur below to better
; understand what is happening here.
;
         LDY #0
         LDA TEMP1
;
; Main read loop
;
READDAT2
Q6LMOD1  LDX $C0EC
         BPL *-3
         EOR TEMP1
         EOR DENIBBLE,X
         STA CHECKSUM
         LDA DENIBBLE,X
         ASL
         ASL
         STA TEMP
;
Q6LMOD2  LDX $C0EC
         BPL *-3
         AND #$C0
         ORA DENIBBLE,X
         STA (BUF1),Y
         STA TEMP1
         LDA TEMP
         ASL
         ASL

Q6LMOD3  LDX $C0EC
         BPL *-3
         STA TEMP
         AND #$C0
         ORA DENIBBLE,X
         STA (BUF2),Y
         STA TEMP2
         LDA TEMP
         ASL
;
Q6LMOD4  LDX $C0EC
         BPL *-3
         ASL
         ORA DENIBBLE,X
         STA (BUF3),Y
         EOR TEMP2
         EOR CHECKSUM
         INY
         BNE READDAT2
;
; Get checksum
;
Q6LMOD5  LDX $C0EC
         BPL *-3
         EOR DENIBBLE,X
         EOR TEMP1
         AND #$3F
         BNE :0
;
         JSR GETNIBBL
         CPX #SN4
         BNE :0
         CLC
         RTS
;
:0       SEC
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
PRENIBL  JSR INITBUF
PRENIBL2 JSR GETBUFS
         LDA BUF1+1
         STA BUF1MOD+2
         LDA BUF2+1
         STA BUF2MOD+2
         LDA BUF3+1
         STA BUF3MOD+2
;
         LDY #0
BUF1MOD  LDX $FF00,Y
         LDA BITS1,X
BUF2MOD  LDX $FF00,Y
         ORA BITS2,X
BUF3MOD  LDX $FF00,Y
         ORA BITS3,X
         STA (LEFT),Y
         INY
         BNE BUF1MOD
         INC LEFT+1
         DEC SECTOR
         BPL PRENIBL2
         RTS
;-----------
;
; Prepare RW18 for use
;
; given A=slot*16
;
PREP     STA PREPSLOT
         ORA #$8C
         STA GETNIBBL+1
         STA Q6LMOD0+1
         STA Q6LMOD1+1
         STA Q6LMOD2+1
         STA Q6LMOD3+1
         STA Q6LMOD4+1
         STA Q6LMOD5+1
         ORA #$1
         STA Q6HMOD0+1
;
; Set up DENIBBL table, used by READ
;
         LDY #$3F
:0       LDX NIBBLES,Y
         TYA
         STA DENIBBLE,X
         DEY
         BPL :0
;
; Set up BITS tables for PRENIBL
;
         LDY #0
:1       TYA
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
         BNE :1
         RTS
;-----------
;
; R/W head SEEK routine
;
; A:track
;
SEEK     ASL
         STA TMP2
         CMP LASTRACK
         BEQ SEEKDONE
         LDA #0
         STA TMP0
;
SEEKLOOP LDA LASTRACK
         STA TMP1
         SEC
         SBC TMP2
         BEQ SEEKTOG2
         BCS :0
         EOR #$FF
         INC LASTRACK
         BCC :1
;
:0       ADC #$FE
         DEC LASTRACK
:1       CMP TMP0
         BCC :2
         LDA TMP0
:2       CMP #$0C
         BCS :3
         TAY
:3       SEC
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
SEEKTOG2 JSR SEEKDELY
         CLC
SEEKTOG1 LDA LASTRACK
;
SEEKTOGL AND #$03
         ROL
         ORA SLOT
         TAX
         LDA $C080,X
SEEKDONE LDX SLOT
         RTS
;
SEEKDELY LDX #$13
:0       DEX
         BNE :0
         SEC
         SBC #1
         BNE SEEKDELY
         RTS
;
; Acceleration/deceleration tables
;
SEEKTBL1 HEX 01302824201E1D1C1C1C1C1C
SEEKTBL2 HEX 702C26221F1E1D1C1C1C1C1C
;
         ASC "COPYRIGHT 1985 "
         ASC "BY ROLAND GUSTAFSSON"
;-----------
;
; Entry point into RW18
;
RW18     PLA
         STA GOTBYTE+1
         PLA
         STA GOTBYTE+2
;
         JSR SWAPZPAG
;
         LDA SLOT
         CMP #00
PREPSLOT =   *-1
         BEQ :0
         JSR PREP
;
:0       JSR GETBYTE
         STA COMMAND
         AND #$0F
         ASL
         TAX
;
         LDA CMDTABLE,X
         STA :1+1
         LDA CMDTABLE+1,X
         STA :1+2
:1       JSR $FFFF
;
         LDA GOTBYTE+2
         PHA
         LDA GOTBYTE+1
         PHA
;
SWAPZPAG LDX #15
:0       LDA DAT,X
         LDY ZPAGSAVE,X
         STA ZPAGSAVE,X
         STY DAT,X
         DEX
         BPL :0
         RTS

CMDTABLE DW CMDRIVON
         DW CMDRIVOF
         DW CMSEEK
         DW CMREADSQ
         DW CMREADGP
         DW CMWRITSQ
         DW CMWRITGP
         DW CMIDMOD
;-----------
;
; DRIVE ON
; <drive#>,<delay, in 1/10ths sec>
;
CMDRIVON LDX SLOT
         JSR GETBYTE
         ORA SLOT
         TAY
         LDA $C089,Y
         LDA $C089,X
;
; Delay 1/10ths of seconds
;
         JSR GETBYTE
         BEQ :2
         STA TMP0
:0       LDY #$17
         LDX #0
;
:1       JSR RTS
         DEX
         BNE :1
         DEY
         BNE :1
         DEC TMP0
         BNE :0
:2       RTS
;-----------
;
; DRIVE OFF
;
CMDRIVOF LDX SLOT
         LDA $C088,X
         RTS
;-----------
;
; SEEK
; <check disk for LASTRACK?>,
; <track>
;
CMSEEK   JSR GETBYTE
         BEQ :1
;
; Force "Track error"
;
         LDA #255
         STA TRACK
         JSR READ
         BCC :0
;
; If CLC, then A = current track,
;         else recalibrate
;
         LDA #$A0
         STA LASTRACK
         LDA #0
         JSR SEEK
         LDA #0
:0       ASL
         STA LASTRACK
;
:1       JSR GETBYTE
         STA TRACK
         JMP SEEK
;-----------
;
; READSEQU
;

; READGROP
; <18 buf adr's>
;
CMREADSQ LDX #1
         HEX 2C
CMREADGP LDX #18
         JSR CMADINFO
;
CMREAD2  JSR READ
         BCS INCTRAK?
         BEQ INCTRAK?
         ASL
         STA LASTRACK
         LDA TRACK
         JSR SEEK
         JMP CMREAD2
;
; READ/WRITE exit.
;
INCTRAK? BIT COMMAND
         BCS WHOOP?
;
; If bit 6 set, then INC TRACK
;
         BVC :0
         INC TRACK
:0       RTS
;
; If bit 7 set then whoop speaker
; WARNIGN: use only with READ
;
WHOOP?   BPL :0
         LDY #0
:1       TYA
         BIT $C030
:2       SEC
         SBC #1
         BNE :2
         DEY
         BNE :1
         BEQ CMREAD2
;-----------
;
; Same as READ
;
CMWRITSQ LDX #1
         HEX 2C
CMWRITGP LDX #18
         JSR CMADINFO
         JSR PRENIBL
         JSR WRITE
         JSR INCTRAK?
;-----------
;
; Chnage Br0derbund ID byte
;
CMIDMOD  JSR GETBYTE
         STA IDMOD0+1
         STA IDMOD1+1
         RTS
;-----------
;
; Get buffer info.
;
CMADINFO STX TMP0
         LDX #0
:0       JSR GETBYTE
         STA BUFTABLE,X
         INX
         CPX TMP0
         BLT :0
         TAY
;
; If sequence, then fill table
;
:1       INY
         CPX #18
         BEQ :2
         TYA
         STA BUFTABLE,X
         INX
         BNE :1
;
; Check for garbage pages
;
:2       DEX
:3       LDA BUFTABLE,X
         BNE :4
         LDA #>GARPAGE
         STA BUFTABLE,X
:4       DEX
         BPL :3
;
;
; SEEK desired track
;
         LDA TRACK
         JMP SEEK
;
GETBYTE  INC GOTBYTE+1
         BNE GOTBYTE
         INC GOTBYTE+2
GOTBYTE  LDA $FFFF
         RTS
;
;
;
         SAV RW18_D000
         END
