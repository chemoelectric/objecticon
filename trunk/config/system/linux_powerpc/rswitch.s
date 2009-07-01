#  -*- mode: asm -*-
#	
#  coswitch(old, new, first)
#          GPR3  GPR4  GPR5

# This code is modeled after the ppc_aix context switch
# it was compared to the Darwin context switch routine to 
# get the syntax correct for the Apple gcc compiler.

# In turn adapted to ppc_gnulinux for use in GNU/Linux
# systems running on PowerPC machines by Jose E. Marchesi
# <jemarch@gnu.org> - 22 May 2003
	
.macro ENTRY
	.text
	.align		2
	.global		$0
	.global		coswitch

$0:
.endm

	.file	"rswitch.s"
	.set	RSIZE, 80		# room for regs 13-31, rounded up mod16

	ENTRY 
	
coswitch:

	stwu	%r1, -RSIZE(%r1)		# allocate stack frame

					# Save Old Context:
	stw	%r1, 0(%r3)		# SP
	stw	%r2, 4(%r3)		# TOC
	mflr	%r0
	stw	%r0, 8(%r3)		# LR (return address)
	mfcr	%r0
	stw	%r0, 12(%r3)		# CR
	stmw	%r13, -RSIZE(%r1)		# GPRs 13-31 (save on stack)

	cmpi	0, %r5, 0
	beq	first			# if first time

					# Restore new context:
	lwz	%r1, 0(%r4)		# SP
	lwz	%r2, 4(%r4)		# TOC
	lwz	%r0, 8(%r4)		# LR
	mtlr	%r0		
	lwz	%r0, 12(%r4)		# CR
	mtcr	%r0
	lmw	%r13, -RSIZE(%r1)		# GPRs 13-31 (from stack)
	
	addic	%r1, %r1, RSIZE		# deallocate stack frame
	blr				# return into new context

first:					# First-time call:
	lwz	%r1, 0(%r4)		# SP as figured by Icon
	addic	%r1, %r1, -64		# save area for callee
	bl	new_context		# new_context()
