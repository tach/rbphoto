#!/usr/bin/make

NAME = rbphoto
LANG = ja
POFILES = $(patsubst %, %.po, $(LANG))
MOFILES = $(patsubst %, %.mo, $(LANG))
TARGETMO = $(patsubst %, /usr/share/locale/%/LC_MESSAGES/rbphoto.mo, $(LANG))

mo: $(MOFILES)
update: $(POFILES)
clean:
	-rm -f *.mo

install: $(MOFILES)
	for mo in $^; do install -m 644 $$mo $(DESTDIR)/usr/share/locale/`basename $$mo .mo`/LC_MESSAGES/rbphoto.mo; done

%.po: $(NAME).pot
	msgmerge -U $@ $<

%.mo: %.po
	msgfmt $< -o $@
