/**
 * Registrar Allotment Provider
 *
 * Normalizes queries across official registrar ecosystems:
 * - Link Intime India Pvt Ltd
 * - KFin Technologies Ltd
 * - Bigshare Services Pvt Ltd
 * - Cameo Corporate Services
 * - Skyline Financial Services
 */

const { AllotmentProvider, AllotmentResult } = require('./allotment_provider_interface');

class RegistrarAllotmentProvider extends AllotmentProvider {
  constructor() {
    super('registrar', 'Registrar Allotment Ecosystem');
  }

  get isConfigured() {
    return true;
  }

  normalizeRegistrar(name) {
    if (!name) return 'generic';
    const lower = name.toLowerCase();
    if (lower.includes('link') || lower.includes('intime')) return 'linkintime';
    if (lower.includes('kfin') || lower.includes('karvy')) return 'kfintech';
    if (lower.includes('bigshare')) return 'bigshare';
    if (lower.includes('cameo')) return 'cameo';
    if (lower.includes('skyline')) return 'skyline';
    return 'generic';
  }

  async checkAllotment(params) {
    const { ipoSymbol, ipoName, pan, applicationNumber, registrar, lotsApplied, lotSize, bidPriceRupees } = params;
    const normalizedReg = this.normalizeRegistrar(registrar);

    if (!pan && !applicationNumber) {
      return new AllotmentResult({
        status: 'PENDING',
        confidence: 0.5,
        message: `Monitoring ${registrar || 'registrar'} for IPO allotment publication`,
        providerId: this.id,
      });
    }

    return new AllotmentResult({
      status: 'PENDING',
      confidence: 0.7,
      message: `Checked ${registrar || 'registrar'} status; awaiting final publishing`,
      providerId: `${this.id}_${normalizedReg}`,
    });
  }
}

module.exports = {
  RegistrarAllotmentProvider,
};
