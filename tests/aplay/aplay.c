#include <u.h>
#include <libc.h>
#include <draw.h>
#include <thread.h>
#include <mouse.h>
#include <keyboard.h>

char *devaudio = "/dev/audio";
char *codec = "/bin/audio/mp3dec";
char *title = "play";
Waitmsg *@waitchan;
vlong maxoff, curoff;
int codecpid, paused, debug;
Image *back, *bord;

void codecproc(int@, int);
void inproc(int@, int);
void inputthread(char*@);
void resized(int new);
void shutdown(char*);
void start(void);
void startstop(void);
void threadsfatal(void);
void timerproc(int);
void usage(void);
void waitforaudio(void);

void
threadmain(int argc, char **argv)
{
	char *@exitchan;

	threadsetname("mainproc");
	ARGBEGIN {
	case 'C':
		codec = ARGF();
		if(codec == nil)
			usage();
		break;
	case 'a':
		devaudio = ARGF();
		if(devaudio == nil)
			usage();
		break;
	default:
		usage();
		break;
	} ARGEND;

	if(argc > 1)
		usage();
	if(argc == 1) {
		close(0);
		title = argv[0];
		if(open(title, OREAD) != 0)
			threadsfatal();
	}

	close(1);
	if(open(devaudio, OWRITE) != 1)
		threadsfatal();

	if((maxoff = seek(0, 0, 2)) <= 0) {
		fprint(2, "Empty file: %s\n", title);
		shutdown(0);
	}

	initdraw(nil, nil, argv0);
	back = allocimagemix(display, DPalebluegreen, DWhite);
	bord = allocimage(display, Rect(0,0,1,1), screen->chan, 1, DPurpleblue);

	waitchan = threadwaitchanext();
	chanset(exitchan, 0);

	cothread inputthread(exitchan);
	coproc timerproc(500);

	start();
	shutdown(@exitchan);
}

void
inputthread(char *@exit)
{
	Mousectlext *mc = initmouseext(nil, screen);
	Keyboardctlext *kc = initkeyboardext(nil);
	Rune r;
	vlong o;
	int i;

	threadsetname("inputthread");
	i = 1;
	for(;;) switch @{
	alt mc->Mouse = @mc->c:
		if(mc->buttons == 0)
			break;
		do {
			if(paused == 0)
				startstop();
			o = mc->xy.x - screen->r.min.x;
			if(o < 0) o = 0LL;
			o *= maxoff;
			o /= Dx(screen->r);
			o &= ~0xFLL;
			curoff = o;
			resized(0);
			mc->Mouse = @mc->c;
		} while(mc->buttons != 0);
		startstop();
		break;
	alt r = @kc->c:
		switch(r) {
		case 'q':
		case Kdel:
			exit @= nil;
			break;
		case ' ':
			startstop();
			break;
		}
		break;
	alt @mc->resizec:
		resized(i);
		break;
	}
}

void
inproc(int @c, int fd)
{
	char buf[1024];
	long n;

	threadsetname("inproc");
	rfork(RFFDG);
	c @= threadid();
	dup(fd, 1);
	close(fd);
	for(;;) {
		n = sizeof(buf);
		if(curoff < 0)
			curoff = 0;
		else if(curoff >= maxoff)
			threadexits(0);
		if(n > maxoff - curoff)
			n = maxoff - curoff;
		n = pread(0, buf, n, curoff);
		if(n <= 0)
			threadexits(0);
		if(write(1, buf, n) != n)
			threadexits(0);
		curoff += n;
	}
}

void
codecproc(int @c, int infd)
{
	char *args[2];

	threadsetname("codecproc");
	rfork(RFFDG);
	if(dup(infd, 0) < 0)
		threadsfatal();
	close(infd);
	args[0] = codec;
	args[1] = nil;
	procexec(c, codec, args);
	threadsfatal();
}

void
timerproc(int t)
{
	threadsetname("timerproc");
	for(;;) {
		sleep(t);
		resized(0);
	}
}

void
resized(int new)
{
	Rectangle r1, r2;
	char buf[512];
	
	if(new && getwindow(display, Refnone) < 0)
		threadsfatal();
	r1 = screen->r;
	r2 = screen->r;
	r1.max.x = r1.min.x + Dx(screen->r) * ((double)curoff/(double)maxoff);
	r2.min.x = r1.max.x;

	draw(screen, r1, back, nil, ZP);
	draw(screen, r2, display->white, nil, ZP);

	if(paused)
		strcpy(buf, "paused");
	else
		strecpy(buf, buf+sizeof(buf), title);

	r2.min = ZP;
	r2.max = stringsize(display->defaultfont, buf);
	r1 = rectsubpt(screen->r, screen->r.min);
	r2 = rectaddpt(r2, subpt(divpt(r1.max, 2), divpt(r2.max, 2)));
	r2 = rectaddpt(r2, screen->r.min);
	r1 = insetrect(r2, -2);
	border(screen, r1, -2, bord, ZP);

	string(screen, r2.min, display->black, ZP, display->defaultfont, buf);

	flushimage(display, 1);
}

void
waitforaudio(void)
{
	Dir *d;

	for(;;) {
		d = dirstat(devaudio);
		if(d->length == 0)
			break;
		free(d);
		sleep(100);
	}
	free(d);
}

void
usage(void)
{
	fprint(2, "%s: aplay [-C codec] [-a audiodevice] [file]\n", argv0);
	threadexitsall(0);
}

void
shutdown(char *s)
{
	if(codecpid != 0)
		postnote(PNPROC, codecpid, "die yankee pig dog");
	threadexitsall(s);
}

void
threadsfatal(void)
{
	fprint(2, "%r\n");
	shutdown("error");
}

int @pidchan;
int inpid, p[2];

void
start()
{
	chanset(pidchan, 0);
	paused = 1;
	startstop();
}

void
startstop()
{
	Waitmsg *w;

	if(paused) {
		waitforaudio();
		assert(codecpid == 0 && inpid == 0);
		if(pipe(p) < 0)
			threadsfatal();
		coproc codecproc(pidchan, p[0]);
		codecpid = @pidchan;
		coproc inproc(pidchan, p[1]);
		inpid = @pidchan;
		close(p[0]);
		close(p[1]);
	} else {
		assert(codecpid != 0 && inpid != 0);
		postnote(PNPROC, codecpid, "die yankee pig dog");
		w = @waitchan;
		if(w->pid != codecpid)
			threadsfatal();
		free(w);	
		threadkill(inpid);
		codecpid = inpid = 0;
	}
	paused ^= 1;
	resized(0);
}
