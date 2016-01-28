<?php
error_reporting(0);

# CONFIG SECTION BEGIN

$ttrss_config_path = '/path/to/your/tinytinyrss/config.php';
$captcha_solver = '/path/to/your/fb-captcha-solver.php';
$php_binary = '/usr/bin/php';
$max_tries = '10';
$success_pattern = '/:\\)$/';

# CONFIG SECTION END

include($ttrss_config_path);

$mysqli = mysqli_connect(DB_HOST, DB_USER, DB_PASS, DB_NAME);
$res = mysqli_query($mysqli, "SELECT title,feed_url FROM ttrss_feeds WHERE feed_url LIKE '%FacebookBridge%'");
while ($row = mysqli_fetch_assoc($res)) {
        $success = null;
        for ( $tries = 0; $tries <= $max_tries; $tries++ ) {
                if ( $success !== true ) {
                        if ( preg_match ($success_pattern, shell_exec("$php_binary $captcha_solver \"" . $row['feed_url'] . "\"" ) ) ) {
                                $success = true;
                                $tries_used = $tries;
                        }
                }
        }

        if ( $success ) {
                echo "[SOLVED] [TRIES: $tries_used] [" . $row['title'] . "]\n";
        }
        else {
                echo "[FAILED] [TRIES: $tries_used] [" . $row['title'] . "]\n";
        }
}
?>
