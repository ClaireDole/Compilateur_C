D           [0-9]
L           [a-zA-Z_]
H           [a-fA-F0-9] /* hexadecimal*/
E           [Ee][+-]?{D}+ /*exposant*/
FS          (f|F|l|L)
IS          (u|U|l|L)

%option yylineno
%{
    #include <stdio.h>
    #include <string.h>
    #include <y.tab.h>
    #include "erreur.h"
    void comment();
%}

%%
    /*Gestion des commentaires*/
"/*"                    { comment(); }
"//"[^\n]*              { /* Consume single-line comment */ }

    /*Mots-clés*/
"extern"                {return EXTERN;}
"for"                   {return FOR;}
"while"                 {return WHILE;}
"break"                 {return BREAK;}
"continue"              {return CONTINUE;}
"if"                    {return IF;}
"else"                  {return ELSE;}
"return"                {return RETURN;}
"sizeof"                {return SIZEOF;}
"int"                   {return INT;}
"void"                  {return VOID;}
"struct"                {return STRUCT;}

    /*identificateurs*/
{L}({L}|{D}|[_])*       {return IDENTIFIER;}

    /*Nombres flottants*/
{D}+{E}{FS}?            { return (FLOTTANT);}
{D}*"."{D}+({E})?{FS}?  { return (FLOTTANT);}
{D}+"."{D}*({E})?{FS}?  { return (FLOTTANT);}

    /*Nombres entiers*/
0[xX]{H}+{IS}?          { return HEXA; }
0{D}+{IS}?              { return OCTAL; }
{D}+{IS}?               { return CONSTANT; }

    /*Opérateurs composés*/
"->"                    { return(PTR_OP); }
"&&"                    { return(AND_OP); }
"||"                    { return(OR_OP); }
"<="                    { return(LE_OP); }
">="                    { return(GE_OP); }
"=="                    { return(EQ_OP); }
"!="                    { return(NE_OP); }

    /*Opérateurs simples et ponctuation*/
"."                     { return '.' ; }
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
":"                     { return ':' ; }
"="                     { return '=' ; }
"("                     { return '(' ; }
")"                     { return ')' ; }
"["                     { return '[' ; }
"]"                     { return ']' ; }

/*Espaces et séparateurs*/
[\t\v\n\f]              {}
/*Gestion des erreurs*/
.                       {   char *message="Le symbole en entrée n'est pas reconnue par le langage.";
                            erreur(LEXICALE,yylineno,message,yytext);}

%%
int yywrap() {
    return 1;
}

void comment() {
    int c;
    while ((c = input()) != 0) {
        if (c == '*') {
            while ((c = input()) == '*');
            if (c == '/') return;
            if (c == 0) break;
        }
    }
}