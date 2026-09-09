/**
 * Rendering. Nothing here decides anything; it is separated so that the modules that DO decide
 * contain no string arithmetic, and so this can be tested without a chain.
 */

/**
 * Render a token amount exactly. `Number(amount) / 10 ** decimals` is fine for Arc USDC and
 * silently wrong above 2^53 — and this is the line a seller reads to decide whether a job is
 * worth doing, so it must not round.
 */
export function formatUnits(amount: bigint, decimals: number): string {
  if (decimals <= 0) return amount.toString();
  const neg = amount < 0n;
  const digits = (neg ? -amount : amount).toString().padStart(decimals + 1, "0");
  const whole = digits.slice(0, digits.length - decimals);
  const frac = digits.slice(digits.length - decimals).replace(/0+$/, "");
  return `${neg ? "-" : ""}${whole}${frac ? "." + frac : ""}`;
}
