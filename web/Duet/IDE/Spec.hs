-- |

module Duet.IDE.Spec where

import Data.Monoid
import Duet.IDE
import Duet.IDE.Test
import Duet.IDE.Types
import Duet.Types

tests :: [Test]
tests =
  [ Group "Definitions" lhsTests
  , switchToRHS (Group "Expressions" valueTests)
  ]

lhsTests :: [Test]
lhsTests =
  [ Test
      "Hitting backspace deletes decl"
      typeBackspace
      initState
      {stateAST = ModuleNode (Label {labelUUID = UUID "STARTER-MODULE"}) []}
  , Test
      "Names are letters and numbers"
      (typeChars "foo")
      (makeState "foo" initExpression)
  , Test "Names can't start with digits" (typeChars "123") initState
  , Test "Names can't start with uppercase" (typeChars "F") initState
  , Test
      "Hit backspace on a name to delete characters"
      (typeChars "foo" <> typeBackspace <> typeBackspace)
      (makeState "f" initExpression)
  , Test
      "Hit return to create a new declaration"
      [KeyDownAction False ReturnKey]
      (State
       { stateCursor = Cursor {cursorUUID = UUID "3"}
       , stateTypeCheck = Right ()
       , stateHighlightErrors = mempty
       , stateAST =
           ModuleNode
             (Label {labelUUID = UUID "STARTER-MODULE"})
             [ BindDecl
                 (Label {labelUUID = UUID "STARTER-DECL"})
                 (ImplicitBinding
                    (ImplicitlyTypedBinding
                     { implicitlyTypedBindingLabel =
                         Label {labelUUID = UUID "STARTER-BINDING"}
                     , implicitlyTypedBindingId =
                         ( Identifier {identifierString = "_"}
                         , Label {labelUUID = UUID "STARTER-BINDING-ID"})
                     , implicitlyTypedBindingAlternatives =
                         [ Alternative
                           { alternativeLabel =
                               Label {labelUUID = UUID "STARTER-ALT"}
                           , alternativePatterns = []
                           , alternativeExpression =
                               ConstantExpression
                                 (Label {labelUUID = UUID "STARTER-EXPR"})
                                 (Identifier {identifierString = "_"})
                           }
                         ]
                     }))
             , BindDecl
                 (Label {labelUUID = UUID "1"})
                 (ImplicitBinding
                    (ImplicitlyTypedBinding
                     { implicitlyTypedBindingLabel =
                         Label {labelUUID = UUID "2"}
                     , implicitlyTypedBindingId =
                         ( Identifier {identifierString = "_"}
                         , Label {labelUUID = UUID "3"})
                     , implicitlyTypedBindingAlternatives =
                         [ Alternative
                           { alternativeLabel = Label {labelUUID = UUID "4"}
                           , alternativePatterns = []
                           , alternativeExpression =
                               ConstantExpression
                                 (Label {labelUUID = UUID "5"})
                                 (Identifier {identifierString = "_"})
                           }
                         ]
                     }))
             ]
       })
  ]

valueTests :: [Test]
valueTests =
  [ Test "Hit tab to move to the next slot" [] (rhsSelectedState initExpression)
  , Test
      "Hitting backspace does nothing"
      typeBackspace
      (rhsSelectedState initExpression)
  , Group "Parentheses" parensTests
  , Group "Variable expressions" variableTests
  , Group "Function application" functionApplicationTests
  , Group "Infix expressions" infixTests
  -- , Group "If expressions" ifTests
  , Group "Lambda expressions" lambdaTests
  , Group "Case expressions" caseTests
  , Group "Literal expressions" literalTests
  ]

