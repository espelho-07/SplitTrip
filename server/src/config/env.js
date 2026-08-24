const path = require('path');

module.exports = {
  PORT: process.env.PORT || 4000,
  HOST: process.env.HOST || '0.0.0.0',
  DATA_DIR: process.env.DATA_DIR || path.join(__dirname, '..', '..', 'data_storage'),
  NODE_ENV: process.env.NODE_ENV || 'development',
  TOKEN_SECRET: process.env.TOKEN_SECRET || 'kith_secure_dev_secret_2026_deterministic',
};
