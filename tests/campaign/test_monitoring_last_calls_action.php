<?php

// Defecto de producción: la consulta de últimas llamadas evita el despachador
// autenticado de Issabel y acepta una cola controlada por la solicitud.
// Production defect: the last-call lookup bypasses Issabel's authenticated
// dispatcher and accepts a request-controlled queue.

function failMonitoringLastCallsAction($message)
{
    fwrite(STDERR, "FAIL monitoring_last_calls_action: $message\n");
    exit(1);
}

function cleanupMonitoringLastCallsActionFixture()
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

function assertMonitoringLastCallsSame($expected, $actual, $message, &$failures)
{
    if ($expected !== $actual) {
        $failures[] = $message.' expected='.
            var_export($expected, TRUE).' actual='.var_export($actual, TRUE);
    }
}

function getParameter($name)
{
    return isset($_REQUEST[$name]) ? $_REQUEST[$name] : NULL;
}

function load_language_module($moduleName)
{
}

function _tr($message)
{
    return $message;
}

class Services_JSON
{
    public function encode($value)
    {
        return json_encode($value);
    }
}

class PaloSantoConsola
{
    public static $calls = array();
    public static $nextResult = array();
    public static $nextError = '';
    public $errMsg = '';

    public function __construct()
    {
        $this->errMsg = self::$nextError;
    }

    public function leerUltimasLlamadasAgentes($campaignType, $campaignId)
    {
        self::$calls[] = array($campaignType, $campaignId);
        return self::$nextResult;
    }
}

class CC5014Smarty
{
    public function get_template_vars($name)
    {
        return '';
    }

    public function assign($name, $value = NULL)
    {
    }

    public function fetch($path)
    {
        return 'HTML';
    }
}

function runLastCallsHandler($parameters, $session)
{
    $_GET = $parameters;
    $_POST = array();
    $_REQUEST = $parameters;
    $_SESSION = $session;
    PaloSantoConsola::$calls = array();

    return manejarMonitoreo_getAgentLastCalls(
        'campaign_monitoring',
        new CC5014Smarty(),
        ''
    );
}

$repoRoot = dirname(dirname(__DIR__));
$fixtureRoot = sys_get_temp_dir().DIRECTORY_SEPARATOR.'cc5014-action-'.getmypid().'-'.uniqid();
register_shutdown_function('cleanupMonitoringLastCallsActionFixture');
$fixtureFiles = array(
    'modules/agent_console/libs/issabel2.lib.php' => "<?php\n",
    'modules/agent_console/libs/JSON.php' => "<?php\n",
    'modules/agent_console/libs/paloSantoConsola.class.php' => "<?php\n",
    'modules/campaign_monitoring/configs/default.conf.php' =>
        "<?php\n\$arrConfModule = array('theme' => 'default', " .
        "'cadena_dsn' => 'mysql://fixture.invalid/call_center');\n",
);
foreach ($fixtureFiles as $relativePath => $source) {
    $path = $fixtureRoot.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0700, TRUE)) {
        failMonitoringLastCallsAction("unable to create fixture directory $directory");
    }
    if (file_put_contents($path, $source) === FALSE) {
        failMonitoringLastCallsAction("unable to create fixture file $path");
    }
}

$previousDirectory = getcwd();
chdir($fixtureRoot);
set_include_path($fixtureRoot.PATH_SEPARATOR.get_include_path());
require_once $repoRoot.'/modules/campaign_monitoring/index.php';

$failures = array();
$expectedRows = array(
    array('agent' => 'Agent/9001', 'lastCall' => '2026-09-02 09:15:00', 'id_campaign' => 41),
);
PaloSantoConsola::$nextResult = $expectedRows;
PaloSantoConsola::$nextError = '';
PaloSantoConsola::$calls = array();
$_GET = array(
    'action' => 'getAgentLastCalls',
    'campaigntype' => 'incoming',
    'campaignid' => '41',
);
$_POST = array();
$_REQUEST = $_GET;
$_SESSION = array('issabel_user' => 'admin');
$_SERVER['SCRIPT_FILENAME'] = $repoRoot.'/index.php';
$arrConf = array('theme' => 'default');
$arrConfig = array('templates_dir' => 'themes');
$arrLang = array();
$smarty = new CC5014Smarty();
$routeOutput = _moduleContent($smarty, 'campaign_monitoring');
$routeResponse = json_decode($routeOutput, TRUE);
assertMonitoringLastCallsSame('success', isset($routeResponse['status']) ? $routeResponse['status'] : NULL,
    'authenticated front-controller action did not return success', $failures);
