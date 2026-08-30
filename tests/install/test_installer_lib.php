<?php
define('CALLCENTER_INSTALLER_NO_ENTRY', true);
require_once __DIR__.'/../../setup/installer.php';

class FakeFailingDB {
    public $errMsg = 'forced database failure';
    public function genQuery($sql) { return false; }
    public function getFirstRowQuery($sql, $assoc, $params) { return false; }
    public function fetchTable($sql, $assoc, $params = array()) { return false; }
}

class FakeMissingUrlColumnsDB {
    public $errMsg = '';
    public $lookups = array();
    public $queries = array();
    public function getFirstRowQuery($sql, $assoc, $params) {
        $this->lookups[] = $params;
        return array(0);
    }
    public function genQuery($sql) {
        $this->queries[] = $sql;
        return true;
    }
}

function expectInstallFailure($callable, $fragment) {
    try { $callable(); }
    catch (CallCenterInstallException $e) {
        if (strpos($e->getMessage(), $fragment) === false) {
            fwrite(STDERR, "FAIL installer_lib: missing error fragment: ".$fragment."\n");
            exit(2);
        }
        return;
    }
    fwrite(STDERR, "FAIL installer_lib: expected install failure: ".$fragment."\n");
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
$missingAgents = sys_get_temp_dir().DIRECTORY_SEPARATOR.'cc-missing-agents-'.getmypid().DIRECTORY_SEPARATOR.'agents.conf';
expectInstallFailure(function () use ($missingAgents) { convertirAgentsConf(11, $missingAgents); }, 'configuration file is missing');
if (cc_parse_asterisk_major('Asterisk 18.19.0 built by root') !== 18) exit(4);

$urlColumnsDB = new FakeMissingUrlColumnsDB();
ensureCampaignExternalUrlColumns($urlColumnsDB);
$expectedLookups = array(
    array('call_center', 'campaign', 'id_url2'),
    array('call_center', 'campaign', 'id_url3'),
    array('call_center', 'campaign_entry', 'id_url2'),
    array('call_center', 'campaign_entry', 'id_url3'),
);
$expectedQueries = array(
    'ALTER TABLE campaign ADD COLUMN id_url2 int unsigned, ADD FOREIGN KEY (id_url2) REFERENCES campaign_external_url (id)',
    'ALTER TABLE campaign ADD COLUMN id_url3 int unsigned, ADD FOREIGN KEY (id_url3) REFERENCES campaign_external_url (id)',
    'ALTER TABLE campaign_entry ADD COLUMN id_url2 int unsigned, ADD FOREIGN KEY (id_url2) REFERENCES campaign_external_url (id)',
    'ALTER TABLE campaign_entry ADD COLUMN id_url3 int unsigned, ADD FOREIGN KEY (id_url3) REFERENCES campaign_external_url (id)',
);
if ($urlColumnsDB->lookups !== $expectedLookups || $urlColumnsDB->queries !== $expectedQueries) {
    fwrite(STDERR, "FAIL installer_lib: campaign URL column repair is incomplete\n");
    exit(5);
}
echo "PASS installer_lib\n";
