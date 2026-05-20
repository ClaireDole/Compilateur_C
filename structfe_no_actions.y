%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "erreur.h"
#include "gestion_tables.h"
#include "tablesymb.h"
#include "affichage.h"
#include "gencode.h"
#define DEBUG_ACTION(msg) fprintf(stderr, "DEBUG ligne %d: %s\n", yylineno, msg)

extern int yylineno;
extern int yylex();
extern char* yytext;
extern SymbolTable* table_globale;
extern SymbolTable* table_courante;
extern SymbolTable* table_next;
extern ST_List* liste_tables;
void yyerror(const char *s);
%}

%union {
    char* nom;              /* Pour IDENTIFIER et les noms simples */
    int valeur;             /* Pour CONSTANT */
    DataType type;          /* Pour type_specifier, declaration_specifiers, etc. */
    
    struct {                /* Pour struct_specifier */
        char *name;
        int cas;
    } struct_info;
    
    struct {                /* Pour les déclarateurs (declarator, direct_declarator) */
        char *name;
        int is_pointer;
        int state;
        DataType type;
        ParamList *param_list;
    } decl_info;
    
    struct {                /* Pour les listes de déclarations/champs */
        PointList *list;    /* init_declarator_list, struct_declarator_list */
        FieldList *field_list; /* struct_declaration_list */
        DataType type;
    } list_info;
    
    struct {                /* Pour les expressions (primary, postfix, unary, etc.) */
        DataType type;
        int constante;
        char *fonc;
        char *name;        /* Nom de la variable d'origine si ID */
        char *expr_res;    /* NOM DU TEMPORAIRE OU DE LA VALEUR POUR LE GENCODE */
        int state;
    } expr_info;
    
    struct {                /* Pour les arguments de fonctions */
        int nb_args;
        ArgList *arg_list;
    } arg_info;
    
    struct {                /* Pour les instructions (statement, selection, etc.) */
        DataType ret_type;
        int unique;
        int ligne;
        StatementList *statement_list;
        char *label_res;   /* REQUIS : Pour propager les étiquettes de sauts (ex: IF/WHILE) */
    } stmt_info;
    
    struct {
        DataType type;
        int cas;
        char* name;         /* Pour STRUCT IDENTIFIER */
    } spec_info;
    
    struct {                /* Pour expression_statement (utilisé dans le FOR et IF) */
        DataType type;
        int constante;
        char *fonc;
        char *name;
        int state;
        DataType ret_type;
        int unique;
        int ligne;
        StatementList *statement_list;
        char *expr_res;    /* REQUIS : Pour récupérer la condition ou le résultat de l'init */
    } expr_stmt;
    
    ParamList *p_list;     /* Pour parameter_list */
}
;

%token <nom> IDENTIFIER
%token <valeur> CONSTANT
%token SIZEOF PTR_OP LE_OP GE_OP EQ_OP NE_OP AND_OP OR_OP
%token EXTERN INT VOID STRUCT IF ELSE WHILE FOR RETURN

%type <spec_info> type_specifier
%type <spec_info> declaration_specifiers
%type <struct_info> struct_specifier
%type <decl_info> declarator
%type <decl_info> direct_declarator
%type <decl_info> parameter_declaration
%type <list_info> init_declarator_list 
%type <list_info> struct_declaration 
%type <list_info> struct_declaration_list 
%type <list_info> struct_declarator_list
%type <p_list> parameter_list
%type <expr_info> primary_expression 
%type <expr_info> postfix_expression 
%type <expr_info> unary_expression
%type <expr_info> multiplicative_expression 
%type <expr_info> additive_expression 
%type <expr_info> relational_expression 
%type <expr_info> equality_expression
%type <expr_info> logical_and_expression 
%type <expr_info> logical_or_expression
%type <expr_info> assignment_expression 
%type <expr_info> expression
%type <expr_stmt> expression_statement
%type <arg_info> argument_expression_list
%type <stmt_info> statement 
%type <stmt_info> compound_statement 
%type <stmt_info> compound_statement_fonction 
%type <stmt_info> selection_statement 
%type <stmt_info> iteration_statement 
%type <stmt_info> jump_statement 
%type <stmt_info> statement_list

%nonassoc IFX
%nonassoc ELSE

%glr-parser

%%

program
    : external_declaration
    | program external_declaration
    ;

external_declaration
    : declaration 
    | function_definition 
    ;

