OBJECTS=Main.o
AS=/usr/bin/as
LDFLAGS=-g
EXECUTABLES=x4y

all: x4y

x4y: $(OBJECTS)
	g++ $(LDFLAGS) -o x4y $^

clean:
	-rm -rf *.o $(EXECUTABLES)

.PHONY: clean
