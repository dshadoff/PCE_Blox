; GAME.ASM v0.04
; --------
;
; This is part of the gameplay coding for a 'Falling Blocks' style of
; game for the PC-Engine, created using the MagicKit assembler.
;
; Key pieces of information:
;
;  playfield = 20 char's vertically + 4 'invisible' lines
;              10 char's horizontally
;
;  pieces (see piece data near end of listing)
;
;

        .include "startup.asm"
	.include "math.asm"
	.nomlist
	.list

;
;---- Compile Constants  ---------------------------------------------
;

;PROFILE_CODE	= 1		; change sprite colors to show CPU usage
;				; (0=NO ; 1=YES )

;
;---- Constants used by program --------------------------------------
;

BAT_VRAMLOC	= $0000 	; always starts at zero

CG_VRAMLOC      = $1000		; VRAM memory location for CG ('tile') data
CG_FONTLOC      = CG_VRAMLOC	; VRAM memory location for CG ('tile') data
CG_GRAPHICS	= CG_VRAMLOC + $1000	; $1000-$1FFF for font; this is graphics

SPR_VRAMLOC	= $5000 	; VRAM memory location for sprite data
SATB_VRAMLOC	= $7F00 	; VRAM memory location of SATB

CG_FONTPAL	= $0F		; palette entry for font

BGMAPHEIGHT	= 32		; 32 tiles high
BGMAPWIDTH      = 64            ; 64 tiles wide (using 'virtual' mode)

