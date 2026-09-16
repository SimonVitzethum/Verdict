# Verdict -- build. The compiler is werkzeug/gabbro; nothing here edits it.
GABBRO := ./werkzeug/gabbro
GABS   := $(wildcard gab/*.gab)
CS     := $(patsubst gab/%.gab,bau/%.c,$(GABS))
CFLAGS := -std=c11 -Wall -Wextra -Werror -O2 -pthread

.PHONY: all pruefen sauber
all: bau/verdict

# The one interface edge (lane bm11): gab/systemrufe.gab names
# gab/netzverbindung.gab's tables for the ptr transports (`use` + `&T`),
# so its check and its emit read the generated interface. The .gabi is
# generated, never edited; every other file checks alone as before.
bau/netz.gabi: gab/netzverbindung.gab
	@mkdir -p bau
	$(GABBRO) abi $< > $@

pruefen: bau/netz.gabi
	@for f in $(GABS); do printf '%-28s ' $$f; \
	  if [ $$f = gab/systemrufe.gab ]; then $(GABBRO) pruefe --with bau/netz.gabi $$f > /tmp/bm.$$$$ 2>&1; \
	  else $(GABBRO) pruefe $$f > /tmp/bm.$$$$ 2>&1; fi \
	  && echo "ok" || { echo "REFUSED"; tail -20 /tmp/bm.$$$$; }; done

bau/%.c: gab/%.gab
	@mkdir -p bau
	$(GABBRO) pruefe $< >/dev/null
	$(GABBRO) emit $< > $@

bau/systemrufe.c: gab/systemrufe.gab bau/netz.gabi
	@mkdir -p bau
	$(GABBRO) pruefe --with bau/netz.gabi $< >/dev/null
	$(GABBRO) emit --with bau/netz.gabi $< > $@

# NOTE (lanes bm7-bm11): the link needs the four diverging exits
# (treffer_aufgegeben, zaehler_streit, netz_streit, lauf_aufgegeben), which
# no Gabbro file may define (Befund T-4: H022/K008, C001, N321). No treiber/
# dir exists in this clone, so this step stays red until the treiber lane
# lands; the scratch stub (out of the tree, never committed) proves linkage
# instead -- see messung/BERICHT-bm10.md and -bm11.md.
bau/verdict: $(CS)
	$(CC) $(CFLAGS) -I bau -o $@ $(CS) $(wildcard treiber/*.c) $(LDLIBS)

sauber:
	rm -rf bau
