%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_VARS 100
#define MAX_FUNCS 100
#define MAX_STMTS 100
int in_main = 0;

typedef struct {
    char* name;
    int used;
    int value;  /* For initialized variables */
} Variable;

typedef struct {
    char* name;
    int called;
    char* body;  /* Store the full body */
} Function;

typedef struct {
    char* text;  /* Store the statement text */
    int keep;    /* Whether to keep this statement in output */
} Statement;

Variable vars[MAX_VARS];
Function funcs[MAX_FUNCS];
Statement stmts[MAX_STMTS];
int var_count = 0;
int func_count = 0;
int stmt_count = 0;

void add_variable(char* name, int value);
void mark_variable_used(char* name);
void add_function(char* name, char* body);
void mark_function_called(char* name);
void add_statement(char* text);
void print_optimized_code();
void yyerror(const char* s);

extern int yylex(void);
extern FILE* yyin;
%}

%union {
    char* str;
    int num;
}

%token INT VOID MAIN PRINTF ID NUM LPAREN RPAREN LBRACE RBRACE SEMI ASSIGN STRING COMMA HASH INCLUDE LT GT FILENAME PLUS

%type <str> ID STRING FILENAME expression
%type <num> NUM

%%

program:
    headers function_list main_func { print_optimized_code(); }
    ;

headers:
    HASH INCLUDE LT FILENAME GT { /* Print later in print_optimized_code */ }
    ;

function_list:
    function function_list
    | /* empty */
    ;

function:
    VOID ID LPAREN RPAREN LBRACE statements RBRACE 
    { 
        char* body = malloc(1024);  /* Allocate space for body */
        body[0] = '\0';
        for (int i = 0; i < stmt_count; i++) {
            if (stmts[i].keep) {
                strcat(body, "    ");
                strcat(body, stmts[i].text);
                strcat(body, "\n");
            }
        }
        add_function($2, body);
        stmt_count = 0;  /* Reset statements for next function */
    }
    ;

main_func:
    INT MAIN LPAREN RPAREN LBRACE { in_main = 1; } statements RBRACE { in_main = 0; }
    ;



statements:
    statement statements
    | /* empty */
    ;

statement:
    INT ID SEMI 
    { 
        add_variable($2, 0); 
        char stmt[100];
        sprintf(stmt, "int %s;", $2);
        add_statement(stmt);
    }
    | INT ID ASSIGN NUM SEMI 
    { 
        add_variable($2, $4); 
        char stmt[100];
        sprintf(stmt, "int %s = %d;", $2, $4);
        add_statement(stmt);
    }
    | INT ID ASSIGN expression SEMI 
    { 
        add_variable($2, 0);  /* Value not tracked for expressions yet */
        char stmt[100];
        sprintf(stmt, "int %s = %s;", $2, $4);
        add_statement(stmt);
    }
    | ID ASSIGN expression SEMI 
    { 
        mark_variable_used($1);
        char stmt[100];
        sprintf(stmt, "%s = %s;", $1, $3);
        add_statement(stmt);
    }
    | PRINTF LPAREN STRING RPAREN SEMI 
    { 
        char stmt[100];
        sprintf(stmt, "printf(%s);", $3);
        add_statement(stmt);
    }
    | PRINTF LPAREN STRING COMMA ID RPAREN SEMI 
    { 
        mark_variable_used($5);
        char stmt[100];
        sprintf(stmt, "printf(%s, %s);", $3, $5);
        add_statement(stmt);
    }
    | ID LPAREN RPAREN SEMI 
    { 
        if (in_main) {
        mark_function_called($1);  // Mark function as called only in main
    }
    char stmt[100];
    sprintf(stmt, "%s();", $1);
    add_statement(stmt);
    }
    ;

expression:
    ID PLUS ID 
    { 
        mark_variable_used($1);
        mark_variable_used($3);
        char* expr = malloc(100);
        sprintf(expr, "%s + %s", $1, $3);
        $$ = expr;
    }
    | ID 
    { 
        mark_variable_used($1);
        $$ = $1;
    }
    | NUM 
    { 
        char* expr = malloc(100);
        sprintf(expr, "%d", $1);
        $$ = expr;
    }
    ;

%%

void add_variable(char* name, int value) {
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, name) == 0) return;
    }
    vars[var_count].name = strdup(name);
    vars[var_count].used = 0;
    vars[var_count].value = value;
    var_count++;
}

void mark_variable_used(char* name) {
    for (int i = 0; i < var_count; i++) {
        if (strcmp(vars[i].name, name) == 0) {
            vars[i].used = 1;
            return;
        }
    }
}

void add_function(char* name, char* body) {
    funcs[func_count].name = strdup(name);
    funcs[func_count].called = 0;
    funcs[func_count].body = strdup(body);
    func_count++;
}

void mark_function_called(char* name) {
    for (int i = 0; i < func_count; i++) {
        if (strcmp(funcs[i].name, name) == 0) {
            funcs[i].called = 1;
            return;
        }
    }
}

void add_statement(char* text) {
    stmts[stmt_count].text = strdup(text);
    stmts[stmt_count].keep = 1;  /* Default to keep; adjust later */
    stmt_count++;
}

void print_optimized_code() {
    printf("#include <stdio.h>\n\n");

    for (int i = 0; i < func_count; i++) {
        if (funcs[i].called) {
            printf("void %s() {\n%s}\n", funcs[i].name, funcs[i].body);
        }
    }

    printf("int main() {\n");
    for (int i = 0; i < stmt_count; i++) {
        int keep = 0;
        for (int j = 0; j < var_count; j++) {
            if (vars[j].used && strstr(stmts[i].text, vars[j].name)) {
                keep = 1;
                break;
            }
        }
        if (keep || strstr(stmts[i].text, "printf")) {  /* Keep printf statements */
            printf("    %s\n", stmts[i].text);
        }
    }
    printf("}\n");
}

int main() {
    yyin = stdin;
    yyparse();
    return 0;
}

void yyerror(const char* s) {
    fprintf(stderr, "Error: %s\n", s);
} 