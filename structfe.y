%{
        #include <stdio.h>
        #include <stdlib.h>
        #include <string.h>
        #include "erreur.h"
        #include "tablesymb.h"
    
        extern int yylineno;
        extern char* yytext;
        
        int yylex(void);
        void yyerror(const char *s);
        
        extern SymbolTable* table_globale;
        extern SymbolTable* table_courante;
        
%}


%token <nom> IDENTIFIER 
%token <val> CONSTANT 
%token SIZEOF
%token PTR_OP LE_OP GE_OP EQ_OP NE_OP
%token AND_OP OR_OP
%token EXTERN
%token INT VOID
%token STRUCT 
%token IF ELSE WHILE FOR RETURN
%token <val> FLOTTANT

/* Priorités */
%nonassoc IFX
%nonassoc ELSE
%left OR_OP
%left AND_OP
%left EQ_OP NE_OP
%left '<' '>' LE_OP GE_OP
%left '+' '-'
%left '*' '/'
%right '='
%left '(' ')'
%left PTR_OP '.'

%start program

%destructor { free($$); } <nom>
%destructor { free($$.type_nom); } type_info
%destructor { free($$.name); } decl_info
%destructor { free($$.name); } struct_info

%type <type_info> type_specifier declaration_specifiers
%type <struct_info> struct_specifier
%type <decl_info> declarator direct_declarator
%type <params_info> parameter_list
%type <val> constant

%%

program     
        : external_declaration
        | program external_declaration
        ;

external_declaration
        : function_definition
        | declaration
        | declaration_affectation_statement
        ;

function_definition
        : declaration_specifiers function_declarator compound_statement /*FAIRE UNE ERREUR SI RETURN TYPE not VOID et pas de RETURN*/
            {
                if ($1.type.is_pointer==$2.is_pointer==1){
                        char *message="Les pointeurs de pointeurs ne sont pas acceptés.";
                        erreur(POINTEUR,yylineno,message,yytext);
                    }
                    if ($1.type.is_pointer==$2.is_pointer==0){
                        Symbol* symbol=new_symbol_fonc($2.name,$1.type.nom_type,0,$1.is_extern);
                        Param* param_courant=$2.param_list->first;
                        while (param_courant){
                            check_validate_param(param_courant, table_courante,yylineno,yytext);
                            add_param_to_function(symbol, param_courant->type.nom_type, param_courant->type.is_pointer);
                            param_courant=param_courant->next;
                        }
                        ts_insert(table_courante,symbol,yylineno);
                    }
                    else{
                        Symbol* symbol=new_symbol_fonc($2.name,$1.type.nom_type,0,$1.is_extern);
                        Param* param_courant=$2.param_list->first;
                        while (param_courant){
                            check_validate_param(param_courant, table_courante,yylineno,yytext);
                            add_param_to_function(symbol, param_courant->type.nom_type, param_courant->type.is_pointer);
                            param_courant=param_courant->next;
                        }
                        ts_insert(table_courante,symbol,yylineno);
                        }
                free($2.name);
                free_param_list($2.param_list);
                free_data_type($1.type);
            }
        ;

declaration
        : declaration_specifiers declarator_list ';'
            {
                Decla* courant=$2.list->first;
                while(courant){
                    if ($1.type.is_pointer==courant->is_pointer==1){
                        char *message="Les pointeurs de pointeurs ne sont pas acceptés.";
                        erreur(POINTEUR,yylineno,message,yytext);
                    }
                    if ($1.type.is_pointer==courant->is_pointer==0){
                        check_validate_var(courant,table_courante,yylineno,yytext,$1.type.nom_type);
                        Symbol* symbol=new_symbol_var(courant->name,$1.type.nom_type,0,$1.is_extern);
                        ts_insert(table_courante,symbol,yylineno);
                    }
                    else{
                        check_validate_var(courant,table_courante,yylineno,yytext,$1.type.nom_type);
                        Symbol* symbol=new_symbol_var(courant->name,$1.type.nom_type,1,$1.is_extern);
                        ts_insert(table_courante,symbol,yylineno);
                        }
                    courant=courant->next;
                }
                free($2.name);
                free_data_type($1.type);
            }
        | struct_specifier ';'
            {
                if ($1.name) free($1.name);
            }
        ;

type_specifier /*Et les pointeurs vers les fonctions? */
        : VOID
            {
                DataType t={strdup("void"),0};
                $$=t;
            }
        | INT
            {
                DataType t={strdup("int"),0};
                $$=t;
            }
        | struct_specifier
            {
                DataType t={strdup($1.name),0};
                $$=t;
            }
        |VOID '*'
            {
                DataType t={strdup("void"),1};
                $$=t; 
            }
        | INT '*'
            {
                DataType t={strdup("int"),1};
                $$=t;
            }
        |struct_specifier '*'
            {
                DataType t={strdup($1.name),1};
                $$=t;
            }
        ;

declaration_specifiers
        : EXTERN type_specifier
            {
                $$.type=$2;
                $$.is_extern = 1;
            }
        | type_specifier
            {
                $$.type = $1;
                $$.is_extern = 0;
            }
        ;

declarator
        : '*' direct_declarator
            {
                $$.name = $2.name;
                $$.is_pointer = 1;
                free($2.name);
            }
        | direct_declarator
            {
                $$.name = $1.name;
                $$.is_pointer = 0;
                free($1.name);
            }
        ;

direct_declarator
        : IDENTIFIER
            {
                $$.name = strdup($1);
                $$.is_pointer=0;
                free($1);
            }
        | '(' declarator ')'
            {
                $$.name = $2.name;
                $$.is_pointer = $2.is_pointer;
                free($2.name);
            }

