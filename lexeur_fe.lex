D           [0-9]
L           [a-zA-Z]
H           [a-fA-F0-9] /* hexadecimal*/
E           [Ee][+]?{D}+ /*exposant*/
FS          (f|F|l|L)
IS          (u|U|l|L)

%option yylineno
%{
    #include <stdio.h>
    #include <y.tab.h>

    void comment();

%}
%%
"/*"                    { comment(); }
"//"[^\n]*              { /* Consume single-line comment */ }

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

{L}({L}|{D}|[_])*       {return IDENTIFIER;}

0[xX]{H}+{IS}?          { return HEXA; }
0{D}+{IS}?              { return OCTAL; }
{D}+{IS}?               { return CONSTANT; }

"->"                    { return(PTR_OP); }
"&&"                    { return(AND_OP); }
"||"                    { return(OR_OP); }
"<="                    { return(LE_OP); }
">="                    { return(GE_OP); }
"=="                    { return(EQ_OP); }
"!="                    { return(NE_OP); }

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

[\t\v\n\f]          {pass;}

{D}+{E}{FS}?            {  }
{D}*"."{D}+({E})?{FS}?  {  }
{D}+"."{D}*({E})?{FS}?  {  }

L?\"(\\.|[^\\"])*\"     {}
%%

/* Function to handle multi-line comments */
void comment() {
    char c, c1;
loop:
    while ((c = input()) != '*' && c != 0);
    if ((c1 = input()) != '/' && c != 0) {
        unput(c1);
        goto loop;
    }
}