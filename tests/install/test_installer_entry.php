<?php

function failInstallerEntryTest($message)
{
    fwrite(STDERR, "FAIL installer_entry: ".$message."\n");
    exit(1);
}

function removeInstallerEntryFixture($path)
{
    if (!is_dir($path)) {
        return;
    }
    foreach (scandir($path) as $entry) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }
        $item = $path.DIRECTORY_SEPARATOR.$entry;
        if (is_dir($item)) {
            removeInstallerEntryFixture($item);
        } else {
            unlink($item);
        }
    }
    rmdir($path);
}

$fixture = sys_get_temp_dir().DIRECTORY_SEPARATOR.'cc-installer-entry-'.getmypid();
$documentRoot = $fixture.DIRECTORY_SEPARATOR.'www';
$libs = $documentRoot.DIRECTORY_SEPARATOR.'libs';
if (!mkdir($libs, 0700, true)) {
    failInstallerEntryTest('cannot create fixture');
}
register_shutdown_function(function () use ($fixture) {
    removeInstallerEntryFixture($fixture);
});

$installerStub = <<<'PHP'
<?php
class Installer {
    public function createNewDatabaseMySQL($path, $name, $connection)
    {
        return 23;
    }
}
PHP;
$databaseStub = <<<'PHP'
<?php
class paloDB {
}
PHP;
if (file_put_contents($libs.DIRECTORY_SEPARATOR.'paloSantoInstaller.class.php', $installerStub) === false ||
    file_put_contents($libs.DIRECTORY_SEPARATOR.'paloSantoDB.class.php', $databaseStub) === false) {
    failInstallerEntryTest('cannot write dependency stubs');
}

$installerPath = realpath(__DIR__.'/../../setup/installer.php');
if ($installerPath === false) {
    failInstallerEntryTest('cannot locate production installer');
}
$harness = $fixture.DIRECTORY_SEPARATOR.'run-installer.php';
$harnessSource = "<?php\n".
    "define('CALLCENTER_DOCUMENT_ROOT', ".var_export($documentRoot, true).");\n".
    "require ".var_export($installerPath, true).";\n";
if (file_put_contents($harness, $harnessSource) === false) {
    failInstallerEntryTest('cannot write entry harness');
}

$command = array(PHP_BINARY, $harness);
$descriptors = array(
    1 => array('pipe', 'w'),
    2 => array('pipe', 'w'),
);
$process = proc_open($command, $descriptors, $pipes, $fixture);
if (!is_resource($process)) {
    failInstallerEntryTest('cannot execute production installer');
}
$stdout = stream_get_contents($pipes[1]);
$stderr = stream_get_contents($pipes[2]);
fclose($pipes[1]);
fclose($pipes[2]);
$status = proc_close($process);

// This catches an entry wrapper that misses or swallows database-create failure.
if ($status !== 1) {
    failInstallerEntryTest('expected exit 1, got '.$status.'; stdout='.$stdout.'; stderr='.$stderr);
}
if (strpos($stderr, 'ERROR: Call Center installer failed: database creation failed with status 23') === false) {
    failInstallerEntryTest('missing database-create failure; stderr='.$stderr);
}
if (strpos($stderr, 'Granted permissions') !== false || $stdout !== '') {
    failInstallerEntryTest('installer continued after database-create failure');
}

echo "PASS installer_entry\n";
