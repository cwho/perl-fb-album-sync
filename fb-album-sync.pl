#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>

#
#    Author: Chun Ho <cwho80@gmail.com>
#

use strict;
use warnings;
use LWP::Simple qw(get getstore is_error);
use JSON qw(decode_json);
use File::Path qw(mkpath);
use Getopt::Long;

my @optSpecificAlbums;
my $optNoTimelinePhotos = 0;
my $optAssumeSorted = 0;
my $optDateLimit = 0;
my $optFbAccessToken;
my $optRootPath = ".";
my $optMatchPartial = 0;
my $optMatchCaseInsens = 0;
my $optUseHttps = 0;

GetOptions("nt|no-timeline-photos" => \$optNoTimelinePhotos, "ab|album=s" => \@optSpecificAlbums, "as|assume-sorted" => \$optAssumeSorted, "dt|date-limit=i" => \$optDateLimit, "at|access-token=s" => \$optFbAccessToken, "o|output=s" => \$optRootPath, "mp|match-partial" => \$optMatchPartial, "mci|match-case-insensitive" => \$optMatchCaseInsens, "https|use-https" => \$optUseHttps);

if($#ARGV < 0) {
   printUsage();
   exit(1);
} 

main();

sub printUsage {
   print("\nUsage: fb-album-sync.pl [ <switches> ] <facebook user or page id>\n");
   print("where switches available are:\n");
   print("   -o <directory path> | --output <directory path> \n");
   print("        Specifies output directory.\n\n");
   print("   -nt | --no-timeline-photos \n");
   print("        Will not download timeline photos.\n\n");
   print("   -ab <album> | --album <album> \n");
   print("        Downloads only specified album by name. Can be used multiple times.\n\n");
   print("   -mp | --match-partial \n");
   print("        Specified album names are matched if the string exists in the album name, not if it matches exactly.\n\n");
   print("   -mci | --match-case-insensitive\n");
   print("        Specified album names are matched with case insensitivity.\n\n");
   print("   -dt <yyyymmdd> \n");
   print("        Specifies date limit - albums and photos before this date will not be downloaded.\n\n");
   print("   -https | --use-https \n");
   print("        use https.\n\n");
   print("   -at <token> | --access-token <token> \n");
   print("        use access token. Note: using access token will use https.\n\n");
}

sub main {
   my $fbId = $ARGV[0];
   my $outputPoint = "$optRootPath/$fbId";

   my $existingAlbumsHash = createAndReadPageOutputPoint($outputPoint);
   my $fbAlbumsArray = readAlbumListFromFB($fbId);
   checkAndSyncAlbums($outputPoint, $fbAlbumsArray, $existingAlbumsHash);
}

# creates output point if not exists and reads existing albums on FS. Returns hash ref
sub createAndReadPageOutputPoint {
   my $outputPoint = shift(@_);
   my %existingAlbumDirs;

   if(!(-d "$outputPoint")) {
      print "[INFO] Creating output point: $outputPoint\n";
      mkpath("$outputPoint");
   }

   print "[INFO] Reading $outputPoint\n";

   opendir(my $outputPointDir, $outputPoint) || die "can't opendir $outputPoint: $!";
   my @subdirs = grep { -d "$outputPoint/$_" } readdir($outputPointDir);
   for my $subdir (@subdirs) {
      if($subdir =~ /([0-9]+)\-([0-9]+)\-.*/) {
         $existingAlbumDirs{$2} = $subdir;
      }
   }
   closedir $outputPointDir;
   print "[INFO] Read ".(scalar keys %existingAlbumDirs)." existing album dirs\n";
   return \%existingAlbumDirs;
}

