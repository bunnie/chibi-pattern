/*
 * chibi_pattern.asm
 *
 *  Created: 12/11/2013 18:10:20
 *   Author: bunnie
 *
 *  Please see LICENSE for license details (LGPLv3).
 */ 

.include "tn5def.inc"

 rjmp RESET  ;go and set up PORTB as an output
 // no interrupt vectors, as interrupts are not used

 .def  counter1  = r16
 .def  counter2  = r17
 .def  counter3  = r18
 .def  temp = r19     		; also end-value arg for PWM value change
 .def  temp1 = r20
 .def  temp2 = r21
 .def  prnstate = r22
 .def  adcval = r23
 .def  pwmstate = r24
 .def  pwmupdwn = r25

 ;time1 and time2 set the value for the final loop in each delay
 .equ  time1   = 180 ;between 0 and 255
 .equ  timef   = 120
 .equ  time2   = 2
 .equ  led     = 0 ;LED at PB0

RESET: ;set PB2 as an output in the Data Direction Register for PORTB
 ldi    prnstate, $01  ; start on a valid polynomial
 ldi    pwmstate, $00  ; start with a known pwm state
 ldi    pwmupdwn, $01  ; 0 down, 1 up

 ldi   temp, $0
 out   OCR0AH, temp

 sbi	DDRB, led  ;connect LED to PB0 (Attiny5 pin 1)

 in 	temp, DIDR0	; Load Digital Input Disable Register value to temporary
 sbr	temp, (1<<ADC2D)	; Disable Digital Inputs on ADC Channel 2
 out	DIDR0, temp	; Store it back to DIDR

 ldi	temp,$02	
 out	ADMUX,temp	; Monitor PB2 (ADC2)

 ldi	temp,$83	; Enable ADC with Clock prescaled by 8
 out	ADCSRA, temp;If Clock speed is 1MHz, then ADC clock = 1MHz/8 = 125kHz (must be 50-200kHz)

/////////////////////////
/// sample ADC to check what behavior we should have, and then dispatch to the correct function
/////////////////////////

_eternal:
 in 	temp, ADCSRA
 sbr	temp, (1<<ADSC)
 out	ADCSRA, temp; Start the ADC Conversion
poll:	
 in 	temp, ADCSRA
 sbrc	temp, 6
 rjmp 	poll		;Wait till ADC Conversion is complete
 in     adcval, ADCL	;Load ADC Conversion result to adcval

 ; resistor ratios are: 0 | 85 | 128 | 255
 ; 0-42 = twinkle
 ; 43-106 = fade
 ; 107-191 = blink
 ; 192-255 = heartbeat
 ldi    temp1,42	;Load MSB of reference value to another temporary register
 cp     adcval,temp1	;Compare both (adcval - temp1)

 rcall  pwmOn
; rjmp   heartbeat ; for debug only, force a particular function

 brsh   next1
 rcall  pwmOn
 rjmp   twinkle
next1:
 ldi    temp1, 106
 cp     adcval,temp1
 brsh   next2
 rcall  pwmOn
 rjmp   fade
next2:
 ldi    temp1, 191
 cp     adcval,temp1
 brsh   next3
 rjmp   blink
next3:
 rcall  pwmOn
 rjmp   heartbeat

/////////////////////// Blink behavior
blink: ; blink the LED
 rcall  pwmOn
	
 ldi   temp, $00
 rcall pwmChange
 ldi   temp1, $01  ; 00 00 00 01  disable PWM (in case we came from fade)
 out   TCCR0A, temp1
 sbi   DDRB, led  ;connect LED to PB0 (Attiny5 pin 1)
 sbi   PORTB, led ;LED off - cbi/sbi swapped for N-FET switching (ie.LED is OFF when FET is ON)

 ldi   counter2, time1 ;load counter1 delay
 ldi   counter3, time2 ;load counter3 delay
 rcall onDelay

 rcall pwmOn

 ldi   temp, $ff
 rcall pwmChange
 ldi   counter3, time2 ;load counter3 delay
 ldi   counter2, time1 ;load counter1 delay
 rcall offDelay
 rjmp 	_eternal	;Jump to "_eternal" and repeat again

/////////////////////// twinkle behavior
twinkle: ; twinkle the LED
 rcall do_prng
 mov   temp, prnstate
 rcall pwmChange
 rcall do_prng
 mov   counter2, prnstate
 ldi   counter3, 1
 rcall onDelay
 rcall do_prng
 mov   temp, prnstate
 rcall pwmChange
 rcall do_prng
 mov   counter2, prnstate
 lsr   counter2
 ldi   counter3, 1
 rcall onDelay
 rjmp 	_eternal	;Jump to "_eternal" and repeat again

/////////////////////// Fade behavior
fade: ; fade the LED
 ; wait a bit before changing the PWM value
 ldi   counter2, 6 ;load counter1 delay
 ldi   counter3, 1 ;load counter3 delay
 out   OCR0AL, pwmstate

 ; now update the up/down count
 sbrc  pwmupdwn, 0   ; skip next instruction if counting down
 rjmp  cntup
 rjmp  cntdwn
