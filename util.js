function quote(s) {
	return "\"" + s.replace(/([\\\"])/, "\\$1") + "\"";
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
	} else if (typeof x == "object") {
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
