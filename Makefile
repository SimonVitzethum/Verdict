# Brandmauer -- build. The compiler is werkzeug/gabbro; nothing here edits it.
GABBRO := ./werkzeug/gabbro
GABS   := $(wildcard gab/*.gab)
CS     := $(patsubst gab/%.gab,bau/%.c,$(GABS))
CFLAGS := -std=c11 -Wall -Wextra -Werror -O2 -pthread

.PHONY: all pruefen sauber
all: bau/brandmauer

pruefen:
	@for f in $(GABS); do printf '%-28s ' $$f; $(GABBRO) pruefe $$f > /tmp/bm.$$$$ 2>&1 \
	  && echo "ok" || { echo "REFUSED"; tail -20 /tmp/bm.$$$$; }; done

bau/%.c: gab/%.gab
	@mkdir -p bau
	$(GABBRO) pruefe $< >/dev/null
	$(GABBRO) emit $< > $@

bau/brandmauer: $(CS) $(wildcard treiber/*.c)
	$(CC) $(CFLAGS) -I bau -o $@ treiber/*.c $(LDLIBS)

sauber:
	rm -rf bau
