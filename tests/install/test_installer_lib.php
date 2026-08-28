<?php
require_once __DIR__.'/../../setup/installer_lib.php';

class FakeFailingDB {
    public $errMsg = 'forced database failure';
    public function genQuery($sql) { return false; }
    public function getFirstRowQuery($sql, $assoc, $params) { return false; }
    public function fetchTable($sql, $assoc, $params = array()) { return false; }
}

function expectInstallFailure($callable, $fragment) {
    try { $callable(); }
    catch (CallCenterInstallException $e) {
        if (strpos($e->getMessage(), $fragment) === false) exit(2);
        return;
    }
    exit(3);
}

$db = new FakeFailingDB();
// These assertions catch swallowed database/file failures and permissive version parsing.
expectInstallFailure(function () use ($db) { cc_db_query($db, 'ALTER TABLE calls ADD x INT'); }, 'forced database failure');
expectInstallFailure(function () use ($db) { cc_db_first_row($db, 'SELECT 1', false, array()); }, 'database first-row query failed');
expectInstallFailure(function () use ($db) { cc_db_fetch_table($db, 'SELECT 1', true, array()); }, 'database table query failed');
expectInstallFailure(function () { cc_write_file(__DIR__.'/missing/path/file.conf', 'test'); }, 'file write failed');
expectInstallFailure(function () { cc_parse_asterisk_major(false); }, 'unavailable');
expectInstallFailure(function () { cc_parse_asterisk_major(''); }, 'unavailable');
expectInstallFailure(function () { cc_parse_asterisk_major('not a version'); }, 'cannot parse');
if (cc_parse_asterisk_major('Asterisk 18.19.0 built by root') !== 18) exit(4);
echo "PASS installer_lib\n";
