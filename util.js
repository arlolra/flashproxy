REPLACEMENTS = {
	"\\": "\\\\",
	"\"": "\\\"",
	"\n": "\\n",
	"\t": "\\t",
	"\r": "\\r",
};
QUOTE_REGEXP = new RegExp("[\\s\\S]", "gm");
function pad(s, n) {
	while (s.length < n)
		s = "0" + s;
	return s;
}
function quote_repl(c) {
	var r, n;

	r = REPLACEMENTS[c];
	if (r)
		return r;

	n = c.charCodeAt(0);
	if (n >= 256)
		return "\\u" + pad(n.toString(16), 4);
	else if (n < 32 || n >= 127)
		return "\\x" + pad(n.toString(16), 2);

	return c;
}

function quote(s) {
	return "\"" + s.replace(QUOTE_REGEXP, quote_repl) + "\"";
}

function maybe_quote(s) {
	if (/^[_A-Za-z][_A-Za-z0-9]*$/.test(s))
		return s;
	else
		return quote(s);
}

function repr(x, max_depth) {
	if (max_depth == undefined)
		max_depth = 1;

	if (x === null) {
		return "null";
	} else if (x instanceof java.lang.Iterable) {
		var elems = [];
		var i = x.iterator();
		while (i.hasNext())
			elems.push(repr(i.next()));
		return x["class"] + ":[ " + elems.join(", ") + " ]";
	} else if (typeof x == "object" && /^\s*function Array/.test(String(x.constructor))) {
		// Looks like an array.
		if (max_depth <= 0)
			return "[...]";
		var elems = [];
		for (var i = 0; i < x.length; i++)
			elems.push(repr(x[i], max_depth - 1));
		return "[ " + elems.join(", ") + " ]";
	} else if (typeof x == "object" && "hashCode" in x) {
		// Guess that it's a Java object.
		return String(x);
	} else if (typeof x == "object") {
		if (max_depth <= 0)
			return "{...}";
		var elems = [];
		for (var k in x)
			elems.push(maybe_quote(k) + ": " + repr(x[k], max_depth - 1));
		return "{ " + elems.join(", ") + " }";
	} else if (typeof x == "string") {
		return quote(x);
	} else {
		return String(x);
	}
}
