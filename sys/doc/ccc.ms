.TL
The Plan 9 Front Concurrent C Extensions
.AU
Benjamin Purcell (spew)
benjapurcell@gmail.com
.AB
The Plan 9 Front compilers extend the C programming language
to provide builtin CSP style concurrency operations.
This paper describes the usage and implementation of the
extension.
.AE
.NH
Introduction and Motivation
.LP
Programming with CSP style concurrency is an essential part
of the Plan 9 operating system. Concurrent
programs were originally written in Alef which had builtin
concurrency operations. When Alef was retired, a library
was written to allow access to CSP operations from programs
written in C (see
.I thread (2)).
However, there are a number of deficiencies with
.I thread (2):
thread creation is inflexible, receiving or sending of
multiple channels requires an awkward definition of an array
of structures, and the send/receive operations
are not type safe. This extension aims to address those
concerns to make threaded programs easier and safer to
write without the need to maintain a separate compiler
infrastructure such as Alef. This document assumes
familiarity with
.I thread (2).
.NH
The Extensions
.LP
The compiler extension provides for launching
new threads and processes, declaring and allocating storage
for typed channels, and type safe sending and receiving from
channels. It also provides a new control structure
for type safe sending or receiving of multiple channels.
.NH 2
Thread and Process Creation
.LP
Threads and processes are created using the keywords
.CW coproc
and
.CW cothread
which have the syntax of a function that takes
two arguments. The first argument a function
application, and the second is an unsigned int
that specifies the stack size for the process or
thread. The calls
.CW coproc
and
.CW cothread
return the resultant thread id.
.DS
.CW
.TA .1i
	int tid, pid
	void fn(int arg1, double arg2, char *arg3);
	...
	tid = cothread(fn(a, b, c), 8192);
	pid = coproc(fn(a, b, c), 8192);
.DE
The function passed to
.CW coproc
and
.CW cothread
can have any signature, though its return value will not
be used. Instead of applying the function to its arguments,
the calls of
.CW cothread
and
.CW coproc
tell the compiler to check the arguments to the function
and then compile a call into
.I thread (2)
to start the function
in a new thread or process with a memory allocated stack
(see
.I malloc (2)).
Due to the type-checking, if
.CW a ,
.CW b ,
and
.CW c ,
are of an incompatible type to
.CW int ,
.CW double ,
and
.CW char*
respectively, then the example above will not compile.
.NH 2
Channel Declarations
.LP
The extension reserves the character
.CW @
for declarations of typed channels. A typed channel
has a type—referred to as the sending type—associated with it; only values of that
type may be sent or received from the channel. The
.CW @
symbol has the same precedence as the pointer dereference
.CW *
and serves a similar purpose. Thus
.DS
.CW
.TA .1i
	int @c;
.DE
declares
.CW c
to be a channel for sending/receiving an int;
.DS
.CW
.TA .1i
	char *@c;
.DE
declares
.CW c
to be a channel for sending/receiving a pointer to
a char; and
.DS
.CW
.TA .1i
	int *(*@c[3])(int);
.DE
declares
.CW c
to be an array of three channels for sending/receiving
pointers to functions that take an int and return
a pointer to an int.
.NH 2
Channel Allocation
.LP
Once a channel is declared, it must be configured for
use by applying the compiler extension
.CW chanset
to it. The usage is
.DS
.CW
.TA .1i
	int @c;
	chanset(c, nelem);
.DE
Where
.CW nelem
is an int that sets the number of values the channel can
hold and whether the channel is buffered or unbuffered.
See
.CW chancreate
in
.I thread (2).
.NH 2
Channel Operations
.LP
The compiler extension allows for sending into and receiving
typed values from channels. The syntax for receiving
a channel mimics that of channel declarations. That is,
for a channel for sending ints and an int as follows:
.DS
.CW
.TA .1i
	int @c, i;
.DE
the statement
.DS
.CW
.TA .1i
	i = @c;
.DE
receives an int from the channel
.CW c
and assigns the value to
.CW i.
More specifically, the expression
.CW @c
evaluates to the value retrieved from the channel via
a call into the
.I thread (2)
library.
.LP
A new binary operator
.CW @=
is used to send into a channel.
The left-hand side of the expression must be a channel
and the right-hand
side's type must match the type of the sending value of
the channel. Thus given
.DS
.CW
.TA .1i
	char *@c;
