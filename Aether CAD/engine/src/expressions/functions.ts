import {
  numeric,
  quantity,
  sameUnits,
  scalar,
  type ExpressionValue,
} from "./values";
export function expressionFunction(
  name: string,
  args: ExpressionValue[],
): ExpressionValue {
  const arity = (n: number) => {
    if (args.length !== n) throw Error(`${name} requires ${n} arguments.`);
  };
  if (name === "min" || name === "max") {
    if (!args.length) throw Error(`${name} needs arguments.`);
    const values = args.map(numeric),
      first = values[0];
    if (!values.every((v) => sameUnits(v, first)))
      throw Error("Function arguments have incompatible units.");
    return quantity(
      Math[name](...values.map((v) => v.magnitudeSI)),
      first.lengthPower,
      first.anglePower,
    );
  }
  if (name === "roundToPrecision") {
    arity(2);
    const precision = scalar(args[1]);
    if (!Number.isInteger(precision) || precision < 0 || precision > 15)
      throw Error("Precision must be an integer from 0 to 15.");
    return quantity(Number(scalar(args[0]).toFixed(precision)));
  }
  if (name === "atan2") {
    arity(2);
    const y = numeric(args[0]),
      x = numeric(args[1]);
    if (!sameUnits(x, y)) throw Error("atan2 arguments need matching units.");
    return quantity(Math.atan2(y.magnitudeSI, x.magnitudeSI), 0, 1);
  }
  arity(1);
  const q = numeric(args[0]);
  if (name === "abs")
    return quantity(Math.abs(q.magnitudeSI), q.lengthPower, q.anglePower);
  if (name === "sqrt")
    return quantity(
      Math.sqrt(q.magnitudeSI),
      q.lengthPower / 2,
      q.anglePower / 2,
    );
  if (["sin", "cos", "tan"].includes(name)) {
    if (!sameUnits(q, quantity(0)) && !sameUnits(q, quantity(0, 0, 1)))
      throw Error("Trigonometry requires an angle or radians as a number.");
    return quantity(
      { sin: Math.sin, cos: Math.cos, tan: Math.tan }[name]!(q.magnitudeSI),
    );
  }
  if (["asin", "acos", "atan"].includes(name))
    return quantity(
      { asin: Math.asin, acos: Math.acos, atan: Math.atan }[name]!(scalar(q)),
      0,
      1,
    );
  const functions: Record<string, (n: number) => number> = {
    round: Math.round,
    floor: Math.floor,
    ceil: Math.ceil,
    exp: Math.exp,
    log: Math.log,
  };
  if (Object.hasOwn(functions, name))
    return quantity(functions[name](scalar(q)));
  throw Error(`Unknown expression function ${name}.`);
}
