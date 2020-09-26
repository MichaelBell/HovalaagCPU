#!/usr/bin/env python
# Copyright (C) 2020 Michael Bell

# Translates a binary program a.out from the Hovalaag assembler 
# to a format that can be pasted into a Verilog case statment

f=open('a.out')

for idx in xrange(256):
    instr = f.read(4)
    if len(instr) != 4: break
    s = "8'h%02x:   data = 32'b" % idx
    for i in xrange(3,-1,-1):
        b = ord(instr[i])
        for j in xrange(8):
            if b & 0x80: s += "1"
            else: s += "0"
            b <<= 1
    print s + ';'

