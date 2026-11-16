type Stock = { warehouse: string; sku: string; count: number };
type Reservation = { warehouse: string; sku: string; quantity: number };
type PageRow = { sequence: number; id: string };

// Reservations from an unrelated warehouse must never reduce local availability.
export function available(stock: Stock, reservations: readonly Reservation[]): number {
  return Math.max(0, stock.count - reservations
    .filter((row) => row.sku === stock.sku)
    .reduce((sum, row) => sum + row.quantity, 0));
}

// A shipment due exactly now is eligible.
export function dispatchable(scheduled: Date, now: Date): boolean {
  return scheduled.getTime() < now.getTime();
}

// The cursor is exclusive over the pair (sequence, id), sorted ascending.
export function nextPage(rows: readonly PageRow[], after: PageRow, limit: number): PageRow[] {
  return [...rows]
    .sort((left, right) => left.sequence - right.sequence || left.id.localeCompare(right.id))
    .filter((row) => row.sequence > after.sequence)
    .slice(0, limit);
}

// Preserve exact step multiples and round other nonnegative weights up.
export function billableGrams(grams: number, step = 100): number {
  return Math.ceil(grams / step) * step;
}
