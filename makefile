EXE := game
CC := odin
BUILD ?= DEBUG

C_FLAGS := -collection:bundler=src -vet -min-link-libs -strict-style
OPT := none

EXE_EXT :=

ifeq ($(BUILD), DEBUG)
	C_FLAGS += -debug
else ifeq ($(BUILD), RELEASE)
	OPT = speed
endif

ifeq ($(OS), Windows_NT)
	EXE_EXT = .exe
	C_FLAGS += -subsystem:windows
endif

.PHONY: build run clean

build:
	$(CC) build src/ -out:$(EXE)$(EXE_EXT) $(C_FLAGS) -o:$(OPT)

run: build
	./$(EXE)

clean:
	rm -f ./$(EXE)
	rm -f *.dat
	rm -rf projects
