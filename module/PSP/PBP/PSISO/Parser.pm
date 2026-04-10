package PSP::PBP::PSISO::Parser;

#use strict;
#use warnings;
use vars qw( $VERSION );
use base qw( PSP::PBP::Parser );

$VERSION = "1.0.0";

use File::IOLite;
use PSP::PBP::PSISO::Const;
use DecHex qw( little_endian_hex2dec );

sub init
{
	my $self = shift;
	
	%{$self} = (
		file      => '',
		total_len => 0,
		len       => {},
		offset    => {},
		error     => Util::ErrorBag->new( 0 )
	
	);
	
	foreach( PSISO_STRUCT_SEQ ){
		$self->{'len'}->{$_}    = 0;
		$self->{'offset'}->{$_} = 0
	}
	
	return $self;
}

sub parse{
	my $self = shift;
	
	if( not -f $self->{'file'} ){
		$self->{'error'}->putin( "$self->{'file'} not found" );
		return;
	}
	
	$self->{'offset'}->{'UNKNOWN.DAT'} = UNKNOWN_DAT_OFFSET;
	$self->{'len'}->{'UNKNOWN.DAT'}    = UNKNOWN_DAT_END() - UNKNOWN_DAT_OFFSET() + 1;
	
	
	my $PSISO = File::IOLite->new( $self->{'file'} );
	$PSISO->open( 'RD' );
	
	$self->{'total_len'} = ( stat( $PSISO->fh ) )[7];
	
	$PSISO->move( 'HEAD', length( PSISO_HEADER ) );
	$self->{'offset'}->{'STARTDAT'} = little_endian_hex2dec( $PSISO->read( 4 ) );
	$self->{'len'}->{'STARTDAT'}    = $self->{'total_len'} - $self->{'offset'}->{'STARTDAT'};
	$self->{'offset'}->{'GAMEDATA'} = GAMEDATA_OFFSET;
	$self->{'len'}->{'GAMEDATA'}    = ( $self->{'offset'}->{'STARTDAT'} - 1 ) - $self->{'offset'}->{'GAMEDATA'};
	
	return 1;
}

1;