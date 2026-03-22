%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int has_error = 0;
int saw_main = 0;
int saw_include = 0;
int saw_return = 0;
int in_main = 0;
char last_type[32] = "";
char last_id[32] = "";

int paren_count = 0;
int bracket_count = 0;
int brace_count = 0;

FILE *output_file;

void report_error(const char* msg) {
    fprintf(output_file, "Error: %s\n", msg);
    has_error = 1;
}

void check_type_match(const char* type, const char* value) {
    if (strcmp(type, "int") == 0 && strchr(value, '.') != NULL) {
        report_error("int cannot hold float value");
    }
    if ((strcmp(type, "float") == 0 || strcmp(type, "double") == 0) && strchr(value, '.') == NULL) {
        report_error("float/double should have decimal point");
    }
    if (strcmp(type, "char") == 0 && strlen(value) != 1) {
        report_error("char must be single character");
    }
    if (strcmp(type, "bool") == 0) {
        if (strcmp(value, "true") != 0 && strcmp(value, "false") != 0 &&
            strcmp(value, "1") != 0 && strcmp(value, "0") != 0) {
            report_error("bool must be true/false/1/0");
        }
    }
}

int main_check() {
    return has_error || paren_count != 0 || bracket_count != 0 || brace_count != 0 || 
           !saw_main || !saw_include || !saw_return;
}

%}

%option noyywrap

%%

"/*"([^*]|\*+[^*/])*\*+"/"    { /* skip block comment */ }
"//".*                        { /* skip line comment */ }
\"[^\"]*\"                    { /* skip string literal */ }

"#include"                    { 
    saw_include = 1; 
    fprintf(output_file, "✓ Found #include\n"); 
}

"int"                         { strcpy(last_type, "int"); }
"float"                       { strcpy(last_type, "float"); }
"char"                        { strcpy(last_type, "char"); }
"double"                      { strcpy(last_type, "double"); }
"bool"|"boolean"              { strcpy(last_type, "bool"); }

"main"                        {
    if (in_main) report_error("multiple main functions");
    saw_main = 1;
    in_main = 1;
    fprintf(output_file, "✓ Found main()\n");
}

"return"                      { 
    saw_return = 1; 
    fprintf(output_file, "✓ Found return\n");
}

[a-zA-Z_][a-zA-Z0-9_]*        {
    if (strlen(last_type) > 0 && strcmp(yytext, "main") != 0) {
        strcpy(last_id, yytext);
        fprintf(output_file, "✓ Variable '%s' declared as %s\n", yytext, last_type);
    }
}

"="                           { /* just mark assignment */ }

[0-9]*\.[0-9]+                { /* float values like 5.5 */
    if (strlen(last_id) > 0 && strlen(last_type) > 0) {
        fprintf(output_file, "  Assigning float %s to %s %s\n", yytext, last_type, last_id);
        check_type_match(last_type, yytext);
        last_id[0] = last_type[0] = 0;
    }
}

[0-9]+                        { /* int values like 5 */
    if (strlen(last_id) > 0 && strlen(last_type) > 0) {
        fprintf(output_file, "  Assigning int %s to %s %s\n", yytext, last_type, last_id);
        check_type_match(last_type, yytext);
        last_id[0] = last_type[0] = 0;
    }
}

(true|false|1|0)              { /* bool values */
    if (strlen(last_id) > 0 && strlen(last_type) > 0) {
        fprintf(output_file, "  Assigning bool %s to %s %s\n", yytext, last_type, last_id);
        check_type_match(last_type, yytext);
        last_id[0] = last_type[0] = 0;
    }
}

'[^']'                        { /* char like 'A' */
    if (strlen(last_id) > 0 && strlen(last_type) > 0) {
        fprintf(output_file, "  Assigning char '%c' to %s %s\n", yytext[1], last_type, last_id);
        check_type_match(last_type, "x");
        last_id[0] = last_type[0] = 0;
    }
}

"printf"                      { /* function call */ }
"void"                        { /* type keyword */ }
"if"|"while"|"for"            { /* control keywords */ }
";"                           { /* statement terminator */ }

"("                            { paren_count++; }
")"                            {
    if (paren_count > 0) paren_count--;
    else report_error("unmatched ')'");
}

"["                            { bracket_count++; }
"]"                            {
    if (bracket_count > 0) bracket_count--;
    else report_error("unmatched ']'");
}

"{"                            {
    brace_count++;
    if (in_main && brace_count == 1) fprintf(output_file, "Entering main body\n");
}

"}"                            {
    if (brace_count > 0) brace_count--;
    else report_error("unmatched '}'");
    if (in_main && brace_count == 0) {
        fprintf(output_file, "Exiting main body\n");
        in_main = 0;
    }
}

[ \t\r\n<>\./]+               { /* whitespace, includes, punctuation */ }
.                             { /* ignore other chars */ }

%%

int main(int argc, char **argv) {
    FILE *f = NULL;
    output_file = fopen("result.txt", "w");
    if (!output_file) {
        fprintf(stderr, "Cannot create result.txt\n");
        return 1;
    }
    
    if (argc > 1) f = fopen(argv[1], "r");
    else f = fopen("code.c", "r");
    
    if (!f) {
        fprintf(output_file, "Error: Could not open input file\n");
        fclose(output_file);
        return 1;
    }
    
    fprintf(output_file, "BASIC C COMPILER\n");
    yyin = f;
    yylex();
    fclose(f);

    fprintf(output_file, "\n Final Report \n");
    if (saw_include) fprintf(output_file, "✓ Has #include\n");
    else report_error("missing #include");
    
    if (saw_main) fprintf(output_file, "✓ Has main()\n");
    else report_error("missing main()");
    
    if (saw_return) fprintf(output_file, "✓ Has return\n");
    else report_error("missing return");

    if (paren_count > 0) report_error("unmatched '('");
    if (bracket_count > 0) report_error("unmatched '['");
    if (brace_count > 0) report_error("unmatched '{'");

    if (main_check()) {
        fprintf(output_file, "Status: ERROR\n");
        fclose(output_file);
        return 1;
    } else {
        fprintf(output_file, "Status: compiled: no error\n");
        fclose(output_file);
        return 0;
    }
}