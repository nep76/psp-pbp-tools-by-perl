#!/usr/local/bin/perl

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
use vars qw( $VERSION @g_tmpfiles );
use Getopt::Std;

use File::IOLite;
use PSP::PBP::Parser;
use PSP::PBP::Maker;
use PSP::PBP::PSISO::Const;
use PSP::PBP::PSISO::Maker;
use PSP::PBP::PSISO::Parser;
use PSP::PBP::PSISO::STARTDAT::Const;
use PSP::PBP::PSISO::STARTDAT::Maker;
use PSP::PBP::PSISO::STARTDAT::Parser;
use DecHex qw( dec2little_endian_hex );

$VERSION = "1.0.0";

$SIG{'INT'} = sub{ exit 1 };

sub HAPPY_MAGIC_NUMBER{ 37633 }
sub BUFFER_SIZE       { 1024 }

if( scalar @ARGV < 2 ){
	die <<_USAGE_;
PSP PBP maker by Perl.

Usage: psxconv.pl [options] BASE_PBP ISO_IMAGE
 options:
    -o PATH        Output path of converted PSX PBP file.
                   The default is "./EBOOT.PBP".

    -f             If the target PBP file (by -o option) alread exists,
                   then overwrite it.

    -d TEMP_DIR    Temporary directory path.
                   Using current directory by default.
                   If current directory not writable, then use this option.

    -n SAVE_DIR_NAME
    	           This is name of directory of PSX save data.
                   You must follow the format "_XXXX_YYYYY".
                   "X" is alphabets in upper case.
                   "Y" is digits.
                   (ex. _SLPS_12345 => ms0:/PSP/SAVEDATA/SLPS12345 )

                   The default is "_SLPS_00000".

    -t SAVE_DATA_TITLE
                   This is title of PSX save data.
                   The default is "PSX SAVEDATA".

    -s PNG_FILE    Splash screen at starting up the PSX emulator.
    	           The default inherit from BASE_PBP.
_USAGE_
}

my $isoimg   = pop @ARGV;
my $base_pbp = pop @ARGV;

my %argv;
getopts( 'd:o:n:s:t:f', \%argv );

foreach( keys %argv ){
	$argv{$_} =~ s/\\/\//g;
}

die( "ISO image \"$isoimg\" not found.\n" )       if( not -f $isoimg );
die( "Base PBP file \"$base_pbp\" not found.\n" ) if( not -e $base_pbp );

$argv{'o'} ||= "./EBOOT.PBP";
die( "$argv{'o'} already exists\n" ) if( -f $argv{'o'} and not $argv{'f'} );

$argv{'d'} ||= ".";
die( "$argv{'d'} not found\n" ) if( not -d $argv{'d'} );

$argv{'n'} ||= "_SLPS_10000";
die( "$argv{'n'} invalid fromat\n" ) if( $argv{'n'} !~ /^_[A-Z]{4}_[0-9]{5}$/ );

$argv{'t'} ||= "PSX SAVEDATA";

$argv{'s'} ||= '';
die( "$argv{'s'} not found\n" ) if( $argv{'s'} and not -f $argv{'s'} );

push( @g_tmpfiles, "$argv{'d'}/PARAM.SFO", "$argv{'d'}/DATA.PSP", "$argv{'d'}/DATA.PSAR" );
extract_files(
	PSP::PBP::Parser->new( $base_pbp ),
	'PARAM.SFO' => "$argv{'d'}/PARAM.SFO",
	'DATA.PSP'  => "$argv{'d'}/DATA.PSP",
	'DATA.PSAR' => "$argv{'d'}/DATA.PSAR"
);

push( @g_tmpfiles, "$argv{'d'}/STARTDAT" );
extract_files(
	PSP::PBP::PSISO::Parser->new( "$argv{'d'}/DATA.PSAR" ),
	'STARTDAT' => "$argv{'d'}/STARTDAT"
);

my $STARTDAT = PSP::PBP::PSISO::STARTDAT::Parser->new( "$argv{'d'}/STARTDAT" );
$STARTDAT->parse;
die( $STARTDAT->error . "\n" ) if( $STARTDAT->error );

if( $argv{'s'} ){
	push( @g_tmpfiles, "$argv{'d'}/PGD", "$argv{'d'}/NEW_STARTDA" );
	
	print "Extracting PGD to $argv{'d'}/PGD...";
	$STARTDAT->fdump( 'PGD', "$argv{'d'}/PGD" );
	print "done.\n";
	
	print "Rebuilding STARTDAT...";
	
	my $NEW_STARTDAT = PSP::PBP::PSISO::STARTDAT::Maker->new( "$argv{'d'}/NEW_STARTDAT" );
	$NEW_STARTDAT->set( 'SPLASH.PNG', $argv{'s'} );
	$NEW_STARTDAT->set( 'PGD', "$argv{'d'}/PGD" );
	$NEW_STARTDAT->make;
	die( $NEW_STARTDAT->error . "\n" ) if( $NEW_STARTDAT->error );
	unlink( "$argv{'d'}/STARTDAT" ) or die( "Failed to unlink: $!" );
	rename( "$argv{'d'}/NEW_STARTDAT", "$argv{'d'}/STARTDAT" ) or die( "Failed to rename: $!" );
	
	$STARTDAT->init->file( "$argv{'d'}/STARTDAT" );
	$STARTDAT->parse;
	die( $STARTDAT->error . "\n" ) if( $STARTDAT->error );
	print "done.\n";
}