declarator_list
        : declarator
            {
                $$.list = create_decla_list();
                add_var_to_list($$.list, $1.name, $1.is_pointer);
                free($1.name);
            }
        | declarator_list ',' declarator
            {
                $$.list = $1.list;
                add_var_to_list($$.list, $3.name, $3.is_pointer);
                free($3.name);
            }
  ;

function_declarator    
        : IDENTIFIER '(' parameter_list ')'
            {
                $$.name = $1.name;
                $$.is_pointer = 0;
                $$.param_list=$3.param_list;
                free($1.name);
            }
        | IDENTIFIER '(' ')'
            {
                $$.name = $1.name;
                $$.is_pointer = 0;
                $$.param_list=$3.param_list;
                free($1.name);
            }
        |'*' IDENTIFIER '(' ')'
            {
                $$.name = $1.name;
                $$.is_pointer = 1;
                $$.param_list=$3.param_list;
                free($1.name);
            }
        | '*' IDENTIFIER '(' parameter_list ')'
            {
                $$.name = $1.name;
                $$.is_pointer = 1;
                $$.param_list=$3.param_list;
                free($1.name);
            }
        ;
        
parameter_list
        : parameter_declaration
            {
                $$.param_list = create_param_list();
                add_param_to_list($$.param_list, $1.type.nom_type, $1.type.is_pointer);
                free_data_type($1.type);
                free($1.name);
            }
        | parameter_list ',' parameter_declaration
            {
                $$.param_list = $1.param_list;
                add_param_to_list($$.param_list, $3.type.nom_type, $3.type.is_pointer);
                free_data_type($3.type);
                free_param_list($1);
                free($3.name);
            }
        ;

parameter_declaration
        : declaration_specifiers declarator
            {
                if ($1.type.is_pointer==$2.is_pointer==1){
                        char *message="Les pointeurs de pointeurs ne sont pas acceptés.";
                        erreur(POINTEUR,yylineno,message,yytext);
                    }
                    if ($1.type.is_pointer==$2.is_pointer==0){
                        $$.type=$1.type;
                    }
                    else{
                        DataType t={$1.type.nom_type,1};
                        $$.type=t;
                        }
                $$.name = $2.name;
                free($2.name);
                free_data_type($1.type);
            }
        ;

