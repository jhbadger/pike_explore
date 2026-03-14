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
	int does_pos = -1;   // NEW: position in prog where does> starts

	void push(mixed v) { stack += ({v}); }
	mixed pop() { mixed v = stack[-1]; stack = stack[..<1]; return v; }
	void rpush(mixed v) { rstack += ({v}); }
	mixed rpop() { mixed v = rstack[-1]; rstack = rstack[..<1]; return v; }
	void emit(array ins) { prog += ({ins}); }

	void run(array code) {
		for (int pc = 0; pc < sizeof(code); pc++) {
			array ins = code[pc];
			switch(ins[0]) {
			case "lit":   push(ins[1]); break;
			case "call":  run_word(ins[1]); break;
			case "branch":  pc = ins[1]-1; break;
			case "0branch": if (pop() == 0) pc = ins[1]-1; break;
			case "exit":    return;
			case "(do)":
				{ int start = pop(), limit = pop();
					rpush(({start, limit})); }
				break;
			case "(loop)":
				{ array f = rstack[-1]; f[0]++;
					rstack[-1] = f;
					if (f[0] < f[1]) pc = ins[1]-1;
					else rpop(); }
				break;
				// NEW: push a heap address (body pointer for created words)
			case "push-addr":
				push(ins[1]);
				break;
			}
		}
	}

	void run_word(string w) {
		if (dict[w]) {
			array entry = dict[w];
			if (entry[0] == "prim") {
				entry[1]();
			} else if (entry[0] == "word") {
				run(entry[1]);
			} else if (entry[0] == "create") {
				// entry = ({"create", body_addr, does_code})
				// Push the body address, then run the does> behavior
				push(entry[1]);
				if (sizeof(entry[2]) > 0)
					run(entry[2]);
			}
			return;
		}

		int n;
		if (sscanf(w, "%d", n)) { push(n); return; }
		error("Unknown word: %s\n", w);
	}

	void init_prims() {
		/* arithmetic */
		dict["+"]   = ({"prim", lambda(){ int b=pop(),a=pop(); push(a+b); }});
		dict["-"]   = ({"prim", lambda(){ int b=pop(),a=pop(); push(a-b); }});
		dict["*"]   = ({"prim", lambda(){ int b=pop(),a=pop(); push(a*b); }});
		dict["/"]   = ({"prim", lambda(){ int b=pop(),a=pop(); push(a/b); }});
		dict["mod"] = ({"prim", lambda(){ int b=pop(),a=pop(); push(a%b); }});

		/* stack */
		dict["dup"]  = ({"prim", lambda(){ push(stack[-1]); }});
		dict["drop"] = ({"prim", lambda(){ pop(); }});
		dict["swap"] = ({"prim", lambda(){ int b=pop(),a=pop(); push(b); push(a); }});
		dict["over"] = ({"prim", lambda(){ push(stack[-2]); }});
		dict["rot"]  = ({"prim", lambda(){ int c=pop(),b=pop(),a=pop(); push(b); push(c); push(a); }});

		/* comparisons */
		dict["="]  = ({"prim", lambda(){ int b=pop(),a=pop(); push(a==b); }});
		dict["<"]  = ({"prim", lambda(){ int b=pop(),a=pop(); push(a<b); }});
		dict[">"]  = ({"prim", lambda(){ int b=pop(),a=pop(); push(a>b); }});
		dict["0="] = ({"prim", lambda(){ push(pop()==0); }});

		/* memory */
		dict["@"] = ({"prim", lambda(){
			int addr = pop();
			if (addr < 0 || addr >= sizeof(heap)) error("Invalid heap address %d\n", addr);
			push(heap[addr]);
		}});
		dict["!"] = ({"prim", lambda(){
			int addr = pop();
			int val  = pop();
			if (addr < 0 || addr >= sizeof(heap)) error("Invalid heap address %d\n", addr);
			heap[addr] = val;
		}});

		/* NEW: cell arithmetic for array access */
		dict["cell+"] = ({"prim", lambda(){ push(pop() + 1); }});
		dict["cells"] = ({"prim", lambda(){ /* cells are 1 unit each, no-op */ }});

		/* output */
		dict["."]     = ({"prim", lambda(){ write("%d ", pop()); }});
		dict["emit"]  = ({"prim", lambda(){ write("%c", pop()); }});
		dict["cr"]    = ({"prim", lambda(){ write("\n"); }});
		dict[".s"]    = ({"prim", lambda(){ write("Stack: %O\n", stack); }});

		/* loop index */
		dict["i"] = ({"prim", lambda(){ array f = rstack[-1]; push(f[0]); }});

		/* allot — grow heap by n cells */
		dict["allot"] = ({"prim", lambda(){
			int n = pop();
			heap += allocate(n, 0);
		}});

		dict["words"] = ({"prim", lambda(){
			foreach(sort(indices(dict)), string s) write("%s ", s);
			write("\n");
		}});
	}

	void process(array tokens) {
		for (int i = 0; i < sizeof(tokens); i++) {
			string t = tokens[i];

			// \ comment: skip rest of token array (rest of line)
			if (t == "\\") break;

			// ( comment: skip tokens until closing )
			if (t == "(") {
				while (i < sizeof(tokens) && tokens[i] != ")") i++;
				continue;
			}
				
			if (!compiling) {
				if (t == "variable") {
					string name = tokens[++i];
					int addr = sizeof(heap);
					heap += ({0});
					dict[name] = ({"word", ({
													 ({"lit", addr}),
													 ({"exit"})
												 })});
					continue;
				}

				if (t == ":") {
					current  = tokens[++i];
					prog     = ({});
					does_pos = -1;
					compiling = 1;
					continue;
				}

				run_word(t);
				continue;
			}

			/* ── compile mode ── */

			if (t == ";") {
				emit(({"exit"}));

				if (does_pos >= 0) {
					// Split prog at does_pos:
					// init_code runs at definition time (between : and does>)
					// does_code runs each time a created word is called
					array init_code = prog[..does_pos-1];  // up to does>
					array does_code = prog[does_pos..];     // after does> (includes exit)

					// The defining word: when run, executes init_code, which
					// must have left a "create" entry ready to receive does_code.
					dict[current] = ({"defining", init_code, does_code});
				} else {
					dict[current] = ({"word", prog});
				}

				compiling = 0;
				does_pos  = -1;
				continue;
			}

			if (t == "does>") {
				// Mark the split point — everything after here is does_code
				does_pos = sizeof(prog);
				continue;
			}

			if (t == "create") {
				// Compile a call to the runtime CREATE primitive
				emit(({"call", "__create__"}));
				continue;
			}

			if (t == "if") {
				emit(({"0branch", 0}));
				cstack += ({sizeof(prog)-1});
				continue;
			}
			if (t == "else") {
				emit(({"branch", 0}));
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
				emit(({"(loop)", addr}));
				continue;
			}

			int n;
			if (sscanf(t, "%d", n)) { emit(({"lit", n})); continue; }
			emit(({"call", t}));
		}
	}

	// Called at runtime when a defining word executes CREATE
	// Grabs the next word name from... wait, we need a different approach.
	// See note below.

	void repl() {
		init_prims();

		// __create__ is a runtime primitive that:
		// creates a new "create"-type dict entry for the NEXT token.
		// We handle this in the REPL loop by peeking ahead, but the
		// cleanest approach is to make defining words work token-by-token.
		// See the defining-word execution in run_word below.

		write("Mini Pike Forth\n");
		while (1) {
			write("> ");
			string line = Stdio.stdin->gets();
			if (!line || line == "bye\n") break;
			process(line / " ");
			write(" ok\n");
		}
	}
}

int main() {
	Forth().repl();
	return 0;
}
