import { parseExpression, type ExpressionNode } from "./parser";
import { expressionFunction } from "./functions";
import {
  expressionUnits,
  expressionText,
  numeric,
  quantity,
  sameUnits,
  scalar,
  type ExpressionValue,
} from "./values";
export interface ExpressionContext {
  resolveVariable?: (name: string) => ExpressionValue;
  allowUnits?: boolean;
  allowText?: boolean;
}
export function evaluateExpression(
  source: string,
  context: ExpressionContext = {},
): ExpressionValue {
  const visit = (node: ExpressionNode): ExpressionValue => {
    switch (node.kind) {
      case "number":
        return quantity(node.value);
      case "text":
        if (context.allowText === false)
          throw Error("Text is not allowed in a numeric field.");
        return node.value;
      case "symbol":
        if (node.name === "pi") return quantity(Math.PI);
        if (
          context.allowUnits !== false &&
          Object.hasOwn(expressionUnits, node.name)
        )
          return { ...expressionUnits[node.name] };
        throw Error(`Unknown or unavailable symbol ${node.name}.`);
      case "variable":
        if (!context.resolveVariable)
          throw Error(`Unknown variable #${node.name}.`);
        return context.resolveVariable(node.name);
      case "unary": {
        const value = numeric(visit(node.value));
        return quantity(
          -value.magnitudeSI,
          value.lengthPower,
          value.anglePower,
        );
      }
      case "call":
        return expressionFunction(node.name, node.arguments.map(visit));
      case "binary": {
        const a = visit(node.left),
          b = visit(node.right);
        if (node.operator === "~") {
          if (context.allowText === false)
            throw Error("Text is not allowed in a numeric field.");
          const result = expressionText(a) + expressionText(b);
          if (result.length > 10000)
            throw Error("Expression text is too long.");
          return result;
        }
        const x = numeric(a),
          y = numeric(b);
        if (node.operator === "+" || node.operator === "-") {
          if (!sameUnits(x, y))
            throw Error("Cannot add quantities with different units.");
          return quantity(
            x.magnitudeSI +
              (node.operator === "+" ? y.magnitudeSI : -y.magnitudeSI),
            x.lengthPower,
            x.anglePower,
          );
        }
        if (node.operator === "^") {
          const power = scalar(y);
          return quantity(
            x.magnitudeSI ** power,
            x.lengthPower * power,
            x.anglePower * power,
          );
        }
        const divide = node.operator === "/",
          sign = divide ? -1 : 1;
        return quantity(
          divide
            ? x.magnitudeSI / y.magnitudeSI
            : x.magnitudeSI * y.magnitudeSI,
          x.lengthPower + sign * y.lengthPower,
          x.anglePower + sign * y.anglePower,
        );
      }
    }
  };
  return visit(parseExpression(source));
}
