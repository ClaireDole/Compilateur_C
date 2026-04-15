#ifndef TABLESYMB_H
#define TABLESYMB_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <tablesymb.h>

/* Structure pour stocker temporairement une liste de paramètres */
typedef struct ParamList {
    Param* first;
    Param* last;
    int count;
} ParamList;

typedef struct DeclaList {
    Decla* first;
    Decla* last;
    int count;
} DeclaList;

typedef struct Decla {
    int is_pointer;
    char* name;
    Decla* next;
} Decla;

typedef struct FieldList {
    Field* first;
    Field* last;
    int count;
} ParamList;

/* Gestion des portées */
void enter_scope(void);
void exit_scope(void);

/* Gestion des paramètres de fonction */
void* create_param_list(void);
void add_param_to_list(void* param_list, char* type_nom, int is_pointer);
void free_param_list(ParamList* list);

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

#endif