parensTests :: [Test]
parensTests =
  [ Test
      "Hit open parenthesis to create balanced parentheses"
      (typeChars "(")
      (focus
         (UUID "2")
         (rhsSelectedState
            (ParensExpression
               (Label {labelUUID = UUID "1"})
               (ConstantExpression
                  (Label {labelUUID = UUID "2"})
                  (Identifier {identifierString = "_"})))))
  , Test
      "Hit backspace to delete parens"
      [KeyPressAction '(', KeyDownAction False BackspaceKey]
      (focus
         (UUID "3")
         (rhsSelectedState
            (ConstantExpression
               (Label {labelUUID = UUID "3"})
               (Identifier {identifierString = "_"}))))
  , Test
      "Hit open parenthesis when on a node to create balanced parentheses"
      (typeChars "f(")
      (focus
         (UUID "2")
         (rhsSelectedState
            (ApplicationExpression
               (Label {labelUUID = UUID "3"})
               (VariableExpression
                  (Label {labelUUID = starterExprUUID})
                  (Identifier {identifierString = "f"}))
               (ParensExpression
                  (Label {labelUUID = UUID "1"})
                  (ConstantExpression
                     (Label {labelUUID = UUID "2"})
                     (Identifier {identifierString = "_"}))))))
  , Test
      "Hit close parenthesis to select the parent node"
      [ KeyPressAction '('
      , KeyPressAction 'f'
      , KeyPressAction ' '
      , KeyPressAction 'x'
      , KeyPressAction ')'
      ]
      (focus
         (UUID "1")
         (rhsSelectedState
            (ParensExpression
               (Label {labelUUID = UUID "1"})
               (ApplicationExpression
                  (Label {labelUUID = UUID "4"})
                  (VariableExpression
                     (Label {labelUUID = UUID "2"})
                     (Identifier {identifierString = "f"}))
                  (VariableExpression
                     (Label {labelUUID = UUID "3"})
                     (Identifier {identifierString = "x"}))))))
  , Test
      "Hit close parenthesis to select the parent node"
      (typeChars "fib(n-1)+fib(n-2")
      (focus
         (UUID "13")
         (rhsSelectedState
            (InfixExpression
               (Label {labelUUID = UUID "8"})
               (ApplicationExpression
                  (Label {labelUUID = UUID "3"})
                  (VariableExpression
                     (Label {labelUUID = starterExprUUID})
                     (Identifier {identifierString = "fib"}))
                  (ParensExpression
                     (Label {labelUUID = UUID "1"})
                     (InfixExpression
                        (Label {labelUUID = UUID "5"})
                        (VariableExpression
                           (Label {labelUUID = UUID "2"})
                           (Identifier {identifierString = "n"}))
                        ( "-"
                        , VariableExpression
                            (Label {labelUUID = UUID "6"})
                            (Identifier {identifierString = "-"}))
                        (LiteralExpression
                           (Label {labelUUID = UUID "4"})
                           (IntegerLiteral 1)))))
               ( "+"
               , VariableExpression
                   (Label {labelUUID = UUID "9"})
                   (Identifier {identifierString = "+"}))
               (ApplicationExpression
                  (Label {labelUUID = UUID "12"})
                  (VariableExpression
                     (Label {labelUUID = UUID "7"})
                     (Identifier {identifierString = "fib"}))
                  (ParensExpression
                     (Label {labelUUID = UUID "10"})
                     (InfixExpression
                        (Label {labelUUID = UUID "14"})
                        (VariableExpression
                           (Label {labelUUID = UUID "11"})
                           (Identifier {identifierString = "n"}))
                        ( "-"
                        , VariableExpression
                            (Label {labelUUID = UUID "15"})
                            (Identifier {identifierString = "-"}))
                        (LiteralExpression
                           (Label {labelUUID = UUID "13"})
                           (IntegerLiteral 2))))))))
  ]

literalTests :: [Test]
literalTests =
  [ Test
      "Type integer literal"
      (typeChars "123")
      (rhsSelectedState
         (LiteralExpression
            (Label {labelUUID = starterExprUUID})
            (IntegerLiteral 123)))
  , Test
      "Type integer literal, invalid chars are ignored"
      (typeChars "123abc")
      (rhsSelectedState
         (LiteralExpression
            (Label {labelUUID = starterExprUUID})
            (IntegerLiteral 123)))
  ]

