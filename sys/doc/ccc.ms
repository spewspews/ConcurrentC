.TL
The Plan 9 Front Concurrent C Extensions
.AU
Benjamin Purcell (spew)
benjapurcell@gmail.com
.AB
The Plan 9 Front compilers extend the C programming language
to allow for built-in CSP style concurrency operations.
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
.I libthread (2)).
However, there are a number of deficiencies with
.I libthread (2):
thread creation is awkward, receiving or sending of
multiple channels requires a large temporary structure
definition, and the send/receive operations
are not type-safe. The extension aims to address those
concerns to make threaded programs easier and safer to
write without the need to maintain a separate compiler
infrastructure such as Alef. This document assumes
familiarity with
.I libthread (2).
.NH
The Extensions
.LP
The compiler extension provides capabilities for launching
new threads and processes, declaring and allocating storage
for typed channels, and type-safe sending and receiving from
channels. It also provides a new control structure that allows
for type-safe sending or receiving of multiple channels.
.NH 2
Thread and Process Creation
.LP
Threads and processes are created using the keywords
.CW coproc
and
.CW cothread
which have a syntax similar to a function that takes
two arguments. The first argument must be a function
application, and the second is an int that specifies
stack size to use to create the process or
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
and then compile a call to libthread to start the function
in a new thread
or process with a memory allocated stack (see
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
for declarations of Channels.
