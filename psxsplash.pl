#!/usr/local/bin/perl

# PSP PSX splash screen changer by Perl
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

use strict;
use warnings;
use Getopt::Std;
use vars qw( $VERSION $TempPrefix $PSISO_Offset $STARTDAT_Offset_from_PSISO @g_tmpfiles );

use File::IOLite;
use PSP::PBP::Parser;
use PSP::PBP::PSISO::Const;
use PSP::PBP::PSISO::STARTDAT::Const;
use PSP::PBP::PSISO::STARTDAT::Maker;
use PSP::PBP::PSISO::STARTDAT::Parser;
use DecHex qw( little_endian_hex2dec dec2little_endian_hex );

my $success = 0;

sub BUFFER_SIZE       { 1024 }
sub TEMPNAME_PREFIX   { '_TMP_' }

if( scalar @ARGV < 2 ){
	$success = 1;
	die <<_USAGE_;
PSP PSX splash screen changer by Perl.

Usage: psxsplash.pl [option] PNG_IMAGE PSX_EBOOT_PBP
 option:
    -d TEMP_DIR    Temporary directory path.
                   Using current directory by default.
                   If current directory not writable, then use this option.
_USAGE_
}

my $pbp = pop @ARGV;
my $png = pop @ARGV;

my %argv;
getopts( 'd:', \%argv );
$argv{'d'} ||= '.';

$TempPrefix = sprintf( "%s/%s", $argv{'d'}, TEMPNAME_PREFIX );

push( @g_tmpfiles,
	"${TempPrefix}OLD_STARTDAT",
	"${TempPrefix}NEW_STARTDAT",
	"${TempPrefix}PGD"
);

print "Extracting STARTDAT to ${TempPrefix}OLD_STARTDAT from $pbp by directly...";
direct_startdat_extract( $pbp, "${TempPrefix}OLD_STARTDAT" );
print "done.\n";

print "Extracting PGD to ${TempPrefix}PGD from ${TempPrefix}OLD_STARTDAT...";
extract_pgd( "${TempPrefix}OLD_STARTDAT", "${TempPrefix}PGD" );
print "done.\n";

print "Rebuilding ${TempPrefix}NEW_STARTDAT...";
rebuilding_startdat( "${TempPrefix}NEW_STARTDAT", $png, "${TempPrefix}PGD" );
print "done.\n";

print "Rewriting PBP file's PGD offset value by directly...";
my $NEW_STARTDAT = PSP::PBP::PSISO::STARTDAT::Parser->new( "${TempPrefix}NEW_STARTDAT" );
$NEW_STARTDAT->parse;
die( $NEW_STARTDAT . "\n" ) if( $NEW_STARTDAT->error );

my $new_pgd_offset_value = $STARTDAT_Offset_from_PSISO + $NEW_STARTDAT->offset( 'PGD' );

my $RawPBP = File::IOLite->new( $pbp );
$RawPBP->open( 'WR' );
$RawPBP->binary;
$RawPBP->move( 'HEAD', $PSISO_Offset );

$RawPBP->move( 'CUR', 0x1220 );
$RawPBP->write( dec2little_endian_hex( $new_pgd_offset_value ) );
die( $RawPBP->error ."\n" ) if( $RawPBP->error );
print "done.\n";

print "Writing new STARTDAT...";
$RawPBP->move( 'HEAD', $PSISO_Offset + $STARTDAT_Offset_from_PSISO );
my $SRC_STARTDAT = File::IOLite->new( "${TempPrefix}NEW_STARTDAT" );
$SRC_STARTDAT->open( "RD" );
$SRC_STARTDAT->binary;
while( not $SRC_STARTDAT->eof ){
	$RawPBP->write( $SRC_STARTDAT->read( BUFFER_SIZE ) );
}
$SRC_STARTDAT->close;
die( $SRC_STARTDAT->error ."\n" ) if( $SRC_STARTDAT->error );
$RawPBP->close;
die( $RawPBP->error ."\n" ) if( $RawPBP->error );
print "done.\n";

