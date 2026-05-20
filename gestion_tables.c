#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "erreur.h"
#include "tablesymb.h"
#include "gestion_tables.h"
#include "affichage.h"

extern int yylineno;
extern char* yytext;

void enter_scope(void) {
    SymbolTable* new_scope = new_symbol_table(table_courante, 
                                               table_courante ? table_courante->niveau + 1 : 1, 
                                               100);
    if (!new_scope) {
        fprintf(stderr, "Erreur: Impossible de créer une nouvelle portée\n");
        exit(1);
    }
    if (table_next) {
        table_next->next = new_scope;
    }
    table_next=new_scope;    
    table_courante = new_scope;
}

void exit_scope(void) {
    if (table_courante && table_courante->parent) {
        table_courante = table_courante->parent;
    }
}

PointList* create_point_list(void) {
    PointList* list = malloc(sizeof(PointList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return list;
}

void add_point_to_list(PointList* decla_list, char* name, int is_pointer, ParamList* param,int state) {
    if (!decla_list) return;
    PointList* list = (PointList*)decla_list;
    
    Point* new_decla = malloc(sizeof(Point));
    new_decla->name = strdup(name);
    new_decla->is_pointer = is_pointer;
    new_decla->next = NULL;
    new_decla->params=param;
    new_decla->state=state;
    
    if (list->last) {
        list->last->next = new_decla;
        list->last = new_decla;
    } else {
        list->first = new_decla;
        list->last = new_decla;
    }
    list->count++;
}

void free_point_list(PointList* list) {
    if (!list) return;
    Point* p = list->first;
    while (p) {
        Point* tmp = p;
        p = p->next;
        if (tmp->name) free(tmp->name);
        if (tmp->params) free_param_list(tmp->params); 
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

void add_param_to_list(ParamList* param_list,char* var_name, char* type_nom, int is_pointer) {
    if (!param_list) return;
    ParamList* list = (ParamList*)param_list;
    
    Param* new_param = malloc(sizeof(Param));
    new_param->name = var_name ? strdup(var_name) : NULL;
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
        if (tmp->name) free(tmp->name);
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

void add_field_to_list(FieldList* field_list,char* name,char* type_nom, int is_pointer) {
    if (!field_list) return;
    FieldList* list = (FieldList*)field_list;
    
    Field* field = malloc(sizeof(Field));
    field->type.nom_type = strdup(type_nom);
    field->type.is_pointer = is_pointer;
    field->name = strdup(name);
    field->next = NULL;
    field->offset = 0;
    
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
        free(tmp->name);
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

void add_arg_to_list(ArgList* arg_list, char* type_nom, int is_pointer, int state) {
    if (!arg_list) return;
    ArgList* list = (ArgList*)arg_list;
    
    Arg* arg = malloc(sizeof(Arg));
    arg->type.nom_type = strdup(type_nom);
    arg->type.is_pointer = is_pointer;
    arg->state=state;
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

StatementList* create_statement_list(void){
    StatementList* list = malloc(sizeof(StatementList));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return list;
}
void add_statement_to_list(StatementList* arg_list, DataType ret_type, int unique){
    if (!arg_list) return;
    StatementList* list = (StatementList*)arg_list;
    
    Statement* arg = malloc(sizeof(Statement));
    arg->ret_type=ret_type;
    arg->unique=unique;
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
void free_statement_list(StatementList* list){
    if (!list) return;
    Statement* p = list->first;
    while (p) {
        Statement* tmp = p;
        p = p->next;
        free_data_type(tmp->ret_type);
        free(tmp);
    }
    free(list);
}

void check_identifier_declared(char* name, SymbolTable* table_courante, int ligne) {
    Symbol* s = ts_lookup(table_courante, name);
    //afficher_symbol_table(table_courante);
    if (s==NULL) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Identifiant '%s' non déclaré", name);
        erreur(SEMANTIQUE, ligne, msg, name);
    }
}

int check_function_pointer(DataType type, SymbolTable* table_courante,int ligne){
    if (strcmp("int", type.nom_type) == 0) return 0;
    if (strcmp("void", type.nom_type) == 0) return 0;
    if(type.is_pointer==0){
        return 0;
    }
    Symbol* s=ts_lookup(table_courante,type.nom_type);
    if (s == NULL) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Identifiant '%s' non déclaré", type.nom_type);
        erreur(SEMANTIQUE, ligne, msg, type.nom_type);
        return 0; 
    }
    switch(s->kind){
        case SYMBOL_FONC:
            return 1;
            break;
        case SYMBOL_STRUCT:
            return 0;
            break;
        case SYMBOL_VAR:
            {char msg[256];
            snprintf(msg, sizeof(msg), "Identifiant '%s' est une variable et non un type", type.nom_type);
            erreur(SEMANTIQUE, ligne, msg, type.nom_type);
            break;}
        default : break;
    }
    return 0;
}

/*Reprendre les validates avec les pointeurs de fonctions : si nom_type correspond à une fonction on analse le type retour de cette fonction... */
void check_validate_param(Param* param,SymbolTable*table_courante,int ligne,char* yytext){
    if (strcmp(param->type.nom_type, "void") == 0 && param->type.is_pointer == 0) {
        return;
    }
    int i=check_function_pointer(param->type,table_courante,ligne);
    if(i==0){
    if(param->type.is_pointer==0){
        if(strcmp(param->type.nom_type,"int")!=0){
            char* msg="Les arguments des fonctions doivent être des pointeurs à l'exception des int.";
            erreur(SEMANTIQUE,yylineno,msg,yytext);
        }
    }
    }else{
        Symbol* s=ts_lookup(table_courante,param->type.nom_type);
        if(s->data.fonc->return_type.is_pointer==0){
        if(strcmp(s->data.fonc->return_type.nom_type,"int")!=0){
            char* msg="Les arguments des fonctions doivent être des pointeurs à l'exception des int.";
            erreur(SEMANTIQUE,yylineno,msg,yytext);
        }
    }
    }
}

void check_validate_var(Point* decla,SymbolTable*table_courante,int ligne,char* yytext,char* nom_type){
    DataType t={nom_type,decla->is_pointer};
    int i=check_function_pointer(t,table_courante,ligne);
    if(i==0){
        if(decla->is_pointer==0){
            if(strcmp(nom_type,"int")!=0){
                char* msg="Les variables doivent être des pointeurs à l'exception des int.";
                erreur(SEMANTIQUE,yylineno,msg,yytext);
            }
        }
        if(strcmp(nom_type,"void")==0){
            char* msg="Les variables ne peuvent pas être de type void";
            erreur(SEMANTIQUE,yylineno,msg,yytext);
        }
    }else{
        Symbol* s=ts_lookup(table_courante,nom_type);
        if (!s || s->kind != SYMBOL_FONC) return;
        if(strcmp(s->data.fonc->return_type.nom_type,"void")==0){
            if(s->data.fonc->return_type.is_pointer==1){
                char* msg="Le pointeur général void* est interdit.";
                erreur(SEMANTIQUE,yylineno,msg,yytext);
            }
        }
        if(s->data.fonc->return_type.is_pointer==0){
            if(strcmp(s->data.fonc->return_type.nom_type, "int") != 0){
                char msg[256];
                snprintf(msg, sizeof(msg), "Le type retourné par la fonction '%s' n'est pas correct, seul les int peuvent ne pas être des pointeurs.",nom_type);
                erreur(SEMANTIQUE, ligne, msg, yytext);
            }
        }
    }
}

void check_validate_field(Field* field,SymbolTable* table_courante,int ligne,char* yytext,char* structe){
    if(field->type.is_pointer==0){
        if(strcmp(field->type.nom_type,"int")!=0){
            char* msg="Les champs des structures doivent être des pointeurs à l'exception des int.";
            erreur(SEMANTIQUE,yylineno,msg,yytext);
        }
    }
    if(field->type.is_pointer==1 && strcmp(field->type.nom_type,"void")==0){
        char* msg="Les champs ne peuvent pas être de type void*";
        erreur(SEMANTIQUE,yylineno,msg,yytext);
    }
    if(strcmp(field->type.nom_type,structe)==0){
        printf("valide");
        return;
    }
    if(check_function_pointer(field->type,table_courante,ligne)==1){
        Symbol* s=ts_lookup(table_courante,field->type.nom_type);
        if(s->data.fonc->return_type.is_pointer==0){
            if(strcmp(s->data.fonc->return_type.nom_type,"int")!=0){
                char* msg="Les champs des structures doivent être des pointeurs à l'exception des int.";
                erreur(SEMANTIQUE,yylineno,msg,yytext);
            }
        }
        if(strcmp(s->data.fonc->return_type.nom_type,"void")==0){
            char* msg="Les champs ne peuvent pas être de type void.";
            erreur(SEMANTIQUE,yylineno,msg,yytext);
        }
    }
}


int check_function_call(char* name, SymbolTable* table_courante, int ligne) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", name);
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
            snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction ni un pointeur de fonction", name);
            erreur(SEMANTIQUE, ligne, msg, name);
        }
        if(s->data.var->type.is_pointer==0){
            char msg[256];
            snprintf(msg, sizeof(msg), "'%s' est une variable de fonction sans être un pointeur.", name);
            erreur(SEMANTIQUE, ligne, msg, name);
        }
        return 1;
    }
    return 0;
}

int check_function_call_with_args(char* name, int nb_params,int ligne,SymbolTable* table_courante) {
    Symbol* s = ts_lookup(table_courante, name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", name);
        erreur(SEMANTIQUE, ligne, msg, name);
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
        return 1;
    }
    return 0;
}

DataType check_struct_field_access(char* struct_name, char* field_name, SymbolTable* table_courante, int yylineno) {
    Symbol* s = ts_lookup(table_courante, struct_name);
    if (!s) {
        char msg[256];
        snprintf(msg, sizeof(msg), "La variable '%s' n'est pas déclarée.", struct_name);
        erreur(SEMANTIQUE, yylineno, msg, struct_name);
    }
    
    if (s->kind != SYMBOL_VAR) {
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas une variable", struct_name);
        erreur(SEMANTIQUE, yylineno, msg, struct_name);
    }

    if(s->data.var->type.is_pointer==0){
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas un pointeur.", struct_name);
        erreur(SEMANTIQUE, yylineno, msg, struct_name);
    }

    Symbol* symbol_struct=ts_lookup(table_courante,s->data.var->type.nom_type);
    if (!symbol_struct) {
        char msg[256];
        snprintf(msg, sizeof(msg), "Le type de structure '%s' n'est pas défini.", s->data.var->type.nom_type);
        erreur(SEMANTIQUE, yylineno, msg, struct_name);
        DataType t = {NULL, 0};
        return t;
    }
    if (symbol_struct->kind != SYMBOL_STRUCT){
        char msg[256];
        snprintf(msg, sizeof(msg), "'%s' n'est pas de type structure.", struct_name);
        erreur(SEMANTIQUE, yylineno, msg, struct_name);
    }


    Field* f = symbol_struct->data.str->champs;
   
    while (f) {
        if (strcmp(f->name, field_name) == 0) {
            DataType type=f->type;
            return type; /* Champ trouvé */
        }
        f = f->next;
    }
    
    char msg[256];
    snprintf(msg, sizeof(msg), "Champ '%s' non trouvé dans la structure '%s'", field_name, struct_name);
    erreur(SEMANTIQUE, yylineno, msg, field_name);
    DataType t={NULL,0};
    return t;
}


/*Système de typage fort*/
int datatype_comp(DataType t, DataType d){
    if (t.nom_type == NULL && d.nom_type == NULL) return 0;
    if (t.nom_type == NULL || d.nom_type == NULL) return 1;
    if(t.is_pointer!=d.is_pointer){
        return 1;
    }
    if (strcmp(t.nom_type,d.nom_type)!=0){
        return 1;
    }
    return 0;
}

int function_comp(Symbol* f, Symbol* g,int yylineno, char* yytext){
    if(f->kind!=SYMBOL_FONC){
        char msg[256];
        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas une fonction",f->name);
        erreur(SEMANTIQUE, yylineno, msg, yytext);
    }
    if(g->kind!=SYMBOL_FONC){
        char msg[256];
        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas une fonction",g->name);
        erreur(SEMANTIQUE, yylineno, msg, yytext);
    }
    if(datatype_comp(f->data.fonc->return_type,g->data.fonc->return_type)!=0){
                return 1;
            }
    if(f->data.fonc->nb_params!=g->data.fonc->nb_params){
                return 1;
            }
    Param* courantf=f->data.fonc->params;
    Param* courantg=g->data.fonc->params;
    while(courantf){
        if(datatype_comp(courantf->type,courantg->type)!=0){
            return 1;
        }
        courantf=courantf->next;
        courantg=courantg->next;
    }
    return 0;
}

Error_List* create_error_list(void) {
    Error_List* list = malloc(sizeof(Error_List));
    if (!list) return NULL;
    list->first = NULL;
    list->last = NULL;
    list->count = 0;
    return list;
}

void add_error_to_list(Error_List* list, char* name) {
    if (!list) return;
    
    Error_L* arg = malloc(sizeof(Error_L));
    arg->name=name;
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

void free_error_list(Error_List* list) {
    if (!list) return;
    Error_L* p = list->first;
    while (p) {
        Error_L* tmp = p;
        p = p->next;
        if (tmp->name) free(tmp->name);
        free(tmp);
    }
    free(list);
}
ParamList* duplicate_param_list(ParamList* src) {
    if (!src) return NULL;
    ParamList* dst = create_param_list();
    Param* curr = src->first;
    while (curr) {
        add_param_to_list(dst, curr->name, curr->type.nom_type, curr->type.is_pointer);
        curr = curr->next;
    }
    return dst;
}

int get_type_size(char* nom_type, int is_pointer) {
    if (nom_type == NULL) return 0;
    
    /* Si c'est un pointeur, sa taille sur une architecture 64 bits est de 8 octets */
    if (is_pointer) return 8; 
    
    /* Tailles des types primitifs supportés par votre lexeur */
    if (strcmp(nom_type, "int") == 0) return 4;
    if (strcmp(nom_type, "char") == 0) return 1;
    if (strcmp(nom_type, "void") == 0) return 0;
    
    /* Valeur par défaut pour le gencode (structures, etc.) */
    return 4; 
}
