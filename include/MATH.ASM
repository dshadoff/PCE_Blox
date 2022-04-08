;
; MATH.ASM  -  MagicKit Standard Math Routines
;
;

; ----
; mulu32
; ----
; 32-bit unsigned multiplication
; ----
; OUT : _DX/CX = _BX/AX * _DX/CX
; ----

mulu32:
	stw   <_cx,<_si
	stw   <_dx,<_di
	stwz  <_cx
	stwz  <_dx
	ldy   #32
.loop:
	aslw  <_cx
	rolw  <_dx
	rolw  <_si
	rolw  <_di
	bcc   .next

	addw  <_ax,<_cx
	adcw  <_bx,<_dx
.next:
	dey
	bne   .loop
	rts

; ----
; rand
; ----
; return a 24-bit random number
; ----
; OUT : _DX/CX
; ----

	.bss

_rndseed: .ds 4
_rndsgn:  .ds 1

	.code
rand:
	stz   _rndsgn		; check seed sign - it must be positive
	lda   _rndseed+3	; for using the unsigned multiplication
	bpl   .l1		; routine
	subw  #0,_rndseed
	sbcw  #0,_rndseed+2
	lda   #1		; note we changed the sign
	sta   _rndsgn
.l1:
	stw   #$19d3,<_cx	; mul seed by $44BF19D3
	stw   #$44BF,<_dx
	stw   _rndseed,<_ax
	stw   _rndseed+2,<_bx
	jsr   mulu32

	lda   _rndsgn		; adjust sign
	bne   .l2
	subw  #0,<_cx
	sbcw  #0,<_dx
.l2:
	lda   <_cl		; adjust random number:
	inc   A			; add 1 and shift right by 8
	lda   <_ch
	adc   #0
	sta   <_cl
	lda   <_dl
	adc   #0
	sta   <_ch
	lda   <_dh
	adc   #0
	sta   <_dl
	stz   <_dh

	stw   <_cx,_rndseed	; update seed
	stw   <_dx,_rndseed+2
	rts

