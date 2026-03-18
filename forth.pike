#!/usr/bin/env pike
class Forth {

	array stack = ({});
	array rstack = ({});
	array locals = ({});
	mapping dict = ([]);

	int compiling = 0;
	string current;
	array prog = ({});
	array cstack = ({});
	int does_pos = -1;   

	// allocate base on the heap
	int base_addr = 0;
	array heap = ({10});  // default decimal

	mixed pop() {
    if (sizeof(stack) == 0) error("Stack underflow\n");
    mixed v = stack[-1];
    stack = stack[..<1];
    return v;
	}

	mixed rpop() {
    if (sizeof(rstack) == 0) error("Return stack underflow\n");
    mixed v = rstack[-1];
    rstack = rstack[..<1];
    return v;
	}
	void push(mixed v) { stack += ({v}); }
	void rpush(mixed v) { rstack += ({v}); }
	void emit(array ins) { prog += ({ins}); }

	string format_int(int n, int b) {
    if (n == 0) return "0";
    string digits = "0123456789abcdef";
    string result = "";
    int neg = n < 0;
    if (neg) n = -n;
    while (n > 0) { result = digits[n % b .. n % b] + result; n /= b; }
    return neg ? "-" + result : result;
	}

	array try_parse_number(string t) {
    int b = heap[base_addr];
    int neg = (sizeof(t) > 0 && t[0] == '-');
    string s = neg ? t[1..] : t;
    if (sizeof(s) == 0) return ({0, 0});
    int n = 0;
    foreach(s / "", string c) {
			int d = search("0123456789abcdef", lower_case(c));
			if (d < 0 || d >= b) return ({0, 0});
			n = n * b + d;
    }
    return ({1, neg ? -n : n});
	}
	
	void run(array code) {
		for (int pc = 0; pc < sizeof(code); pc++) {
			array ins = code[pc];
			switch(ins[0]) {
			case "lit":   push(ins[1]); break;
			case "strlit": write(ins[1]); break;
			case "call":  run_word(ins[1]); break;
			case "branch":  pc = ins[1]-1; break;
			case "0branch": if (pop() == 0) pc = ins[1]-1; break;
			case "exit":    return;
			case "local@":
				// ins[1] is the frame offset from top of rstack locals frame
				push(rstack[-1][ins[1]]);
				break;
			case "local!":
				rstack[-1][ins[1]] = pop();
				break;
			case "locals-enter":
				// ins[1] is number of locals -- push a frame of that size
				rpush(allocate(ins[1], 0));
				break;
			case "locals-exit":
				rpop();
				break;
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
			case "push-addr":
				push(ins[1]);
				break;
			}
		}
	}

