/**
 * Pure helpers that build the read-only text summary and the pre-targeting
 * deep link a Share hands off to the device's native share sheet (ticket 10).
 * Kept free of I/O so the exact payload text is easy to assert in tests.
 *
 * Shares never grant edit access or merge Ledgers — they only carry text.
 */

export interface ShareExpenseSource {
  amount: number; // paise
  category: string; // e.g. 'FoodDrink'
  payerName: string;
  isUserPayer: boolean;
  participants: Array<{ name: string; sharePaise: number; isUser: boolean }>;
}

const CATEGORY_LABELS: Record<string, string> = {
  FoodDrink: 'Food & Drink',
  Transport: 'Transport',
  Groceries: 'Groceries',
  RentUtilities: 'Rent & Utilities',
  Travel: 'Travel',
  Entertainment: 'Entertainment',
  Other: 'Other',
};

/** Formats paise as an INR string, e.g. 4000 -> "₹40.00". */
export function rupees(paise: number): string {
  const sign = paise < 0 ? '-' : '';
  const abs = Math.abs(paise);
  const r = Math.trunc(abs / 100);
  const f = (abs % 100).toString().padStart(2, '0');
  return `${sign}₹${r}.${f}`;
}

function categoryLabel(category: string): string {
  return CATEGORY_LABELS[category] ?? category;
}

/**
 * The read-only text summary of a single Expense. Always describes the whole
 * Expense — the amount, who paid, and each Participant's share — never grants
 * edit access, and never mentions the sender's wider Ledger.
 */
export function expenseShareText(expense: ShareExpenseSource): string {
  const lines = [
    `${rupees(expense.amount)} · ${categoryLabel(expense.category)}`,
    `Paid by ${expense.payerName}`,
  ];
  const shares = expense.participants
    .filter((p) => p.name.length > 0)
    .map((p) => `${p.name}: ${rupees(p.sharePaise)}`)
    .join(', ');
  if (shares.length > 0) lines.push(shares);
  lines.push('— CollegeSplit');
  return lines.join('\n');
}

/**
 * The read-only text summary of the User's aggregate Balance with one
 * counterparty. States the direction explicitly ("X owes you" / "you owe X").
 */
export function balanceShareText(counterparty: string, balancePaise: number): string {
  const who = balancePaise >= 0 ? `${counterparty} owes you` : `You owe ${counterparty}`;
  return [`${who} ${rupees(balancePaise)}`, '— CollegeSplit'].join('\n');
}

/**
 * Builds a deep link that pre-targets the device's native share sheet at a
 * recipient's phone number (a WhatsApp chat with the summary prefilled).
 *
 * A phone number is required here; callers that discover no phone on file should
 * choose the generic (no-target) payload instead and never call this.
 */
export function phoneDeepLink(phoneNumber: string, text: string): string {
  const digits = phoneNumber.replace(/\D/g, '');
  return `https://wa.me/${digits}?text=${encodeURIComponent(text)}`;
}
