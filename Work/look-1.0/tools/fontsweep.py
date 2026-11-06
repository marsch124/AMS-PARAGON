import re, sys, pathlib
root = pathlib.Path("/Users/martinschabbauer/Documents/01 Leisure/30 App Development/AMS PARA/App/Paragon")
mapping = {"caption2": "listSecond", "caption": "label", "footnote": "label", "subheadline": "label",
           "callout": "value", "body": "value", "headline": "listTitle", "title3": "sectionTitle",
           "title2": "sectionTitle", "title": "pageTitle", "largeTitle": "pageTitle"}
mono = re.compile(r"^\.system\(\.(caption2|caption|callout|body|footnote), design: \.monospaced\)$")
total = 0
for f in sorted(root.rglob("*.swift")):
    if f.name in ("Look.swift",): continue
    s = f.read_text(); out = []; i = 0; n = 0
    while True:
        j = s.find(".font(", i)
        if j < 0: out.append(s[i:]); break
        out.append(s[i:j]); k = j + len(".font("); depth = 1; m = k
        while m < len(s) and depth:
            if s[m] == "(": depth += 1
            elif s[m] == ")": depth -= 1
            m += 1
        inner = s[k:m-1]
        new = inner
        mm = mono.match(inner.strip())
        if mm: new = "Txt.mono"
        else:
            r = re.match(r"^\.([a-zA-Z0-9]+)(.*)$", inner, re.S)
            if r and r.group(1) in mapping:
                new = "Txt." + mapping[r.group(1)] + r.group(2)
        if new != inner: n += 1
        out.append(".font(" + new + ")"); i = m
    if n:
        f.write_text("".join(out)); total += n
        print(f"{f.relative_to(root)}: {n}")
print("total", total)
