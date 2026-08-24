const crypto = require('crypto');
const { db } = require('../db/database');
const { AppError } = require('../middleware/error_handler');

class PersonalService {
  // ==========================================
  // 1. Personal Expenses
  // ==========================================

  getPersonalExpenses(userId, { startDate, endDate, category } = {}) {
    let list = db.find('personal_expenses', (e) => e.userId === userId && !e.isDeleted);

    if (startDate) {
      const start = new Date(startDate);
      list = list.filter((e) => new Date(e.date) >= start);
    }

    if (endDate) {
      const end = new Date(endDate);
      list = list.filter((e) => new Date(e.date) <= end);
    }

    if (category && category !== 'all') {
      list = list.filter((e) => e.category.toLowerCase() === category.toLowerCase());
    }

    // Sort descending by date
    list.sort((a, b) => new Date(b.date) - new Date(a.date));

    // Compute totals
    const totalSpentInPaise = list.reduce((sum, e) => sum + Number(e.amountInPaise), 0);

    const categoryBreakdown = {};
    for (const item of list) {
      const cat = item.category || 'general';
      categoryBreakdown[cat] = (categoryBreakdown[cat] || 0) + Number(item.amountInPaise);
    }

    return {
      expenses: list,
      totalSpentInPaise,
      categoryBreakdown,
      count: list.length,
    };
  }

  createPersonalExpense(userId, data) {
    if (!data.title || !data.title.trim()) {
      throw AppError.badRequest('Expense title is required');
    }

    const amountInPaise = parseInt(data.amountInPaise, 10);
    if (isNaN(amountInPaise) || amountInPaise <= 0) {
      throw AppError.badRequest('Amount must be greater than zero');
    }

    const id = data.id || `pexp_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`;
    const now = new Date().toISOString();

    const expense = {
      id,
      userId,
      title: data.title.trim(),
      amountInPaise,
      category: data.category || 'general',
      date: data.date ? new Date(data.date).toISOString() : now,
      notes: data.notes ? data.notes.trim() : null,
      voiceTranscript: data.voiceTranscript || null,
      receiptUrl: data.receiptUrl || null,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };

    db.insert('personal_expenses', expense);
    return expense;
  }

  updatePersonalExpense(userId, expenseId, data) {
    const existing = db.get('personal_expenses', expenseId);
    if (!existing || existing.isDeleted) {
      throw AppError.notFound('Personal expense not found');
    }

    if (existing.userId !== userId) {
      throw AppError.forbidden('You are not authorized to modify this expense');
    }

    const updates = {
      updatedAt: new Date().toISOString(),
    };

    if (data.title !== undefined) {
      if (!data.title.trim()) throw AppError.badRequest('Title cannot be empty');
      updates.title = data.title.trim();
    }

    if (data.amountInPaise !== undefined) {
      const amt = parseInt(data.amountInPaise, 10);
      if (isNaN(amt) || amt <= 0) throw AppError.badRequest('Amount must be greater than zero');
      updates.amountInPaise = amt;
    }

    if (data.category !== undefined) updates.category = data.category;
    if (data.date !== undefined) updates.date = new Date(data.date).toISOString();
    if (data.notes !== undefined) updates.notes = data.notes;

    const updated = db.update('personal_expenses', expenseId, updates);
    return updated;
  }

  deletePersonalExpense(userId, expenseId) {
    const existing = db.get('personal_expenses', expenseId);
    if (!existing || existing.isDeleted) {
      throw AppError.notFound('Personal expense not found');
    }

    if (existing.userId !== userId) {
      throw AppError.forbidden('You are not authorized to delete this expense');
    }

    db.update('personal_expenses', expenseId, {
      isDeleted: true,
      updatedAt: new Date().toISOString(),
    });

    return { success: true, id: expenseId };
  }

  // ==========================================
  // 2. Personal Debts (Lending & Borrowing)
  // ==========================================

  getPersonalDebts(userId) {
    const allDebts = db.find('personal_debts', (d) => d.userId === userId && !d.isDeleted);
    const repayments = db.find('personal_repayments', (r) => r.userId === userId);

    const repaymentMap = {};
    for (const r of repayments) {
      if (!repaymentMap[r.debtId]) repaymentMap[r.debtId] = [];
      repaymentMap[r.debtId].push(r);
    }

    let totalLentPaise = 0;
    let totalBorrowedPaise = 0;

    const enrichedDebts = allDebts.map((d) => {
      const debtRepayments = repaymentMap[d.id] || [];
      const repaidSum = debtRepayments.reduce((sum, r) => sum + Number(r.amountInPaise), 0);
      const remaining = Math.max(0, Number(d.initialAmountInPaise) - repaidSum);
      const isSettled = remaining === 0;

      if (!isSettled) {
        if (d.debtType === 'lent') {
          totalLentPaise += remaining;
        } else {
          totalBorrowedPaise += remaining;
        }
      }

      return {
        ...d,
        remainingAmountInPaise: remaining,
        isSettled,
        repayments: debtRepayments,
      };
    });

    enrichedDebts.sort((a, b) => new Date(b.date) - new Date(a.date));

    return {
      debts: enrichedDebts,
      totalLentPaise, // Rahul owes you
      totalBorrowedPaise, // You owe Amit
      netBalancePaise: totalLentPaise - totalBorrowedPaise,
    };
  }

