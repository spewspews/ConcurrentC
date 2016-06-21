#include <u.h>
#include <libc.h>
#include <thread.h>

void
thread(int @c, char *@d, int @e, int @end)
{
	int i;
	char *s;

	for(;;) switch @{
	alt s = @d:
		print("received from d: %s\n", s);
		print("and again from d: %s\n", @d);
		break;
	alt @end:
		print("ending\n");
		threadexitsall(nil);
	alt i = @c:
	alt i = @e:
		print("received from c or e: %d\n", i);
		break;
	}
}

void
threadmain(int, char**)
{
	int @ic, @jc;
	char *@sc;
	int @end;

	chanset(ic, 0);
	chanset(jc, 0);
	chanset(sc, 0);
	chanset(end, 0);

	cothread thread(ic, sc, jc, end);

	ic @= 5;
	ic @= 7;
	jc @= 20;
	sc @= "foobar";
	sc @= "hello";
	ic @= 10;
	end @= 0;
}
