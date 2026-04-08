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
            void* sym;
            int is_pointer;
        } id_info;
        struct {
            void* type;
            char* code;
            char* temp_var;
            char* name;
            void* sym;
            int op;
        } expr_info;
        struct {
            char* code;
            char* params_list;
            int nb_params;
        } args_info;
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
%destructor { free($$.name); } id_info
%destructor { free($$.code); free($$.temp_var); free($$.name); } expr_info
%destructor { free($$.code); free($$.params_list); } args_info

%type <type_info> type_specifier declaration_specifiers struct_specifier
%type <id_info> declarator direct_declarator
%type <expr_info> expression additive_expression multiplicative_expression
%type <expr_info> relational_expression equality_expression
%type <expr_info> logical_and_expression logical_or_expression
%type <expr_info> unary_expression postfix_expression primary_expression constant
%type <expr_info> expression_statement
%type <expr_info> unary_operator
%type <args_info> argument_expression_list

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
                current_function = NULL;
            }
        ;

declaration
        : declaration_specifiers declarator ';'
            {
                Symbol* sym = new_symbol_var($2.name, $1.type_nom, $2.is_pointer, $1.is_extern);
                if (table_courante) {
                    ts_insert(table_courante, sym, @1.first_line);
                }
                free($2.name);
                free($1.type_nom);
            }
        | struct_specifier ';'
            {
                free($1.type_nom);
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
                $$.type_nom = $1.type_nom;
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
                $$.sym = $2.sym;
                $$.is_pointer = 1;
            }
        | direct_declarator
            {
                $$.name = $1.name;
                $$.sym = $1.sym;
                $$.is_pointer = 0;
            }
        ;

direct_declarator
        : IDENTIFIER
            {
                $$.name = strdup($1);
                $$.is_pointer = 0;
                if (table_courante) {
                    $$.sym = (void*)ts_lookup(table_courante, $1);
                } else {
                    $$.sym = NULL;
                }
            }
        | '(' declarator ')'
            {
                $$.name = $2.name;
                $$.sym = $2.sym;
                $$.is_pointer = $2.is_pointer;
            }
        | direct_declarator '(' parameter_list ')'
            {
                $$.name = $1.name;
                $$.is_pointer = 0;
                Symbol* s = new_symbol_fonc($1.name, "int", 0, 0);
                if (table_courante) {
                    ts_insert(table_courante, s, @1.first_line);
                }
                $$.sym = (void*)s;
                current_function = s;
            }
        | direct_declarator '(' ')'
            {
                $$.name = $1.name;
                $$.is_pointer = 0;
                Symbol* s = new_symbol_fonc($1.name, "int", 0, 0);
                if (table_courante) {
                    ts_insert(table_courante, s, @1.first_line);
                }
                $$.sym = (void*)s;
                current_function = s;
            }
        ;
        
parameter_list
        : parameter_declaration
        | parameter_list ',' parameter_declaration
        ;

