#
#  Assembler source for context switch on gcc/linux x86
#

.file	"rswitch.s"
.text
	.align 4

        .globl coswitch

coswitch:
        # Save esp and ebp to the current coexpression's state
	movl 4(%esp),%eax
	movl %esp,0(%eax)
	movl %ebp,4(%eax)

        # Is this the first activation of the target coexpression?
	cmpl $0,12(%esp)
	je .L2

        # No, so restore esp, ebp from its state
	movl 8(%esp),%eax
        movl 0(%eax),%esp
	movl 4(%eax),%ebp
	ret

.L2:
        # Yes, so set esp from its state, clear ebp and call
        # new_context (which never returns).
	movl 8(%esp),%eax
	movl 0(%eax),%esp
	movl $0,%ebp
	call new_context
