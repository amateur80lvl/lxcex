prefix = /usr

LDADD = -z relro -z now


all: uidmapshift

uidmapshift: uidmapshift.c
	@echo "CFLAGS=$(CFLAGS)" | \
		fold -s -w 70 | \
		sed -e 's/^/# /'
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDCFLAGS) $(LDADD) -o $@ $^

install: uidmapshift
	install -D uidmapshift \
		$(DESTDIR)$(prefix)/bin/uidmapshift

clean:
	-rm -f uidmapshift

distclean: clean

uninstall:
	-rm -f $(DESTDIR)$(prefix)/bin/uidmapshift

.PHONY: all install clean distclean uninstall
