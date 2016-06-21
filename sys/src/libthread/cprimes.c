#include <u.h>
#include <libc.h>
#include <thread.h>

int quiet;
int goal;
int buffer;

void
primethread(int @c)
{
	int @nc;
	int p, i;

	p = @c;
	if(p > goal)
		threadexitsall(nil);
	if(!quiet)
		print("%d\n", p);
	chanset(nc, 0);
	cothread primethread(nc);
	for(;;){
		i = @c;
		if(i%p)
			nc @= i;
	}
}

void
threadmain(int argc, char **argv)
{
	int i;
	int @c;

	ARGBEGIN{
	case 'q':
		quiet = 1;
		break;
	case 'b':
		buffer = atoi(ARGF());
		break;
	}ARGEND

	if(argc>0)
		goal = atoi(argv[0]);
	else
		goal = 100;

	chanset(c, buffer);
	cothread primethread(c);
	for(i=2;; i++)
		c @= i;
}