caseTests :: [Test]
caseTests =
  [ Test
      "Case completion"
      (typeChars "case ")
      (focus
         (UUID "2")
         (rhsSelectedState
            (CaseExpression
               (Label {labelUUID = UUID "1"})
               (ConstantExpression
                  (Label {labelUUID = UUID "2"})
                  (Identifier {identifierString = "_"}))
               [ CaseAlt
                 { caseAltLabel = Label {labelUUID = UUID "3"}
                 , caseAltPattern =
                     WildcardPattern (Label {labelUUID = UUID "4"}) "_"
                 , caseAltExpression =
                     ConstantExpression
                       (Label {labelUUID = UUID "5"})
                       (Identifier {identifierString = "_"})
                 }
               ])))
  , Test
      "Case delete via expr"
      [ KeyPressAction 'c'
      , KeyPressAction 'a'
      , KeyPressAction 's'
      , KeyPressAction 'e'
      , KeyPressAction ' '
      , KeyDownAction False BackspaceKey
      ]
      (focus
         (UUID "6")
         (rhsSelectedState
            (ConstantExpression
               (Label {labelUUID = UUID "6"})
               (Identifier {identifierString = "_"}))))
  , Test
      "Case delete only alt"
      (typeChars "case " <> typeBackspace)
      (focus
         (UUID "6")
         (rhsSelectedState
            (ConstantExpression
               (Label {labelUUID = UUID "6"})
               (Identifier {identifierString = "_"}))))
  , Test
      "Case delete one alt of many"
      (typeChars "case " <> typeReturn <> typeBackspace)
      (focus
         (UUID "5")
         (rhsSelectedState
            (CaseExpression
               (Label {labelUUID = UUID "1"})
               (ConstantExpression
                  (Label {labelUUID = UUID "2"})
                  (Identifier {identifierString = "_"}))
               [ CaseAlt
                 { caseAltLabel = Label {labelUUID = UUID "3"}
                 , caseAltPattern =
                     WildcardPattern (Label {labelUUID = UUID "4"}) "_"
                 , caseAltExpression =
                     ConstantExpression
                       (Label {labelUUID = UUID "5"})
                       (Identifier {identifierString = "_"})
                 }
               ])))
  , Test
      "Case insert alts inbetween"
      (typeChars "case " <> typeReturn <> typeLeft <> typeReturn)
      (focus
         (UUID "10")
         (rhsSelectedState
            (CaseExpression
               (Label {labelUUID = UUID "1"})
               (ConstantExpression
                  (Label {labelUUID = UUID "2"})
                  (Identifier {identifierString = "_"}))
               [ CaseAlt
                 { caseAltLabel = Label {labelUUID = UUID "3"}
                 , caseAltPattern =
                     WildcardPattern (Label {labelUUID = UUID "4"}) "_"
                 , caseAltExpression =
                     ConstantExpression
                       (Label {labelUUID = UUID "5"})
                       (Identifier {identifierString = "_"})
                 }
               , CaseAlt
                 { caseAltLabel = Label {labelUUID = UUID "9"}
                 , caseAltPattern =
                     WildcardPattern (Label {labelUUID = UUID "10"}) "_"
                 , caseAltExpression =
                     ConstantExpression
                       (Label {labelUUID = UUID "11"})
                       (Identifier {identifierString = "_"})
                 }
               , CaseAlt
                 { caseAltLabel = Label {labelUUID = UUID "6"}
                 , caseAltPattern =
                     WildcardPattern (Label {labelUUID = UUID "7"}) "_"
                 , caseAltExpression =
                     ConstantExpression
                       (Label {labelUUID = UUID "8"})
                       (Identifier {identifierString = "_"})
                 }
               ])))
  ]

