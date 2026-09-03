<?php

// Defecto de producción: el estado estructurado UNAVAILABLE de AMI se pierde
// antes de llegar al monitor y se vuelve a consultar mediante un shell.
// Production defect: AMI's structured UNAVAILABLE status is lost before it
// reaches the monitor and is queried again through a shell.

function failMonitoringUnavailableStatus($message)
{
    fwrite(STDERR, "FAIL monitoring_unavailable_status: $message\n");
    exit(1);
}

function assertMonitoringUnavailableSame($expected, $actual, $message)
{
    if ($expected !== $actual) {
        failMonitoringUnavailableStatus($message.' expected='.
            var_export($expected, TRUE).' actual='.var_export($actual, TRUE));
    }
}

function _tr($message)
{
    return $message;
}

function load_language_module($moduleName)
{
}

function getParameter($name)
{
    return NULL;
}

function cleanupMonitoringUnavailableFixture()
{
    global $fixtureRoot;

    if (!is_dir($fixtureRoot)) return;
    $items = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($fixtureRoot, FilesystemIterator::SKIP_DOTS),
        RecursiveIteratorIterator::CHILD_FIRST
    );
    foreach ($items as $item) {
        if ($item->isDir()) {
            rmdir($item->getPathname());
        } else {
            unlink($item->getPathname());
        }
    }
    rmdir($fixtureRoot);
}

function createAgentInfo($queueStatus)
{
    $info = array(
        'login_channel' => 'SIP/7001',
        'extension' => NULL,
        'oncall' => FALSE,
        'num_pausas' => 0,
        'estado_consola' => 'logged-in',
        'waitedcallinfo' => NULL,
        'id_hold' => NULL,
        'id_break' => NULL,
    );
    if (!is_null($queueStatus)) {
        $info['queue_status'] = $queueStatus;
    }
    return $info;
}

function formatQueueMember($queueStatus)
{
    $xml = new SimpleXMLElement('<agent />');
    $xml->addChild('agentchannel', 'Agent/9001');
    ECCPConn::getcampaignstatus_setagent($xml, createAgentInfo($queueStatus));
    return $xml;
}

$repoRoot = dirname(dirname(__DIR__));
$fixtureRoot = sys_get_temp_dir().DIRECTORY_SEPARATOR.'cc5014-status-'.getmypid().'-'.uniqid();
register_shutdown_function('cleanupMonitoringUnavailableFixture');
$fixtureFiles = array(
    'ECCPHelper.lib.php' => "<?php\n",
    'ECCP.class.php' => "<?php\n",
    'libs/paloSantoDB.class.php' => "<?php\n",
    'modules/agent_console/libs/issabel2.lib.php' => "<?php\n",
    'modules/agent_console/libs/JSON.php' => "<?php\n",
    'modules/agent_console/libs/paloSantoConsola.class.php' => "<?php\n",
);
foreach ($fixtureFiles as $relativePath => $source) {
    $path = $fixtureRoot.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0700, TRUE)) {
        failMonitoringUnavailableStatus("unable to create fixture directory $directory");
    }
    if (file_put_contents($path, $source) === FALSE) {
        failMonitoringUnavailableStatus("unable to create fixture file $path");
    }
}

$previousDirectory = getcwd();
chdir($fixtureRoot);
set_include_path($fixtureRoot.PATH_SEPARATOR.get_include_path());
require_once $repoRoot.'/setup/dialer_process/dialer/ECCPConn.class.php';
require_once $repoRoot.'/modules/agent_console/libs/paloSantoConsola.class.php';
require_once $repoRoot.'/modules/campaign_monitoring/index.php';
chdir($previousDirectory);

$unavailableXml = formatQueueMember(5);
assertMonitoringUnavailableSame('online', (string)$unavailableXml->status,
    'AMI unavailable state changed the established ECCP agent status token');
assertMonitoringUnavailableSame('5', isset($unavailableXml->queue_status) ?
    (string)$unavailableXml->queue_status : NULL,
    'AMI unavailable state was not exposed as structured queue status');

$ringingXml = formatQueueMember(6);
assertMonitoringUnavailableSame('ringing', (string)$ringingXml->status,
    'AMI ringing state changed');
assertMonitoringUnavailableSame('6', isset($ringingXml->queue_status) ?
    (string)$ringingXml->queue_status : NULL,
    'AMI ringing state was not exposed as structured queue status');

$withoutQueueStatus = formatQueueMember(NULL);
assertMonitoringUnavailableSame(FALSE, isset($withoutQueueStatus->queue_status),
    'missing AMI queue status was invented');

$translator = new ReflectionMethod('PaloSantoConsola', '_traducirEstadoAgente');
$translator->setAccessible(TRUE);
$console = new PaloSantoConsola();
$translated = $translator->invoke($console, $unavailableXml);
assertMonitoringUnavailableSame(5,
    isset($translated['queue_status']) ? $translated['queue_status'] : NULL,
    'structured queue status was dropped by PaloSantoConsola');

$translated['callinfo'] = array('callnumber' => NULL, 'trunk' => NULL);
$formatted = formatoAgente($translated);
assertMonitoringUnavailableSame('Phone Off', $formatted['status'],
    'campaign monitor did not preserve the existing Phone Off label');

$translated['status'] = 'offline';
$formatted = formatoAgente($translated);
assertMonitoringUnavailableSame('offline', $formatted['status'],
    'stale queue status overrode the authoritative agent state');

echo "PASS monitoring_unavailable_status\n";
