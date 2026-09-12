/** Row-normalized local Jacobian rank. Copies input so callers can reuse rows. */
export function diagnosticRank(input: number[][]): number {
  const rows = input
    .filter((row) => Math.hypot(...row) > 1e-8)
    .map((row) => {
      const n = Math.hypot(...row);
      return row.map((x) => x / n);
    });
  const width = rows[0]?.length ?? 0;
  let rank = 0;
  for (let col = 0; col < width && rank < rows.length; col++) {
    let pivot = rank;
    for (let i = rank + 1; i < rows.length; i++)
      if (Math.abs(rows[i][col]) > Math.abs(rows[pivot][col])) pivot = i;
    if (Math.abs(rows[pivot][col]) < 1e-7) continue;
    [rows[rank], rows[pivot]] = [rows[pivot], rows[rank]];
    const scale = rows[rank][col];
    for (let k = col; k < width; k++) rows[rank][k] /= scale;
    for (let i = rank + 1; i < rows.length; i++) {
      const f = rows[i][col];
      for (let k = col; k < width; k++) rows[i][k] -= f * rows[rank][k];
    }
    rank++;
  }
  return rank;
}