	void run_word(string w) {
		w = lower_case(w);
    if (dict[w]) {
			array entry = dict[w];
			if (entry[0] == "prim") {
				entry[1]();
			} else if (entry[0] == "word") {
				run(entry[1]);
			} else if (entry[0] == "create") {
				// push body address, then run does> code
				push(entry[1]);
				if (sizeof(entry[2]) > 0)
					run(entry[2]);
			}
			// "defining" entries are only invoked via process(), not run_word()
			return;
    }
		array parsed = try_parse_number(w);
		if (parsed[0]) { push(parsed[1]); return; }
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
		dict[">r"] = ({"prim", lambda(){ rpush(pop()); }});
		dict["r>"] = ({"prim", lambda(){ push(rpop()); }});
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

		/* bases */
		dict["base"] = ({"prim", lambda(){ push(base_addr); }});
		dict["hex"]     = ({"prim", lambda(){ heap[base_addr] = 16; }});
		dict["decimal"] = ({"prim", lambda(){ heap[base_addr] = 10; }});
		dict["octal"]   = ({"prim", lambda(){ heap[base_addr] = 8;  }});
		dict["binary"]  = ({"prim", lambda(){ heap[base_addr] = 2;  }});

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

		dict["cell+"] = ({"prim", lambda(){ push(pop() + 1); }});
		dict["cells"] = ({"prim", lambda(){ /* cells are 1 unit each, no-op */ }});
		dict[","]    = ({"prim", lambda(){ heap += ({pop()}); }});
		dict["here"] = ({"prim", lambda(){ push(sizeof(heap)); }});
		dict["c,"]   = ({"prim", lambda(){ heap += ({pop()}); }});  // same as , in a cell-based forth
		
		/* output */
		dict["."]     = dict["."] = ({"prim", lambda(){
			write("%s ", format_int(pop(), heap[base_addr])); }});
		
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

	array(string|int) collect_string(array tokens, int i) {
    string result = "";
    while (i + 1 < sizeof(tokens)) {
			i++;
			if (tokens[i][-1] == '"') {
				result += tokens[i][..<1];
				return ({result, i});
			}
			result += tokens[i] + " ";
    }
    error("Unterminated .\" string\n");
	}

	void process(array tokens) {
    for (int i = 0; i < sizeof(tokens); i++) {
			string t = lower_case(tokens[i]);

			// \ comment: skip rest of token array (rest of line)
			if (t == "\\") break;

			// ( comment: skip tokens until closing )
			if (t == "(") {
				i++;
				while (i < sizeof(tokens) && tokens[i] != ")") i++;
				continue;
			}
			if (t == ".\"") {
				[string s, i] = collect_string(tokens, i);
				if (!compiling)
					write(s);
				else
					emit(({"strlit", s}));
				continue;
			}

			if (!compiling) {
				if (t == "load") {
					string filename = tokens[++i];
					string src = Stdio.read_file(filename);
					if (!src) { write("Cannot open %s\n", filename); continue; }
					foreach(src / "\n", string line) {
						line = String.trim(line);
						if (line == "") continue;
						process((line / " ") - ({""}));
					}
					continue;
				}
				if (t == "create") {
					string new_name = tokens[++i];
					int body_addr = sizeof(heap);
					heap += ({0});
					dict[new_name] = ({"create", body_addr, ({})});
					push(body_addr);
					continue;
				}
				if (t == "see") {
					string name = lower_case(tokens[++i]);
					if (!dict[name]) {
						write("Unknown word: %s\n", name);
						continue;
					}
					array entry = dict[name];
					if (entry[0] == "prim") {
						write("%s is a primitive\n", name);
					} else if (entry[0] == "word" || entry[0] == "defining") {
						array code = entry[0] == "defining" ? entry[1] : entry[1];
						write(": %s\n", name);
						foreach(code, array ins) {
							switch(ins[0]) {
							case "lit":          write("  lit %d\n", ins[1]);        break;
							case "strlit":       write("  .\" %s\"\n", ins[1]);      break;
							case "call":         write("  %s\n", ins[1]);            break;
							case "branch":       write("  branch %d\n", ins[1]);     break;
							case "0branch":      write("  0branch %d\n", ins[1]);    break;
							case "(do)":         write("  do\n");                    break;
							case "(loop)":       write("  loop\n");                  break;
							case "exit":         write("  exit\n");                  break;
							case "locals-enter": write("  { %s -- }\n", ins[2] * " "); break;
							case "locals-exit":                                      break;
							case "local@":       write("  %s\n", ins[2]);            break;
							case "local!":       write("  -> %s\n", ins[2]);         break;
							default:             write("  %O\n", ins);               break;
							}
						}
						if (entry[0] == "defining") {
							write("does>\n");
							foreach(entry[2], array ins) {
								switch(ins[0]) {
								case "call":   write("  %s\n", ins[1]);  break;
								case "exit":   write("  exit\n");        break;
								default:       write("  %O\n", ins);     break;
								}
							}
						}
						write(";\n");
					} else if (entry[0] == "create") {
						write("%s is a created word, body addr=%d\n", name, entry[1]);
					}
					continue;
				}

				if (t == ":") {
					current  = lower_case(tokens[++i]);
					prog     = ({});
					does_pos = -1;
					compiling = 1;
					continue;
				}

				if (dict[t] && dict[t][0] == "defining") {
					string new_name = lower_case(tokens[++i]);
					int body_addr = sizeof(heap);
					heap += ({0});
					array does_code = dict[t][2];
					dict[new_name] = ({"create", body_addr, does_code});
					push(body_addr);
					run(dict[t][1]);
					continue;
				}

				run_word(t);
				continue;
			}

			/* ── compile mode ── */

			if (t == ";") {
				if (sizeof(locals) > 0)
					emit(({"locals-exit"}));
				emit(({"exit"}));
				locals = ({});

				if (does_pos >= 0) {
					array init_code = prog[..does_pos-1];
					array does_code = prog[does_pos..];
					dict[current] = ({"defining", init_code, does_code});
				} else {
					dict[current] = ({"word", prog});
				}
				compiling = 0;
				does_pos  = -1;
				continue;
			}

			if (t == "does>") {
				does_pos = sizeof(prog);
				continue;
			}

			if (t == "create") {
				continue;
			}

			if (t == "recurse") {
				emit(({"call", current}));
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
			if (t == "{") {
				array all = ({});
				while (i + 1 < sizeof(tokens)) {
					i++;
					if (tokens[i] == "}") break;
					all += ({tokens[i]});
				}
				array names = ({});
				foreach(all, string tok) {
					if (tok == "--") break;
					names += ({tok});
				}
				emit(({"locals-enter", sizeof(names), names}));
				for (int j = sizeof(names)-1; j >= 0; j--)
					emit(({"local!", j, names[j]}));
				locals = names;
				continue;
			}

			// check if token is a known local
			int local_idx = search(locals, t);
			if (local_idx >= 0) {
				emit(({"local@", local_idx, t}));
				continue;
			}

			if (t == "->") {
				string lname = tokens[++i];
				int lidx = search(locals, lname);
				if (lidx < 0) error("Unknown local: %s\n", lname);
				emit(({"local!", lidx, lname}));
				continue;
			}
			array parsed = try_parse_number(t);
			if (parsed[0]) { emit(({"lit", parsed[1]})); continue; }
			emit(({"call", t}));
    }
	}

	void repl() {
    init_prims();
    write("Mini Pike Forth\n");
		string stdlib_path = dirname(System.resolvepath(__FILE__)) + "/stdlib.fs";
    string src = Stdio.read_file(stdlib_path);
    if (src) {
			foreach(src / "\n", string line) {
				line = String.trim(line);
				if (line == "") continue;
				mixed err = catch(process((line / " ") - ({""})));
				if (err) write("stdlib error: %s", describe_error(err));
			}
    }
    while (1) {
			write("> ");
			string line = Stdio.stdin->gets();
			if (!line || line == "bye") break;
			mixed err = catch(process((line / " ") - ({""})));
			if (err) {
				write("Error: %s", describe_error(err));
				// Reset interpreter state so it's usable after an error
				stack   = ({});
				rstack  = ({});
				cstack  = ({});
				prog    = ({});
				compiling = 0;
				does_pos  = -1;
			} else {
				write(" ok\n");
			}
    }
	}
}

int main() {
	Forth().repl();
	return 0;
}
