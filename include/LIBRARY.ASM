;
; LIBRARY.ASM  -  MagicKit Standard Library
;
;


; ----
; set_palette
; ----
; initialize one or more sub-palette
; ----
; IN :  _AL = index of the first sub-palette (0-31)
;       _SI = address of the color table
;       _CL = number of sub_palette to copy
; ----

set_palette:
	lda   <_al		; mulitply the sub-palette index by 16
	stz   <_ah		; and set the color index of the VCE
	asl   A
	asl   A
	asl   A
	asl   A
	rol   <_ah
	sta   color_reg
	lda   <_ah
	sta   color_reg+1
	cly
.loop_a:
	ldx   #16
.loop_b:
	lda   [_si],Y		; set a color
	iny
	sta   color_data
	lda   [_si],Y
	sta   color_data+1
	iny
	bne   .next
	inc   <_si+1
.next:  dex			; next color
	bne   .loop_b

	dec   <_cl		; next sub-palette
	bne   .loop_a
	rts


; ----
; load_bat
; ----
; transfer a bloc attribute table into VRAM
; ----
; IN :  _DI = VRAM base address
;       _DX = width of the virtual screen
;       _SI = memory location
;       _CL = nb of column to copy
;       _CH = nb of row
; ----

;load_bat:
;	cly
;.l1:	jsr   set_write
;	ldx   <_cl
;.l2:	lda   [_si],Y
;	sta   video_data
;	iny
;	lda   [_si],Y
;	sta   video_data+1
;	iny
;	bne   .n1
;	inc   <_si+1
;.n1:	dex
;	bne   .l2
;	
;	addw  <_dx,<_di
;	dec   <_ch
;	bne   .l1
;	rts


; ----
; load_font
; ----
; transfer a 8x8 monochrome font into VRAM, slow but can be useful
; ----
; IN :  _DI = VRAM base address
;       _SI = font address in memory
;       _AL = font color (0-15)
;       _CL = number of characters to copy
; ----

load_font:
	jsr   set_write

	; copy planes 1 & 2

.copy:
	cly
.l1:	lda   [_si],Y
	tst   #$01,<_al
	bne   .p1
	cla
.p1:	sta   video_data

	lda   [_si],Y
	tst   #$02,<_al
	bne   .p2
	cla
.p2:	sta   video_data+1

	iny
	cpy   #8
	bne   .l1

	; copy planes 3 & 4

	cly
.l2:	lda   [_si],Y
	tst   #$04,<_al
	bne   .p3
	cla
.p3:	sta   video_data

	lda   [_si],Y
	tst   #$08,<_al
	bne   .p4
	cla
.p4:	sta   video_data+1

	iny
	cpy   #8
	bne   .l2

	; next character

	addw  #8,<_si
	dec   <_cl
	bne   .copy
	rts


; ----
; load_vram
; ----
; copy a block of memory to the VRAM
; ----
; IN :  _DI = VRAM location
;       _SI = memory location
;       _CX = number of words to copy
; ----

load_vram:
	jsr   set_write
	cly
.loop:	lda   [_si],Y
	sta   video_data
	iny
	lda   [_si],Y
	sta   video_data+1
	iny
	bne   .next
	inc   <_si+1
.next:	decw  <_cx
	lda   <_cl
	ora   <_ch
	bne   .loop
	rts


; ----
; set_read
; ----
; set the VDC VRAM read address
; ----
; IN :  _DI = VRAM location
; ----

;set_reada:
;	vreg  #$01
;	lda   <_di 
;	sta   video_data
;	lda   <_di+1
;	sta   video_data+1
;	vreg  #$02
;	rts 


; ----
; set_write
; ----
; set the VDC VRAM write address
; ----
; IN :  _DI = VRAM location
; ----

set_write:
	vreg  #$00
	lda   <_di 
	sta   video_data
	lda   <_di+1
	sta   video_data+1
	vreg  #$02
	rts 


; ----
; HSR(xres)
; ----
; macros to calculate the value of the HSR VDC register
; ----
; IN :  xres, horizontal screen resolution
; ----

HSR	.macro
	 .if (\1 <= 272)
	  ; low res
	  .db $02
	  .db (18 - (((\1 / 8) - 1) / 2))
	 .else
	  ; high res
	  .db $03
	  .db (24 - (((\1 / 8) - 1) / 2))
	 .endif
	.endm


; ----
; HDR(xres)
; ----
; macros to calculate the value of the HDR VDC register
; ----
; IN :  xres, horizontal screen resolution
; ----

HDR	.macro
	 .db ((\1 / 8) - 1)
	 .if (\1 <= 272)
	  ; low res
	  .db (38 - ((18 - (((\1 / 8) - 1) / 2)) + (\1 / 8)))
	 .else
	  ; high res
	  .db (54 - ((24 - (((\1 / 8) - 1) / 2)) + (\1 / 8)))
	 .endif
	.endm


; ----
; init_vdc
; ----
; initialize the video controller
;  * screen mode set to 256x240
;  * display and sprites off
;  * interrupts disabled
;  * virtual screen size set to 512x256
;  * SATB set to $7F00
;  * clear the video RAM
; ----

init_vdc:
	; default screen resolution

	.ifndef _xres
_xres    .equ 256
	.endif

	; initialize the VDC registers

	stw   #.table,<_si 	; register table address in '_si'
	cly 
.l1:	lda   [_si],Y		; select the VDC register
	iny
	sta   <_vreg
	sta   video_reg
	lda   [_si],Y		; send the 16-bit data
	iny 
	sta   video_data
	lda   [_si],Y
	iny 
	sta   video_data+1
	cpy   #36		; loop if not at the end of the
	bne   .l1		; table

	; set the pixel clock frequency

	.if (_xres <= 272)
	 stz  color_ctrl
	.else
	 lda  #1
	 sta  color_ctrl
	.endif

	; clear the video RAM

	st0	#0
	st1	#0
	st2	#0

	ldx	#128
.l2:	cly
.l3:	st1	#0
	st2	#0
	dey
	bne	.l3
	dex
	bne	.l2

	rts

	; VDC register data

.table:	.db $05,$00,$00		; CR    control register
	.db $06,$00,$00		; RCR   scanline interrupt counter
	.db $07,$00,$00		; BXR   background horizontal scroll offset
	.db $08,$00,$00		; BYR        "     vertical     "      "
	.db $09,$10,$00		; MWR   size of the virtual screen
	.db $0A			; HSR +
	 HSR _xres		;     |                 [$02,$02]
	.db $0B			; HDR | display size
	 HDR _xres		;     | and synchro     [$1F,$04]
	.db $0C,$02,$0F		; VPR |
	.db $0D,$EF,$00		; VDW |
	.db $0E,$04,$00		; VCR +
	.db $0F,$10,$00		; DCR   DMA control register
	.db $13,$00,$7F		; SATB  address of the SATB


; ----
; init_psg
; ----
; initialize the sound generator.
; ----

init_psg:
	stz   psg_mainvol	; main volume to zero
	stz   psg_lfoctrl	; disable the LFO
	
	lda   #5		; set volume to zero for each channel
.clear:	sta   psg_ch            ; and disable them
	stz   psg_ctrl
	stz   psg_pan
	dec   A
	bpl   .clear

	lda   #4		; disable noise for channel 5 & 6
	sta   psg_ch
	stz   psg_noise
	lda   #5
	sta   psg_ch
	stz   psg_noise
	rts

