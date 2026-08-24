const express = require('express');
const expenseService = require('../services/expense_service');
const { authMiddleware } = require('../middleware/auth');
const { realtimeHub } = require('../realtime/websocket_hub');

const router = express.Router({ mergeParams: true });

router.use(authMiddleware);

// GET /api/trips/:tripId/expenses
router.get('/', (req, res, next) => {
  try {
    const expenses = expenseService.getExpenses(req.params.tripId, req.user.id);
    res.status(200).json({ data: expenses });
  } catch (e) {
    next(e);
  }
});

// GET /api/trips/:tripId/expenses/balance/summary
// Must be registered BEFORE /:expenseId to prevent Express from matching
// "balance" as an expenseId param.
router.get('/balance/summary', (req, res, next) => {
  try {
    const summary = expenseService.getBalanceSummary(req.params.tripId, req.user.id);
    res.status(200).json({ data: summary });
  } catch (e) {
    next(e);
  }
});

// POST /api/trips/:tripId/expenses
router.post('/', (req, res, next) => {
  try {
    const {
      id,
      title,
      amountInPaise,
      category,
      paidById,
      splitType,
      splits,
      voiceTranscript,
      receiptUrl,
    } = req.body;

    const result = expenseService.createExpense(
      req.user,
      req.params.tripId,
      {
        id,
        title,
        amountInPaise,
        category,
        paidById,
        splitType,
        splits,
        voiceTranscript,
        receiptUrl,
      },
      realtimeHub
    );

    res.status(201).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// DELETE /api/trips/:tripId/expenses/:expenseId
router.delete('/:expenseId', (req, res, next) => {
  try {
    const result = expenseService.deleteExpense(
      req.params.tripId,
      req.params.expenseId,
      req.user.id,
      realtimeHub
    );
    res.status(200).json({ data: result });
  } catch (e) {
    next(e);
  }
});

// POST /api/trips/:tripId/expenses/settle
router.post('/settle', (req, res, next) => {
  try {
    const { fromMemberId, toMemberId, amountInPaise, paymentReference, note } = req.body;
    const settlementService = require('../services/settlement_service');
    const result = settlementService.recordSettlement(
      req.user,
      req.params.tripId,
      {
        fromMemberId,
        toMemberId,
        amountInPaise,
        paymentReference,
        note,
      },
      realtimeHub
    );
    res.status(201).json({ data: result });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
