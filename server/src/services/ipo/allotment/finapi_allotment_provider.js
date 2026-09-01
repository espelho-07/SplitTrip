/**
 * FinAPI Allotment Provider
 *
 * Integrates with FinAPI / authorized financial data feeds.
 */

const { AllotmentProvider, AllotmentResult } = require('./allotment_provider_interface');

class FinApiAllotmentProvider extends AllotmentProvider {
  constructor(options = {}) {
    super('finapi', 'FinAPI Allotment Feed');
    this.baseUrl = options.baseUrl || 'https://finapi.upvaly.com/api';
    this.apiKey = options.apiKey || process.env.FINAPI_API_KEY;
  }

  get isConfigured() {
    return true;
  }

  async checkAllotment({ ipoSymbol, ipoName, pan, applicationNumber, registrar, lotsApplied, lotSize, bidPriceRupees }) {
    if (!ipoSymbol && !ipoName) {
      return new AllotmentResult({
        status: 'UNKNOWN',
        confidence: 0,
        message: 'Insufficient IPO identifiers for query',
        providerId: this.id,
      });
    }

    try {
      const url = `${this.baseUrl}/ipo/allotment`;
      const queryParams = new URLSearchParams({
        symbol: ipoSymbol || '',
        name: ipoName || '',
      });

      if (applicationNumber) {
        queryParams.append('app_no', applicationNumber);
      }
      if (pan) {
        queryParams.append('pan', pan);
      }

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 6000);

      const response = await fetch(`${url}?${queryParams.toString()}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Kith-Backend/1.0',
          ...(this.apiKey ? { 'Authorization': `Bearer ${this.apiKey}` } : {}),
        },
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        if (response.status === 404) {
          return new AllotmentResult({
            status: 'PENDING',
            confidence: 0.8,
            message: 'Allotment is still pending or not published yet by registrar',
            providerId: this.id,
          });
        }
        throw new Error(`FinAPI returned HTTP ${response.status}`);
      }

      const body = await response.json();
      const data = body.data || body;

      if (!data || data.status === 'pending' || data.is_allotment_out === false) {
        return new AllotmentResult({
          status: 'PENDING',
          confidence: 0.9,
          message: 'Allotment is in progress / not finalized yet',
          providerId: this.id,
          raw: data,
        });
      }

      const outcome = (data.allotment_status || data.status || '').toUpperCase();
      const allottedLots = parseInt(data.allotted_lots || (data.allotted_shares ? data.allotted_shares / (lotSize || 1) : 0), 10) || 0;
      const allottedShares = parseInt(data.allotted_shares || (allottedLots * (lotSize || 1)), 10) || 0;

      if (outcome.includes('ALLOT') && allottedLots > 0) {
        const isPartial = lotsApplied && allottedLots < lotsApplied;
        return new AllotmentResult({
          status: isPartial ? 'PARTIALLY_ALLOTTED' : 'ALLOTTED',
          allottedLots,
          allottedShares,
          issuePriceRupees: data.issue_price || bidPriceRupees,
          confidence: 1.0,
          message: isPartial ? `Partially allotted ${allottedLots} lots` : `Allotted ${allottedLots} lots`,
          providerId: this.id,
          raw: data,
        });
      } else if (outcome.includes('NOT') || outcome.includes('ZERO') || (data.is_allotment_out && allottedLots === 0)) {
        return new AllotmentResult({
          status: 'NOT_ALLOTTED',
          allottedLots: 0,
          allottedShares: 0,
          issuePriceRupees: data.issue_price || bidPriceRupees,
          confidence: 1.0,
          message: 'Not allotted (100% funds released/refunded)',
          providerId: this.id,
          raw: data,
        });
      }

      return new AllotmentResult({
        status: 'PENDING',
        confidence: 0.8,
        message: 'Allotment pending',
        providerId: this.id,
        raw: data,
      });
    } catch (err) {
      if (err.name === 'AbortError') {
        return new AllotmentResult({
          status: 'PENDING',
          confidence: 0.0,
          message: 'Provider timeout, retry scheduled',
          providerId: this.id,
        });
      }
      return new AllotmentResult({
        status: 'PENDING',
        confidence: 0.0,
        message: `Provider unavailable: ${err.message}`,
        providerId: this.id,
      });
    }
  }
}

module.exports = {
  FinApiAllotmentProvider,
};
