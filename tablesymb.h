#ifndef TABLESYMB_H
#define TABLESYMB_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* --- Énumérations et Structures de base --- */

typedef enum { 
    SYMBOL_VAR, 
    SYMBOL_STRUCT, 
    SYMBOL_FONC 
} symbol_type;
typedef struct {
    char* nom_type;    
    int is_pointer;    
} DataType;

/* --- Structures de métadonnées --- */

typedef struct {
    DataType type;
    int is_extern; 
} VarInfo;

typedef struct Field {
    char* name;
    DataType type;
    int offset;
    struct Field* next;
} Field;

typedef struct {
    char* nom;
    Field* champs;     
    int taille_totale;
} StructInfo;

typedef struct Param {
    DataType type;
    struct Param* next;
} Param;

typedef struct {
    DataType return_type;
    int nb_params;
    Param* params;    
    int is_extern;
} FoncInfo;

/* --- Entrées de la Table des Symboles --- */

typedef struct {
    char* name;
    symbol_type kind; 
    union {
        VarInfo* var;
        StructInfo* str;
        FoncInfo* fonc;
    } data;
} Symbol;

typedef struct {
    char* key;
    Symbol* symbol;
} Item;

typedef struct {
    int size;
    int count;
    Item** items;
} Table;

typedef struct SymbolTable {
    Table* ht;
    int niveau;
    struct SymbolTable* parent;
} SymbolTable;

/* --- Prototypes des fonctions --- */

// Initialisation
Table* new_table(int size);
SymbolTable* new_symbol_table(SymbolTable* parent, int niveau, int HT_SIZE);

// Constructeurs de Symboles
Symbol* new_symbol_var(char* name, char* type_nom, int is_ptr, int is_ext);
Symbol* new_symbol_struct(char* name);
Symbol* new_symbol_fonc(char* name, char* ret_type_nom, int ret_is_ptr, int is_ext);

// Gestion des structures
void add_field_to_struct(Symbol* struct_sym, char* field_name, char* type_nom, int is_ptr);

//Gestion des fonctions
void add_param_to_function(Symbol* fonc_sym, char* type_nom, int is_ptr)

// Recherche et Insertion
Symbol* ts_lookup(SymbolTable* st, const char* name);
void ts_insert(SymbolTable* st, Symbol* sym, int ligne);

// Libération de la mémoire
void free_symbol(Symbol* s);
void free_table(Table* ht);
void del_symbol_table(SymbolTable* st);

#endif 