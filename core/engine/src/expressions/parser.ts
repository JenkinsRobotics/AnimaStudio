import { expressionUnits } from "./values";
export type ExpressionNode =
  | { kind: "number"; value: number }
  | { kind: "text"; value: string }
  | { kind: "symbol" | "variable"; name: string }
  | { kind: "unary"; negative: boolean; value: ExpressionNode }
  | {
      kind: "binary";
      operator: string;
      left: ExpressionNode;
      right: ExpressionNode;
    }
  | { kind: "call"; name: string; arguments: ExpressionNode[] };
/** Bounded grammar, never JavaScript execution or property lookup. */
export function parseExpression(source: string): ExpressionNode {
  if (typeof source !== "string" || !source.trim() || source.length > 4096)
    throw Error("Enter an expression of at most 4096 characters.");
  let position = 0,
    depth = 0,
    nodes = 0;
  const node = (value: ExpressionNode) => {
    if (++nodes > 1024) throw Error("Expression is too complex.");
    return value;
  };
  const skip = () => {
    while (position < source.length && /\s/.test(source[position])) position++;
  };
  const take = (token: string) => {
    skip();
    if (source.startsWith(token, position)) {
      position += token.length;
      return true;
    }
    return false;
  };
  const error = () =>
    Error(`Invalid expression near character ${position + 1}.`);
  const identifier = () => {
    skip();
    const match = /^[A-Za-z_][A-Za-z0-9_]*/.exec(source.slice(position));
    if (!match) throw error();
    position += match[0].length;
    return match[0];
  };
  const primary = (): ExpressionNode => {
    if (take("(")) {
      const result = concat();
      if (!take(")")) throw error();
      return result;
    }
    if (take("#")) return node({ kind: "variable", name: identifier() });
    skip();
    if (source[position] === '"') {
      const match =
        /^"(?:[^"\\\u0000-\u001f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"/.exec(
          source.slice(position),
        );
      if (!match) throw error();
      position += match[0].length;
      return node({ kind: "text", value: JSON.parse(match[0]) });
    }
    const match = /^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/.exec(
      source.slice(position),
    );
    if (match) {
      position += match[0].length;
      return node({ kind: "number", value: Number(match[0]) });
    }
    if (take("π")) return node({ kind: "symbol", name: "pi" });
    const name = identifier();
    if (!take("(")) return node({ kind: "symbol", name });
    const args: ExpressionNode[] = [];
    if (!take(")")) {
      do {
        args.push(concat());
        if (args.length > 32) throw error();
      } while (take(","));
      if (!take(")")) throw error();
    }
    return node({ kind: "call", name, arguments: args });
  };
  const unary = (): ExpressionNode => {
    if (++depth > 64) throw Error("Calculation is nested too deeply.");
    try {
      if (take("+")) return unary();
      if (take("-") || take("−"))
        return node({ kind: "unary", negative: true, value: unary() });
      const left = primary();
      return take("^")
        ? node({ kind: "binary", operator: "^", left, right: unary() })
        : left;
    } finally {
      depth--;
    }
  };
  const product = (): ExpressionNode => {
    let left = unary();
    for (;;) {
      if (take("*"))
        left = node({ kind: "binary", operator: "*", left, right: unary() });
      else if (take("/"))
        left = node({ kind: "binary", operator: "/", left, right: unary() });
      else {
        skip();
        const symbol = /^[A-Za-z_][A-Za-z0-9_]*/.exec(
          source.slice(position),
        )?.[0];
        if (symbol && Object.hasOwn(expressionUnits, symbol))
          left = node({ kind: "binary", operator: "*", left, right: unary() });
        else return left;
      }
    }
  };
  const sum = (): ExpressionNode => {
    let left = product();
    for (;;) {
      if (take("+"))
        left = node({ kind: "binary", operator: "+", left, right: product() });
      else if (take("-") || take("−"))
        left = node({ kind: "binary", operator: "-", left, right: product() });
      else return left;
    }
  };
  const concat = (): ExpressionNode => {
    let left = sum();
    while (take("~"))
      left = node({ kind: "binary", operator: "~", left, right: sum() });
    return left;
  };
  const result = concat();
  skip();
  if (position !== source.length) throw error();
  return result;
}
