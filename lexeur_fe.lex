D           [0-9]
L           [a-zA-Z]
H           [a-fA-F0-9] 
E           [Ee][+-]?{D}+ 
FS          (f|F|l|L)
IS          (u|U|l|L)

%option yylineno
%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <errno.h>
    #include "erreur.h"
    #include "gestion_tables.h"
    #include "tablesymb.h"
    #include "structfe.tab.h"
    void comment();
%}

%%
"/*"                    { comment(); }
"//"[^\n]*              { /* Consume single-line comment */ }

"extern"                {return EXTERN;}
"for"                   {return FOR;}
"while"                 {return WHILE;}
"if"                    {return IF;}
"else"                  {return ELSE;}
"return"                {return RETURN;}
"sizeof"                {return SIZEOF;}
"int"                   {return INT;}
"void"                  {return VOID;}
"struct"                {return STRUCT;}


{L}({L}|{D}|"_")*       { yylval.nom = strdup(yytext); return IDENTIFIER;}


{D}+{E}{FS}?            {char* message = "Les chiffres à virgule ne sont pas autorisés."; erreur(LEXICALE,yylineno,message,yytext);}
{D}*"."{D}+({E})?{FS}?  { char* message = "Les chiffres à virgule ne sont pas autorisés."; erreur(LEXICALE,yylineno,message,yytext);}
{D}+"."{D}*({E})?{FS}?  { char* message = "Les chiffres à virgule ne sont pas autorisés."; erreur(LEXICALE,yylineno,message,yytext);}


0[xX]{H}+{IS}?          { char *message="Les hexadécimaux ne sont pas autorisés. Base 10 uniquement."; erreur(LEXICALE,yylineno,message,yytext); }
0{D}+{IS}?              { char *message="Les octaux ne sont pas autorisés. Base 10 uniquement."; erreur(LEXICALE,yylineno,message,yytext); }
{D}+{IS}?               { yylval.valeur = atoi(yytext); return CONSTANT;}

"->"                    { return(PTR_OP); }
"&&"                    { return(AND_OP); }
"||"                    { return(OR_OP); }
"<="                    { return(LE_OP); }
">="                    { return(GE_OP); }
"=="                    { return(EQ_OP); }
"!="                    { return(NE_OP); }


"&"                     { return '&'; }
"-"                     { return '-'; }
"+"                     { return '+'; }
"*"                     { return '*'; }
"/"                     { return '/'; }
"<"                     { return('<'); }
">"                     { return('>'); }
";"                     { return ';' ; }
"{"                     { return '{' ; }
"}"                     { return '}' ; }
","                     { return ',' ; }
"="                     { return '=' ; }
"("                     { return '(' ; }
")"                     { return ')' ; }



[\t\v\n\f\r' ']              { }

"..."                   { char* msg = "Les fonctions variadiques (...) ne sont pas supportees."; erreur(LEXICALE, yylineno, msg, yytext);}
"."                     {   char* msg="Les structures ne sont manipulables que par pointeur, opérateur . incorrect. Merci d'utiliser ->"; erreur(LEXICALE, yylineno, msg, yytext);}
.                       {   char *message="Le symbole en entrée n'est pas reconnue par le langage."; erreur(LEXICALE,yylineno,message,yytext);}

%%
int yywrap() {
    return 1;
}

void comment() {
    int c;
    while (1) {
        while ((c = input()) != '*' && c != EOF);
        if (c == '*') {
            while ((c = input()) == '*');
            if (c == '/') break;
            if (c == EOF) {
                char* msg = "Commentaire non fermé";
                erreur(LEXICALE, yylineno, msg, yytext);
            }
        }
        if (c == EOF) {
            char* msg = "Commentaire non fermé";
            erreur(LEXICALE, yylineno, msg, yytext);
        }
    }
}