.DE
the statement
.DS
.CW
.TA .1i
	c @= "hello, world";
.DE
sends the string into the channel. The expression
.CW
c @= val
.R
evaluates to an int: 1 on success and -1 if the send
was interrupted.
.NH 2
Sending/Receiving of Multiple Channels
.LP
Channel sending/receiving may be multiplexed on a
single statement using a new control flow statement called
the alt-switch. It is similar
to a switch with the expression value replaced by an
.CW @
character and the
.CW case
keywords replaced by a new extension keyword
.CW alt .
Instead of constant expressions, each
.CW alt
is labeled by potential channel sends or receives. An optional
default label handles the case where the underlying
.CW doalt
operation (see
.I thread (2))
is interrupted.
.DS
.CW
.TA .1i .6i 1.1i
	int @ichan, @req, i;
	char *@schan, *s;

	s = "hello";
	switch @{
	alt i = @ichan:
		print("%d\en", i);
		...
		break;
	alt @req:
		...
		break;
	alt schan @= s:
		print("Sent hello\en");
		...
		break;
	default:
		print("Interrupted!\en");
	}
.DE
.LP
In the example above three potential channel operations
are multiplexed on one alt-switch statement. Either an int is received from
.CW @ichan
and assigned to
.CW i ,
an int is received from
.CW @req
and its value thrown away, or the string
.CW hello
is sent into
.CW schan .
The operations are multiplexed in the sense that
if at least one of those channel operations
can proceed, one is chosen at random to be executed and
control flow proceeds after the corresponding
.CW alt
label. Otherwise the alt-switch statement blocks until
one of the operations can proceed.
.LP
A non-blocking alt-switch statement is specified by using
two
.CW @
symbols:
.DS
.CW
.TA .1i .6i 1.1i
	switch @@{
		...
	default:
		print("No channel operations can proceed.\en");
	}
.DE
.LP
In this case, the statement does not block if no channel
operations can proceed, but immediately continues execution
at the default label. If a non-blocking alt-switch is interrupted
while in the middle of executing a valid channel operation,
then the alt-switch will continue execution at a
.CW case
labeled by
.CW -1 .
.LP
The channel send operation in an
.CW alt
label is more restricted than an ordinary channel
send in the sense that the right
hand side of the
.CW @=
binary operator must be addressable. Thus
.DS
.CW
.TA .1i
	alt ichan @= 5:
.DE
will not compile.
.NH
Summary of the Extension
.LP
In total the extension reserves the following new keywords
or symbols
.TS
center;
cfCW cfCW cfCW cfCW cfCW.
@ alt	chanset	cothread	coproc
.TE
and defines the following new expressions:
.TS
center box;
cB s
cB s
cfCW | l
cfCW | l
cfCW | l
cB s
cfCW | l
cfCW | l
cfCW | l
cfCW | l
cfCW | l
cB s
cfCW | l.
.sp .2
Usage Summary
.sp .2
=
.sp .2
Channel Operations
.sp .2
_
.sp .2
chanset(chan, nelem)	Allocates and readies a channel
.sp .2
_
.sp .2
chan @= val	Channel Send
.sp .2
_
.sp .2
@chan	Channel dereference (receive)
.sp .2
_
.sp .2
Alt-Switch
.sp .2
_
.sp .2
switch @{...}	Blocking alt-switch
.sp .2
_
.sp .2
switch @@{...}	Non-blocking alt-switch
.sp .2
_
.sp .2
alt val = @chan:	Alt label (receive)
.sp .2
_
.sp .2
alt @chan:	Alt label (receive, value thrown away)
.sp .2
_
.sp .2
alt chan @= val:	Alt label (send)
.sp .2
_
.sp .2
Thread Creation
.sp .2
_
.sp .2
coproc(fn(...), stksize)	Starts a process in its own stack
.sp .2
_
.sp .2
cothread(fn(...), stksize)	Starts a thread in its own stack
.TE
.LP
.ps 8
.vs 10
Figure 1.  Summary of compiler extensions and usage.
.CW chan
denotes a typed channel and
.CW val
is of the channel's sending type.
.CW nelem
is an int,
.CW fn
is a function of any signature, and
.CW stksize
is an unsigned int.
.sp
.NH
Implementation Details
.LP
The extension does two things: checks types and provides
syntactic sugar for calls to
.CW thread (2).
.LP
Threads and processes are created by walking the argument
list to find the number of arguments to the function and
then compiling a call to
.CW rtthreadcreate
in
.I thread (2).
For example, given a call
.DS
.CW
.TA .1i
	cothread(fn(a, b, c), 1024);
