<?php

// Production defect: loading the outgoing-campaign page can call a helper that
// reads database credentials and changes schema privileges during the request.

function failOutgoingPageContract($message)
{
    fwrite(STDERR, "FAIL outgoing_page_contract: $message\n");
    exit(1);
}

function cleanupOutgoingPageFixture()
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
$fixtureRoot = sys_get_temp_dir().DIRECTORY_SEPARATOR.'cc5012-'.getmypid().'-'.uniqid();
register_shutdown_function('cleanupOutgoingPageFixture');
$fixtureSources = array(
    'libs/paloSantoDB.class.php' => "<?php\n",
    'libs/paloSantoForm.class.php' => "<?php\n",
    'libs/paloSantoTrunk.class.php' => "<?php\n",
    'libs/misc.lib.php' => "<?php\n",
    'libs/paloSantoConfig.class.php' => "<?php\n",
    'libs/paloSantoGrid.class.php' => "<?php\n",
    'modules/agent_console/libs/issabel2.lib.php' => "<?php\n",
    'modules/campaign_out/configs/default.conf.php' =>
        "<?php\n\$arrConfModule = array('theme' => 'default', 'cadena_dsn' => 'test');\n",
);
foreach ($fixtureSources as $relativePath => $source) {
    $path = $fixtureRoot.DIRECTORY_SEPARATOR.str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
    $directory = dirname($path);
    if (!is_dir($directory) && !mkdir($directory, 0700, TRUE)) {
        failOutgoingPageContract("unable to create fixture directory $directory");
    }
    if (file_put_contents($path, $source) === FALSE) {
        failOutgoingPageContract("unable to create fixture file $path");
    }
}

set_include_path(
    $fixtureRoot.PATH_SEPARATOR.
    $repoRoot.'/modules/campaign_out'.PATH_SEPARATOR.
    $repoRoot.PATH_SEPARATOR.
    get_include_path()
);
require_once $repoRoot.'/modules/campaign_out/libs/paloSantoCampaignCC.class.php';

if (function_exists('checkDataBase') || function_exists('amportal_conf')) {
    failOutgoingPageContract('legacy page-load migration helpers remain exported');
}

class CC5012LazyMigrationInvoked extends Exception {}
class CC5012DatabaseBoundaryReached extends Exception {}

if (!function_exists('checkDataBase')) {
    function checkDataBase()
    {
        throw new CC5012LazyMigrationInvoked('legacy migration hook invoked');
    }
}

function get_language()
{
    return 'en';
}

function load_language_module($moduleName)
{
}

function _tr($message)
{
    return $message;
}

class paloDB
{
    var $errMsg = '';
    var $connStatus = TRUE;

    function __construct($dsn)
    {
    }

    function fetchTable($sql, $returnAssociative = FALSE, $params = array())
    {
        throw new CC5012DatabaseBoundaryReached('ordinary campaign query reached');
    }
}

class CC5012Smarty
{
    function assign($name, $value = NULL)
    {
    }
}

require_once $repoRoot.'/modules/campaign_out/index.php';

$_SERVER['SCRIPT_FILENAME'] = $repoRoot.'/index.php';
$_GET = array();
$_POST = array();
$_REQUEST = array();
$arrConf = array('theme' => 'default');
$smarty = new CC5012Smarty();

try {
    _moduleContent($smarty, 'campaign_out');
    failOutgoingPageContract('page bootstrap continued past the expected database boundary');
} catch (CC5012LazyMigrationInvoked $e) {
    failOutgoingPageContract('outgoing page invoked the legacy migration hook');
} catch (CC5012DatabaseBoundaryReached $e) {
    echo "PASS outgoing_page_contract\n";
}
