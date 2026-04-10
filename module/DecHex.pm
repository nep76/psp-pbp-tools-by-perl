package DecHex;

# PSP PBP tools shared module
# http://classg.sytes.net

#use strict;
#use warnings;
use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK );
use Exporter;

$VERSION = "1.0.0";

@ISA       = qw(Exporter);
@EXPORT    = ();
@EXPORT_OK = qw(
	dec2little_endian_hex
	little_endian_hex2dec
);

sub dec2little_endian_hex
{
	return defined $_[0] ? pack( 'H*', join('', reverse ( unpack( '(A2)*', sprintf( '%08x', $_[0] ) ) ) ) ) : undef;
}

sub little_endian_hex2dec
{
	return $_[0] ? unpack( 'V*', $_[0] ) : 0;
}

1;