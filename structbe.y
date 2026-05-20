%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int backendlex(void);
extern int backendlineno;
void backenderror(const char *s);

static int nb_errors = 0;
%}

%union {
    char *nom;
    int   valeur;
}

/* ── Tokens terminaux ───────────────────────────────────── */
%token <nom>    ID
%token <valeur> CONST

%token FUNC END_FUNC DEC PROTO PARAM_TYPE PARAM CALL GOTO IF RETURN EXTERN ARROW
%token INT VOID_T
%token EQ_OP NE_OP LE_OP GE_OP

/* ── Types des non-terminaux ────────────────────────────── */
%type <nom> atom

%%

/* Programme */
backend_program
    : liste_lignes
    | /* vide */
    ;

liste_lignes
    : ligne
    | liste_lignes ligne
    ;

ligne
    : decl_globale newlines
    | definition_fonction newlines
    | PARAM_TYPE type_be newlines
    | newlines
    ;

newlines
    : '\n'
    | newlines '\n'
    ;

/* Déclarations globales */
decl_globale
    : DEC ID type_be
    | EXTERN DEC ID type_be
    | PROTO ID type_be
    | EXTERN PROTO ID type_be
    ;

/* Définition de fonction */
definition_fonction
    : FUNC ID ':' newlines corps_fonction END_FUNC ID
    ;

corps_fonction
    : /* vide */
    | corps_fonction ligne_interne
    ;

ligne_interne
    : instr_interne newlines
    | label_def newlines
    | DEC ID type_be newlines
    | EXTERN DEC ID type_be newlines
    ;

label_def
    : ID ':'
    ;

/* Instructions internes
   Les règles sont ordonnées du plus spécifique au plus
   général pour éviter les conflits shift/reduce. */
instr_interne
    /* PARAM_FETCH : x = PARAM */
    : ID '=' PARAM

    /* CALL_ASSIGN : t0 = CALL f */
    | ID '=' CALL ID

    /* ASSIGN_ADDR : t0 = &x */
    | ID '=' '&' ID

    /* LOAD : t0 = *p */
    | ID '=' '*' ID

    /* GET_FIELD : t0 = p->champ */
    | ID '=' ID ARROW ID

    /* Unaire moins : t0 = -x  ou  t0 = -42 */
    | ID '=' '-' atom

    /* Op 3 adresses avec opérateurs arithmétiques (symboles + textuels mappés) */
    | ID '=' atom '+' atom
    | ID '=' atom '-' atom
    | ID '=' atom '*' atom
    | ID '=' atom '/' atom

    /* Op 3 adresses avec opérateurs de COMPARAISON */
    | ID '=' atom EQ_OP atom
    | ID '=' atom NE_OP atom
    | ID '=' atom '<' atom
    | ID '=' atom '>' atom
    | ID '=' atom LE_OP atom
    | ID '=' atom GE_OP atom

    /* COPY / ASSIGN : x = y  ou  x = 42  (doit être en dernier) */
    | ID '=' atom

    /* STORE : *p = val */
    | '*' ID '=' atom

    /* GOTO */
    | GOTO ID

    /* IFZ : IF !(cond) GOTO label */
    | IF '!' '(' atom ')' GOTO ID

    /* PARAM <arg> */
    | PARAM atom

    /* CALL sans retour */
    | CALL ID

    /* RETURN sans valeur */
    | RETURN

    /* RETURN avec valeur */
    | RETURN atom
    ;

/* Types */
type_be
    : INT
    | VOID_T
    | VOID_T '*'
    | ID
    ;

/* Atome */
atom
    : ID      { $$ = $1; }
    | CONST   { $$ = NULL; }
    ;

%%

void backenderror(const char *s) {
    fprintf(stderr, "Erreur syntaxique backend ligne %d : %s\n",
            backendlineno, s);
    nb_errors++;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage : %s <fichier_backend>\n", argv[0]);
        return 1;
    }

    extern FILE *backendin;
    FILE *f = fopen(argv[1], "r");
    if (!f) {
        perror(argv[1]);
        return 1;
    }
    backendin = f;

    printf("--- Analyse du fichier backend : %s ---\n", argv[1]);
    int result = backendparse();
    fclose(f);

    if (result == 0 && nb_errors == 0) {
        printf("[OK] %s : syntaxe correcte.\n", argv[1]);
        return 0;
    } else {
        printf("[ECHEC] %s : %d erreur(s) syntaxique(s).\n",
               argv[1], nb_errors);
        return 1;
    }
}
