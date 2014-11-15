speedcheck.sh - What does it do?
=======

It's a little script that continuously connects to an iperf3 server in order to determine the current bandwith.

I created it in order to confront my local broadband provider (Kabel Deutschland) with the shitty performance they seem to be delivering sometimes.

The script runs every two minutes on my DD-WRT router and is invoked by cron (see below).

Prerequisites
=======

  * Set up a cronjob via the admin interface of your DD-WRT router (see Administration > Management > "Additional Cron Jobs")
  * Mount an USB storage device to /jffs
  * The rest, I think, you can figure out by yourself, the script itself is not hard to understand

Please feel free to fork, contribute, file issues or buy me some flowers.

* Bitcoin: 161DUoRPtDQ896i8M2DRP4gnvNLUfaFLsc
* Namecoin: MzbU4nMuFR8gEpP3zfQs89y8MXKCo1moh3

Cheers, Thomas
