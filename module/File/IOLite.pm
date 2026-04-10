package File::IOLite;
require 5.6.0;

# File::IOLite
# http://classg.sytes.net

#use strict;
#use warnings;
#use utf8;
use Util::ErrorBag;

our $VERSION = 1.0.0;

use Fcntl qw(
	LOCK_SH  LOCK_EX  LOCK_NB  LOCK_UN
	O_APPEND O_CREAT  O_EXCL   O_RDONLY
	O_RDWR   O_TRUNC  O_WRONLY
	SEEK_SET SEEK_CUR SEEK_END
);

sub DEFAULT_PERMISSION{ 0666 }
sub LOCKED_BY_FLOCK   { 1 }
sub LOCKED_BY_RNLOCK  { 3 }

sub FIOMTD{
	return {
		RD   => O_RDONLY,
		WR   => O_WRONLY,
		RDWR => O_RDWR,
		SW   => -1,
	}
}
sub FIOPT{
	return {
		FIO_APPEND  => O_APPEND,
		FIO_BLANK   => O_TRUNC,
		FIO_CREATE  => O_CREAT,
		FIO_EXCLUDE => O_EXCL
	}
}
sub FIOSEEK{
	return {
		HEAD => SEEK_SET,
		CUR  => SEEK_CUR,
		TAIL => SEEK_END
	}
}

sub DESTROY{
	$_[0]->close;
}#END DESTROY

sub new{
	my $class = shift;
	my $self  = {
		file   => ( defined $_[0] ? shift : '' ),
		state  => {},
		pref   => {},
		error  => Util::ErrorBag->new( verbose => 1 )
	};
	
	bless($self,$class);
	
	$self->_state_init;
	$self->_pref_init;
	
	return $self;
}#END new

sub _state_init{
	$_[0]->{'state'} = {
		fh       => undef,
		method   => undef,
	};
	
	$_[0]->_lockstate_init;
	
	return 1;
}#END _state_init

sub _lockstate_init{
	$_[0]->{'state'}->{'lockedby'} = 0;
	$_[0]->{'state'}->{'rnlock'} = {
		standby => '',
		working => ''
	};
	
	return 1;
}#END _lockstate_init

sub _pref_init{
	$_[0]->{'pref'} = {
		autochop    => 0,
		autoflush   => 0,
		use_syscall => 0,
		input_record_separator  => undef,
		output_record_separator => "\n"
	};
	
	return 1;
}#END _pref_init

sub file{
	$_[0]->{'file'} = $_[1] if( $_[1] );
	return $_[0]->{'file'};
}#END file

sub _opened{
	if( not defined $_[0]->{'state'}->{'fh'} ){
		$_[0]->{'error'}->putin("Filehandle does not defined. File is not opened yet",1);
		return;
	}
	return 1;
}#END _opened

sub error{
	return $_[0]->{'error'}->list;
}#END error

sub open{
	my $self   = shift;
	my $method = shift;
	if( not $method ){
		$self->{'error'}->putin('You must select open method');
		return;
	}
	my $perm = DEFAULT_PERMISSION;
	$perm = pop if( defined($_[-1]) and $_[-1] =~ /[0-9]/ );
	
	my $mode    = 0;
	
	if( not exists FIOMTD->{$method} ){
		$self->{'error'}->putin("Invalid open method constant \"$method\"");
		return;
	}
	
	SET_OPEN_MODE:{
		foreach( @_ ){
			if( not exists FIOPT->{$_} ){
				$self->{'error'}->putin("Invalid option constant \"$_\"");
				return;
			}
			$mode    = $mode    | FIOPT->{$_};
		}
	}
	
	my $fh;
	sysopen($fh,$self->{'file'},FIOMTD->{$method} | $mode,$perm) or ( $self->{'error'}->putin("Failed to open: $!") and return );
	
	$self->{'state'}->{'fh'}     = $fh;
	$self->{'state'}->{'method'} = $method;
	
	return $self;
}#END open

