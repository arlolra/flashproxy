function quote(s) {
	return "\"" + s.replace(/([\\\"])/, "\\$1") + "\"";
}

function maybe_quote(s) {
	if (/[\\\"]/.test(s))
		return quote(s);
	else
		return s;
}

function repr(x, max_depth) {
	if (max_depth == undefined)
		max_depth = 1;

	if (x === null) {
		return "null";
	} if (typeof x == "object") {
		if ("hashCode" in x)
			// Guess that it's a Java object.
			return String(x);
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
