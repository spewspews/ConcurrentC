#include <u.h>
#include <libc.h>
#include <thread.h>

/* prints "Hello, world." */

void
otherthread(char *@d)
{
	print("%s", @d);
	print("%s\n", @d);
	threadexitsall(0);
}

void
threadmain(int, char**)
{
	char *@d;

	chanset(d, 0);
	cothread otherthread(d);

	d @= "Hello, ";
	d @= "world.";
	d @= "foobar";
}
