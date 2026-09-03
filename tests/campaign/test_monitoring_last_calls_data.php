<?php

// Defecto de producción: las consultas de últimas llamadas viven en un
// endpoint público separado en lugar de la autoridad de datos existente.
// Production defect: last-call queries live in a separate public endpoint
// instead of the existing data authority.

function failMonitoringLastCallsData($message)
{
    fwrite(STDERR, "FAIL monitoring_last_calls_data: $message\n");
    exit(1);
}

function assertMonitoringLastCallsDataSame($expected, $actual, $message)
{
    if ($expected !== $actual) {
        failMonitoringLastCallsData($message.' expected='.
            var_export($expected, TRUE).' actual='.var_export($actual, TRUE));
    }
}

class CC5014LastCallsDB
{
    public $errMsg = '';
    public $queries = array();
    public $nextResult = array();

    public function fetchTable($sql, $returnAssociative = FALSE, $params = NULL)
    {
        $this->queries[] = array(
            'sql' => $sql,
            'returnAssociative' => $returnAssociative,
            'params' => $params,
        );
        return $this->nextResult;
    }
}

function injectMonitoringLastCallsDB($console, $database)
{
    $property = new ReflectionProperty('PaloSantoConsola', '_oDB_call_center');
    $property->setAccessible(TRUE);
    $property->setValue($console, $database);
}

$repoRoot = dirname(dirname(__DIR__));
$fixtureRoot = sys_get_temp_dir().DIRECTORY_SEPARATOR.'cc5014-data-'.getmypid().'-'.uniqid();
if (!mkdir($fixtureRoot, 0700, TRUE)) {
    failMonitoringLastCallsData('unable to create fixture directory');
}
register_shutdown_function(function () use ($fixtureRoot) {
    $paths = array(
        $fixtureRoot.DIRECTORY_SEPARATOR.'libs'.DIRECTORY_SEPARATOR.'paloSantoDB.class.php',
        $fixtureRoot.DIRECTORY_SEPARATOR.'ECCP.class.php',
    );
    foreach ($paths as $path) {
        if (is_file($path)) unlink($path);
    }
    $libsPath = $fixtureRoot.DIRECTORY_SEPARATOR.'libs';
    if (is_dir($libsPath)) rmdir($libsPath);
    if (is_dir($fixtureRoot)) rmdir($fixtureRoot);
});
if (!mkdir($fixtureRoot.DIRECTORY_SEPARATOR.'libs', 0700, TRUE)) {
    failMonitoringLastCallsData('unable to create fixture library directory');
}
if (file_put_contents(
    $fixtureRoot.DIRECTORY_SEPARATOR.'libs'.DIRECTORY_SEPARATOR.'paloSantoDB.class.php',
    "<?php\n"
) === FALSE || file_put_contents(
    $fixtureRoot.DIRECTORY_SEPARATOR.'ECCP.class.php',
    "<?php\n"
) === FALSE) {
    failMonitoringLastCallsData('unable to create dependency fixtures');
}

$previousDirectory = getcwd();
chdir($fixtureRoot);
set_include_path($fixtureRoot.PATH_SEPARATOR.get_include_path());
require_once $repoRoot.'/modules/agent_console/libs/paloSantoConsola.class.php';
chdir($previousDirectory);

if (!method_exists('PaloSantoConsola', 'leerUltimasLlamadasAgentes')) {
    failMonitoringLastCallsData('PaloSantoConsola last-call data method is missing');
}

$incomingRows = array(
    array('agent' => 'Agent/9001', 'lastCall' => '2026-09-02 09:15:00', 'id_campaign' => '41'),
);
$database = new CC5014LastCallsDB();
$database->nextResult = $incomingRows;
$console = new PaloSantoConsola();
injectMonitoringLastCallsDB($console, $database);
$result = $console->leerUltimasLlamadasAgentes('incoming', 41);
assertMonitoringLastCallsDataSame($incomingRows, $result,
    'incoming last-call rows changed');
assertMonitoringLastCallsDataSame(1, count($database->queries),
    'incoming lookup did not issue exactly one query');
assertMonitoringLastCallsDataSame(TRUE, $database->queries[0]['returnAssociative'],
    'incoming lookup did not request associative rows');
assertMonitoringLastCallsDataSame(array(41), $database->queries[0]['params'],
    'incoming lookup did not bind the campaign ID');
if (strpos($database->queries[0]['sql'], 'FROM call_entry ce') === FALSE ||
    strpos($database->queries[0]['sql'], 'MAX(ce.datetime_end) AS lastCall') === FALSE) {
    failMonitoringLastCallsData('incoming lookup used the wrong data source');
}

$outgoingRows = array(
    array('agent' => 'SIP/7001', 'lastCall' => '2026-09-02 10:30:00', 'id_campaign' => '42'),
);
$database = new CC5014LastCallsDB();
$database->nextResult = $outgoingRows;
$console = new PaloSantoConsola();
injectMonitoringLastCallsDB($console, $database);
$result = $console->leerUltimasLlamadasAgentes('outgoing', 42);
assertMonitoringLastCallsDataSame($outgoingRows, $result,
    'outgoing last-call rows changed');
assertMonitoringLastCallsDataSame(1, count($database->queries),
    'outgoing lookup did not issue exactly one query');
assertMonitoringLastCallsDataSame(array(42), $database->queries[0]['params'],
    'outgoing lookup did not bind the campaign ID');
if (strpos($database->queries[0]['sql'], 'FROM calls c') === FALSE ||
    strpos($database->queries[0]['sql'], 'MAX(c.end_time) AS lastCall') === FALSE) {
    failMonitoringLastCallsData('outgoing lookup used the wrong data source');
}

$invalidInputs = array(
    array('incomingqueue', 41),
    array('incoming', 0),
    array('incoming', '41'),
    array('outgoing', -1),
);
foreach ($invalidInputs as $input) {
    $database = new CC5014LastCallsDB();
    $console = new PaloSantoConsola();
    injectMonitoringLastCallsDB($console, $database);
    $result = $console->leerUltimasLlamadasAgentes($input[0], $input[1]);
    assertMonitoringLastCallsDataSame(NULL, $result,
        'invalid service input was accepted');
    assertMonitoringLastCallsDataSame(array(), $database->queries,
        'invalid service input reached the database');
}

$database = new CC5014LastCallsDB();
$database->nextResult = FALSE;
$database->errMsg = 'fixture database failure';
$console = new PaloSantoConsola();
injectMonitoringLastCallsDB($console, $database);
$result = $console->leerUltimasLlamadasAgentes('incoming', 41);
assertMonitoringLastCallsDataSame(NULL, $result,
    'database failure did not fail closed');
if (strpos($console->errMsg, 'fixture database failure') === FALSE) {
    failMonitoringLastCallsData('database failure did not preserve diagnostic context');
}

echo "PASS monitoring_last_calls_data\n";
