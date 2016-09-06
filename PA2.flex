/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

int str_too_long = 0;
int str_invalid_char = 0;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
#define report_error(err) \
    { \
        cool_yylval.error_msg = strdup(err); \
        return ERROR; \
    }
#define insert_char(ch) \
    if (string_buf_ptr < string_buf + (MAX_STR_CONST - 1)) { \
        *string_buf_ptr++ = ch; \
    } else { \
        str_too_long = 1; \
    }

int nested_comment_size = 0;

%}

%x STRING_COND
%x NESTED_COMMENT
/*
 * Define names for regular expressions here.
 */

%%

 /*
  *  Nested comments
  */
--.*
"(*"            {
                    BEGIN(NESTED_COMMENT);
                    ++nested_comment_size;
                }
"*)"            {
                    report_error("Unmatched *)");
                }
<NESTED_COMMENT>{
    "*)"            {
                        if (--nested_comment_size == 0) {
                            BEGIN(INITIAL);
                        }
                    }
    "(*"            { ++nested_comment_size; }
    "\n"            { ++curr_lineno; }
    .
    <<EOF>>         {
                        BEGIN(INITIAL);
                        report_error("EOF in comment");
                    }
}

 /*
  *  Operators.
  */
"=>"		    { return DARROW; }
"<-"            { return ASSIGN; }
"<="            { return LE; }

[-{}();,@:.+*/~<=]  { return yytext[0]; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class)      { return CLASS; }
(?i:else)       { return ELSE; }
(?i:fi)         { return FI; }
(?i:if)         { return IF; }
(?i:in)         { return IN; }
(?i:inherits)   { return INHERITS; }
(?i:isvoid)     { return ISVOID; }
(?i:let)        { return LET; }
(?i:loop)       { return LOOP; }
(?i:pool)       { return POOL; }
(?i:then)       { return THEN; }
(?i:while)      { return WHILE; }
(?i:case)       { return CASE; }
(?i:esac)       { return ESAC; }
(?i:new)        { return NEW; }
(?i:of)         { return OF; }
(?i:not)        { return NOT; }

t(?i:rue)       {
                    cool_yylval.boolean = 1;
                    return BOOL_CONST;
                }
f(?i:alse)      {
                    cool_yylval.boolean = 0;
                    return BOOL_CONST;
                }

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */

\"                  {
                        str_too_long = 0;
                        str_invalid_char = 0;
                        string_buf_ptr = string_buf;
                        BEGIN(STRING_COND);
                    }
<STRING_COND>{
      \"            {
                        *string_buf_ptr = '\0';
                        BEGIN(INITIAL);
                        if (str_too_long || str_invalid_char) {
                            if (str_too_long) {
                                report_error("String constant too long");
                            } else {
                                report_error("String contains null character");
                            }
                        } else {
                            cool_yylval.symbol = stringtable.add_string(string_buf);
                            return STR_CONST;
                        }
                    }
      \\b           { insert_char('\b'); }
      \\t           { insert_char('\t'); }
      \\n           { insert_char('\n'); }
      \\f           { insert_char('\f'); }
      \\\n          {
                        insert_char('\n');
                        ++curr_lineno;
                    }
      \\[^\n\0]     { insert_char(yytext[1]); }
      \0[^\n\"]*    {
                        str_invalid_char = 1;
                    }
      .             { insert_char(yytext[0]); }
      \n            {
                        ++curr_lineno;
                        BEGIN(INITIAL);
                        report_error("Unterminated string constant");
                    }
      <<EOF>>       {
                        BEGIN(INITIAL);
                        report_error("EOF in string constant");
                    }
}

[0-9]+              {
                        cool_yylval.symbol = inttable.add_string(yytext);
                        return INT_CONST;
                    }
[A-Z][_a-zA-Z0-9]*  {
                        cool_yylval.symbol = idtable.add_string(yytext);
                        return TYPEID;
                    }
[a-z][_a-zA-Z0-9]*  {
                        cool_yylval.symbol = idtable.add_string(yytext);
                        return OBJECTID;
                    }

 /*
  * white space, EOF
  */
[ \f\r\t]+
[\n\v]              { ++curr_lineno; }
.                   {
                        report_error(yytext);
                    }
%%
