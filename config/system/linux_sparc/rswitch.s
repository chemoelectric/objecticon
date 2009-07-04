/*
 * Coswitch for Sun-4 Sparc.
 * 
 */

	.file	"rswitch.s"
	.section	".text"
	.align 4
	.global coswitch
	.type	coswitch, #function
	.proc	020
coswitch:
	save	%sp, -104, %sp
	st	%i0, [%fp+68]
	st	%i1, [%fp+72]
	st	%i2, [%fp+76]
	ta	0x03			/* ST_FLUSH_WINDOWS in trap.h     */
	ld	[%fp+0x44], %o0		/* load old_cs into %o0	          */
	st	%sp,[%o0]		/* Save user stack pointer        */
	st	%fp,[%o0+0x4]		/* Save frame pointer             */
	st	%i7,[%o0+0x8]		/* Save return address            */
	ld	[%fp+76], %g1
	cmp	%g1, 0
	bne	.LL2
	    				/* this is the first activation   */
	ld	[%fp+0x48], %o0		/* load new_cs into %o0           */
	ld	[%o0], %o1		/* load %o1 from cstate[0]        */

        /* Decrement new stack pointer value before loading it into sp.	  */
        /* The top 64 bytes of the stack are reserved for the kernel, to  */
        /* save the 8 local and 8 in registers into, on context switches, */
        /* interrupts, traps, etc.					  */
	save  %o1,-96, %sp		/* load %sp from %o1	          */
	call	new_context, 0
        /* not reached */
	 nop
	b	.LL5
	 nop
.LL2:
	ld	[%fp+0x48], %o0		/* load new_cs into %o0           */
	ld	[%o0+0x4],%fp		/* Load frame pointer             */
	ld	[%o0+0x8],%i7		/* Load return address            */
	ld	[%o0],%sp		/* Load user stack pointer        */
.LL5:
	restore
	jmp	%o7+8
	 nop
	.size	coswitch, .-coswitch
	.section	".note.GNU-stack"
