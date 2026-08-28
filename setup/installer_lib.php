<?php

class CallCenterInstallException extends Exception
{
}

function cc_db_query($db, $sql)
{
    $result = $db->genQuery($sql);
    if ($result === false) {
        throw new CallCenterInstallException('database query failed: '.$db->errMsg);
    }
    return $result;
}

function cc_db_first_row($db, $sql, $assoc, $params)
{
    $result = $db->getFirstRowQuery($sql, $assoc, $params);
    if ($result === false) {
        throw new CallCenterInstallException('database first-row query failed: '.$db->errMsg);
    }
    return $result;
}

function cc_db_fetch_table($db, $sql, $assoc, $params = array())
{
    $result = $db->fetchTable($sql, $assoc, $params);
    if ($result === false) {
        throw new CallCenterInstallException('database table query failed: '.$db->errMsg);
    }
    return $result;
}

function cc_write_file($path, $contents)
{
    $result = @file_put_contents($path, $contents);
    if ($result === false) {
        throw new CallCenterInstallException('file write failed: '.$path);
    }
    return $result;
}

function cc_parse_asterisk_major($output)
{
    if ($output === false || $output === '') {
        throw new CallCenterInstallException('Asterisk version unavailable');
    }
    if (!preg_match('/Asterisk\s+(\d+)/', $output, $matches)) {
        throw new CallCenterInstallException('cannot parse Asterisk version');
    }
    return (int)$matches[1];
}
