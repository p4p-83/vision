CC = aarch64-unknown-linux-gnu-g++
LDFLAGS =
BLDDIR = .
INCDIR = $(BLDDIR)/inc
SRCDIR = $(BLDDIR)/src
OBJDIR = $(BLDDIR)/bin
CFLAGS = -c -Wall -I$(INCDIR) -L/Users/Sam/Development/cross-compilers/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot/usr/lib -I/Users/Sam/Development/cross-compilers/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot/usr/include/libcamera
SRC = $(wildcard $(SRCDIR)/*.cpp)
OBJ = $(patsubst $(SRCDIR)/%.cpp, $(OBJDIR)/%.o, $(SRC))
EXE = $(OBJDIR)/vision

all: clean $(EXE) 
    
$(EXE): $(OBJ) 
	$(CC) $(LDFLAGS) $(OBJDIR)/*.o /Users/Sam/Development/cross-compilers/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot/usr/lib/libcamera.so -o $@ 

$(OBJDIR)/%.o : $(SRCDIR)/%.cpp
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $< -o $@

clean:
	-rm -f $(OBJDIR)/*.o $(EXE)