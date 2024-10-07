EXE := lspp
CC := odin
BUILD ?= DEBUG

C_FLAGS := -vet -min-link-libs -strict-style -disallow-do
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
ifeq ($(OS), Windows_NT)
	rmdir /s projects

	del $(EXE)$(EXE_EXT) *.dat
else
	rm -rf projects

	rm -f ./$(EXE)$(EXE_EXT) *.dat
endif
