S = @ # silent

.PHONY: all clean run plugins $(EXE)

OPA ?= opa
OPA_PLUGIN ?= opa-plugin-builder
OPA_OPT ?= --parser js-like
MINIMAL_VERSION = 1046
EXE = opa_chat.exe

all: $(EXE)

plugins: plugins/file/file.js plugins/mindwave/mindwave.js
	$(OPA_PLUGIN) --js-validator-off plugins/file/file.js -o file.opp
	$(OPA_PLUGIN) --js-validator-off plugins/mindwave/mindwave.js -o mindwave.opp
	$(OPA) $(OPA_OPT) plugins/file/file.opa file.opp
	$(OPA) $(OPA_OPT) plugins/mindwave/mindwave.opa mindwave.opp

$(EXE): plugins src/*.opa resources/*
	$(OPA) $(OPA_OPT) --minimal-version $(MINIMAL_VERSION) *.opp src/*.opa -o $(EXE)

run: all
	$(S) ./$(EXE) $(RUN_OPT) || exit 0 ## prevent ugly make error 130 :) ##

clean:
	rm -Rf *.opx* *.opp*
	rm -Rf *.exe _build _tracks *.log **/#*#
