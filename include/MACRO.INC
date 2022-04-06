;
; MACRO.INC  -  MagicKit standard MACRO definitions
;

map	.macro			; map a memory bank into
	 lda   #bank(\1)	; addressable memory
	 tam   #page(\1)
	.endm

vreg	.macro			; set up video register
	 lda	\1		; to be read/written
	 sta	<_vreg
	 sta	video_reg
	.endm

;
; STWZ - store a word-sized zero value at stated memory location
;
stwz	.macro
	 stz	\1
	 stz	\1+1
	.endm

;
; STW - store a word-sized value at stated memory location
;
stw	.macro
	.if	(\?1 = 2)	; immediate mode
	 lda	#low(\1)	; same as old 'stwi'
	 sta	\2
	 lda	#high(\1)
	 sta	\2+1
	.else			; other addressing modes
	 lda	\1		; same as old 'movw'
	 sta	\2
	 lda	\1+1
	 sta	\2+1
	.endif
	.endm

;
; ADDW - add word-sized value to value at stated memory location,
;        storing result back into stated memory location
;
addw	.macro
	.if	(\?1 = 2)	; immediate mode
	 clc			; same as old 'addwi'
	 lda	\2
	 adc	#low(\1)
	 sta	\2
	 lda	\2+1
	 adc	#high(\1)
	 sta	\2+1
	.else			; other addressing modes
	 clc			; same as old 'addw'
	 lda	\2
	 adc	\1
	 sta	\2
	 lda	\2+1
	 adc	\1+1
	 sta	\2+1
	.endif
	.endm

;
; ADCW - add word-sized value plus carry to value at stated memory location,
;        storing result back into stated memory location
;
adcw	.macro
	.if	(\?1 = 2)	; immediate mode
	 lda	\2		; same as old 'addwi'
	 adc	#low(\1)
	 sta	\2
	 lda	\2+1
	 adc	#high(\1)
	 sta	\2+1
	.else			; other addressing modes
	 lda	\2		; same as old 'addw'
	 adc	\1
	 sta	\2
	 lda	\2+1
	 adc	\1+1
	 sta	\2+1
	.endif
	.endm

;
; SUBW - substract word-sized value from value at stated memory location,
;        storing result back into stated memory location
;
subw	.macro
	.if	(\?1 = 2)	; immediate mode
	 sec			; same as old 'subwi'
	 lda	\2
	 sbc	#low(\1)
	 sta	\2
	 lda	\2+1
	 sbc	#high(\1)
	 sta	\2+1
	.else			; other addressing modes
	 sec			; same as old 'subw'
	 lda	\2
	 sbc	\1
	 sta	\2
	 lda	\2+1
	 sbc	\1+1
	 sta	\2+1
	.endif
	.endm

;
; SBCW - substract word-sized value plus carry from value at stated memory
;        location, storing result back into stated memory location
;
sbcw	.macro
	.if	(\?1 = 2)	; immediate mode
	 lda	\2		; same as old 'subwi'
	 sbc	#low(\1)
	 sta	\2
	 lda	\2+1
	 sbc	#high(\1)
	 sta	\2+1
	.else			; other addressing modes
	 lda	\2		; same as old 'subw'
	 sbc	\1
	 sta	\2
	 lda	\2+1
	 sbc	\1+1
	 sta	\2+1
	.endif
	.endm

cmpw	.macro
	.if	(\?1 = 2)	; immediate mode
	 lda	\2+1
	 cmp	#high(\1)
	 bne	.x_\@
	 lda	\2
	 cmp	#low(\1)
	.else
	 lda	\2+1
	 cmp	\1+1
	 bne	.x_\@
	 lda	\2
	 cmp	\1
	.endif
.x_\@:
	.endm

incw	.macro			; increment a word-sized
	 inc	\1		; value at stated memory
	 bne	.x_\@		; location
	 inc	\1+1
.x_\@:
	.endm

decw	.macro			; decrement a word-sized
	 sec			; value at stated memory
	 lda	\1		; location
	 sbc	#1
	 sta	\1
	 lda	\1+1
	 sbc	#0
	 sta	\1+1
	.endm

rolw	.macro			; rotate word-sized value
	 rol	\1		; (at stated memory location)
	 rol	\1+1
	.endm

aslw	.macro			; arithmetic shift-left
	 asl	\1		; word-sized value (at stated
	 rol	\1+1		; memory location)
	.endm

lsrw	.macro			; logical shift-right word-sized
	 lsr	\1+1		; value (at stated memory
	 ror	\1		; location)
	.endm

rorw	.macro			; rotate right word-sized value
	 ror	\1+1		; (at stated memory location)
	 ror	\1
	.endm

negw	.macro			; negate word-sized value
	 cla			; (at stated memory location)
	 sub	\1		; 2's complement
	 sta	\1
	 cla
	 sbc	\1+1
	 sta	\1+1
	.endm

neg	.macro			; negate byte-sized value
	 eor	#$FF		; in register A
	 inc	A		; 2's complement
	.endm

add	.macro			; add byte-sized value to
	 clc			; register A (handle carry
	 adc	\1		; flag)
	.endm

sub	.macro			; subtract byte-sized value
	 sec			; from register A (handle
	 sbc	\1		; carry flag)
	.endm

blo	.macro			; branch if 'lower'
	 bcc	\1
	.endm

bhs	.macro			; branch if 'higher or same'
	 bcs	\1
	.endm

;-------------------------------

;
; Long branch MACROs
;

lbne	.macro
	 beq	.x_\@
	 jmp	\1
.x_\@
	.endm

lbeq	.macro
	 bne	.x_\@
	 jmp	\1
.x_\@
	.endm

lbpl	.macro
	 bmi	.x_\@
	 jmp	\1
.x_\@
	.endm

lbmi	.macro
	 bpl	.x_\@
	 jmp	\1
.x_\@
	.endm

lbcc	.macro
	 bcs	.x_\@
	 jmp	\1
.x_\@
	.endm

lbcs	.macro
	 bcc	.x_\@
	 jmp	\1
.x_\@
	.endm

lblo	.macro
	 bcs	.x_\@
	 jmp	\1
.x_\@
	.endm

lbhs	.macro
	 bcc	.x_\@
	 jmp	\1
.x_\@
	.endm


;-------------------------------

;
; These MACROs are the same as the MACROs
; without an underscore; the difference
; is these MACROs preserve the state of
; the registers they use (at the expense
; of speed)
;

_stw	.macro
	 pha
	 stw	\1,\2
	 pla
	.endm

_addw	.macro
	 pha
	 addw	\1,\2
	 pla
	.endm

_adcw	.macro
	 pha
	 adcw	\1,\2
	 pla
	.endm

_subw	.macro
	 pha
	 subw	\1,\2
	 pla
	.endm

_sbcw	.macro
	 pha
	 sbcw	\1,\2
	 pla
	.endm

_cmpw	.macro
	 pha
	 cmpw	\1,\2
	 pla
	.endm

_incw	.macro
	 incw	\1
	.endm

_decw	.macro
	 pha
	 decw	\1
	 pla
	.endm

