const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const BackupManager = require('../src/utils/backup_manager');

describe('Storage Backup & Disaster Recovery Tests', () => {
  const testStorageDir = path.join(__dirname, 'temp_storage_backup_test');
  const testBackupDir = path.join(__dirname, 'temp_backups_test');

  before(() => {
    fs.mkdirSync(testStorageDir, { recursive: true });
    fs.mkdirSync(testBackupDir, { recursive: true });

    // Seed mock data table
    fs.writeFileSync(
      path.join(testStorageDir, 'trips.json'),
      JSON.stringify([{ id: 'trip_1', name: 'Goa Escape', totalSpendInPaise: 120000 }]),
      'utf8'
    );
  });

  after(() => {
    if (fs.existsSync(testStorageDir)) {
      fs.rmSync(testStorageDir, { recursive: true, force: true });
    }
    if (fs.existsSync(testBackupDir)) {
      fs.rmSync(testBackupDir, { recursive: true, force: true });
    }
  });

  it('Creates an exact snapshot backup of data storage tables', () => {
    const backupPath = BackupManager.createBackup(testStorageDir, testBackupDir);
    assert.ok(fs.existsSync(backupPath), 'Backup directory should exist');
    assert.ok(fs.existsSync(path.join(backupPath, 'trips.json')), 'trips.json must exist in backup');

    const backedUpData = JSON.parse(fs.readFileSync(path.join(backupPath, 'trips.json'), 'utf8'));
    assert.strictEqual(backedUpData[0].name, 'Goa Escape');
  });

  it('Restores storage snapshot after data wipe with 100% integrity', () => {
    const backupPath = BackupManager.createBackup(testStorageDir, testBackupDir);

    // Simulate accidental data wipe
    fs.writeFileSync(path.join(testStorageDir, 'trips.json'), JSON.stringify([]), 'utf8');
    const wipedData = JSON.parse(fs.readFileSync(path.join(testStorageDir, 'trips.json'), 'utf8'));
    assert.strictEqual(wipedData.length, 0);

    // Perform disaster recovery restore
    BackupManager.restoreBackup(backupPath, testStorageDir);

    const restoredData = JSON.parse(fs.readFileSync(path.join(testStorageDir, 'trips.json'), 'utf8'));
    assert.strictEqual(restoredData.length, 1);
    assert.strictEqual(restoredData[0].id, 'trip_1');
    assert.strictEqual(restoredData[0].totalSpendInPaise, 120000);
  });
});
