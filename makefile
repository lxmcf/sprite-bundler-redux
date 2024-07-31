EXE := game
CC := odin
BUILD ?= DEBUG

C_FLAGS := -collection:bundler=src
OPT := none

ifeq ($(BUILD), DEBUG)
	C_FLAGS += -debug
else ifeq ($(BUILD), RELEASE)
	C_FLAGS += -microarch:native
	OPT = speed
endif

.PHONY: build run clean

build:
	$(CC) build src/ -out:$(EXE) $(C_FLAGS) -o:$(OPT)

run: build
	./$(EXE)

clean:
	rm -f ./$(EXE)
	rm -f *.dat
	rm -rf projects
