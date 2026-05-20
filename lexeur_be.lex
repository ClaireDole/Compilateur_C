%{
#include "backend.tab.h"
#include <string.h>
%}

%option noyywrap
%option yylineno
%option prefix="backend"

%%

[ \t\r]+        { /* ignorer espaces et tabulations */ }
\n              { return '\n'; }

"/*"([^*]|\*+[^*/])*\*+"/"  { /* ignorer commentaires */ }

"extern"        { return EXTERN; }
"int"           { return INT; }
"void"          { return VOID_T; }

"FUNC"          { return FUNC; }
"END_FUNC"      { return END_FUNC; }
"DEC"           { return DEC; }
"PROTO"         { return PROTO; }
"PARAM_TYPE"    { return PARAM_TYPE; }
"PARAM"         { return PARAM; }
"CALL"          { return CALL; }
"GOTO"          { return GOTO; }
"IF"            { return IF; }
"RETURN"        { return RETURN; }

"ADD"           { return '+'; }
"SUB"           { return '-'; }
"MUL"           { return '*'; }
"DIV"           { return '/'; }

"LT"            { return '<'; }
"GT"            { return '>'; }
"LE"            { return LE_OP; }
"GE"            { return GE_OP; }
"EQ"            { return EQ_OP; }
"NE"            { return NE_OP; }

"=="            { return EQ_OP; }
"!="            { return NE_OP; }
"<="            { return LE_OP; }
">="            { return GE_OP; }
"<"             { return '<'; }
">"             { return '>'; }
"->"            { return ARROW; }

"="             { return '='; }
":"             { return ':'; }
"("             { return '('; }
")"             { return ')'; }
","             { return ','; }
"*"             { return '*'; }
"&"             { return '&'; }
"-"             { return '-'; }
"+"             { return '+'; }
"/"             { return '/'; }
"!"             { return '!'; }

[a-zA-Z_][a-zA-Z0-9_]* {
    backendlval.nom = strdup(yytext);
    return ID;
}

[0-9]+ {
    backendlval.valeur = atoi(yytext);
    return CONST;
}

. { fprintf(stderr, "Erreur lexicale backend ligne %d : caractere inattendu '%s'\n", backendlineno, yytext); }

%%
