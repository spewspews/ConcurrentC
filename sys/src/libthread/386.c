#include <u.h>
#include <libc.h>
#include <thread.h>
#include "threadimpl.h"

void launcher386(void);

void
_threadinitstack(Thread *t, int argc, void *fn, void *argv)
{
	uintptr *tos, *sp;

	tos = sp = (uintptr*)(t->stk + (t->stksize&~7)) - (argc+2);
	*sp++ = (uintptr)fn;
	*sp++ = (uintptr)_threadexitsnil;
	memcpy(sp, argv, argc*sizeof(uintptr));
	t->sched[JMPBUFPC] = (uintptr)launcher386 + JMPBUFDPC;
	t->sched[JMPBUFSP] = (uintptr)tos - sizeof(uintptr);
}