struct_specifier 
        : STRUCT IDENTIFIER IDENTIFIER
            { /*vérifier que $2 est bien une structure déclarée puis déclarer la variable $3 de type structure $2*/
                Symbol* s=ts_lookup(table_courante,$2);
                if (!s){
                    char* message = "La structure n'est pas déclarée.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                if (s->kind != SYMBOL_STRUCT){
                    char* message = "Le nom de la structure ne correspond pas à une structure.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                char* message = "Les structures ne peuvent être manipulées que par des pointeurs.";
                error(SEMANTIQUE,yylineno, message, yytext);
                free_symbol(s);
                free($3);
                free($2);
            }
        | STRUCT IDENTIFIER '*' IDENTIFIER{
            Symbol* s=ts_lookup(table_courante,$2);
                if (!s){
                    char* message = "La structure n'est pas déclarée.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                if (s->kind != SYMBOL_STRUCT){
                    char* message = "Le nom de la structure ne correspond pas à une structure.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                Symbol* symbol=new_symbol_var($3,s->data.str->nom,1,0);
                ts_insert(table_courante,symbol,yylineno);
                free_symbol(s);     
                free($3);
                free($2);
        }
        | EXTERN STRUCT IDENTIFIER IDENTIFIER
            { /*vérifier que $2 est bien une structure déclarée puis déclarer la variable $3 de type structure $2*/
                Symbol* s=ts_lookup(table_courante,$2);
                if (!s){
                    char* message = "La structure n'est pas déclarée.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                if (s->kind != SYMBOL_STRUCT){
                    char* message = "Le nom de la structure ne correspond pas à une structure.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                char* message = "Les structures ne peuvent être manipulées que par des pointeurs.";
                error(SEMANTIQUE,yylineno, message, yytext);
                free_symbol(s);
                free($3);
                free($2);
            }
        | EXTERN STRUCT IDENTIFIER '*'IDENTIFIER{
            Symbol* s=ts_lookup(table_courante,$2);
                if (!s){
                    char* message = "La structure n'est pas déclarée.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                if (s->kind != SYMBOL_STRUCT){
                    char* message = "Le nom de la structure ne correspond pas à une structure.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                Symbol* symbol=new_symbol_var($3,s->data.str->nom,1,1);
                ts_insert(table_courante,symbol,yylineno);
                free_symbol(s);
                free($3);
                free($2);
        }
        | STRUCT '{' struct_declaration_list '}' IDENTIFIER 
            {
                Symbol* symbol=new_symbol_struct($5);
                Field* field_courant=$3.field_list->first;
                while (field_courant){
                    check_validate_field(field_courant,table_courante,yylineno,yytext);
                    add_field_to_struct(symbol, field_courant->name, field_courant->type.nom_type, field_courant->type.is_pointer);
                    field_courant=field_courant->next;
                }
                ts_insert(table_courante,symbol,yylineno);
                free_field_list($3.field_list);
            }
        | STRUCT IDENTIFIER '{' struct_declaration_list '}' 
            {
                Symbol* symbol=new_symbol_struct($2);
                Field* field_courant=$4.field_list->first;
                while (field_courant){
                    check_validate_field(field_courant,table_courante,yylineno,yytext);
                    add_field_to_struct(symbol, field_courant->name, field_courant->type.nom_type, field_courant->type.is_pointer);
                    field_courant=field_courant->next;
                }
                ts_insert(table_courante,symbol,yylineno);
                free_field_list($4.field_list);
            }
        ;

struct_declaration_list
        : struct_declaration {
                $$.field_list = create_field_list();
                add_field_to_list($$.field_list, $1.type.nom_type, $1.type.is_pointer);
                free_data_type($1.type);
                free($1.name);
        }
        | struct_declaration_list struct_declaration {
                $$.field_list = $1.field_list;
                add_field_to_list($$.field_list, $3.type.nom_type, $3.type.is_pointer);
                free_data_type($3.type);
                free($3.name);
        }
        ;

struct_declaration
        : type_specifier declarator ';'
            {
                $$.type=$1.type;
                $$.name=$2.name;
                if ($1.type.is_pointer==$2.is_pointer==1){
                    char *message="Les pointeurs de pointeurs ne sont pas acceptés.";
                    erreur(POINTEUR,yylineno,message,yytext);
                }
                if ($1.type.is_pointer==$2.is_pointer==0){
                    strcm($1)
                }
                else{
                    $$.type.is_pointer=1;
                    }
                free_data_type($1.type);
                free($2.name);
            }
        ;

compound_statement
        : '{' '}'
            {
                enter_scope();
                mess="Le bloc est vide.";
                warning(SEMANTIQUE,yylineno,mess, yytext);
                exit_scope();
            }
        | '{' {enter_scope();} statement_list '}'
            {
                exit_scope();
            }
        | '{'{enter_scope();} declaration_list '}'
            {
                exit_scope();
            }
        | '{' {enter_scope();} declaration_list statement_list '}'
            {
                exit_scope();
            }
        ;

affectation
        : affectation_statement ';'
            {
                $$.name=$1.name;
                $$.type=$1.type;
            }
        | declaration_affectation_statement
            {
                $$.name=$1.name;
                $$.type=$1.type;
            }
        ;

affectation_statement       
        : IDENTIFIER '=' logical_or_expression 
            {
                check_identifier_declared($1);
                Symbol* var=ts_lookup(table_courante,$1);
                switch(struct->kind){
                    case SYMBOL_VAR :
                        break;
                    case SYMBOL_FONC:
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas une variable mais une fonction définie.",$1);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case SYMBOL_STRUCT:
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas une variable mais un type de structure.",$1);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case default : 
                        break;
                }
                if (!(strcmp($3.type.nom_type,strdup("void"))) && $3.type.is_pointer==0){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "On ne peut pas mettre un type void dans une variable",$1);
                        erreur(TYPE, yylineno, msg, yytext);
                }
                if (strcmp(var->data.var->type.nom_type,$3.type.nom_type)!=0){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s est de type %s",$1,var->data.var->type.nom_type);
                        erreur(TYPE, yylineno, msg, yytext);
                }
                if (var->data.var->type.is_pointer!=$3.type.is_pointer){
                    char msg[256];
                    if (var->data.var->type.is_pointer==0){
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas un pointeur.",var->name);
                    }
                    else{
                        snprintf(msg, sizeof(msg), "Le symbole %s est un pointeur.",var->name);
                    }
                    erreur(POINTEUR, yylineno, msg, yytext);
                }
                $$.type=var->data.var->type;
                $$.name=var->name;
                free_symbol(var);
                free_data_type($3.type);
            }
        | IDENTIFIER '=' postfix_expression_function 
        | '&' IDENTIFIER '=' logical_or_expression 
            {
                check_identifier_declared($1);
                Symbol* var=ts_lookup(table_courante,$2);
                switch(struct->kind){
                    case SYMBOL_VAR :
                        break;
                    case SYMBOL_FONC:
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas une variable mais une fonction définie.",$2);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case SYMBOL_STRUCT:
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas une variable mais un type de structure.",$2);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case default : 
                        break;
                }
                if (var->data.var->type.is_pointer==1){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "La variable %s est un pointeur.",var->name);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                }
                if (!(strcmp($4.type.nom_type,strdup("void"))) && $4.type.is_pointer==0){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "On ne peut pas mettre un type void dans une variable");
                        erreur(TYPE, yylineno, msg, yytext);
                }
                if ($4.type.is_pointer==0){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "On attend un pointeur comme valeur pour %s.",var->name);
                        erreur(POINTEUR, yylineno, msg, yytext);
                }
                if (strcmp(var->data.var->type.nom_type,$4.type.nom_type)!=0){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s est de type %s",$2,var->data.var->type.nom_type);
                        erreur(TYPE, yylineno, msg, yytext);
                }
                $$.type=var->data.var->type;
                $$.name=var->name;
                free_symbol(var);
                free_data_type($4.type);
            }
        | '&' IDENTIFIER '=' postfix_expression_function 
        | '*' IDENTIFIER '=' logical_or_expression
            {
                check_identifier_declared($2);
                Symbol* var=ts_lookup(table_courante,$2);
                switch(struct->kind){
                    case SYMBOL_VAR :
                        break;
                    case SYMBOL_FONC:
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas une variable mais une fonction définie.",$2);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case SYMBOL_STRUCT:
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas une variable mais un type de structure.",$2);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case default : 
                        break;
                }
                if (var->data.var->type.is_pointer==0){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "La variable %s est un pointeur.",var->name);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                }
                if (!(strcmp($4.type.nom_type,strdup("void"))) && $4.type.is_pointer==0){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "On ne peut pas mettre un type void dans une variable");
                        erreur(TYPE, yylineno, msg, yytext);
                }
                if ($4.type.is_pointer==1){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "Les pointeurs de pointeurs sont interdits.");
                        erreur(POINTEUR, yylineno, msg, yytext);
                }
                if (strcmp(var->data.var->type.nom_type,$4.type.nom_type)!=0){
                    char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s est de type %s",$2,var->data.var->type.nom_type);
                        erreur(TYPE, yylineno, msg, yytext);
                }
                $$.type=var->data.var->type;
                $$.name=var->name;
                free_symbol(var);
                free_data_type($4.type);
            }
        | '*' IDENTIFIER '=' postfix_expression_function
        ;

