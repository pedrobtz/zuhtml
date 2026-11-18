import collections
m = {"GBK":"gbk","gb18030":"gb18030","Big5":"big5hkscs","EUC-JP":"euc_jp","Shift_JIS":"cp932","EUC-KR":"cp949"}
diff = collections.defaultdict(list); tot = collections.Counter()
for line in open("mb.tsv"):
    e,b,v = line.rstrip("\n").split("\t")
    raw = b"z"+bytes.fromhex(b)+b"z"
    try: ref = "+".join("%04X"%ord(c) for c in raw.decode(m[e]))
    except UnicodeDecodeError: ref = "ERR"
    tot[e]+=1
    if ref != v:
        kind = "pkgERR" if v=="ERR" else ("pyERR" if ref=="ERR" else "DIFF")
        diff[(e,kind)].append((b,v,ref))
for k,v in diff.items():
    print(k, len(v))
    step = max(1, len(v)//25)
    for t in v[::step][:30]: print("   ", t)
