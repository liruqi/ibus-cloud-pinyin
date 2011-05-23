PREFIX ?= /usr

SHELL=/bin/bash
VALAC=valac
CC=gcc

CFLAGS = `cat $(CFLAGFILE)` -pthread
CFLAGS2 = `cat $(CFLAGFILE2)`
VALAFLAGS= `cat $(VALACFLAGFILE)` --pkg posix --thread --enable-checking --vapidir=.
VALAFLAGS2= `cat $(VALACFLAGFILE2)` --pkg posix

VALASRCS= main.vala dbus-binding.vala pinyin-utils.vala frontend-utils.vala config.vala database.vala lua-binding.vala ibus-engine.vala
CSRCS= $(VALASRCS:.vala=.c)

CFLAGFILE=c-flags.txt
CFLAGFILE2=c-flags-2.txt
VALACFLAGFILE=valac-flags.txt
VALACFLAGFILE2=valac-flags-2.txt

ECHO= echo -e

MSG_PREFIX=\x1b[32;01m:: \x1b[39;01m
MSG_SUFFIX=\x1b[33;00m

.PHONY: all clean

.NOTPARALLEL: $(CSRCS)

.DELETE_ON_ERROR: $(CSRCS)

all: ibus-engine-cloud-pinyin ibus-cloud-pinyin-request

ibus-engine-cloud-pinyin: $(CFLAGFILE)
	@$(ECHO) "$(MSG_PREFIX)Building $@ ...$(MSG_SUFFIX)"
	$(CC) $(CFLAGS) $(CSRCS) -g -o $@

ibus-cloud-pinyin-request: 
	@$(ECHO) "$(MSG_PREFIX)Building $@ ...$(MSG_SUFFIX)"
	$(CC) $(CFLAGS2) -Os -o $@ request-main.c

clean:
	@$(ECHO) "$(MSG_PREFIX)Cleaning src ...$(MSG_SUFFIX)"
	-rm -rf ibus-engine-cloud-pinyin ibus-cloud-pinyin-request *.o $(CSRCS) request-main.c
