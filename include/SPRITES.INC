;
; SPRITES.INC  -  MagicKit sprite MACRO definitions
;


; load_sprites(vram_addr, spr_bank, #nb_group)
; ----
; vram_addr, destination address in VRAM
; spr_bank,  sprite bank address
; nb_group,  number of 32x64 patterns to copy

	.macro load_sprites

	; put the VRAM address in _di

	 stw   #\1,<_di

	; map the sprite bank; use the BANK() function of the assembler
	; to get the physical ROM bank number and map it to page 2
	; ($4000)

	 tma   #2	; get the current bank mapped to page 2 and push it
	 pha		; onto the stack, we will restore it after the copy

	 lda   #BANK(\2)
	 tam   #2

	; put the sprite bank address in _si
	; this code can seem strange, this is because we force the sprite
	; bank address to page 2 whatever the address is, the advantage
	; is that you are not obliged to use .org in the sprite bank

	 lda   #LOW(\2)
	 sta   <_si
	 lda   #HIGH(\2)
	 and   #$1F
	 ora   #$40
	 sta   <_si+1

	; get the number of patterns to copy, multiply it by $200,
	; the size in words of a 32x64 pattern (remember that
	; 'load_vram' need a size in words), and put it in _cx

	 lda   \3
	 asl   A
	 stz   <_cx
	 sta   <_cx+1

	; call the 'load_vram' function

	 jsr load_vram

	; and restore the old bank that was in page 2

	 pla
	 tam   #2
	.endm


; spr_set(#sprite, satb)
; ----
; sprite, the sprite number (0-63)
; satb,   the address of the SATB in RAM

	.macro spr_set

	; multiply the sprite number by 8 (the size of a SATB entry)
	; and put the result in _si

	 stz   <_si+1
	 lda   \1
	 asl   A
	 asl   A
	 asl   A
	 rol   <_si+1
	 sta   <_si

	; add the satb address to _si

	 addw  #\2,<_si
	.endm


; spr_x(#x)
; ----
; x, the new x coordinate

	.macro spr_x
	 ldy   #2
	 .if (\?1 = ARG_IMMED)	; immediate mode
	  lda   #LOW(\1)
	  sta   [_si],Y
	  lda   #HIGH(\1)
	 .else			; absolute mode
	  lda   \1
	  sta   [_si],Y
	  lda   \1+1
	 .endif
	 iny
	 sta   [_si],Y
	.endm


; spr_y(y)
; ----
; y, the new y coordinate

	.macro spr_y
	 .if (\?1 = ARG_IMMED)	; immediate mode
	  lda   #LOW(\1)
	  sta   [_si]
	  lda   #HIGH(\1)
	 .else			; absolute mode
	  lda   \1
	  sta   [_si]
	  lda   \1+1
	 .endif
	 ldy   #1
	 sta   [_si],Y
	.endm


; spr_pattern(#addr)
; ----
; addr, address of the sprite pattern in VRAM

	.macro spr_pattern
	 ldy   #4
	 .if (\?1 = ARG_IMMED)
	  lda   #LOW((\1) >> 5)
	  sta   [_si],Y
	  lda   #HIGH((\1) >> 5)
	 .else
	  lda   \1
	  sta   [_si],Y
	  lda   \1+1
	 .endif
	 iny
	 sta   [_si],Y
	.endm


; spr_ctrl(#mask, #flag)
; ----
; mask, mask of the bits to change
; flag, new bit value

	.macro spr_ctrl
	 ldy   #7
	 lda   \1
	 eor   #$FF
	 and   [_si],Y
	 ora   \2
	 sta   [_si],Y
	.endm


; spr_pri(#flag)
; ----
; flag, new priority (1 = in foreground, 0 = in background)

	.macro spr_pri
	 ldy   #6
	 lda   [_si],Y
	 and   #$7F
	 ldx   \1
	 beq   .x\@
	 ora   #$80
.x\@:
	 sta [_si],Y
	.endm


; spr_pal(#index)
; ----
; index, palette index (0-15)

	.macro spr_pal
	 ldy   #6
	 lda   [_si],Y
	 and   #$F0
	 ora   \1
	 sta   [_si],Y
	.endm


; init_satb(addr)
; ----
; addr, the address of the local RAM SATB

	.macro init_satb
	 stz \1
	 tii \1,\1+1,511
	.endm


; update_satb(satb[, addr])
; ----
; satb, the address of the local RAM SATB
; addr, the address where to copy the SATB in VRAM ($7F00 by default)

	.macro update_satb
	 stw   #\1,<_si
	 .if (\?2)
	  stw   #\2,<_di
	 .else
	  stw   #$7F00,<_di
	 .endif
	 stw   #$100,<_cx
	 jsr   load_vram
	.endm


; ----
FLIP_X_MASK .equ $08
FLIP_Y_MASK .equ $80
FLIP_MASK   .equ $88
SIZE_MASK   .equ $31

NO_FLIP    .equ 0
NO_FLIP_X  .equ 0
NO_FLIP_Y  .equ 0
FLIP_X     .equ $08
FLIP_Y     .equ $80
SIZE_16x16 .equ 0
SIZE_16x32 .equ $10
SIZE_16x64 .equ $30
SIZE_32x16 .equ $01
SIZE_32x32 .equ $11
SIZE_32x64 .equ $31

