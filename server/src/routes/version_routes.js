const express = require('express');
const versionService = require('../services/version_service');

const router = express.Router();

/**
 * GET /api/app/version or GET /api/version
 * Checks application version compatibility and returns update recommendations.
 */
router.get(['/', '/check'], (req, res) => {
  const clientVersion = req.query.clientVersion || 
                        req.query.version || 
                        req.headers['x-client-version'] || 
                        req.headers['client-version'];

  const status = versionService.checkVersion(clientVersion);
  res.status(200).json({
    data: status,
  });
});

/**
 * POST /api/app/version (Admin dynamic update)
 */
router.post(['/', '/config'], (req, res) => {
  const { latestVersion, minimumSupportedVersion, releaseNotes, storeUrl, updatePriority, featureFlags } = req.body;

  const updated = versionService.updateConfig({
    latestVersion,
    minimumSupportedVersion,
    releaseNotes,
    storeUrl,
    updatePriority,
    featureFlags,
  });

  res.status(200).json({
    message: 'Version configuration updated successfully',
    data: updated,
  });
});

module.exports = router;
