const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const personalService = require('../services/personal_service');
const { realtimeHub } = require('../realtime/websocket_hub');

const router = express.Router();

// All personal finance routes require an authenticated user session
router.use(authMiddleware);

// ==========================================
// 1. Personal Expenses
// ==========================================

router.get('/expenses', (req, res, next) => {
  try {
    const { startDate, endDate, category } = req.query;
    const result = personalService.getPersonalExpenses(req.user.id, {
      startDate,
      endDate,
      category,
    });
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/expenses', (req, res, next) => {
  try {
    const expense = personalService.createPersonalExpense(req.user.id, req.body, realtimeHub);
    res.status(201).json({ expense });
  } catch (err) {
    next(err);
  }
});

router.put('/expenses/:id', (req, res, next) => {
  try {
    const expense = personalService.updatePersonalExpense(req.user.id, req.params.id, req.body, realtimeHub);
    res.status(200).json({ expense });
  } catch (err) {
    next(err);
  }
});

router.delete('/expenses/:id', (req, res, next) => {
  try {
    const result = personalService.deletePersonalExpense(req.user.id, req.params.id, realtimeHub);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

// ==========================================
// 2. Personal Debts (Lending & Borrowing)
// ==========================================

router.get('/debts', (req, res, next) => {
  try {
    const result = personalService.getPersonalDebts(req.user.id);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/debts', (req, res, next) => {
  try {
    const debt = personalService.createPersonalDebt(req.user.id, req.body, realtimeHub);
    res.status(201).json({ debt });
  } catch (err) {
    next(err);
  }
});

router.post('/debts/:id/repayments', (req, res, next) => {
  try {
    const result = personalService.recordDebtRepayment(req.user.id, req.params.id, req.body, realtimeHub);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

router.delete('/debts/:id', (req, res, next) => {
  try {
    const result = personalService.deletePersonalDebt(req.user.id, req.params.id, realtimeHub);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

// ==========================================
// 3. Personal Budgets
// ==========================================

router.get('/budget', (req, res, next) => {
  try {
    const { month } = req.query;
    const result = personalService.getBudget(req.user.id, month);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

router.put('/budget', (req, res, next) => {
  try {
    const result = personalService.setBudget(req.user.id, req.body, realtimeHub);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;

