import type { InputHTMLAttributes } from "react";

export type TextFieldProps = InputHTMLAttributes<HTMLInputElement>;

/** Single-line inset text input. */
export function TextField({ className, ...rest }: TextFieldProps) {
  const classes = ["aui-text-field"];
  if (className) classes.push(className);
  return <input className={classes.join(" ")} {...rest} />;
}
