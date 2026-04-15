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
        
        /* variables globales pour l'analyse sémantique */
        Symbol* current_struct = NULL;

        /*Listes*/
        typedef struct {
            int count;
            struct{

            }elt;

        }list;
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
%left '(' '[' ')'
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
                        symbol=new_symbol_fonc($2.name,$1.type.nom_type,0,$1.is_extern);
                        param_courant=$2.param_list.first;
                        while (param_courant){
                            add_param_to_function(symbol, param_courant.type.nom_type, param_courant.type.is_pointer);
                            param_courant=param_courant.next;
                        }
                        ts_insert(table_courante,symbol,yylineno);
                    }
                    else{
                        symbol=new_symbol_fonc($2.name,$1.type.nom_type,0,$1.is_extern);
                        param_courant=$2.param_list.first;
                        while (param_courant){
                            add_param_to_function(symbol, param_courant.type.nom_type, param_courant.type.is_pointer);
                            param_courant=param_courant.next;
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
                courant=$2.list.first;
                while(courant){
                    if ($1.type.is_pointer==courant.is_pointer==1){
                        char *message="Les pointeurs de pointeurs ne sont pas acceptés.";
                        erreur(POINTEUR,yylineno,message,yytext);
                    }
                    if ($1.type.is_pointer==courant.is_pointer==0){
                        symbol=new_symbol_var(courant.name,$1.type.nom_type,0,$1.is_extern);
                        ts_insert(table_courante,symbol,yylineno);
                    }
                    else{
                        symbol=new_symbol_var(courant.name,$1.type.nom_type,1,$1.is_extern);
                        ts_insert(table_courante,symbol,yylineno);
                        }
                    courant=courant.next;
                }
                free($2.name);
                free_data_type($1.type);
            }
        | struct_specifier ';'
            {
                if ($1.name) free($1.name);
            }
        ;

type_specifier
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
                free($1);
            }
        | '(' declarator ')'
            {
                $$.name = $2.name;
                $$.is_pointer = $2.is_pointer;
            }

declarator_list
        : declarator
            {
                $.nb_params = 1;
                $$.list = create_decla_list();
                add_var_to_list($$.list, $1.name, $1.is_pointer);
                free($1.name);
            }
        | declarator_list ',' declarator
            {
                $$.nb_params = $1.nb_params + 1;
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
                free($3.name);
            }
        ;

parameter_declaration
        : declaration_specifiers declarator
            {
                if ($1.type.is_pointer==courant.is_pointer==1){
                        char *message="Les pointeurs de pointeurs ne sont pas acceptés.";
                        erreur(POINTEUR,yylineno,message,yytext);
                    }
                    if ($1.type.is_pointer==courant.is_pointer==0){
                        $$.type=$1.type;
                    }
                    else{
                        t=DataType{$1.type.nom_type,1};
                        $$.type=t;
                        }
                $$.name = $2.name;
            }
        ;

