import re
import os

def dump_strings_around(path, offset, length=800):
    with open(path, "rb") as f:
        f.seek(offset)
        data = f.read(length)
    idx = 0
    while idx < len(data) - 2:
        str_len = data[idx] + (data[idx+1] << 8)
        if 0 < str_len < 200 and idx + 2 + str_len * 2 <= len(data):
            try:
                s = data[idx+2 : idx+2 + str_len*2].decode("utf-16le")
                if all(32 <= ord(c) < 127 or ord(c) in [10, 13] for c in s):
                    print("  [0x%X] len=%d: %s" % (offset + idx, str_len, s))
            except Exception:
                pass
        idx += 2

base = r"C:\Users\nguye\Downloads\Age of Empires 1_Linkneverdie.com\Age of Empires 1_Linkneverdie.com\Age of Empires"
print("--- Unit/Animal Help Text in Language.Dll ---")
dump_strings_around(os.path.join(base, "Language.Dll"), 0x1FED0, 600)



