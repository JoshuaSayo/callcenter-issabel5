<?php

function _tr($text)
{
    return $text;
}

$repoRoot = dirname(dirname(__DIR__));
set_include_path($repoRoot.'/modules/agent_console'.PATH_SEPARATOR.get_include_path());
require_once $repoRoot.'/modules/campaign_in/libs/paloSantoIncomingCampaign.class.php';

class FakeIncomingCampaignDB
{
    var $errMsg = '';
    var $firstRows;
    var $firstQueries = array();
    var $generatedQueries = array();
    var $currentRow;

    function __construct($firstRows)
    {
        $this->firstRows = $firstRows;
    }

    function &getFirstRowQuery($sql, $assoc = FALSE, $params = NULL)
    {
        $this->firstQueries[] = array('sql' => $sql, 'params' => $params);
        $this->currentRow = array_shift($this->firstRows);
        return $this->currentRow;
    }

    function genQuery($sql, $params = NULL)
    {
        $this->generatedQueries[] = array('sql' => $sql, 'params' => $params);
        return TRUE;
    }
}

function failIncomingCampaignTest($message)
{
    fwrite(STDERR, "FAIL incoming_campaign: $message\n");
    exit(1);
}

function assertIncomingCampaignSame($expected, $actual, $message)
{
    if ($expected !== $actual) {
        failIncomingCampaignTest($message.' expected='.var_export($expected, TRUE).' actual='.var_export($actual, TRUE));
    }
}

function assertCreateRejectsExternalUrl($url2, $url3, $label)
{
    $db = new FakeIncomingCampaignDB(array());
    $campaign = new paloSantoIncomingCampaign($db);
    $createdId = $campaign->createEmptyCampaign(
        'Invalid URL campaign', '600', '2026-08-31', '2026-09-01',
        '08:00', '17:00', 'Agent script', NULL, 11, $url2, $url3
    );
    assertIncomingCampaignSame(NULL, $createdId, "$label was accepted during create");
    assertIncomingCampaignSame('URL ID is not numeric', $campaign->errMsg, "$label reported the wrong create error");
    assertIncomingCampaignSame(array(), $db->firstQueries, "$label reached a database read during create");
    assertIncomingCampaignSame(array(), $db->generatedQueries, "$label reached a database write during create");
}

function assertUpdateRejectsExternalUrl($url2, $url3, $label)
{
    $db = new FakeIncomingCampaignDB(array());
    $campaign = new paloSantoIncomingCampaign($db);
    $updated = $campaign->updateCampaign(
        9, 'Invalid URL campaign', '600', '2026-08-31', '2026-09-01',
        '08:00', '17:00', 'Agent script', NULL, 11, $url2, $url3
    );
    assertIncomingCampaignSame(FALSE, $updated, "$label was accepted during update");
    assertIncomingCampaignSame('URL ID is not numeric', $campaign->errMsg, "$label reported the wrong update error");
    assertIncomingCampaignSame(array(), $db->firstQueries, "$label reached a database read during update");
    assertIncomingCampaignSame(array(), $db->generatedQueries, "$label reached a database write during update");
}

// Creation must bind all three external URL IDs supplied by the public form path.
$createDB = new FakeIncomingCampaignDB(array(array(0), array(17), array(42)));
$campaign = new paloSantoIncomingCampaign($createDB);
$createdId = $campaign->createEmptyCampaign(
    'Incoming URL campaign', '600', '2026-08-31', '2026-09-01',
    '08:00', '17:00', 'Agent script', NULL, 11, 12, 13
);
assertIncomingCampaignSame(42, $createdId, 'valid campaign was not created');
assertIncomingCampaignSame(
    array('Incoming URL campaign', 17, NULL, '2026-08-31', '2026-09-01',
        '08:00', '17:00', 'Agent script', 11, 12, 13),
    $createDB->generatedQueries[0]['params'],
    'create did not preserve all external URL IDs'
);

// Invalid secondary URL IDs must fail before any database operation.
assertCreateRejectsExternalUrl('invalid', 13, 'invalid URL2');
assertCreateRejectsExternalUrl(12, 'invalid', 'invalid URL3');
assertCreateRejectsExternalUrl('12junk', 13, 'partially numeric URL2');
assertUpdateRejectsExternalUrl('invalid', 13, 'invalid URL2');
assertUpdateRejectsExternalUrl(12, 'invalid', 'invalid URL3');
assertUpdateRejectsExternalUrl(12, '13junk', 'partially numeric URL3');

// A successful update must preserve all URL IDs without writing debug SQL to the response.
$updateDB = new FakeIncomingCampaignDB(array(array(0), array(17)));
$campaign = new paloSantoIncomingCampaign($updateDB);
ob_start();
$updated = $campaign->updateCampaign(
    9, 'Updated URL campaign', '600', '2026-08-31', '2026-09-01',
    '08:00', '17:00', 'Updated script', NULL, 21, 22, 23
);
$responseOutput = ob_get_clean();
assertIncomingCampaignSame(TRUE, $updated, 'valid campaign was not updated');
assertIncomingCampaignSame('', $responseOutput, 'update leaked debug SQL into the response');
assertIncomingCampaignSame(
    array('Updated URL campaign', 17, NULL, '2026-08-31', '2026-09-01',
        '08:00', '17:00', 'Updated script', 21, 22, 23, 9),
    $updateDB->generatedQueries[0]['params'],
    'update did not preserve all external URL IDs'
);

echo "PASS incoming_campaign\n";
