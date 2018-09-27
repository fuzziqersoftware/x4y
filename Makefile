OBJECTS=Main.o
AS=/usr/bin/as
LDFLAGS=-g
EXECUTABLES=x-for-y

all: x-for-y

x-for-y: $(OBJECTS)
	g++ $(LDFLAGS) -o x-for-y $^

clean:
	-rm -rf *.o $(EXECUTABLES)

.PHONY: clean