sub close{
	my $self = shift;
	
	return if( not $self->_opened );
	
	$self->unlock;
	
	close($self->{'state'}->{'fh'});
	
	
	$self->_state_init;
	
	return 1;
}#END close

sub binary{
	$self = shift;
	
	return if( not $self->_opened );
	
	binmode($self->{'state'}->{'fh'});
	
	return 1;
}#END binary

sub use_syscall{
	$_[0]->{'pref'}->{'use_syscall'} = 1;
	return $_[0];
}#END use_syscall

sub unuse_syscall{
	$_[0]->{'pref'}->{'use_syscall'} = 0;
	return $_[0];
}#END unuse_syscall

sub autoflush{
	$_[0]->{'pref'}->{'autoflush'} = 1;
	return $_[0];
}#END autoflush

sub no_autoflush{
	$_[0]->{'pref'}->{'autoflush'} = 0;
	return $_[0];
}#END no_autoflush

sub input_record_separator{
	$_[0]->{'pref'}->{'input_record_separator'} = $_[1];
	return $_[0];
}#END input_record_separator

sub output_record_separator{
	$_[0]->{'pref'}->{'output_record_separator'} = $_[1];
	return $_[0];
}#END output_record_separator

sub record_separator{
	$_[0]->input_record_separator($_[1]);
	$_[0]->output_record_separator($_[1]);
	return $_[0];
}#END record_separator

sub autochop{
	$_[0]->{'pref'}->{'autochop'} = 1;
	return $_[0];
}#END autochop

sub no_autochop{
	$_[0]->{'pref'}->{'autochop'} = 0;
	return $_[0];
}#END no_autochop

sub shlock{
	return $_[0]->_flock_wrapper(LOCK_SH);
}#END shlock

sub shlock_nb{
	return $_[0]->_flock_wrapper(LOCK_SH + LOCK_NB);
}#END shlock_nb

sub exlock{
	return $_[0]->_flock_wrapper(LOCK_EX);
}#END exlock

sub exlock_nb{
	return $_[0]->_flock_wrapper(LOCK_EX + LOCK_NB);
}#END exlock_nb

sub _flock_wrapper{
	my $self     = shift;
	my $lockmode = shift;
	
	return if( not $self->_opened );
	
	if( flock($self->{'state'}->{'fh'},$lockmode) ){
		$self->{'state'}->{'lockedby'} = LOCKED_BY_FLOCK;
		return 1;
	} else{
		$self->{'error'}->putin("Failed to lock: $!",1);
		return;
	}
}#END _flock_wrapper

sub rnlock{
	my $self = shift;
	my %args  = @_;
	
	return if( not $self->_opened );
	
	my $unlock  = shift;
	my $retry   = shift;
	my $timeout = shift;
	$retry   = 0  if( not defined $retry );
	$timeout = 60 if( not defined $timeout );
	
	if( ! $unlock ){
		$self->{'error'}->putin("You must set path to lockfile");
		return;
	}
	
	my $now           = time;
	my $locked_prefix = '.LOCKED';
	my $lockdir       = do{
		my $idx = rindex($unlock,'/',length($unlock));
		if( $idx == -1 ){
			return '';
		} else{
			return substr($unlock,$idx + 1);
		}
	};
	my $locked = "${lockdir}${locked_prefix}.${now}";
	
	for( my $i = 0; $i < $retry; $i++, sleep(1) ){
		if( rename($unlock,$locked) ){
			$self->{'state'}->{'lockedby'} = LOCKED_BY_RNLOCK;
			$self->{'state'}->{'rnlock'}   = {
				standby => $unlock,
				working => $locked
			};
			return 1;
		}
	}

	if( ! opendir(LOCKDIR,$lockdir) ){
		$self->{'error'}->putin("No such directory \"$lockdir\"");
		return;
	}
	my $locktime = do{
		my $file;
		while( $file = readdir(LOCKDIR) ){
			next if( $file eq '.' or $file eq '..' );
			last if( $file =~ /^$locked_prefix/ );
		}
		my $time = (split(/\./,$file,2))[1];
		if( $time =~ /^[0-9]+$/ ){
			return $time;
		} else{
			return 0;
		}
	};
	closedir(LOCKDIR);
	
	if( ! $locktime ){
		$self->{'error'}->putin("Unknown file lock error. Confirm lockfile name. Does filepath \"$unlock\" really exist?");
		return;
	} elsif( (($now - $locktime) > $timeout) and rename("${lockdir}${locked_prefix}.${locktime}",$unlock) ){
		$self->rnlock(@_);
	} else{
		$self->{'error'}->putin("File locked by other process. Please try again later. (about $timeout seconds)");
		return;
	}
}#END rnlock

