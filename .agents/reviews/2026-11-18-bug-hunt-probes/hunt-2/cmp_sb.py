import sys
m = {"IBM866":"cp866","ISO-8859-8-I":"iso8859_8","macintosh":"mac_roman","windows-874":"cp874","x-mac-cyrillic":"mac_cyrillic","KOI8-R":"koi8_r","KOI8-U":"koi8_u"}
for line in open("sb.tsv"):
    e,b,v = line.rstrip("\n").split("\t")
    py = m.get(e) or (e.lower().replace("windows-","cp").replace("iso-8859-","iso8859_"))
    try:
        ref = "%04X" % ord(bytes([int(b,16)]).decode(py))
    except UnicodeDecodeError:
        ref = "ERR"
    if ref != v: print(e,b,"pkg",v,"python",ref)
