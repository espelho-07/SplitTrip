const fs = require('fs');
const path = require('path');

/**
 * Manages backup and recovery of file-based data storage.
 */
class BackupManager {
  /**
   * Creates a timestamped backup of the data storage directory.
   * @param {string} sourceDir 
   * @param {string} backupBaseDir 
   * @returns {string} Path to created backup directory
   */
  static createBackup(sourceDir, backupBaseDir) {
    if (!fs.existsSync(sourceDir)) {
      throw new Error(`Source directory does not exist: ${sourceDir}`);
    }

    if (!fs.existsSync(backupBaseDir)) {
      fs.mkdirSync(backupBaseDir, { recursive: true });
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = path.join(backupBaseDir, `backup_${timestamp}`);
    fs.mkdirSync(backupDir, { recursive: true });

    const files = fs.readdirSync(sourceDir);
    for (const file of files) {
      if (file.endsWith('.json')) {
        const srcPath = path.join(sourceDir, file);
        const destPath = path.join(backupDir, file);
        fs.copyFileSync(srcPath, destPath);
      }
    }

    return backupDir;
  }

  /**
   * Restores data storage from a specific backup directory.
   * @param {string} backupDir 
   * @param {string} targetDir 
   */
  static restoreBackup(backupDir, targetDir) {
    if (!fs.existsSync(backupDir)) {
      throw new Error(`Backup directory does not exist: ${backupDir}`);
    }

    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }

    const files = fs.readdirSync(backupDir);
    for (const file of files) {
      if (file.endsWith('.json')) {
        const srcPath = path.join(backupDir, file);
        const destPath = path.join(targetDir, file);
        // Atomic write via tmp file
        const tmpPath = `${destPath}.tmp`;
        fs.copyFileSync(srcPath, tmpPath);
        fs.renameSync(tmpPath, destPath);
      }
    }
  }
}

module.exports = BackupManager;
