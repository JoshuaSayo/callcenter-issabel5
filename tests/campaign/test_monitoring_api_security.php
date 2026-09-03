<?php

// Defecto de producción: el endpoint directo acepta datos de cola sin autorización
// y los copia a un comando de shell en ambas ramas de campaña.
// Production defect: the direct endpoint accepts queue data without authorization
// and copies it into a shell command in both campaign branches.

function failMonitoringApiSecurity($message)
{
    fwrite(STDERR, "FAIL monitoring_api_security: $message\n");
    exit(1);
}

function cleanupMonitoringApiSecurityFixture()
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

function createMonitoringApiSecurityFixture($repoRoot, $fixtureRoot)
{
    $endpointSource = file_get_contents($repoRoot.'/modules/campaign_monitoring/libs/api.php');
    if ($endpointSource === FALSE) {
        failMonitoringApiSecurity('unable to read production endpoint');
    }
    $endpointSource = preg_replace(
        '/^<\?php/',
        "<?php\nnamespace CC5014EndpointFixture;",
        $endpointSource,
        1,
        $replacementCount
    );
    if ($replacementCount !== 1) {
        failMonitoringApiSecurity('unable to confine production endpoint in test namespace');
    }

    $fixtureFiles = array(
        'modules/campaign_monitoring/libs/api.php' => $endpointSource,
        'modules/campaign_monitoring/configs/default.conf.php' =>
            "<?php\n\$arrConfModule = array('cadena_dsn' => " .
            "'mysql://fixture_user:fixture_pass@fixture.invalid/call_center');\n",
        'boundary.php' => <<<'PHP'
<?php
namespace CC5014EndpointFixture;

class Boundary
{
    public static $databaseConnections = 0;
    public static $commands = array();

    public static function reset()
    {
        self::$databaseConnections = 0;
        self::$commands = array();
    }
}

class mysqli
{
    public $connect_error = FALSE;

    public function __construct($host, $user, $password, $database)
    {
        Boundary::$databaseConnections++;
    }

    public function prepare($sql)
    {
        return new Statement();
    }

    public function close()
    {
    }
}

class Statement
{
    public function bind_param($types, &$campaignId)
    {
    }

    public function execute()
    {
    }

    public function bind_result(&$agent, &$lastCall, &$campaignId)
    {
    }

    public function fetch()
    {
        return FALSE;
    }

    public function get_result()
    {
        return new Result();
    }

    public function close()
    {
    }
}

class Result
{
    public function fetch_assoc()
    {
        return NULL;
    }
}

function shell_exec($command)
{
    Boundary::$commands[] = $command;
    return '';
}
PHP
    );

    foreach ($fixtureFiles as $relativePath => $source) {
        $path = $fixtureRoot.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
        $directory = dirname($path);
        if (!is_dir($directory) && !mkdir($directory, 0700, TRUE)) {
            failMonitoringApiSecurity("unable to create fixture directory $directory");
        }
        if (file_put_contents($path, $source) === FALSE) {
            failMonitoringApiSecurity("unable to create fixture file $path");
        }
    }
}

function exerciseRetiredEndpoint($endpointPath, $parameters)
{
    \CC5014EndpointFixture\Boundary::reset();
    $arrConfModule = array(
        'cadena_dsn' => 'mysql://fixture_user:fixture_pass@fixture.invalid/call_center',
    );
    $_GET = $parameters;
    http_response_code(200);
    ob_start();
    include $endpointPath;
    $output = ob_get_clean();

    return array(
        'status' => http_response_code(),
        'output' => $output,
        'databaseConnections' => \CC5014EndpointFixture\Boundary::$databaseConnections,
        'commands' => \CC5014EndpointFixture\Boundary::$commands,
    );
}

$repoRoot = dirname(dirname(__DIR__));
$fixtureRoot = sys_get_temp_dir().DIRECTORY_SEPARATOR.'cc5014-api-'.getmypid().'-'.uniqid();
register_shutdown_function('cleanupMonitoringApiSecurityFixture');
createMonitoringApiSecurityFixture($repoRoot, $fixtureRoot);
require $fixtureRoot.'/boundary.php';

$endpointPath = $fixtureRoot.'/modules/campaign_monitoring/libs/api.php';
$scenarios = array(
    'incoming-valid' => array('id_campaignIncoming' => '41', 'queue' => '600'),
    'outgoing-valid' => array('id_campaignOutgoing' => '42', 'queue' => '601'),
    'incoming-unsafe' => array('id_campaignIncoming' => '43', 'queue' => "600'; id; #"),
);
$failures = array();
foreach ($scenarios as $label => $parameters) {
    $result = exerciseRetiredEndpoint($endpointPath, $parameters);
    if ($result['status'] !== 410 ||
        $result['databaseConnections'] !== 0 ||
        $result['commands'] !== array()) {
        $failures[] = $label.
            ' status='.$result['status'].
            ' databaseConnections='.$result['databaseConnections'].
            ' commands='.json_encode($result['commands']);
    }
    $decoded = json_decode($result['output'], TRUE);
    if (!is_array($decoded) || !isset($decoded['status']) || $decoded['status'] !== 'error') {
        $failures[] = $label.' did not return the retired-endpoint JSON error contract';
    }
}

if ($failures !== array()) {
    failMonitoringApiSecurity(implode("\n", $failures));
}

echo "PASS monitoring_api_security\n";
