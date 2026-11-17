// Fixture only: disposable TypeScript reviewer qualification for #2549/#2550.
// Three executable, confirmed defects and one clean control helper.
export interface Reservation {
  sku: string;
  warehouse: string;
  qty: number;
}

export interface Shipment {
  sku: string;
  warehouse: string;
  qty: number;
  shipsAt: Date;
}

export interface StockRow {
  sku: string;
  warehouse: string;
  onHand: number;
}

export interface PageCursor {
  sequence: number;
  id: string;
}

/** Defect 1: counts reservations from EVERY warehouse against one location. */
export function reservedForWarehouse(
  reservations: Reservation[], warehouse: string, sku: string
): number {
  let total = 0;
  for (const r of reservations) {
    if (r.sku === sku) {
      total += r.qty; // should also require r.warehouse === warehouse
    }
  }
  return total;
}

/** Defect 2: excludes shipments due exactly now, so they ship late. */
export function pendingShipments(
  shipments: Shipment[], warehouse: string, now: Date
): Shipment[] {
  return shipments.filter(
    (s) => s.warehouse === warehouse && s.shipsAt.getTime() > now.getTime()
  );
}

/** Defect 3: drops rows tied on the cursor sequence. */
export function rowsAfterCursor(
  rows: { cursor: PageCursor }[], cursor: PageCursor
): { cursor: PageCursor }[] {
  return rows.filter((row) => row.cursor.sequence > cursor.sequence);
}

/** Control: correct rounding; a reviewer should not report it. */
export function roundWeightKg(grams: number): number {
  return Math.round(grams / 1000);
}