declaration
    : declaration_specifiers init_declarator_list ';'{
        DEBUG_ACTION("entree dans declaration");
        fprintf(stderr, "DEBUG declaration: spec cas=%d, list=%p\n", $1.cas, (void*)$2.list);
        if ($2.list == NULL) {
            fprintf(stderr, "ERREUR: $2.list est NULL!\n");
            YYERROR;
        }
        if($1.cas==1){
            char *message="Interdiction des déclarations/affectations.";
            erreur(SEMANTIQUE,yylineno,message,yytext);
        }
        
        if($2.list->count==1){ /* déclaration unique */
            if($1.cas==2){ /* on a STRUCT IDENTIFIER */
                printf("%s", $1.type.nom_type);
                check_identifier_declared($1.type.nom_type,table_courante,yylineno);
                Symbol* st=ts_lookup(table_courante,$1.type.nom_type);
                if(st && st->kind!=SYMBOL_STRUCT){
                    char msg[256];
                    snprintf(msg, sizeof(msg), "%s n'est pas une structure.",$1.type.nom_type);
                    erreur(SEMANTIQUE,yylineno,msg,yytext);
                }
                if($2.list->first->is_pointer==0){
                    char *message="Les structures ne peuvent être manipulées que par des pointeurs.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
            }
            if($1.cas==0 && strcmp("void",$1.type.nom_type)==0){
                if($2.list->first->is_pointer==1 && $2.list->first->state != 5 && $2.list->first->state != 4){
                    char *message="Le pointeur générique void* est interdit.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
            }
            if($2.list->first->state==4){ /* déclaration de fonction prototype */
                Symbol* fonc=new_symbol_fonc($2.list->first->name,$1.type.nom_type,$2.list->first->is_pointer,1);
                
                /* Génération de Code : Émission du prototype */
                emettre_quad("PROTO", $2.list->first->name, $1.type.nom_type, NULL);

                struct Point* premier_noeud = (struct Point*)$2.list->first;
                if (premier_noeud != NULL && premier_noeud->params != NULL) {
                    ParamList* p_list_ptr = (ParamList*)premier_noeud->params;
                    if (p_list_ptr->first != NULL) {
                        Param* courant = p_list_ptr->first;
                        while(courant){
                            check_validate_param(courant,table_courante,yylineno, yytext);
                            add_param_to_function(fonc,courant->type.nom_type,courant->type.is_pointer);
                            
                            /* Génération de Code : Déclaration du type du paramètre dans le proto */
                            emettre_quad("PARAM_TYPE", courant->type.nom_type, NULL, NULL);
                            
                            courant=courant->next;
                        }
                    }
                }
                ts_insert(table_courante,fonc,yylineno);
            }
            if($2.list->first->params==NULL){
                if($1.cas==0 && strcmp("void",$1.type.nom_type)==0){
                    char *message="Les variables ne peuvent pas être de type void.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
                Symbol* var=new_symbol_var($2.list->first->name,$1.type.nom_type,$2.list->first->is_pointer,0);
                ts_insert(table_courante,var,yylineno);
                
                /* Génération de Code : Allocation/Déclaration de variable */
                emettre_quad("DEC", $2.list->first->name, $1.type.nom_type, NULL);
            }
            if($2.list->first->state==5){
                if ($2.list->first->params!= NULL && $2.list->first->params->first!= NULL) {
                    /* Pointeur de fonction: créer un nom unique pour la signature */
                    char sig_name[64];
                    int i = 0;

                    /* Trouver un nom "0_i" libre */
                    do {
                        snprintf(sig_name, 64, "0_%d", i);
                        i++;
                    } while (ts_lookup(table_courante, sig_name)!= NULL);

                    /* Créer la fonction fantôme avec la signature */
                    Symbol* fonc = new_symbol_fonc(sig_name, $1.type.nom_type, $2.list->first->is_pointer, 0);
                    
                    /* Génération de Code : Prototype fantôme intermédiaire */
                    emettre_quad("PROTO", sig_name, $1.type.nom_type, NULL);

                    Param* param_courant = $2.list->first->params->first;
                    while (param_courant) {
                        check_validate_param(param_courant, table_courante, yylineno, yytext);
                        add_param_to_function(fonc, param_courant->type.nom_type, param_courant->type.is_pointer);
                        
                        emettre_quad("PARAM_TYPE", param_courant->type.nom_type, NULL, NULL);
                        param_courant = param_courant->next;
                    }
                    ts_insert(table_courante, fonc, yylineno);

                    /* Créer la variable pointant vers cette signature */
                    Symbol* var = new_symbol_var($2.list->first->name, sig_name, 1, 0);
                    ts_insert(table_courante, var, yylineno);
                    
                    /* Génération de Code : Déclaration du pointeur de fonction */
                    emettre_quad("DEC", $2.list->first->name, "PTR_FONC", NULL);
                }
            }
        } 
        
        if($2.list->count!=1){ /* déclaration multiple */
            if($1.cas==2){ /* on a STRUCT IDENTIFIER */
                check_identifier_declared($1.type.nom_type,table_courante,yylineno);
                Symbol* st=ts_lookup(table_courante,$1.type.nom_type);
                if(st && st->kind!=SYMBOL_STRUCT){
                    char msg[256];
                    snprintf(msg, sizeof(msg), "%s n'est pas une structure.",$1.type.nom_type);
                    erreur(SEMANTIQUE,yylineno,msg,yytext);
                }
            }
            int verif=0;
            Point* courant=$2.list->first;
            while(courant->next!=NULL){
                if(courant->state==4){
                    char *message="Pas de déclaration de fonction dans une déclaration à multiples variables.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
                if((courant->state==5 && courant->next->state!=5) ||(courant->state!=5 && courant->next->state==5)){
                    char *message="On ne mélange pas déclarations de pointeurs de fonctions et déclaration de variables.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
                if(courant->state==5){
                    verif=1;
                }
                courant=courant->next;
            }
            if(courant->state==5) verif=1; /* Vérification sur le dernier élément */

            if(verif==1){ /* déclaration de multiples pointeurs de fonction */
                char sig_name[64];
                int i = 0;
                do {
                    snprintf(sig_name, 64, "0_%d", i);
                    i++;
                } while (ts_lookup(table_courante, sig_name)!= NULL);
                
                Point* crt=$2.list->first;
                if($1.cas==2 && crt->is_pointer==0){
                    char *message="Les structures ne peuvent être manipulées que par des pointeurs.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
                if($1.cas==0 && strcmp("void",$1.type.nom_type)==0){
                    if(crt->is_pointer==1){
                        char *message="Le pointeur générique void* est interdit.";
                        erreur(SEMANTIQUE,yylineno,message,yytext);
                    }
                }
                Symbol* fonc=new_symbol_fonc(sig_name,$1.type.nom_type,crt->is_pointer,0);
                
                emettre_quad("PROTO", sig_name, $1.type.nom_type, NULL);

                Param* param_courant=crt->params->first;
                while (param_courant){
                    check_validate_param(param_courant, table_courante,yylineno,yytext);
                    add_param_to_function(fonc, param_courant->type.nom_type, param_courant->type.is_pointer);
                    emettre_quad("PARAM_TYPE", param_courant->type.nom_type, NULL, NULL);
                    param_courant=param_courant->next;
                }
                ts_insert(table_courante,fonc,yylineno);
                
                Symbol* var=new_symbol_var(crt->name,sig_name,1,0);
                ts_insert(table_courante,var,yylineno);
                emettre_quad("DEC", crt->name, "PTR_FONC", NULL);
                
                crt=crt->next;
                while(crt){
                    if($1.cas==2 && crt->is_pointer==0){
                        char *message="Les structures ne peuvent être manipulées que par des pointeurs.";
                        erreur(SEMANTIQUE,yylineno,message,yytext);
                    }
                    if($1.cas==0 && strcmp("void",$1.type.nom_type)==0){
                        if(crt->is_pointer==1){
                            char *message="Le pointeur générique void* est interdit.";
                            erreur(SEMANTIQUE,yylineno,message,yytext);
                        }
                    }
                    char temp_name[256];
                    snprintf(temp_name, sizeof(temp_name), "%s %d ", sig_name, i + 1);
                    
                    Symbol* test=new_symbol_fonc(temp_name, $1.type.nom_type, crt->is_pointer, 0);
                    Param* p_courant=crt->params->first;
                    while (p_courant){
                        check_validate_param(p_courant, table_courante,yylineno,yytext);
                        add_param_to_function(test, p_courant->type.nom_type, p_courant->type.is_pointer);
                        p_courant=p_courant->next;
                    }
                    /* comparer fonc et test */
                    if(function_comp(fonc,test,yylineno,yytext)!=0){
                        fonc=test;
                        ts_insert(table_courante,fonc,yylineno);
                        
                        emettre_quad("PROTO", temp_name, $1.type.nom_type, NULL);
                        p_courant=crt->params->first;
                        while(p_courant) {
                            emettre_quad("PARAM_TYPE", p_courant->type.nom_type, NULL, NULL);
                            p_courant=p_courant->next;
                        }

                        strncpy(sig_name, temp_name, sizeof(sig_name) - 1);
                        sig_name[sizeof(sig_name) - 1] = '\0';
                        i++;
                    }
                    var=new_symbol_var(crt->name,sig_name,1,0);
                    ts_insert(table_courante,var,yylineno);
                    emettre_quad("DEC", crt->name, "PTR_FONC", NULL);
                    crt=crt->next;
                }  
            }
            if(verif==0){ /* déclaration de multiples variables */
                Point* crt=$2.list->first;
                while(crt){
                    if($1.cas==2 && crt->is_pointer==0){
                        char *message="Les structures ne peuvent être manipulées que par des pointeurs.";
                        erreur(SEMANTIQUE,yylineno,message,yytext);
                    }
                    if($1.cas==0 && strcmp("void",$1.type.nom_type)==0){
                        char *message="Les variables ne peuvent pas être de type void.";
                        erreur(SEMANTIQUE,yylineno,message,yytext);
                    }
                    check_validate_var(crt,table_courante,yylineno,yytext,$1.type.nom_type);
                    Symbol* symbol=new_symbol_var(crt->name,$1.type.nom_type,crt->is_pointer,0);
                    ts_insert(table_courante,symbol,yylineno);
                    
                    /* Génération de Code : Émettre pour chaque variable */
                    emettre_quad("DEC", crt->name, $1.type.nom_type, NULL);
                    
                    crt=crt->next;
                }
            }
        }
    }
    | EXTERN declaration_specifiers init_declarator_list ';'{
        DEBUG_ACTION("entree dans declaration externe");
        if($2.cas==1){
            char *message="Une déclaration externe ne peut pas être définie explicitement.";
            erreur(SEMANTIQUE,yylineno,message,yytext);
        }
        char* type_connu = $2.type.nom_type;
        if($3.list->count==1){ /* déclaration unique */
            if($2.cas==2){ /* on a STRUCT IDENTIFIER */
                Symbol* ex_symbol;
                if(!liste_tables || !liste_tables->first){
                    ex_symbol = ts_lookup(table_globale, type_connu);
                }
                else{
                    ex_symbol = global_lookup(liste_tables, type_connu);
                }
                if(ex_symbol == NULL){
                    ex_symbol = new_symbol_struct(type_connu);
                    ts_insert(table_courante, ex_symbol, yylineno);
                } else {
                    if(ex_symbol->kind != SYMBOL_STRUCT && ex_symbol->kind != SYMBOL_VAR){
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Identifiant '%s' n'est pas un type de structure valide", type_connu);
                        erreur(SEMANTIQUE, yylineno, msg, yytext);
                    }
                }
            }
            if(strcmp("void", type_connu)==0){
                if($3.list->first->is_pointer==1 && $3.list->first->state != 5 && $3.list->first->state != 4){
                    char *message="Le pointeur générique void* est interdit.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
            }
            if($3.list->first->state==4){ /* déclaration de fonction prototype externe */
                Symbol* fonc=new_symbol_fonc($3.list->first->name,type_connu,$3.list->first->is_pointer,1);
                
                /* Génération de Code : Émission du prototype externe */
                emettre_quad("PROTO_EXT", $3.list->first->name, type_connu, NULL);

                if ($3.list->first != NULL && $3.list->first->params != NULL) {
                    ParamList* p_list_ptr = $3.list->first->params;
                    if (p_list_ptr->first != NULL) {
                        Param* courant = p_list_ptr->first;
                        while(courant){
                            check_validate_param(courant,table_courante,yylineno, yytext);
                            add_param_to_function(fonc,courant->type.nom_type,courant->type.is_pointer);
                            
                            emettre_quad("PARAM_TYPE", courant->type.nom_type, NULL, NULL);
                            courant=courant->next;
                        }
                    }
                }
                ts_insert(table_courante,fonc,yylineno);
            }
            if($3.list->first->params==NULL){
                if($2.cas==0 && strcmp("void",type_connu)==0){
                    char *message="Les variables ne peuvent pas être de type void.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
                char* nom_variable = strdup($3.list->first->name); 
                Symbol* var=new_symbol_var(nom_variable, type_connu, $3.list->first->is_pointer, 1);
                ts_insert(table_courante, var, yylineno);
                
                /* Génération de Code : Variable externe */
                emettre_quad("DEC_EXT", nom_variable, type_connu, NULL);
                free(nom_variable);
            }
            if($3.list->first->state==5){
                if ($3.list->first->params!= NULL && $3.list->first->params->first!= NULL) {
                    char sig_name[64];
                    int i = 0;
                    do {
                        snprintf(sig_name, 64, "0_%d", i);
                        i++;
                    } while (ts_lookup(table_courante, sig_name)!= NULL);

                    Symbol* fonc = new_symbol_fonc(sig_name, type_connu, $3.list->first->is_pointer, 0);
                    emettre_quad("PROTO", sig_name, type_connu, NULL);

                    Param* param_courant = $3.list->first->params->first;
                    while (param_courant) {
                        check_validate_param(param_courant, table_courante, yylineno, yytext);
                        add_param_to_function(fonc, param_courant->type.nom_type, param_courant->type.is_pointer);
                        emettre_quad("PARAM_TYPE", param_courant->type.nom_type, NULL, NULL);
                        param_courant = param_courant->next;
                    }
                    ts_insert(table_courante, fonc, yylineno);
                    
                    Symbol* var = new_symbol_var($3.list->first->name, sig_name, 1, 0);
                    ts_insert(table_courante, var, yylineno);
                    emettre_quad("DEC_EXT", $3.list->first->name, "PTR_FONC", NULL);
                }
            }
        }
        
        if($3.list->count!=1){ /* déclaration multiple externe */
            if($2.cas==2){ /* on a STRUCT IDENTIFIER */
                Symbol* multi_symbole=global_lookup(liste_tables,$2.name);
                if(multi_symbole == NULL){
                    char msg[256];
                    snprintf(msg, sizeof(msg), "Identifiant '%s' non déclaré ni dans ce fichier ni aucun précédent", $2.name);
                    warning(SEMANTIQUE, yylineno, msg, yytext); 
                    multi_symbole = new_symbol_var($2.name, "int", 1, 1);
                    ts_insert(table_courante, multi_symbole, yylineno);
                }
                if(multi_symbole->kind!=SYMBOL_VAR){
                    char msg[256];
                    snprintf(msg, sizeof(msg), "Identifiant '%s' n'est pas une variable", yytext);
                    erreur(SEMANTIQUE, yylineno, msg, yytext); 
                }
                if(datatype_comp(multi_symbole->data.var->type,$2.type)==1){
                    char msg[256];
                    snprintf(msg, sizeof(msg), "Identifiant '%s' n'a pas le type correct", yytext);
                    erreur(SEMANTIQUE, yylineno, msg, yytext);
                }
                ts_insert(table_courante,multi_symbole,yylineno);
            }
            int verif=0;
            Point* courant=$3.list->first;
            while(courant->next!=NULL){
                if(courant->state==4){
                    char *message="Pas de déclaration de fonction dans une déclaration à multiples variables.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
                if((courant->state==5 && courant->next->state!=5) ||(courant->state!=5 && courant->next->state==5)){
                    char *message="On ne mélange pas déclarations de pointeurs de fonctions et déclaration de variables.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
                if(courant->state==5){
                    verif=1;
                }
                courant=courant->next;
            }
            if(courant->state==5) verif=1;

            if(verif==1){ /* multi-pointeurs de fonction externes */
                char sig_name[64];
                int i = 0;
                do {
                    snprintf(sig_name, 64, "0_%d", i);
                    i++;
                } while (ts_lookup(table_courante, sig_name)!= NULL);
                
                Point* crt=$3.list->first;
                if($2.cas==2 && crt->is_pointer==0){
                    char *message="Les structures ne peuvent être manipulées que par des pointeurs.";
                    erreur(SEMANTIQUE,yylineno,message,yytext);
                }
                if($2.cas==0 && strcmp("void",type_connu)==0){
                    if(crt->is_pointer==1){
                        char *message="Le pointeur générique void* est interdit.";
                        erreur(SEMANTIQUE,yylineno,message,yytext);
                    }
                }
                Symbol* fonc=new_symbol_fonc(sig_name,type_connu,crt->is_pointer,0);
                emettre_quad("PROTO", sig_name, type_connu, NULL);

                Param* param_courant=crt->params->first;
                while (param_courant){
                    check_validate_param(param_courant, table_courante,yylineno,yytext);
                    add_param_to_function(fonc, param_courant->type.nom_type, param_courant->type.is_pointer);
                    emettre_quad("PARAM_TYPE", param_courant->type.nom_type, NULL, NULL);
                    param_courant=param_courant->next;
                }
                ts_insert(table_courante,fonc,yylineno);
                
                Symbol* var=new_symbol_var(crt->name,sig_name,1,0);
                ts_insert(table_courante,var,yylineno);
                emettre_quad("DEC_EXT", crt->name, "PTR_FONC", NULL);
                
                crt=crt->next;
                while(crt){
                    if($2.cas==2 && crt->is_pointer==0){
                        char *message="Les structures ne peuvent être manipulées que par des pointeurs.";
                        erreur(SEMANTIQUE,yylineno,message,yytext);
                    }
                    if($2.cas==0 && strcmp("void",type_connu)==0){
                        if(crt->is_pointer==1){
                            char *message="Le pointeur générique void* est interdit.";
                            erreur(SEMANTIQUE,yylineno,message,yytext);
                        }
                    }
                    char temp_name[256];
                    snprintf(temp_name, sizeof(temp_name), "%s %d ", sig_name, i + 1);

                    Symbol* test=new_symbol_fonc(temp_name, type_connu, crt->is_pointer, 0);
                    Param* p_courant=crt->params->first;
                    while (p_courant){
                        check_validate_param(p_courant, table_courante,yylineno,yytext);
                        add_param_to_function(test, p_courant->type.nom_type, p_courant->type.is_pointer);
                        p_courant=p_courant->next;
                    }
                    if(function_comp(fonc,test,yylineno,yytext)!=0){
                        fonc=test;
                        ts_insert(table_courante,fonc,yylineno);
                        
                        emettre_quad("PROTO", temp_name, type_connu, NULL);
                        p_courant=crt->params->first;
                        while(p_courant) {
                            emettre_quad("PARAM_TYPE", p_courant->type.nom_type, NULL, NULL);
                            p_courant=p_courant->next;
                        }

                        strncpy(sig_name, temp_name, sizeof(sig_name) - 1);
                        sig_name[sizeof(sig_name) - 1] = '\0';
                        i++;
                    }
                    var=new_symbol_var(crt->name,sig_name,1,0);
                    ts_insert(table_courante,var,yylineno);
                    emettre_quad("DEC_EXT", crt->name, "PTR_FONC", NULL);
                    crt=crt->next;
                }  
            }
            if(verif!=1){ /* multi-variables externes */
                Point* crt=$3.list->first;
                while(crt){
                    if($2.cas==2 && crt->is_pointer==0){
                        char *message="Les structures ne peuvent être manipulées que par des pointeurs.";
                        erreur(SEMANTIQUE,yylineno,message,yytext);
                    }
                    if($2.cas==0 && strcmp("void",type_connu)==0){
                        char *message="Les variables ne peuvent pas être de type void.";
                        erreur(SEMANTIQUE,yylineno,message,yytext);
                    }
                    check_validate_var(crt,table_courante,yylineno,yytext,type_connu);
                    Symbol* symbol=new_symbol_var(crt->name,type_connu,crt->is_pointer,1);
                    ts_insert(table_courante,symbol,yylineno);
                    
                    /* Émission de code pour chaque variable externe de la liste */
                    emettre_quad("DEC_EXT", crt->name, type_connu, NULL);
                    
                    crt=crt->next;
                }
            }
        }
    }
    | declaration_specifiers ';'{
        DEBUG_ACTION("entree dans declaration type seul");
        if($1.cas==0){
            char *message="On ne peut pas déclarer un type de base.";
            erreur(SEMANTIQUE,yylineno,message,yytext);
        }
        if($1.cas==2){
            char *message="On attend une variable à la suite du nom du type.";
            erreur(SEMANTIQUE,yylineno,message,yytext);
        }
    }
    ;

declaration_specifiers
    : type_specifier {
        DEBUG_ACTION("entree dans declaration_specifiers");
        /* Transmission des attributs de type_specifier ($1) vers declaration_specifiers ($$) */
        $$.type.nom_type = $1.type.nom_type;
        $$.type.is_pointer = $1.type.is_pointer;
        $$.cas = $1.cas;
        $$.name = $1.name;
    }
    ;

type_specifier
    : VOID{
        DEBUG_ACTION("entree dans type_specifier void");
        $$.type.nom_type = "void";
        $$.type.is_pointer = 0;
        $$.cas = 0;
        $$.name = NULL;
        }
    | INT{
        DEBUG_ACTION("entree dans type_specifier int");
        $$.type.nom_type = "int";
        $$.type.is_pointer = 0;
        $$.cas = 0;
        $$.name = NULL;
        }
    | struct_specifier {
        DEBUG_ACTION("entree dans type_specifier struct");
        /* Allocation dynamique du nom pour éviter les conflits de mémoire */
        if ($1.name != NULL) {
            $$.type.nom_type = strdup($1.name);
        } else {
            $$.type.nom_type = NULL;
        }
        $$.type.is_pointer = 0;
        $$.cas = $1.cas;
        $$.name = NULL;
    }
    ;

struct_specifier
    : STRUCT IDENTIFIER '{' struct_declaration_list '}' {
        DEBUG_ACTION("entree dans struct_specifier struct id");
        
        Symbol* symbol = ts_lookup(table_courante, $2);
        if (symbol != NULL) {
            if (symbol->kind != SYMBOL_STRUCT) {
                char msg[256];
                snprintf(msg, sizeof(msg), "L'identifiant '%s' est déjà utilisé et n'est pas une structure.", $2);
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
            if (symbol->data.str->champs != NULL) {
                char msg[256];
                snprintf(msg, sizeof(msg), "Redéfinition de la structure '%s' interdite.", $2);
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
        } else {
            symbol = new_symbol_struct($2);
        }
        
        /* Parcours et validation de la liste des champs */
        if ($4.field_list != NULL) {
            Field* field_courant = $4.field_list->first;
            while (field_courant) {
                check_validate_field(field_courant, table_courante, yylineno, yytext, $2);
                add_field_to_struct(symbol, field_courant->name, field_courant->type.nom_type, field_courant->type.is_pointer);
                field_courant = field_courant->next;
            }
        }
        
        $$.name = $2;
        $$.cas = 1;
        
        /* Enregistrement final dans la table des symboles si non présente */
        if (ts_lookup(table_courante, $2) == NULL) {
            ts_insert(table_courante, symbol, yylineno);   
        }
    }
    | STRUCT '{' struct_declaration_list '}' IDENTIFIER {
        DEBUG_ACTION("entree dans struct_specifier struct");
        
        Symbol* symbol = ts_lookup(table_courante, $5);
        if (symbol != NULL) {
            if (symbol->kind != SYMBOL_STRUCT || symbol->data.str->champs != NULL) {
                char msg[256];
                snprintf(msg, sizeof(msg), "L'identifiant '%s' est déjà utilisé ou redéfini.", $5);
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
        } else {
            symbol = new_symbol_struct($5);
            ts_insert(table_courante, symbol, yylineno);
        }
        
        /* Parcours et validation de la liste des champs */
        if ($3.field_list != NULL) {
            Field* field_courant = $3.field_list->first;
            while (field_courant) {
                check_validate_field(field_courant, table_courante, yylineno, yytext, $5);
                add_field_to_struct(symbol, field_courant->name, field_courant->type.nom_type, field_courant->type.is_pointer);
                field_courant = field_courant->next;
            }
        }
        
        $$.name = $5;
        $$.cas = 1;
        
        if (ts_lookup(table_courante, $5) == NULL) {
            ts_insert(table_courante, symbol, yylineno);   
        }
    }
    | STRUCT IDENTIFIER {
        DEBUG_ACTION("entree dans struct id");
        $$.name = $2;
        $$.cas = 2; // Cas de référence simple, le type_specifier s'occupera du reste
    }
    ;

struct_declaration_list
    : struct_declaration {
        DEBUG_ACTION("entree dans struct_declaration");
        $$.field_list = create_field_list();
        
        if ($1.list != NULL) {
            Point* courant = $1.list->first;
            while (courant) {
                if (courant->params != NULL) {
                    /* Cas d'un membre pointeur de fonction */
                    char sig_name[64];
                    int i = 0;
                    do {
                        snprintf(sig_name, 64, "0_%d", i);
                        i++;
                    } while (ts_lookup(table_courante, sig_name) != NULL);
                    
                    /* Création du symbole de fonction pour stocker la signature des paramètres */
                    Symbol* fonc = new_symbol_fonc(sig_name, $1.type.nom_type, $1.type.is_pointer, 0);
                    
                    Param* param_courant = courant->params->first;
                    while (param_courant) {
                        check_validate_param(param_courant, table_courante, yylineno, yytext);
                        add_param_to_function(fonc, param_courant->type.nom_type, param_courant->type.is_pointer);
                        param_courant = param_courant->next;
                    }
                    
                    ts_insert(table_courante, fonc, yylineno);
                    /* Le type du champ devient le nom de la signature masquée, et c'est un pointeur (1) */
                    add_field_to_list($$.field_list, courant->name, sig_name, 1);
                } else {
                    /* Cas d'une variable membre classique */
                    add_field_to_list($$.field_list, courant->name, $1.type.nom_type, courant->is_pointer);
                }
                courant = courant->next;
            }
        }
    }
    | struct_declaration_list struct_declaration {
        DEBUG_ACTION("entree dans struct_declaration_list struct_declaration");
        $$.field_list = $1.field_list;
        
        if ($2.list != NULL) {
            Point* courant = $2.list->first;
            while (courant) {
                if (courant->params != NULL) {
                    /* Cas d'un membre pointeur de fonction */
                    char sig_name[64];
                    int i = 0;
                    do {
                        snprintf(sig_name, 64, "0_%d", i);
                        i++;
                    } while (ts_lookup(table_courante, sig_name) != NULL);
                    
                    /* Correction de cohérence : Utilisation de $2.type (le type de base de la ligne courante) */
                    Symbol* fonc = new_symbol_fonc(sig_name, $2.type.nom_type, $2.type.is_pointer, 0);
                    
                    Param* param_courant = courant->params->first;
                    while (param_courant) {
                        check_validate_param(param_courant, table_courante, yylineno, yytext);
                        add_param_to_function(fonc, param_courant->type.nom_type, param_courant->type.is_pointer);
                        param_courant = param_courant->next;
                    }
                    
                    ts_insert(table_courante, fonc, yylineno);
                    add_field_to_list($$.field_list, courant->name, sig_name, 1);
                } else {
                    /* Cas d'une variable membre classique */
                    add_field_to_list($$.field_list, courant->name, $2.type.nom_type, courant->is_pointer);
                }
                courant = courant->next;
            }
        }
    }
    ;
    
struct_declaration
    : type_specifier struct_declarator_list ';' {
        DEBUG_ACTION("entree dans type spe struct declarator");
        
        /* Propagation du type de base trouvé (ex: "int", "void", "struct Blocs") */
        $$.type = $1.type;
        
        /* Propagation de la liste des champs déclarés sur cette ligne */
        $$.list = $2.list;
    }
    ;

struct_declarator_list
    : declarator {
        DEBUG_ACTION("entree dans declarator");
        
        /* Initialisation d'une nouvelle liste de points temporaire */
        $$.list = create_point_list();
        
        /* Contrôle sémantique : interdit la définition de fonction directe dans une structure */
        if ($1.state == 4) {
            char *message = "Pas de fonction dans les champs d'une structure.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        }
        
        /* Ajout du premier déclarateur à la liste */
        add_point_to_list($$.list, $1.name, $1.is_pointer, $1.param_list, $1.state);
    }
    | struct_declarator_list ',' declarator {
        DEBUG_ACTION("entree dans struct declarator list");
        
        /* Récupération de la liste déjà initialisée à l'étape précédente */
        $$.list = $1.list;
        
        /* Contrôle sémantique sur le nouveau déclarateur */
        if ($3.state == 4) {
            char *message = "Pas de fonction dans les champs d'une structure.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        }
        
        /* Ajout du déclarateur courant à la suite de la liste */
        add_point_to_list($$.list, $3.name, $3.is_pointer, $3.param_list, $3.state);
    }
    ;

init_declarator_list
    : declarator {
        DEBUG_ACTION("entree dans declarator init decla list");
        
        /* Initialisation d'une nouvelle liste de points temporaire */
        $$.list = create_point_list();
        
        /* Ajout du premier déclarateur rencontré à la liste */
        add_point_to_list($$.list, $1.name, $1.is_pointer, $1.param_list, $1.state);
    }
    | init_declarator_list ',' declarator {
        DEBUG_ACTION("entree dans init declarator list");
        
        /* Récupération de la liste existante propagée par la récursion gauche */
        $$.list = $1.list;
        
        /* Ajout du nouveau déclarateur à la suite de la liste */
        add_point_to_list($$.list, $3.name, $3.is_pointer, $3.param_list, $3.state);
    }
    ;

declarator
    : '*' direct_declarator {
        DEBUG_ACTION("entree dans *direct decla");
        
        /* Duplication sécurisée du nom pour isoler la chaîne en mémoire */
        $$.name = strdup($2.name);
        $$.param_list = $2.param_list;
        
        /* Ajustement ou propagation de l'état selon la présence de l'indirection */
        if ($2.state == 0) {
            $$.state = 1; 
        } else {
            $$.state = $2.state; 
        }
        
        /* Contrôle Sémantique : Empêcher le multi-niveau de pointeurs (ex: int **p) */
        if ($2.is_pointer == 1 && $2.state != 3 && $2.state != 4 && $2.state != 5) {
            char *message = "Les pointeurs de pointeurs sont interdits.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        } else {
            $$.is_pointer = 1;
        }
    }
    | direct_declarator {
        DEBUG_ACTION("entree dans direct decla");
        
        /* Propagation simple et transparente de tous les attributs de direct_declarator */
        $$.name = $1.name;
        $$.is_pointer = $1.is_pointer;
        $$.param_list = $1.param_list;
        $$.state = $1.state;
    }
    ;

direct_declarator
    : IDENTIFIER {
        DEBUG_ACTION("entree dans direct decla id");
        $$.name = strdup($1);
        $$.is_pointer = 0;
        $$.state = 0;        /* État initial : variable simple */
        $$.param_list = NULL;
    }
    | '(' declarator ')' {
        DEBUG_ACTION("entree dans direct decla declarator");
        $$.name = $2.name;
        $$.is_pointer = $2.is_pointer;
        $$.param_list = $2.param_list;
        
        /* Si on entoure un pointeur de parenthèses (ex: (*p)), on passe à l'état 3 */
        if ($2.state == 1) {
            $$.state = 3;
        } else {
            $$.state = $2.state;
        }
    }
    | direct_declarator '(' parameter_list ')' %dprec 2 {
        DEBUG_ACTION("entree dans direct decla direct declarator param");
        $$.name = $1.name;
        $$.is_pointer = $1.is_pointer;
        $$.param_list = $3; /* Récupération de la liste des paramètres */
        
        /* Si l'identifiant était un pointeur isolé (*f), cela devient un pointeur de fonction (état 5) */
        if ($1.state == 3) {
            $$.state = 5;
        }
        /* Si c'était une variable simple ou un pointeur classique, cela devient une fonction (état 4) */
        if ($1.state == 0 || $1.state == 1) {
             $$.state = 4;
        }
    }
    | direct_declarator '(' ')' %dprec 1 {
        DEBUG_ACTION("entree dans direct decla direct declarator");
        $$.name = $1.name;
        $$.is_pointer = $1.is_pointer;
        $$.param_list = create_param_list(); /* Liste de paramètres vide */
        
        if ($1.state == 3) {
            $$.state = 5;
        }
        if ($1.state == 0 || $1.state == 1) {
             $$.state = 4;
        }
    }
    | direct_declarator '(' VOID ')' %dprec 1 {
        DEBUG_ACTION("entree dans direct decla direct declarator avec VOID explicite");
        $$.name = $1.name;
        $$.is_pointer = $1.is_pointer;
        $$.param_list = create_param_list(); /* int func(void) équivaut à int func() */
        
        $$.state = ($1.state == 3) ? 5 : 4;
    }
    ;

parameter_list
    : parameter_declaration {
        DEBUG_ACTION("entree dans param list param decla");
        
        /* Initialisation d'une nouvelle liste de paramètres */
        $$ = create_param_list();
        
        /* Ajout du premier paramètre extrait de $1 */
        add_param_to_list($$, $1.name, $1.type.nom_type, $1.type.is_pointer);
    }
    | parameter_list ',' parameter_declaration {
        DEBUG_ACTION("entree dans param list ");
        
        /* Récupération de la liste existante via la récursion gauche */
        $$ = $1;
        
        /* Ajout du paramètre courant extrait de $3 à la suite de la liste */
        add_param_to_list($$, $3.name, $3.type.nom_type, $3.type.is_pointer);
    }
    ;

parameter_declaration
    : declaration_specifiers declarator {
        DEBUG_ACTION("entree dans param declarator ");
        
        /* 1. Contrôles sémantiques initiaux */
        if ($2.state == 4) {
            char *message = "Pas de fonction dans les paramètres d'une fonction.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        }
        if ($1.cas == 1) {
            char *message = "Pas définition de structure dans les paramètres d'une fonction.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        }
        
        /* 2. Validation si le type est une structure */
        if ($1.cas == 2) {
            check_identifier_declared($1.type.nom_type, table_courante, yylineno);
            Symbol* st = ts_lookup(table_courante, $1.type.nom_type);
            if (st == NULL || st->kind != SYMBOL_STRUCT) {
                char msg[256];
                snprintf(msg, sizeof(msg), "%s n'est pas une structure.", $1.type.nom_type);
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
            if ($2.is_pointer == 0) {
                char *message = "Les structures ne peuvent être manipulées que par des pointeurs.";
                erreur(SEMANTIQUE, yylineno, message, yytext);
            }
        }
        
        /* 3. Validation concernant le type void */
        if ($1.cas == 0 && strcmp("void", $1.type.nom_type) == 0) {
            if ($2.is_pointer == 1) {
                char *message = "Le pointeur générique void* est interdit.";
                erreur(SEMANTIQUE, yylineno, message, yytext);
            }
        }
        
        /* 4. Cas d'un paramètre variable standard (pas un pointeur de fonction) */
        if ($2.param_list == NULL) { 
            if ($1.cas == 0 && strcmp("void", $1.type.nom_type) == 0) {
                char *message = "Les variables ne peuvent pas être de type void.";
                erreur(SEMANTIQUE, yylineno, message, yytext);
            }
            $$.type.nom_type = $1.type.nom_type; 
            $$.type.is_pointer = $2.is_pointer;
            $$.name = $2.name; 
        }
        
        /* 5. Cas d'un paramètre de type pointeur de fonction */
        if ($2.state != 4 && $2.param_list != NULL && $1.cas != 2) {
            char name[64];
            int i = 0;
            Symbol* verif;

            /* Génération d'une signature unique masquée */
            do {
                snprintf(name, sizeof(name), "0_%d", i);
                verif = ts_lookup(table_courante, name);
                i++;
            } while (verif != NULL);
            
            /* Création et enregistrement du prototype de fonction masqué */
            Symbol* fonc = new_symbol_fonc(name, $1.type.nom_type, $2.is_pointer, 0);
            Param* param_courant = $2.param_list->first;
            while (param_courant) {
                check_validate_param(param_courant, table_courante, yylineno, yytext);
                add_param_to_function(fonc, param_courant->type.nom_type, param_courant->type.is_pointer);
                param_courant = param_courant->next;
            }
            ts_insert(table_courante, fonc, yylineno);
            
            /* Le type de l'argument devient le nom du prototype masqué */
            $$.type.nom_type = ts_lookup(table_courante, name)->name; 
            $$.type.is_pointer = 1; /* C'est un pointeur de fonction */
            $$.name = $2.name;
        }
    }
    | declaration_specifiers {
        DEBUG_ACTION("entree dans param declarator abstrait (type seul)");
        DataType t;
        t.nom_type = $1.type.nom_type;
        t.is_pointer = 0;
        $$.type = t;
        $$.name = NULL;
    }
    | declaration_specifiers '*' {
        DEBUG_ACTION("entree dans param declarator abstrait pointeur");
        if (strcmp($1.type.nom_type, "void") == 0) {
            char *message = "Le pointeur générique void* est interdit.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        }
        DataType t;
        t.nom_type = $1.type.nom_type;
        t.is_pointer = 1;
        $$.type = t;
        $$.name = NULL;
    }
    ;

primary_expression
    : IDENTIFIER {
        DEBUG_ACTION("entree dans primary id ");
        
        /* 1. Validation sémantique de l'existence du symbole */
        check_identifier_declared($1, table_courante, yylineno);
        Symbol* s = ts_lookup(table_courante, $1);
        
        /* Sécurité : si le symbole n'existe pas, on applique un type par défaut pour éviter un crash */
        if (!s) {
            $$.type = (DataType){"int", 0};
            $$.expr_res = strdup($1);
            $$.constante = 0;
            $$.fonc = NULL;
            $$.state = 0;
            $$.name = strdup($1);
        } else {
            /* Initialisation des attributs par défaut */
            $$.constante = 0;
            $$.fonc = NULL;
            $$.state = 0;
            $$.name = strdup($1);

            /* 2. Traitement sémantique selon la nature sémantique du symbole */
            switch (s->kind) {
                case SYMBOL_VAR:
                    $$.type.nom_type = s->data.var->type.nom_type;
                    $$.type.is_pointer = s->data.var->type.is_pointer;
                    break;
                    
                case SYMBOL_STRUCT: {
                    char* message = "Le symbole est associé à un type structure et non à une variable.";
                    erreur(SEMANTIQUE, yylineno, message, yytext);
                    $$.type = (DataType){"int", 0};
                    break;
                }
                    
                case SYMBOL_FONC:
                    $$.type.nom_type = s->data.fonc->return_type.nom_type;
                    $$.type.is_pointer = s->data.fonc->return_type.is_pointer;
                    $$.fonc = strdup($1); /* Identifié comme une fonction possible à appeler */
                    break;
                    
                default:
                    $$.type = (DataType){"int", 0};
                    break;
            }
            
            /* 3. ACTION DE GÉNÉRATION DE CODE INTERMÉDIAIRE */
            /* On transmet le nom de l'identifiant comme résultat de cette expression */
            $$.expr_res = strdup($1);
        }
    }
    | CONSTANT {
        DEBUG_ACTION("entree dans primary const "); 
        
        /* Configuration sémantique pour une constante entière */
        $$.type = (DataType){"int", 0};
        $$.constante = 1;
        $$.fonc = NULL;
        $$.state = 0;
        $$.name = NULL;
        
        /* ACTION DE GÉNÉRATION DE CODE INTERMÉDIAIRE */
        /* Une constante est convertie en chaîne pour servir de valeur immédiate dans les quads */
        char buf[20];
        snprintf(buf, sizeof(buf), "%d", $1);
        $$.expr_res = strdup(buf);
    }
    | '(' expression ')' %dprec 1 {
        DEBUG_ACTION("entree dans primary expression ");
        
        /* Les parenthèses n'altèrent en rien la sémantique ni le code intermédiaire */
        $$.type = $2.type;
        $$.constante = $2.constante;
        $$.fonc = NULL;
        $$.state = $2.state;
        $$.name = $2.name;
        
        /* Transmission transparente de l'adresse ou de la valeur stockée */
        $$.expr_res = $2.expr_res;
        
        /* Copie globale de la structure de l'expression enfant */
        $$ = $2;
    }
    ;

postfix_expression
    : primary_expression {
        DEBUG_ACTION("entree dans postfix primary ");
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        
        /* Génération de code : Propagation simple du résultat ou de la constante */
        $$.expr_res = $1.expr_res;
    }
    | postfix_expression '(' ')' {
        DEBUG_ACTION("entree dans postfix postfix ");
        if ($1.constante == 1) {
            char* message = "Mauvaise syntaxe d'appel.";
            erreur(SYNTAXE, yylineno, message, yytext);
        }
        if ($1.name == NULL) {
            char* message = "Forme d'appel incorrecte.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        }
        
        int ptr = check_function_call($1.name, table_courante, yylineno);
        $$.state = 1;
        $$.constante = 0;
        $$.fonc = NULL;
        $$.name = NULL;
        
        /* Récupération du type de retour */
        Symbol* fonc = NULL;
        if (ptr == 0) { 
            fonc = ts_lookup(table_courante, $1.name);
        } else {
            Symbol* var = ts_lookup(table_courante, $1.name);
            fonc = ts_lookup(table_globale, var->data.var->type.nom_type);
        }
        
        if (fonc != NULL) {
            if (strcmp(fonc->data.fonc->return_type.nom_type, "void") == 0 && fonc->data.fonc->return_type.is_pointer == 1) {
                char *message = "L'utilisation du type de retour void* est interdite.";
                erreur(SEMANTIQUE, yylineno, message, yytext);
            }
            $$.type.nom_type = strdup(fonc->data.fonc->return_type.nom_type);
            $$.type.is_pointer = fonc->data.fonc->return_type.is_pointer;
        }

        /* ACTION DE GÉNÉRATION DE CODE : Appel sans arguments */
        if (strcmp($$.type.nom_type, "void") == 0 && $$.type.is_pointer == 0) {
            /* Cas d'une fonction void : aucun temporaire requis pour intercepter le retour */
            emettre_quad("CALL", $1.expr_res, NULL, NULL);
            $$.expr_res = NULL;
        } else {
            /* La fonction retourne une valeur : allocation d'un temporaire */
            char* temp = new_temp();
            emettre_quad("CALL_ASSIGN", temp, $1.expr_res, NULL);
            $$.expr_res = temp;
        }
    }
    | postfix_expression '(' argument_expression_list ')' {
        DEBUG_ACTION("entree dans postfix postfix arg");
        if ($1.constante == 1) {
            char* message = "Mauvaise syntaxe d'appel.";
            erreur(SYNTAXE, yylineno, message, yytext);
        }
        if ($1.name == NULL) {
            char* message = "Forme d'appel incorrecte.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        }
        
        int ptr = check_function_call_with_args($1.name, $3.nb_args, yylineno, table_courante);
        $$.state = 1;
        $$.constante = 0;
        $$.fonc = NULL;
        $$.name = NULL;
        
        Symbol* fonc = NULL;
        if (ptr == 0) {
            fonc = ts_lookup(table_courante, $1.name);
        } else {
            Symbol* var = ts_lookup(table_courante, $1.name);
            fonc = ts_lookup(table_globale, var->data.var->type.nom_type);
        }
        
        if (fonc != NULL) {
            if (strcmp(fonc->data.fonc->return_type.nom_type, "void") == 0 && fonc->data.fonc->return_type.is_pointer == 1) {
                char *message = "L'utilisation du type de retour void* est interdite.";
                erreur(SEMANTIQUE, yylineno, message, yytext);
            }
            
            /* Vérification des types des arguments transmis */
            if ($3.arg_list != NULL) {
                Arg* arg_courant = $3.arg_list->first;
                Param* param_courant = fonc->data.fonc->params;
                while (arg_courant && param_courant) {
                    if (datatype_comp(arg_courant->type, param_courant->type) != 0) {
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Champ '%s' n'a pas le même type que celui de l'argument %s", param_courant->type.nom_type, yytext);
                        erreur(SEMANTIQUE, yylineno, msg, yytext);
                    }
                    param_courant = param_courant->next;
                    arg_courant = arg_courant->next;
                }
            }
            $$.type.nom_type = strdup(fonc->data.fonc->return_type.nom_type);
            $$.type.is_pointer = fonc->data.fonc->return_type.is_pointer;
        }

        /* ACTION DE GÉNÉRATION DE CODE : Appel avec arguments */
        /* 1. Émission des quads ARG pour chaque argument de la liste */
        if ($3.arg_list != NULL) {
            Arg* arg_courant = $3.arg_list->first;
            while (arg_courant) {
                /* On transmet le résultat de l'évaluation de l'argument (stocké dans arg_courant->expr_res) */
                emettre_quad("PARAM", "", arg_courant->expr_res, NULL);
                arg_courant = arg_courant->next;
            }
        }
        
        /* 2. Émission du quad CALL avec le nombre d'arguments converti en chaîne */
        char nb_args_str[12];
        snprintf(nb_args_str, sizeof(nb_args_str), "%d", $3.nb_args);
        
        if (strcmp($$.type.nom_type, "void") == 0 && $$.type.is_pointer == 0) {
            emettre_quad("CALL", $1.expr_res, NULL, NULL);
            $$.expr_res = NULL;
        } else {
            char* temp = new_temp();
            emettre_quad("CALL_ASSIGN", temp, $1.expr_res, NULL);
            $$.expr_res = temp;
        }
    }
    | postfix_expression PTR_OP IDENTIFIER {
        DEBUG_ACTION("entree dans postfix ptr op ");
        if (strcmp($1.type.nom_type, "int") == 0 || strcmp($1.type.nom_type, "void") == 0) {
            char* msg = "Le membre gauche n'a pas le bon type.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        char* name = $1.type.nom_type;
        check_identifier_declared(name, table_courante, yylineno);
        Symbol* s = ts_lookup(table_courante, name);
        if (s == NULL || s->kind != SYMBOL_STRUCT) {
            char msg[256];
            snprintf(msg, sizeof(msg), "'%s' n'est pas de type structure.", name);
            erreur(SEMANTIQUE, yylineno, msg, name);
        }
        if ($1.type.is_pointer == 0) {
            char* msg = "Les structures ne sont manipulables que par pointeur.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        /* Vérifier que le champ identifier est bien présent dans la structure s */
        Field* f = s->data.str->champs;
        int verif = 0;
        while (f) {
            if (strcmp(f->name, $3) == 0) {
                $$.type = f->type;
                verif = 1;
                break;
            }
            f = f->next;
        }
        if (verif == 0) {
            char msg[256];
            snprintf(msg, sizeof(msg), "Champ '%s' non trouvé dans la structure '%s'", $3, name);
            erreur(SEMANTIQUE, yylineno, msg, $3);
        }
        
        $$.state = 2;
        $$.name = NULL;
        $$.constante = 0;
        $$.fonc = NULL;

        /* ACTION DE GÉNÉRATION DE CODE : Accès au champ via pointeur */
        /* Allocation d'un temporaire pour contenir la valeur extraite du champ */
        char* temp = new_temp();
        /* Quad : GET_FIELD , adresse_base_structure , nom_du_champ , variable_cible */
        emettre_quad("GET_FIELD", temp, $1.expr_res, $3);
        $$.expr_res = temp;
    }
    ;

argument_expression_list
    : assignment_expression {
        DEBUG_ACTION("entree dans arg expr list assignment_expression ");
        
        $$.nb_args = 1;
        $$.arg_list = create_arg_list();
        
        /* Ajout de l'argument à la liste avec ses propriétés sémantiques */
        add_arg_to_list($$.arg_list, $1.type.nom_type, $1.type.is_pointer, $1.state);
        
        /* ACTION DE GÉNÉRATION DE CODE : */
        /* On mémorise le nom du conteneur du résultat (variable, temporaire ou constante) */
        /* dans le nœud qui vient d'être inséré en queue de liste. */
        if ($$.arg_list->last != NULL) {
            $$.arg_list->last->expr_res = strdup($1.expr_res);
        }
    }
    | argument_expression_list ',' assignment_expression {
        DEBUG_ACTION("entree dans arg expr list");
        
        $$.nb_args = $1.nb_args + 1;
        
        /* Récupération et propagation de la liste existante (Complexité en O(1)) */
        $$.arg_list = $1.arg_list;
        
        /* Ajout du nouvel argument */
        add_arg_to_list($$.arg_list, $3.type.nom_type, $3.type.is_pointer, $3.state);
        
        /* ACTION DE GÉNÉRATION DE CODE : */
        /* On mémorise le conteneur du résultat de ce nouvel argument dans le dernier nœud. */
        if ($$.arg_list->last != NULL) {
            $$.arg_list->last->expr_res = strdup($3.expr_res);
        }
    }
    ;

unary_expression
    : postfix_expression {
        DEBUG_ACTION("entree dans unary postfix");
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        
        /* Propagation du conteneur de résultat */
        $$.expr_res = $1.expr_res;
    }
    | '-' unary_expression {
        DEBUG_ACTION("entree dans unary -");
        DataType t = {"int", 0};
        if (datatype_comp(t, $2.type) != 0) {
            char* msg = "Le moins unaire ne s'applique qu'aux entiers.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        $$.type = t;
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 4;
        $$.name = NULL;

        /* ACTION DE GÉNÉRATION DE CODE */
        char* temp = new_temp();
        emettre_quad("NEG", temp, $2.expr_res, NULL);  // temp = -expr
        $$.expr_res = temp;
    }
    | '*' unary_expression {
	    DEBUG_ACTION("entree dans unary *");
	    
	    /* Vérification que l'opérande est valide */
	    if ($2.state != 0 && $2.state != 1 && $2.state != 2 && $2.state != 5) {
		char* msg = "L'opérateur unaire * ne peut pas s'appliquer au membre droit.";
		erreur(SEMANTIQUE, yylineno, msg, yytext);
	    }
	    
	    /* Vérification que c'est bien un pointeur */
	    if ($2.type.is_pointer == 0) {
		char* msg = "Il est possible de déréférencer uniquement les pointeurs.";
		erreur(SEMANTIQUE, yylineno, msg, yytext);
	    }
	    
	    /* Déréférencement d'un pointeur de fonction (state 5) */
	    if ($2.state == 5) {
		if (strcmp($2.type.nom_type, "void") == 0) {
		    char* msg = "Le déréférencement de void* est interdit.";
		    erreur(SEMANTIQUE, yylineno, msg, yytext);
		}
		
		/* Pour un pointeur de fonction, on garde l'adresse comme L-value */
		/* Le type devient le type de retour de la fonction */
		$$.type = $2.type;
		$$.type.is_pointer = 0;  /* Après déréférencement, ce n'est plus un pointeur */
		$$.constante = 0;
		$$.fonc = NULL;
		$$.state = 6;  /* ← L-value (peut être utilisée à gauche de =) */
		$$.name = NULL;
		$$.expr_res = $2.expr_res;  /* On garde l'adresse, on ne charge PAS */
	    }
	    
	    /* Déréférencement d'une variable pointeur normale (state 0, 1, 2) */
	    else if ($2.state == 0 || $2.state == 1 || $2.state == 2) {
		if ($2.constante == 1) {
		    char* msg = "L'opérateur unaire * ne peut pas s'appliquer à une constante.";
		    erreur(SEMANTIQUE, yylineno, msg, yytext);
		}
		
		if (strcmp($2.type.nom_type, "void") == 0) {
		    char* msg = "Le déréférencement de void* est interdit.";
		    erreur(SEMANTIQUE, yylineno, msg, yytext);
		}
		
		/* Cas particulier : pointeur vers structure */
		Symbol* s = ts_lookup(table_courante, $2.type.nom_type);
		if (s && s->kind == SYMBOL_STRUCT) {
		    char* msg = "Les structures ne sont manipulables que par des pointeurs.";
		    erreur(SEMANTIQUE, yylineno, msg, yytext);
		}
		
		/* Cas particulier : pointeur vers fonction (auto-déréférencement) */
		if (s && s->kind == SYMBOL_FONC) {
		    char* msg = "Utilisation de l'auto-déréférencement des pointeurs de fonction déconseillée.";
		    warning(SEMANTIQUE, yylineno, msg, yytext);
		    /* Pour un pointeur de fonction, on garde l'adresse */
		    $$.type = $2.type;
		    $$.type.is_pointer = 0;
		    $$.constante = 0;
		    $$.fonc = NULL;
		    $$.state = 6;  /* L-value */
		    $$.name = NULL;
		    $$.expr_res = $2.expr_res;
		}
		else {
		    /* Cas normal : déréférencement d'un pointeur vers int */
		    /* On retourne une L-value (l'adresse, pas la valeur chargée) */
		    $$.type = $2.type;
		    $$.type.is_pointer = 0;  /* Le résultat n'est plus un pointeur */
		    $$.constante = 0;
		    $$.fonc = NULL;
		    $$.state = 6;  /* ← L-value : peut être utilisée à gauche de = */
		    $$.name = NULL;
		    $$.expr_res = $2.expr_res;  /* On garde l'adresse, PAS de LOAD */
		}
	    }
	    
	    /* Autres cas (ne devrait pas arriver) */
	    else {
		char* msg = "Déréférencement impossible sur cet opérande.";
		erreur(SEMANTIQUE, yylineno, msg, yytext);
	    }
	}
    | '&' unary_expression {
        DEBUG_ACTION("entree dans unary &");
        if ($2.state != 0 && $2.state != 2 && $2.state != 6) {
            char* msg = "L'opérateur & ne peut pas s'appliquer au membre droit.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if ($2.state == 0) {
            if ($2.constante == 1) {
                char* msg = "L'opérateur & ne peut pas s'appliquer à une constante.";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
            if ($2.fonc != NULL) {      
                DataType t_adr;
                t_adr.nom_type = $2.fonc;
                t_adr.is_pointer = 1;
                $$.type = t_adr;
                $$.constante = 0;
                $$.fonc = NULL;
                $$.name = NULL;
                $$.state = 5;
            } else {
                if ($2.type.is_pointer == 1) {
                    char* msg = "Les pointeurs de pointeurs ne sont pas autorisés.";
                    erreur(SEMANTIQUE, yylineno, msg, yytext);
                }
                if (strcmp($2.type.nom_type, "void") == 0) {
                    char* msg = "Pas de pointeur générique.";
                    erreur(SEMANTIQUE, yylineno, msg, yytext);
                }
                $$.type = $2.type;
                $$.type.is_pointer = 1;
                $$.constante = 0;
                $$.fonc = NULL;
                $$.name = NULL;
                $$.state = 5;
            }
        }
        if ($2.state == 2 || $2.state == 6) { 
            DataType t_adr;
            t_adr.nom_type = "int";
            t_adr.is_pointer = 1;
            $$.type = t_adr;
            $$.constante = 0;
            $$.fonc = NULL;
            $$.state = 5;
            $$.name = NULL;
        }

        /* ACTION DE GÉNÉRATION DE CODE (Prise d'adresse) */
        char* temp = new_temp();
        emettre_quad("ASSIGN_ADDR", temp, $2.expr_res, NULL);
        $$.expr_res = temp;
    }
    | SIZEOF '(' unary_expression ')' { 
        DEBUG_ACTION("entree dans unary siweof unary");
        DataType t = {"int", 0};
        $$.type = t;
        $$.constante = 1; /* Devient une constante immédiate */
        $$.fonc = NULL;
        $$.state = 3;
        $$.name = NULL;

        /* ACTION DE GÉNÉRATION DE CODE */
        int size = get_type_size($3.type.nom_type, $3.type.is_pointer);
        char buf[12];
        snprintf(buf, sizeof(buf), "%d", size);
        
        char* temp = new_temp();
        emettre_quad("ASSIGN", temp, buf, NULL);
        $$.expr_res = temp;
    }
    | SIZEOF '(' type_specifier ')' {
        DEBUG_ACTION("entree dans unary sizeof type"); 
        DataType t = {"int", 0};
        $$.type = t;
        $$.constante = 1;
        $$.fonc = NULL;
        $$.state = 3;
        $$.name = NULL;

        /* ACTION DE GÉNÉRATION DE CODE */
        /* Note: Ici, $3 doit correspondre au nom du type extrait de type_specifier */
        int size = get_type_size($3.type.nom_type, $3.type.is_pointer); 
        char buf[12];
        snprintf(buf, sizeof(buf), "%d", size);
        
        char* temp = new_temp();
        emettre_quad("ASSIGN", temp, buf, NULL);
        $$.expr_res = temp;
    }
    ;

multiplicative_expression
    : unary_expression {
        DEBUG_ACTION("entree dans mult unary"); 
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        
        /* Propagation transparente du conteneur de résultat (variable, constante ou temporaire) */
        $$.expr_res = $1.expr_res;
    }
    | multiplicative_expression '*' unary_expression {
        DEBUG_ACTION("entree dans mult *"); 
        DataType t = {"int", 0};
        
        /* Vérifications sémantiques strictes : pas d'opération multiplicative sur pointeur ou structure */
        if (datatype_comp(t, $1.type) != 0) {
            char* msg = "Le membre de gauche n'est pas un int.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if (datatype_comp(t, $3.type) != 0) {
            char* msg = "Le membre de droite n'est pas un int.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        $$.type.nom_type = strdup($1.type.nom_type);
        $$.type.is_pointer = $1.type.is_pointer;
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 8;
        $$.name = NULL;

        /* ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("MUL", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
    }
    | multiplicative_expression '/' unary_expression {
        DEBUG_ACTION("entree dans mult /"); 
        DataType t = {"int", 0};
        
        if (datatype_comp(t, $1.type) != 0) {
            char* msg = "Le membre de gauche n'est pas un int.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if (datatype_comp(t, $3.type) != 0) {
            char* msg = "Le membre de droite n'est pas un int.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        $$.type.nom_type = strdup($1.type.nom_type);
        $$.type.is_pointer = $1.type.is_pointer;
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 8;
        $$.name = NULL;

        /* ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("DIV", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
    }
    ;

additive_expression
    : multiplicative_expression {
        DEBUG_ACTION("entree dans add mult"); 
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        $$.expr_res = $1.expr_res;
    }
    | additive_expression '+' multiplicative_expression { /* On autorise l'arithmétique des pointeurs */
        DEBUG_ACTION("entree dans add +");
        DataType t = {"int", 0};
        
        /* 1. Validations sémantiques */
        if (datatype_comp(t, $1.type) != 0 && $1.type.is_pointer == 0) {
            char* msg = "Le membre de gauche n'est ni un int ni un pointeur.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if (datatype_comp(t, $3.type) != 0 && $3.type.is_pointer == 0) {
            char* msg = "Le membre de droite n'est ni un int ni un pointeur.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if ($1.type.is_pointer == 1 && $3.type.is_pointer == 1) {
            char* msg = "L'addition de deux pointeurs est interdite.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }

        /* 2. Détermination du type du résultat */
        if ($1.type.is_pointer == 1) {
            $$.type.nom_type = strdup($1.type.nom_type);
            $$.type.is_pointer = 1;
        } else if ($3.type.is_pointer == 1) {
            $$.type.nom_type = strdup($3.type.nom_type);
            $$.type.is_pointer = 1;
        } else {
            $$.type.nom_type = "int";
            $$.type.is_pointer = 0;
        }

        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 9;
        $$.name = NULL;
        
        /* 3. ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("ADD", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
    }
    | additive_expression '-' multiplicative_expression { /* On autorise l'arithmétique des pointeurs */
        DEBUG_ACTION("entree dans add -");
        DataType t = {"int", 0};
        
        /* 1. Validations sémantiques */
        if (datatype_comp(t, $1.type) != 0 && $1.type.is_pointer == 0) {
            char* msg = "Le membre de gauche n'est ni un int ni un pointeur.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if (datatype_comp(t, $3.type) != 0 && $3.type.is_pointer == 0) {
            char* msg = "Le membre de droite n'est ni un int ni un pointeur.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        /* 2. Détermination du type selon les règles de la soustraction */
        if ($1.type.is_pointer == 1 && $3.type.is_pointer == 1) {
            /* ex: p1 - p2 -> donne un entier (ptrdiff_t) */
            if (strcmp($1.type.nom_type, $3.type.nom_type) != 0) {
                char* msg = "Soustraction de pointeurs de types incompatibles.";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
            $$.type.nom_type = "int";
            $$.type.is_pointer = 0;
        } 
        else if ($1.type.is_pointer == 1 && $3.type.is_pointer == 0) {
            /* ex: p - 2 -> préserve le type du pointeur original */
            $$.type.nom_type = strdup($1.type.nom_type);
            $$.type.is_pointer = 1;
        } 
        else if ($1.type.is_pointer == 0 && $3.type.is_pointer == 1) {
            char* msg = "Impossible de soustraire un pointeur à un entier.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
            $$.type.nom_type = "int";
            $$.type.is_pointer = 0;
        } 
        else {
            /* int - int -> int */
            $$.type.nom_type = "int";
            $$.type.is_pointer = 0;
        }
        
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 9;
        $$.name = NULL;

        /* 3. ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("SUB", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
    }
    ;

relational_expression
    : additive_expression {
        DEBUG_ACTION("entree dans rel add");
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        $$.expr_res = $1.expr_res;
    }
    | relational_expression '<' additive_expression {
        DEBUG_ACTION("entree dans rel <");
        
        /* 1. Validation sémantique de compatibilité */
        if ($1.type.is_pointer != $3.type.is_pointer || datatype_comp($1.type, $3.type) != 0) {
            char* msg = "Les deux membres doivent être de types compatibles (soit deux int, soit deux pointeurs identiques).";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        /* 2. Le résultat d'une comparaison est toujours un entier (booléen) */
        $$.type = (DataType){"int", 0};
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 10;
        $$.name = NULL;
        
        /* 3. ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("LT", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
	}
    | relational_expression '>' additive_expression {
        DEBUG_ACTION("entree dans rel >");
        
        if ($1.type.is_pointer != $3.type.is_pointer || datatype_comp($1.type, $3.type) != 0) {
            char* msg = "Les deux membres doivent être de types compatibles (soit deux int, soit deux pointeurs identiques).";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        $$.type = (DataType){"int", 0};
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 10;
        $$.name = NULL;
        
        /* ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("GT", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
    }
    | relational_expression LE_OP additive_expression {
        DEBUG_ACTION("entree dans rel <=");
        
        if ($1.type.is_pointer != $3.type.is_pointer || datatype_comp($1.type, $3.type) != 0) {
            char* msg = "Les deux membres doivent être de types compatibles (soit deux int, soit deux pointeurs identiques).";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        $$.type = (DataType){"int", 0};
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 10;
        $$.name = NULL;
        
        /* ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("LE", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
    }
    | relational_expression GE_OP additive_expression {
        DEBUG_ACTION("entree dans rel >=");
        
        if ($1.type.is_pointer != $3.type.is_pointer || datatype_comp($1.type, $3.type) != 0) {
            char* msg = "Les deux membres doivent être de types compatibles (soit deux int, soit deux pointeurs identiques).";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        $$.type = (DataType){"int", 0};
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 10;
        $$.name = NULL;
        
        /* ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("GE", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
    }
    ;

equality_expression
    : relational_expression {
        DEBUG_ACTION("entree dans equ rel");
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        
        /* Propagation transparente du conteneur de résultat */
        $$.expr_res = $1.expr_res;
    }
    | equality_expression EQ_OP relational_expression {
        DEBUG_ACTION("entree dans equ ==");
        
        /* 1. Validation sémantique de compatibilité des types */
        if ($1.type.is_pointer != $3.type.is_pointer || datatype_comp($1.type, $3.type) != 0) {
            char* msg = "Les deux membres doivent être de types compatibles (soit deux int, soit deux pointeurs identiques).";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        /* 2. Le résultat d'une égalité est toujours un entier (0 ou 1) */
        $$.type = (DataType){"int", 0};
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 10;
        $$.name = NULL;
        
        /* 3. ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("EQ", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
    }
    | equality_expression NE_OP relational_expression {
        DEBUG_ACTION("entree dans equ !=");
        
        /* 1. Validation sémantique de compatibilité des types */
        if ($1.type.is_pointer != $3.type.is_pointer || datatype_comp($1.type, $3.type) != 0) {
            char* msg = "Les deux membres doivent être de types compatibles (soit deux int, soit deux pointeurs identiques).";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        /* 2. Le résultat d'une différence est toujours un entier */
        $$.type = (DataType){"int", 0};
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 10;
        $$.name = NULL;
        
        /* 3. ACTION DE GÉNÉRATION DE CODE */
        char *temp = new_temp();
        emettre_quad("NE", temp, $1.expr_res, $3.expr_res);
        $$.expr_res = temp;
    }
    ;

logical_and_expression
    : equality_expression {
        DEBUG_ACTION("entree dans log equ");
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        
        /* Propagation du conteneur de résultat */
        $$.expr_res = $1.expr_res;
    }
    | logical_and_expression AND_OP equality_expression {
        DEBUG_ACTION("entree dans log and");
        DataType t = {"int", 0};
        
        /* 1. Validations sémantiques */
        if ($1.type.is_pointer == 0 && strcmp("int", $1.type.nom_type) != 0) {
            char* msg = "Le membre de gauche n'est ni un int ni un pointeur.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if ($3.type.is_pointer == 0 && strcmp("int", $3.type.nom_type) != 0) {
            char* msg = "Le membre de droite n'est ni un int ni un pointeur.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        /* 2. Type du résultat */
        $$.type = t;
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 10;
        $$.name = NULL;
        
        /* 3. ACTION DE GÉNÉRATION DE CODE : && decompose en IFZ/GOTO */
        char *temp   = new_temp();
        char *l_faux = new_label();
        char *l_fin  = new_label();
        emettre_quad("ASSIGN", temp, "0", NULL);
        emettre_quad("IFZ", l_faux, $1.expr_res, NULL);
        emettre_quad("IFZ", l_faux, $3.expr_res, NULL);
        emettre_quad("ASSIGN", temp, "1", NULL);
        emettre_quad("LABEL", l_faux, NULL, NULL);
        (void)l_fin;
        $$.expr_res = temp;
    }
    ;

logical_or_expression
    : logical_and_expression {
        DEBUG_ACTION("entree dans log or log and");
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        
        /* Propagation du conteneur de résultat */
        $$.expr_res = $1.expr_res;
    }
    | logical_or_expression OR_OP logical_and_expression {
        DEBUG_ACTION("entree dans log or");
        DataType t = {"int", 0};
        
        /* 1. Validations sémantiques des opérandes */
        if ($1.type.is_pointer == 0 && strcmp("int", $1.type.nom_type) != 0) {
            char* msg = "Le membre de gauche n'est ni un int ni un pointeur.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if ($3.type.is_pointer == 0 && strcmp("int", $3.type.nom_type) != 0) {
            char* msg = "Le membre de droite n'est ni un int ni un pointeur.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        /* 2. Mise à jour des attributs sémantiques de l'expression résultante */
        $$.type = t;
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 10;
        $$.name = NULL;
        
        /* 3. ACTION DE GÉNÉRATION DE CODE : || decompose en IFZ/GOTO */
        /* Logique : si gauche != 0 OU droite != 0 alors temp=1, sinon temp=0 */
        char *temp   = new_temp();
        char *l_vrai = new_label();
        char *l_fin  = new_label();
        /* Par défaut : faux */
        emettre_quad("ASSIGN", temp, "0", NULL);
        /* t_g = (gauche == 0) ; si t_g est faux (gauche!=0) -> vrai */
        char *t_g = new_temp();
        emettre_quad("==", t_g, $1.expr_res, "0");
        emettre_quad("IFZ", l_vrai, t_g, NULL);
        /* gauche est faux, tester droite */
        char *t_d = new_temp();
        emettre_quad("==", t_d, $3.expr_res, "0");
        emettre_quad("IFZ", l_vrai, t_d, NULL);
        /* les deux sont faux -> sauter a la fin (temp reste 0) */
        emettre_quad("GOTO", NULL, l_fin, NULL);
        /* l_vrai : au moins un est vrai */
        emettre_quad("LABEL", l_vrai, NULL, NULL);
        emettre_quad("ASSIGN", temp, "1", NULL);
        emettre_quad("LABEL", l_fin, NULL, NULL);
        $$.expr_res = temp;
    }
    ;

assignment_expression
    : logical_or_expression {
        DEBUG_ACTION("entree dans ass log");
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        
        /* Propagation du conteneur de résultat */
        $$.expr_res = $1.expr_res;
    }
    | unary_expression '=' assignment_expression {
        DEBUG_ACTION("entree dans ass");
        
        /* 1. Vérification stricte de la l-value */
        /* Les L-values valides sont :
           - state 0 : variable simple (x)
           - state 2 : accès champ de structure (p->champ)
           - state 6 : variable déréférencée utilisée comme L-value (*p)
        */
        if ($1.state != 0 && $1.state != 2 && $1.state != 6) {
            char* msg = "Le membre de gauche n'est pas une left-value.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        
        if ($1.state == 0 || $1.state == 2) {
            if ($1.constante == 1) {
                char* msg = "Une constante n'est pas une left-value.";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
            if ($1.fonc != NULL) {
                char* msg = "La left-value est un nom de fonction.";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
        }

        /* 2. Validation de la compatibilité des types */
        int ptr = check_function_pointer($1.type, table_courante, yylineno);
        if (ptr == 0) {
            if (datatype_comp($1.type, $3.type) != 0) {
                char* msg = "Le membre de droite et de gauche n'ont pas le même type.";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
        } else {
            if (function_comp(global_lookup(liste_tables, $1.type.nom_type), 
                              global_lookup(liste_tables, $3.type.nom_type), 
                              yylineno, yytext) != 0) {
                char* msg = "Le membre de droite et de gauche n'ont pas le même type.";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
        }

        /* 3. Initialisation des attributs de l'expression d'affectation */
        $$.type.nom_type = $1.type.nom_type ? strdup($1.type.nom_type) : NULL; 
        $$.type.is_pointer = $1.type.is_pointer;
        $$.constante = 0;
        $$.fonc = NULL;
        $$.state = 11;
        $$.name = NULL;

        /* 4. ACTION DE GÉNÉRATION DE CODE */
        /* 
         * Cas 1: Affectation indirecte via pointeur (*p = valeur)
         *   $1.expr_res contient l'adresse (p)
         *   Il faut générer: STORE adresse valeur
         *   Ce qui donne en backend: *adresse = valeur
         */
        if ($1.state == 6) {
            /* *p = valeur : $1.expr_res est l'adresse, $3.expr_res est la valeur */
            emettre_quad("STORE", $1.expr_res, $3.expr_res, NULL);
        }
        /* 
         * Cas 2: Affectation directe (x = valeur)
         *   $1.expr_res est le nom de la variable
         *   Générer: COPY dest src
         */
        else {
            emettre_quad("COPY", $1.expr_res, $3.expr_res, NULL);
        }

        /* 
         * Pour les affectations en chaîne (a = b = 5), on propage la valeur
         * de droite pour qu'elle puisse être utilisée par l'affectation de gauche
         */
        $$.expr_res = $3.expr_res ? strdup($3.expr_res) : NULL;
    }
    ;

expression
    : assignment_expression {
        DEBUG_ACTION("entree dans expr ass");
        $$.type = $1.type;
        $$.constante = $1.constante;
        $$.fonc = $1.fonc;
        $$.state = $1.state;
        $$.name = $1.name;
        
        /* Propagation cruciale du conteneur de résultat pour les règles parentes */
        $$.expr_res = $1.expr_res;
    }
    ;

statement
    : compound_statement {
        DEBUG_ACTION("entree dans statement compound_statement");
        $$.ret_type = $1.ret_type;
        $$.unique = $1.unique;
        $$.ligne = 0;
        
        /* Note: Si compound_statement gère une liste de quads ou un label de fin, */
        /* propagation transparente ici si nécessaire pour le maillage du code. */
    }
    | expression_statement {
        DEBUG_ACTION("entree dans statement exprstatement");
        DataType t = {NULL, 0};
        $$.ret_type = t;
        $$.unique = 0;
        $$.ligne = 0;
    }
    | selection_statement {
        DEBUG_ACTION("entree dans statement select_statement");
        $$.ret_type = $1.ret_type;
        $$.unique = $1.unique;
        $$.ligne = 1;
    }
    | iteration_statement {
        DEBUG_ACTION("entree dans statement it_statement");
        $$.ret_type = $1.ret_type;
        $$.unique = 0;
        $$.ligne = 1;
    }
    | jump_statement {
        DEBUG_ACTION("entree dans statement jump_statement");
        $$.ret_type = $1.ret_type;
        $$.unique = 0;
        $$.ligne = 0;
    }
    ;

compound_statement
    : '{' '}' {
        DEBUG_ACTION("entree dans compound_statement vide");
        DataType t = {NULL, 0};
        $$.ret_type = t;
        $$.unique = 0;
        char* msg = "Bloc vide.";
        warning(SEMANTIQUE, yylineno, msg, yytext);
    }
    | '{' open_scope statement_list '}' {
        DEBUG_ACTION("entree dans compound_statement statement_list");
        /* Ici, statement_list correspond à $3 */
        if ($3.statement_list != NULL && $3.statement_list->first != NULL) { 
            Statement* courant = $3.statement_list->first; 
            DataType ret_type = courant->ret_type; 
            DataType t = {NULL, 0}; 
            $$.unique = 0; 
            
            while (courant) {
                if (datatype_comp(courant->ret_type, t) == 0) { 
                    courant = courant->next; 
                    continue;
                }
                if (datatype_comp(ret_type, t) == 0) { 
                    ret_type = courant->ret_type; 
                }
                if (datatype_comp(courant->ret_type, ret_type) != 0) { 
                    $$.unique = 1; 
                    break;
                }
                courant = courant->next; 
            }
            $$.ret_type = ret_type; 
        } else {
            DataType t = {NULL, 0}; 
            $$.ret_type = t; 
            $$.unique = 0; 
        }
        exit_scope(); 
    }
    | '{' open_scope declaration_list '}' {
        DEBUG_ACTION("entree dans compound_statement decla");
        DataType t = {NULL, 0}; 
        $$.ret_type = t; 
        $$.unique = 0; 
        exit_scope(); 
    }
    | '{' open_scope declaration_list statement_list '}' {
        DEBUG_ACTION("entree dans compound_statement decla et statement_list");
        /* Attention : ici, declaration_list est $3 et statement_list est $4 */
        if ($4.statement_list != NULL && $4.statement_list->first != NULL) { 
            Statement* courant = $4.statement_list->first; 
            DataType ret_type = courant->ret_type; 
            DataType t = {NULL, 0}; 
            $$.unique = 0; 
            
            while (courant) {
                if (datatype_comp(courant->ret_type, t) == 0) { 
                    courant = courant->next; 
                    continue;
                }
                if (datatype_comp(ret_type, t) == 0) { 
                    ret_type = courant->ret_type; 
                }
                if (datatype_comp(courant->ret_type, ret_type) != 0) { 
                    $$.unique = 1; 
                    break;
                }
                courant = courant->next; 
            }
            $$.ret_type = ret_type; 
        } else {
            DataType t = {NULL, 0}; 
            $$.ret_type = t; 
            $$.unique = 0; 
        }
        exit_scope(); 
    }
    ;

open_scope
    : /* vide */ { 
        DEBUG_ACTION("Changement de portee : entree dans un nouveau scope");
        enter_scope(); 
    }
    ;

declaration_list
    : declaration
    | declaration_list declaration
    ;

statement_list
    : statement {
        DEBUG_ACTION("entree dans statement_list statement");
        
        /* 1. Gestion de la liste sémantique interne */
        $$.statement_list = create_statement_list();
        add_statement_to_list($$.statement_list, $1.ret_type, $1.unique);
        
        /* 2. Propagation des attributs sémantiques */
        $$.ret_type = $1.ret_type;
        $$.unique = $1.unique;
        
        /* Note Gencode : Si un statement propage une référence vers un quad, 
           on pourrait l'initialiser ici (ex: $$.first_quad = $1.first_quad;) */
    }
    | statement_list statement {
        DEBUG_ACTION("entree dans statement_list statement_list");
        
        /* 1. Accumulation dans la liste existante */
        $$.statement_list = $1.statement_list;
        add_statement_to_list($$.statement_list, $2.ret_type, $2.unique);
        
        /* 2. Logique d'unification et de détection des conflits de types de retour */
        DataType t_vide = {NULL, 0};
        
        if (datatype_comp($1.ret_type, t_vide) == 0) {
            /* La liste précédente n'avait pas encore de 'return', on prend le type du nouveau statement */
            $$.ret_type = $2.ret_type;
            $$.unique = $2.unique;
        } 
        else if (datatype_comp($2.ret_type, t_vide) != 0 && datatype_comp($1.ret_type, $2.ret_type) != 0) {
            /* Conflit détecté : Deux instructions 'return' renvoient des types différents */
            $$.ret_type = $1.ret_type; 
            $$.unique = 1; // Marqueur de conflit qui sera intercepté lors de la validation de la fonction
        } 
        else {
            /* Les types sont identiques ou le second statement n'est pas un return */
            $$.ret_type = $1.ret_type;
            $$.unique = $1.unique || $2.unique;
        }
        
        /* Note Gencode : Dans le cas d'un chaînage de blocs de quads, on lierait ici 
           la fin de la liste $1 avec le début de la liste $2. */
    }
    ;

expression_statement
    : ';'{ 
        DEBUG_ACTION("entree dans expression_statement vide");
        DataType t = {NULL, 0};
        $$.ret_type = t;
        $$.type = t;       
        $$.state = -1;
        $$.unique = 0;
        $$.ligne = 0;
        
        /* Une instruction vide n'a pas de conteneur de résultat */
        $$.expr_res = NULL;
    }
    | expression ';'{ 
        DEBUG_ACTION("entree dans expression_statement avec expression");
        DataType t = {NULL, 0};
        $$.ret_type = t;
        $$.type = $1.type;     /* On propage le type pour le FOR */
        $$.state = $1.state;   /* On propage le state pour le FOR */
        $$.unique = 0;
        $$.ligne = 0;
        
        /* PROPAGATION CRUCIALE DU RÉSULTAT */
        /* Transmet le nom de la variable ou du temporaire (ex: t0, x) */
        $$.expr_res = $1.expr_res;
    }
    ;

selection_statement
    : IF '(' expression ')' {
        /* mid-rule : on émet IFZ avant le corps du IF */
        char* lf = new_label();
        emettre_quad("IFZ", lf, $3.expr_res, NULL);
        $<nom>$ = lf;
    } statement %prec IFX {
        DEBUG_ACTION("entree dans selection if ");
        DataType t = {"int", 0};
        
        if ($3.state != 10 || datatype_comp(t, $3.type) != 0) {
            char* msg = "La condition n'est pas booléenne.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if ($6.ligne == 1) {
            char* msg = "Plusieurs instructions -> bloc d'instructions avec { }.";
            erreur(SYNTAXE, yylineno, msg, yytext);
        }
        
        $$.ret_type = $6.ret_type;
        $$.unique = 0;
        
        /* On émet le label de fin APRÈS le corps */
        char* label_fin = $<nom>5;
        emettre_quad("LABEL", label_fin, NULL, NULL);
        if (label_fin) free(label_fin);
    }
    | IF '(' expression ')' {
        /* mid-rule 1 : IFZ vers label_else avant le corps du IF */
        char* le = new_label();
        emettre_quad("IFZ", le, $3.expr_res, NULL);
        $<nom>$ = le;
    } statement ELSE {
        /* mid-rule 2 : GOTO label_fin + LABEL label_else avant le corps du ELSE */
        char* lf = new_label();
        emettre_quad("GOTO", NULL, lf, NULL);
        emettre_quad("LABEL", $<nom>5, NULL, NULL);
        if ($<nom>5) free($<nom>5);
        $<nom>$ = lf;
    } statement {
        DEBUG_ACTION("entree dans selection if else");
        DataType t = {"int", 0};
        
        if ($3.state != 10 || datatype_comp(t, $3.type) != 0) {
            char* msg = "La condition n'est pas booléenne.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if ($6.ligne == 1 || $9.ligne == 1) {
            char* msg = "Plusieurs instructions -> bloc d'instructions avec { }.";
            erreur(SYNTAXE, yylineno, msg, yytext);
        }
        
        $$.ret_type = $6.ret_type;
        if (datatype_comp($6.ret_type, $9.ret_type) != 0) {
            $$.unique = 1;
        } else {
            $$.unique = 0;
        }
        
        /* label_fin : fin du IF/ELSE */
        char* label_fin = $<nom>8;
        emettre_quad("LABEL", label_fin, NULL, NULL);
        if (label_fin) free(label_fin);
    }
    ;

iteration_statement
    : FOR '(' expression_statement {
        /* mid-rule 1 : label de début de boucle, après l'init */
        char* label_debut = new_label();
        emettre_quad("LABEL", label_debut, NULL, NULL);
        $<nom>$ = label_debut;
    }
    expression_statement {
        /* mid-rule 2 : IFZ après la condition, AVANT le corps et l'incrément */
        char* lf = new_label();
        if ($5.state != -1 && $5.expr_res != NULL) {
            emettre_quad("IFZ", lf, $5.expr_res, NULL);
        }
        $<nom>$ = lf;
    }
    expression ')' statement {
        DEBUG_ACTION("entree dans it for");
        DataType t = {"int", 0};
        
        if ($5.state != -1) {
            if ($5.state != 10 || datatype_comp(t, $5.type) != 0) {
                char* msg = "La condition du FOR n'est pas booléenne (doit être un entier).";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
        }
        if ($9.ligne == 1) {
            char* msg = "Plusieurs instructions -> bloc d'instructions avec { }.";
            erreur(SYNTAXE, yylineno, msg, yytext);
        }
        
        $$.ret_type.nom_type = $9.ret_type.nom_type ? strdup($9.ret_type.nom_type) : NULL;
        $$.ret_type.is_pointer = $9.ret_type.is_pointer;
        $$.unique = 0;
        
        char* l_deb = $<nom>4;
        char* label_fin = $<nom>6;
        
        /* L'incrément $7 a été émis avant le corps $9 en ordre de parsing.
           On revient au début de boucle, puis on pose le label de sortie. */
        emettre_quad("GOTO", NULL, l_deb, NULL);
        emettre_quad("LABEL", label_fin, NULL, NULL);
        
        if (l_deb) free(l_deb);
        if (label_fin) free(label_fin);
    }
    | WHILE '(' {
        /* mid-rule 1 : label de début avant la condition */
        char* ld = new_label();
        emettre_quad("LABEL", ld, NULL, NULL);
        $<nom>$ = ld;
    } expression ')' {
        /* mid-rule 2 : IFZ après la condition, avant le corps */
        char* lf = new_label();
        emettre_quad("IFZ", lf, $4.expr_res, NULL);
        $<nom>$ = lf;
    } statement {
        DEBUG_ACTION("entree dans while");
        DataType t = {"int", 0};
        if ($4.state != 10 || datatype_comp(t, $4.type) != 0) {
            char* msg = "La condition du WHILE n'est pas booléenne.";
            erreur(SEMANTIQUE, yylineno, msg, yytext);
        }
        if ($7.ligne == 1) {
            char* msg = "Plusieurs instructions -> bloc d'instructions avec { }.";
            erreur(SYNTAXE, yylineno, msg, yytext);
        }
        $$.ret_type = $7.ret_type;
        $$.unique = 0;
        char* l_deb = $<nom>3;
        char* l_fin = $<nom>6;
        emettre_quad("GOTO", NULL, l_deb, NULL);
        emettre_quad("LABEL", l_fin, NULL, NULL);
        if (l_deb) free(l_deb);
        if (l_fin) free(l_fin);
    }
    ;
    
jump_statement
    : RETURN ';' {
        DEBUG_ACTION("entree dans jump return");
        DataType t;
        t.nom_type = "void";
        t.is_pointer = 0;
        
        $$.ret_type = t;
        $$.unique = 0;  
        $$.ligne = 0;
        
        emettre_quad("RETURN", "", "", "");
    }
    | RETURN expression ';' {
        DEBUG_ACTION("entree dans jump return type");
        DataType t;
        if ($2.type.nom_type != NULL) {
            t.nom_type = strdup($2.type.nom_type);
        } else {
            t.nom_type = NULL;
        }
        t.is_pointer = $2.type.is_pointer;
        
        $$.ret_type = t;
        $$.unique = 0;  
        $$.ligne = 0;
        
        emettre_quad("RETURN_VAL", "", $2.expr_res, "");
    }
    ;

function_definition
    : declaration_specifiers declarator {
        Symbol* fonc_pre = new_symbol_fonc($2.name, $1.type.nom_type, $1.type.is_pointer, 0);
        if ($2.param_list != NULL) {
            Param* courant = $2.param_list->first;
            while(courant){
                add_param_to_function(fonc_pre, courant->type.nom_type, courant->type.is_pointer);
                courant = courant->next;
            }
        }
        ts_insert(table_globale, fonc_pre, yylineno);
        
        /* 1. GÉNÉRATION DE CODE : Début de la fonction */
        emettre_quad("FUNC_START", $2.name, "", "");
        
        enter_scope();
        
        if ($2.param_list != NULL) {
            Param* courant = $2.param_list->first;
            while (courant) {
                check_validate_param(courant, table_courante, yylineno, yytext);
                if (courant->name != NULL) {
                    Symbol* var_param = new_symbol_var(courant->name, courant->type.nom_type, courant->type.is_pointer, 0);
                    ts_insert(table_courante, var_param, yylineno);
                    
                    /* 2. GÉNÉRATION DE CODE : Récupération séquentielle des arguments */
                    emettre_quad("PARAM_FETCH", courant->name, "", "");
                }
                courant = courant->next;
            }
        }
    } compound_statement_fonction {
        DEBUG_ACTION("entree dans function_definition decla");
        
        /* 1. Validations sémantiques et de cohérence des retours */
        if ($4.unique == 1) {
            char *message = "Erreur il y a au moins deux types différents au niveau des return dans le corps du texte.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        }
        if ($2.state != 4) {
            char *message = "Mauvaise syntaxe pour la définition d'une fonction.";
            erreur(SYNTAXE, yylineno, message, yytext);
        }
        if ($1.cas == 1) {
            char *message = "Pas de déclaration de structure devant une définition de fonction.";
            erreur(SEMANTIQUE, yylineno, message, yytext);
        }
        if ($1.cas == 2) {
            check_identifier_declared($1.type.nom_type, table_courante, yylineno);
            Symbol* st = ts_lookup(table_courante, $1.type.nom_type);
            if (st->kind != SYMBOL_STRUCT) {
                char msg[256];
                snprintf(msg, sizeof(msg), "%s n'est pas une structure.", $1.type.nom_type);
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
            if ($2.is_pointer == 0) {
                char *message = "Les structures ne peuvent être manipulées que par des pointeurs.";
                erreur(SEMANTIQUE, yylineno, message, yytext);
            }
        }
        
        /* 2. Vérification de la conformité du type de retour */
        DataType type_attendu;
        type_attendu.nom_type = $1.type.nom_type;
        type_attendu.is_pointer = $2.is_pointer;
        
        if (datatype_comp(type_attendu, $4.ret_type) != 0) {
            if (!(strcmp(type_attendu.nom_type, "void") == 0 && type_attendu.is_pointer == 0 && $4.ret_type.nom_type == NULL)) {
                char *message = "Le type de retour de la fonction ne correspond pas au type de retour déclaré.";
                erreur(SEMANTIQUE, yylineno, message, yytext);
            }
        } 
        if ($4.ret_type.nom_type == NULL) { 
            if (!(strcmp(type_attendu.nom_type, "void") == 0)) {
                char *message = "Absence de type de retour"; 
                erreur(SEMANTIQUE, yylineno, message, yytext); 
            }
        }
        if ($1.cas == 0 && strcmp("void", $1.type.nom_type) == 0) {
            if ($2.is_pointer == 1) {
                char *message = "Le pointeur générique void* est interdit.";
                erreur(SEMANTIQUE, yylineno, message, yytext);
            }
        }
        
        /* 3. GÉNÉRATION DE CODE : Fin de la fonction */
        emettre_quad("FUNC_END", $2.name, "", "");
        
        exit_scope();
    }
    ;
    
compound_statement_fonction
    : '{' '}' {
        DEBUG_ACTION("corps fonction vide");
        DataType t = {NULL, 0};
        $$.ret_type = t;
        $$.unique = 0;
        char* msg = "Bloc de fonction vide.";
        warning(SEMANTIQUE, yylineno, msg, yytext);
    }
    | '{' statement_list '}' {
        DEBUG_ACTION("corps fonction : statement_list");
        /* Propagation simple de la liste et de ses propriétés sémantiques */
        $$.statement_list = $2.statement_list;
        $$.ret_type = $2.ret_type;
        $$.unique = $2.unique;
    }
    | '{' declaration_list '}' {
        DEBUG_ACTION("corps fonction : declaration_list");
        DataType t = {NULL, 0};
        $$.ret_type = t;
        $$.unique = 0;
    }
    | '{' declaration_list statement_list '}' {
        DEBUG_ACTION("corps fonction : decla et statement_list");
        
        /* Analyse et unification du type de retour à partir de statement_list ($3) */
        if ($3.statement_list != NULL && $3.statement_list->first != NULL) { 
            Statement* courant = $3.statement_list->first;
            DataType ret_type = courant->ret_type; 
            DataType t = {NULL, 0}; 
            int unique_flag = 0; 
            
            while (courant) {
                if (datatype_comp(courant->ret_type, t) == 0) { 
                    courant = courant->next;
                    continue; 
                }
                if (datatype_comp(ret_type, t) == 0) { 
                    ret_type = courant->ret_type;
                }
                if (datatype_comp(courant->ret_type, ret_type) != 0) { 
                    unique_flag = 1;
                    break;
                }
                courant = courant->next;
            }
            $$.ret_type = ret_type;
            $$.unique = unique_flag; 
        } else {
            DataType t = {NULL, 0};
            $$.ret_type = t; 
            $$.unique = 0; 
        }
    }
    ;
    
%%

void yyerror(const char *s){
    char msg[256];
    snprintf(msg, sizeof(msg), "Erreur syntaxique ligne %d : %s\n", yylineno,s);
    erreur(SYNTAXE,yylineno,msg,yytext);
}
