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
        Symbol* current_function = NULL;
        Symbol* current_struct = NULL;
%}

%union {
        int val;
        char* nom;
        struct {
            char* type_nom;
            int is_pointer;
            int is_extern;
        } type_info;
        struct {
            char* name;
            int is_pointer;
        } decl_info;
        struct {
            int nb_params;
            void* param_list;
        } params_info;
        struct {
            char* name;
            int is_definition;
        } struct_info;
}

%token <nom> IDENTIFIER 
%token <val> CONSTANT 
%token SIZEOF
%token PTR_OP LE_OP GE_OP EQ_OP NE_OP
%token AND_OP OR_OP
%token EXTERN
%token INT VOID
%token STRUCT 
%token IF ELSE WHILE FOR RETURN
%token BREAK CONTINUE
%token <val> HEXA OCTAL FLOTTANT

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
        ;

function_definition
        : declaration_specifiers declarator compound_statement
            {
                end_function_definition(current_function);
                current_function = NULL;
            }
        ;

declaration
        : declaration_specifiers declarator ';'
            {
                declare_variable($2.name, $1.type_nom, $2.is_pointer, $1.is_extern);
                free($2.name);
                free($1.type_nom);
            }
        | struct_specifier ';'
            {
                if ($1.name) free($1.name);
            }
        ;

type_specifier
        : VOID
            {
                $$.type_nom = strdup("void");
                $$.is_pointer = 0;
            }
        | INT
            {
                $$.type_nom = strdup("int");
                $$.is_pointer = 0;
            }
        | struct_specifier
            {
                $$.type_nom = strdup($1.name);
                $$.is_pointer = 0;
            }
        ;

declaration_specifiers
        : EXTERN type_specifier
            {
                $$.type_nom = $2.type_nom;
                $$.is_pointer = $2.is_pointer;
                $$.is_extern = 1;
            }
        | type_specifier
            {
                $$.type_nom = $1.type_nom;
                $$.is_pointer = $1.is_pointer;
                $$.is_extern = 0;
            }
        ;

declarator
        : '*' direct_declarator
            {
                $$.name = $2.name;
                $$.is_pointer = 1;
            }
        | direct_declarator
            {
                $$.name = $1.name;
                $$.is_pointer = 0;
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
        | direct_declarator '(' parameter_list ')'
            {
                $$.name = $1.name;
                $$.is_pointer = 0;
                current_function = create_function_symbol($1.name, $3.nb_params, $3.param_list);
                free($1.name);
            }
        | direct_declarator '(' ')'
            {
                $$.name = $1.name;
                $$.is_pointer = 0;
                current_function = create_function_symbol($1.name, 0, NULL);
                free($1.name);
            }
        ;
        
parameter_list
        : parameter_declaration
            {
                $$.nb_params = 1;
                $$.param_list = create_param_list();
                add_param_to_list($$.param_list, $1.type_nom, $1.is_pointer);
                free($1.type_nom);
                free($1.name);
            }
        | parameter_list ',' parameter_declaration
            {
                $$.nb_params = $1.nb_params + 1;
                $$.param_list = $1.param_list;
                add_param_to_list($$.param_list, $3.type_nom, $3.is_pointer);
                free($3.type_nom);
                free($3.name);
            }
        ;

parameter_declaration
        : declaration_specifiers declarator
            {
                $$.type_nom = $1.type_nom;
                $$.is_pointer = $2.is_pointer;
                $$.name = $2.name;
                /* Note: $1.type_nom sera libéré par le parent */
            }
        ;

compound_statement
        : '{' '}'
            {
                enter_scope();
                exit_scope();
            }
        | '{' statement_list '}'
            {
                enter_scope();
                exit_scope();
            }
        | '{' declaration_list '}'
            {
                enter_scope();
                exit_scope();
            }
        | '{' declaration_list statement_list '}'
            {
                enter_scope();
                exit_scope();
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
        ;

expression_statement
        : ';'
        | expression ';'
        ;

expression
        : logical_or_expression
        | unary_expression '=' expression
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
        : postfix_expression
        | unary_operator unary_expression
        | SIZEOF unary_expression
        ;

unary_operator
        : '&'
        | '*'
        | '-'
        ;

postfix_expression
        : primary_expression
        | postfix_expression '(' ')'
            {
                check_function_call($1.name);
                free($1.name);
            }
        | postfix_expression '(' argument_expression_list ')'
            {
                check_function_call_with_args($1.name, $3.nb_params);
                free($1.name);
            }
        | postfix_expression '.' IDENTIFIER
            {
                error_direct_struct_access($3);
                free($3);
            }
        | postfix_expression PTR_OP IDENTIFIER
            {
                check_struct_field_access($1.name, $3);
                free($1.name);
                free($3);
            }
        ;

primary_expression
        : IDENTIFIER
            {
                check_identifier_declared($1);
                free($1);
            }
        | constant
        | '(' expression ')'
        ;

constant
        : CONSTANT { $$ = $1; }
        | HEXA { $$ = $1; }
        | OCTAL { $$ = $1; }
        | FLOTTANT { $$ = $1; }
        ;

argument_expression_list
        : expression
            {
                $$.nb_params = 1;
                $$.param_list = NULL;
            }
        | argument_expression_list ',' expression
            {
                $$.nb_params = $1.nb_params + 1;
                $$.param_list = NULL;
            }
        ;

struct_specifier
        : STRUCT IDENTIFIER
            {
                $$.name = declare_struct($2);
                $$.is_definition = 0;
                free($2);
            }
        | STRUCT '{' struct_declaration_list '}'
            {
                $$.name = declare_anonymous_struct();
                $$.is_definition = 1;
            }
        | STRUCT IDENTIFIER '{' struct_declaration_list '}'
            {
                $$.name = define_struct($2);
                $$.is_definition = 1;
                free($2);
            }
        ;

struct_declaration_list
        : struct_declaration
        | struct_declaration_list struct_declaration
        ;

struct_declaration
        : type_specifier declarator ';'
            {
                add_struct_field($2.name, $1.type_nom, $2.is_pointer);
                free($1.type_nom);
                free($2.name);
            }
        ;

selection_statement
        : IF '(' expression ')' statement %prec IFX
        | IF '(' expression ')' statement ELSE statement
        ;

iteration_statement
        : WHILE '(' expression ')' statement
        | FOR '(' expression_statement expression_statement expression ')' statement
        ;

jump_statement
        : RETURN ';'
            {
                check_return_statement(NULL);
            }
        | RETURN expression ';'
            {
                check_return_statement(NULL); /* NULL car pas de type pour l'instant */
            }
        | BREAK ';'
            {
                error_unsupported("break");
            }
        | CONTINUE ';'
            {
                error_unsupported("continue");
            }
        ;

%%

void yyerror(const char *s) {
        erreur(SYNTAXE, yylineno, s, yytext);
        afficher_erreur();
}