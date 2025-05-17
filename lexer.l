%{
#include <stdio.h>
#include <string.h>
#include "parser.tab.h"
%}

%option noyywrap

%%
"//".*                          { /* skip single-line comment */ }
"/*"([^*]|\*+[^*/])*\*+"/"      { /* skip multi-line comment */ }

"int"           { return INT; }
"void"          { return VOID; }
"main"          { return MAIN; }

"printf"        { return PRINTF; }
"include"       { return INCLUDE; }
[a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z]+  { yylval.str = strdup(yytext); return FILENAME; }
[a-zA-Z_][a-zA-Z0-9_]*  { yylval.str = strdup(yytext); return ID; }
[0-9]+          { yylval.num = atoi(yytext); return NUM; }
"("             { return LPAREN; }
")"             { return RPAREN; }
"{"             { return LBRACE; }
"}"             { return RBRACE; }
";"             { return SEMI; }
"="             { return ASSIGN; }
"+"             { return PLUS; }  /* New token for addition */
"\""[^\"]*"\""  { yylval.str = strdup(yytext); return STRING; }
","             { return COMMA; }
"#"             { return HASH; }
"<"             { return LT; }
">"             { return GT; }
[ \t\n\r]+      ; /* Ignore all whitespace */
.               { printf("Unexpected character: '%c'\n", yytext[0]); }

%%