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

ibus-engine-cloud-pinyin: $(CFLAGFILE) $(CSRCS)
	@$(ECHO) "$(MSG_PREFIX)Building $@ ...$(MSG_SUFFIX)"
	$(CC) $(CFLAGS) $(CSRCS) -g -o $@

ibus-cloud-pinyin-request: request-main.c
	@$(ECHO) "$(MSG_PREFIX)Building $@ ...$(MSG_SUFFIX)"
	$(CC) $(CFLAGS2) -Os -o $@ $^

request-main.c: request-main.vala $(VALACFLAGFILE2)
	@$(ECHO) "$(MSG_PREFIX)Generating C file for ibus-cloud-pinyin-request ...$(MSG_SUFFIX)"
	$(VALAC) $(VALAFLAGS2) --disable-warnings -C $<

$(CSRCS): $(VALACFLAGFILE) $(VALASRCS)
	@$(ECHO) "$(MSG_PREFIX)Generating C files for ibus-engine-cloud-pinyin ...$(MSG_SUFFIX)"
	@-rm -rf $(CSRCS)
	$(VALAC) $(VALAFLAGS) --disable-warnings  -C $(VALASRCS)
	@#$(VALAC) $(VALAFLAGS) -C $(VALASRCS)
	@$(ECHO) "$(MSG_PREFIX)Patching C files (workaround for valac) ...$(MSG_SUFFIX)"
	@#if ! grep -qe 'dbus_[^t]*thread' main.c; then sed -i 's/gdk_threads_init/dbus_g_thread_init();gdk_threads_init/' main.c; fi
	for i in *.c; do sed -i "s#@PREFIX@#$(PREFIX)#g" $$i; done

clean:
	@$(ECHO) "$(MSG_PREFIX)Cleaning src ...$(MSG_SUFFIX)"
	-rm -rf ibus-engine-cloud-pinyin ibus-cloud-pinyin-request *.o $(CSRCS) request-main.c