lambdaTests :: [Test]
lambdaTests =
  [ Test
      "Lambda completion"
      (typeChars "\\")
      (focus
         (UUID "3")
         (rhsSelectedState
            (LambdaExpression
               (Label {labelUUID = UUID "1"})
               (Alternative
                { alternativeLabel = Label {labelUUID = UUID "2"}
                , alternativePatterns =
                    [WildcardPattern (Label {labelUUID = UUID "3"}) "_"]
                , alternativeExpression =
                    ConstantExpression
                      (Label {labelUUID = UUID "4"})
                      (Identifier {identifierString = "_"})
                }))))
  , Test
      "Lambda arguments don't accept literal patterns"
      [KeyPressAction '\\', KeyPressAction '2']
      (focus
         (UUID "3")
         (rhsSelectedState
            (LambdaExpression
               (Label {labelUUID = UUID "1"})
               (Alternative
                { alternativeLabel = Label {labelUUID = UUID "2"}
                , alternativePatterns =
                    [WildcardPattern (Label {labelUUID = UUID "3"}) "_"]
                , alternativeExpression =
                    ConstantExpression
                      (Label {labelUUID = UUID "4"})
                      (Identifier {identifierString = "_"})
                }))))
  , Test
      "Lambda variable argument"
      [KeyPressAction '\\', KeyPressAction 'a']
      (focus
         (UUID "3")
         (rhsSelectedState
            (LambdaExpression
               (Label {labelUUID = UUID "1"})
               (Alternative
                { alternativeLabel = Label {labelUUID = UUID "2"}
                , alternativePatterns =
                    [ VariablePattern
                        (Label {labelUUID = UUID "3"})
                        (Identifier {identifierString = "a"})
                    ]
                , alternativeExpression =
                    ConstantExpression
                      (Label {labelUUID = UUID "4"})
                      (Identifier {identifierString = "_"})
                }))))
  , Test
      "Lambda make many arguments and inserting between others"
      [ KeyPressAction '\\'
      , KeyPressAction 'a'
      , KeyPressAction ' '
      , KeyPressAction 'b'
      , KeyDownAction False LeftKey
      , KeyPressAction ' '
      , KeyPressAction 'x'
      ]
      (focus
         (UUID "6")
         (rhsSelectedState
            (LambdaExpression
               (Label {labelUUID = UUID "1"})
               (Alternative
                { alternativeLabel = Label {labelUUID = UUID "2"}
                , alternativePatterns =
                    [ VariablePattern
                        (Label {labelUUID = UUID "3"})
                        (Identifier {identifierString = "a"})
                    , VariablePattern
                        (Label {labelUUID = UUID "6"})
                        (Identifier {identifierString = "x"})
                    , VariablePattern
                        (Label {labelUUID = UUID "5"})
                        (Identifier {identifierString = "b"})
                    ]
                , alternativeExpression =
                    ConstantExpression
                      (Label {labelUUID = UUID "4"})
                      (Identifier {identifierString = "_"})
                }))))
  , Test
      "Lambda delete arguments"
      [ KeyPressAction '\\'
      , KeyPressAction 'a'
      , KeyPressAction ' '
      , KeyPressAction 'b'
      , KeyPressAction ' '
      , KeyPressAction 'c'
      , KeyDownAction False LeftKey
      , KeyDownAction False BackspaceKey
      , KeyDownAction False BackspaceKey
      ]
      (focus
         (UUID "3")
         (rhsSelectedState
            (LambdaExpression
               (Label {labelUUID = UUID "1"})
               (Alternative
                { alternativeLabel = Label {labelUUID = UUID "2"}
                , alternativePatterns =
                    [ VariablePattern
                        (Label {labelUUID = UUID "3"})
                        (Identifier {identifierString = "a"})
                    , VariablePattern
                        (Label {labelUUID = UUID "6"})
                        (Identifier {identifierString = "c"})
                    ]
                , alternativeExpression =
                    ConstantExpression
                      (Label {labelUUID = UUID "4"})
                      (Identifier {identifierString = "_"})
                }))))
  , Test
      "Lambda delete via arg"
      [KeyPressAction '\\', KeyDownAction False BackspaceKey]
      (focus
         (UUID "5")
         (rhsSelectedState
            (ConstantExpression
               (Label {labelUUID = UUID "5"})
               (Identifier {identifierString = "_"}))))
  , Test
      "Lambda delete via body"
      [ KeyPressAction '\\'
      , KeyDownAction False RightKey
      , KeyDownAction False BackspaceKey
      ]
      (focus
         (UUID "5")
         (rhsSelectedState
            (ConstantExpression
               (Label {labelUUID = UUID "5"})
               (Identifier {identifierString = "_"}))))
  ]

