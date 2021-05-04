; Copyright (C) 2020 Sean Gonsalves
;
; This file is part of Neo CD SD Loader.
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2, or (at your option)
; any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; see the file COPYING.  If not, write to
; the Free Software Foundation, Inc., 51 Franklin Street,
; Boston, MA 02110-1301, USA.

RunDMADirect:
    ; Using DMA copy causes corruption ? Do a CPU copy instead

    ; Copied from original routine:
	add.l   $7EF4(a5),d0	; SectorLoadDest
	movea.l d0,a1
	move.l  $7EF8(a5),a0	; SectorLoadBuffer (source)
	move.l  $7EFC(a5),d7	; SectorLoadSize
	lsr.l   #1,d7           ; Original routine does a word copy
	move.l  d7,d6
	andi.b  #31,d7
	lsr.l   #5,d6			; /32
	beq     .skip           ; Less than 32 words
	; Do as many 32-word copies as possible and top it off with a 1-loop if needed
.copy32:
	move.b  d0,REG_DIPSW    ; 16
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	move.l  (a0)+,(a1)+		; 20
	subq.l  #1,d6			; 8
    bne     .copy32			; 10	Total 354 cycles for 64 bytes (5.53 cycles per byte, 2119kB/s)
.skip:

	tst.b   d7
	beq     .exit
	move.b  d0,REG_DIPSW
.copy2:
	move.w  (a0)+,(a1)+		; 12
	subq.b  #1,d7			; 4
    bne     .copy2			; 10
.exit:
    rts


    IFDEF EXPERIMENTAL
