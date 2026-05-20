#ifndef AFFICHAGE_H
#define AFFICHAGE_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tablesymb.h"
#include "gestion_tables.h"

void print_indent(int niveau);
void afficher_datatype(DataType type);
void afficher_symbole(Symbol* s, int niveau);
void afficher_table_hachage(Table* ht, int niveau);
void afficher_symbol_table(SymbolTable* st);
void afficher_liste_tables(ST_List* liste);
void afficher_liste_erreurs(void* list_ptr);
#endif