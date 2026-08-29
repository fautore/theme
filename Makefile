PREFIX ?= $(HOME)/.local
BIN ?= theme
ODIN ?= odin

.PHONY: build run install clean

build:
	$(ODIN) build . -out:$(BIN)

run: build
	./$(BIN) $(ARGS)

install: build
	install -Dm755 $(BIN) $(DESTDIR)$(PREFIX)/bin/$(BIN)

clean:
	rm -f $(BIN)