sub unlock{
	my $self = shift;
	
	return if( not $self->_opened );
	
	if( $self->{'state'}->{'lockedby'} == LOCKED_BY_RNLOCK ){
		if( not rename($self->{'state'}->{'rnlock'}->{'working'},$self->{'state'}->{'rnlock'}->{'standby'}) ){
			$self->{'error'}->putin("Failed to rename for unlock of rnlock: $!");
			return;
		}
	} elsif( $self->{'state'}->{'lockedby'} == LOCKED_BY_FLOCK ){
		if( not flock($self->{'state'}->{'fh'},LOCK_UN) ){
			$self->{'error'}->putin("Failed to rename for unlock of flock: $!");
			return;
		}
	}
	
	$self->_lockstate_init;
	
	return 1;
}#END unlock

sub readln{
	my $self = shift;
	my $line = shift || 1;
	my $cont = shift;
	
	return if( not $self->_opened );
	
	if( $line =~ /[^0-9]/ ){
		$self->{'error'}->putin('Invalid number of lines');
		return;
	}
	
	local $/ = $self->{'pref'}->{'input_record_separator'} if( defined $self->{'pref'}->{'input_record_separator'} ) ;
	
	my $refer = ref $cont or 0;
	if( $refer eq 'SCALAR' ){
		while( $line-- ){
			${$cont} .= readline($self->{'state'}->{'fh'});
			chomp ${$cont} if( $self-{'pref'}->{'autochop'} );
		}
	} elsif( ($refer eq 'ARRAY') or (not $refer) ){
		$cont = [] if( not $refer );
		while( $line-- ){
			push(@{$cont},scalar(readline($self->{'state'}->{'fh'})));
			if( not defined $cont->[scalar(@{$cont}) - 1] ){
				pop @{$cont};
				last;
			}
		}
		chomp @{$cont} if( $self->{'pref'}->{'autochop'} );
		
	} else{
		$self->{'error'}->putin('Not supported data type');
		return;
	}
	
	return $refer ? $cont : ( wantarray ? @{$cont} : $cont->[0] );
}#END readln

sub read{
	my $self   = shift;
	my $bytes  = shift || 1;
	my $offset = shift || 0;
	my $cont   = shift;
	
	return if( not $self->_opened );
	
	if( $bytes =~ /[^0-9]/ or $offset =~ /[^0-9]/ ){
		$self->{'error'}->putin('Invalid reading length or offset value');
		return;
	}
	
	my $read_w;
	my $seek_w;
	if( $self->{'pref'}->{'use_syscall'} ){
		$read_w = sub{ sysread($_[0],$_[1],$_[2],$_[3]); };
		$seek_w = sub{ sysseek($_[0],$_[1],$_[2]); };
	} else{
		$read_w = sub{ read($_[0],$_[1],$_[2],$_[3]); };
		$seek_w = sub{ seek($_[0],$_[1],$_[2]); };
	}
	
	my $pointer;
	my $refer;
	if( ref $cont eq 'SCALAR' ){
		$pointer = $cont;
		$refer   = 1;
	} elsif( ref $cont ){
		$self->{'error'}->putin('Invalid reference type');
		return;
	} else{
		$pointer = \$cont;
	}
	
	&{$seek_w}($self->{'state'}->{'fh'},$offset,SEEK_CUR) if( $offset );
	&{$read_w}($self->{'state'}->{'fh'},${$pointer},$bytes,0);
	
	return $refer ? $pointer : ${$pointer};
}#END read

