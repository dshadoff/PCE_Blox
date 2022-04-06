;
; STARTUP.ASM  -  MagicKit standard startup code
;

	.include "standard.inc"

; ----
; setup flexible boundaries for startup code
; and user program's "main".

START_BANK	.equ	0
MAIN_BANK	.equ	START_BANK+1


; ----
; system variables

		.bss
		.org	$2200
user_vec:		; user interrupt vectors
irq2_vec:	.ds 2	; IRQ2 (BRK instruction and external IRQ)
irq1_vec:	.ds 2	; IRQ1 (VDC interrupt)
timer_vec:	.ds 2	; TIMER
nmi_vec:	.ds 2	; NMI (unused)
vsync_vec:	.ds 2	; VDC vertical sync routine
hsync_vec:	.ds 2	; VDC horizontal sync rountine

		.org	$2227
joyena:		.ds 1	; soft reset enable (bit 0/pad 1, bit 1/pad2, etc.)
joy:		.ds 5	; 'current' pad values (pad #1-5)
joytrg:		.ds 5	; 'delta' pad values (new keys hit)
joyold:		.ds 5	; 'previous' pad values

		.org	$2241
vsync_cnt:	.ds 1	; VDC interrupt counter; increased 60 times per second

		.org	$2284
soft_reset:	.ds 2	; soft reset jump loc (run+select)

		.org	$2680
joycnt:		.ds 1	; counter for 'wait_vsync' routine
joydlta:	.ds 5	; latched 'delta' pad values (new keys hit)
joyprev:	.ds 5	; latched 'previous' pad values
joybuf:		.ds 5	; 'delta' pad values collector


;±±±[ STARTUP CODE ]±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

; ----
; interrupt vectors

	.code
	.bank START_BANK
	.org  $FFF6

	.dw _irq2
	.dw _irq1
	.dw _timer
	.dw _nmi
	.dw _reset

	.org $E000

; ----
; reset
; ----
; things start here
; ----

_reset:
	sei			; disable interrupts 
	csh			; select the 7.16 MHz clock
	cld			; clear the decimal flag 
	ldx   #$FF		; initialize the stack pointer
	txs 
	lda   #$FF		; map the I/O bank in the first page
	tam   #0
	lda   #$F8		; and the RAM bank in the second page
	tam   #1
	stz   $2000		; clear all the RAM
	tii   $2000,$2001,$1FFF

; ----
; initialize the hardware

	stz   timer_ctrl	; init timer
	jsr   init_psg		; init PSG
	jsr   init_vdc		; init video
	lda   #$1F		; init joypad
	sta   joyena

; ----
; initialize interrupt vectors

	ldx   #4		; user vector table
	cly
.1:	lda   #LOW(_rti)
	sta   user_vec,Y
	iny
	lda   #HIGH(_rti)
	sta   user_vec,Y
	iny
	dex
	bne   .1

	stw   #_reset,soft_reset ; soft reset
	stw   #_rts,vsync_vec	; user vsync routine
	stw   #_rts,hsync_vec	; user hsync routine

	stz   <_irq_m		; clear irq flag register
	stz   $1402		; enable interrupts
	stz   $1403
	cli

; ----
; enable display and VDC interrupts

	vreg  #5
	st1   #$CC
	st2   #$00

; ----
; jump to main routine

	map   main
	jmp   main


;±±±[ INTERRUPT CODE ]±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

_rts:
	rts
_rti:
	rti

; ----
; irq2
; ----
; IRQ2 interrupt handler
; ----

_irq2:
	bbs0  <_irq_m,.user
	rti
.user:
	jmp   [irq2_vec]

; ----
; irq1
; ----
; VDC interrupt handler
; ----

_irq1:
	bbs1  <_irq_m,.user_irq1 ; jump to the user irq1 vector

	pha
	phx
	phy
	lda   video_reg		; get VDC status register
	sta   <_vsr

; ----
; vsync interrupt

.vsync:
	bbr5  <_vsr,.hsync

	inc   vsync_cnt		; increment the IRQ counter
	jsr   read_joypad	; read the joypad
	bbr4  <_irq_m,.l1	; call the user vsync routine
	bsr   .user_vsync
.l1:

; ----
; hsync interrupt

.hsync:
	bbr2  <_vsr,.exit

	bbr6  <_irq_m,.l2	; call the user hsync routine
	bsr   .user_hsync
.l2:

; ----
; exit interrupt

.exit:
	lda   <_vreg		; restore the VDC register index
	sta   video_reg
	ply
	plx
	pla
	rti

; ----
; user routines

.user_hsync:
	jmp   [hsync_vec]
.user_vsync:
	jmp   [vsync_vec]
.user_irq1:
	jmp   [irq1_vec]

; ----
; timer
; ----
; timer interrupt handler
; ----

_timer:
	bbs2  <_irq_m,.user
	stz   $1403
	rti
.user:
	jmp   [timer_vec]

; ----
; nmi
; ----
; NMI interrupt handler
; ----

_nmi:
	bbs3  <_irq_m,.user
	rti
.user:
	jmp   [nmi_vec]


;±±[ LIBRARY ]±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

	.include "library.asm"

; ----
; set_intvec
; ----
; set interrupt vector
; ----
; IN : A = vector number
;           0 IRQ2
;           1 IRQ1 (VDC)
;           2 TIMER
;           3 NMI
;           4 VSYNC
;           5 HSYNC
;           6 SOFT RESET (RUN + SELECT)
;      X = vector address low byte
;      Y =   "      "    high byte
; ----

set_intvec:
	php
	sei
	cmp   #6
	blo   .vector
	bne   .exit
.reset:
	stx   soft_reset
	sty   soft_reset+1
	bra   .exit	
.vector:
	pha
	asl   A
	sax
	sta   user_vec,X
	inx
	tya
	sta   user_vec,X
	pla
.exit:
	plp
	rts

; ----
; wait_vsync
; ----
; wait the next vsync
; ----
; IN :  A = number of frames to be sync'ed on
; ----
; OUT:  A = number of elapsed frames since last call
; ----

wait_vsync:
	bbr1  <_irq_m,.l1
	cla			; return immediately if IRQ1 is redirected
	rts

.l1:	sei
	cmp   vsync_cnt		; calculate how many frames to wait
	beq   .l2
	bhs   .l3
	lda   vsync_cnt
.l2	inc   A
.l3:	sub   vsync_cnt
	sta   joycnt
	cli

.l4	lda   vsync_cnt		; wait
.l5:	cmp   vsync_cnt
	beq   .l5
	dec   joycnt
	bne   .l4

	stz   vsync_cnt
	inc   A
.exit:
	rts

; ----
; read_joypad
; ----
; poll joypads
;
; 'joyport' (location $1000) is a control read/write port which only reads
; 4 bits at a time; the program uses joyport to toggle the multiplex line
;
; real logic values are read into the port - the joypad's keys are default
; high, and 'pulled' low when pressed.  Therefore, these values must be
; inverted/complemented to yield values where '1' means 'pressed'
;
; bit values for joypad bytes: (MSB = #7; LSB = #0)
; -------------------------------------------------
; bit 0 (ie $01) = I
; bit 1 (ie $02) = II
; bit 2 (ie $04) = 'select'
; bit 3 (ie $08) = 'run'
; bit 4 (ie $10) = UP
; bit 5 (ie $20) = RIGHT
; bit 6 (ie $40) = DOWN
; bit 7 (ie $80) = LEFT
; ----

read_joypad:
	lda   #$01		; reset joypad port to joystick #1
	sta   joyport
	lda   #$03
	sta   joyport

; ----
; poll all the joypads

	cly			; counter for 5 joypads
.l1:	lda   #$01		; first nybble
	sta   joyport
	pha			; required delay (approx 9 cycles)
	pla
	nop
	nop
	lda   joy,Y		; move previous pad value to 'prev' area
	sta   joyold,Y
	lda   joyport		; fetch first nybble
	asl   A			; shift it to 'high' position within byte
	asl   A
	asl   A
	asl   A
	sta   joy,Y		; store in 'current' area
	stz   joyport		; toggle port (to read other 4 key values)
	pha			; delay again
	pla
	nop
	nop
	lda   joyport		; fetch second nybble
	and   #$0F		; clear unused bits
	ora   joy,Y		; merge 2 nybbles into 1 byte
	eor   #$FF		; reset 'sense' of keys
	sta   joy,Y		; store it
	eor   joyold,Y		; check against previous value
	and   joy,Y
	sta   joytrg,Y		; 'new key pressed' key values

	ora   joybuf,Y
	sta   joybuf,Y

	lda   joycnt
	cmp   #1
	bne   .l2
	lda   joy,Y
	eor   joyprev,Y
	and   joy,Y
	sta   joydlta,Y
	lda   joy,Y
	sta   joyprev,Y

.l2:	iny
	cpy   #$05		; cycle for next of 5 joypads
	bcc   .l1

; ----
; soft reset check

	cly			; start cycle of 5 joypads
.l3:	lda   joyena		; find mask of 'important' joysticks
	and   .bitmsk,Y
	beq   .l4		; not important enough to check
	lda   joytrg,Y
	cmp   #$04		; 'select' key newly-pressed ?
	bne   .l4
	lda   joy,Y
	cmp   #$0C		; 'run+select' currently pressed ?
	bne   .l4
	jmp   [soft_reset]	; run+select 'soft reset' vector

.l4:	iny			; try next joypad
	cpy   #$05
	bcc   .l3
; ----
; ok
	rts

.bitmsk:
	.db $01,$02,$04,$08,$10	; bit-mappings for check-reset


;±±[ DEFINES ]±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

; ----
; this block defines names for interrupt
; vectors

IRQ2		= 0
IRQ1		= 1
TIMER		= 2
NMI		= 3
VSYNC		= 4
HSYNC		= 5
SOFT_RESET	= 6

; ----
; this block defines names for joypad
; direction and button bits

JOY_I		= $01
JOY_II		= $02
JOY_SEL		= $04
JOY_RUN		= $08
JOY_UP		= $10
JOY_RIGHT	= $20
JOY_DOWN	= $40
JOY_LEFT	= $80

JOY_BITI	= $0
JOY_BITII	= $1
JOY_BITSEL	= $2
JOY_BITRUN	= $3
JOY_BITUP	= $4
JOY_BITRT	= $5
JOY_BITDN	= $6
JOY_BITLT	= $7

;±±[ MACROS ]±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

; ----
; setvec(num, addr)
; ----
; num,  vector number (see defines above)
; addr, address of the new routine
; ----

setvec	.macro
	 lda  \1
	 ldx  #LOW(\2)
	 ldy  #HIGH(\2)
	 jsr  set_intvec
	.endm

; ----
; vec_on(num)
; ----
; num, vector to enable
; ----

vec_on	.macro
	.if (\1 = 5)
	 smb  #6,<_irq_m
	.else
	 smb  \1,<_irq_m
	.endif
	.endm

; ----
; vec_off(num)
; ----
; num, vector to disable
; ----

vec_off	.macro
	.if (\1 = 5)
	 rmb  #6,<_irq_m
	.else
	 rmb  \1,<_irq_m
	.endif
	.endm

; ----
; vsync(nb)
; ----
; nb, number of frames to be sync'ed on
; ----

vsync	.macro
	.if (\# = 0)
	 lda #1
	.else
	 lda \1
	.endif
	 jsr  wait_vsync
	.endm


;±±[ USER PROGRAM ]±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±±

	.nomlist
	.list

	;...

