package PSP::PBP::Maker;

#use strict;
#use warnings;
use vars qw( $VERSION );

use File::IOLite;
use Util::ErrorBag;
use PSP::PBP::Const;
use DecHex qw( dec2little_endian_hex );

sub BUFFER_SIZE{ 1024 }

$VERSION = "2.0.0";

sub new
{
	my $class = shift;
	my $self  = {};
	
	bless( $self, $class );
	
	$self->init;
	$self->file( shift );
	
	return $self;
}

sub init
{
	my $self = shift;
	
	%{$self} = (
		file  => '',
		parts => {},
		error     => Util::ErrorBag->new( 0 )
	);
	
	foreach( PBP_STRUCT_SEQ ){
		$self->{'parts'}->{$_} = '';
	}
	
	return $self;
}

sub error
{
	return $_[0]->{'error'}->list;
}

sub file
{
	$_[0]->{'file'} = $_[1] if( $_[1] );
	return $_[0]->{'file'};
}

sub set
{
	my $self = shift;
	my $part = shift;
	my $file = shift;
	
	if( not exists $self->{'parts'}->{$part} ){
		$self->{'error'}->putin( "Unknown structure file name: $part" );
		return;
	}
	
	$self->{'parts'}->{$part} = $file;
	
	return 1;
}

sub get
{
	return $_[0]->{'parts'}->{$_[1]};
}

sub unset
{
	$_[0]->{'parts'}->{$_[1]} = '' if( $_[1] );
	return 1;
}

sub make
{
	my $self = shift;
	my ( $flen, @offset );
	
	# get first offset
	$offset[0] = length( PBP_HEADER ) + length( PBP_VERSION );
	$offset[0] += ( PBP_HEADER_FIELD_LENGTH() * PBP_STRUCT_FILES_NUM() );
	
	# get offsets
	foreach( PBP_STRUCT_SEQ ){
		if( not $self->{'parts'}->{$_} ){
			push( @offset, $offset[-1] );
			next;
		}
		
		if( not -f $self->{'parts'}->{$_} ){
			$self->{'error'}->putin( "$self->{'parts'}->{$_} not found" );
			return;
		}
		
		$flen = ( stat( $self->{'parts'}->{$_} ) )[7] || die "Fatal error: failed to \"stat\" system call: $self->{'parts'}->{$_}: $!\n";
		
		push( @offset, $flen + $offset[-1] );
	}
	pop @offset;
	
	# write pbp header
	if( $self->{'file'} eq '' ){
		$self->{'error'}->putin( "internel error: file not set" );
		return;
	}
	
	my $PBP = File::IOLite->new( $self->{'file'} );
	$PBP->open( 'WR', 'FIO_CREATE', 'FIO_BLANK' );
	$PBP->binary;
	$PBP->write( PBP_HEADER, PBP_VERSION );
	
	if( $PBP->error ){
		$self->{'error'}->putin( "File I/O error: header section:" . $PBP->error );
		return;
	}
	
	# write offsets
	foreach( @offset ){
		$PBP->write( dec2little_endian_hex( $_ ) );
	}
	
	# write data
	my $PBPPart;
	foreach( PBP_STRUCT_SEQ ){
		next if( not $self->{'parts'}->{$_} );
		$PBPPart = File::IOLite->new( $self->{'parts'}->{$_} );
		$PBPPart->open( 'RD' );
		$PBPPart->binary;
		$PBP->write( $PBPPart->read( BUFFER_SIZE ) ) while( not $PBPPart->eof );
		$PBPPart->close;
		if( $PBPPart->error ){
			$self->{'error'}->putin( "File I/O error: data section:" . $PBPPart->error );
			return;
		}
	}
	
	$PBP->close;
	
	if( $PBP->error ){
		$self->{'error'}->putin( $PBP->error );
		return;
	}
	
	return 1;
}

1;