sub skipln{
	my $self = shift;
	my $line = shift || 1;
	
	return if( not $self->_opened );
	
	if( $line =~ /[^0-9]/ ){
		$self->{'error'}->putin('Invalid number of lines');
		return;
	}
	
	local $/ = $self->{'pref'}->{'input_record_separator'} if( defined $self->{'pref'}->{'input_record_separator'} );
	
	readline($self->{'state'}->{'fh'}) while( $line-- );
	
	return 1;
}#END skipln

sub move{
	my $self   = shift;
	my $whence = shift || 'CUR';
	my $bytes  = shift || 0;
	
	return if( not $self->_opened );
	
	if( $bytes =~ /[^0-9\-]/ ){
		$self->{'error'}->putin('Invalid skipping length');
		return;
	}
	
	if( not exists FIOSEEK->{$whence} ){
		$self->{'error'}->putin("Invalid seeking whence position");
		return;
	}
	
	my $seek_w = $self->{'pref'}->{'use_syscall'} ?
		sub{ sysseek($_[0],$_[1],$_[2]); } :
		sub{ seek($_[0],$_[1],$_[2]); };
	
	&{$seek_w}($self->{'state'}->{'fh'},$bytes,FIOSEEK->{$whence});
	
	return 1;
}#END move

sub position{
	my $self  = shift;
	
	return if( not $self->_opened );
	
	my $tell_w = $self->{'pref'}->{'use_syscall'} ?
		sub{ sysseek($_[0],0,SEEK_CUR); } :
		sub{ tell($_[0]); };
	
	return &{$tell_w}($self->{'state'}->{'fh'});
}#END position

sub cut{
	my $self = shift;
	my $size = shift;
	$size = $self->position if( not defined $size );
	
	return if( not $self->_opened );
	
	return truncate($self->{'state'}->{'fh'},$size);
}#END cut

sub _writer{
	my $self = shift;
	my $ln   = shift || 0;
	my $args = shift;
	
	return if( not $self->_opened );
	
	if( FIOMTD->{$self->{'state'}->{'method'}} == FIOMTD->{'RD'} ){
		$self->{'error'}->putin("Operation not permitted. It is now readonly operation");
		return;
	}
	
	my $write_w = $self->{'pref'}->{'use_syscall'} ?
		sub{ syswrite($_[0],${$_[1]}.$_[2]); }:
		sub{ print {$_[0]} ${$_[1]}.$_[2]; };
	
	my $br = '';
	foreach( @{$args} ){
		if( ref $_ eq 'SCALAR' ){
			$br .= $self->{'pref'}->{'output_record_separator'} if( $ln );
			&{$write_w}($self->{'state'}->{'fh'},$_,$br);
		} elsif( ref $_ eq 'ARRAY' ){
			foreach( @{$_} ){
				$br .= $self->{'pref'}->{'output_record_separator'} if( $ln );
				&{$write_w}($self->{'state'}->{'fh'},\$_,$br);
			}
		} elsif( ref $_ eq 'HASH' ){
			foreach( %{$_} ){
				$br .= $self->{'pref'}->{'output_record_separator'} if( $ln );
				&{$write_w}($self->{'state'}->{'fh'},\$_,$br);
			}
		} else{
			$br = $self->{'pref'}->{'output_record_separator'} if( $ln );
			&{$write_w}($self->{'state'}->{'fh'},\$_,$br);
		}
	}
	
	return 1;
}#END _writer

sub writeln{
	my $self = shift;
	$self->_writer(1,\@_);
}#END writeln

sub write{
	my $self = shift;
	$self->_writer(0,\@_);
}#END write

sub fh{
	return if( not $_[0]->_opened );
	return $_[0]->{'state'}->{'fh'};
}#END fh

sub eof{
	return if( not $_[0]->_opened );
	return CORE::eof $_[0]->{'state'}->{'fh'} ? 1 : 0;
}#END eof

sub suicide{
	my $self = shift;
	
	$self->close if( defined $self->{'state'}->{'fh'} );
	
	return unlink($self->{'file'});
}#END suicide

__END__