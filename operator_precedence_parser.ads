package Operator_Precedence_Parser
  with Preelaborate
is

   -- Domain-specific types for robust static analysis
   type Token_Kind_Type is (Num, Add, Sub, Mul, Div, EOF);
   type Token_Value_Type is new Long_Integer;

   -- A discriminated record representing a lexical token.
   -- Operators will only carry their kind, whereas numbers carry a value.
   type Token_Type (Kind : Token_Kind_Type := EOF) is record
      case Kind is
         when Num =>
            Value : Token_Value_Type;
         when others =>
            null;
      end case;
   end record;

   type Token_Array_Type is array (Positive range <>) of Token_Type;

   -- Named exceptions for explicit error handling
   Syntax_Error     : exception;
   Evaluation_Error : exception;
   Divide_By_Zero   : exception;

   -- Precondition helper: Valid inputs must have at least an EOF token at the end.
   function Is_Valid_Input (Tokens : Token_Array_Type) return Boolean is
     (Tokens'Length > 0 and then Tokens (Tokens'Last).Kind = EOF);

   -----------------------------------------------------------------------------
   -- VARIANT 1: Table-Driven Shift-Reduce Evaluator
   -----------------------------------------------------------------------------
   -- A classic bottom-up approach relying on an operator precedence matrix
   -- (Yields, Takes, Accepts). It uses an operator stack and a value stack.
   function Evaluate_Table_Driven (Tokens : Token_Array_Type) return Token_Value_Type
     with Pre    => Is_Valid_Input (Tokens),
          Post   => True,
          Global => null;

   -----------------------------------------------------------------------------
   -- VARIANT 2: Pratt Parser (Top-Down Operator Precedence)
   -----------------------------------------------------------------------------
   -- An elegant recursive descent method resolving precedence via numerical
   -- binding powers (Left Binding Power / LBP).
   function Evaluate_Pratt (Tokens : Token_Array_Type) return Token_Value_Type
     with Pre    => Is_Valid_Input (Tokens),
          Post   => True,
          Global => null;

   -----------------------------------------------------------------------------
   -- VARIANT 3: Dijkstra's Shunting-Yard Algorithm
   -----------------------------------------------------------------------------
   -- Transforms an infix token stream into a Postfix (Reverse Polish Notation)
   -- token sequence, correctly reordering based on precedence and associativity.
   function Infix_To_RPN (Tokens : Token_Array_Type) return Token_Array_Type
     with Pre    => Is_Valid_Input (Tokens),
          Post   => True,
          Global => null;

   -- Helper to evaluate a Postfix token stream directly.
   function Evaluate_RPN (Tokens : Token_Array_Type) return Token_Value_Type
     with Pre    => Is_Valid_Input (Tokens),
          Post   => True,
          Global => null;

   -- Helper that ties Variant 3 together: parses infix to RPN, then evaluates.
   function Evaluate_Shunting_Yard (Tokens : Token_Array_Type) return Token_Value_Type
     with Pre    => Is_Valid_Input (Tokens),
          Post   => True,
          Global => null;

end Operator_Precedence_Parser;
