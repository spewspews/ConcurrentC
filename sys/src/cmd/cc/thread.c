#include "gc.h"

int
countargs(Node *n)
{
	Node *l;
	int i;

	for(i = 0; n != Z; n = n->right) {
		if(n->op == OLIST)
			l = n->left;
		else
			l = n;
		if(l->type == T)
			return 0;

		i += (l->type->width - 1)/SZ_IND + 1;
	}
	return i;
}

static
Node*
symnod(Sym *s)
{
	Node *n;

	n = new1(ONAME, Z, Z);
	n->sym = s;
	n->type = s->type;
	if(s->type != T)
		n->etype = s->type->etype;
	n->xoffset = s->offset;
	n->class = s->class;
	return n;
}

Node*
thrdnod(int o, Node *fn, Node *stk)
{
	Node *n, *args, *c;
	Sym *s;
	int argc;

	if(fn->op != OFUNC) {
		diag(fn, "Not a function application for op %O", o);
		return Z;
	}

	n = copynod(fn);
	tcom(n);

	argc = countargs(n->right);
	if(argc == 0) {
		args = new(OCONST, Z, Z);
		args->type = types[TINT];
		args->vconst = 0;
	} else
		args = fn->right;

	c = new(OCONST, Z, Z);
	c->type = types[TINT];
	c->vconst = argc;

	switch(o){
	case OCOTHREAD:
		s = slookup("rtthreadcreate");
		break;
	case OCOPROC:
		s = slookup("rtproccreate");
		break;
	default:
		diag(Z, "No such CSP op");
		return nil;
	}
	if(s->type == T){
		diag(Z, "no include of <thread.h>");
		return nil;
	}

	n = new(OLIST, fn->left, args);
	n = new(OLIST, c, n);
	n = new(OLIST, stk, n);
	return new(OFUNC, symnod(s), n);
}

Node*
chanalloc(Node *c, Node *elems)
{
	Sym *s;
	Node *n;

	s = slookup("rtchancreate");
	if(s->type == T)
		fatal(Z, "No include of <thread.h> for CHANSET");

	n = new(OLIST, new(OSIZE, chanval(copynod(c), ORECV), Z), elems);
	n = new(OLIST, new(OSIZE, new(OIND, copynod(c), Z), Z), n);
	n = new(OFUNC, symnod(s), n);
	return new(OAS, c, n);
}

Node*
chanval(Node *n, int op)
{
	n = new1(ODOT, new(OIND, n, Z), Z);
	if(op == OSEND)
		n->sym = slookup("@in");
	else
		n->sym = slookup("@out");;
	return n;
}

Node*
chanop(int op, Node *n)
{
	Sym *s;

	switch(op){
	case ORECV:
		s = slookup("recv");
		break;
	case OSEND:
		s = slookup("send");
		break;
	default:
		fatal(Z, "No valid channel op.");
		return Z;
	}

	if(s->type == T) {
		diag(Z, "No include of <thread.h>");
		return Z;
	}

	n = new1(OLIST, copynod(n), new1(OADDR, chanval(n, op), Z));
	return new1(OFUNC, symnod(s), n);

}

Node*
chanopaddr(int op, Node *n, Node *v)
{
	Sym *s;

	switch(op){
	case ORECV:
		s = slookup("recv");
		break;
	case OSEND:
		s = slookup("send");
		break;
	default:
		fatal(Z, "No valid channel op.");
		return Z;
	}

	if(s->type == T) {
		diag(Z, "No include of <thread.h>");
		return Z;
	}

	n = new(OLIST, n, new(OADDR, v, Z));
	return new(OFUNC, symnod(s), n);
}
	
static int nalt;

static
void
altcase(Node *n, Node **i)
{
	Node *n1;
	Sym *s;

	switch(n->op) {
	case OALTRECV:
		s = slookup("CHANRCV");
		break;
	case OALTSEND:
		s = slookup("CHANSND");
		break;
	default:
		return;
	}
	if(s->tenum == T) {
		diag(n, "No include of <thread.h> for alt");
		return;
	}

	n1 = symnod(s);
	if(n->left != Z)
		n1 = new(OLIST, new(OADDR, n->left, Z), n1);
	else {
		n1 = new(OLIST, new(OCONST, Z, Z), n1);
		n1->left->vconst = 0;
		n1->left->type = types[TINT];
	}
	n1 = new(OLIST, n->right, n1);

	n1 = new(OINIT, n1, Z);

	if(*i == nil)
		*i = n1;
	else
		*i = new(OLIST, *i, n1);


	n->op = OCASE;
	n1 = new(OCONST, Z, Z);
	n1->type = types[TINT];
	n1->vconst = nalt++;
	n->left = n1;
	n->right = Z;
}
	
Node*
altcases(Node *n, Node **i)
{
	for(; n != nil; n = n->right) {
		if(n->op == OLIST)
			altcases(n->left, i);
		else
			altcase(n, i);
	}

	return *i;
}

Node*
procalts(Node *n, int nb)
{
	Node *n1, *i;
	Sym *s;
	long w;

	if(nb)
		s = slookup("CHANNOBLK");
	else
		s = slookup("CHANEND");
	if(s->tenum == T) {
		diag(Z, "No include of <thread.h>");
		return nil;
	}

	n1 = symnod(s);

	n1 = new(OLIST, new(OCONST, Z, Z), n1);
	n1->left->type = types[TINT];
	n1->left->vconst = 0;

	n1 = new(OLIST, new(OCONST, Z, Z), n1);
	n1->left->type = types[TINT];
	n1->left->vconst = 0;

	n1 = new(OINIT, n1, Z);

	nalt = 0;
	i = Z;
	n1 = invert(new(OLIST, altcases(n, &i), n1));
	n1 = new(OINIT, n1, Z);

	n = newalt();

	w = n->sym->type->width;
	n1 = doinit(n->sym, n->type, 0L, n1);
	lastalt = contig(n->sym, n1, w);

	s = slookup("doalt");
	if(s->type == T)
		fatal(Z, "no include of <thread.h> for definition of doalt()");

	n1 = symnod(s);

	n->xoffset =n->sym->offset;
	n->sym->aused = 1;
	return new(OFUNC, n1, n);
}

static int altcount;

Node*
newalt(void)
{
	Node *n;
	Sym *s;
	Type *t;
	char buf[1024];

	s = slookup("Alt");
	if(s->type == T)
		fatal(Z, "no include of <thread.h> for definition of Alt");
	t = s->type;

	sprint(buf, "@lt_%d_", altcount++);
	s = slookup(buf);
	if(s->type != T)
		fatal(Z, "alt already defined.");

	n = symnod(s);
	
	n = new(OARRAY, n, Z);

	return dodecl(adecl, CXXX, t, n);
}

Type*
chansbody(Type *t)
{
	Type *t1, *ostrf, *ostrl;
	Sym *s;

	ostrf = strf;
	ostrl = strl;

	strf = T;
	strl = T;
	lastbit = 0;
	firstbit = 1;

	s = slookup("Channel");
	if(s->type == T)
		diag(Z, "no include of <thread.h> for definition of Channel");
	edecl(CXXX, s->type, S);

	dodecl(edecl, CXXX, t, symnod(slookup("@in")));
	dodecl(edecl, CXXX, t, symnod(slookup("@out")));

	t1 = strf;

	strf = ostrf;
	strl = ostrl;

	return t1;
}
