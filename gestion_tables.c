#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "erreur.h"
#include "tablesymb.h"
#include "gestion_tables.h"

void enter_scope(void) {
    SymbolTable* new_scope = new_symbol_table(table_courante, 
                                               table_courante ? table_courante->niveau + 1 : 1, 
                                               100);
    if (!new_scope) {
        fprintf(stderr, "Erreur: Impossible de créer une nouvelle portée\n");
        exit(1);
    }
    table_courante = new_scope;
}

void exit_scope(void) {
    if (table_courante && table_courante->parent) {
        SymbolTable* old = table_courante;
        table_courante = table_courante->parent;
        del_symbol_table(table_courante);
    }
}

DeclaList* create_decla_list(void) {
    DeclaList* list = malloc(sizeof(DeclaList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return list;
}

void add_var_to_list(DeclaList* decla_list, char* name, int is_pointer) {
    if (!decla_list) return;
    DeclaList* list = (DeclaList*)decla_list;
    
    Decla* new_decla = malloc(sizeof(Decla));
    new_decla->name = name;
    new_decla->is_pointer = is_pointer;
    new_decla->next = NULL;
    
    if (list->last) {
        list->last->next = new_decla;
        list->last = new_decla;
    } else {
        list->first = new_decla;
        list->last = new_decla;
    }
    list->count++;
}

void free_decla_list(DeclaList* list) {
    if (!list) return;
    Decla* p = list->first;
    while (p) {
        Decla* tmp = p;
        p = p->next;
        free(tmp->name);
        free(tmp);
    }
    free(list);
}

ParamList* create_param_list(void) {
    ParamList* list = malloc(sizeof(ParamList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return list;
}

void add_param_to_list(ParamList* param_list, char* type_nom, int is_pointer) {
    if (!param_list) return;
    ParamList* list = (ParamList*)param_list;
    
    Param* new_param = malloc(sizeof(Param));
    new_param->type.nom_type = strdup(type_nom);
    new_param->type.is_pointer = is_pointer;
    new_param->next = NULL;
    
    if (list->last) {
        list->last->next = new_param;
        list->last = new_param;
    } else {
        list->first = new_param;
        list->last = new_param;
    }
    list->count++;
}

void free_param_list(ParamList* list) {
    if (!list) return;
    Param* p = list->first;
    while (p) {
        Param* tmp = p;
        p = p->next;
        free(tmp->type.nom_type);
        free(tmp);
    }
    free(list);
}

FieldList* create_field_list(void) {
    FieldList* list = malloc(sizeof(FieldList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return list;
}

void add_field_to_list(FieldList* field_list, char* type_nom, int is_pointer) {
    if (!field_list) return;
    FieldList* list = (FieldList*)field_list;
    
    Field* field = malloc(sizeof(Field));
    field->type.nom_type = strdup(type_nom);
    field->type.is_pointer = is_pointer;
    field->next = NULL;
    field->offset = NULL;
    
    if (list->last) {
        list->last->next = field;
        list->last = field;
    } else {
        list->first = field;
        list->last = field;
    }
    list->count++;
}

void free_field_list(FieldList* list) {
    if (!list) return;
    Field* p = list->first;
    while (p) {
        Field* tmp = p;
        p = p->next;
        free(tmp->type.nom_type);
        free(tmp);
    }
    free(list);
}

ArgList* create_arg_list(void) {
    ArgList* list = malloc(sizeof(ArgList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return list;
}

void add_arg_to_list(ArgList* arg_list, char* type_nom, int is_pointer) {
    if (!arg_list) return;
    ArgList* list = (ArgList*)arg_list;
    
    Arg* arg = malloc(sizeof(Arg));
    arg->type.nom_type = strdup(type_nom);
    arg->type.is_pointer = is_pointer;
    arg->next = NULL;
    
    if (list->last) {
        list->last->next = arg;
        list->last = arg;
    } else {
        list->first = arg;
        list->last = arg;
    }
    list->count++;
}

void free_arg_list(ArgList* list) {
    if (!list) return;
    Arg* p = list->first;
    while (p) {
        Arg* tmp = p;
        p = p->next;
        free(tmp->type.nom_type);
        free(tmp);
    }
    free(list);
}

void check_identifier_declared(char* name, SymbolTable* table_courante, int ligne) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Identifiant '%s' non déclaré", name);
        erreur(SEMANTIQUE, ligne, msg, name);
    }
}

void check_validate_param(Param* param,SymbolTable* table_courante,int ligne,char* yytext){
    if(param->type.is_pointer==0){
        if(strcmp(param->type.nom_type,strdup("int"))!=0){
            char* msg="Les arguments des fonctions doivent être des pointeurs à l'exception des int.";
            error(SEMANTIQUE,yylineno,msg,yytext);
        }
    }
}

void check_validate_var(Decla* decla,SymbolTable* table_courante,int ligne,char* yytext,char* nom_type){
    if(decla->is_pointer==0){
        if(strcmp(nom_type,strdup("int"))!=0){
            char* msg="Les variables doivent être des pointeurs à l'exception des int.";
            error(SEMANTIQUE,yylineno,msg,yytext);
        }
    }
    if(decla->is_pointer==1 && strcmp(nom_type,strdup("void"))==0){
        char* msg="Les variables ne peuvent pas être de type void*";
        error(SEMANTIQUE,yylineno,msg,yytext);
    }
}

void check_validate_field(Field* field,SymbolTable* table_courante,int ligne,char* yytext){
    if(field->type.is_pointer==0){
        if(strcmp(field->type.nom_type,strdup("int"))!=0){
            char* msg="Les champs des structures doivent être des pointeurs à l'exception des int.";
            error(SEMANTIQUE,yylineno,msg,yytext);
        }
    }
    if(field->type.is_pointer==1 && strcmp(field->type.nom_type,strdup("void"))==0){
        char* msg="Les champs ne peuvent pas être de type void*";
        error(SEMANTIQUE,yylineno,msg,yytext);
    }
}


int check_function_call(char* name, SymbolTable* table_courante, int ligne) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", name);
        erreur(SEMANTIQUE, ligne, msg, name);
        return;
    }
    
    if (s->kind == SYMBOL_STRUCT) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", name);
        erreur(SEMANTIQUE, ligne, msg, name);
    }
    if(s->kind==SYMBOL_VAR){
        char* nom= s->data.var->type.nom_type;
        Symbol* f=ts_lookup(table_courante,nom);
        if (f->kind!=SYMBOL_FONC){
            char msg[256];
            snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", name);
            erreur(SEMANTIQUE, ligne, msg, name);
        }
        if(s->data.var->type.is_pointer==0){
            char msg[256];
            snprintf(msg, sizeof(msg), "'%s' est une variable de fonction sans être un pointeur.", name);
            erreur(SEMANTIQUE, ligne, msg, name);
        }
        free_symbol(f);
        free_symbol(s);
        return 1;
    }
    free_symbol(s);
    return 0;
}

int check_function_call_with_args(char* name, int nb_params,int ligne,SymbolTable* table_courante) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", name);
        erreur(SEMANTIQUE, ligne, msg, name);
        return;
    }
    
    if (s->data.fonc->nb_params != nb_params) {
        char msg[256];
        snprintf(msg, sizeof(msg), 
                 "Nombre de paramètres incorrect pour '%s' : attendu %d, reçu %d",
                 name, s->data.fonc->nb_params, nb_params);
        erreur(SEMANTIQUE, ligne, msg, name);
    }
    if (s->kind == SYMBOL_STRUCT) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", name);
        erreur(SEMANTIQUE, ligne, msg, name);
    }
    if(s->kind==SYMBOL_VAR){
        char* nom= s->data.var->type.nom_type;
        Symbol* f=ts_lookup(table_courante,nom);
        if (f->kind!=SYMBOL_FONC){
            char msg[256];
            snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", name);
            erreur(SEMANTIQUE, ligne, msg, name);
        }
        if(s->data.var->type.is_pointer==0){
            char msg[256];
            snprintf(msg, sizeof(msg), "'%s' est une variable de fonction sans être un pointeur.", name);
            erreur(SEMANTIQUE, ligne, msg, name);
        }
        free_symbol(s);
        free_symbol(f);
        return 1;
    }
    free_symbol(s);
    return 0;
}