parameter_declaration
        : declaration_specifiers declarator
            {
                if (current_function) {
                    add_param_to_function(current_function, $1.type_nom, $1.is_pointer);
                }
                free($1.type_nom);
                free($2.name);
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
            /* Le code de statement_list sera exécuté entre enter et exit */
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
            {
                static DataType void_type = {"void", 0};
                $$.type = &void_type;
                $$.temp_var = NULL;
                $$.code = NULL;
                $$.name = NULL;
                $$.sym = NULL;
            }
        | expression ';'
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        ;

expression
        : logical_or_expression
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | unary_expression '=' expression
            {
                /* Vérification de compatibilité des types pour l'affectation */
                DataType* left_type = (DataType*)$1.type;
                DataType* right_type = (DataType*)$3.type;
                if (left_type && right_type) {
                    if (strcmp(left_type->nom_type, right_type->nom_type) != 0 ||
                        left_type->is_pointer != right_type->is_pointer) {
                        char msg[256];
                        snprintf(msg, sizeof(msg), 
                                 "Type incompatible pour l'affectation: '%s' vs '%s'",
                                 left_type->nom_type, right_type->nom_type);
                        erreur(SEMANTIQUE, @2.first_line, msg, yytext);
                    }
                }
                $$.type = $3.type;
                $$.temp_var = $1.temp_var;
                asprintf(&$$.code, "%s%s%s = %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $1.temp_var, $3.temp_var);
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        ;

logical_or_expression
        : logical_and_expression
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | logical_or_expression OR_OP logical_and_expression
            {
                DataType* type1 = (DataType*)$1.type;
                DataType* type3 = (DataType*)$3.type;
                if (type1 && type3 && (strcmp(type1->nom_type, "int") != 0 || strcmp(type3->nom_type, "int") != 0)) {
                    erreur(SEMANTIQUE, @2.first_line, "L'opérateur || n'est supporté que sur des entiers", yytext);
                }
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s || %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        ;

logical_and_expression
        : equality_expression
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | logical_and_expression AND_OP equality_expression
            {
                DataType* type1 = (DataType*)$1.type;
                DataType* type3 = (DataType*)$3.type;
                if (type1 && type3 && (strcmp(type1->nom_type, "int") != 0 || strcmp(type3->nom_type, "int") != 0)) {
                    erreur(SEMANTIQUE, @2.first_line, "L'opérateur && n'est supporté que sur des entiers", yytext);
                }
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s && %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        ;

equality_expression
        : relational_expression
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | equality_expression EQ_OP relational_expression
            {
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s == %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        | equality_expression NE_OP relational_expression
            {
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s != %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        ;

relational_expression
        : additive_expression
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | relational_expression '<' additive_expression
            {
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s < %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        | relational_expression '>' additive_expression
            {
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s > %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        | relational_expression LE_OP additive_expression
            {
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s <= %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        | relational_expression GE_OP additive_expression
            {
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s >= %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        ;

additive_expression
        : multiplicative_expression
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | additive_expression '+' multiplicative_expression
            {
                DataType* type1 = (DataType*)$1.type;
                DataType* type3 = (DataType*)$3.type;
                if (type1 && type3 && (strcmp(type1->nom_type, "int") != 0 || strcmp(type3->nom_type, "int") != 0)) {
                    erreur(SEMANTIQUE, @2.first_line, "L'addition n'est supportée que sur des entiers", yytext);
                }
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s + %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        | additive_expression '-' multiplicative_expression
            {
                DataType* type1 = (DataType*)$1.type;
                DataType* type3 = (DataType*)$3.type;
                if (type1 && type3 && (strcmp(type1->nom_type, "int") != 0 || strcmp(type3->nom_type, "int") != 0)) {
                    erreur(SEMANTIQUE, @2.first_line, "La soustraction n'est supportée que sur des entiers", yytext);
                }
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s - %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        ;

multiplicative_expression
        : unary_expression
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | multiplicative_expression '*' unary_expression
            {
                DataType* type1 = (DataType*)$1.type;
                DataType* type3 = (DataType*)$3.type;
                if (type1 && type3 && (strcmp(type1->nom_type, "int") != 0 || strcmp(type3->nom_type, "int") != 0)) {
                    erreur(SEMANTIQUE, @2.first_line, "La multiplication n'est supportée que sur des entiers", yytext);
                }
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s * %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        | multiplicative_expression '/' unary_expression
            {
                DataType* type1 = (DataType*)$1.type;
                DataType* type3 = (DataType*)$3.type;
                if (type1 && type3 && (strcmp(type1->nom_type, "int") != 0 || strcmp(type3->nom_type, "int") != 0)) {
                    erreur(SEMANTIQUE, @2.first_line, "La division n'est supportée que sur des entiers", yytext);
                }
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                $$.temp_var = new_temp();
                asprintf(&$$.code, "%s%s%s = %s / %s\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.temp_var, $3.temp_var);
                $$.name = NULL;
                $$.sym = NULL;
            }
        ;

unary_expression
        : postfix_expression
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | unary_operator unary_expression
            {
                DataType* type = (DataType*)$2.type;
                if ($1.op == '-') {
                    if (type && strcmp(type->nom_type, "int") != 0) {
                        erreur(SEMANTIQUE, @1.first_line, "L'opérateur - unaire s'utilise uniquement sur des entiers", yytext);
                    }
                    static DataType int_type = {"int", 0};
                    $$.type = &int_type;
                    $$.temp_var = new_temp();
                    asprintf(&$$.code, "%s%s = -%s\n", 
                             $2.code ? $2.code : "", $$.temp_var, $2.temp_var);
                    $$.name = NULL;
                    $$.sym = NULL;
                } else if ($1.op == '&') {
                    if (!$2.name || !$2.sym) {
                        erreur(SEMANTIQUE, @1.first_line, "L'opérateur & ne peut s'appliquer qu'à une variable", yytext);
                    }
                    if (type && type->is_pointer) {
                        erreur(SEMANTIQUE, @1.first_line, "Adresse d'un pointeur non supportée", yytext);
                    }
                    static DataType ptr_type;
                    ptr_type.nom_type = type ? strdup(type->nom_type) : strdup("int");
                    ptr_type.is_pointer = 1;
                    $$.type = &ptr_type;
                    asprintf(&$$.temp_var, "&%s", $2.temp_var);
                    $$.code = $2.code;
                    $$.name = $2.name;
                    $$.sym = $2.sym;
                } else if ($1.op == '*') {
                    if (type && !type->is_pointer) {
                        erreur(SEMANTIQUE, @1.first_line, "Le déréférencement * s'utilise uniquement sur des pointeurs", yytext);
                    }
                    static DataType val_type;
                    val_type.nom_type = type ? strdup(type->nom_type) : strdup("int");
                    val_type.is_pointer = 0;
                    $$.type = &val_type;
                    asprintf(&$$.temp_var, "*%s", $2.temp_var);
                    $$.code = $2.code;
                    $$.name = $2.name;
                    $$.sym = $2.sym;
                }
            }
        | SIZEOF unary_expression
            {
                DataType* type = (DataType*)$2.type;
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                int size = (type && type->is_pointer) ? 8 : 4;
                asprintf(&$$.temp_var, "%d", size);
                $$.code = NULL;
                $$.name = NULL;
                $$.sym = NULL;
            }
        ;

unary_operator
        : '&' { $$.op = '&'; }
        | '*' { $$.op = '*'; }
        | '-' { $$.op = '-'; }
        ;

postfix_expression
        : primary_expression
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | postfix_expression '(' ')'
            {
                Symbol* sym = (Symbol*)$1.sym;
                if (!sym) {
                    char msg[256];
                    snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", $1.name);
                    erreur(SEMANTIQUE, @2.first_line, msg, $1.name);
                }
                if (sym && sym->kind != SYMBOL_FONC) {
                    char msg[256];
                    snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", $1.name);
                    erreur(SEMANTIQUE, @2.first_line, msg, $1.name);
                }
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                asprintf(&$$.temp_var, "call_%s", $1.name);
                asprintf(&$$.code, "%s%s = %s()\n", 
                         $1.code ? $1.code : "", $$.temp_var, $1.name);
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | postfix_expression '(' argument_expression_list ')'
            {
                Symbol* sym = (Symbol*)$1.sym;
                if (!sym) {
                    char msg[256];
                    snprintf(msg, sizeof(msg), "Fonction '%s' non déclarée", $1.name);
                    erreur(SEMANTIQUE, @2.first_line, msg, $1.name);
                }
                if (sym && sym->kind != SYMBOL_FONC) {
                    char msg[256];
                    snprintf(msg, sizeof(msg), "'%s' n'est pas une fonction", $1.name);
                    erreur(SEMANTIQUE, @2.first_line, msg, $1.name);
                }
                
                if (sym && sym->kind == SYMBOL_FONC && sym->data.fonc->nb_params > 0) {
                    int nb_params_attendus = sym->data.fonc->nb_params;
                    int nb_params_fournis = $3.nb_params;
                    
                    if (nb_params_attendus != nb_params_fournis) {
                        char msg[256];
                        snprintf(msg, sizeof(msg), 
                                 "Nombre de paramètres incorrect pour '%s': attendu %d, reçu %d",
                                 $1.name, nb_params_attendus, nb_params_fournis);
                        erreur(SEMANTIQUE, @2.first_line, msg, $1.name);
                    }
                }
                
                /* Déterminer le type de retour */
                DataType* return_type = &((DataType){"int", 0});
                if (sym && sym->kind == SYMBOL_FONC) {
                    return_type = &sym->data.fonc->return_type;
                }
                $$.type = return_type;
                
                asprintf(&$$.temp_var, "call_%s", $1.name);
                asprintf(&$$.code, "%s%s%s = %s(%s)\n", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "",
                         $$.temp_var, $1.name, $3.params_list);
                $$.name = $1.name;
                $$.sym = $1.sym;
                
                free($3.params_list);
                free($3.code);
            }
        | postfix_expression '.' IDENTIFIER
            {
                erreur(SEMANTIQUE, @2.first_line, "Accès direct à structure non supporté, utilisez ->", $3);
                free($3);
            }
        | postfix_expression PTR_OP IDENTIFIER
            {
                Symbol* ptr_sym = (Symbol*)$1.sym;
                
                if (!ptr_sym || ptr_sym->kind != SYMBOL_VAR) {
                    erreur(SEMANTIQUE, @2.first_line, 
                           "L'opérateur -> s'utilise uniquement sur des variables de type pointeur", 
                           yytext);
                }
                
                if (!ptr_sym->data.var->type.is_pointer) {
                    erreur(SEMANTIQUE, @2.first_line, 
                           "L'opérateur -> s'utilise uniquement sur des pointeurs", 
                           yytext);
                }
                
                char* struct_name = ptr_sym->data.var->type.nom_type;
                Symbol* struct_sym = ts_lookup(table_courante, struct_name);
                
                if (!struct_sym || struct_sym->kind != SYMBOL_STRUCT) {
                    char msg[256];
                    snprintf(msg, sizeof(msg), "Type de structure '%s' inconnu", struct_name);
                    erreur(SEMANTIQUE, @2.first_line, msg, struct_name);
                }
                
                Field* field = (Field*)struct_sym->data.str->champs;
                DataType* field_type = NULL;
                
                while (field) {
                    if (strcmp(field->name, $3) == 0) {
                        field_type = &field->type;
                        break;
                    }
                    field = field->next;
                }
                
                if (!field_type) {
                    char msg[256];
                    snprintf(msg, sizeof(msg), "Champ '%s' non trouvé dans la structure '%s'", $3, struct_name);
                    erreur(SEMANTIQUE, @2.first_line, msg, $3);
                }
                
                DataType* result_type = malloc(sizeof(DataType));
                result_type->nom_type = strdup(field_type->nom_type);
                result_type->is_pointer = field_type->is_pointer;
                $$.type = result_type;
                
                asprintf(&$$.temp_var, "%s->%s", $1.temp_var, $3);
                $$.code = $1.code;
                $$.name = strdup($3);
                
                Symbol* field_sym = malloc(sizeof(Symbol));
                field_sym->kind = SYMBOL_VAR;
                field_sym->name = strdup($3);
                field_sym->data.var = malloc(sizeof(VarInfo));
                field_sym->data.var->type = *result_type;
                field_sym->data.var->is_extern = 0;
                $$.sym = field_sym;
                
                free($3);
            }
        ;

primary_expression
        : IDENTIFIER
            {
                $$.name = strdup($1);
                if (table_courante) {
                    $$.sym = (void*)ts_lookup(table_courante, $1);
                } else {
                    $$.sym = NULL;
                }
                if (!$$.sym) {
                    char msg[256];
                    snprintf(msg, sizeof(msg), "Variable '%s' non déclarée", $1);
                    erreur(SEMANTIQUE, @1.first_line, msg, $1);
                }
                Symbol* sym = (Symbol*)$$.sym;
                if (sym && sym->kind == SYMBOL_VAR) {
                    $$.type = (void*)&sym->data.var->type;
                    $$.temp_var = strdup($1);
                } else if (sym && sym->kind == SYMBOL_FONC) {
                    $$.type = (void*)&sym->data.fonc->return_type;
                    $$.temp_var = strdup($1);
                } else {
                    static DataType int_type = {"int", 0};
                    $$.type = &int_type;
                    $$.temp_var = strdup($1);
                }
                $$.code = NULL;
                free($1);
            }
        | constant
            {
                $$.type = $1.type;
                $$.temp_var = $1.temp_var;
                $$.code = $1.code;
                $$.name = $1.name;
                $$.sym = $1.sym;
            }
        | '(' expression ')'
            {
                $$.type = $2.type;
                $$.temp_var = $2.temp_var;
                $$.code = $2.code;
                $$.name = $2.name;
                $$.sym = $2.sym;
            }
        ;

constant
        : CONSTANT
            { 
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                asprintf(&$$.temp_var, "%d", $1);
                $$.code = NULL;
                $$.name = NULL;
                $$.sym = NULL;
            }
        | HEXA
            {
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                asprintf(&$$.temp_var, "%d", $1);
                $$.code = NULL;
                $$.name = NULL;
                $$.sym = NULL;
            }
        | OCTAL
            {
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                asprintf(&$$.temp_var, "%d", $1);
                $$.code = NULL;
                $$.name = NULL;
                $$.sym = NULL;
            }
        | FLOTTANT
            {
                static DataType int_type = {"int", 0};
                $$.type = &int_type;
                asprintf(&$$.temp_var, "%d", $1);
                $$.code = NULL;
                $$.name = NULL;
                $$.sym = NULL;
            }
        ;

argument_expression_list
        : expression
            {
                $$.code = $1.code;
                $$.params_list = strdup($1.temp_var);
                $$.nb_params = 1;
            }
        | argument_expression_list ',' expression
            {
                asprintf(&$$.code, "%s%s", 
                         $1.code ? $1.code : "",
                         $3.code ? $3.code : "");
                asprintf(&$$.params_list, "%s, %s", $1.params_list, $3.temp_var);
                $$.nb_params = $1.nb_params + 1;
                free($1.params_list);
                free($1.code);
            }
        ;

struct_specifier
        : STRUCT IDENTIFIER
            {
                Symbol* s = NULL;
                if (table_courante) {
                    s = ts_lookup(table_courante, $2);
                }
                if (!s) {
                    s = new_symbol_struct($2);
                    if (table_courante) {
                        ts_insert(table_courante, s, @1.first_line);
                    }
                }
                current_struct = s;
                $$.type_nom = strdup($2);
                free($2);
            }
        | STRUCT '{' struct_declaration_list '}'
            {
                current_struct = new_symbol_struct("__anon__");
                if (table_courante) {
                    ts_insert(table_courante, current_struct, @1.first_line);
                }
                $$.type_nom = strdup("__anon__");
                current_struct = NULL;
            }
        | STRUCT IDENTIFIER '{' struct_declaration_list '}'
            {
                Symbol* s = NULL;
                if (table_courante) {
                    s = ts_lookup(table_courante, $2);
                }
                if (!s) {
                    s = new_symbol_struct($2);
                    if (table_courante) {
                        ts_insert(table_courante, s, @1.first_line);
                    }
                }
                current_struct = s;
                $$.type_nom = strdup($2);
                current_struct = NULL;
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
                if (current_struct) {
                    add_field_to_struct(current_struct, $2.name, $1.type_nom, $2.is_pointer);
                } else {
                    erreur(SEMANTIQUE, @1.first_line, "Champ de structure en dehors d'une définition de structure", $2.name);
                }
                free($1.type_nom);
                free($2.name);
            }
        ;

selection_statement
        : IF '(' expression ')' statement %prec IFX
            {
                int label = new_label();
                if ($3.code) {
                    printf("%s", $3.code);
                }
                printf("if (%s) goto L%d\n", $3.temp_var, label);
                printf("L%d:\n", label);
            }
        | IF '(' expression ')' statement ELSE statement
            {
                int label_else = new_label();
                int label_end = new_label();
                if ($3.code) {
                    printf("%s", $3.code);
                }
                printf("if (%s) goto L%d\n", $3.temp_var, label_else);
                printf("goto L%d\n", label_end);
                printf("L%d:\n", label_else);
                printf("L%d:\n", label_end);
            }
        ;

iteration_statement
        : WHILE '(' expression ')' statement
            {
                int label_start = new_label();
                int label_end = new_label();
                printf("L%d:\n", label_start);
                if ($3.code) {
                    printf("%s", $3.code);
                }
                printf("if (%s) goto L%d\n", $3.temp_var, label_start);
                printf("goto L%d\n", label_end);
                printf("L%d:\n", label_end);
            }
        | FOR '(' expression_statement expression_statement expression ')' statement
            {
                int label_cond = new_label();
                int label_body = new_label();
                int label_end = new_label();
                
                printf("/* Début du for */\n");
                
                if ($3.code) {
                    printf("%s", $3.code);
                }
                
                printf("L%d:\n", label_cond);
                
                if ($4.code) {
                    printf("%s", $4.code);
                }
                printf("if (%s) goto L%d\n", $4.temp_var, label_body);
                printf("goto L%d\n", label_end);
                
                printf("L%d:\n", label_body);
                
                if ($5.code) {
                    printf("%s", $5.code);
                }
                
                printf("goto L%d\n", label_cond);
                printf("L%d:\n", label_end);
                printf("/* Fin du for */\n");
            }
        ;

jump_statement
        : RETURN ';'
            {
                if (current_function && strcmp(current_function->data.fonc->return_type.nom_type, "void") != 0) {
                    erreur(SEMANTIQUE, @1.first_line, 
                           "return sans valeur dans une fonction qui retourne une valeur", 
                           "return");
                }
                printf("return\n");
            }
        | RETURN expression ';'
            {
                DataType* expr_type = (DataType*)$2.type;
                if (current_function) {
                    DataType* ret_type = &current_function->data.fonc->return_type;
                    if (strcmp(ret_type->nom_type, "void") == 0) {
                        erreur(SEMANTIQUE, @1.first_line,
                               "return avec valeur dans une fonction void",
                               "return");
                    } else if (strcmp(expr_type->nom_type, ret_type->nom_type) != 0 ||
                               expr_type->is_pointer != ret_type->is_pointer) {
                        char msg[256];
                        snprintf(msg, sizeof(msg),
                                 "Type de retour incompatible: attendu %s%s, reçu %s%s",
                                 ret_type->is_pointer ? "*" : "",
                                 ret_type->nom_type,
                                 expr_type->is_pointer ? "*" : "",
                                 expr_type->nom_type);
                        erreur(SEMANTIQUE, @1.first_line, msg, "return");
                    }
                }
                if ($2.code) {
                    printf("%s", $2.code);
                }
                printf("return %s\n", $2.temp_var);
            }
        | BREAK ';'
            {
                erreur(SEMANTIQUE, @1.first_line, "break statement not supported", "break");
            }
        | CONTINUE ';'
            {
                erreur(SEMANTIQUE, @1.first_line, "continue statement not supported", "continue");
            }
        ;

%%

void yyerror(const char *s) {
        erreur(SYNTAXE, yylineno, s, yytext);
        afficher_erreur();
}