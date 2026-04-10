package PSP::PBP::PSISO::Maker;

# PSP PSISO maker module
# http://classg.sytes.net

#use strict;
#use warnings;
use vars qw( $VERSION );
use base qw( PSP::PBP::Maker );

$VERSION = "1.0.0";

use File::IOLite;
use PSP::PBP::PSISO::Const;
use DecHex qw( dec2little_endian_hex );

sub BUFFER_SIZE{ 1024 }

sub init
{
	my $self = shift;
	
	%{$self} = (
		file  => '',
		parts => {},
		error     => Util::ErrorBag->new( 0 )
	);
	
	foreach( PSISO_STRUCT_SEQ ){
		$self->{'parts'}->{$_} = '';
	}
	
	return $self;
}

sub make{
	my $self = shift;
	
	foreach( PSISO_STRUCT_SEQ ){
		if( not -f $self->{'parts'}->{$_} ){
			$self->{'error'}->putin( "$self->{'parts'}->{$_} not found" );
			return;
		}
	}
	
	if( ( stat( $self->{'parts'}->{( PSISO_STRUCT_SEQ )[0]} ) )[7] < ( UNKNOWN_DAT_END() - UNKNOWN_DAT_OFFSET() + 1 ) ){
		$self->{'error'}->putin( "UNKNOWN.DAT is too short. required 1,047,552 bytes" );
		return;
	}
	my $startdat_offset = ( stat( $self->{'parts'}->{( PSISO_STRUCT_SEQ )[1]} ) )[7] + GAMEDATA_OFFSET();
	
	my $PSISO = File::IOLite->new( $self->{'file'} );
	$PSISO->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
	$PSISO->binary;
	$PSISO->write( PSISO_HEADER, dec2little_endian_hex( $startdat_offset ) );
	$PSISO->write( "\x00" x 0x3F0 );
	
	my $PSISOPart;
	foreach( PSISO_STRUCT_SEQ ){
		next if( not $self->{'parts'}->{$_} );
		$PSISOPart = File::IOLite->new( $self->{'parts'}->{$_} );
		$PSISOPart->open( 'RD' );
		$PSISOPart->binary;
		$PSISO->write( $PSISOPart->read( BUFFER_SIZE ) ) while( not $PSISOPart->eof );
		$PSISOPart->close;
		if( $PSISOPart->error ){
			$self->{'error'}->putin( "File I/O error: " . $PSISOPart->error );
			return;
		}
	}
	
	$PSISO->close;
	
	if( $PSISO->error ){
		$self->{'error'}->putin( $PSISO->error );
		return;
	}
	
	return 1;
}

1;