assertMonitoringLastCallsSame($expectedRows,
    isset($routeResponse['listaLastCall']) ? $routeResponse['listaLastCall'] : NULL,
    'authenticated front-controller action changed the last-call response', $failures);
assertMonitoringLastCallsSame(array(array('incoming', 41)), PaloSantoConsola::$calls,
    'incoming action did not reach the service once with a canonical campaign ID', $failures);

if (!function_exists('manejarMonitoreo_getAgentLastCalls')) {
    $failures[] = 'authenticated last-call handler is missing';
} else {
    PaloSantoConsola::$nextResult = $expectedRows;

    $response = json_decode(runLastCallsHandler(
        array('campaigntype' => 'incoming', 'campaignid' => '41'),
        array()
    ), TRUE);
    assertMonitoringLastCallsSame('ERROR_SESSION',
        isset($response['statusResponse']) ? $response['statusResponse'] : NULL,
        'missing session was not rejected with the established session contract', $failures);
    assertMonitoringLastCallsSame(array(), PaloSantoConsola::$calls,
        'missing session reached the service boundary', $failures);

    $invalidRequests = array(
        'invalid-type' => array('campaigntype' => 'incomingqueue', 'campaignid' => '41'),
        'empty-id' => array('campaigntype' => 'incoming', 'campaignid' => ''),
        'zero-id' => array('campaigntype' => 'incoming', 'campaignid' => '0'),
        'leading-zero-id' => array('campaigntype' => 'incoming', 'campaignid' => '041'),
        'partial-id' => array('campaigntype' => 'incoming', 'campaignid' => '41x'),
        'overflow-id' => array('campaigntype' => 'incoming', 'campaignid' => str_repeat('9', 40)),
        'array-id' => array('campaigntype' => 'incoming', 'campaignid' => array('41')),
        'legacy-valid-queue' => array(
            'campaigntype' => 'incoming', 'campaignid' => '41', 'queue' => '600',
        ),
        'legacy-unsafe-queue' => array(
            'campaigntype' => 'incoming', 'campaignid' => '41', 'queue' => "600'; id; #",
        ),
    );
    foreach ($invalidRequests as $label => $parameters) {
        $response = json_decode(runLastCallsHandler(
            $parameters,
            array('issabel_user' => 'admin')
        ), TRUE);
        assertMonitoringLastCallsSame('error', isset($response['status']) ? $response['status'] : NULL,
            "$label was not rejected", $failures);
        assertMonitoringLastCallsSame(array(), PaloSantoConsola::$calls,
            "$label reached the service boundary", $failures);
    }

    $outgoingRows = array(
        array('agent' => 'SIP/7001', 'lastCall' => '2026-09-02 10:30:00', 'id_campaign' => 42),
    );
    PaloSantoConsola::$nextResult = $outgoingRows;
    $response = json_decode(runLastCallsHandler(
        array('campaigntype' => 'outgoing', 'campaignid' => '42'),
        array('issabel_user' => 'admin')
    ), TRUE);
    assertMonitoringLastCallsSame($outgoingRows,
        isset($response['listaLastCall']) ? $response['listaLastCall'] : NULL,
        'valid outgoing action changed the last-call response', $failures);
    assertMonitoringLastCallsSame(array(array('outgoing', 42)), PaloSantoConsola::$calls,
        'outgoing action did not reach the service once with a canonical campaign ID', $failures);
}

chdir($previousDirectory);
if ($failures !== array()) {
    failMonitoringLastCallsAction(implode("\n", $failures));
}

echo "PASS monitoring_last_calls_action\n";