cntup:
 ldi   temp, $01   ; meh. clearly, I am not trying hard.
 add   pwmstate, temp
 brcc  faderet    ; skip to end if add didn't overflow
 ldi   pwmupdwn, 0  ; set up/down flag to down
 ldi   pwmstate, 255  ; i think at this point, the carry means we're at 0, so reset to 255 for down count
 rjmp  faderet
cntdwn:
 subi  pwmstate, 1
 brne  faderet    ; skip to end if result wasn't 0
 ldi   pwmupdwn, 1  ; set up/down flag to up

faderet:
 rcall onDelay
 rjmp 	_eternal	;Jump to "_eternal" and repeat again

/////////////////////// Heartbeat behavior
heartbeat: 
 ldi   temp, $04
 rcall pwmChange
 ldi   counter2, timef ;load counter1 delay
 ldi   counter3, 1 ;load counter3 delay
 rcall onDelay
 ldi   temp, $c0
 rcall pwmChange
 ldi   counter3, 1 ;load counter3 delay
 ldi   counter2, timef ;load counter1 delay
 rcall offDelay

 ldi   temp, $00
 rcall pwmChange
 ldi   counter2, timef ;load counter1 delay
 ldi   counter3, 1 ;load counter3 delay
 rcall onDelay
 ldi   temp, $ff
 rcall pwmChange
 ldi   counter3, 2 ;load counter3 delay
 ldi   counter2, time1 ;load counter1 delay
 rcall offDelay
 rjmp 	_eternal	;Jump to "_eternal" and repeat again

/////////////////////// Cheesy PRNG
do_prng: ; polynomial is 1 + x^4 + x^5 + x^6 + x^8; this is maximal LFSR for 255 states.
; eg bits are 3, 4, 5, and 7 to check for xor value
ldi    temp, 0   ; initially, no parity
sbrc   prnstate, 3
inc    temp
sbrc   prnstate, 4
inc    temp
sbrc   prnstate, 5
inc    temp
sbrc   prnstate, 7
inc    temp

andi   temp, $01
; now temp[0] should have prnstate[3] ^ prnstate[4] ^ prnstate[5] ^ prnstate[7]
lsl   prnstate
add   prnstate, temp
ret

/////////////////////// cycle-counting delays
onDelay:
 clr   counter1  ;clear counter1

loop1: ;nested loop that decrements counter 1 (255) x counter2 (time1) times (ie. 255*time1)
 dec   counter1  ;decrement counter1
 brne  loop1     ;branch if not 0
 dec   counter2  ;decrement counter2
 brne  loop1     ;branch if not 0
 dec   counter3
 brne  loop1
 ret

offDelay: ;same as onDelay but with a third loop
 clr   counter1
 clr   counter2


loop2: ;decrement counter 1(255) x counter2(255) x counter3(time2) (ie. 255*255*time2)
 dec   counter1
 brne  loop2
 dec   counter2
 brne  loop2
 dec   counter3
 brne  loop2
 ret

/////////////////////// PWM subsystem
//////////////// pwmChange should be used to cause "soft" transitions between lighting states
//////////////// pwmOn, pwmOff simply initialize the system into or out of the PWM hardware mode
pwmOn:
 ; enable PWM; use OC0A for digital output
 ldi   temp, $C1  ; 11 00 00 01  fast pwm mode, 8-bit, set OC0A on compare match, clear at bottom
 out   TCCR0A, temp
 ldi   temp, $09  ; 00 0 01 001  other 1/2 of fast PWM mode, clock scale = 8MHz / 1 (no prescale)
 out   TCCR0B, temp
 ret

pwmOff:
 ldi   temp, $01  ; 00 00 00 01  disable PWM (in case we came from fade)
 out   TCCR0A, temp
 ret


pwmChange:			; r19 (temp) has argument
 in    temp1, OCR0AL		; grab the current PWM value
 cp    temp1, temp  		; OCR0AL - temp -> flag
 brne  pwmNextTest
 ret
pwmNextTest:
 brlo  pwmGoUp  		; branch if C set, e.g. temp > OCR0AL
	;;  this case, OCR0AL < temp, so count down
pwmGoDn:
 rcall pwmWait
 rcall pwmWait
 dec   temp1
 out   OCR0AL, temp1
 cp    temp1, temp
 brne  pwmGoDn
 ret
	
pwmGoUp:
 rcall pwmWait
 rcall pwmWait
 inc   temp1
 out   OCR0AL, temp1
 cp    temp1, temp
 brne  pwmGoUp
 ret

pwmWait:
 in    temp2, TIFR0
 sbr   temp2, 0
 out   TIFR0, temp2
pwmWaitLoop:
 in    temp2, TIFR0
 sbrs  temp2, 0
 rjmp  pwmWaitLoop
 ret