.DE
the compiler first checks the types of the arguments to the
function
.CW fn
and then rewrites the above as
.DS
.CW
.TA .1i
	rtthreadcreate(1024, 3, fn, a, b, c);
.DE
The library
.I thread (2)
takes things from there. A call of
.CW coproc
is rewritten as a call to
.CW rtproccreate
in the exact same way.
.LP
Each channel declaration declares a new structure
that holds both the channel and locations for sending
and receiving values of the sending type of the channel.
The channel itself is declared as a pointer to that
struct. Thus, a channel declaration such as
.DS
.CW
.TA .1i
	int @c;
.DE
is rewritten by the compiler as
.DS
.CW
.TA .1i .6i
	struct {
		Channel;
		int @in;
		int @out;
	} *chan;
.DE
In this rewrite the symbols
.CW @in " "
and
.CW @out " "
are not channels but the actual identifier used internally
by the compiler to access those members of the structure.
They are only accessible within the compiler since
.CW @
is reserved.
.LP
A more complicated type such as
.DS
.CW
.TA .1i
	int (*@*chan[3])(int, double);
.DE
(an array of three pointers to a channel that returns
pointers to function pointers), becomes
.DS
.CW
.TA .1i .6i
	struct {
		Channel;
		int (*@in)(int, double);
		int (*@out)(int, double);
	} **chan[3];
.DE
In other words, if you read the declaration from the
outer type inwards toward the symbol, then everything
before the
.CW @
symbol is associated with the sending type of the channel
and everything after is associated with the declaration
of the the symbol
.CW chan
itself.
.LP
The call
.DS
.CW
.TA .1i
	chanset(chan, nelem);
.DE
allocates memory for the
channel and does further setup as needed for
.I thread (2).
It is syntactic sugar for the call
.DS C
.CW
chan = rtchancreate(sizeof(*chan), sizeof(chan->@in), nelem);
.DE
where
.CW chan
has already been defined by the compiler to have a  structure
type like the examples above.
.LP
A channel receive operation
.CW
val = @chan
.R
is rewritten as
.DS
.CW
.TA .1i
	recv(c, c->@out);
	val = c->@out;
.DE
and in the case when there is no left hand side, then as
.DS
.CW
.TA .1i
	recv(c, c->@out);
.DE
alone.
A channel send expression
.DS
.CW
.TA .1i
	c @= val;
.DE
is first type checked so that val is assignable to
.CW c->@in
and then rewritten as
.DS
.CW
.TA .1i
	send(c, &val);
.DE
In the case where
.CW val
is not addressable, such as
.DS
.CW
.TA .1i
	c @= val1 + val2;
.DE
then the compiler rewrites this as
.DS
.CW
.TA .1i
	c->@in = val1 + val2;
	recv(c, &c->@in);
.DE
.LP
The alt-switch statement is compiled by constructing an
.CW Alt
structure (see
.I thread (2))
and then rewriting the alt-switch as a normal switch with
case labels corresponding to the value returned by a
.CW doalt
call (see
.I thread(2))
with the
.CW Alt
structure as an argument.
The example
.DS
.CW
.TA .1i .6i 1.1i
	int @ichan, @req, i;
	char *@schan, *s;

	s = "hello";
	switch @{
	alt i = @ichan:
		print("%d\en", i);
		...
		break;
	alt @req:
		...
		break;
	alt schan @= s:
		print("Sent hello\en");
		...
		break;
	default:
		print("Interrupted!\en");
	}
.DE
is rewritten as
.DS
.CW
.TA .1i .6i 1.1i
	int @ichan, @req, i;
	char *@schan, *s;

	s = "hello";

	struct Alt alts[] = {
		{ichan, &i, CHANRCV},
		{req, nil, CHANRCV},
		{schan, &s, CHANSND},
		{nil, nil, CHANEND}
	};
	switch(doalt(alts)) {
	case 0:
		print("%d\en", i);
		...
		break;
	case 1:
		...
		break;
	case 2:
		print("Sent hello\en");
		...
		break;
	default:
		print("Interrupted!\en");
	}
.DE
The appropriate type checking takes place on the values
being sent or received in order to preserve type safety.