ifTests :: [Test]
ifTests =
  [ Test
      "If completion"
      (typeChars "if ")
      (focus
         (UUID "2")
         (rhsSelectedState
            (IfExpression
               (Label {labelUUID = UUID "1"})
               (ConstantExpression
                  (Label {labelUUID = UUID "2"})
                  (Identifier {identifierString = "_"}))
               (ConstantExpression
                  (Label {labelUUID = UUID "3"})
                  (Identifier {identifierString = "_"}))
               (ConstantExpression
                  (Label {labelUUID = UUID "4"})
                  (Identifier {identifierString = "_"})))))
  , Test
      "If deletion"
      (typeChars "if " <> typeBackspace)
      (focus
         (UUID "5")
         (rhsSelectedState
            (ConstantExpression
               (Label {labelUUID = UUID "5"})
               (Identifier {identifierString = "_"}))))
  , Test
      "If deletion after then"
      (typeChars "if " <> typeRight <> typeBackspace)
      (focus
         (UUID "5")
         (rhsSelectedState
            (ConstantExpression
               (Label {labelUUID = UUID "5"})
               (Identifier {identifierString = "_"}))))
  , Test
      "If deletion after else"
      (typeChars "if " <> typeRight <> typeRight <> typeBackspace)
      (focus
         (UUID "5")
         (rhsSelectedState
            (ConstantExpression
               (Label {labelUUID = UUID "5"})
               (Identifier {identifierString = "_"}))))
  ]

functionApplicationTests :: [Test]
functionApplicationTests =
  [ Test
      "Function completion"
      (typeChars "f ")
      (focus
         (UUID "1")
         (rhsSelectedState
            (ApplicationExpression
               (Label {labelUUID = UUID "2"})
               (VariableExpression
                  (Label {labelUUID = starterExprUUID})
                  (Identifier {identifierString = "f"}))
               (ConstantExpression
                  (Label {labelUUID = UUID "1"})
                  (Identifier {identifierString = "_"})))))
  , Test
      "Type variable argument and typing one argument"
      (typeChars "f x")
      (focus
         (UUID "1")
         (rhsSelectedState
            (ApplicationExpression
               (Label {labelUUID = UUID "2"})
               (VariableExpression
                  (Label {labelUUID = starterExprUUID})
                  (Identifier {identifierString = "f"}))
               (VariableExpression
                  (Label {labelUUID = UUID "1"})
                  (Identifier {identifierString = "x"})))))
  , Test
      "Function completion and typing two arguments"
      (typeChars "f x y")
      (focus
         (UUID "5")
         (rhsSelectedState
            (ApplicationExpression
               (Label {labelUUID = UUID "6"})
               (ApplicationExpression
                  (Label {labelUUID = UUID "2"})
                  (VariableExpression
                     (Label {labelUUID = starterExprUUID})
                     (Identifier {identifierString = "f"}))
                  (VariableExpression
                     (Label {labelUUID = UUID "1"})
                     (Identifier {identifierString = "x"})))
               (VariableExpression
                  (Label {labelUUID = UUID "5"})
                  (Identifier {identifierString = "y"})))))
  , Test
      "Delete an argument from a function application"
      (typeChars "f x" <> typeBackspace <> typeBackspace)
      (focus
         starterExprUUID
         (rhsSelectedState
            (VariableExpression
               (Label {labelUUID = starterExprUUID})
               (Identifier {identifierString = "f"}))))
  , Test
      "Delete the function from a function application"
      (typeChars "f x" <> typeLeft <> typeBackspace <> typeBackspace)
      (focus
         (UUID "1")
         (rhsSelectedState
            (VariableExpression
               (Label {labelUUID = UUID "1"})
               (Identifier {identifierString = "x"}))))
  , Test
      "Add argument inbetween function and argument"
      (typeChars "f x" <> typeLeft <> typeChars " ")
      (focus
         (UUID "3")
         (rhsSelectedState
            (ApplicationExpression
               (Label {labelUUID = UUID "2"})
               (ApplicationExpression
                  (Label {labelUUID = UUID "4"})
                  (VariableExpression
                     (Label {labelUUID = starterExprUUID})
                     (Identifier {identifierString = "f"}))
                  (ConstantExpression
                     (Label {labelUUID = UUID "3"})
                     (Identifier {identifierString = "_"})))
               (VariableExpression
                  (Label {labelUUID = UUID "1"})
                  (Identifier {identifierString = "x"})))))
  , Test
      "Add argument to application directly in a lambda (regression test)"
      [ KeyPressAction '\\'
      , KeyDownAction False RightKey
      , KeyPressAction 'f'
      , KeyPressAction ' '
      ]
      (focus
         (UUID "5")
         (rhsSelectedState
            (LambdaExpression
               (Label {labelUUID = UUID "1"})
               (Alternative
                { alternativeLabel = Label {labelUUID = UUID "2"}
                , alternativePatterns =
                    [WildcardPattern (Label {labelUUID = UUID "3"}) "_"]
                , alternativeExpression =
                    ApplicationExpression
                      (Label {labelUUID = UUID "6"})
                      (VariableExpression
                         (Label {labelUUID = UUID "4"})
                         (Identifier {identifierString = "f"}))
                      (ConstantExpression
                         (Label {labelUUID = UUID "5"})
                         (Identifier {identifierString = "_"}))
                }))))
  ]

