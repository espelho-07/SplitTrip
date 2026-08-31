/**
 * Base Abstract Interface for IPO Market Data Providers.
 * Allows seamless switching or multi-tier fallback between free providers
 * without modifying client application code.
 */
class IpoProvider {
  /**
   * Returns provider identifier (e.g. 'ipo_guru', 'ipo_alerts')
   */
  get id() {
    throw new Error('Not implemented');
  }

  /**
   * Fetches and normalizes IPOs into the canonical Kith schema.
   * @returns {Promise<Array<Object>|null>} Array of normalized IPOs or null on failure.
   */
  async fetchIpos() {
    throw new Error('Not implemented');
  }
}

module.exports = { IpoProvider };
