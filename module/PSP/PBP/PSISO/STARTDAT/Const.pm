package PSP::PBP::PSISO::STARTDAT::Const;

#use strict;
#use warnings;
use vars qw( $VERSION @ISA @EXPORT );
use Exporter;

# Auto flush (global effects)
$| = 1;

$VERSION = "1.0.0";

@ISA = qw(Exporter);
@EXPORT = qw(
	STARTDAT_HEADER STARTDAT_HEADER_LENGTH STARTDAT_UNKNOWN_HEADER_DATA
	STARTDAT_STRUCT_SEQ
);

sub STARTDAT_HEADER             { 'STARTDAT' }
sub STARTDAT_HEADER_LENGTH      { 0x50 }
sub STARTDAT_UNKNOWN_HEADER_DATA{ "\x01\x00\x00\x00\x01\x00\x00\x00" }
sub STARTDAT_STRUCT_SEQ
{
	return (qw/
		SPLASH.PNG
		PGD
	/);
}

sub opt2name
{
	return {
		s => 'SPLASH.PNG',
		p => 'PGD',
	}->{$_[0]};
}

1;