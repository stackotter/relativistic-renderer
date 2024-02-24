s = """
1000 K  #ff3800
1200 K  #ff5300
1400 K  #ff6500
1600 K  #ff7300
1800 K  #ff7e00
2000 K  #ff8912
2200 K  #ff932c
2400 K  #ff9d3f
2600 K  #ffa54f
2800 K  #ffad5e
3000 K  #ffb46b
3200 K  #ffbb78
3400 K  #ffc184
3600 K  #ffc78f
3800 K  #ffcc99
4000 K  #ffd1a3
4200 K  #ffd5ad
4400 K  #ffd9b6
4600 K  #ffddbe
4800 K  #ffe1c6
5000 K  #ffe4ce
5200 K  #ffe8d5
5400 K  #ffebdc
5600 K  #ffeee3
5800 K  #fff0e9
6000 K  #fff3ef
6200 K  #fff5f5
6400 K  #fff8fb
6600 K  #fef9ff
""".strip()

out = []
for line in s.splitlines():
    line = line.strip()
    hex = line.split(" ")[3][1:]
    r = hex[:2]
    g = hex[2:4]
    b = hex[4:]
    r = int(r, base=16)
    g = int(g, base=16)
    b = int(b, base=16)
    out.append(f"float3({r}.0 / 255.0, {g}.0 / 255.0, {b}.0 / 255.0)")
print(",\n".join(out))
