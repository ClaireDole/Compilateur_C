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
} FieldList;

typedef struct ArgList {
    Arg* first;
    Arg* last;
    int count;
} ArgList;

typedef struct Arg {
    int is_pointer;
    char* name;
    DataType type;
    Arg* next;
} Arg;

/* Gestion des portées */
void enter_scope(void);
void exit_scope(void);

/* Gestion des paramètres de fonction */
ParamList* create_param_list(void);
void add_param_to_list(ParamList* param_list, char* type_nom, int is_pointer);
void free_param_list(ParamList* list);

/* Gestion des déclarations multiples */
DeclaList* create_decla_list(void);
void add_var_to_list(DeclaList* decla_list, char* type_nom, int is_pointer);
void free_decla_list(DeclaList* list);

/* Gestion des champs des structures */
FieldList* create_field_list(void);
void add_field_to_list(FieldList* field_list, char* type_nom, int is_pointer);
void free_field_list(FieldList* list);

/* Gestion des arguments pour fonctions et structures*/
ArgList* create_arg_list(void);
void add_arg_to_list(ArgList* arg_list, char* type_nom, int is_pointer);
void free_arg_list(ArgList* list);

/*validation des types*/
void check_validate_param(Param* param,SymbolTable* table_courante,int ligne,char* yytext);
void check_validate_var(Decla* decla,SymbolTable* table_courante,int ligne,char* yytext,char* nom_type); 
void check_validate_field(Field* field,SymbolTable* table_courante,int ligne,char* yytext);

/* Gestion des identifiants */
void check_identifier_declared(char* name, SymbolTable* table_courante, int ligne);

/* Gestion des appels de fonction */
int check_function_call(char* name, SymbolTable* table_courante, int ligne);
int check_function_call_with_args(char* name, int nb_params,int ligne,SymbolTable* table_courante);

/* Gestion des structures */
DataType check_struct_field_access(char* struct_name, char* field_name, SymbolTable* table_courante, int yylineno);

/* Gestion des retours de fonction */
void check_return_statement(void* expr_type);
void check_return_without_value(void);
void check_return_with_value(void);

/* Gestion des erreurs sémantiques */
void error_direct_struct_access(char* field_name);
void error_unsupported(char* feature);
void error_redeclaration(char* name, int niveau);

#endif