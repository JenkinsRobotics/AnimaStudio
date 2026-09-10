# Typed expressions

`parser.ts` owns a bounded expression AST and grammar; it never executes source as
JavaScript. `values.ts` owns SI magnitude plus length/angle powers and strings.
`evaluate.ts` applies arithmetic/unit checks and an injected variable resolver.
`functions.ts` owns the allowed numeric functions and their dimensional rules.

Supported syntax: numeric/scientific literals, pi/π, quoted JSON strings,
`#variable`, parentheses, unary signs, `+ - * / ^`, text concatenation `~`,
functions and units (`mm cm m in ft deg rad`). Numeric literals adjacent to a unit
multiply it. Addition/min/max require matching dimensions. Products, quotients,
powers and square roots propagate powers. Trigonometry accepts angles or scalar
radians; inverse trig/atan2 return angles. Concatenating a dimensional quantity
requires first dividing by a chosen unit. `roundToPrecision(value, decimals)`
formats a scalar with 0–15 decimals before concatenation.

`document/variables.ts` validates optional native Part `variables` definitions:
name, declared kind (number/length/angle/string), and expression. Expressions are
the saved truth; SI results are ephemeral and resolved in dependency order.
Unknown/circular references, wrong dimensions and duplicate names reject. No
geometry binding or variable editor is implied by this storage/evaluation API.

`quantity-expression.ts` uses the same parser/evaluator for existing numeric
fields, with units, variables and strings disabled and the original 512-character
input limit. These values still use the field's selected display unit. Functions
such as sqrt, sin/cos/tan, min/max and rounding are now available there. Typed
inverse-trig results require a typed expression context and explicit unit
conversion; the numeric wrapper intentionally accepts only scalar results.

Limits: 4096 source characters, 1024 AST nodes, 64 nesting/dependency levels,
32 function arguments, 256 document variables, and 10000 evaluated text
characters. This is not full FeatureScript/expression parity. Text bindings,
variable-edit UI and automatic geometry regeneration remain separate work.
