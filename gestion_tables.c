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

void* create_decla_list(void) {
    DeclaList* list = malloc(sizeof(DeclaList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return (void*)list;
}

void add_var_to_list(void* decla_list, char* name, int is_pointer) {
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

void* create_param_list(void) {
    ParamList* list = malloc(sizeof(ParamList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return (void*)list;
}

void add_param_to_list(void* param_list, char* type_nom, int is_pointer) {
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

void* create_field_list(void) {
    FieldList* list = malloc(sizeof(FieldList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return (void*)list;
}

void add_field_to_list(void* field_list, char* type_nom, int is_pointer) {
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

void check_identifier_declared(char* name, SymbolTable* table_courante, int ligne) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Identifiant '%s' non déclaré", name);
        erreur(SEMANTIQUE, ligne, msg, name);
    }
}

void check_function_call(char* name) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", name);
        erreur(SEMANTIQUE, 0, msg, name);
        return;
    }
    
    if (s->kind != SYMBOL_FONC) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", name);
        erreur(SEMANTIQUE, 0, msg, name);
    }
}

void check_function_call_with_args(char* name, int nb_params) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", name);
        erreur(SEMANTIQUE, 0, msg, name);
        return;
    }
    
    if (s->kind != SYMBOL_FONC) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", name);
        erreur(SEMANTIQUE, 0, msg, name);
        return;
    }
    
    if (s->data.fonc->nb_params != nb_params) {
        char msg[256];
        snprintf(msg, sizeof(msg), 
                 "Nombre de paramètres incorrect pour '%s' : attendu %d, reçu %d",
                 name, s->data.fonc->nb_params, nb_params);
        erreur(SEMANTIQUE, 0, msg, name);
    }
}


void check_struct_field_access(char* struct_name, char* field_name) {
    Symbol* s = ts_lookup(table_courante, struct_name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Type de structure '%s' inconnu", struct_name);
        erreur(SEMANTIQUE, 0, msg, struct_name);
        return;
    }
    
    if (s->kind != SYMBOL_STRUCT) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une structure", struct_name);
        erreur(SEMANTIQUE, 0, msg, struct_name);
        return;
    }
    
    Field* f = s->data.str->champs;
    while (f) {
        if (strcmp(f->name, field_name) == 0) {
            return; /* Champ trouvé */
        }
        f = f->next;
    }
    
    char msg[256];
    snprintf(msg, sizeof(msg), "Champ '%s' non trouvé dans la structure '%s'", 
             field_name, struct_name);
    erreur(SEMANTIQUE, 0, msg, field_name);
}

Symbol* get_current_struct(void) {
    return current_struct;
}

void set_current_struct(Symbol* s) {
    current_struct = s;
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