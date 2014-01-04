perl-fb-album-sync
==================

This perl script allows you to download images by album from a Facebook page or user.
It downloads the images to a specified location. Future invocations will download only new material.

If the albums are private, you need to get a Facebook access token to pass to the program. You can get an access token with the "user.photos" and "friend.photos" permissions from the Facebook Graph API Explorer (https://developers.facebook.com/tools/explorer).

If the album owner has set up privacy settings to deny access to the albums/photos from Apps, then you will not be able to use this script (or the Graph API) to download them, even if you are a friend and have the access permissions within Facebook.


Usage
=====
```
Usage: fb-album-sync.pl [ <switches> ] <facebook user or page id>
where switches available are:
   -o <directory path> | --output <directory path>
        Specifies output directory.

   -nt | --no-timeline-photos
        Will not download timeline photos.

   -ab <album> | --album <album>
        Downloads only specified album by name. Can be used multiple times.

   -mp | --match-partial
        Specified album names are matched if the string exists in the album name
, not if it matches exactly.

   -mci | --match-case-insensitive
        Specified album names are matched with case insensitivity.

   -dt <yyyymmdd>
        Specifies date limit - albums and photos before this date will not be do
wnloaded.

   -https | --use-https
        use https.

   -at <token> | --access-token <token>
        use access token. Note: using access token will use https.

```

The supplied facebook page or user id does not have to be the numeric id but also the url suffix, e.g.
"liferay" from https://www.facebook.com/liferay

The images are saved in the supplied output directory (current working directory default) in the structure:
```
<supplied output directory>
   + subdir: <fb page or user id>
      + subdir: <yyyymmdd create date of album>-<album id>-<safe album name>
          + file: <yyyymmdd create date of photo>-<photo id>.<ext>
          + file: <yyyymmdd create date of photo>-<photo id>.<ext>
          + file: <yyyymmdd create date of photo>-<photo id>.<ext>
```
When the script is run again, the script will run the output area and determine what content is new to be downloaded.


Perl
====

HTTP is used to access the graph API by default. If you pass a access token or use -https, then it will use HTTPS. You will need LWP::Protocol::https installed for HTTPS to work. Developed off Perl 5.14+

Dependencies: LWP::Simple File::Path JSON Getopt::Long
