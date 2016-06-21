#include <u.h>
#include <libc.h>
#include <thread.h>

void
thread(char *@d, int @c)
{
	d @= "foo";
	c @= 5;
	threadexitsall(nil);
}

void
threadmain(int, char**)
{
	int @c, i;
	char *@d, *s;

	chanset(c, 0);
	chanset(d, 0);

	cothread thread(d, c);

	for(;;) switch @@{
	alt i = @c:
		print("received %d\n", i);
		break;
	alt s = @d:
		print("received %s\n", s);
		break;
	default:
		print("no receive, yielding.\n");
		yield();
		break;
	}
}
