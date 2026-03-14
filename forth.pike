#!/usr/bin/env pike

class Forth {

	array stack = ({});
	array rstack = ({});
	array heap = ({});
	mapping dict = ([]);

	int compiling = 0;
	string current;
	array prog = ({});
	array cstack = ({});

	void push(mixed v) { stack += ({v}); }
	mixed pop() { mixed v = stack[-1]; stack = stack[..<1]; return v; }

	void rpush(mixed v) { rstack += ({v}); }
	mixed rpop() { mixed v = rstack[-1]; rstack = rstack[..<1]; return v; }

	void emit(array ins) { prog += ({ins}); }

	void run(array code) {
		for (int pc = 0; pc < sizeof(code); pc++) {
			array ins = code[pc];
			switch(ins[0]) {
			case "lit":
				push(ins[1]);
				break;
			case "call":
				run_word(ins[1]);
				break;
			case "branch":
				pc = ins[1]-1;
				break;
			case "0branch":
				if (pop() == 0) pc = ins[1]-1;
				break;
			case "exit":
				return;
			case "(do)":
				{
					int start = pop();
					int limit = pop();
					rpush(({start, limit})); // correct order: start, limit
				}
				break;
			case "(loop)":
				{
					array f = rstack[-1];   // copy frame
					f[0]++;                  // increment index
					rstack[-1] = f;          // write it back
					if (f[0] < f[1])
						pc = ins[1]-1;
					else
						rpop();
				}
				break;
			}
		}
	}

	void run_word(string w) {
		if (dict[w]) {
			array entry = dict[w];
			if (entry[0] == "prim")
				entry[1]();
			else
				run(entry[1]);
			return;
		}

		int n;
		if (sscanf(w,"%d",n)) {
			push(n);
			return;
		}

		error("Unknown word: %s\n", w);
	}

	void init_prims() {
		/* arithmetic */
		dict["+"] = ({ "prim", lambda(){ int b=pop(),a=pop(); push(a+b);} });
		dict["-"] = ({ "prim", lambda(){ int b=pop(),a=pop(); push(a-b);} });
		dict["*"] = ({ "prim", lambda(){ int b=pop(),a=pop(); push(a*b);} });
		dict["/"] = ({ "prim", lambda(){ int b=pop(),a=pop(); push(a/b);} });
		dict["mod"] = ({ "prim", lambda(){ int b=pop(),a=pop(); push(a%b); }});

		/* stack */
		dict["dup"] = ({ "prim", lambda(){ push(stack[-1]); } });
		dict["drop"] = ({ "prim", lambda(){ pop(); } });
		dict["swap"] = ({ "prim", lambda(){ int b=pop(),a=pop(); push(b); push(a); } });
		dict["over"] = ({ "prim", lambda(){ push(stack[-2]); } });
		dict["rot"] = ({ "prim", lambda(){ int c=pop(),b=pop(),a=pop(); push(b); push(c); push(a); } });

		/* comparisons */
		dict["="] = ({ "prim", lambda(){ int b=pop(),a=pop(); push(a==b); } });
		dict["<"] = ({ "prim", lambda(){ int b=pop(),a=pop(); push(a<b); } });
		dict[">"] = ({ "prim", lambda(){ int b=pop(),a=pop(); push(a>b); } });
		dict["0="] = ({ "prim", lambda(){ push(pop()==0); } });

		/* memory */
		dict["@"] = ({ "prim", lambda(){
			int addr = pop();
			if (addr >= sizeof(heap) || addr < 0) 
				error("Invalid heap address %d\n", addr);
			push(heap[addr]);
		}});
		dict["!"] = ({ "prim", lambda(){
			int addr = pop();
			int val = pop();
			if (addr >= sizeof(heap) || addr < 0) 
				error("Invalid heap address %d\n", addr);
			heap[addr] = val;
		}});

		/* output */
		dict["."] = ({ "prim", lambda(){ write("%d ", pop()); } });
		dict["emit"] = ({ "prim", lambda(){ write("%c", pop()); } });
		dict["cr"] = ({ "prim", lambda(){ write("\n"); } });
		dict[".s"] = ({ "prim", lambda(){ write("Stack: %O\n", stack); } });

		/* loop index */
		dict["i"] = ({ "prim", lambda(){ array f = rstack[-1]; push(f[0]); } });

		/* dictionary listing */
		dict["words"] = ({ "prim", lambda(){
			array w = sort(indices(dict));
			foreach(w,string s) write("%s ", s);
			write("\n");
		}});
	}

	void process(array tokens) {
		for (int i=0;i<sizeof(tokens);i++) {
			string t = tokens[i];

			if (!compiling) {
				if (t == "variable") {
					string name = tokens[++i];
					int addr = sizeof(heap); // next free slot
					heap += ({0});           // initialize memory
					dict[name] = ({ "word", ({
														({ "lit", addr }),
														({ "exit" })
													})});
					continue;
				}

				if (t == ":") {
					current = tokens[++i];
					prog = ({});
					compiling = 1;
					continue;
				}

				run_word(t);
				continue;
			}

			/* compile mode */
			if (t == ";") {
				emit(({"exit"}));
				dict[current] = ({ "word", prog });
				compiling = 0;
				continue;
			}

			if (t == "if") {
				emit(({"0branch",0}));
				cstack += ({sizeof(prog)-1});
				continue;
			}

			if (t == "else") {
				emit(({"branch",0}));
				int prev = cstack[-1];
				cstack = cstack[..<1];
				prog[prev][1] = sizeof(prog);
				cstack += ({sizeof(prog)-1});
				continue;
			}

			if (t == "then") {
				int prev = cstack[-1];
				cstack = cstack[..<1];
				prog[prev][1] = sizeof(prog);
				continue;
			}

			if (t == "do") {
				emit(({"(do)"}));
				cstack += ({sizeof(prog)});
				continue;
			}

			if (t == "loop") {
				int addr = cstack[-1];
				cstack = cstack[..<1];
				emit(({"(loop)",addr}));
				continue;
			}

			int n;
			if (sscanf(t,"%d",n)) {
				emit(({"lit",n}));
				continue;
			}

			emit(({"call",t}));
		}
	}

	void repl() {
		init_prims();
		write("Mini Pike Forth\n");
		while(1) {
			write("> ");
			string line = Stdio.stdin->gets();
			if (!line || line=="bye\n") break;
			process(line/" ");
			write(" ok\n");
		}
	}
}

int main() {
	Forth()->repl();
}
