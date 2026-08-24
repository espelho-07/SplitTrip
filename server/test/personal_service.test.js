const { test, describe, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { Database } = require('../src/db/database');
const personalService = require('../src/services/personal_service');
const authService = require('../src/services/auth_service');

describe('Personal Finance Service Tests (Personal Expenses, Debts, Budgets)', () => {
  let user1, user2;

  beforeEach(() => {
    // Create fresh users for test isolation
    const auth1 = authService.createGuest({ displayName: 'Aarav Personal' });
    const auth2 = authService.createGuest({ displayName: 'Rahul Friend' });
    user1 = auth1.user;
    user2 = auth2.user;
  });

  test('1. Creates personal expense with integer paise and category', () => {
    const expense = personalService.createPersonalExpense(user1.id, {
      title: 'Lunch at Cafe',
      amountInPaise: 45000, // ₹450.00
      category: 'food',
      date: new Date().toISOString(),
    });

    assert.ok(expense.id.startsWith('pexp_'));
    assert.equal(expense.userId, user1.id);
    assert.equal(expense.title, 'Lunch at Cafe');
    assert.equal(expense.amountInPaise, 45000);
    assert.equal(expense.category, 'food');
  });

  test('2. Filters personal expenses by date and calculates category totals', () => {
    personalService.createPersonalExpense(user1.id, {
      title: 'Metro card recharge',
      amountInPaise: 50000,
      category: 'travel',
      date: '2026-08-10T10:00:00Z',
    });

    personalService.createPersonalExpense(user1.id, {
      title: 'Groceries',
      amountInPaise: 120000,
      category: 'groceries',
      date: '2026-08-15T14:00:00Z',
    });

    const result = personalService.getPersonalExpenses(user1.id, {
      startDate: '2026-08-01T00:00:00Z',
      endDate: '2026-08-31T23:59:59Z',
    });

    assert.equal(result.count, 2);
    assert.equal(result.totalSpentInPaise, 170000);
    assert.equal(result.categoryBreakdown.travel, 50000);
    assert.equal(result.categoryBreakdown.groceries, 120000);
  });

  test('3. Updates and soft-deletes personal expense with authorization checks', () => {
    const expense = personalService.createPersonalExpense(user1.id, {
      title: 'Coffee',
      amountInPaise: 20000,
      category: 'food',
    });

    const updated = personalService.updatePersonalExpense(user1.id, expense.id, {
      title: 'Cold Brew Coffee',
      amountInPaise: 25000,
    });

    assert.equal(updated.title, 'Cold Brew Coffee');
    assert.equal(updated.amountInPaise, 25000);

    // User 2 cannot delete User 1's expense
    assert.throws(() => {
      personalService.deletePersonalExpense(user2.id, expense.id);
    }, /not authorized/);

    const delResult = personalService.deletePersonalExpense(user1.id, expense.id);
    assert.equal(delResult.success, true);

    const list = personalService.getPersonalExpenses(user1.id);
    assert.equal(list.count, 0);
  });

  test('4. Tracks Lending & Borrowing with partial repayments and remaining balances', () => {
    // User 1 lends ₹1000 to Rahul
    const debt = personalService.createPersonalDebt(user1.id, {
      personName: 'Rahul',
      debtType: 'lent',
      amountInPaise: 100000,
      description: 'Dinner share',
    });

    assert.equal(debt.remainingAmountInPaise, 100000);
    assert.equal(debt.isSettled, false);

    // Rahul repays ₹400
    const rep1 = personalService.recordDebtRepayment(user1.id, debt.id, {
      amountInPaise: 40000,
      note: 'UPI transfer',
    });

    assert.equal(rep1.debt.remainingAmountInPaise, 60000);
    assert.equal(rep1.debt.isSettled, false);

    // Rahul repays remaining ₹600 -> fully settled
    const rep2 = personalService.recordDebtRepayment(user1.id, debt.id, {
      amountInPaise: 60000,
      note: 'Cash',
    });

    assert.equal(rep2.debt.remainingAmountInPaise, 0);
    assert.equal(rep2.debt.isSettled, true);

    const summary = personalService.getPersonalDebts(user1.id);
    assert.equal(summary.totalLentPaise, 0);
  });

  test('5. Manages monthly budget and computes remaining amount', () => {
    personalService.setBudget(user1.id, {
      monthYear: '2026-08',
      monthlyLimitInPaise: 2000000, // ₹20,000.00
    });

    personalService.createPersonalExpense(user1.id, {
      title: 'Weekend shopping',
      amountInPaise: 750000, // ₹7,500
      date: '2026-08-20T12:00:00Z',
    });

    const budget = personalService.getBudget(user1.id, '2026-08');
    assert.equal(budget.monthlyLimitInPaise, 2000000);
    assert.equal(budget.spentInPaise, 750000);
    assert.equal(budget.remainingInPaise, 1250000);
    assert.equal(budget.hasBudget, true);
    assert.equal(budget.percentageUsed, 38);
  });
});