  createPersonalDebt(userId, data) {
    if (!data.personName || !data.personName.trim()) {
      throw AppError.badRequest('Person name is required');
    }

    if (!['lent', 'borrowed'].includes(data.debtType)) {
      throw AppError.badRequest('Debt type must be "lent" or "borrowed"');
    }

    const amountInPaise = parseInt(data.amountInPaise, 10);
    if (isNaN(amountInPaise) || amountInPaise <= 0) {
      throw AppError.badRequest('Amount must be greater than zero');
    }

    const id = data.id || `pdebt_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`;
    const now = new Date().toISOString();

    const debt = {
      id,
      userId,
      personName: data.personName.trim(),
      debtType: data.debtType,
      initialAmountInPaise: amountInPaise,
      remainingAmountInPaise: amountInPaise,
      description: data.description ? data.description.trim() : null,
      date: data.date ? new Date(data.date).toISOString() : now,
      dueDate: data.dueDate ? new Date(data.dueDate).toISOString() : null,
      isSettled: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };

    db.insert('personal_debts', debt);
    return {
      ...debt,
      repayments: [],
    };
  }

  recordDebtRepayment(userId, debtId, data) {
    const debt = db.get('personal_debts', debtId);
    if (!debt || debt.isDeleted) {
      throw AppError.notFound('Debt record not found');
    }

    if (debt.userId !== userId) {
      throw AppError.forbidden('You are not authorized to modify this debt');
    }

    const amountInPaise = parseInt(data.amountInPaise, 10);
    if (isNaN(amountInPaise) || amountInPaise <= 0) {
      throw AppError.badRequest('Repayment amount must be greater than zero');
    }

    const repaymentId = `prepay_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`;
    const now = new Date().toISOString();

    const repayment = {
      id: repaymentId,
      debtId,
      userId,
      amountInPaise,
      date: data.date ? new Date(data.date).toISOString() : now,
      note: data.note ? data.note.trim() : null,
      createdAt: now,
    };

    db.insert('personal_repayments', repayment);

    // Recompute remaining balance
    const allRepayments = db.find('personal_repayments', (r) => r.debtId === debtId);
    const totalRepaid = allRepayments.reduce((sum, r) => sum + Number(r.amountInPaise), 0);
    const remaining = Math.max(0, Number(debt.initialAmountInPaise) - totalRepaid);
    const isSettled = remaining === 0;

    const updatedDebt = db.update('personal_debts', debtId, {
      remainingAmountInPaise: remaining,
      isSettled,
      updatedAt: now,
    });

    return {
      debt: {
        ...updatedDebt,
        repayments: allRepayments,
      },
      repayment,
    };
  }

  deletePersonalDebt(userId, debtId) {
    const debt = db.get('personal_debts', debtId);
    if (!debt || debt.isDeleted) {
      throw AppError.notFound('Debt record not found');
    }

    if (debt.userId !== userId) {
      throw AppError.forbidden('You are not authorized to delete this debt');
    }

    db.update('personal_debts', debtId, {
      isDeleted: true,
      updatedAt: new Date().toISOString(),
    });

    return { success: true, id: debtId };
  }

  // ==========================================
  // 3. Personal Budgets
  // ==========================================

  getBudget(userId, monthYear) {
    const targetMonth = monthYear || new Date().toISOString().substring(0, 7);
    const budget = db.findOne('personal_budgets', (b) => b.userId === userId && b.monthYear === targetMonth);

    // Calculate actual spending in that month
    const startOfMonth = `${targetMonth}-01T00:00:00.000Z`;
    const endOfMonth = new Date(new Date(startOfMonth).setMonth(new Date(startOfMonth).getMonth() + 1)).toISOString();

    const expenses = db.find('personal_expenses', (e) =>
      e.userId === userId &&
      !e.isDeleted &&
      e.date >= startOfMonth &&
      e.date < endOfMonth
    );

    const spentInPaise = expenses.reduce((sum, e) => sum + Number(e.amountInPaise), 0);
    const monthlyLimitInPaise = budget ? Number(budget.monthlyLimitInPaise) : 0;
    const remainingInPaise = Math.max(0, monthlyLimitInPaise - spentInPaise);

    return {
      monthYear: targetMonth,
      monthlyLimitInPaise,
      spentInPaise,
      remainingInPaise,
      hasBudget: monthlyLimitInPaise > 0,
      percentageUsed: monthlyLimitInPaise > 0 ? Math.min(100, Math.round((spentInPaise / monthlyLimitInPaise) * 100)) : 0,
    };
  }

  setBudget(userId, data) {
    const targetMonth = data.monthYear || new Date().toISOString().substring(0, 7);
    const limitInPaise = parseInt(data.monthlyLimitInPaise, 10);
    if (isNaN(limitInPaise) || limitInPaise < 0) {
      throw AppError.badRequest('Monthly limit must be a positive number');
    }

    const now = new Date().toISOString();
    const existing = db.findOne('personal_budgets', (b) => b.userId === userId && b.monthYear === targetMonth);

    if (existing) {
      db.update('personal_budgets', existing.id, {
        monthlyLimitInPaise: limitInPaise,
        updatedAt: now,
      });
    } else {
      const budget = {
        id: `pbudg_${crypto.randomUUID().replace(/-/g, '').substring(0, 12)}`,
        userId,
        monthYear: targetMonth,
        monthlyLimitInPaise: limitInPaise,
        createdAt: now,
        updatedAt: now,
      };
      db.insert('personal_budgets', budget);
    }

    return this.getBudget(userId, targetMonth);
  }
}

module.exports = new PersonalService();
