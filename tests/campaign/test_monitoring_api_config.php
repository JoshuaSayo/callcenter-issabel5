<?php

// Defecto de producción: la API de monitoreo solicitada directamente ignora
// el DSN de base de datos del módulo y depende de su propio analizador de
// /etc/amportal.conf, creando una segunda autoridad de configuración.
// Production defect: the directly requested monitoring API ignores the
// module database DSN and depends on its own /etc/amportal.conf parser,
// creating a second configuration authority.

function failMonitoringApiConfig($message)
{
    fwrite(STDERR, "FAIL monitoring_api_config: $message\n");
    exit(1);
}

function cleanupMonitoringApiFixture()
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
register_shutdown_function('cleanupMonitoringApiFixture');

$fixtureFiles = array(
    'modules/campaign_monitoring/libs/api.php' =>
        file_get_contents($repoRoot.'/modules/campaign_monitoring/libs/api.php'),
    'modules/campaign_monitoring/configs/default.conf.php' =>
        "<?php\n\$arrConfModule = array('cadena_dsn' => " .
        "'mysql://cc_fixture_user:cc_fixture_pass@db.fixture.invalid/fixture_call_center');\n",
);
foreach ($fixtureFiles as $relativePath => $source) {
    if ($source === FALSE) {
        failMonitoringApiConfig("unable to read fixture source $relativePath");
    }
    $path = $fixtureRoot.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0700, TRUE)) {
        failMonitoringApiConfig("unable to create fixture directory $directory");
    }
    if (file_put_contents($path, $source) === FALSE) {
        failMonitoringApiConfig("unable to create fixture file $path");
    }
}

if (!class_exists('mysqli', FALSE)) {
    class mysqli
    {
        public static $constructorArguments = array();
        public $connect_error = FALSE;

        public function __construct($host, $user, $password, $database)
        {
            self::$constructorArguments[] = array($host, $user, $password, $database);
        }
    }
} else {
    failMonitoringApiConfig('mysqli is loaded; run this boundary test with php -n');
}

$warnings = array();
set_error_handler(function ($severity, $message) use (&$warnings) {
    $warnings[] = $message;
    return TRUE;
});

$_GET = array();
$previousOpenBasedir = ini_set('open_basedir', $fixtureRoot);
if ($previousOpenBasedir === FALSE) {
    failMonitoringApiConfig('unable to confine the endpoint fixture');
}
if (!is_readable($fixtureRoot.'/modules/campaign_monitoring/configs/default.conf.php')) {
    failMonitoringApiConfig('module DSN fixture is unreadable after confinement');
}
ob_start();
require $fixtureRoot.'/modules/campaign_monitoring/libs/api.php';
$responseOutput = ob_get_clean();
restore_error_handler();

$expectedArguments = array(
    'db.fixture.invalid',
    'cc_fixture_user',
    'cc_fixture_pass',
    'fixture_call_center',
);
if (mysqli::$constructorArguments !== array($expectedArguments)) {
    failMonitoringApiConfig(
        'API did not initialize mysqli from the module DSN expected='.
        var_export(array($expectedArguments), TRUE).' actual='.
        var_export(mysqli::$constructorArguments, TRUE)
    );
}
if ($responseOutput !== '') {
    failMonitoringApiConfig('empty monitoring bootstrap emitted response output');
}
if ($warnings !== array()) {
    failMonitoringApiConfig('canonical module DSN bootstrap emitted a warning');
}

echo "PASS monitoring_api_config\n";
