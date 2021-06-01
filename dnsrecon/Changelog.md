## Version 0.8.14

**Date: 11/19/18**
**Changes:**

- Fixed AXFR issue
- Support for querying via TCP.
- Better handling of no NameServer error.


## Version 0.8.13

**Date: 4/30/18**
**Changes:**

- Fixed typos
- Certificate Transparency logs consists a lot of domain information via Crt.sh thanks to @ginta1337


## Version 0.8.12

**Date: 12/12/17**
**Changes:**

- Removed AXFR from std enumeration type unless -a is specified.
- Fixed processing of TXT records.


## Version 0.8.11

**Date: 10/23/17**
**Changes:**

- Bug fix for python 3.6.x and the Google enumeration type.
- Merged PR for Bing support.
- Fixed issue when doing zone walks on servers without a SOA record.

## Version 0.8.9

### Date: 1/14/14
### Changes:
- Bug fixes.

## Version 0.8.8
- Minor bug fixes in parsing tool and dnsrecon.

### Date: 4/14/14
### Changes:
- Support for saving results to a JSON file.
- Bug fixes for:
    - Parsing SPF and TXT records when saving to XML, CSV and SQLite3.
    - Filtering of wildcard records when brute forcing a forward lookup zone.
    - Several typos and misspelled words.

## Version 0.8.5

### Date: 5/25/13
### Changes:
- Changed the way IP ranges are handled.
- Greatly improved speed and memory use in a reverse lookup of large networks.

## Version 0.8.4

### Date: 5/19/13
### Changes:
- Improved Whois parsing for ranges and organization.
- Better Whois record and request handling for RIPE and APNIC.
- Several bug fixes.
- Added print messages when saving output to files.


## Version 0.8.1

### Changes:
- Improved DNSEC zone walk.
- Several bug fixes for exporting data and parsing records in zone transfers.
- DigiNinja Edition for all his hard work in making dnsrecon better.
## Version 0.7.8

### Date: 7/8/12
### Changes:
- CSV files now have a proper header for better parsing on tools that support them like Excel and PowerShell.
- Windows System Console printing is now managed properly.
- CNAME records are now saved in SQLite3 and CSV output.
- Fixed an error when performing zone transfers due to improper indent.
- Fixed mislabeling of -c option in the help message.
- If a range or CIDR is provided and no scan type is given, dnsrecon will perform a reverse lookup against it. When other types are given, the rvl type will be appended to the list automaticaly.
- Improved NSEC type detection to eliminate possible false positives.
- Added processing of LOC, NAPTR, CERT and RP records of zone transfers returned. Proper information saved on XML output with proper field names in the attributes for these.
- Fixes on Google enumeration parsing.
- Fixed several typos.
- Better handling and canceling of threaded tasks.

## Version 0.7.3

### Date: 5/2/12
### Changes:
- Fixes for Python 3 compatibility.
- Fixed key values when saving results to XML and CSV.

## Version 0.7.0

### Date: 3/2/12
### Changes:
- Fixes to zonewalk option.
- Query for _domainkey record in standard enumeration.

## Version 0.6.8

### Date: 2/15/12
### Changes:
- Added tool folder with Python script for parsing results in XML and CSV format. 
- Added the ability to filter and extract hostnames and subdomains.
- Added Metasploit plugin for importing into Metasploit the CSV and XML results in a very fast manner using Nokogiri for XML. It will add hosts, notes for hostnames and service entries.
-Improvements on the zone transfer code:
	- Handling of zones with no NS records.
	- Proper parsing of PTR records in returned zones.
	- De-duplication of NS records IP addresses.
	- Provide additional info on failure.
	- Provide more info on actions being taken.

- Bug fixes reported by users at RandomStorm and by Robin Wood.
- Zone walking has been greatly improved including the accuracy of the results and the formatting to extract the information in a manner more useful for a pentester.

## Version 0.6.6

### Date: 1/20/12
### Changes:
- Does not for a Origin Check for zones transferred since some admin may have configured their zones without NS servers as experienced by a user.
- Handles exception if NS records cannot be resolved when performing a zone transfer test.
- Will always ??? for a test for the SOA and test it for zone transfer.
- Fixed a problem when generating an XML file from a zone transfer with the new parsing method. Info type was added to the XML output.

## Version 0.6.5
### Date: 1/16/12
### Changes:
- Fixed problem with get_ns.
- Python 3.2 support.
- Color printing of messages like Metasploit.
- New library for printing color messages.
- Improved parsing of records when there is a zone transfer.

## Version 0.6.1
### Date: 1/14/12
### Changes:
- IPv6 support for ranges in reverse lookup.
- Enhanced parsing of SPF records ranges to cover includes and IPv6.
- Specific host query for TXT RR.
- Better handling and logging of TXT and SPF RR.
- Started changes for Python 3.x compatibility.
- Filtering of wildcard records when saving brute force results.
- Show found records after brute force of domain is finished.
- Manage Ctrl-c when doing a brute force and save results for those records found.
- Corrected several spelling errors.

## Version 0.6
### Date: 1/11/12
### Changes:
- Removed mDNS enumeration due to the pybonjour library has been abandoned and faster ways are available to achieve enumeration of mDNS records in a sub-net.
- Removed unused variables.
- Applied changes for PEP8 compliance.
- Added comma delimited value to a file for the results.

## Version 0.5.1
### Date: 1/8/12
### Changes:
- Additional fixes for XML formatting.
- Ability to end a zonewalk with Ctrl-c and not lose data.
- Initial Metasploit plug-in to be able to import data from XML file generated by dnsrecon.

## Version 0.5
### Date: 1/8/12
### Changes:
- Will check in standard enumeration if DNSSEC is configured for the zone by checking for DNSKEY records and checking if the zone is configured as NSEC or NSEC3.
- With the get_ip() method it will also check for CNAME records and add those to the list found hosts.
- Will perform a DNSSEC zonewalk if NSEC records are available. It currently identifies A, AAAA, CNAME, NS and SRV records. For any other, it will just print the RDATA info.
- General record resolver method added.
- Changes to the options.

Known Issues:
- For some reason, the Python getopt is not parsing the options correctly in some cases. Considering changing to optparse even if it is more complicated to manage.
- When running Python 3.x the Whois query does not show the organization.