my $pgd_offset = GAMEDATA_OFFSET() + ( stat( $isoimg ) )[7] + $STARTDAT->offset( 'PGD' );

push( @g_tmpfiles, "$argv{'d'}/UNKNOWN.DAT" );
conv_unknown_dat(
	"$argv{'d'}/UNKNOWN.DAT",
	'pgd_offset'          => $pgd_offset,
	'unknown_stream_seed' => ( stat( $isoimg ) )[7],
	'dirname'             => $argv{'n'},
	'title'               => $argv{'t'}
);

push( @g_tmpfiles, "$argv{'d'}/NEW_DATA.PSAR" );
print "Creating new DATA.PSAR to $argv{'d'}/NEW_DATA.PSAR...";
my $PSISO = PSP::PBP::PSISO::Maker->new( "$argv{'d'}/NEW_DATA.PSAR" );
$PSISO->set( "UNKNOWN.DAT", "$argv{'d'}/UNKNOWN.DAT" );
$PSISO->set( "GAMEDATA", $isoimg );
$PSISO->set( "STARTDAT", "$argv{'d'}/STARTDAT" );
$PSISO->make;
die( $PSISO->error . "\n" ) if( $PSISO->error );
print "done.\n";

print "Creating new EBOOT.PBP to $argv{'o'}...";
my $PBP = PSP::PBP::Maker->new( $argv{'o'} );
$PBP->set( 'PARAM.SFO', "$argv{'d'}/PARAM.SFO" );
$PBP->set( 'DATA.PSP', "$argv{'d'}/DATA.PSP" );
$PBP->set( 'DATA.PSAR', "$argv{'d'}/NEW_DATA.PSAR" );
$PBP->make;
die( $PBP->error . "\n" ) if( $PBP->error );
print "done.\n";

my $success = 1;

END{
	if( scalar( @g_tmpfiles ) ){
		print "Removing tempfiles.\n";
		unlink( @g_tmpfiles );
	}
		print "\nError occurred.\n" if( not $success );
}

sub extract_files
{
	my $SRC_FILE = shift;
	my %ex_files = @_;
	
	printf( "Extracting %s from %s...", join( ',', keys( %ex_files ) ), $SRC_FILE->file );
	$SRC_FILE->parse;
	foreach( keys( %ex_files ) ){
		$SRC_FILE->fdump( $_, $ex_files{$_} );
	}
	die( $SRC_FILE->error . "\n" ) if( $SRC_FILE->error );
	print "done.\n";
	
	return 1;
}

sub conv_unknown_dat
{
	my $udat_path = shift;
	my %opt       = @_;
	
	print "Creating new UNKNOWN.DAT to $udat_path...";
	my ( $UNKNOWN_DAT, $null_length );
	$UNKNOWN_DAT = File::IOLite->new( $udat_path );
	$UNKNOWN_DAT->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
	$UNKNOWN_DAT->binary;
	
	$UNKNOWN_DAT->write( $opt{'dirname'} );
	
	die( $UNKNOWN_DAT->error . "\n" ) if( $UNKNOWN_DAT->error );
	
	$null_length = ( 0x1220 - UNKNOWN_DAT_OFFSET() ) - $UNKNOWN_DAT->position;
	_null_write( $UNKNOWN_DAT, $null_length );
	$UNKNOWN_DAT->write( dec2little_endian_hex( $opt{'pgd_offset'} ) );
	$UNKNOWN_DAT->write( "\x00" x 4 );
	$UNKNOWN_DAT->write( UNKNOWN_INDEX_POINTER );
	$UNKNOWN_DAT->write( $opt{'title'} );
	
	$null_length = ( 0x4000 - UNKNOWN_DAT_OFFSET() ) - $UNKNOWN_DAT->position;
	_null_write( $UNKNOWN_DAT, $null_length );
	
	my $step    = 0x93;
	my $current = 0;
	my $stepcnt = 0;
	
	while( $current <= $opt{'unknown_stream_seed'} ){
		$stepcnt++;
		$current += HAPPY_MAGIC_NUMBER;
	}
	
	$current = 0;
	while( $stepcnt-- ){
		$UNKNOWN_DAT->write( "\x00", dec2little_endian_hex( $current ) , dec2little_endian_hex( $step ), "\x00" x 23 );
		$current += $step;
	}
	$null_length = ( GAMEDATA_OFFSET() - UNKNOWN_DAT_OFFSET() ) - $UNKNOWN_DAT->position;
	_null_write( $UNKNOWN_DAT, $null_length );
	$UNKNOWN_DAT->move( 'HEAD', UNKNOWN_MAGIC_NUMBER_OFFSET() - UNKNOWN_DAT_OFFSET() );
	$UNKNOWN_DAT->write( UNKNOWN_MAGIC_NUMBER );
	$UNKNOWN_DAT->close;
	die( $UNKNOWN_DAT->error . "\n" ) if( $UNKNOWN_DAT->error );
	print "done.\n";
	
	return 1;
}

sub _null_write
{
	my $File = shift;
	my $len  = shift;
	
	my $loop = 0;
	my $frac = 0;
	
	if( $len < BUFFER_SIZE ){
		$frac = $len;
	} else{
		$loop = int( $len / BUFFER_SIZE() );
		$frac = $len - ( BUFFER_SIZE() * $loop );
	}
	
	$File->write( "\x00" x BUFFER_SIZE ) while( $loop-- );
	$File->write( "\x00" x $frac )       if( $frac );
	
	return 1;
}