<?php

// Production defect: loading the incoming-campaign page can call a helper that
// reads database credentials and changes schema privileges during the request.

function failIncomingPageContract($message)
{
    fwrite(STDERR, "FAIL incoming_page_contract: $message\n");
    exit(1);
}

function cleanupIncomingPageFixture()
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
$fixtureRoot = sys_get_temp_dir().DIRECTORY_SEPARATOR.'cc5011-'.getmypid().'-'.uniqid();
register_shutdown_function('cleanupIncomingPageFixture');
$fixtureSources = array(
    'libs/paloSantoDB.class.php' => "<?php\n",
    'libs/paloSantoForm.class.php' => "<?php\n",
    'libs/paloSantoGrid.class.php' => "<?php\n",
    'libs/paloSantoConfig.class.php' => "<?php\n",
    'modules/agent_console/libs/issabel2.lib.php' => "<?php\n",
    'modules/campaign_in/configs/default.conf.php' =>
        "<?php\n\$arrConfModule = array('theme' => 'default', 'cadena_dsn' => 'test');\n",
);
foreach ($fixtureSources as $relativePath => $source) {
    $path = $fixtureRoot.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0700, TRUE)) {
        failIncomingPageContract("unable to create fixture directory $directory");
    }
    if (file_put_contents($path, $source) === FALSE) {
        failIncomingPageContract("unable to create fixture file $path");
    }
}

set_include_path(
    $fixtureRoot.PATH_SEPARATOR.
    $repoRoot.'/modules/campaign_in'.PATH_SEPARATOR.
    $repoRoot.PATH_SEPARATOR.
    get_include_path()
);
require_once $repoRoot.'/modules/campaign_in/libs/paloSantoIncomingCampaign.class.php';

if (function_exists('checkDataBase') || function_exists('amportal_conf')) {
    failIncomingPageContract('legacy page-load migration helpers remain exported');
}

class CC5011LazyMigrationInvoked extends Exception {}
class CC5011DatabaseBoundaryReached extends Exception {}

if (!function_exists('checkDataBase')) {
    function checkDataBase()
    {
        throw new CC5011LazyMigrationInvoked('legacy migration hook invoked');
    }
}

function load_language_module($moduleName)
{
}

class paloDB
{
    function __construct($dsn)
    {
        throw new CC5011DatabaseBoundaryReached('normal database construction reached');
    }
}

class CC5011Smarty
{
    function assign($name, $value)
    {
    }
}

require_once $repoRoot.'/modules/campaign_in/index.php';

$_SERVER['SCRIPT_FILENAME'] = $repoRoot.'/index.php';
$arrConf = array('theme' => 'default');
$smarty = new CC5011Smarty();

try {
    _moduleContent($smarty, 'campaign_in');
    failIncomingPageContract('page bootstrap continued past the expected database boundary');
} catch (CC5011LazyMigrationInvoked $e) {
    failIncomingPageContract('incoming page invoked the legacy migration hook');
} catch (CC5011DatabaseBoundaryReached $e) {
    echo "PASS incoming_page_contract\n";
}
