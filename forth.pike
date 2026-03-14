class ForthInterpreter {
	array stack = ({});
	array rstack = ({});
	array heap = allocate(1024);
	mapping dictionary = ([
		"+":    ({ "prim", lambda() {
			int b=stack[-1]; int a=stack[-2]; stack=stack[..<-3]+({a+b}); } }),
		"-":    ({ "prim", lambda() {
			int b=stack[-1]; int a=stack[-2]; stack=stack[..<-3]+({a-b}); } }),
		"*":    ({ "prim", lambda() {
			int b=stack[-1]; int a=stack[-2]; stack=stack[..<-3]+({a*b}); } }),
		".":    ({ "prim", lambda() {
			write("%d ", stack[-1]); stack = stack[..<-2]; } }),
		"dup":  ({ "prim", lambda() {
			stack += ({ stack[-1] }); } }),
		"!":    ({ "prim", lambda() {
			int val=stack[-1]; int addr=stack[-2]; heap[addr]=val;
			stack=stack[..<-3]; } }),
		"@":    ({ "prim", lambda() {
			int addr=stack[-1]; stack[-1]=heap[addr]; } }),
		"i":    ({ "prim", lambda() {
			stack += ({ rstack[-1][1] }); } }),
		"words":({ "prim", lambda() {
			write(sort(indices(dictionary))*", " + "\n"); } })
	]);

	void run(array tokens) {
		for (int pc = 0; pc < sizeof(tokens); pc++) {
			string token = tokens[pc];
			if ((int)token != 0 || token == "0") stack += ({ (int)token });
			else if (token == "if") {
				if (stack[-1] == 0) {
					int depth = 1;
					while (depth > 0 && ++pc < sizeof(tokens)) {
						if (tokens[pc] == "if") depth++;
						else if (tokens[pc] == "then") depth--;
						else if (tokens[pc] == "else" && depth == 1) break;
					}
				}
				stack = stack[..<-2];
			} else if (token == "else") {
				int depth = 1;
				while (depth > 0 && ++pc < sizeof(tokens)) {
					if (tokens[pc] == "if") depth++;
					else if (tokens[pc] == "then") depth--;
				}
			} else if (token == "do") {
				int limit = stack[-1]; int start = stack[-2];
				stack = stack[..<-3];
				rstack += ({ ({ pc, start, limit }) });
			} else if (token == "loop") {
				array frame = rstack[-1];
				if (++frame[1] < frame[2]) pc = frame[0];
				else rstack = rstack[..<-2];
			} else if (array entry = dictionary[token]) {
				if (entry[0] == "prim") entry[1]();
				else run(entry[1]);
			}
		}
	}

	void repl() {
		write("Pike-Forth REPL. (Use : name ... ; to define words)\n");
		while (1) {
			write("> ");
			string line = Stdio.stdin->gets();
			if (!line || line == "bye") break;
            
			if (has_prefix(line, ": ")) {
				array parts = (line / " ");
				string name = parts[1];
				array body = parts[2..<1]; // Excludes ':' and ';'
				dictionary[name] = ({ "user", body });
				write("Word '%s' defined.\n", name);
			} else {
				run(line / " ");
				write(" ok\n");
			}
		}
	}
}

int main() {
	ForthInterpreter()->repl();
	return 0;
}