$success = 1;

END{
	if( scalar( @g_tmpfiles ) ){
		print "Removing tempfiles.\n";
		unlink( @g_tmpfiles );
	}
		print "\nError occurred.\n" if( not $success );
}

sub direct_startdat_extract
{
	my $pbp     = shift;
	my $outpath = shift;
	
	my $PBP = PSP::PBP::Parser->new( $pbp );
	$PBP->parse;
	die( $PBP->error , "\n" ) if( $PBP->error );
	
	$PSISO_Offset = $PBP->offset( 'DATA.PSAR' );
	
	my $RawPBP = File::IOLite->new( $pbp );
	$RawPBP->open( 'RD' );
	$RawPBP->binary;
	$RawPBP->move( 'HEAD', $PSISO_Offset );
	
	die( $RawPBP->error , "\n" ) if( $RawPBP->error );
	
	$RawPBP->move( 'CUR', length( PSISO_HEADER ) );
	$STARTDAT_Offset_from_PSISO = little_endian_hex2dec( $RawPBP->read( 4 ) );
	$RawPBP->move( 'HEAD', $PSISO_Offset + $STARTDAT_Offset_from_PSISO );
	
	my $OLD_STARTDAT = File::IOLite->new( $outpath );
	$OLD_STARTDAT->open( 'WR', 'FIO_CREATE' );
	$OLD_STARTDAT->binary;
	
	while( not $RawPBP->eof ){
		$OLD_STARTDAT->write( $RawPBP->read( BUFFER_SIZE ) );
	}
	$RawPBP->close;
	
	die( $OLD_STARTDAT->error , "\n" ) if( $OLD_STARTDAT->error );
	
	return 1;
}

sub extract_pgd
{
	my $src_startdat = shift;
	my $pgd_path = shift;
	my $OLD_STARTDAT = PSP::PBP::PSISO::STARTDAT::Parser->new( $src_startdat );
	$OLD_STARTDAT->parse;
	die( $OLD_STARTDAT->error , "\n" ) if( $OLD_STARTDAT->error );
	
	$OLD_STARTDAT->fdump( 'PGD', $pgd_path );
	
	return 1;
}

sub rebuilding_startdat
{
	my $new_outpath = shift;
	my $png         = shift;
	my $pgd         = shift;
	
	my $NEW_STARTDAT = PSP::PBP::PSISO::STARTDAT::Maker->new( $new_outpath );
	$NEW_STARTDAT->set( 'SPLASH.PNG', $png );
	$NEW_STARTDAT->set( 'PGD', $pgd );
	$NEW_STARTDAT->make;
	
	return 1;
}

sub direct_rewrite_pgd_offset
{
	my $pbp          = shift;
	my $new_startdat = shift;
	my $psiso_offset = shift;
	my $startdat_offset_from_psiso = shift;
	
	my $NEW_STARTDAT = PSP::PBP::PSISO::STARTDAT::Parser->new( $new_startdat );
	$NEW_STARTDAT->parse;
	die( $NEW_STARTDAT , "\n" ) if( $NEW_STARTDAT );
	
	my $new_pgd_offset_value = $startdat_offset_from_psiso + $NEW_STARTDAT->offset( 'PGD' );
	
	my $RawPBP = File::IOLite->new( $pbp );
	$RawPBP->open( 'WR' );
	$RawPBP->binary;
	$RawPBP->move( 'HEAD', $psiso_offset );
	
	$RawPBP->move( 'CUR', 0x1220 );
	$RawPBP->write( dec2little_endian_hex( $new_pgd_offset_value ) );
	
	$RawPBP->close;
	
	return 1;
}

sub writing_startdat
{
	my $startdat_offset_from_pbp = shift;
	
	my $RawPBP
}
