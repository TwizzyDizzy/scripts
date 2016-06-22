<?php

/*
This script takes your koel (https://github.com/phanan/koel) database
and creates playlists from the folders defined. This comes in handy
if you have folders that have some specific meaning. For example, I have
a folder for tracks that do not belong to any album or a folder for mixes.
I wrote this script in order to access them easily from koel. This makes
sense mainly for folders that are one-dimensional, since a playlist cannot
represent multi-dimensional properties.
*/

error_reporting(E_ALL);

// CONFIG SECTION BEGIN

$koel_config = '/path/to/koel/.env';
$php_binary = '/usr/bin/php';

# $folders array format:
# array(["koel_user-id-1"] => array("folder-foo","folder-bar","folder-foobar"),

$folders = array(
        "1" => array("Tracks","Mixes"),
        "3" => array("Tracks","Mixes"),
        );

// CONFIG SECTION END

$config_vars = array( "DB_HOST","DB_DATABASE","DB_USERNAME","DB_PASSWORD" );

$file = fopen( $koel_config, "r" );
while(!feof($file)){
        $line = fgets($file);
        foreach( $config_vars as $var ) {
                if ( preg_match( "/^$var=/", $line, $matches ) ) {
                        define($var, str_replace( array ( "$var=", "\n"),"",$line ) );
                }
        }
}
fclose($file);

$mysqli = mysqli_connect(DB_HOST, DB_USERNAME, DB_PASSWORD, DB_DATABASE);


foreach ( $folders as $user_id => $folders ) {
        foreach( $folders as $folder ) {
                $res = mysqli_query($mysqli, "SELECT id FROM playlists WHERE user_id='$user_id' AND name = '$folder'");

                // create playlist if not present already
                if( mysqli_num_rows( $res ) == "0" ) {
                        mysqli_query( $mysqli, "INSERT INTO playlists (user_id,name) VALUES ('$user_id','$folder')" );
                }

                // get id of $folder playlist
                $res = mysqli_query( $mysqli, "SELECT id FROM playlists where user_id='$user_id' AND name = '$folder'" );
                $row = mysqli_fetch_assoc( $res );

                /* this only fetches the first playlist with that name, but I see no reason to care for the possibility
                of two playlists of the same name (but of cause different 'id') - that's probably not even possible
                without directly doing it in the database - and that would be your fault ;)
                */
                $playlist_id = $row['id'];

                // delete content of playlist
                $res = mysqli_query( $mysqli, "DELETE FROM playlist_song WHERE playlist_id='$playlist_id'" );


                // create playlist from songs that match $folder name (this obviously works on unix only because of forward slashes
                $res = mysqli_query( $mysqli, "SELECT id FROM songs WHERE path LIKE '%/$folder/%.%'" );
                while( $row = mysqli_fetch_assoc( $res ) ) {
                        $song_id = $row['id'];
                        $values[] = "('$playlist_id','".$song_id."')";
                }

                $sql = "INSERT INTO playlist_song (playlist_id,song_id) VALUES ".implode( ',',$values );
                $res = mysqli_query( $mysqli, $sql );
        }
}
?>
