#----------------- LIBRARY -------------------
BINDIR = /usr/custom/bin
#----------------- LINK OPTIONS -------------------
CCOMPL=gcc $(CFLAGS)
#------- Followings are PASS or DIRECTORY -------
PROGS=	readXM1
GRLIBS= -L/usr/X11R6/lib -lX11
MATH=	-lm
#----------------- MAPPING ------------------------
OBJ_XM1=	readXM1.o
#----------------- Compile and link ------------------------
readXM1 : $(OBJ_XM1)
	$(CCOMPL) -o $@ $(OBJ_XM1)

clean :
	\rm $(PROGS) *.o a.out core *.trace

all :	$(PROGS)

install:
	@mv $(PROGS) $(BINDIR)

#----------------- Objects ------------------------
.c.o:
	$(CCOMPL) -c $*.c
readXM1.o:	readXM1.c
#----------------- End of File --------------------
