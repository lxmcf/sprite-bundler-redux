EXE := lspb
ODINC := odin
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
	C_FLAGS += -subsystem:windows -resource:data/win.rc
endif

.PHONY: build run clean

build:
	mkdir -p .build
	$(ODINC) build src/ -out:.build/$(EXE)$(EXE_EXT) $(C_FLAGS) -o:$(OPT)

run: build
	.build/$(EXE)$(EXE_EXT)

clean:
ifeq ($(OS), Windows_NT)
	rmdir /s projects .build
else
	rm -rf projects .build
endif
