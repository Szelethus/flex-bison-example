%language "c++"
%locations
%define api.value.type variant

%code top {
#include "implementation.hh"
#include <list>
}

%code provides {
int yylex(yy::parser::semantic_type* yylval, yy::parser::location_type* yylloc);
}

%token PRG
%token BEG
%token END
%token BOO
%token NAT
%token REA
%token WRI
%token IF
%token THE
%token ELS
%token EIF
%token WHI
%token DO
%token DON
%token TRU
%token FAL
%token ASN
%token OP
%token CL
%token <std::string> ID
%token <std::string> NUM

%left OR
%left AND
%left EQ
%left LS GR LSE GRE
%left ADD SUB
%left MUL DIV MOD
%left COLON QMARK
%right COMMA
%precedence NOT

%type <expression*> expression
%type <instruction*> command
%type <std::list<instruction*>* > commands
%type <std::list<instruction*>* > assignments

%%

start:
    PRG ID declarations BEG commands END
    {
        type_check_commands($5);
        if(current_mode == compiler) {
            generate_code($5);
        } else {
            execute_commands($5);
        }
        delete_commands($5);
    }
;

declarations:
    // empty
|
    declarations declaration
;

declaration:
    BOO ID
    {
        symbol(@1.begin.line, $2, boolean).declare();
    }
|
    NAT ID
    {
        symbol(@1.begin.line, $2, natural).declare();
    }
;

commands:
    // empty
    {
        $$ = new std::list<instruction*>();
    }
|
    commands command
    {
        $1->push_back($2);
        $$ = $1;
    }
|
    commands assignments
    {
        std::vector<expression *> right_hands;
        for (std::list<instruction*>::iterator it = $2->begin(); it != $2->end(); ++it) {
          assign_instruction *a = static_cast<assign_instruction *>(*it);
          right_hands.push_back(a->get_right());
        }
        std::reverse(right_hands.begin(), right_hands.end());

        for (std::list<instruction*>::iterator it = $2->begin(); it != $2->end(); ++it) {
          assign_instruction *a = static_cast<assign_instruction *>(*it);
          a->set_right(right_hands.back());
          right_hands.pop_back();
        }
        $1->insert($1->end(), $2->begin(), $2->end());
        $$ = $1;
    }
;

command:
    REA OP ID CL
    {
        $$ = new read_instruction(@1.begin.line, $3);
    }
|
    WRI OP expression CL
    {
        $$ = new write_instruction(@1.begin.line, $3);
    }
|
    IF expression THE commands EIF
    {
        $$ = new if_instruction(@1.begin.line, $2, $4, 0);
    }
|
    IF expression THE commands ELS commands EIF
    {
        $$ = new if_instruction(@1.begin.line, $2, $4, $6);
    }
|
    WHI expression DO commands DON
    {
        $$ = new while_instruction(@1.begin.line, $2, $4);
    }
;

assignments:
    ID COMMA assignments COMMA expression 
    {
        $3->push_back(new assign_instruction(@2.begin.line, $1, $5));
        $$ = $3;
    }
|
    ID ASN expression
    {
        $$ = new std::list<instruction*>();
        $$->push_back(new assign_instruction(@2.begin.line, $1, $3));
    }
;

expression:
    NUM
    {
        $$ = new number_expression($1);
    }
|
    TRU
    {
        $$ = new boolean_expression(true);
    }
|
    FAL
    {
        $$ = new boolean_expression(false);
    }
|
    ID
    {
        $$ = new id_expression(@1.begin.line, $1);
    }
|
    expression ADD expression
    {
        $$ = new binop_expression(@2.begin.line, "+", $1, $3);
    }
|
    expression SUB expression
    {
        $$ = new binop_expression(@2.begin.line, "-", $1, $3);
    }
|
    expression MUL expression
    {
        $$ = new binop_expression(@2.begin.line, "*", $1, $3);
    }
|
    expression DIV expression
    {
        $$ = new binop_expression(@2.begin.line, "/", $1, $3);
    }
|
    expression MOD expression
    {
        $$ = new binop_expression(@2.begin.line, "%", $1, $3);
    }
|
    expression LS expression
    {
        $$ = new binop_expression(@2.begin.line, "<", $1, $3);
    }
|
    expression GR expression
    {
        $$ = new binop_expression(@2.begin.line, ">", $1, $3);
    }
|
    expression LSE expression
    {
        $$ = new binop_expression(@2.begin.line, "<=", $1, $3);
    }
|
    expression GRE expression
    {
        $$ = new binop_expression(@2.begin.line, ">=", $1, $3);
    }
|
    expression AND expression
    {
        $$ = new binop_expression(@2.begin.line, "and", $1, $3);
    }
|
    expression OR expression
    {
        $$ = new binop_expression(@2.begin.line, "or", $1, $3);
    }
|
    expression QMARK expression COLON expression
    {
        $$ = new triop_expression(@2.begin.line, "?:", $1, $3, $5);
    }
|
    expression EQ expression
    {
        $$ = new binop_expression(@2.begin.line, "=", $1, $3);
    }
|
    NOT expression
    {
        $$ = new not_expression(@1.begin.line, "not", $2);
    }
|
    OP expression CL
    {
        $$ = $2;
    }
;

%%