infixTests :: [Test]
infixTests =
  [ Test
      "Infix completion (after a hole)"
      (typeChars "*")
      (focus
         (UUID "1")
         (rhsSelectedState
            (InfixExpression
               (Label {labelUUID = UUID "2"})
               (ConstantExpression
                  (Label {labelUUID = UUID "STARTER-EXPR"})
                  (Identifier {identifierString = "_"}))
               ( "*"
               , VariableExpression
                   (Label {labelUUID = UUID "3"})
                   (Identifier {identifierString = "*"}))
               (ConstantExpression
                  (Label {labelUUID = UUID "1"})
                  (Identifier {identifierString = "_"})))))
  , Test
      "Infix completion (after a variable)"
      (typeChars "x*")
      (focus
         (UUID "1")
         (rhsSelectedState
            (InfixExpression
               (Label {labelUUID = UUID "2"})
               (VariableExpression
                  (Label {labelUUID = UUID "STARTER-EXPR"})
                  (Identifier {identifierString = "x"}))
               ( "*"
               , VariableExpression
                   (Label {labelUUID = UUID "3"})
                   (Identifier {identifierString = "*"}))
               (ConstantExpression
                  (Label {labelUUID = UUID "1"})
                  (Identifier {identifierString = "_"})))))
  , Test
      "Infix completion (after function application of a hole)"
      (typeChars "x *")
      (focus
         (UUID "3")
         (rhsSelectedState
            (InfixExpression
               (Label {labelUUID = UUID "4"})
               (VariableExpression
                  (Label {labelUUID = UUID "STARTER-EXPR"})
                  (Identifier {identifierString = "x"}))
               ( "*"
               , VariableExpression
                   (Label {labelUUID = UUID "5"})
                   (Identifier {identifierString = "*"}))
               (ConstantExpression
                  (Label {labelUUID = UUID "3"})
                  (Identifier {identifierString = "_"})))))
  , Test
      "Infix completion (after nested function application of a hole)"
      (typeChars "x*y *")
      (focus
         (UUID "6")
         (rhsSelectedState
            (InfixExpression
               (Label {labelUUID = UUID "2"})
               (VariableExpression
                  (Label {labelUUID = UUID "STARTER-EXPR"})
                  (Identifier {identifierString = "x"}))
               ( "*"
               , VariableExpression
                   (Label {labelUUID = UUID "3"})
                   (Identifier {identifierString = "*"}))
               (InfixExpression
                  (Label {labelUUID = UUID "7"})
                  (VariableExpression
                     (Label {labelUUID = UUID "1"})
                     (Identifier {identifierString = "y"}))
                  ( "*"
                  , VariableExpression
                      (Label {labelUUID = UUID "8"})
                      (Identifier {identifierString = "*"}))
                  (ConstantExpression
                     (Label {labelUUID = UUID "6"})
                     (Identifier {identifierString = "_"}))))))
  , Test
      "Infix completion (after nested function application of a hole)"
      (typeChars "x*y +")
      (focus
         (UUID "6")
         (rhsSelectedState
            (InfixExpression
               (Label {labelUUID = UUID "7"})
               (InfixExpression
                  (Label {labelUUID = UUID "2"})
                  (VariableExpression
                     (Label {labelUUID = UUID "STARTER-EXPR"})
                     (Identifier {identifierString = "x"}))
                  ( "*"
                  , VariableExpression
                      (Label {labelUUID = UUID "3"})
                      (Identifier {identifierString = "*"}))
                  (VariableExpression
                     (Label {labelUUID = UUID "1"})
                     (Identifier {identifierString = "y"})))
               ( "+"
               , VariableExpression
                   (Label {labelUUID = UUID "8"})
                   (Identifier {identifierString = "+"}))
               (ConstantExpression
                  (Label {labelUUID = UUID "6"})
                  (Identifier {identifierString = "_"})))))
  , Test
      "Infix preserves order of operations"
      (typeChars "*+/")
      (focus
         (UUID "7")
         (rhsSelectedState
            (InfixExpression
               (Label {labelUUID = UUID "5"})
               (InfixExpression
                  (Label {labelUUID = UUID "2"})
                  (ConstantExpression
                     (Label {labelUUID = UUID "STARTER-EXPR"})
                     (Identifier {identifierString = "_"}))
                  ( "*"
                  , VariableExpression
                      (Label {labelUUID = UUID "3"})
                      (Identifier {identifierString = "*"}))
                  (ConstantExpression
                     (Label {labelUUID = UUID "1"})
                     (Identifier {identifierString = "_"})))
               ( "+"
               , VariableExpression
                   (Label {labelUUID = UUID "6"})
                   (Identifier {identifierString = "+"}))
               (InfixExpression
                  (Label {labelUUID = UUID "8"})
                  (ConstantExpression
                     (Label {labelUUID = UUID "4"})
                     (Identifier {identifierString = "_"}))
                  ( "/"
                  , VariableExpression
                      (Label {labelUUID = UUID "9"})
                      (Identifier {identifierString = "/"}))
                  (ConstantExpression
                     (Label {labelUUID = UUID "7"})
                     (Identifier {identifierString = "_"}))))))
  , Test
      "Deleting infix RHS selects last thing on the right"
      (typeChars "f x-" <> typeBackspace)
      (focus
         (UUID "1")
         (rhsSelectedState
            (ApplicationExpression
               (Label {labelUUID = UUID "2"})
               (VariableExpression
                  (Label {labelUUID = UUID "STARTER-EXPR"})
                  (Identifier {identifierString = "f"}))
               (VariableExpression
                  (Label {labelUUID = UUID "1"})
                  (Identifier {identifierString = "x"})))))
  , Test
      "Moving after focusing a parent works like normal"
      [ KeyPressAction 'x'
      , KeyPressAction '+'
      , KeyPressAction '2'
      , KeyPressAction '*'
      , KeyPressAction '3'
      , KeyPressAction ')'
      , KeyDownAction False LeftKey
      ]
      (focus
         (UUID "3")
         (rhsSelectedState
            (InfixExpression
               (Label {labelUUID = UUID "2"})
               (VariableExpression
                  (Label {labelUUID = UUID "STARTER-EXPR"})
                  (Identifier {identifierString = "x"}))
               ( "+"
               , VariableExpression
                   (Label {labelUUID = UUID "3"})
                   (Identifier {identifierString = "+"}))
               (InfixExpression
                  (Label {labelUUID = UUID "5"})
                  (LiteralExpression
                     (Label {labelUUID = UUID "1"})
                     (IntegerLiteral 2))
                  ( "*"
                  , VariableExpression
                      (Label {labelUUID = UUID "6"})
                      (Identifier {identifierString = "*"}))
                  (LiteralExpression
                     (Label {labelUUID = UUID "4"})
                     (IntegerLiteral 3))))))
  ]

