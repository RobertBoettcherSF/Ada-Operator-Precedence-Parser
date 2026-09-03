with Ada.Text_IO; use Ada.Text_IO;
with Operator_Precedence_Parser; use Operator_Precedence_Parser;

procedure Tests is
   Pass_Count : Natural := 0;
   Fail_Count : Natural := 0;

   procedure Check (Label : String; OK : Boolean) is
   begin
      if OK then
         Put_Line ("  PASS — " & Label);
         Pass_Count := Pass_Count + 1;
      else
         Put_Line ("  FAIL — " & Label);
         Fail_Count := Fail_Count + 1;
      end if;
   end Check;

   -- Lightweight string-to-token lexer for succinct, readable test cases.
   function T (Input : String) return Token_Array_Type is
      Temp  : Token_Array_Type (1 .. Input'Length + 1);
      Count : Natural := 0;
      Idx   : Positive := Input'First;
   begin
      while Idx <= Input'Last loop
         case Input (Idx) is
            when ' ' => Idx := Idx + 1;
            when '+' => Count := Count + 1; Temp (Count) := (Kind => Add); Idx := Idx + 1;
            when '-' => Count := Count + 1; Temp (Count) := (Kind => Sub); Idx := Idx + 1;
            when '*' => Count := Count + 1; Temp (Count) := (Kind => Mul); Idx := Idx + 1;
            when '/' => Count := Count + 1; Temp (Count) := (Kind => Div); Idx := Idx + 1;
            when '0' .. '9' =>
               declare
                  Val : Token_Value_Type := 0;
               begin
                  while Idx <= Input'Last and then Input (Idx) in '0' .. '9' loop
                     Val := Val * 10 + Token_Value_Type (Character'Pos (Input (Idx)) - Character'Pos ('0'));
                     Idx := Idx + 1;
                  end loop;
                  Count := Count + 1;
                  Temp (Count) := (Kind => Num, Value => Val);
               end;
            when others =>
               Idx := Idx + 1;
         end case;
      end loop;
      Count := Count + 1;
      Temp (Count) := (Kind => EOF);
      return Temp (1 .. Count);
   end T;

   procedure Test_Success (Label, Input : String; Expected : Token_Value_Type) is
      Tokens : constant Token_Array_Type := T (Input);
   begin
      Put_Line ("TEST " & Label & " — Correctness of '" & Input & "' (Expect" & Token_Value_Type'Image(Expected) & ")");
      Check (Label & ".1 Table_Driven", Evaluate_Table_Driven (Tokens) = Expected);
      Check (Label & ".2 Pratt", Evaluate_Pratt (Tokens) = Expected);
      Check (Label & ".3 Shunting_Yard", Evaluate_Shunting_Yard (Tokens) = Expected);
   end Test_Success;

   procedure Test_Exception (Label, Input : String; Expect_Div_Zero : Boolean := False) is
      Tokens : constant Token_Array_Type := T (Input);
      Val    : Token_Value_Type;
      pragma Unreferenced (Val);
   begin
      Put_Line ("TEST " & Label & " — Error Handling for '" & Input & "'");
      -- 1. Table Driven
      begin
         Val := Evaluate_Table_Driven (Tokens);
         Check (Label & ".1 Table_Driven should have raised exception", False);
      exception
         when Divide_By_Zero => Check (Label & ".1 Table_Driven Divide_By_Zero", Expect_Div_Zero);
         when Syntax_Error   => Check (Label & ".1 Table_Driven Syntax_Error", not Expect_Div_Zero);
         when others         => Check (Label & ".1 Table_Driven Raised wrong exception", False);
      end;

      -- 2. Pratt
      begin
         Val := Evaluate_Pratt (Tokens);
         Check (Label & ".2 Pratt should have raised exception", False);
      exception
         when Divide_By_Zero => Check (Label & ".2 Pratt Divide_By_Zero", Expect_Div_Zero);
         when Syntax_Error   => Check (Label & ".2 Pratt Syntax_Error", not Expect_Div_Zero);
         when others         => Check (Label & ".2 Pratt Raised wrong exception", False);
      end;

      -- 3. Shunting Yard
      begin
         Val := Evaluate_Shunting_Yard (Tokens);
         Check (Label & ".3 Shunting_Yard should have raised exception", False);
      exception
         when Divide_By_Zero => Check (Label & ".3 Shunting_Yard Divide_By_Zero", Expect_Div_Zero);
         when Syntax_Error   => Check (Label & ".3 Shunting_Yard Syntax_Error", not Expect_Div_Zero);
         when others         => Check (Label & ".3 Shunting_Yard Raised wrong exception", False);
      end;
   end Test_Exception;

begin
   -- CATEGORY: Functional Correctness & Operator Precedence
   Test_Success ("1", "1 + 2", 3);
   Test_Success ("2", "2 * 3", 6);
   Test_Success ("3", "1 + 2 * 3", 7);
   Test_Success ("4", "2 * 3 + 1", 7);

   -- CATEGORY: Associativity Rules
   Test_Success ("5", "10 - 4 - 2", 4);     -- Evaluates as (10 - 4) - 2
   Test_Success ("6", "24 / 2 / 3", 4);     -- Evaluates as (24 / 2) / 3

   -- CATEGORY: Mixed & Edge Cases
   Test_Success ("7", "42", 42);            -- Single element
   Test_Success ("8", "10 * 10 / 2 + 5", 55);

   -- CATEGORY: Error Handling (Syntax Errors)
   Test_Exception ("9",  "1 + + 2");        -- Consecutive Operators
   Test_Exception ("10", "1 +");            -- Missing RHS operand
   Test_Exception ("11", "* 2");            -- Missing LHS operand
   Test_Exception ("12", "1 / 0", Expect_Div_Zero => True); -- Math Exception
   Test_Exception ("13", "");               -- Empty Expression

   -- CATEGORY: Invariants / Intermediates (Testing specific outputs of RPN translation)
   Put_Line ("TEST 14 — RPN Translation & Intermediates");
   declare
      Tokens : constant Token_Array_Type := T ("1 + 2 * 3");
      RPN    : constant Token_Array_Type := Infix_To_RPN (Tokens);
   begin
      -- '1 + 2 * 3' -> RPN should be '1 2 3 * + EOF' (Length 6)
      Check ("14.1 Output Array correctly sized", RPN'Length = 6);
      Check ("14.2 High Precedence routed first", RPN (RPN'First + 3).Kind = Mul);
      Check ("14.3 Low Precedence routed last",   RPN (RPN'First + 4).Kind = Add);
   end;

   Put_Line ("");
   Put_Line ("=== " & Natural'Image (Pass_Count) & " passed, "
             & Natural'Image (Fail_Count) & " failed ===");
   pragma Assert (Fail_Count = 0, "Some tests failed");
end Tests;
