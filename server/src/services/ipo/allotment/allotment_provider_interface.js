/**
 * AllotmentProvider Interface
 *
 * Base abstraction for all IPO Allotment Providers.
 * Allows seamless integration of Registrars (Link Intime, KFintech, Bigshare),
 * Exchange Bid Verification (NSE/BSE), and Aggregator APIs (FinAPI) without
 * coupling the application logic to a single provider.
 */

class AllotmentResult {
  /**
   * @param {Object} params
   * @param {'ALLOTTED'|'NOT_ALLOTTED'|'PARTIALLY_ALLOTTED'|'PENDING'|'UNKNOWN'} params.status
   * @param {number} [params.allottedLots=0]
   * @param {number} [params.allottedShares=0]
   * @param {number} [params.issuePriceRupees]
   * @param {number} [params.confidence=1.0] - Between 0.0 and 1.0 (1.0 = definitive result)
   * @param {string} [params.message]
   * @param {string} [params.providerId]
   * @param {Object} [params.raw]
   */
  constructor({
    status,
    allottedLots = 0,
    allottedShares = 0,
    issuePriceRupees,
    confidence = 1.0,
    message = '',
    providerId = 'unknown',
    raw = null,
  }) {
    this.status = status;
    this.allottedLots = allottedLots;
    this.allottedShares = allottedShares;
    this.issuePriceRupees = issuePriceRupees;
    this.confidence = confidence;
    this.message = message;
    this.providerId = providerId;
    this.raw = raw;
    this.timestamp = new Date().toISOString();
  }

  get isDefinitive() {
    return (
      (this.status === 'ALLOTTED' ||
        this.status === 'NOT_ALLOTTED' ||
        this.status === 'PARTIALLY_ALLOTTED') &&
      this.confidence >= 0.9
    );
  }
}

class AllotmentProvider {
  /**
   * @param {string} id - Unique identifier for the provider
   * @param {string} name - Human readable provider name
   */
  constructor(id, name) {
    if (new.target === AllotmentProvider) {
      throw new TypeError('Cannot construct AllotmentProvider instances directly');
    }
    this.id = id;
    this.name = name;
  }

  get isConfigured() {
    return true;
  }

  /**
   * Checks allotment for an application.
   */
  async checkAllotment(params) {
    throw new Error('checkAllotment() must be implemented by subclass');
  }
}

module.exports = {
  AllotmentProvider,
  AllotmentResult,
};