declaration_affectation_statement 
        : STRUCT IDENTIFIER IDENTIFIER '=' '{'argument_expression_list'}' ';'
            {
                check_identifier_declared($2,table_courante,yylineno);
                Symbol* struct=ts_lookup($2,table_courante);
                switch(struct->kind){
                    case SYMBOL_VAR :
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas un type de structure mais une variable.",$2);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case SYMBOL_FONC:
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas un type de structure mais une fonction définie.",$2);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case SYMBOL_STRUCT:
                        break;
                    case default : 
                        break;
                }
                char msg[256];
                snprintf(msg, sizeof(msg), "Les variables de type structures doivent être manipulées avec des pointeurs.");
                erreur(SEMANTIQUE, yylineno, msg, yytext);
                free_arg_list($6.arg_list);
                free_symbol(struct);
            }
        | STRUCT IDENTIFIER '*' IDENTIFIER '=' '{'argument_expression_list'}' ';'
        {
                check_identifier_declared($2,table_courante,yylineno);
                Symbol* struct=ts_lookup($2,table_courante);
                switch(struct->kind){
                    case SYMBOL_VAR :
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas un type de structure mais une variable.",$2);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case SYMBOL_FONC:
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Le symbole %s n'est pas un type de structure mais une fonction définie.",$2);
                        erreur(TYPE, yylineno, msg, yytext);
                        break;
                    case SYMBOL_STRUCT:
                        break;
                    case default : 
                        break;
                }
                if($7.nb_args < struct.data.str->nb_champs){
                    char* message="Pas assez d'arguments.";
                    error(FONCTION,yylineno,message,yytext);
                }
                if($7.nb_args > struct.data.str->nb_champs){
                    char* message="Trop d'arguments.";
                    error(FONCTION,yylineno,message,yytext);
                }
                Arg* arg_courant=$7.arg_list->first;
                Field* field_courant=struct->data.str->champs;
                Symbol* symbol=new_symbol_var($4,struct->name,1,0);
                while(arg_courant){
                    if (strcmp(field_courant->type.nom_type,arg_courant->type.nom_type)!=0){
                        char msg[256];
                        snprintf(msg, sizeof(msg), "Champ '%s' n'a pas le même type que celui de l'argument %s",field_courant->type.nom_type,yytext);
                        erreur(TYPE, yylineno, msg, yytext);
                    }
                    else{
                        add_field_to_struct(symbol,field_courant->name,field_courant->type.nom_type,field_courant->type.is_pointer);
                        field_courant=field_courant->next;
                        arg_courant=arg_courant->next;
                    }
                }
                ts_insert(table_courante,symbol,yylineno);
                $$.type=symbol->data.var->type;
                $$.name=symbol->name;
                free_arg_list($7.arg_list);
                free_symbol(struct);
            }
        | type_specifier declarator '=' logical_or_expression
            {
                /*Ne pas autoriser void non pointeur, ne pas autoriser struct_specifier et struct_specifier* 
                il y aussi les postfix_expression_structure dans logical_or_expression */
            }
        | type_specifier declarator '=' postfix_expression_function
            {
                /*vérifier que type retour=type_specifier, vérifier les types des arguments, vérifier que le symbol de postfix_expression_function existe*/
            }
        ;

constant
        : CONSTANT { $$ = $1;}
        | FLOTTANT { $$ = $1;
                char* message = "Les chiffres à virgule ne sont pas autorisés.";
                error(FLOTTANT,yylineno,message,yytext); }
        ;

primary_expression 
        : IDENTIFIER
            {
                check_identifier_declared($1,table_courante,yylineno);
                Symbol* s=ts_lookup(table_courante,$1);
                $$.parenthese=0;
                $$.constante=0;
                switch (s->kind){
                    case SYMBOL_VAR:
                        $$.type=s->var.type;
                        break;
                    case SYMBOL_STRUCT:
                        char* message= "Le symbole est associé à un type structure et non à une variable.";
                        erreur(SYNTAXE,yylineno,message,yytext);
                        break;
                    case SYMBOL_FONC :
                        char* message= "Le symbole est associé à un type fonction et non à une variable.";
                        erreur(SYNTAXE,yylineno,message,yytext);
                        break;
                    case default:
                        break;
                }
                free_symbol(s);
                free($1);
            }
        | constant{
            DataType t={strdup("int"),0};
            $$.type=t;
            $$.parenthese=0;
            $$.constante=1;
            free($1);
        }
        | '(' logical_or_expression ')'{
            $$.type=$2.type;
            $$.parenthese=1;
            $$.contante=$2.constante;
        }
        | '('affectation_statement')'{
            $$.type=$2.type;
            $$.parenthese=1;
            $$.contante=0;
        }
        ;

