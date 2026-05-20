#ifndef GESTION_TABLES_H
#define GESTION_TABLES_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "tablesymb.h"

/* Structure pour stocker temporairement une liste de paramètres */
typedef struct ParamList {
    Param* first;
    Param* last;
    int count;
} ParamList;

typedef struct FieldList {
    Field* first;
    Field* last;
    int count;
} FieldList;

typedef struct Arg {
    int is_pointer;
    char* name;
    int state;
    DataType type;
    struct Arg* next;
    char* expr_res;
} Arg;

typedef struct ArgList {
    Arg* first;
    Arg* last;
    int count;
} ArgList;

typedef struct Point {
    int is_pointer;
    char* name;
    ParamList* params;
    int state;
    struct Point* next;
} Point;

typedef struct PointList {
    Point* first;
    Point* last;
    int count;
} PointList;

typedef struct Statement {
    int unique;
    DataType ret_type;
    struct Statement* next;
} Statement;

typedef struct StatementList {
    Statement* first;
    Statement* last;
    int count;
} StatementList;

/*Déclarations de Error_List*/
typedef struct Error_L{
    char* name;
    struct Error_L* next;
}Error_L;

typedef struct Error_List {
    Error_L* first;
    Error_L* last;
    int count;
} Error_List;

/* Gestion des portées */
void enter_scope(void);
void exit_scope(void);

/* Gestion des paramètres de fonction */
ParamList* create_param_list(void);
void add_param_to_list(ParamList* param_list, char* var_name,char* type_nom, int is_pointer);
void free_param_list(ParamList* list);

/* Gestion des déclarations (multiples) pour pointeur de fonctions*/
PointList* create_point_list(void);
void add_point_to_list(PointList* decla_list, char* type_nom, int is_pointer, ParamList* params,int state);
void free_point_list(PointList* list);

/* Gestion des champs des structures */
FieldList* create_field_list(void);
void add_field_to_list(FieldList* field_list,char* name ,char* type_nom, int is_pointer);
void free_field_list(FieldList* list);

/* Gestion des arguments pour fonctions et structures*/
ArgList* create_arg_list(void);
void add_arg_to_list(ArgList* arg_list, char* type_nom, int is_pointer, int state);
void free_arg_list(ArgList* list);

/*validation des types*/
void check_validate_param(Param* param,SymbolTable*table_courante,int ligne,char* yytext);
void check_validate_var(Point* decla,SymbolTable*table_courante,int ligne,char* yytext,char* nom_type);
void check_validate_field(Field* field,SymbolTable* table_courante,int ligne,char* yytext,char* structe);

/* Gestion des identifiants */
void check_identifier_declared(char* name, SymbolTable* table_courante, int ligne);

/*Gestion des pointeurs de fonctions */
int check_function_pointer(DataType type, SymbolTable* table_courante,int ligne);
/* Gestion des appels de fonction */
int check_function_call(char* name, SymbolTable* table_courante, int ligne);
int check_function_call_with_args(char* name, int nb_params,int ligne,SymbolTable* table_courante);

/* Gestion des structures */
DataType check_struct_field_access(char* struct_name, char* field_name, SymbolTable* table_courante, int yylineno);

/*Gestion des statements*/
StatementList* create_statement_list(void);
void add_statement_to_list(StatementList* field_list, DataType ret_type, int unique);
void free_statement_list(StatementList* list);

/* Système de typage*/
int datatype_comp(DataType t, DataType d);
int function_comp(Symbol* f, Symbol* g,int yylineno, char* yytext);

/* Gestion des erreurs d'analyse */
Error_List* create_error_list(void);
void add_error_to_list(Error_List* field_list, char* name);
void free_error_list(Error_List* list);

int get_type_size(char* nom_type, int is_pointer);

ParamList* duplicate_param_list(ParamList* src);
#endif
