.TL
The Plan 9 Front Concurrent C Extensions
.AU
Benjamin Purcell (spew)
benjapurcell@gmail.com
.AB
The Plan 9 Front compilers extend the C programming language
to provide built-in CSP style concurrency operations.
This paper describes the usage and implementation of the
extension.
.AE
.NH
Introduction and Motivation
.LP
CSP-style concurrency operations are an essential part
of many programs in the Plan 9 operating system. Concurrent
programs were originally written in Alef which had built-in
concurrency operations. When Alef was retired, a library
was written to allow access to CSP operations from programs
written in C (see
.I thread (2)).
However, there are a number of deficiencies with
.I thread (2);
thread creation is inflexible, receiving or sending of
multiple channels requires an awkward definition of an array
of structures, and the send/receive operations
are not type-safe. The extension aims to address those
concerns to make threaded programs easier and safer to
write without the need to maintain a separate compililer
infrastructure such as Alef. This document assumes
familiarity with
.I thread (2).
.NH
The Extensions
.LP
The compiler extension provides for launching
new threads and processes, declaring and allocating storage
for typed channels, and type-safe sending and receiving from
channels. It also provides a new control structure
for type-safe sending or receiving of multiple channels.
.NH 2
Thread and Process Creation
.LP
Threads and processes are created using the keywords
.CW coproc
and
.CW cothread
which has the syntax of a function that takes
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
.ta .1i
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
the calls to
.CW cothread
and
.CW coproc
tell the compiler to check the arguments to the function
and then compile a call to thread to start the function
in a new thread or process with a memory allocated stack
(see
.I malloc (2)).
Thus, if
.CW a ,
.CW b ,
and
.CW c ,
are of an incompatible type to
.CW int ,
.CW double ,
and
.CW char*
respectively, then the above will not compile.
.NH 2
Channel Declarations
.LP
The extension reserves the character
.CW @
for declarations of typed Channels. A typed channel
has a type associated with it; only values of that
type may be sent or received from the channel. The
.CW @
symbol has the same precedence as the pointer de-reference
.CW *
and functions similarly. Thus
.DS
.CW
.ta .1i
	int @c;
.DE
declares c to be a channel for sending/receiving an int;
.DS
.CW
.ta .1i
	char *@c;
.DE
declares c to be a channel for sending/receiving a pointer to
a char; and
.DS
.CW
.ta .1i
	int *(*@c[3])(int);
.DE
declares c to be an array of three channels for sending/receiving
pointers to functions that take an int and return
a pointer to an int.
.LP
The
.CW @
symbol can be viewed as a special kind of de-reference.
It represents the value in the channel.
.NH 2
Channel Allocation
.LP
Once a channel is declared, it must be configured for
use by applying the compiler extension
.CW chanset
to the channel. The usage is
.DS
.CW
.ta .1i
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
The compiler extensions allows for sending into and receiving
typed values from channels. The syntax for receiving
a channel mimics that of channel declarations. That is,
for a channel for sending ints and an int as follows:
.DS
.CW
.ta .1i
	int @c, i;
.DE
the statement
.DS
.CW
.ta .1i
	i = @c;
.DE
receives an int from the channel
.CW c
and assigns the value to
.CW i.
This can be thought of as a kind of de-reference that first
calls into the
.I thread (2)
library in order to retrieve have the value available in
the channel.
