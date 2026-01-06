# uptime-pushover

Send notifications via Pushover if any listed site shows offline status.

## Notable features
- Pushover alerts:
  - Sent as priority-2 with noisy retries until acknowledged.
  - Not duplicated for any given site. Once an alert has been sent on a site, it
    it will not be sent again until after the sent message is acknowledged for
    a configurable amount of time (default is 5 minutes).
- Alert logs:
  - Per each alert sent, a log file is stored in ./alert-logs to help identify the
    reason for the alert (useful for debugging false positives).
  - Alert logs older than 14 days are automatically removed.

## Assumptions:
- Each monitored site is expected to provide a consistent "good health" statement
  at a consistent URL (both are configurable per "Configuration" below). Failure
  to proved the expected/configured "good health" statement is the definition of
  poor health which triggers an alert.

## Requires:
  - system packages:
    - jq
  - external services:
    - pushover, and a registered pushover app

## Configuration:
- Copy config.sh.dist to config.sh and edit per comments.
- Copy sites.txt.dist to sites.txt and edit per comments.

## Cron-based monitoring:
Configure a cron job to run (e.g. every minute), calling
/path/to/uptime-pushover/scan-all.sh

## Quick test from command line:
- Call scan-all.sh with no arguments: will scan all sites in sites.txt
  and alert appropriately.
- Call scan-all.sh with an argument of any single item in sites.txt:
  will scan that site and alert appropriately.

## Support
Support for this plugin is handled under Joinery's ["As-Is Support" policy](https://joineryhq.com/software-support-levels#as-is-support).

Public issue queue for this plugin: https://github.com/JoineryHQ/uptime-pushover/issues