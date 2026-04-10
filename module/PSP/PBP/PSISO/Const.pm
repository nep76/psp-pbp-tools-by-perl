package PSP::PBP::PSISO::Const;

# PSP PSISO shared module
# http://classg.sytes.net

#use strict;
#use warnings;
use vars qw( $VERSION @ISA @EXPORT );
use Exporter;

# Auto flush (global effects)
$| = 1;

$VERSION = "1.0.0";

@ISA = qw(Exporter);
@EXPORT = qw(
	UNKNOWN_DAT_OFFSET
	UNKNOWN_DAT_END
	UNKNOWN_MAGIC_NUMBER_OFFSET
	UNKNOWN_MAGIC_NUMBER
	UNKNOWN_INDEX_POINTER
	GAMEDATA_OFFSET
	PSISO_HEADER PSISO_STRUCT_SEQ
	
	opt2name
);

sub PSISO_HEADER                { 'PSISOIMG0000' }
sub UNKNOWN_DAT_OFFSET          { 0x400 }
sub UNKNOWN_DAT_END             { 0xfffff }
sub UNKNOWN_MAGIC_NUMBER_OFFSET { 0xbfe }
sub UNKNOWN_MAGIC_NUMBER        { "\x10" }
sub UNKNOWN_INDEX_POINTER       { "\xff\x07\x00\x00" }
sub GAMEDATA_OFFSET             { 0x100000 }

sub PSISO_STRUCT_SEQ
{
	return (qw/
		UNKNOWN.DAT
		GAMEDATA
		STARTDAT
	/);
}

sub opt2name
{
	return {
		u => 'UNKNOWN.DAT',
		g => 'GAMEDATA',
		s => 'STARTDAT',
	}->{$_[0]};
}
1;