RunDMADirectMulti:
    ; Using DMA copy causes corruption :( do a CPU copy instead
	add.l   $7EF4(a5),d0		; SectorLoadDest
	movea.l d0,a1
	move.l  $7EF8(a5),a0		; SectorLoadBuffer
	move.l  $7EFC(a5),d0		; SectorLoadSize
	
	divu.w  #48,d0              ; 12 longword registers = 12*4 = 48 bytes per MOVEM
	swap    d0                  ; QQQQRRRR
	move.w  d0,d1               ; d1.w=RRRR
	swap    d0                  ; d0.w=QQQQ

	subq.w  #1,d0               ; Dangerous ! Can wrap if size < 48
	subq.w  #1,d1
	bmi     .multipleof48
.subloop:
	; Do sub-48 copy
	move.b  (a0)+,(a1)+
	dbra    d1,.subloop

.multipleof48:
    movem.l (a0)+,d1-d7/a2-a6   ; 12+8n = 108
    movem.l d1-d7/a2-a6,(a1)    ; 8+8n = 104
    adda.l  #48,a1              ; 24 ?
    dbra    d0,.multipleof48    ; 10    Total 246 cycles for 48 bytes (5.125 cycles per byte, 2286kB/s)

    lea     $108000,a5
    rts
    ENDIF


UploadFIXDMABytes:
	move.l  #$E00000,d0
	add.l   $7EF4(a5),d0		; SectorLoadDest
	movea.l d0,a1
    movea.l $7EF8(a5),a0		; SectorLoadBuffer
    move.l  $7EFC(a5),d7		; SectorLoadSize
	lsr.l   #1,d7               ; Original routine does a word copy
.copy:
	move.b  (a0)+,d0            ; Read AA BB, store 00 AA 00 BB
    move.w  d0,(a1)+            ; 00 AA
	move.b  (a0)+,d0
	move.w  d0,(a1)+			; 00 BB
	move.b  d0,REG_DIPSW
	subq.l  #1,d7
    bne     .copy
	move.l  $7EF4(a5),d0		; SectorLoadDest
	add.l   $7EFC(a5),d0		; SectorLoadSize
	add.l   $7EFC(a5),d0		; SectorLoadSize
	move.l  d0,$7EF4(a5)		; SectorLoadDest
	rts

UploadZ80DMABytes:
	move.l  #$E00000,d0
	add.l   $7EF4(a5),d0		; SectorLoadDest
	movea.l d0,a1
	movea.l $7EF8(a5),a0		; SectorLoadBuffer
	move.l  $7EFC(a5),d7		; SectorLoadSize
	lsr.l   #1,d7               ; Original routine does a word copy
.copy:
	move.b  (a0)+,d0            ; Read AA BB, store 00 AA 00 BB
    move.w  d0,(a1)+            ; 00 AA
	move.b  (a0)+,d0
	move.w  d0,(a1)+			; 00 BB
	move.b  d0,REG_DIPSW
	subq.l  #1,d7
    bne     .copy
	move.l  $7EF4(a5),d0		; SectorLoadDest
	add.l   $7EFC(a5),d0		; SectorLoadSize
	add.l   $7EFC(a5),d0		; SectorLoadSize
	move.l  d0,$7EF4(a5)		; SectorLoadDest
	rts

DMAClearPalettes:
    movem.l d0/d7/a0,-(sp)
    move.b  #1,REG_UPLOAD_EN
    move.b  #0,REG_ENVIDEO
	move.b  d0,REG_DIPSW
    lea     PALETTES,a0
    moveq.l #0,d0
    move.w  #$1000,d7
.fill:
    move.w  d0,(a0)+            ; 8
    subq.w  #1,d7               ; 4
    bne     .fill               ; 10, 22 total, 90112 cycles = 7.5ms
    move.b  #1,REG_ENVIDEO
    move.b  d0,REG_DIPSW
    move.b  #0,REG_UPLOAD_EN
    movem.l (sp)+,d0/d7/a0
    rts
    
DMAClearPCMDRAM:
    movem.l d0/d7/a0-a1,-(sp)
    move.b  #1,REG_UPLOAD_EN
    move.b  d0,REG_UPMAPPCM
    move.b  #1,REG_TRANSAREA

    move.w  #$FF08,d0
    lea     REG_DIPSW,a1

    move.b  #0,REG_PCMBANK
    jsr     .clear
    move.b  #1,REG_PCMBANK
    jsr     .clear

    move.b  d0,REG_UPUNMAPPCM
    move.b  d0,REG_DIPSW
    move.b  #0,REG_UPLOAD_EN
    movem.l (sp)+,d0/d7/a0-a1
    rts

.clear:
    movea.l #$E00000,a0
    move.w  #$100000/32,d7      ; 1MB range, 512kB of data on odd bytes
.fill:
    move.l  d0,(a0)+            ; 12
    move.l  d0,(a0)+            ; 12
    move.l  d0,(a0)+            ; 12
    move.l  d0,(a0)+            ; 12
    move.l  d0,(a0)+            ; 12
    move.l  d0,(a0)+            ; 12
    move.l  d0,(a0)+            ; 12
    move.l  d0,(a0)+            ; 12
	move.b  d0,(a1)             ; 8
    subq.w  #1,d7               ; 4
    bne     .fill               ; 10, 118 total, 8126464 cycles = 322ms
    rts

; Original routine copies at 378kB/s
CopyBytesToWordCPU:
	move.l  d7,d6
	andi.b  #15,d7
	lsr.l   #4,d6				; /16
	beq     .copy1
	; Do as many 16-bytes copies as possible and top it off with a 1-loop
.copy16:
	move.b  (a0)+,d0			; 8
	move.w  d0,(a1)+			; 8
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	move.b  d0,REG_DIPSW
	subq.w  #1,d6			; 4
    bne     .copy16         ; 10, total 286 cycles for 16 bytes (17.9 cycles per byte, 655kB/s)
	tst.b   d7
	beq     .exit
.copy1:
	move.b  (a0)+,d0
	move.w  d0,(a1)+
	subq.b  #1,d7			; 4
    bne     .copy1			; 10
.exit:
    rts
