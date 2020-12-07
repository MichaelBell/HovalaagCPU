# File: Makefile
# Author: Aaron Odell
# Company: Digilent Inc.
# Date: 8/16/2010
# Description: makefile for Adept SDK DeppDemo

CC = gcc
INC = /usr/include/digilent/adept
LIBDIR = /usr/lib64/digilent/adept
TARGETS = Inject InjectS
CFLAGS = -I $(INC) -L $(LIBDIR) -ldepp -ldmgr

all: $(TARGETS)

Inject: Inject.cpp
	$(CC) -o Inject Inject.cpp $(CFLAGS)

Inject: InjectS.cpp
	$(CC) -o InjectS InjectS.cpp $(CFLAGS)

.PHONY: clean

clean:
	rm -f $(TARGETS)