FIELDWIDTH	= 10		; Field size - # tiles wide
FIELDHEIGHT	= 20		; (# tiles high)
FIELDHIDHT	= 4		; height of 'hidden' portion at top

SCOREPOSX	= 3		; x-position of score message
SCOREPOSY	= 3		; y-position of score message
SCOREPAL	= 1		; CG palette # for printing scores

FIELDX		= 20		; field x-position in tiles - top left corner
FIELDY		= 1		; (y-position)   *-includes hidden portion

FLD_SPRXORG	= (FIELDX*8+32) ; pixel-based origin x-position (for sprites)
FLD_SPRYORG	= (FIELDY*8+64) ; (y-position)


PAUSEMSGX	= 22		; pause message (x,y) location
PAUSEMSGY	= 14

GAMOVRMSGX	= 23		; GAME OVER message (x,y) location
GAMOVRMSGY	= 14


JOYRPTMASK	= (JOY_LEFT|JOY_RIGHT|JOY_DOWN|JOY_I|JOY_II)
JOYRPTINIT	= 15		; 15 frames delay before initial repeat
JOYRPTSUBS	= 3		; 3 frames between repeats

DIFLVLSIZE	= 7		; size of "difficulty level" structure


;
; ---- Globals: ------------
;

;
; ---- Structure definition: ------------
; (use constants as offsets into struct):
;
;
; 'C' definition of piece-phase data structure:
;
; struct piecephasedata {
;	u_char		width;
;	u_char		height;
;	struct sqrpos	{
;		u_char	x;
;		u_char	y;
;	} square[4];
;	u_int16 	sprite_pattern_vram_address;
;	char		sprite_x_rotate_adjustment;
;	char		sprite_y_rotate_adjustment;
; }

		.rsset	0	; start counting at 0
PHS_WIDTH	.rs	1
PHS_HEIGHT	.rs	1
PHS_SQR1X	.rs	1
PHS_SQR1Y	.rs	1
PHS_SQR2X	.rs	1
PHS_SQR2Y	.rs	1
PHS_SQR3X	.rs	1
PHS_SQR3Y	.rs	1
PHS_SQR4X	.rs	1
PHS_SQR4Y	.rs	1
PHS_PATADDR	.rs	2
PHS_ROTADJX	.rs	1
PHS_ROTADJY	.rs	1


;
;---- Zero Page area used by program ---------------------------------
;
		.zp

waitcnt:	.ds	1	; countdown (in VSYNC frames)

dspfldptr:	.ds	2	; pointer into display field
fromfldptr:	.ds	2	; 'from' field pointer
tofldptr:	.ds	2	; 'to' field pointer

; sprite-specific .zp data:

pieceptr:	.ds	2	; pointer to piece data structure
phaseptr:	.ds	2	; pointer to piece phase data structure


; temporaries:

tmpptr: 	.ds	2	; temporary field pointer
xcnt:		.ds	1	; temporary x counter
ycnt:		.ds	1	; temporary y counter
tmpzp:		.ds	1	; temporary variable
txtptr:		.ds	2	; temp pointer into text message

;
;---- Scratchpad RAM used by program ---------------------------------
;

		.bss

; sprite-specific .bss data:

ramsatb:	.ds	512	; RAM copy of sprite attribute table

levelval:	.ds	1	; level #
scoreval:	.ds	6	; score
nxtlvlscr:	.ds	6	; score of next level
frampermov:	.ds	1	; # vsync frames per move
fpmcount:	.ds	1	; # vsync frames per move - counter

deletelines:	.ds	1

joyrptval:	.ds	1	; joypad-repeat "repeat value"
joyfrminit:	.ds	1	; joypad-repeat initial #frames
joyfrmsubs:	.ds	1	; joypad-repeat subsequent #frames
joyout:		.ds	1	; readable value (auto repeater)

pieceposx:	.ds	1	; x-position of piece (tile co-ordinates)
pieceposy:	.ds	1	; y-position of piece (tile co-ordinates)
piecenum:	.ds	1	; shape of piece
phasenum:       .ds     1       ; rotated 'phase' of piece
sprpataddr:	.ds	2	; sprite pattern address
sx:		.ds	2	; sprite x-position
sy:		.ds	2	; sprite y-position

oldx:		.ds	1	; temp (used when testing move/rotate)
oldy:		.ds	1	; temp (used when testing move/rotate)
oldphs: 	.ds	1	; temp (used when testing move/rotate)

tstx:		.ds	1	; test coordinates for individual blocks
tsty:		.ds	1
flg:		.ds	1	; return flag (0=ok, 1=err)

tmpcnt: 	.ds	1	; counter


; dispfld is a field for display of items, 24 lines * 10 char's

dispfld:				; RAM copy of display field;
					; 1 square = 1 byte
displn00:	.ds	FIELDWIDTH	; (top line)
displn01:	.ds	FIELDWIDTH
displn02:	.ds	FIELDWIDTH
displn03:	.ds	FIELDWIDTH
displn04:	.ds	FIELDWIDTH	; first visible line
displn05:	.ds	FIELDWIDTH
displn06:	.ds	FIELDWIDTH
displn07:	.ds	FIELDWIDTH
displn08:	.ds	FIELDWIDTH
displn09:	.ds	FIELDWIDTH
displn10:	.ds	FIELDWIDTH
displn11:	.ds	FIELDWIDTH
displn12:	.ds	FIELDWIDTH
displn13:	.ds	FIELDWIDTH
displn14:	.ds	FIELDWIDTH
displn15:	.ds	FIELDWIDTH
displn16:	.ds	FIELDWIDTH
displn17:	.ds	FIELDWIDTH
displn18:	.ds	FIELDWIDTH
displn19:	.ds	FIELDWIDTH
displn20:	.ds	FIELDWIDTH
displn21:	.ds	FIELDWIDTH
displn22:	.ds	FIELDWIDTH
displn23:	.ds	FIELDWIDTH	; (bottom line)



;---[ STARTUP CODE ]------------------------------------------------------------

; initialize the interrupt vectors

		.code
		.bank	MAIN_BANK
		.org	$C000

;---[ USER PROGRAM ]------------------------------------------------------------

main:

; Initialization section:
		jsr	loadvram	; load sprite/char/palettes into VRAM
		init_satb ramsatb	; init the RAM copy of SATB

		stw	#$65B2,_rndseed	; seed the random-number generator
		lda	#$CD
		sta	_rndseed+3
		vreg	#6		; rastercounter
		lda	video_data_l
		eor	video_data_h
		sta	_rndseed+2
		jsr	rand

; clear variables and arrays:

		jsr	clrdspfld	; init the playing field

		stz	deletelines	; clear score increment
		ldx	#0
		lda	#'0'		; clear score
.loop:		sta	scoreval,x
		inx
		cpx	#5
		bne	.loop		

; setup initial difficulty level:

		lda	#0
		sta	levelval
		jsr	setlevel	; set difficulty level

		lda	frampermov
		sta	fpmcount	; reset down-counter too

; get ready for first display of screen:

.rndlp		jsr	rand		; randomize game piece number
		lda	<_dx		; to between 0-6
		and	#7
		cmp	#7
		beq	.rndlp
		sta	piecenum	; to piece type #0
		jsr	setpiece	; default piece values

		jsr	setsprvars	; calculate sprite values
		jsr	sprite2satb	; set values in (RAM version of) SATB
		jsr	spritedisp	; update VRAM satb to video latches

		vsync			; synchronise with VSYNC interrupt

		jsr	dispbkgnd	; display background BAT map
		jsr	dispscore	; display score
		jsr	dispdspfld	; display the playing field

; main processing/display loop:

gameloop:	jsr	rand		; keep randomizing


	.IFDEF PROFILE_CODE
		setcolor #$100, #7, #0, #0	; set first profiling color
	.ENDIF


; calc animations & sprites

		jsr	sensejoy	; figure out joypad auto-repeat
		jsr	joypadmv	; move
		stz	joyout		; normal moves

		lda	joytrg		; special one-shot (run = pause)
		and	#JOY_RUN
		beq	.notpause
		jsr	pause

.notpause:

		jsr	setsprvars	; calculate sprite values


	.IFDEF PROFILE_CODE
		setcolor #$100, #0, #7, #0	; set next profiling color
	.ENDIF


		dec	fpmcount	; is it time to move piece down ?
		bne	.donemove
		lda	frampermov	; reset down-counter
		sta	fpmcount

		jsr	mvdown		; force piece down
		lda	flg		; hit bottom ?
		beq	.donemove	; no

.hitbottom:	stz	joyrptval	; reset joy-repeat

		jsr	snapshot	; xfer to background
		jsr	testhidn	; any squares in drop area ?
		lda	flg
		beq	.game_cont	; no, it's OK
		jmp	game_over	; yes, it's game_over

.game_cont:	jsr	testlines	; delete complete lines & add score
		jsr	nxtpiece	; set next piece

.donemove:


	.IFDEF PROFILE_CODE
		setcolor #$100, #0, #0, #7	; set next profiling color
	.ENDIF


		jsr	addscore	; add score (if any)
		jsr	chklvl		; advanced to next level ?

		jsr	setsprvars	; calculate sprite values
		jsr	sprite2satb	; set values in (RAM version of) satb
		jsr	spritedisp	; update VRAM satb to video latches


	.IFDEF PROFILE_CODE
		setcolor #$100, #0, #0, #0	; reset profiling color
	.ENDIF


		vsync
		jsr	dispscore
		jsr	dispdspfld	; display the playing field

		jmp	gameloop	; repeat


pause:		jsr	dispblnkfld	; blank field
					; and display a pause message

		setvwaddr #(PAUSEMSGY*BGMAPWIDTH + PAUSEMSGX)
		stw	#pausemsg, <txtptr
		jsr	dispmsg

.loop:		vsync
		lda	joytrg
		and	#JOY_RUN
		beq	.loop
		rts


game_over:	; this should do something more elaborate eventually
		;

		setvwaddr #(GAMOVRMSGY*BGMAPWIDTH + GAMOVRMSGX)
		stw	#gamovrmsg1, <txtptr
		jsr	dispmsg
		setvwaddr #((GAMOVRMSGY+1)*BGMAPWIDTH + GAMOVRMSGX)
		stw	#gamovrmsg2, <txtptr
		jsr	dispmsg

.loop:		vsync
		lda	joytrg
		and	#JOY_RUN
		beq	game_over
		jmp	main


;---[ USER SUBROUTINES ]--------------------------------------------------------

;----- joypad repeat ----

sensejoy:	lda	joy		; get joypad value (player #1)
		and	#JOYRPTMASK	; ignore useless keys
		cmp	joyrptval	; is it same as last time ?
		bne	.different	; nope - stop repeat

		lda	joyfrminit	; is initial wait done ?
		cmp	#JOYRPTINIT
		bne	.initwait	; nope - wait some more

		lda	joyfrmsubs	; is it time to repeat ?
		cmp	#JOYRPTSUBS
		bne	.subswait	; nope - wait some more

		lda	joyrptval	; hit it again
		sta	joyout		
		stz	joyfrmsubs	; start repeat wait cycle again
		rts

.different:	sta	joyout		; output keys
		sta	joyrptval	; keep for later
		stz	joyfrminit	; init counters
		stz	joyfrmsubs
		rts

.initwait:	inc	A		; inc counter
		sta	joyfrminit
		stz	joyfrmsubs
		rts

.subswait:	inc	A		; inc counter
		sta	joyfrmsubs
		rts


; ---- JOYSTICK routines ---------------------

;
; joypadmv - test joypad inputs, and move piece accordingly
;
; NOTE: 3 moves are possible in the same frame:
;	- rotate
;	- move horizontal
;	- move vertical
;

joypadmv:	lda	joyout		; put joystick value in zp
		sta	<tmpzp		; for easy branching

.tstI:		bbr	#JOY_BITI,  <tmpzp,.tstII
		jsr	rotclk		; rotate piece clockwise
		bra	.tstlft		; can't be both rotations

.tstII: 	bbr	#JOY_BITII, <tmpzp,.tstlft
		jsr	rotcntclk	; rotate piece counterclockwise

.tstlft: 	lda	joyout
		bbr	#JOY_BITLT, <tmpzp,.tstrt
		jsr	mvleft		; move piece left
		bra	.tstdn		; can't be both left and right

.tstrt: 	bbr	#JOY_BITRT, <tmpzp,.tstdn
		jsr	mvright 	; move piece right

.tstdn:		bbr	#JOY_BITDN, <tmpzp,.ret
		lda	#1		; set down-counter to trigger
		sta	fpmcount	; immediately for move down

.ret:		rts


;
; nxtpiece - change to the next piece type
;

nxtpiece:	jsr	rand		; randomize game piece number
		lda	<_dx		; to between 0-6
		and	#7
		cmp	#7
		beq	nxtpiece

		sta	piecenum
		jsr	setpiece
		rts


;
; setpiece - set default phase & position values for a piece
;

setpiece:	cla			; start with first phase, at (0,0)
		sta	phasenum
		sta	pieceposx
		sta	pieceposy

		jsr	setsprvars	; set pointers 'n' stuff

		ldy	#PHS_HEIGHT
		lda	#FIELDHIDHT	; make sure that one edge is in
		sec			; real playfield, by adjusting the
		sbc	[phaseptr],Y	; y-position according to height
		sta	pieceposy

		ldy	#PHS_WIDTH
		lda	#FIELDWIDTH	; center the piece too
		sec
		sbc	[phaseptr],Y
		lsr	A		; half of the difference between widths
		sta	pieceposx

		rts


;
; mvleft - move piece left
;

mvleft: 	jsr	storoldpos
		dec	pieceposx
		jsr	chkmvok
		lda	flg
		beq	.out
		jsr	backoutmv
.out:		rts


;
; mvright - move piece right
;

mvright:	jsr	storoldpos
		inc	pieceposx
		jsr	chkmvok
		lda	flg
		beq	.out
		jsr	backoutmv
.out:		rts


;
; mvup - move piece up
;
; (note: this is just for debugging; it is not used as part of the real game)
;

mvup:		jsr	storoldpos
		dec	pieceposy
		jsr	chkmvok
		lda	flg
		beq	.out
		jsr	backoutmv
.out:		rts


;
; mvdown - move piece down
;

mvdown: 	jsr	storoldpos
		inc	pieceposy
		jsr	chkmvok
		lda	flg
		beq	.out
		jsr	backoutmv
.out:		rts


;
; rotclk - rotate piece clockwise
;

rotclk: 	jsr	storoldpos
		lda	phasenum
		beq	.phase3
		dec	A
		bra	.adjust
.phase3:	lda	#3
.adjust:	sta	phasenum
		jsr	setphsptr	; new phase pointer

		ldy	#PHS_ROTADJX	; make rotate-adjustments to (x,y)
		lda	[phaseptr],Y
		add	pieceposx
		sta	pieceposx
		ldy	#PHS_ROTADJY
		lda	[phaseptr],Y
		add	pieceposy
		sta	pieceposy

		jsr	chkmvok
		lda	flg
		beq	.out
		jsr	backoutmv
.out:		rts


;
; rotcntclk - rotate piece counter-clockwise
;

rotcntclk:	jsr	storoldpos
		lda	phasenum
		inc	A
		cmp	#4
		bne	.adjust
		cla
.adjust:	sta	phasenum
		jsr	setphsptr	; new phase pointer

		ldy	#PHS_ROTADJX	; make rotate-adjustments to (x,y)
		lda	[phaseptr],Y
		add	pieceposx
		sta	pieceposx
		ldy	#PHS_ROTADJY
		lda	[phaseptr],Y
		add	pieceposy
		sta	pieceposy

		jsr	chkmvok
		lda	flg
		beq	.out
		jsr	backoutmv
.out:		rts


;
; chkmvok - check updated phase/position to determine
;	    whether it is valid
;

chkmvok:	stz	flg		; OK until proven otherwise

		ldy	#PHS_SQR1X	; test each square for validity
		lda	[phaseptr],Y
		add	pieceposx
		sta	tstx
		iny
		lda	[phaseptr],Y
		add	pieceposy
		sta	tsty
		jsr	testsqr

		ldy	#PHS_SQR2X	; game pieces all have 4 squares
		lda	[phaseptr],Y
		add	pieceposx
		sta	tstx
		iny
		lda	[phaseptr],Y
		add	pieceposy
		sta	tsty
		jsr	testsqr

		ldy	#PHS_SQR3X
		lda	[phaseptr],Y
		add	pieceposx
		sta	tstx
		iny
		lda	[phaseptr],Y
		add	pieceposy
		sta	tsty
		jsr	testsqr

		ldy	#PHS_SQR4X
		lda	[phaseptr],Y
		add	pieceposx
		sta	tstx
		iny
		lda	[phaseptr],Y
		add	pieceposy
		sta	tsty
		jsr	testsqr
		rts


;
; testsqr - test a square for validity (for moving game pieces)
;

testsqr:	lda	tstx		; test x range
		bmi	.bad		; < 0
		cmp	#FIELDWIDTH	; > maximum
		bcs	.bad

		lda	tsty		; test y range
		bmi	.bad		; < 0
		cmp	#(FIELDHEIGHT+FIELDHIDHT)	; > maximum
		bcs	.bad

		; Now find out if square is occupied:

		lda	tsty		; use tsty as index into displntbl
		asl	A		; array of pointers into the display
		tax			; field
		lda	displntbl,X
		sta	<dspfldptr
		inx
		lda	displntbl,X
		sta	<dspfldptr+1

                ldy     tstx            ; now use 'tstx' as offset

                lda     [dspfldptr],Y   ; if non-zero, it's occupied
		beq	.out

.bad:		lda	#1
		sta	flg

.out:		rts


;
; storoldpos - store old position in case we need to backout a move
;

storoldpos:	lda	pieceposx	; store old position and phase
		sta	oldx		; in case move is not possible
		lda	pieceposy	; (restore old)
		sta	oldy
		lda	phasenum
		sta	oldphs
		rts


;
; backoutmv - move was invalid; restore original position/phase
;

backoutmv:	lda	oldx		; move failed; restore original info
		sta	pieceposx
		lda	oldy
		sta	pieceposy
		lda	oldphs
		sta	phasenum
		rts


;
; snapshot - place piece into display field
;

snapshot:	ldy	#PHS_SQR1X	; move each square individually
		lda	[phaseptr],Y
		add	pieceposx
		sta	tstx
		iny
		lda	[phaseptr],Y
		add	pieceposy
		sta	tsty
		jsr	setsqr

		ldy	#PHS_SQR2X	; game pieces all have 4 squares
		lda	[phaseptr],Y
		add	pieceposx
		sta	tstx
		iny
		lda	[phaseptr],Y
		add	pieceposy
		sta	tsty
		jsr	setsqr

		ldy	#PHS_SQR3X
		lda	[phaseptr],Y
		add	pieceposx
		sta	tstx
		iny
		lda	[phaseptr],Y
		add	pieceposy
		sta	tsty
		jsr	setsqr

		ldy	#PHS_SQR4X
		lda	[phaseptr],Y
		add	pieceposx
		sta	tstx
		iny
		lda	[phaseptr],Y
		add	pieceposy
		sta	tsty
		jsr	setsqr

		rts


;
; setsqr - place a square into playfield (ie background)
;

setsqr: 	lda	tsty		; use tsty as index into displntbl
		asl	A		; array of pointers into the display
		tax			; field
		lda	displntbl,X
		sta	<dspfldptr
		inx
		lda	displntbl,X
		sta	<dspfldptr+1

                ldy     tstx            ; now use 'tstx' as offset

		lda	piecenum	; use piece type as marker
		inc	A

                sta     [dspfldptr],Y   ; it's now occupied
		rts


;
; Test hidden area, to see if any squares have been deposited here
; if yes, then game ends
;

testhidn:	stz	flg		; OK until proven otherwise

		cla
.loop1:		sta	<tmpzp		; loop of lines

		asl	A		; use A as index into displntbl
		tax			; array of pointers into the disp fld
		lda	displntbl,X
		sta	<dspfldptr
		inx
		lda	displntbl,X
		sta	<dspfldptr+1

		cly
.loop2:		lda	[dspfldptr],Y	; loop of squares in line
		bne	.bad
		iny
		cpy	#FIELDWIDTH
		bne	.loop2

		lda	<tmpzp
		inc	A
		cmp	#FIELDHIDHT
		bne	.loop1
		bra	.out

.bad:		lda	#1
		sta	flg

.out:		rts


;
; Add score (from 'deletelines')
; do not add a large number (ie. > 195)
;

addscore:	lda	deletelines
		beq	.out
		stz	deletelines
		ldx	#4
		clc
		adc	scoreval,x
		sta	scoreval,x
.testcarry:	cmp	#('9'+1)
		bcc	.nocarry
		sub	#10
		sta	scoreval,x
		inc	(scoreval-1),x
		bra	.testcarry
.nocarry:	dex
		beq	.out
		lda	scoreval,x
		bra	.testcarry
.out:		rts


;
; Test lines in play area, to see if any are complete
; if so, remove them by copying contents above down one line
;

testlines:	lda	#(FIELDHEIGHT+FIELDHIDHT-1)
.loop1:		sta	<ycnt

		asl	A		; use A as index into displntbl
		tax			; array of pointers into the disp fld
		lda	displntbl,X
		sta	<dspfldptr
		inx
		lda	displntbl,X
		sta	<dspfldptr+1

.loop2:		jsr	testline
		lda	flg		; if flg = 0, then compress this line
		bne	.nocompress	; else, don't

		inc	deletelines	; add to score

		jsr	compress
		bra	.loop2

.nocompress:	lda	<ycnt
		dec	A
		cmp	#(FIELDHIDHT-1)
		bne	.loop1
		rts


;
; Test line to see if it is complete
;

testline:	stz	flg
		cly
.loop1:		lda	[dspfldptr],Y
		beq	.bad
		iny
		cpy	#FIELDWIDTH
		bne	.loop1
		bra	.out

.bad:		lda	#1
		sta	flg
.out:		rts


;
; compress - remove a line by moving down block from above
;

compress:	lda	<ycnt
		sta	<tmpzp

.loop1		lda	<tmpzp

		asl	A
		tax
		lda	displntbl,X
		sta	<tofldptr
		inx
		lda	displntbl,X
		sta	<tofldptr+1

		stw	<tofldptr,<fromfldptr
		subw	#FIELDWIDTH,<fromfldptr

		jsr	copyline

		lda	<tmpzp
		dec	A
		cmp	#(FIELDHIDHT-1)
		beq	.out

		sta	<tmpzp
		bra	.loop1

.out:		rts


;
; copyline - copy 1 line of blocks from one place to another
;

copyline:	cly

.loop1:		lda	[fromfldptr],Y
		sta	[tofldptr],Y
		iny
		cpy	#FIELDWIDTH
		bne	.loop1
		rts
		rts

;
; Work with difficulty levels:
;

;
; setlevel: set level-information based on 'levelval'
;

setlevel:	stw	#diff_level, <tmpptr
		lda	levelval
		beq	.load
		sta	<tmpzp
.incloop:	addw	#DIFLVLSIZE, <tmpptr
		dec	<tmpzp
		bne	.incloop

.load:		lda	[tmpptr]
		sta	frampermov
		ldy	#5		; # bytes in score
.scrcpylp:	lda	[tmpptr],y
		sta	nxtlvlscr-1,y
		dey
		bne	.scrcpylp
		rts

;
; chklvl: check score against 'nxtlvlscr' to determine
;         when to advance difficulty level
;

chklvl:		clx			; start at first digit
.loop:		lda	nxtlvlscr,x
		cmp	scoreval,x
		bcc	.inclvl		; score is bigger
		bne	.out		; score is smaller

		inx			; don't know; check next digit
		cpx	#5
		bne	.loop
.out:		rts

.inclvl:	inc	levelval
		jsr	setlevel
		rts


; ---- SPRITE internals routines --------------------------

;
; setsprvars - setup sprite-related variables, based
;	       on game-piece information
;

setsprvars:	lda	pieceposx	; First, calculate sprite X-pos
		asl	A		; from tile co-ordinates
		asl	A
		asl	A
		stz	sx+1
		sta	sx
		addw	#FLD_SPRXORG,sx

		lda	pieceposy	; Now calculate sprite Y-pos
		asl	A		; from tile co-ordinates
		asl	A
		asl	A
		stz	sy+1
		sta	sy
		addw	#FLD_SPRYORG,sy

setpcnphs:	lda	piecenum	; Find piece & phase pattern info
		asl	A		; First, get piece pointer
		stz	<tmpptr+1
		sta	<tmpptr
		addw	#piecetbl,<tmpptr
		cly
		lda	[tmpptr],Y
		sta	<pieceptr
		iny
		lda	[tmpptr],Y
		sta	<pieceptr+1

setphsptr:	lda	phasenum	; Next, get phase pointer
		asl	A
		tay
		lda	[pieceptr],Y
		sta	<phaseptr
		iny
		lda	[pieceptr],Y
		sta	<phaseptr+1

		ldy	#PHS_PATADDR
		lda	[phaseptr],Y
		sta	sprpataddr
		iny
		lda	[phaseptr],Y
		sta	sprpataddr+1

		rts


;
; sprite2satb - update sprite var's in (RAM version of) satb
;

sprite2satb:	; sprite #1 = 'blocker', and sprite #2 = moving piece

		spr_set		#1,ramsatb
		spr_x		sx
		spr_y		#FLD_SPRYORG
		spr_pattern	#VRAM(p7cella)
		spr_ctrl	#SIZE_MASK|FLIP_MASK,#SIZE_32x32|NO_FLIP
		spr_pri		#0		; background
		spr_pal		#0

		spr_set 	#2,ramsatb	; sprite #2 in ramsatb
		spr_x		sx
		spr_y		sy
		spr_pattern	sprpataddr
		spr_ctrl	#SIZE_MASK|FLIP_MASK,#SIZE_32x32|NO_FLIP
		spr_pri 	#1		; foreground

		lda		piecenum	; piecenum is 0-relative,
		inc		A		; color is 1-relative
		sta		<tmpzp
		spr_pal 	<tmpzp
		rts


;
; spritedisp - update the satb, to display sprite(s)
;

spritedisp:	update_satb	ramsatb
		rts


; ---- INITIALIZATION routines --------------------

;
; loadvram - load VRAM with sprite/character data
;	     and associated palettes too
;

loadvram:	map	displntbl	; map in the data bank

		;
		; load sprites into VRAM at their respective locations
		;
                ; NOTE: each sprite is 32x32; 2 'phases' exist in each
		; 32x64 sprite unit that it loaded into memory
		; (this macro loads sprites in 32x64 units)
		;

		map	p0ph0cella	; map in temp graphics bank

		load_sprites	VRAM(p0ph0cella),p0ph0cella,#2
		load_sprites	VRAM(p1ph0cella),p1ph0cella,#2
		load_sprites	VRAM(p2ph0cella),p2ph0cella,#2
		load_sprites	VRAM(p3ph0cella),p3ph0cella,#1


		map	cgpal0		; map in temp graphics bank

		load_sprites	VRAM(p4ph0cella),p4ph0cella,#1
		load_sprites	VRAM(p5ph0cella),p5ph0cella,#1
		load_sprites	VRAM(p6ph0cella),p6ph0cella,#1
		load_sprites	VRAM(p7cella),p7cella,#1

		; load palette:

		set_bgpal	#0,cgpal0,#8	; fill CG palettes #0-7
		set_sprpal	#0,sprpal0,#8	; fill Sprite palettes #0-7

		; load characters into VRAM:

		map	offchr		; map in temp graphics bank

		fntcpy	CG_FONTLOC, font, #CG_FONTPAL, #$40	; load font

		vload	offchr,#(7*16)	; load graphics characters

		rts


; ---- MISCELLANEOUS routines -------------------

;
; wait_frames - Wait for a period of time (measured in VSYNC intervals)
;
; input - # of frames in waitcnt
;

wait_frames:	vsync

.l2:		dec	<waitcnt	; if processing took more than 1 frame,
		beq	.out
		dec	a		; then decrement correct # frames from
                bne     .l2             ; waiting period (returned in reg 'A')

		lda	<waitcnt
		bne	wait_frames
.out:		rts


;
; display the background:
; (currently displays checkered screen)
;

dispbkgnd:	setvwaddr #BAT_VRAMLOC	; set VRAM address to start of BAT map

		lda	#(BGMAPHEIGHT/2)	; # lines tall

.l1:		ldx	#(BGMAPWIDTH/2)		; # chars wide (whole virt map)
		pha

.l2:		; fill BAT map location

		stw	#CHAR(bkchr1),video_data
		stw	#CHAR(bkchr2),video_data
		dex				; next chars
		bne	.l2

		ldx	#(BGMAPWIDTH/2)		; # chars wide (whole virt map)

.l3:		; fill BAT map location alternate line

		stw	#CHAR(bkchr2),video_data
		stw	#CHAR(bkchr1),video_data
		dex				; next chars
		bne	.l3

		pla
		dec	a			; next lines
		bne	.l1

		rts


;
; clear the display field:
;

clrdspfld:	stw	#dispfld,<dspfldptr

		lda	#(FIELDHEIGHT+FIELDHIDHT)	; # tiles tall
.l1:		ldx	#FIELDWIDTH			; # chars wide
		pha
		cla
.l2:		sta	[dspfldptr]
		incw	<dspfldptr
		dex
		bne	.l2
		pla
		dec	a
		bne	.l1
		rts


;
; display the background, from the display field:
;

dispblnkfld:	lda	#FIELDHIDHT	; line #4 is first displayable line
					; up to (FIELDHEIGHT+FIELDHIDHT)

.l1:		pha
		asl	a		; use line# as index into table
		tax

		lda	dispvramtbl,x
		sta	<_di
		inx
		lda	dispvramtbl,x
		sta	<_di+1		; set the start VRAM address
                jsr     set_write       ; for this line's BAT

		ldx	#FIELDWIDTH	; # chars wide

.l2:		stw	#CHAR(offchr),video_data
		dex			; next block
		bne	.l2

		pla
		inc	a		; next line
		cmp	#(FIELDHEIGHT+FIELDHIDHT)	; # lines total
		bne	.l1

		spr_set #2,ramsatb	; sprite #2 in ramsatb
		spr_x	#0
		spr_y	#0
		jsr	spritedisp

		rts


;
; display the background, from the display field:
;

dispdspfld:	stw	#(dispfld+(FIELDHIDHT*FIELDWIDTH)),<dspfldptr
					; start reading display field only
					; from displayable portion

		lda	#FIELDHIDHT	; line #4 is first displayable line
					; up to (FIELDHEIGHT+FIELDHIDHT)

.l1:		pha
		asl	a		; use line# as index into table
		tax

		lda	dispvramtbl,x
		sta	<_di
		inx
		lda	dispvramtbl,x
		sta	<_di+1		; set the start VRAM address
                jsr     set_write       ; for this line's BAT

		ldx	#FIELDWIDTH	; # chars wide

.l2:		lda	[dspfldptr]
		beq	.off

.on:
		lda	#LOW(VRAM(fullchr)>>4)
		sta	video_data
		lda	[dspfldptr]
		asl	A
		asl	A
		asl	A
		asl	A
		ora	#HIGH(VRAM(fullchr)>>4)
		sta	video_data+1

		bra	.next

.off:		stw	#CHAR(offchr),video_data

.next:		incw	<dspfldptr
		dex			; next block
		bne	.l2

                ; finish the line with a 'right edge' character

		pla
		inc	a		; next line
		cmp	#(FIELDHEIGHT+FIELDHIDHT)	; # lines total
		bne	.l1

		rts


;
; display the score message on the screen
;

dispscore:	setvwaddr #(SCOREPOSY*BGMAPWIDTH + SCOREPOSX)
		stw	#scoremsg, <txtptr
		jsr	dispmsg
		stw	#scoreval, <txtptr
		jsr	dispmsg
		rts


dispmsg:	lda	[txtptr]
		beq	.out
		sub	#$20
		sta	video_data_l
		lda	#((SCOREPAL<<4)+(HIGH(CG_VRAMLOC)>>4))
		sta	video_data_h
		incw	<txtptr
		bra	dispmsg
.out:		rts

dispchar:	sub	#$20
		sta	video_data_l
		lda	#((SCOREPAL<<4)+(HIGH(CG_VRAMLOC)>>4))
		sta	video_data_h
		rts


;---[ GRAPHICS DATA ]-----------------------------------------------------------
;
; This data only needs to be mapped in order to load it
; into the video memory (then it can be unmapped)
;

	.data
	.bank	MAIN_BANK+1
	.org	$4000


; size of a single cell (16x16) of a sprite:
SPR_CELL	=	$40

; size of a full (32x32) sprite:
SPR_MEM 	=	$100


;---[ SPRITE DATA ]----------------------

;
; game pieces' data
; -----------------
;
; piece #:	   0	 1     2     3	   4	 5     6
;
; appearance:	   XX	 XX    X     X	    X	 X     XX
;		   X	  X    XX    X	   XX	 XX    XX
;		   X	  X    X     X	   X	  X
;				     X
;
;-----------------------------------------
;
; Piece 0 has the following rotation cycle: (counter-clockwise)
;
; phase #:	   0	 1     2     3
;
; appearance:	   XX	 X	X    XXX
;		   X	 XXX	X      X
;		   X	       XX
;
;-----------------------------------------
;
; Piece 1 has the following rotation cycle: (counter-clockwise)
;
; phase #:	   0	 1     2     3
;
; appearance:	   XX	 XXX   X       X
;		    X	 X     X     XXX
;		    X	       XX
;
;-----------------------------------------
;
; Piece 2 has the following rotation cycle: (counter-clockwise)
;
; phase #:	   0	 1     2     3
;
; appearance:	   X	  X	X    XXX
;		   XX	 XXX   XX     X
;		   X		X
;
;-----------------------------------------
;
; Piece 3 has the following rotation cycle: (counter-clockwise)
;
; phase #:	   0	 1     2     3
;
; appearance:	   X	 XXXX  X    XXXX
;		   X	       X
;		   X	       X
;		   X	       X
;
;-----------------------------------------
;
; Piece 4 has the following rotation cycle: (counter-clockwise)
;
; phase #:	   0	 1     2     3
;
; appearance:	    X	 XX	X    XX
;		   XX	  XX   XX     XX
;		   X	       X
;
;-----------------------------------------
;
; Piece 5 has the following rotation cycle: (counter-clockwise)
;
; phase #:	   0	 1     2     3
;
; appearance:	   X	  XX   X      XX
;		   XX	 XX    XX    XX
;		    X		X
;
;-----------------------------------------
;
; Piece 6 has the following rotation cycle: (counter-clockwise)
;
; phase #:	   0	 1     2     3
;
; appearance:	   XX	 XX    XX    XX
;		   XX	 XX    XX    XX
;
;-----------------------------------------
;
SPR0_VRAM	=	SPR_VRAMLOC
	.include  "sprite0.asm"

SPR1_VRAM	=	SPR0_VRAM+SPR0_SIZE
	.include  "sprite1.asm"

SPR2_VRAM	=	SPR1_VRAM+SPR1_SIZE
	.include  "sprite2.asm"

SPR3_VRAM	=	SPR2_VRAM+SPR2_SIZE
	.include  "sprite3.asm"



; ----------- End of Bank #2 (full) -----------

; ----------- Start of Bank #3 -----------
;
; This data only needs to be mapped in order to load it
; into the video memory (then it can be unmapped)
;

	.data
	.bank	MAIN_BANK+2
	.org	$4000


SPR4_VRAM	=	SPR3_VRAM+SPR3_SIZE
	.include  "sprite4.asm"

SPR5_VRAM	=	SPR4_VRAM+SPR4_SIZE
	.include  "sprite5.asm"

SPR6_VRAM	=	SPR5_VRAM+SPR5_SIZE
	.include  "sprite6.asm"


;---[ PALETTE DATA ]---------------------
;
	.include  "palette1.asm"


;---[ CHARACTER DATA ]-------------------
;

;	.data
;	.bank	MAIN_BANK+3
;	.org	$4000

;  offchr    cornerchr	 endchr    bottomchr  fullchr
;  $1000      $1010	 $1020	    $1030      $1040
; ........   XXXXXXXX	X.......   XXXXXXXX   XXXXXXXX
; ........   X.......	X.......   ........   XXXXXXXX
; ........   X.......	X.......   ........   XXXXXXXX
; ........   X.......	X.......   ........   XXXXXXXX
; ........   X.......	X.......   ........   XXXXXXXX
; ........   X.......	X.......   ........   XXXXXXXX
; ........   X.......	X.......   ........   XXXXXXXX
; ........   X.......	X.......   ........   XXXXXXXX
;

	.include  "font.inc"
	.include  "cgchar1.asm"


;---[ USER DATA ]---------------------------------------------------------------
;
; This data is needed on a fairly consistent basis while the
; game mainloop is executing, so keep it mapped
;

	.data
	.bank	MAIN_BANK+3
	.org	$A000

;
; Pointers to display field data, at the start of each line:
;
displntbl:	dw	displn00
		dw	displn01
		dw	displn02
		dw	displn03
		dw	displn04
		dw	displn05
		dw	displn06
		dw	displn07
		dw	displn08
		dw	displn09
		dw	displn10
		dw	displn11
		dw	displn12
		dw	displn13
		dw	displn14
		dw	displn15
		dw	displn16
		dw	displn17
		dw	displn18
		dw	displn19
		dw	displn20
		dw	displn21
		dw	displn22
		dw	displn23

;
; Pointers to display field VRAM addresses, at the start of each line:
;
dispvramorg     =       (FIELDY*BGMAPWIDTH)+FIELDX ; field's display location
dispvramtbl:	dw	dispvramorg
		dw	dispvramorg+( 1*BGMAPWIDTH)
		dw	dispvramorg+( 2*BGMAPWIDTH)
		dw	dispvramorg+( 3*BGMAPWIDTH)
		dw	dispvramorg+( 4*BGMAPWIDTH)	; first visible line
		dw	dispvramorg+( 5*BGMAPWIDTH)	
		dw	dispvramorg+( 6*BGMAPWIDTH)
		dw	dispvramorg+( 7*BGMAPWIDTH)
		dw	dispvramorg+( 8*BGMAPWIDTH)
		dw	dispvramorg+( 9*BGMAPWIDTH)
		dw	dispvramorg+(10*BGMAPWIDTH)
		dw	dispvramorg+(11*BGMAPWIDTH)
		dw	dispvramorg+(12*BGMAPWIDTH)
		dw	dispvramorg+(13*BGMAPWIDTH)
		dw	dispvramorg+(14*BGMAPWIDTH)
		dw	dispvramorg+(15*BGMAPWIDTH)
		dw	dispvramorg+(16*BGMAPWIDTH)
		dw	dispvramorg+(17*BGMAPWIDTH)
		dw	dispvramorg+(18*BGMAPWIDTH)
		dw	dispvramorg+(19*BGMAPWIDTH)
		dw	dispvramorg+(20*BGMAPWIDTH)
		dw	dispvramorg+(21*BGMAPWIDTH)
		dw	dispvramorg+(22*BGMAPWIDTH)
		dw	dispvramorg+(23*BGMAPWIDTH)	; last line
		dw	dispvramorg+(24*BGMAPWIDTH)	; bottom edge

;
; General info about game pieces' data
; ------------------------------------
;
; There are 7 different pieces in use, and each piece has
; up to 4 different rotations, or 'phases'.  Each piece has
; 4 sub-pieces, or 'squares', and each piece can be
; represented inside of a 2x2 cell sprite unit (32x32 pixels)
; Only piece #2 (the 4-unit long one) requires special
; consideration for its origin to be moved during a rotate
; operation.
;
;
; The overall data format is as follows:
; piece table(piece_index) -> phase table
; phase table(phase_index) -> phase data structure
;
; The data structure contains the following information:
; (listed in 'C' structure format)
;
; struct sqrpos {
;	u_char		x;
;	u_char		y;
; }
;
; struct piecephasedata {
;	u_char		width;
;	u_char		height;
;	struct sqrpos	square[4];
;	u_int16 	sprite_pattern_vram_address;
;	char		sprite_x_rotate_adjustment;
;	char		sprite_y_rotate_adjustment;
; }
;
; the square data is used for detecting existing filled-blocks
; (for collision-detection), and for sprite-to-block transfer
; when the piece comes to rest
;
; sprite_x_rotate_adjustment (and y) is only used for piece #2, to
; compensate for its special rotation (around its second square)
;

;
; game pieces' data
; -----------------
;
; piece #:	   0	 1     2     3	   4	 5     6
;
; appearance:	   XX	 XX    X     X	    X	 X     XX
;		   X	  X    XX    X	   XX	 XX    XX
;		   X	  X    X     X	   X	  X
;				     X
; # rotation
;   phases:	   4	 4     4     2	   2	 2     1
;
piecetbl:	dw	p0phstbl
		dw	p1phstbl
		dw	p2phstbl
		dw	p3phstbl
		dw	p4phstbl
		dw	p5phstbl
		dw	p6phstbl

p0phstbl:	dw	p0ph0dat
		dw	p0ph1dat
		dw	p0ph2dat
		dw	p0ph3dat

p1phstbl:	dw	p1ph0dat
		dw	p1ph1dat
		dw	p1ph2dat
		dw	p1ph3dat

p2phstbl:	dw	p2ph0dat
		dw	p2ph1dat
		dw	p2ph2dat
		dw	p2ph3dat

p3phstbl:	dw	p3ph0dat
		dw	p3ph1dat
		dw	p3ph0dat
		dw	p3ph1dat

p4phstbl:	dw	p4ph0dat
		dw	p4ph1dat
		dw	p4ph0dat
		dw	p4ph1dat

p5phstbl:	dw	p5ph0dat
		dw	p5ph1dat
		dw	p5ph0dat
		dw	p5ph1dat

p6phstbl:	dw	p6ph0dat
		dw	p6ph0dat
		dw	p6ph0dat
		dw	p6ph0dat


p0ph0dat:	db	2,3			; width, height
		db	0,0, 1,0, 0,1, 0,2	; 4 squares
		dw	SPR_VRAM(p0ph0cella)	; pattern address
		db	0,0			; x-,y-adjust

p0ph1dat:	db	3,2			; width, height
		db	0,0, 0,1, 1,1, 2,1	; 4 squares
		dw	SPR_VRAM(p0ph1cella)	; pattern address
		db	0,0			; x-,y-adjust

p0ph2dat:	db	2,3			; width, height
		db	1,0, 1,1, 1,2, 0,2	; 4 squares
		dw	SPR_VRAM(p0ph2cella)	; pattern address
		db	0,0			; x-,y-adjust

p0ph3dat:	db	3,2			; width, height
		db	0,0, 1,0, 2,0, 2,1	; 4 squares
		dw	SPR_VRAM(p0ph3cella)	; pattern address
		db	0,0			; x-,y-adjust


p1ph0dat:	db	2,3			; width, height
		db	0,0, 1,0, 1,1, 1,2	; 4 squares
		dw	SPR_VRAM(p1ph0cella)	; pattern address
		db	0,0			; x-,y-adjust

p1ph1dat:	db	3,2			; width, height
		db	0,0, 0,1, 1,0, 2,0	; 4 squares
		dw	SPR_VRAM(p1ph1cella)	; pattern address
		db	0,0			; x-,y-adjust

p1ph2dat:	db	2,3			; width, height
		db	0,0, 0,1, 0,2, 1,2	; 4 squares
		dw	SPR_VRAM(p1ph2cella)	; pattern address
		db	0,0			; x-,y-adjust

p1ph3dat:	db	3,2			; width, height
		db	0,1, 1,1, 2,1, 2,0	; 4 squares
		dw	SPR_VRAM(p1ph3cella)	; pattern address
		db	0,0			; x-,y-adjust


p2ph0dat:	db	2,3			; width, height
		db	0,0, 0,1, 1,1, 0,2	; 4 squares
		dw	SPR_VRAM(p2ph0cella)	; pattern address
		db	0,0			; x-,y-adjust

p2ph1dat:	db	3,2			; width, height
		db	0,1, 1,0, 1,1, 2,1	; 4 squares
		dw	SPR_VRAM(p2ph1cella)	; pattern address
		db	0,0			; x-,y-adjust

p2ph2dat:	db	2,3			; width, height
		db	0,1, 1,0, 1,1, 1,2	; 4 squares
		dw	SPR_VRAM(p2ph2cella)	; pattern address
		db	0,0			; x-,y-adjust

p2ph3dat:	db	3,2			; width, height
		db	0,0, 1,0, 2,0, 1,1	; 4 squares
		dw	SPR_VRAM(p2ph3cella)	; pattern address
		db	0,0			; x-,y-adjust

;
; Note: Piece #3 rotates around 2nd square, not 1st
;
p3ph0dat:	db	1,4			; width, height
		db	0,0, 0,1, 0,2, 0,3	; 4 squares
		dw	SPR_VRAM(p3ph0cella)	; pattern address
		db	1,-1			; x-,y-adjust

p3ph1dat:	db	4,1			; width, height
		db	0,0, 1,0, 2,0, 3,0	; 4 squares
		dw	SPR_VRAM(p3ph1cella)	; pattern address
		db	-1,1			; x-,y-adjust


p4ph0dat:	db	2,3			; width, height
		db	1,0, 1,1, 0,1, 0,2	; 4 squares
		dw	SPR_VRAM(p4ph0cella)	; pattern address
		db	0,0			; x-,y-adjust

p4ph1dat:	db	3,2			; width, height
		db	0,0, 1,0, 1,1, 2,1	; 4 squares
		dw	SPR_VRAM(p4ph1cella)	; pattern address
		db	0,0			; x-,y-adjust


p5ph0dat:	db	2,3			; width, height
		db	0,0, 0,1, 1,1, 1,2	; 4 squares
		dw	SPR_VRAM(p5ph0cella)	; pattern address
		db	0,0			; x-,y-adjust

p5ph1dat:	db	3,2			; width, height
		db	0,1, 1,1, 1,0, 2,0	; 4 squares
		dw	SPR_VRAM(p5ph1cella)	; pattern address
		db	0,0			; x-,y-adjust


p6ph0dat:	db	2,2			; width, height
		db	0,0, 0,1, 1,0, 1,1	; 4 squares
		dw	SPR_VRAM(p6ph0cella)	; pattern address
		db	0,0			; x-,y-adjust

;
; --- TEXT ------------------------------------
;

scoremsg:	db	"SCORE: "
		db	0

pausemsg:	db	"PAUSE"
		db	0

gamovrmsg1:	db	"GAME"
		db	0
gamovrmsg2:	db	"OVER"
		db	0

;
; Difficulty-level data:
; For now, it's a list of speed and next-level-starts-at scores
;  speed is "vsync-frames per move", and score is in "lines cleared"
;
diff_level:
.diff1:		db	30
		db	"00004"
		db	0
.diff2:		db	24
		db	"00009"
		db	0
.diff3:		db	20
		db	"00014"
		db	0
.diff4:		db	16
		db	"00019"
		db	0
.diff5:		db	12
		db	"00029"
		db	0
.diff6:		db	10
		db	"00039"
		db	0
.diff7:		db	8
		db	"00049"
		db	0
.diff8:		db	6
		db	"00059"
		db	0
.diff9:		db	5
		db	"00069"
		db	0
.diff10:	db	4
		db	"00079"
		db	0
.diff11:	db	3
		db	"00099"
		db	0
.diff12:	db	2
		db	"00119"
		db	0
.diff13:	db	1
		db	"99999"
		db	0

