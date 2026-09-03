package body Operator_Precedence_Parser is

   -----------------------------------------------------------------------------
   -- Shared Helper: Apply a binary operator
   -----------------------------------------------------------------------------
   function Apply_Operator
     (Left, Right : Token_Value_Type;
      Op          : Token_Kind_Type) return Token_Value_Type
   is
   begin
      case Op is
         when Add => return Left + Right;
         when Sub => return Left - Right;
         when Mul => return Left * Right;
         when Div =>
            if Right = 0 then
               raise Divide_By_Zero;
            end if;
            return Left / Right;
         when others =>
            raise Evaluation_Error;
      end case;
   end Apply_Operator;

   -----------------------------------------------------------------------------
   -- VARIANT 1: Table-Driven Shift-Reduce Evaluator
   -----------------------------------------------------------------------------
   function Evaluate_Table_Driven (Tokens : Token_Array_Type) return Token_Value_Type is
      type Precedence_Relation is (Yields, Takes, Accepts, Err);
      type Prec_Table_Type is array (Token_Kind_Type, Token_Kind_Type) of Precedence_Relation;

      -- Rows are stack Top, Columns are incoming Token. Num is handled lexically.
      Table : constant Prec_Table_Type :=
        (Add    => (Add => Takes, Sub => Takes, Mul => Yields, Div => Yields, EOF => Takes,   others => Err),
         Sub    => (Add => Takes, Sub => Takes, Mul => Yields, Div => Yields, EOF => Takes,   others => Err),
         Mul    => (Add => Takes, Sub => Takes, Mul => Takes,  Div => Takes,  EOF => Takes,   others => Err),
         Div    => (Add => Takes, Sub => Takes, Mul => Takes,  Div => Takes,  EOF => Takes,   others => Err),
         EOF    => (Add => Yields,Sub => Yields,Mul => Yields, Div => Yields, EOF => Accepts, others => Err),
         others => (others => Err));

      -- Bounded stacks tied to input length guarantee safety without dynamic allocation
      Val_Stack : array (1 .. Tokens'Length) of Token_Value_Type;
      Val_Top   : Natural := 0;

      Op_Stack  : array (1 .. Tokens'Length + 1) of Token_Kind_Type;
      Op_Top    : Natural := 0;

      procedure Push_Val (V : Token_Value_Type) is
      begin
         Val_Top := Val_Top + 1;
         Val_Stack (Val_Top) := V;
      end Push_Val;

      function Pop_Val return Token_Value_Type is
         V : Token_Value_Type;
      begin
         if Val_Top = 0 then raise Syntax_Error; end if;
         V := Val_Stack (Val_Top);
         Val_Top := Val_Top - 1;
         return V;
      end Pop_Val;

      procedure Push_Op (K : Token_Kind_Type) is
      begin
         Op_Top := Op_Top + 1;
         Op_Stack (Op_Top) := K;
      end Push_Op;

      function Pop_Op return Token_Kind_Type is
         K : Token_Kind_Type;
      begin
         if Op_Top = 0 then raise Syntax_Error; end if;
         K := Op_Stack (Op_Top);
         Op_Top := Op_Top - 1;
         return K;
      end Pop_Op;

      Cursor         : Positive := Tokens'First;
      Expect_Operand : Boolean := True;
      T              : Token_Type;
      Op             : Token_Kind_Type;
      Left, Right    : Token_Value_Type;
   begin
      Push_Op (EOF);

      while Cursor <= Tokens'Last loop
         T := Tokens (Cursor);

         if T.Kind = Num then
            if not Expect_Operand then raise Syntax_Error; end if;
            Push_Val (T.Value);
            Expect_Operand := False;
            Cursor := Cursor + 1;
         else
            -- Validate alternating syntax structurally
            if Expect_Operand and then T.Kind /= EOF then
               raise Syntax_Error;
            end if;

            case Table (Op_Stack (Op_Top), T.Kind) is
               when Yields =>
                  Push_Op (T.Kind);
                  Expect_Operand := True;
                  Cursor := Cursor + 1;

               when Takes =>
                  Op    := Pop_Op;
                  Right := Pop_Val;
                  Left  := Pop_Val;
                  Push_Val (Apply_Operator (Left, Right, Op));
                  -- Cursor is intentionally NOT advanced here so the table can compare
                  -- the new stack Top against the same incoming token in the next cycle.

               when Accepts =>
                  if Val_Top = 1 and then Op_Top = 1 then
                     return Pop_Val;
                  else
                     raise Syntax_Error;
                  end if;

               when Err =>
                  raise Syntax_Error;
            end case;
         end if;
      end loop;
      raise Syntax_Error;
   end Evaluate_Table_Driven;

   -----------------------------------------------------------------------------
   -- VARIANT 2: Pratt Parser
   -----------------------------------------------------------------------------
   function Evaluate_Pratt (Tokens : Token_Array_Type) return Token_Value_Type is
      Cursor : Positive := Tokens'First;

      function Peek return Token_Type is (Tokens (Cursor));

      procedure Advance is
      begin
         if Cursor < Tokens'Last then
            Cursor := Cursor + 1;
         end if;
      end Advance;

      -- LBP: Left Binding Power maps tokens to precedence tiers.
      function LBP (Kind : Token_Kind_Type) return Natural is
      begin
         case Kind is
            when Add | Sub => return 10;
            when Mul | Div => return 20;
            when others    => return 0;
         end case;
      end LBP;

      function Expression (Right_Binding_Power : Natural) return Token_Value_Type is
         Left : Token_Value_Type;
         T    : Token_Type;
      begin
         -- Null Denotation (Nud): parse prefix
         T := Peek;
         Advance;
         if T.Kind = Num then
            Left := T.Value;
         else
            raise Syntax_Error;
         end if;

         -- Left Denotation (Led): loop while incoming operator binds tighter
         while Right_Binding_Power < LBP (Peek.Kind) loop
            T := Peek;
            Advance;
            Left := Apply_Operator (Left, Expression (LBP (T.Kind)), T.Kind);
         end loop;

         return Left;
      end Expression;
   begin
      declare
         Result : constant Token_Value_Type := Expression (0);
      begin
         if Peek.Kind /= EOF then
            raise Syntax_Error;
         end if;
         return Result;
      end;
   end Evaluate_Pratt;

   -----------------------------------------------------------------------------
   -- VARIANT 3: Dijkstra's Shunting-Yard
   -----------------------------------------------------------------------------
   function Infix_To_RPN (Tokens : Token_Array_Type) return Token_Array_Type is
      Output  : Token_Array_Type (Tokens'Range);
      Out_Idx : Natural := Output'First - 1;

      Op_Stack : array (1 .. Tokens'Length) of Token_Kind_Type;
      Op_Top   : Natural := 0;

      procedure Emit (T : Token_Type) is
      begin
         Out_Idx := Out_Idx + 1;
         Output (Out_Idx) := T;
      end Emit;

      procedure Push (K : Token_Kind_Type) is
      begin
         Op_Top := Op_Top + 1;
         Op_Stack (Op_Top) := K;
      end Push;

      function Pop return Token_Kind_Type is
         K : constant Token_Kind_Type := Op_Stack (Op_Top);
      begin
         Op_Top := Op_Top - 1;
         return K;
      end Pop;

      function Precedence (K : Token_Kind_Type) return Natural is
      begin
         case K is
            when Add | Sub => return 1;
            when Mul | Div => return 2;
            when others    => return 0;
         end case;
      end Precedence;

      Expect_Operand : Boolean := True;
   begin
      for I in Tokens'Range loop
         declare
            T : constant Token_Type := Tokens (I);
         begin
            if T.Kind = Num then
               if not Expect_Operand then raise Syntax_Error; end if;
               Emit (T);
               Expect_Operand := False;
            elsif T.Kind in Add .. Div then
               if Expect_Operand then raise Syntax_Error; end if;
               -- Route operators out if their precedence is >= incoming
               while Op_Top > 0 and then Precedence (Op_Stack (Op_Top)) >= Precedence (T.Kind) loop
                  Emit ((Kind => Pop));
               end loop;
               Push (T.Kind);
               Expect_Operand := True;
            elsif T.Kind = EOF then
               if Expect_Operand and then Out_Idx >= Output'First then
                  raise Syntax_Error;
               end if;
               -- Flush remaining operators
               while Op_Top > 0 loop
                  Emit ((Kind => Pop));
               end loop;
               Emit ((Kind => EOF));
            end if;
         end;
      end loop;

      if Out_Idx < Output'First then
         raise Syntax_Error;
      end if;
      return Output (Output'First .. Out_Idx);
   end Infix_To_RPN;

   function Evaluate_RPN (Tokens : Token_Array_Type) return Token_Value_Type is
      Val_Stack : array (1 .. Tokens'Length) of Token_Value_Type;
      Val_Top   : Natural := 0;

      procedure Push (V : Token_Value_Type) is
      begin
         Val_Top := Val_Top + 1;
         Val_Stack (Val_Top) := V;
      end Push;

      function Pop return Token_Value_Type is
         V : Token_Value_Type;
      begin
         if Val_Top = 0 then raise Syntax_Error; end if;
         V := Val_Stack (Val_Top);
         Val_Top := Val_Top - 1;
         return V;
      end Pop;
   begin
      for I in Tokens'Range loop
         declare
            T           : constant Token_Type := Tokens (I);
            Left, Right : Token_Value_Type;
         begin
            case T.Kind is
               when Num =>
                  Push (T.Value);
               when Add | Sub | Mul | Div =>
                  Right := Pop;
                  Left  := Pop;
                  Push (Apply_Operator (Left, Right, T.Kind));
               when EOF =>
                  if Val_Top = 1 then
                     return Pop;
                  else
                     raise Syntax_Error;
                  end if;
            end case;
         end;
      end loop;
      raise Syntax_Error;
   end Evaluate_RPN;

   function Evaluate_Shunting_Yard (Tokens : Token_Array_Type) return Token_Value_Type is
      Postfix : constant Token_Array_Type := Infix_To_RPN (Tokens);
   begin
      return Evaluate_RPN (Postfix);
   end Evaluate_Shunting_Yard;

end Operator_Precedence_Parser;
