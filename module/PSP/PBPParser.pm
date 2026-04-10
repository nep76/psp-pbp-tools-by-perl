package PSP::PBPParser;

# PSP PBP parser module
# http://classg.sytes.net

use strict;
use warnings;
use vars qw( $VERSION @ISA @EXPORT );

use PSP::PBPh;
use File::IOLite;

$VERSION = "1.0.0";

sub BUFFER_SIZE{ 1024 }

sub new{
	my $class = shift;
	
	my $self = {};
	
	bless( $self, $class );
	
	$self->init;
	$self->{'pbp'} = shift || '';
	
	return $self;
}

sub error{
	return $_[0]->{'error'}->list;
}

sub file{
	$_[0]->{'pbp'} = $_[1] if( $_[1] );
	return $_[0]->{'pbp'};
}

sub init{
	my $self = shift;
	
	%{$self} = (
		pbp    => '',
		size   => 0,
		len    => {},
		offset => {},
		error => Util::ErrorBag->new( 0 )
	);
	
	foreach( PBP_DATA_SEQUENCE ){
		$self->{'len'}->{$_}    = 0;
		$self->{'offset'}->{$_} = 0;
	}
	
	return 1;
}

sub parse_header{
	my $self = shift;
	{	
		if( not -f $self->{'pbp'} ){
			$self->{'error'}->putin("$self->{'pbp'} does not exist");
			last;
		}
		
		my $Pbp = File::IOLite->new( $self->{'pbp'} );
		$Pbp->open( 'RD' );
		$Pbp->binary;
		
		if( $Pbp->read( 4 ) ne "\x00PBP" ){
			$self->{'error'}->putin("$self->{'pbp'} is not valid PBP format");
			last;
		} else{
			my $cur_ver = $Pbp->read( 4 );
			if( scalar( @_ ) and not scalar( grep { $cur_ver eq $_ } @_ ) ){
				$self->{'error'}->putin("$self->{'pbp'} is not supported PBP version");
				last;
			}
		}
		
		$self->{'size'}       = (stat($Pbp->fh))[7];
		$self->{'offset'}->{$_} = unpack( 'V*', $Pbp->read( 4 ) ) foreach( PBP_DATA_SEQUENCE );
		
		my $prev_len    = 0;
		my $prev_offset = 0;
		foreach( reverse PBP_DATA_SEQUENCE ){
			$self->{'len'}->{$_} = $self->{'size'} - ( $self->{'offset'}->{$_} + $prev_len );
			
			if( $self->{'offset'}->{$_} == $prev_offset ){
				$self->{'len'}->{$_}    = 0;
				$self->{'offset'}->{$_} = 0;
			} else{
				$prev_len    += $self->{'len'}->{$_};
				$prev_offset = $self->{'offset'}->{$_};
			}
		}
		$Pbp->close;
	}
	return $self;
}

sub flen{
	return defined $_[0]->{'len'}->{$_[1]} ? $_[0]->{'len'}->{$_[1]} : undef;
}

sub foffset{
	return defined $_[0]->{'offset'}->{$_[1]} ? $_[0]->{'offset'}->{$_[1]} : undef;
}

sub fsize{
	return defined $_[0]->{'size'} ? $_[0]->{'size'} : undef;
}

sub output{
	my $self   = shift;
	my $name   = shift;
	my $output = shift || return;
	
	my $rotate = 0;
	my $rest   = 0;
	
	if( not exists $self->{'len'}->{$name} ){
		return;
	} elsif( not $self->{'len'}->{$name} ){
		return 1;
	} elsif( $self->{'len'}->{$name} <= BUFFER_SIZE ){
		$rest = $self->{'len'}->{$name};
	} else{
		$rotate = int( $self->{'len'}->{$name} / BUFFER_SIZE );
		$rest   = $self->{'len'}->{$name} - &BUFFER_SIZE * $rotate;
	}
	
	my $Pbp = File::IOLite->new( $self->{'pbp'} );
	$Pbp->open( 'RD' );
	$Pbp->binary;
	$Pbp->move( 'HEAD', $self->{'offset'}->{$name} );
	
	my $Pbpparts = File::IOLite->new( $output );
	$Pbpparts->open( 'WR', 'FIO_CREATE' );
	$Pbpparts->binary;
	
	$Pbpparts->write( $Pbp->read( BUFFER_SIZE ) ) while( $rotate-- );
	$Pbpparts->write( $Pbp->read( $rest ) )       if( $rest );
	
	$Pbpparts->close;
	$Pbp->close;
	
	die $Pbpparts->error if( $Pbpparts->error );
	die $Pbp->error      if( $Pbp->error );
	
	return 1;
}

1;
__END__