variableTests :: [Test]
variableTests =
  [ Test
      "Type variable name"
      (typeChars "foo")
      (rhsSelectedState
         (VariableExpression
            (Label {labelUUID = starterExprUUID})
            (Identifier {identifierString = "foo"})))
  , Test
      "Uppercase at the beginning of a variable name is ignored"
      (typeChars "Foo")
      (rhsSelectedState
         (VariableExpression
            (Label {labelUUID = starterExprUUID})
            (Identifier {identifierString = "oo"})))
  , Test
      "Type variable name, delete characters"
      (typeChars "foo" <> typeBackspace <> typeBackspace)
      (rhsSelectedState
         (VariableExpression
            (Label {labelUUID = starterExprUUID})
            (Identifier {identifierString = "f"})))
  , Test
      "Type variable name, backspace to a hole"
      (typeChars "foo" <> typeBackspace <> typeBackspace <> typeBackspace)
      (rhsSelectedState
         (ConstantExpression
            (Label {labelUUID = starterExprUUID})
            (Identifier {identifierString = "_"})))
  , Test
      "Type variable name with digits in it"
      (typeChars "foo123")
      (rhsSelectedState
         (VariableExpression
            (Label {labelUUID = starterExprUUID})
            (Identifier {identifierString = "foo123"})))
  ]
