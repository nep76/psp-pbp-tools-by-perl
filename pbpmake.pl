#!/usr/local/bin/perl

# PSP PBP maker by Perl
# http://classg.sytes.net

BEGIN{
	my $self = $0;
	$self =~ s/\\/\//g;
	if( $self =~ /\// ){
		$self = substr( $self, 0, rindex( $self, '/' ) );
	} else{
		$self = '.' ;
	}
	push( @INC, "$self/module" );
}

#use strict;
#use warnings;
use vars qw( $VERSION );
use IO::Socket;
use Getopt::Std;

use File::IOLite;
use PSP::PBP::Const;
use PSP::PBP::Maker;
use PSP::PBP::Parser;
use HttpDownloader;

$VERSION = "2.0.0";

sub BUFFER_SIZE     { 1024 }
sub TEMPNAME_PREFIX { '_TMP_' }

my ( $success, @g_tmpfiles );
$success = 0;

if( scalar @ARGV < 1 ){
	$success = 1;
	die <<_USAGE_;
PSP PBP maker by Perl.

Usage: pbpedit.pl [options] [PBP struct files] PBP_FILE
 options:
    -e - | PATH    The default is new creation to PBP_FILE.
                   But if this option was defined,
                   then script uses this value as source file.
                   If there are not defined some option,
                   then inherit it from source file.

                   PATH is the normal file path.
                   But "-" value is special value.
                   This is same as selection of the target PBP_FILE.
                   However, in this case, you must use -f option,
                   because the default is not allowed to overwrite.

    -f             If the target PBP_FILE alread exists,
                   then overwrite it.

    -d TEMP_DIR    Temporary directory path.
                   Using current directory by default.
                   If current directory not writable, then use this option.

 PBP struct files:
    -p remove | PATH | URI    PARAM.SFO
    -i remove | PATH | URI    ICON0.PNG
    -a remove | PATH | URI    ICON1.PNG
    -t remove | PATH | URI    PIC0.PNG
    -b remove | PATH | URI    PIC1.PNG
    -s remove | PATH | URI    SND0.AT3
    -0 remove | PATH | URI    DATA.PSP
    -1 remove | PATH | URI    DATA.PSAR
_USAGE_
}


my $new_pbp = pop @ARGV;
my %st_files;
getopts( 'p:i:a:t:b:s:0:1:d:fe:', \%st_files ) or exit 1;

my %option;
foreach( qw( d f e ) ){
	$option{$_} = $st_files{$_};
	delete $st_files{$_};
}

die( "$new_pbp already exists\n" ) if( not $option{'f'} and -f $new_pbp );

$option{'d'} ||= '.';
die( "$option{'d'} not found\n" ) if( not -d $option{'d'} );

my $NEW_PBP = PSP::PBP::Maker->new( $new_pbp );
foreach( keys %st_files ){
	$st_files{$_} =~ s/\\/\//g;
	$NEW_PBP->set( opt2name( $_ ), $st_files{$_} );
}

my $SRC_PBP;
if( $option{'e'} ){
	$option{'e'} = $new_pbp if( $option{'e'} eq '-' );
	$SRC_PBP = PSP::PBP::Parser->new( $option{'e'} );
	$SRC_PBP->parse;
	die( $SRC_PBP->error ) if( $SRC_PBP->error );
}

print "Selected struct files:\n";
my ( $file, @http_parts, @inherit_parts );
foreach( PBP_STRUCT_SEQ ){
	$file = $NEW_PBP->get( $_ );
	
	print "  $_: ";
	
	if( not $file or $file eq 'remove' ){
		if( ref $SRC_PBP and $SRC_PBP->len( $_ ) ){
			if( $file eq 'remove' ){
				print "remove";
				$NEW_PBP->unset( $_ );
			} else{
				print "inherit";
				push( @inherit_parts, $_ );
			}
		} else{
			print "none";
		}
	} elsif( $file =~ /^http:\/\// ){
		print "HTTP $file";
		push( @http_parts, $_ );
	} else{
		print "FILE $file";
		die( "$file not found.\n" ) if( not -f $file );
	}
	print "\n";
}

my $temp_seq = time;
my $temppath;

if( scalar @inherit_parts ){
	print "Extracting inherit file(s).\n";
	foreach( @inherit_parts ){
		$temp_seq++;
		$temppath = sprintf( '%s/%s%d', $option{'d'}, TEMPNAME_PREFIX, $temp_seq );
		
		push( @g_tmpfiles, $temppath ); # for cleaning files
		
		print "  Extracting inherit $_ to $temppath...";
		$SRC_PBP->fdump( $_, $temppath );
		print "done.\n";
		
		$NEW_PBP->set( $_, $temppath );
	}
}

if( scalar @http_parts ){
	print "Trying to get file(s) via HTTP.\n";
	
	my $Http = HttpDownloader->new;
	foreach( @http_parts ){
		$Http->init;
		$Http->set_http_uri( $NEW_PBP->get( $_ ) );
		
		printf( "  Connecting to %s:%d...\n", $Http->host, $Http->port );
		$Http->connect_to_server or die( $Http->error . "\n" );
		
		print "  Sending HTTP request...\n";
		$Http->send_http_request;
		
		$temp_seq++;
		$temppath = sprintf( '%s/%s%d', $option{'d'}, TEMPNAME_PREFIX, $temp_seq );
		
		push( @g_tmpfiles, $temppath ); # for cleaning files
		
		printf( "  Downloading /%s to %s...", $Http->path, $temppath );
		$Http->download( $temppath ) or die( $Http->error . "\n" );
		print "done.\n";
		
		$Http->disconnect;
		print "  Disconnected from foreign server.\n";
		
		$NEW_PBP->set( $_, $temppath );
	}
}

print "Writing PBP file...";
$NEW_PBP->make;
if( $NEW_PBP->error ){
	die( $NEW_PBP->error . "\n" );
}
print "done.\n";
$success = 1;

END{
	if( scalar( @g_tmpfiles ) ){
		print ".\n";
		unlink( @g_tmpfiles );
	}
	print "\nError occurred." if( not $success );
}
__END__