# reads albums from FB and return array ref
sub readAlbumListFromFB {
   my $fbId = shift(@_);
   my @albums;

   my $albumStartUrl = "://graph.facebook.com/$fbId/albums?fields=id,name,count,created_time,updated_time";
   if(defined $optFbAccessToken) {
      $albumStartUrl=$albumStartUrl."&access_token=".$optFbAccessToken;
   }
   if(defined $optFbAccessToken || $optUseHttps == 1) {
      $albumStartUrl="https".$albumStartUrl;
   } else {
      $albumStartUrl="http".$albumStartUrl;
   }
   my $albumUrl = $albumStartUrl;
   while(defined $albumUrl) {
      print "[INFO] Getting $albumUrl ...\n";
      my $json = get $albumUrl;
   
      die "Could not get $albumUrl!" unless defined $json;
      my $decoded_json = decode_json( $json );
   
      if(defined $decoded_json->{"data"} &&  ref $decoded_json->{"data"} eq "ARRAY") {
         for my $hash (@{$decoded_json->{"data"}}) {
		      my $name = $hash->{"name"};
		      $name =~ s/[^A-Za-z0-9]+/_/g;
		      $hash->{"hashedname"} = $name;
   	      push @albums, $hash; 
	      }   
      }

      if(defined $decoded_json->{"paging"} && defined $decoded_json->{"paging"}{"next"}) {
         $albumUrl = $decoded_json->{"paging"}{"next"};
      } else {
         undef $albumUrl;
      }
   }

   print "[INFO] Found ".($#albums+1)." albums\n";
   return \@albums;
}

   
# determines if an album name matches the specified albums in options   
sub isAlbumMatchOptSpecificAlbums {
   my $albumName = shift(@_);
   my $isMatch = 0;
   for my $specificAlbumName (@optSpecificAlbums) {
      if($optMatchPartial == 1 && $optMatchCaseInsens == 0) {
         $isMatch = 1 if(index($albumName, $specificAlbumName) != -1);
      } elsif($optMatchPartial == 0 && $optMatchCaseInsens == 1) {
	      $isMatch = 1 if(lc($specificAlbumName) eq lc($albumName));
      } elsif($optMatchPartial == 1 && $optMatchCaseInsens == 1) {
	      $isMatch = 1 if(index(lc($albumName), lc($specificAlbumName)) != -1);
      } else {
		   #if($optMatchPartial == 0 && $optMatchCaseInsens == 0) {
		   $isMatch = 1 if($specificAlbumName eq $albumName);
		}
	}
   return $;	
}  



# reads an existing album on FS and returns existing photos. Returns hash ref.
sub readExistingPhotosInFsAlbum {
   my $albumDirPath = shift(@_);
   my %existingPhotos;
   print "[INFO] Reading $albumDirPath\n";
   opendir(my $albumDir, $albumDirPath) || die "can't opendir $albumDirPath: $!";
   my @subfiles = grep { -f "$albumDirPath/$_" } readdir($albumDir);
   for my $subfile (@subfiles) {
      if($subfile =~ /([0-9]+)\-([0-9]+)\..*/) {
   	     #print "[DEBUG] Found existing subfile $subfile\n";
   	     $existingPhotos{$2} = $subfile;
      }
   }
   closedir $albumDir;
   return \%existingPhotos;
}

# checks and syncs the albums
sub checkAndSyncAlbums {
   my $outputPoint = shift(@_);
   my $albums = shift(@_);
   my $existingAlbumDirs = shift(@_);

   for my $album (@$albums) {
      print "[INFO] Checking album ".$album->{'id'}." ".$album->{'name'}."\n";
   
      my $albumUpdateTime = (substr $album->{'updated_time'}, 0, 4).(substr $album->{'updated_time'}, 5, 2).(substr $album->{'updated_time'}, 8, 2);
      if($albumUpdateTime < $optDateLimit) {
         print "[INFO] Update Time of $albumUpdateTime before date limit of $optDateLimit, skipping \n";
         next;
      }

      if($album->{'name'} eq "Timeline Photos" && $optNoTimelinePhotos == 1) {
         print "[INFO] Timeline Photos, skipping \n";
         next;
      } 
   
      if($#optSpecificAlbums >= 0) {
         if(!isAlbumMatchOptSpecificAlbums($album->{'name'})) {
	         print "[INFO] Skipping due to album selection \n";
            next;
         }
      }
   
      my $albumCreateTime = (substr $album->{'created_time'}, 0, 4).(substr $album->{'created_time'}, 5, 2).(substr $album->{'created_time'}, 8, 2);
      my $albumDirName = $albumCreateTime."-".$album->{'id'}."-".$album->{"hashedname"};
      if(defined $existingAlbumDirs->{$album->{'id'}}) {
         $albumDirName = $existingAlbumDirs->{$album->{'id'}};
      }
   
      my $albumDirPath = $outputPoint."/".$albumDirName;
      if(!(-d "$albumDirPath")) {
         print "[INFO] Creating $albumDirPath\n";
         mkpath $albumDirPath;
      }
   
      my $existingPhotosHash = readExistingPhotosInFsAlbum($albumDirPath);
      my $existingPhotosCount = scalar keys %$existingPhotosHash;
      print "[INFO] Read $existingPhotosCount existing photos\n";
   
      if($existingPhotosCount == $album->{'count'}) {
         print "[INFO] Same number of photos as album json - skipping check\n";
      } else {
         my $photosArray = getAlbumPhotosFromFB($album->{'id'});
	      checkAndSyncAlbumPhotos($photosArray, $existingPhotosHash, $albumDirPath);
      }
   }
}

# Gets list of photos from FB and returns array ref
sub getAlbumPhotosFromFB {
   my $albumId = shift(@_);
   my @photos;
   my $photoStartUrl = "://graph.facebook.com/".$albumId."/photos?fields=id,name,images,created_time,updated_time";
   if(defined $optFbAccessToken) {
      $photoStartUrl=$photoStartUrl."&access_token=".$optFbAccessToken;
   }
   if(defined $optFbAccessToken || $optUseHttps == 1) {
      $photoStartUrl="https".$photoStartUrl;
   } else {
      $photoStartUrl="http".$photoStartUrl;
   }   
   my $photoUrl = $photoStartUrl;
   while(defined $photoUrl) {
      print "[INFO] Getting $photoUrl ...\n";
      my $json = get $photoUrl;
      
      die "Could not get $photoUrl!" unless defined $json;
      my $decoded_json = decode_json( $json );
      my $doContinue = 1;
      if(defined $decoded_json->{"data"} &&  ref $decoded_json->{"data"} eq "ARRAY") {
         for my $hash (@{$decoded_json->{"data"}}) {
            my $photoUpdateTime = (substr $hash->{'updated_time'}, 0, 4).(substr $hash->{'updated_time'}, 5, 2).(substr $hash->{'updated_time'}, 8, 2);
			   if($photoUpdateTime < $optDateLimit) {
				   last if($optAssumeSorted == 1);
			   } else {
			      push @photos, $hash; 
			   }
	      }   
      }
      if(defined $decoded_json->{"paging"} && defined $decoded_json->{"paging"}{"next"} && $doContinue == 1) {
         $photoUrl = $decoded_json->{"paging"}{"next"};
      } else {
         undef $photoUrl;
      }
   }   
   print "[INFO] Found ".($#photos+1)." photos\n";
   return \@photos;
}

# checks and syncs the photos
sub checkAndSyncAlbumPhotos {
   my $photosArray = shift(@_);
   my $existingPhotosHash = shift(@_);
   my $albumDirPath = shift(@_);
   for my $photo (@$photosArray) {
		
      next if(defined $existingPhotosHash->{$photo->{'id'}});
		 
		my $photoUpdateTime = (substr $photo->{'updated_time'}, 0, 4).(substr $photo->{'updated_time'}, 5, 2).(substr $photo->{'updated_time'}, 8, 2);
		if($photoUpdateTime < $optDateLimit) {
			#print "[INFO] Update Time of $photoUpdateTime before date limit of $optDateLimit, skipping \n";
			next;
		}
		 
		my $photoDownloadUrl;
		 
		if(defined $photo->{"images"} && ref $photo->{"images"} eq "ARRAY") {
		   my $maxWidth = 0;
		   for my $hash (@{$photo->{"images"}}) {
			   if($hash->{"width"} > $maxWidth) {
			      $maxWidth = $hash->{"width"};
			      $photoDownloadUrl = $hash->{"source"};
			   }
			}
		}
		 
		if(defined $photoDownloadUrl) {
		   if( $photoDownloadUrl =~ /.*(\.[A-Za-z0-9]+)$/) {
		      my $photoExt = $1;
			
		      print "[INFO] Downloading $photoDownloadUrl \n";
			   my $photoCreateTime = (substr $photo->{'created_time'}, 0, 4).(substr $photo->{'created_time'}, 5, 2).(substr $photo->{'created_time'}, 8, 2);
			   my $photoFilePath = $albumDirPath."/".$photoCreateTime."-".$photo->{"id"}.$photoExt;
		      my $respCode = getstore($photoDownloadUrl, $photoFilePath);
			   if(is_error($respCode)) {
			      unlink $photoFilePath;
			   } else {
    	         print "[INFO] Downloaded $photoFilePath \n";
			      if( defined $photo->{"name"} ) {
			         print "[INFO] Writing description file\n";
			         open(my $descfile, ">".$photoFilePath.".txt");
			         print $descfile $photo->{"name"};
			         close $descfile;
			      }
			   }
			}
		}
	}
}
