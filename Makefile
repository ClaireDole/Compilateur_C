CC = gcc
CFLAGS = -Wall -g -I.
LEX = flex
YACC = bison -d -v

SOURCES = main.c tablesymb.c erreur.c
HEADERS = erreur.h tablesymb.h y.tab.h
LEX_FILE = lexeur_fe.lex
YACC_FILE = structfe.y

all: structfe

structfe: lex.yy.c y.tab.c $(SOURCES)
	$(CC) $(CFLAGS) -o $@ lex.yy.c y.tab.c $(SOURCES)

lex.yy.c: $(LEX_FILE) y.tab.h
	$(LEX) -o $@ $(LEX_FILE)

y.tab.c y.tab.h: $(YACC_FILE)
	$(YACC) -o y.tab.c $(YACC_FILE)

clean:
	rm -f structfe lex.yy.c y.tab.c y.tab.h y.output *.o

.PHONY: all clean
