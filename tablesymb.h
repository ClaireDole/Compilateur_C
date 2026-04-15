#ifndef TABLESYMB_H
#define TABLESYMB_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* Types de symboles */
typedef enum { 
    SYMBOL_VAR,
    SYMBOL_STRUCT,
    SYMBOL_FONC
} symbol_type;

/* Type de données */
typedef struct DataType {
    char* nom_type;
    int is_pointer;
} DataType;

/* Structure pour un paramètre de fonction */
typedef struct Param {
    DataType type;
    struct Param* next;
} Param;

/* Structure pour une variable */
typedef struct {
    DataType type;
    int is_extern;
} VarInfo;

/* Structure pour un champ de structure */
typedef struct Field {
    char* name;
    DataType type;
    int offset;
    struct Field* next;
} Field;

/* Structure pour une structure */
typedef struct {
    char* nom;
    Field* champs;
    int taille_totale;
    int is_extern;
} StructInfo;

/* Structure pour une fonction */
typedef struct {
    DataType return_type;
    int nb_params;
    Param* params;
    int is_extern;
} FoncInfo;

/* Symbole */
typedef struct Symbol {
    char* name;
    symbol_type kind;
    union {
        VarInfo* var;
        StructInfo* str;
        FoncInfo* fonc;
    } data;
} Symbol;

/* Entrée dans la table de hachage */
typedef struct {
    char* key;
    Symbol* symbol;
} Item;

/* Table de hachage */
typedef struct {
    int size;
    int count;
    Item** items;
} Table;

/* Table des symboles avec gestion des portées */
typedef struct SymbolTable {
    Table* ht;
    int niveau;
    struct SymbolTable* parent;
} SymbolTable;


/* Variables globales */
extern SymbolTable* table_globale;
extern SymbolTable* table_courante;

/* Initialisation */
Table* new_table(int size);
SymbolTable* new_symbol_table(SymbolTable* parent, int niveau, int HT_SIZE);

/* Constructeurs de symboles */
Symbol* new_symbol_var(char* name, char* type_nom, int is_ptr, int is_ext);
Symbol* new_symbol_struct(char* name);
void add_field_to_struct(Symbol* struct_sym, char* field_name, char* type_nom, int is_ptr);
Symbol* new_symbol_fonc(char* name, char* ret_type_nom, int ret_is_ptr, int is_ext);
void add_param_to_function(Symbol* fonc_sym, char* type_nom, int is_ptr);

/* Recherche et insertion */
Symbol* ts_lookup(SymbolTable* st, const char* name);
void ts_insert(SymbolTable* st, Symbol* sym, int ligne);

/* Libération mémoire */
void free_symbol(Symbol* s);
void free_table(Table* ht);
void del_symbol_table(SymbolTable* st);

/* Utilitaires mémoire */
void free_str(char* s);
void free_data_type(DataType* dt);

#endif