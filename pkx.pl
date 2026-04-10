#!/usr/local/bin/perl

# PSP KXploit tool by Perl
# Version: 2.0.2
# http://classg.sytes.net

use strict;
use warnings;

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

use File::IOLite;
use PSP::PBPParser;

sub BUFFER_SIZE{ 1024 }

if   ( not defined $ARGV[0] ){ usage(); }
elsif( scalar( @ARGV ) < 1 ) { error("Not enought arguments"); }

my %conf = (
	path   => '.',
	dir    => join( '', (localtime)[0,1,2] ),
	nohide => 0
);
read_args( \%conf );
make_kxploit( \%conf );

#------------------------------------------------

sub error{
	my $err = shift;
	$err =~ s/_VAR_/shift/eg if( scalar( @_ ) );
	die "Error: $err" . ".\n";
}

sub usage{
	print <<_USAGE_;
PSP KXploit tool by Perl.

Usage: perl pkx.pl [options] Install_PBP_File
    
    options:
      -o PATH    Install directory path. (ex. /mnt/PSP/GAME)
                 If this option is not set then will use current directory.
      -d DIRNAME Directory name.
                 If this option is not set then will use current date.
      -h         Displaying help document. (It is this)
      -n         Do not hide the broken file.
_USAGE_
	exit(1);
}

sub read_args{
	my $conf = shift;
	my $argv = shift || \@ARGV;
	
	$conf->{'pbp'} = pop @{$argv};
	error("Install_PBP_File \"_VAR_\" does not exist", $conf->{'pbp'}) if( not -e $conf->{'pbp'} );
	
	for( my $i = 0; $i < scalar( @{$argv} ); $i++ ){
		if( $argv->[$i] eq '-o' ){
			$conf->{'path'} = $argv->[++$i];
			die "$conf->{'path'} is not a directory." if( not -d $conf->{'path'} );
		} elsif( $argv->[$i] eq '-d' ){
			$conf->{'dir'} = $argv->[++$i];
		} elsif( $argv->[$i] eq '-n' ){
			$conf->{'nohide'} = 1;
		} elsif( $argv->[$i] eq '-h' ){
			usage();
		} else{
			error("Illegal argument _VAR_", $argv->[$i]);
		}
	}
	
	return 1;
}

sub make_kxploit{
	my $conf = shift;
	
	my ( $datadir, $headdir );
	make_dir:{
		if( $conf->{'nohide'} ){
			$datadir = $conf->{'dir'};
			$headdir = $datadir;
		} else{
			$datadir = sprintf( '%- 31s', $conf->{'dir'} ) . '1';
			$datadir =~ tr/ /_/;
			$headdir = substr( $datadir, 0, 6 ) . '~1';
		}
		$datadir = $conf->{'path'} . '/' . $datadir;
		$headdir = $conf->{'path'} . '/' . $headdir . '%';
	}
	
	my $Pbp = PSP::PBPParser->new( $conf->{'pbp'} )->parse_header;
	error( $Pbp->error ) if( $Pbp->error );
	
	my $border = $Pbp->foffset( 'psp' ) || $Pbp->foffset( 'psar' ) || 0;
	error( "\"_VAR_\" is not valid unpatched PBP file", $conf->{'pbp'} ) if( not $border );
	
	my $Src  = File::IOLite->new( $conf->{'pbp'} );
	my $Head = File::IOLite->new( $headdir . '/EBOOT.PBP' );
	my $Data = File::IOLite->new( $datadir . '/EBOOT.PBP' );
	$Head->autoflush;
	$Data->autoflush;
	
	$Src->open( 'RD' );
	$Src->binary;

	mkdir( $datadir );
	print "Created data directory.\n";
	print "Writing data...\n";
	$Src->move( 'HEAD', $border );
	$Data->open( 'WR', 'FIO_CREATE', 'FIO_BLANK', 'FIO_APPEND' );
	$Data->binary;
	while( not $Src->eof ){
		error( $Src->error . $Data->error ) if( $Src->error or $Data->error );
		$Data->write( $Src->read( BUFFER_SIZE ) );
	}
	$Data->close;
	
	my $pbp_head;
	my $pbp_ver;
	my @pbp_index;
	
	$Src->move('HEAD');
	$Src->read( 4, 0, \$pbp_head );
	$Src->read( 4, 0, \$pbp_ver  );
	for( my $i = 0; $i < 8; $i++ ){ $Src->read( 4, 0, \$pbp_index[$i] ); }
	#rewrite index
	$pbp_index[6] = $pbp_index[5];
	$pbp_index[7] = $pbp_index[5];
	
	$border -= length( $pbp_head );
	$border -= length( $pbp_ver  );
	$border -= length( $_ ) foreach( @pbp_index );
	
	my $rotate = 0;
	my $rest   = 0;
	
	if( $border <= BUFFER_SIZE ){
		$rest = $border;
	} else{
		$rotate = int( $border / BUFFER_SIZE );
		$rest   = $border - ( &BUFFER_SIZE * $rotate );
	}
	
	mkdir( $headdir );
	print "Created header directory.\n";
	print "Writing header...\n";
	$Head->open( 'WR', 'FIO_CREATE', 'FIO_BLANK', 'FIO_APPEND' );
	$Head->binary;
	$Head->write( $pbp_head, $pbp_ver, @pbp_index );
	$Head->write( $Src->read( BUFFER_SIZE ) ) while( $rotate-- );
	$Head->write( $Src->read( $rest ) )       if( $rest );
	$Head->close;
	
	$Src->close;
	
	return 1;
}

__END__