postfix_expression_structure /*toto->titi() n'est valide que si titi est un pointeur de fonction*/
        : IDENTIFIER '.' IDENTIFIER 
            {
                char* msg="Les structures ne sont manipulables que par pointeur, opérateur . incorrect. Merci d'utiliser ->";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
        | '(' IDENTIFIER ')' '.' IDENTIFIER
            {
                char* msg="Les structures ne sont manipulables que par pointeur, opérateur . incorrect. Merci d'utiliser ->";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
        | postfix_expression_structure '.' IDENTIFIER
            {
                char* msg="Les structures ne sont manipulables que par pointeur, opérateur . incorrect. Merci d'utiliser ->";
                erreur(SEMANTIQUE, yylineno, msg, yytext);
            }
        | IDENTIFIER PTR_OP IDENTIFIER  
            {
                $$.type=check_struct_field_access($1, $3,table_courante,yylineno);
                free($1);
                free($3);
            }
        | '(' IDENTIFIER ')' PTR_OP IDENTIFIER
            {
                $$.type=check_struct_field_access($2,$4,table_courante,yylineno);
                free($2);
                free($4);
            }
        | postfix_expression_structure PTR_OP IDENTIFIER
            {
                /*il faut que $1.type soit un pointeur vers une structure*/
                if($1.type.is_pointer==0){
                    char* msg="Les structures ne sont manipulables que par pointeur.";
                    erreur(SEMANTIQUE, yylineno, msg, yytext);
                }
                if(strcmp($1.type.type_nom,strdup("int"))!=0 && strcmp($1.type.type_nom,strdup("void"))!=0){ /*pas de pointeur vers un type de base*/
                    char* name=$1.type.type_nom;
                    check_identifier_declared(name);
                    Symbol* s=ts_lookup(name,table_courante);
                    if (s->kind != SYMBOL_STRUCT){
                        char msg[256];
                        snprintf(msg, sizeof(msg), "'%s' n'est pas de type structure.", struct_name);
                        erreur(SEMANTIQUE, yylineno, msg, struct_name);
                    }
                    /*vérifier que le champ identifier est bien dans la structure s*/
                    Field* f = s->data.str->champs;
                    while (f) {
                        if (strcmp(f->name, $3) == 0) {
                            $$.type=f->type;
                        }
                        f = f->next;
                    }
                    char msg[256];
                    snprintf(msg, sizeof(msg), "Champ '%s' non trouvé dans la structure '%s'", $3, struct_name);
                    erreur(SEMANTIQUE, yylineno, msg, $3);
                }
                char* msg="Absence de pointeur vers une structure.";
                erreur(TYPE, yylineno, msg, yytext);
            }
        ;

argument_expression_list
        : logical_or_expression
            {
                $$.nb_args = 1;
                $$.arg_list = create_arg_list();
                add_arg_to_list($$.arg_list, $1.type.nom_type, $1.type.is_pointer);
                free_data_type($1.type);
                free($1.name);
            }
        | argument_expression_list ',' logical_or_expression
            {
                $$.nb_args = $1.nb_args + 1;
                $$.arg_list = $1.arg_list;
                add_arg_to_list($$.arg_list, $3.type.nom_type, $3.type.is_pointer);
                free_data_type($3.type);
                free_arg_list($1);
                free($3.name);
            }
        |affectation_statement
            {
                $$.nb_args = 1;
                $$.arg_list = create_arg_list();
                add_arg_to_list($$.arg_list, $1.type.nom_type, $1.type.is_pointer);
                free_data_type($1.type);
                free($1.name);
            }
        |argument_expression_list ','affectation_statement
            {
                $$.nb_args = $1.nb_args + 1;
                $$.arg_list = $1.arg_list;
                add_arg_to_list($$.arg_list, $3.type.nom_type, $3.type.is_pointer);
                free_data_type($3.type);
                free_arg_list($1);
                free($3.name);
            }
        |postfix_expression_function
            {
                $$.nb_args = 1;
                $$.arg_list = create_arg_list();
                add_arg_to_list($$.arg_list, $1.type.nom_type, $1.type.is_pointer);
                free_data_type($1.type);
                free($1.name);
            }
        |argument_expression_list ','postfix_expression_function
            {
                $$.nb_args = $1.nb_args + 1;
                $$.arg_list = $1.arg_list;
                add_arg_to_list($$.arg_list, $3.type.nom_type, $3.type.is_pointer);
                free_data_type($3.type);
                free_arg_list($1);
                free($3.name);
            }
        ;

simple
        : IDENTIFIER '(' ')'
            {   /*L'affectation du résultat d'une fonction est facultative.*/
                int ptr=check_function_call($1,table_courante,yylineno);
                if (ptr==0){
                    Symbol* fonc=ts_lookup(table_courante,$1);
                    $$.name=$1;
                    $$.pointeur=0;
                    $$.type=fonc->data.fonc->return_type;
                    free_symbol(fonc);
                } else {
                    Symbol* var= ts_lookup(table_courante,$1);
                    $$.pointeur=1;
                    Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                    $$.type=fonc->data.fonc->return_type;
                    $$.name=$1;
                    free_symbol(fonc);
                    free_symbol(var);
                }
            }
        | IDENTIFIER '(' argument_expression_list ')'{
            int ptr=check_function_call_with_args($1, $3.nb_args,yylineno,table_courante);
            if(ptr==0){
                Symbol* fonc=ts_lookup(table_courante,$1);
                Arg* arg_courant=$3.arg_list->first;
                Param* param_courant=s->data.fonc->params;
                while(arg_courant){
                        if (strcmp(param_courant->type.nom_type,arg_courant->type.nom_type)!=0){
                            char msg[256];
                            snprintf(msg, sizeof(msg), "Champ '%s' n'a pas le même type que celui de l'argument %s",param_courant->type.nom_type,yytext);
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                        else{
                            param_courant=param_courant->next;
                            arg_courant=arg_courant->next;
                        }
                    }
                $$.name=$1;
                $$.type=fonc->data.fonc->return_type;
                $$.pointeur=0;
                free_arg_list($3.arg_list);
                free_symbol(fonc);
            } else{
                Symbol* var= ts_lookup(table_courante,$1);
                $$.pointeur=1;
                Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                Arg* arg_courant=$3.arg_list->first;
                Param* param_courant=fonc->data.fonc->params;
                while(arg_courant){
                        if (strcmp(param_courant->type.nom_type,arg_courant->type.nom_type)!=0){
                            char msg[256];
                            snprintf(msg, sizeof(msg), "Champ '%s' n'a pas le même type que celui de l'argument %s",param_courant->type.nom_type,yytext);
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                        else{
                            param_courant=param_courant->next;
                            arg_courant=arg_courant->next;
                        }
                    }
                $$.type=fonc->data.fonc->return_type;
                $$.name=$1;
                free_symbol(fonc);
                free_symbol(var);
            }
        }
        | '(' IDENTIFIER')' '(' ')'{
                int ptr=check_function_call($1,table_courante,yylineno);
                if (ptr==0){
                    Symbol* fonc=ts_lookup(table_courante,$1);
                    $$.name=$1;
                    $$.pointeur=0;
                    $$.type=fonc->data.fonc->return_type;
                    free_symbol(fonc);
                } else {
                    Symbol* var= ts_lookup(table_courante,$1);
                    $$.pointeur=1;
                    Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                    $$.type=fonc->data.fonc->return_type;
                    $$.name=$1;
                    free_symbol(fonc);
                    free_symbol(var);
                }
        }
        | '(' IDENTIFIER')' '(' argument_expression_list')'{
            int ptr=check_function_call_with_args($1, $3.nb_args,yylineno,table_courante);
            if(ptr==0){
                Symbol* fonc=ts_lookup(table_courante,$1);
                Arg* arg_courant=$3.arg_list->first;
                Param* param_courant=s->data.fonc->params;
                while(arg_courant){
                        if (strcmp(param_courant->type.nom_type,arg_courant->type.nom_type)!=0){
                            char msg[256];
                            snprintf(msg, sizeof(msg), "Le paramètre '%s' n'a pas le même type que celui de l'argument %s",param_courant->type.nom_type,yytext);
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                        else{
                            param_courant=param_courant->next;
                            arg_courant=arg_courant->next;
                        }
                    }
                $$.name=$1;
                $$.type=fonc->data.fonc->return_type;
                $$.pointeur=0;
                free_arg_list($3.arg_list);
                free_symbol(fonc);
            } else{
                Symbol* var= ts_lookup(table_courante,$1);
                $$.pointeur=1;
                Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                Arg* arg_courant=$3.arg_list->first;
                Param* param_courant=fonc->data.fonc->params;
                while(arg_courant){
                        if (strcmp(param_courant->type.nom_type,arg_courant->type.nom_type)!=0){
                            char msg[256];
                            snprintf(msg, sizeof(msg), "Le paramètre '%s' n'a pas le même type que celui de l'argument %s",param_courant->type.nom_type,yytext);
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                        else{
                            param_courant=param_courant->next;
                            arg_courant=arg_courant->next;
                        }
                    }
                $$.type=fonc->data.fonc->return_type;
                $$.name=$1;
                free_symbol(fonc);
                free_symbol(var);
            }
        }
        | postfix_expression_structure '('')'{
            name=$1.type.nom_type;
            int ptr=check_function_call(name,table_courante,yylineno);
            if (ptr==0){
                Symbol* fonc=ts_lookup(table_courante,name);
                $$.name=name;
                $$.pointeur=0;
                $$.type=fonc->data.fonc->return_type;
                free_symbol(fonc);
            } else {
                Symbol* var= ts_lookup(table_courante,name);
                $$.pointeur=1;
                Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                $$.type=fonc->data.fonc->return_type;
                $$.name=name;
                free_symbol(fonc);
                free_symbol(var);
            }
        }
        | postfix_expression_structure '('argument_expression_list')'{
            name=$1.type.nom_type;
            int ptr=check_function_call_with_args(name, $3.nb_args,yylineno,table_courante);
            if(ptr==0){
                Symbol* fonc=ts_lookup(table_courante,name);
                Arg* arg_courant=$3.arg_list->first;
                Param* param_courant=s->data.fonc->params;
                while(arg_courant){
                        if (strcmp(param_courant->type.nom_type,arg_courant->type.nom_type)!=0){
                            char msg[256];
                            snprintf(msg, sizeof(msg), "Champ '%s' n'a pas le même type que celui de l'argument %s",param_courant->type.nom_type,yytext);
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                        else{
                            param_courant=param_courant->next;
                            arg_courant=arg_courant->next;
                        }
                    }
                $$.name=name;
                $$.type=fonc->data.fonc->return_type;
                $$.pointeur=0;
                free_arg_list($3.arg_list);
                free_symbol(fonc);
            } else{
                Symbol* var= ts_lookup(table_courante,name);
                $$.pointeur=1;
                Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                Arg* arg_courant=$3.arg_list->first;
                Param* param_courant=fonc->data.fonc->params;
                while(arg_courant){
                        if (strcmp(param_courant->type.nom_type,arg_courant->type.nom_type)!=0){
                            char msg[256];
                            snprintf(msg, sizeof(msg), "Champ '%s' n'a pas le même type que celui de l'argument %s",param_courant->type.nom_type,yytext);
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                        else{
                            param_courant=param_courant->next;
                            arg_courant=arg_courant->next;
                        }
                    }
                $$.type=fonc->data.fonc->return_type;
                $$.name=name;
                free_symbol(fonc);
                free_symbol(var);
            }
        }
        ;

postfix_expression_function 
        : simple{
            $$.name=$1.name;
            $$.type=$1.type;
            $$.pointeur=$1.pointeur;
        }
        | ptr_fonction{
            $$.name=$1.name;
            $$.type=$1.type;
            $$.pointeur=$1.pointeur;
        }
        ;

ptr_fonction
        : '(' '*' IDENTIFIER')' '(' ')'{
                int ptr=check_function_call($3,table_courante,yylineno);
                if (ptr==0){
                    char msg[256];
                    snprintf(msg, sizeof(msg), "%s n'est pas un pointeur de fonction.",yytext);
                    erreur(TYPE, yylineno, msg, yytext);
                } else {
                    Symbol* var= ts_lookup(table_courante,$3);
                    $$.pointeur=1;
                    Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                    $$.type=fonc->data.fonc->return_type;
                    char* msg="Cette forme est correcte mais inhabituelle.";
                    warning(SEMANTIQUE,yylineno,msg,yytext);
                    $$.name=$3;
                    free_symbol(fonc);
                    free_symbol(var);
                }
        }
        | '(' '*' IDENTIFIER')' '(' argument_expression_list ')'{
            int ptr=check_function_call_with_args($3, $6.nb_args,yylineno,table_courante);
            if(ptr==0){
                char msg[256];
                snprintf(msg, sizeof(msg), "%s n'est pas un pointeur de fonction.",yytext);
                erreur(TYPE, yylineno, msg, yytext);
            } else{
                Symbol* var= ts_lookup(table_courante,$3);
                $$.pointeur=1;
                Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                Arg* arg_courant=$6.arg_list->first;
                Param* param_courant=fonc->data.fonc->params;
                while(arg_courant){
                        if (strcmp(param_courant->type.nom_type,arg_courant->type.nom_type)!=0){
                            char msg[256];
                            snprintf(msg, sizeof(msg), "Le paramètre '%s' n'a pas le même type que celui de l'argument %s",param_courant->type.nom_type,yytext);
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                        else{
                            param_courant=param_courant->next;
                            arg_courant=arg_courant->next;
                        }
                    }
                $$.type=fonc->data.fonc->return_type;
                $$.name=$3;
                char* msg="Cette forme est correcte mais inhabituelle.";
                warning(SEMANTIQUE,yylineno,msg,yytext);
                free_arg_list($6.arg_list);
                free_symbol(fonc);
                free_symbol(var);
            }
        }
        | '(' '*' postfix_expression_structure ')' '('')'{
                int ptr=check_function_call($3.type.nom_type,table_courante,yylineno);
                if (ptr==0){
                    char msg[256];
                    snprintf(msg, sizeof(msg), "%s n'est pas un pointeur de fonction.",yytext);
                    erreur(TYPE, yylineno, msg, yytext);
                } else {
                    Symbol* var= ts_lookup(table_courante,$3.type.nom_type);
                    $$.pointeur=1;
                    Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                    $$.type=fonc->data.fonc->return_type;
                    char* msg="Cette forme est correcte mais inhabituelle.";
                    warning(SEMANTIQUE,yylineno,msg,yytext);
                    $$.name=$3.type.nom_type;
                    free_symbol(fonc);
                    free_symbol(var);
                }
        }
        | '(' '*' postfix_expression_structure')' '(' argument_expression_list ')'{
            name=$3.type.nom_type;
            int ptr=check_function_call_with_args(name, $6.nb_args,yylineno,table_courante);
            if(ptr==0){
                char msg[256];
                snprintf(msg, sizeof(msg), "%s n'est pas un pointeur de fonction.",yytext);
                erreur(TYPE, yylineno, msg, yytext);
            } else{
                Symbol* var= ts_lookup(table_courante,name);
                $$.pointeur=1;
                Symbol* fonc=ts_lookup(table_courante,var->data.var->type.nom_type);
                Arg* arg_courant=$6.arg_list->first;
                Param* param_courant=fonc->data.fonc->params;
                while(arg_courant){
                        if (strcmp(param_courant->type.nom_type,arg_courant->type.nom_type)!=0){
                            char msg[256];
                            snprintf(msg, sizeof(msg), "Champ '%s' n'a pas le même type que celui de l'argument %s",param_courant->type.nom_type,yytext);
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                        else{
                            param_courant=param_courant->next;
                            arg_courant=arg_courant->next;
                        }
                    }
                $$.type=fonc->data.fonc->return_type;
                $$.name=name;
                free_arg_list($6.arg_list);
                free_symbol(fonc);
                free_symbol(var);
            }
        }
        ;
unary_operator
        : '&'{
            $$.name='&';
        }
        | '*'{
            $$.name='*';
        }
        | '-'{
            $$.name='-';
        }
        ;

unary_expression 
        : primary_expression{
            $$.type=$1.type;
            $$.constante=$1.constante;
        }
        | postfix_expression_structure
        {
            $$.type=$1.type;
            $$.constante=0;
        } 
        | '(' postfix_expression_structure ')'
        {
            $$.type=$1.type;
            $$.constante=0;
        } 
        | unary_operator unary_expression {
            switch($1.name){
                case '&':
                /*&mastruct->monchamp est valide, renvoie l'adresse de monchamp mais n'est pas un accès à la valeur de monchamp*/
                /*&nom_fonction est valide ssi nom_fonction est un identifiant d'une fonction définie, cela renvoie un pointeur vers la fonction*/    
                /*&nom_fonction() est interdit!!!*/
                /*&(a+b) interdit*/
                    if($2.type.is_pointer==1){
                        char* msg="Les pointeurs de pointeurs ne sont pas autorisés.";
                        erreur(POINTEUR,yylineno,msg,yytext);
                    }
                    if($2.constante==1){
                        char* msg="Les constantes ne peuvent pas être référencée.";
                        erreur(SEMANTIQUE,yylineno,msg,yytext);
                    }
                    $$.type=$2.type;
                    $$.type.is_pointer=1;
                    $$.constante=0; /*Le résultat correspond à une variable pointeur sur un type*/
                    break;
                case '*': /* *mafonction() est correcte, même chose pour (*mafonction)(), c'est un appel déréférencé, correct pour type void et *int*/
                    if($2.type.is_pointer==0){
                        char* msg="Il est possible de déréférencer uniquement les pointeurs.";
                        erreur(POINTEUR,yylineno,msg,yytext);
                    }
                    if($2.type.is_pointer==1 && strcmp($2.type.nom_type,strdup("int"))!=0){
                        char* msg="On ne peut déréférencer que les type *int.";
                        erreur(SEMANTIQUE,yylineno,msg,yytext);
                    }
                    $$.type=$2.type;
                    $$.type.is_pointer=0;
                    $$.constante=1;
                    break;
                case '-': /*-calculerValeur() est correct si le type retour de la fonction est un int*/
                    if($2.type.is_pointer==1){
                        char* msg="Il n'est pas possible de négativer une adresse mémoire.";
                        erreur(POINTEUR,yylineno,msg,yytext);
                    }
                    $$.type=$2.type;
                    $$.constante=1;
                    break;
                default:
                    break;
            }
        }
        |unary_operator simple{
            switch($1.name){
                case '&':
                    char* msg="Un appel de fonction n'est pas possible avec l'opérateur &.";
                    erreur(SEMANTIQUE,yylineno,msg,yytext);
                case '*':
                    if(strcmp($2.type.nom_type,strdup"void")!=0){
                        if(strcmp($2.type.nom_type,strdup"int"!=0)){
                            char* msg="Les appels déréférencés ne sont corrects que si la fonction renvoie un void ou un int*.";
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                        if($2.type.is_pointer==0){
                            char* msg="Les appels déréférencés ne sont corrects que si la fonction renvoie un void ou un int*.";
                            erreur(TYPE, yylineno, msg, yytext);
                        }
                    }
                    if(strcmp($2.type.nom_type,strdup("void"))==0){
                        $$.type=$2.type;
                    }else{
                        $$.type=$2.type;
                        $$.type.is_pointer=0;
                    }
                    $$.constante=1;
                    break;
                case '-':
                    if($2.type.is_pointer==1){
                        char* msg="Il n'est pas possible de négativer une adresse mémoire.";
                        erreur(POINTEUR,yylineno,msg,yytext);
                    }
                    if(strcmp($2.type.nom_type,strdup"int"!=0)){
                        char* msg="Un moins unaire sur un appel de fonction n'est correcte que si la fonction renvoie un int.";
                        erreur(TYPE, yylineno, msg, yytext);
                    }
                    $$.type=$2.type;
                    $$.type.is_pointer=0;
                    $$.constante=1;
                    break;
                default:
                    break;
            }
        }
        | unary_operator ptr_fonction{
            switch($1.name){
                case '&':
                    char* msg="Un appel de fonction n'est pas possible avec l'opérateur &.";
                    erreur(SEMANTIQUE,yylineno,msg,yytext);
                case '*':
                    char* msg="On ne peut avoir qu'un seul niveau d'indirection car les pointeurs de pointeurs sont interdits.";
                    erreur(SEMANTIQUE,yylineno,msg,yytext);
                case '-':
                    if($2.type.is_pointer==1){
                        char* msg="Il n'est pas possible de négativer une adresse mémoire.";
                        erreur(POINTEUR,yylineno,msg,yytext);
                    }
                    if(strcmp($2.type.nom_type,strdup"int"!=0)){
                        char* msg="Un moins unaire sur un appel de fonction n'est correcte que si la fonction renvoie un int.";
                        erreur(TYPE, yylineno, msg, yytext);
                    }
                    $$.type=$2.type;
                    $$.type.is_pointer=0;
                    $$.constante=1;
                    break;
                default:
                    break;
            }
        }
        | SIZEOF '(' unary_expression ')'{ 
            DataType t = {strdup("int"),0};
            $$.type=t;
            $$.constante=1;
        }
        ;

declaration_list
        : declaration
        | declaration_list declaration
        ;

statement_list
        : statement
        | statement_list statement
        ;

statement
        : compound_statement
        | expression_statement
        | selection_statement
        | iteration_statement
        | jump_statement
        | postfix_expression_function
        | affectation
        ;

expression_statement
        : ';'
        | logical_or_expression ';'
        ;

logical_or_expression       /*faire un champ type (DataType)*/
        : logical_and_expression
        | logical_or_expression OR_OP logical_and_expression
        ;

logical_and_expression
        : equality_expression
        | logical_and_expression AND_OP equality_expression
        ;

equality_expression
        : relational_expression
        | equality_expression EQ_OP relational_expression
        | equality_expression NE_OP relational_expression
        ;

relational_expression
        : additive_expression
        | relational_expression '<' additive_expression
        | relational_expression '>' additive_expression
        | relational_expression LE_OP additive_expression
        | relational_expression GE_OP additive_expression
        ;

additive_expression
        : multiplicative_expression
        | additive_expression '+' multiplicative_expression
        | additive_expression '-' multiplicative_expression
        ;

multiplicative_expression
        : unary_expression
        | multiplicative_expression '*' unary_expression
        | multiplicative_expression '/' unary_expression
        ;

selection_statement
        : IF '(' logical_or_expression ')' compound_statement %prec IFX
        | IF '(' logical_or_expression ')' compound_statement ELSE compound_statement
        ;

iteration_statement
        : WHILE '(' logical_or_expression ')' compound_statement
        | FOR '(' expression_statement expression_statement logical_or_expression ')' compound_statement
        ; 

jump_statement
        : RETURN ';' /*si en dehors d'une boucle ou d'un if/else faire un warning car c'est inutile*/
            {
                check_return_statement(NULL);
            }
        | RETURN logical_or_expression ';'
            {
                check_return_statement(NULL); /* NULL car pas de type pour l'instant */
            }
        ;

%%

void yyerror(const char *s) {
        erreur(SYNTAXE, yylineno, s, yytext);
        afficher_erreur();
}