#!/usr/local/bin/perl

# PSP KXploit tool by Perl
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

use Getopt::Std;
use File::IOLite;
use PSP::PBP::Parser;

$VERSION = "3.0.0";

sub BUFFER_SIZE{ 1024 }

if( scalar @ARGV < 1 ){
	die <<_USAGE_;
PSP KXploit tool by Perl.

Usage: perl pkx.pl [options] PBP_File

    options:
      -o PATH    Install directory path. (ex. /mnt/PSP/GAME)
                 If this option is not set then will use current directory.

      -d DIRNAME Base directory name. (ex. hello_psp_world)
                 If this option is not set then will use current time.

      -h         Displaying help document. (It is this)

      -n         Do not hide the broken file.

      -r         Hide the broken file by legacy method.
                 (long directory name not allowed)
_USAGE_
}

my $src_pbp = pop @ARGV;
my %argv;
getopts( 'o:d:anh', \%argv );

$argv{'o'} ||= '.';
$argv{'d'} ||= time;

$src_pbp   =~ s/\\/\//g;
$argv{'o'} =~ s/\\/\//g;

die( "Install PBP file \"$src_pbp\" not found\n" ) if( not -f $src_pbp );

my ( $data_dir, $head_dir );
mkdirs:{
	if( $argv{'n'} ){
		$data_dir = $argv{'d'};
		$head_dir = $argv{'d'} . '%';
	} elsif( $argv{'r'} ){
		$data_dir = sprintf( '%- 31s', $argv{'d'} ) . '1';
		$data_dir =~ tr/ /_/;
		$head_dir = substr( $data_dir, 0, 6 ) . '~1%';
	} else{
		$data_dir = '__SCE__' . $argv{'d'};
		$head_dir = '%' . $data_dir;
	}
	
	$data_dir = $argv{'o'} . '/' . $data_dir;
	$head_dir = $argv{'o'} . '/' . $head_dir;
}

my $SRC_PBP_INFO = PSP::PBP::Parser->new( $src_pbp );
$SRC_PBP_INFO->parse;
die( $SRC_PBP_INFO->error ."\n" ) if( $SRC_PBP_INFO->error );

my $boundary = $SRC_PBP_INFO->offset( 'DATA.PSP' ) || $SRC_PBP_INFO->offset( 'DATA.PSAR' ) || 0;
die( "Is $src_pbp already applying kxploit?\n" ) if( not $boundary );

my ( $SRC_PBP, $DATA_PBP );
my ( $loop, $frac ) = ( 0, 0 );

$SRC_PBP  = File::IOLite->new( $src_pbp );
$SRC_PBP->open( 'RD' );
$SRC_PBP->binary;

printf( "Creating data directory...\n" );
mkdir( $data_dir ) or die( "Failed to mkdir: $data_dir: $!\n" );

printf( "Ready to writing data...\n" );
$loop = int( ( $SRC_PBP_INFO->total_len - $boundary ) / BUFFER_SIZE );
$frac = ( $SRC_PBP_INFO->total_len - $boundary ) - ( BUFFER_SIZE() * $loop );
$SRC_PBP->move( 'HEAD', $boundary ) or die( $SRC_PBP->error ."\n" );

printf( "Writing data to %s/EBOOT.PBP...\n", $data_dir );
$DATA_PBP = File::IOLite->new( $data_dir . "/EBOOT.PBP" );
$DATA_PBP->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
$DATA_PBP->binary;
$DATA_PBP->write( $SRC_PBP->read( BUFFER_SIZE ) ) while( $loop-- );
$DATA_PBP->write( $SRC_PBP->read( $frac )       ) if( $frac );
$DATA_PBP->close;
die( $DATA_PBP->error ."\n" ) if( $DATA_PBP->error );
undef $DATA_PBP;

printf( "Creating header directory...\n" );
mkdir( $head_dir ) or die( "Failed to mkdir: $head_dir: $!\n" );

printf( "Ready to writing header...\n" );
my ( $pbp_head, $pbp_ver, @pbp_index );
$SRC_PBP->move( 'HEAD' );
$SRC_PBP->read( 4, 0, \$pbp_head );
$SRC_PBP->read( 4, 0, \$pbp_ver  );
for( my $i = 0; $i < 8; $i++ ){
	$SRC_PBP->read( 4, 0, \$pbp_index[$i] );
}

# rewrite index
$pbp_index[6] = $pbp_index[5];
$pbp_index[7] = $pbp_index[5];

$boundary -= length( $pbp_head );
$boundary -= length( $pbp_ver  );
$boundary -= length( $_ ) foreach( @pbp_index );

$loop = int( $boundary / BUFFER_SIZE );
$frac = $boundary - ( BUFFER_SIZE() * $loop );

printf( "Writing header to %s/EBOOT.PBP...\n", $head_dir );
$DATA_PBP = File::IOLite->new( $head_dir . '/EBOOT.PBP' );
$DATA_PBP->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
$DATA_PBP->binary;
$DATA_PBP->write( $pbp_head, $pbp_ver, @pbp_index );
$DATA_PBP->write( $SRC_PBP->read( BUFFER_SIZE ) ) while( $loop-- );
$DATA_PBP->write( $SRC_PBP->read( $frac )       ) if( $frac );
$DATA_PBP->close;
die( $DATA_PBP->error ."\n" ) if( $DATA_PBP->error );
undef $DATA_PBP;

$SRC_PBP->close;
die( $SRC_PBP->error ."\n" ) if( $SRC_PBP->error );

printf( "Done.\n" );

__END__