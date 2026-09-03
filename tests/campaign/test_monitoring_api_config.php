<?php

// Contrato de regresión: la ruta autenticada de monitoreo usa el DSN del
// módulo como única autoridad de configuración para call_center.
// Regression contract: authenticated monitoring uses the module DSN as the
// sole call_center configuration authority.

function failMonitoringApiConfig($message)
{
    fwrite(STDERR, "FAIL monitoring_api_config: $message\n");
    exit(1);
}

function cleanupMonitoringApiConfigFixture()
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

$repoRoot = dirname(dirname(__DIR__));
$fixtureRoot = sys_get_temp_dir().DIRECTORY_SEPARATOR.'cc5013-'.getmypid().'-'.uniqid();
register_shutdown_function('cleanupMonitoringApiConfigFixture');

$fixtureFiles = array(
    'modules/campaign_monitoring/configs/default.conf.php' =>
        "<?php\n\$arrConfModule = array('cadena_dsn' => ".
        "'mysql://cc_fixture_user:cc_fixture_pass@db.fixture.invalid/fixture_call_center');\n",
    'libs/paloSantoDB.class.php' => <<<'DATABASE_FIXTURE'
<?php
class paloDB
{
    public static $constructorArguments = array();
    public static $queries = array();
    public $connStatus = FALSE;
    public $errMsg = '';

    public function __construct($dsn)
    {
        self::$constructorArguments[] = $dsn;
    }

    public function fetchTable($sql, $returnAssociative = FALSE, $params = NULL)
    {
        self::$queries[] = array($sql, $returnAssociative, $params);
        return array();
    }
}
DATABASE_FIXTURE
    ,
    'ECCP.class.php' => "<?php\n",
);

foreach ($fixtureFiles as $relativePath => $source) {
    $path = $fixtureRoot.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0700, TRUE)) {
        failMonitoringApiConfig("unable to create fixture directory $directory");
    }
    if (file_put_contents($path, $source) === FALSE) {
        failMonitoringApiConfig("unable to create fixture file $path");
    }
}

$arrConf = array();
$arrConfModule = array();
require $fixtureRoot.'/modules/campaign_monitoring/configs/default.conf.php';
$arrConf = array_merge($arrConf, $arrConfModule);

$warnings = array();
set_error_handler(function ($severity, $message) use (&$warnings) {
    $warnings[] = $message;
    return TRUE;
});

$previousDirectory = getcwd();
chdir($fixtureRoot);
set_include_path($fixtureRoot.PATH_SEPARATOR.get_include_path());
require_once $repoRoot.'/modules/agent_console/libs/paloSantoConsola.class.php';
chdir($previousDirectory);

$console = new PaloSantoConsola();
$result = $console->leerUltimasLlamadasAgentes('incoming', 41);
restore_error_handler();

$expectedDSN = 'mysql://cc_fixture_user:cc_fixture_pass@db.fixture.invalid/fixture_call_center';
if (paloDB::$constructorArguments !== array($expectedDSN)) {
    failMonitoringApiConfig(
        'authenticated data service did not use the module DSN expected='.
        var_export(array($expectedDSN), TRUE).' actual='.
        var_export(paloDB::$constructorArguments, TRUE)
    );
}
if ($result !== array() || count(paloDB::$queries) !== 1) {
    failMonitoringApiConfig('module DSN connection did not execute the last-call query');
}
if ($warnings !== array()) {
    failMonitoringApiConfig('canonical module DSN path emitted a warning: '.implode('; ', $warnings));
}

echo "PASS monitoring_api_config\n";