struct_specifier 
        : STRUCT IDENTIFIER IDENTIFIER
            { /*vérifier que $2 est bien une structure déclarée puis déclarer la variable $3 de type structure $2*/
                s=ts_lookup(table_courante,$2);
                if (!s){
                    char* message = "La structure n'est pas déclarée.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                if (s-->kind != SYMBOL_STRUCT){
                    char* message = "Le nom de la structure ne correspond pas à une structure.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                symbol=new_symbol_var($3,s.str.nom,0,0);
                ts_insert(table_courante,symbol,yylineno);
                free($3);
                free($2);
            }
        | STRUCT IDENTIFIER '*' IDENTIFIER{
            s=ts_lookup(table_courante,$2);
                if (!s){
                    char* message = "La structure n'est pas déclarée.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                if (s-->kind != SYMBOL_STRUCT){
                    char* message = "Le nom de la structure ne correspond pas à une structure.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                symbol=new_symbol_var($3,s.str.nom,1,0);
                ts_insert(table_courante,symbol,yylineno);
                free($3);
                free($2);
        }
        | EXTERN STRUCT IDENTIFIER IDENTIFIER
            { /*vérifier que $2 est bien une structure déclarée puis déclarer la variable $3 de type structure $2*/
                s=ts_lookup(table_courante,$2);
                if (!s){
                    char* message = "La structure n'est pas déclarée.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                if (s-->kind != SYMBOL_STRUCT){
                    char* message = "Le nom de la structure ne correspond pas à une structure.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                symbol=new_symbol_var($3,s.str.nom,0,1);
                ts_insert(table_courante,symbol,yylineno);
                free($3);
                free($2);
            }
        | EXTERN STRUCT IDENTIFIER '*'IDENTIFIER{
            s=ts_lookup(table_courante,$2);
                if (!s){
                    char* message = "La structure n'est pas déclarée.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                if (s->kind != SYMBOL_STRUCT){
                    char* message = "Le nom de la structure ne correspond pas à une structure.";
                    error(SEMANTIQUE,yylineno, message, yytext);
                }
                symbol=new_symbol_var($3,s.str.nom,1,1);
                ts_insert(table_courante,symbol,yylineno);
                free($3);
                free($2);
        }
        | STRUCT '{' struct_declaration_list '}' IDENTIFIER 
            {
                symbol=new_symbol_struct($5);
                field_courant=$3.field_list.first;
                while (field_courant){
                    add_field_to_struct(symbol, field_courant.name, field_courant.type.nom_type, field_courant.type.is_pointer);
                    field_courant=field_courant.next;
                }
                ts_insert(table_courante,symbol,yylineno);
                free_field_list($3.field_list);
            }
        | STRUCT IDENTIFIER '{' struct_declaration_list '}' 
            {
                symbol=new_symbol_struct($2);
                field_courant=$4.field_list.first;
                while (field_courant){
                    add_field_to_struct(symbol, field_courant.name, field_courant.type.nom_type, field_courant.type.is_pointer);
                    field_courant=field_courant.next;
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
                    $$.type.is_pointer=0;
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
        :affectation_statement
        |declaration_affectation_statement
        ;

affectation_statement
        : IDENTIFIER '=' logical_or_expression ';'
        | IDENTIFIER '=' postfix_expression_function ';'
        | '&' IDENTIFIER '=' logical_or_expression ';'
        | '&' IDENTIFIER '=' postfix_expression_fonction ';'
        ;

declaration_affectation_statement
        : STRUCT IDENTIFIER IDENTIFIER '=' '{'argument_expression_list'}' ';'
        | STRUCT IDENTIFIER '*' IDENTIFIER '=' '{'argument_expression_list'}' ';'
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
                $$.name=ts_lookup(table_courante,$1);
                $$.parenthese=0;
                $$.constante=0;
                switch ($$.name->kind){
                    case SYMBOL_VAR:
                        $$.type=$$.name->var.type;
                        break;
                    case SYMBOL_STRUCT:
                        char* message= "Le symbole est associé à un type structure et non a une variable.";
                        erreur(SYNTAXE,yylineno,message,yytext);
                        break;
                    case SYMBOL_FONC :
                        char* message= "Le symbole est associé à un type fonction et non a une variable.";
                        erreur(SYNTAXE,yylineno,message,yytext);
                        break;
                    case default:
                        break;
                }
                free($1);
            }
        | constant{
            $$.name=$1;
            t=DataType{strdup("int"),0};
            $$.type=t;
            $$.base=$1.base;
            $$.parenthese=0;
            $$.constante=1;
        }
        | '(' logical_or_expression ')'{
            $$.name=$2.name;
            $$.type=$2.type;
            $$.parenthese=1;
            $$.contante=0;
            free($2.name);
        | '('affectation_statement')'
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
        |affectation
        ;

expression_statement
        : ';'
        | logical_or_expression ';'
        ;

logical_or_expression
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

unary_expression
        : primary_expression/*PROBLEMES : *constante pas possible, *appel de fonction direct non plus, etc... remplacer par affectation_statement?*/
        | postfix_expression_structure
        | unary_operator unary_expression 
        | SIZEOF '(' unary_expression ')'{ /*ATTTENTION unary_expression peut être un pointeur...*/
            DataType t = {strdup("int"),0};
            $$.type=t;
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

postfix_expression_function
        : primary_expression '(' ')'
            {
                check_function_call($1.name);
                free($1.name);
            }
        | primary_expression '(' argument_expression_list ')'
            {
                check_function_call_with_args($1.name, $3.nb_params);
                free($1.name);
            }

postfix_expression_structure
        : primary_expression '.' IDENTIFIER /*il faut que postfix_expression soit une variable déclarée de type structure, que ce ne soit pas un pointeur et que le champ IDENTIFIER existe.*/
            {
                error_direct_struct_access($3);
                free($3);
            }
        | primary_expression PTR_OP IDENTIFIER
            {
                check_struct_field_access($1.name, $3);
                free($1.name);
                free($3);
            }
        ;

argument_expression_list
        : logical_or_expression
            {
                $$.nb_params = 1;
                $$.param_list = NULL;
            }
        | argument_expression_list ',' logical_or_expression
            {
                $$.nb_params = $1.nb_params + 1;
                $$.param_list = NULL;
            }
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