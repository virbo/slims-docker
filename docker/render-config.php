<?php
declare(strict_types=1);

$root = '/var/www/html/config';
if (!is_dir($root) && !mkdir($root, 0755, true) && !is_dir($root)) {
    fwrite(STDERR, "Cannot create SLiMS config directory.\n");
    exit(1);
}

$appEnv = getenv('APP_ENV') ?: 'production';
$dbHost = getenv('DB_HOST') ?: 'db';
$dbName = getenv('DB_NAME') ?: 'senayan';
$dbPort = getenv('DB_PORT') ?: '3306';
$dbUser = getenv('DB_USER') ?: '';
$dbPass = getenv('DB_PASS') ?: '';

if ($dbUser === '' || $dbPass === '') {
    fwrite(STDERR, "DB_USER and DB_PASS must be configured.\n");
    exit(1);
}

$envContents = "<?php\n"
    . '$env = ' . var_export($appEnv, true) . ";\n"
    . '$conditional_environment = ' . var_export($appEnv, true) . ";\n"
    . "\$based_on_ip = false;\n"
    . "\$range_ip = [''];\n";

$dbConfig = [
    'default_profile' => 'SLiMS',
    'proxy' => false,
    'nodes' => [
        'SLiMS' => [
            'host' => $dbHost,
            'database' => $dbName,
            'port' => $dbPort,
            'username' => $dbUser,
            'password' => $dbPass,
            'options' => ['storage_engine' => 'MyISAM'],
        ],
    ],
];

$dbContents = "<?php\nreturn " . var_export($dbConfig, true) . ";\n";

foreach (['env.php' => $envContents, 'database.php' => $dbContents] as $name => $contents) {
    $target = $root . '/' . $name;
    $temp = tempnam($root, '.slims-config-');
    if ($temp === false || file_put_contents($temp, $contents, LOCK_EX) === false) {
        fwrite(STDERR, "Could not write SLiMS configuration: {$name}\n");
        exit(1);
    }
    chmod($temp, 0640);
    if (!rename($temp, $target)) {
        @unlink($temp);
        fwrite(STDERR, "Could not install SLiMS configuration: {$name}\n");
        exit(1);
    }
}
