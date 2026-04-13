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

/* Structure pour stocker temporairement une liste de paramètres */
typedef struct ParamList {
    Param* first;
    Param* last;
    int count;
} ParamList;

/* Variables globales */
extern SymbolTable* table_globale;
extern SymbolTable* table_courante;

/* Initialisation */
Table* new_table(int size);
SymbolTable* new_symbol_table(SymbolTable* parent, int niveau, int HT_SIZE);

/* Constructeurs de symboles */
Symbol* new_symbol_var(char* name, char* type_nom, int is_ptr, int is_ext);
Symbol* new_symbol_struct(char* name);
Symbol* new_symbol_fonc(char* name, char* ret_type_nom, int ret_is_ptr, int is_ext);

/* Recherche et insertion */
Symbol* ts_lookup(SymbolTable* st, const char* name);
void ts_insert(SymbolTable* st, Symbol* sym, int ligne);

/* Libération mémoire */
void free_symbol(Symbol* s);
void free_table(Table* ht);
void del_symbol_table(SymbolTable* st);

/* Gestion des portées */
void enter_scope(void);
void exit_scope(void);

/* Gestion des paramètres de fonction */
void* create_param_list(void);
void add_param_to_list(void* param_list, char* type_nom, int is_pointer);
void free_param_list(ParamList* list);

/* Gestion des fonctions */
Symbol* create_function_symbol(char* name, int nb_params, void* param_list);
void end_function_definition(Symbol* func);
Symbol* get_current_function(void);

/* Gestion des variables */
void declare_variable(char* name, char* type_nom, int is_pointer, int is_extern);

/* Gestion des identifiants */
void check_identifier_declared(char* name);
Symbol* get_identifier_symbol(char* name);

/* Gestion des appels de fonction */
void check_function_call(char* name);
void check_function_call_with_args(char* name, int nb_params);

/* Gestion des structures */
char* declare_struct(char* name);
char* declare_anonymous_struct(void);
char* define_struct(char* name);
void add_struct_field(char* field_name, char* type_nom, int is_pointer);
void check_struct_field_access(char* struct_name, char* field_name);
Symbol* get_current_struct(void);
void set_current_struct(Symbol* s);

/* Gestion des retours de fonction */
void check_return_statement(void* expr_type);
void check_return_without_value(void);
void check_return_with_value(void);

/* Gestion des erreurs sémantiques */
void error_direct_struct_access(char* field_name);
void error_unsupported(char* feature);
void error_redeclaration(char* name, int niveau);

/* Utilitaires mémoire */
void free_str(char* s);
void free_data_type(DataType* dt);

#endif