DataType check_struct_field_access(char* struct_name, char* field_name, SymbolTable* table_courante, int yylineno) {
    Symbol* s = ts_lookup(table_courante, struct_name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "La variable '%s' n'est pas déclarée.", struct_name);
        erreur(SEMANTIQUE, yylineno, msg, struct_name);
        return NULL;
    }
    
    if (s->kind != SYMBOL_VAR) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une variable", struct_name);
        erreur(TYPE, yylineno, msg, struct_name);
        return NULL;
    }

    if(s->data.var->type.is_pointer==0){
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas un pointeur.", struct_name);
        erreur(TYPE, yylineno, msg, struct_name);
        return NULL;
    }

    symbol_struct=ts_lookup(s->data.var->type.nom_type);
    if (symbol_struct->kind != SYMBOL_STRUCT){
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas de type structure.", struct_name);
        erreur(SEMANTIQUE, yylineno, msg, struct_name);
        return NULL;
    }
    free_symbol(symbol_struct);

    Field* f = s->data.str->champs;
   
    while (f) {
        if (strcmp(f->name, field_name) == 0) {
            type=f->type;
            free_symbol(s);
            return type; /* Champ trouvé */
        }
        f = f->next;
    }
    
    char msg[256];
    snprintf(msg, sizeof(msg), "Champ '%s' non trouvé dans la structure '%s'", 
             field_name, struct_name);
    erreur(SEMANTIQUE, yylineno, msg, field_name);
    free_symbol(s);
    return NULL;
}

void check_return_statement(void* expr_type) {
    if (!current_function) {
        erreur(SEMANTIQUE, 0, 
               "Instruction return en dehors d'une fonction", 
               "return");
        return;
    }
}

void check_return_without_value(void) {
    if (!current_function) {
        erreur(SEMANTIQUE, 0, 
               "Instruction return en dehors d'une fonction", 
               "return");
        return;
    }
    
    if (strcmp(current_function->data.fonc->return_type.nom_type, "void") != 0) {
        erreur(SEMANTIQUE, 0, 
               "return sans valeur dans une fonction qui retourne une valeur", 
               "return");
    }
}

void check_return_with_value(void) {
    if (!current_function) {
        erreur(SEMANTIQUE, 0, 
               "Instruction return en dehors d'une fonction", 
               "return");
        return;
    }
    
    if (strcmp(current_function->data.fonc->return_type.nom_type, "void") == 0) {
        erreur(SEMANTIQUE, 0, 
               "return avec valeur dans une fonction void", 
               "return");
    }
}

void error_direct_struct_access(char* field_name) {
    erreur(SEMANTIQUE, 0, 
           "Accès direct à structure non supporté, utilisez ->", 
           field_name);
}

void error_unsupported(char* feature) {
    erreur(SEMANTIQUE, 0, 
           "Instruction non supportée", 
           feature);
}

void error_redeclaration(char* name, int niveau) {
    char msg[256];
    snprintf(msg, sizeof(msg), 
             "Redéclaration de '%s' dans la même portée (niveau %d)", 
             name, niveau);
    erreur(SEMANTIQUE, 0, msg, name);
}