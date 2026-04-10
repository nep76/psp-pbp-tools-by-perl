package PSP::PBP::Const;

# PSP PBP tools shared module
# http://classg.sytes.net

#use strict;
#use warnings;
use vars qw( $VERSION @ISA @EXPORT );
use Exporter;

# Auto flush (global effects)
$| = 1;

$VERSION = "2.0.0";

@ISA = qw(Exporter);
@EXPORT = qw(
	PBP_HEADER PBP_VERSION PBP_HEADER_FIELD_LENGTH
	PBP_STRUCT_FILES_NUM PBP_STRUCT_SEQ
	opt2name
);

sub PBP_HEADER             { "\x00PBP" }
sub PBP_VERSION            { "\x00\x00\x01\x00" }
sub PBP_HEADER_FIELD_LENGTH{ 4 }
sub PBP_STRUCT_FILES_NUM   { 8 }
sub PBP_STRUCT_SEQ
{
	return (qw/
		PARAM.SFO
		ICON0.PNG
		ICON1.PNG
		PIC0.PNG
		PIC1.PNG
		SND0.AT3
		DATA.PSP
		DATA.PSAR
	/);
}

sub opt2name
{
	return {
		p => 'PARAM.SFO',
		i => 'ICON0.PNG',
		a => 'ICON1.PNG',
		t => 'PIC0.PNG',
		b => 'PIC1.PNG',
		s => 'SND0.AT3',
		0 => 'DATA.PSP',
		1 => 'DATA.PSAR'
	}->{$_[0]};
}

1;